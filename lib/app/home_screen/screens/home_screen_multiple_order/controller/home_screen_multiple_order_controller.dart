import 'dart:async';
import 'dart:convert';

import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/send_notification.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/app/auth_screen/controller/login_controller.dart';
import 'package:jippydriver_driver/models/driver_delivery_charge_model.dart';
import 'package:jippydriver_driver/models/order_model.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/services/audio_player_service.dart';
import 'package:jippydriver_driver/services/auth_http_client.dart';
import 'package:jippydriver_driver/services/driver_delivery_charge_service.dart';
import 'package:jippydriver_driver/services/order_detail_service.dart';
import 'package:jippydriver_driver/services/order_workflow_service.dart';
import 'package:jippydriver_driver/utils/common.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/utils/utils.dart';
import 'package:get/get.dart';

class HomeScreenMultipleOrderController extends GetxController {
  Rx<UserModel> driverModel =Constant.userModel!.obs;
  RxBool isLoading = true.obs;
  RxInt selectedTabIndex = 0.obs;

  RxList<dynamic> newOrder = [].obs;
  RxList<dynamic> activeOrder = [].obs;

  /// Order id -> details returned by
  /// `getDriverDeliveryChargesForOrder` (outlet, customer, distances,
  /// charges, tip, COD, order total).
  final RxMap<String, DriverDeliveryChargeModel> deliveryCharges =
      <String, DriverDeliveryChargeModel>{}.obs;

  final Set<String> _chargesInFlight = {};
  final Map<String, DateTime> _chargesRetryAfter = {};
  static const Duration _chargesFailureTtl = Duration(seconds: 60);

  @override
  void onInit() {
    getDriver();
    super.onInit();
  }
  getDriver() async {
    try {
      String? userId = await LoginController.getFirebaseId();

      // Uses the shared getDriverDetails cache (FireStoreUtils).
      final userDetails = await FireStoreUtils.getDriverDetailsData(userId);
      // `getActiveOrderByDriverId` is authoritative for the active order,
      // because `getDriverDetails` does not include the in-progress lists.
      final serverActiveOrderId = await _fetchActiveOrderId(userId);

        if (userDetails.isNotEmpty) {
          driverModel.value = UserModel.fromJson(userDetails);
          Constant.userModel = driverModel.value;
          newOrder.clear();
          activeOrder.clear();
          /// ========= In-Progress Order Logic =========
          final inProgressIds = driverModel.value.inProgressOrderID;
          if (inProgressIds.isNotEmpty &&
              !(inProgressIds.length == 1 && inProgressIds.first == "")) {
            activeOrder.addAll(inProgressIds);
            if (serverActiveOrderId != null &&
                !activeOrder.contains(serverActiveOrderId)) {
              activeOrder.add(serverActiveOrderId);
            }
            for (final id in activeOrder) {
              unawaited(loadDeliveryChargesFor(id.toString()));
            }
            await AudioPlayerService.playSound(false);
            isLoading.value = false;
            return;
          }

          /// ========= New Order Request Logic =========
          final requestIds = driverModel.value.orderRequestData;
          if (requestIds.isNotEmpty) {
            newOrder.add(requestIds.first);
            for (final id in newOrder) {
              unawaited(loadDeliveryChargesFor(id.toString()));
            }
          }

          if (newOrder.isEmpty) {
            await AudioPlayerService.playSound(false);
          }

          if (newOrder.isNotEmpty && (driverModel.value.vendorID?.isEmpty ?? true)) {
            await AudioPlayerService.playSound(true);
          }
        }

      // Show the server-reported active order even when the cached driver
      // profile has no in-progress list.
      if (serverActiveOrderId != null &&
          !activeOrder.contains(serverActiveOrderId)) {
        activeOrder.add(serverActiveOrderId);
        unawaited(loadDeliveryChargesFor(serverActiveOrderId));
      }
    } catch (e) {
      print("Error fetching driver: $e");
    }

    isLoading.value = false;
  }

  /// Returns the order id from `getActiveOrderByDriverId`, or null when the
  /// driver has no active order.
  Future<String?> _fetchActiveOrderId(String userId) async {
    if (userId.trim().isEmpty) return null;
    try {
      final response = await AuthHttpClient().get(
        Uri.parse(
          '${Constant.baseUrl}driver/getActiveOrderByDriverId'
          '?driverId=$userId',
        ),
        headers: await getHeaders(),
        timeout: const Duration(seconds: 10),
      );
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;

      var orderId = decoded['orderId']?.toString().trim() ?? '';
      if (orderId.isEmpty || orderId.toLowerCase() == 'null') {
        final data = decoded['data'];
        if (data is Map) {
          orderId = data['orderId']?.toString().trim() ?? '';
        }
      }

      if (orderId.isEmpty || orderId.toLowerCase() == 'null') return null;
      return orderId;
    } catch (_) {
      return null;
    }
  }

