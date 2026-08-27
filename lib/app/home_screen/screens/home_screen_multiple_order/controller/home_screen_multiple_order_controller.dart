import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/send_notification.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/controllers/login_controller.dart';
import 'package:jippydriver_driver/models/order_model.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/services/audio_player_service.dart';
import 'package:jippydriver_driver/services/order_workflow_service.dart';
import 'package:jippydriver_driver/utils/common.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:get/get.dart';

class HomeScreenMultipleOrderController extends GetxController {
  Rx<UserModel> driverModel =Constant.userModel!.obs;
  RxBool isLoading = true.obs;
  RxInt selectedTabIndex = 0.obs;

  RxList<dynamic> newOrder = [].obs;
  RxList<dynamic> activeOrder = [].obs;

  @override
  void onInit() {
    getDriver();
    super.onInit();
  }
  getDriver() async {
    try {
      String? userId = await LoginController.getFirebaseId();
      final headers = await getHeaders();

      final response = await http.get(
        Uri.parse("${Constant.baseUrl}driver/getDriverDetails?driverId=$userId"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        Map<String, dynamic> userDetails;
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data') && data['data'] is Map) {
            userDetails = data['data'] as Map<String, dynamic>;
          } else {
            userDetails = data;
          }
        } else {
          userDetails = {};
        }

        if (userDetails.isNotEmpty) {
          if (!userDetails.containsKey('role')) {
            userDetails['role'] = Constant.userRoleDriver;
          }
          if (!userDetails.containsKey('active')) {
            userDetails['active'] = true;
          }
          if (!userDetails.containsKey('isActive')) {
            userDetails['isActive'] = true;
          }

          driverModel.value = UserModel.fromJson(userDetails);
          Constant.userModel = driverModel.value;
          newOrder.clear();
          activeOrder.clear();
          /// ========= In-Progress Order Logic =========
          if (driverModel.value.inProgressOrderID != null &&
              driverModel.value.inProgressOrderID!.isNotEmpty &&
              !(driverModel.value.inProgressOrderID!.length == 1 &&
                  driverModel.value.inProgressOrderID!.first == "")) {
            activeOrder.addAll(driverModel.value.inProgressOrderID!);
            await AudioPlayerService.playSound(false);
            return;
          }

          /// ========= New Order Request Logic =========
          if (driverModel.value.orderRequestData != null &&
              driverModel.value.orderRequestData!.isNotEmpty) {
            newOrder.add(driverModel.value.orderRequestData!.first);
          }

          if (newOrder.isEmpty) {
            await AudioPlayerService.playSound(false);
          }

          if (newOrder.isNotEmpty && (driverModel.value.vendorID?.isEmpty ?? true)) {
            await AudioPlayerService.playSound(true);
          }
        }
      }
    } catch (e) {
      print("Error fetching driver: $e");
    }

    isLoading.value = false;
  }

  acceptOrder(OrderModel currentOrder) async {
    // Prevent accepting if already in progress
    if (driverModel.value.inProgressOrderID != null &&
        driverModel.value.inProgressOrderID!.isNotEmpty &&
        !(driverModel.value.inProgressOrderID!.length == 1 && driverModel.value.inProgressOrderID!.first == "")) {
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
      if (assignResult == null) {
        Get.snackbar(
          "Rate Limited",
          "Too many requests. Please wait a moment and try again.",
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 3),
        );
        return; // Don't clear order, allow retry
      }
      if (assignResult == true) {
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