  /// Loads `getDriverDeliveryChargesForOrder` for [rawOrderId] and caches the
  /// result so both the New and Active cards can render outlet / customer /
  /// distance / charge / tip / COD details returned by the backend.
  Future<DriverDeliveryChargeModel?> loadDeliveryChargesFor(
    String rawOrderId,
  ) async {
    final orderId = rawOrderId.trim();
    if (orderId.isEmpty) return null;

    final cached = deliveryCharges[orderId];
    if (cached != null) return cached;
    if (_chargesInFlight.contains(orderId)) return null;

    final retryAt = _chargesRetryAfter[orderId];
    if (retryAt != null && DateTime.now().isBefore(retryAt)) return null;

    _chargesInFlight.add(orderId);
    try {
      bool isUsable(double? value, double limit) =>
          value != null && value != 0 && value.abs() <= limit;

      double? latitude = driverModel.value.location?.latitude;
      double? longitude = driverModel.value.location?.longitude;
      if (!isUsable(latitude, 90) || !isUsable(longitude, 180)) {
        latitude = Constant.locationDataFinal?.latitude;
        longitude = Constant.locationDataFinal?.longitude;
      }

      if (!isUsable(latitude, 90) || !isUsable(longitude, 180)) {
        final position = await Utils.getCurrentLocation();
        latitude = position?.latitude;
        longitude = position?.longitude;
      }

      if (latitude == null ||
          longitude == null ||
          latitude.abs() > 90 ||
          longitude.abs() > 180) {
        _chargesRetryAfter[orderId] =
            DateTime.now().add(const Duration(seconds: 15));
        return null;
      }

      final details = await DriverDeliveryChargeService.fetchForOrder(
        orderId: orderId,
        driverLatitude: latitude,
        driverLongitude: longitude,
      );
      if (details == null) {
        _chargesRetryAfter[orderId] =
            DateTime.now().add(_chargesFailureTtl);
        return null;
      }

      _chargesRetryAfter.remove(orderId);
      deliveryCharges[orderId] = details;
      deliveryCharges.refresh();
      return details;
    } finally {
      _chargesInFlight.remove(orderId);
    }
  }

  DriverDeliveryChargeModel? chargesFor(String? orderId) {
    if (orderId == null) return null;
    return deliveryCharges[orderId.trim()];
  }

  Future<({OrderModel? order, DriverDeliveryChargeModel? details})>
      fetchOrderBundle(dynamic rawOrderId) async {
    final orderId = rawOrderId?.toString().trim() ?? '';
    if (orderId.isEmpty) {
      return (order: null, details: null);
    }

    // Reuse the cached charges to build the order locally. Otherwise the
    // bundle call fetches the order and charges in a single network request.
    final cached = chargesFor(orderId);
    final bundle = await OrderDetailService.fetchOrderBundle(
      orderId,
      knownDetails: cached,
    );

    final details = bundle.details;
    if (details != null) {
      _chargesRetryAfter.remove(orderId);
      deliveryCharges[orderId] = details;
      deliveryCharges.refresh();
    }

    if (bundle.order != null) {
      return (order: bundle.order, details: details);
    }

    // Legacy fallback for deployments without the driver charges endpoint.
    final order = await FireStoreUtils.getOrderById(orderId);
    return (order: order, details: details ?? chargesFor(orderId));
  }

  acceptOrder(OrderModel currentOrder) async {
    // Prevent accepting if already in progress
    final inProgressIds = driverModel.value.inProgressOrderID;
    if (inProgressIds.isNotEmpty &&
        !(inProgressIds.length == 1 && inProgressIds.first == "")) {
      ShowToastDialog.showToast("You already have an order in progress. Complete it before accepting a new one.");
      return;
    }
    if (currentOrder.id == null || driverModel.value.id == null) {
      ShowToastDialog.showToast("Order or driver ID is missing!".tr);
      return;
    }
    await AudioPlayerService.playSound(false);
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      final assignResult = await OrderWorkflowService.acceptOrderBackend(
        order: currentOrder,
        driverModel: driverModel.value,
      );
      ShowToastDialog.closeLoader();
      // Handle rate limiting (429)
      if (assignResult.success == null) {
        Get.snackbar(
          "Rate Limited",
          "Too many requests. Please wait a moment and try again.",
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 3),
        );
        return; // Don't clear order, allow retry
      }
      if (assignResult.success == true) {
        // Reuse the details from the accept response instead of issuing a
        // second `getDriverDeliveryChargesForOrder` request.
        final details = assignResult.details;
        final acceptedId = currentOrder.id?.toString();
        if (details != null && acceptedId != null && acceptedId.isNotEmpty) {
          deliveryCharges[acceptedId] = details;
          deliveryCharges.refresh();
        }
        if (acceptedId != null && acceptedId.isNotEmpty) {
          newOrder.remove(acceptedId);
          if (!activeOrder.contains(acceptedId)) {
            activeOrder.add(acceptedId);
          }
        }
        if (currentOrder.author?.fcmToken != null) {
          await SendNotification.sendFcmMessage(
              Constant.driverAcceptedNotification,
              currentOrder.author!.fcmToken.toString(), {});
        }
        if (currentOrder.vendor?.fcmToken != null) {
          await SendNotification.sendFcmMessage(
              Constant.driverAcceptedNotification,
              currentOrder.vendor!.fcmToken.toString(), {});
        }
        ShowToastDialog.showToast("Order assigned successfully!".tr);
      } else {
        newOrder.remove(currentOrder.id);
        ShowToastDialog.showToast("Order already taken by another driver.".tr);
      }
    } finally {
      await AudioPlayerService.playSound(false);
    }
  }

  rejectOrder(OrderModel currentOrder) async {
    await AudioPlayerService.playSound(false);
    try {
      await OrderWorkflowService.rejectOrderBackend(
        order: currentOrder,
        driverModel: driverModel.value,
      );
      newOrder.remove(currentOrder.id);
    } finally {
      await AudioPlayerService.playSound(false);
    }
  }
}
