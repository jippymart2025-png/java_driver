import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/app/home_screen/controller/home_controller.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/send_notification.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/models/order_model.dart';
import 'package:jippydriver_driver/services/audio_player_service.dart';
import 'package:jippydriver_driver/services/order_workflow_service.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DeliverOrderController extends GetxController {
  RxBool isLoading = true.obs;
  RxBool conformPickup = false.obs;
  RxBool isCompletingOrder = false.obs; // Guard to prevent duplicate calls


  void confirmPickupFunction() {
    conformPickup.value = !conformPickup.value;
  }

  @override
  void onInit() {
    AppLogger.log('DeliverOrderController onInit() called', tag: 'Controller');
    super.onInit();
    // Avoid updating Rx during GetX initState / first build (parent Home GetX).
    WidgetsBinding.instance.addPostFrameCallback((_) => getArgument());
  }

  @override
  void onClose() {
    AppLogger.log('DeliverOrderController onClose() called', tag: 'Controller');
    super.onClose();
  }

  Rx<OrderModel> orderModel = OrderModel().obs;

  RxInt totalQuantity = 0.obs;

  void getArgument() {
    final argumentData = Get.arguments;
    if (argumentData != null) {
      final order = argumentData['orderModel'];
      if (order is OrderModel) {
        orderModel.value = order;
        var total = 0;
        for (final element in order.products ?? []) {
          final qty = element.quantity;
          total += qty is num
              ? qty.toInt()
              : int.tryParse(qty?.toString() ?? '0') ?? 0;
        }
        totalQuantity.value = total;
      }
    }
    isLoading.value = false;
  }


  Future<int> getTodayCompletedOrdersCount() async {
    int todayCount = 0;
    try {
      // 确保用户已登录
      if (Constant.userModel == null || Constant.userModel!.id == null) {
        log("User not logged in");
        return 0;
      }
      final driverID = Constant.userModel!.id.toString();
      final response = await http.get(
        Uri.parse('${Constant.baseUrl}orders/completed/today/$driverID'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          todayCount = data['count'] ?? 0;
        } else {
          log("API returned error: ${data['message'] ?? 'Unknown error'}");
        }
      } else {
        log("API request failed with status: ${response.statusCode}");
      }
    } catch (e) {
      log("Error getting today's completed orders: $e");
    }
    return todayCount;
  }


  Future<Map<String, dynamic>?> getZoneBonusByZoneId(String zoneId) async {
    try {
      final response = await http.post(
        Uri.parse("${Constant.baseUrl}zone/bonus/byZoneId"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"zone_id": zoneId}),
      );
      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);

        if (res['success'] == true && res['data'] != null) {
          return res['data'];
        } else {
          print("No bonus found for zone id: $zoneId");
          return null;
        }
      } else {
        print("API Error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error fetching zone bonus: $e");
      return null;
    }
  }



  void deliveryAmountBonusAmount() async {
    try {
      print("totalCalculatedCharge and zone id ${Constant.userModel?.zoneId.toString()} ");
      int orderCount = await getTodayCompletedOrdersCount();
      Map<String, dynamic>? docData =
          await getZoneBonusByZoneId(Constant.userModel?.zoneId ?? '');
      OrderModel? orderModelNew = await FireStoreUtils.getOrderById(
          orderModel.value.id ?? "");
      double totalCalculatedCharge = double.tryParse(
          orderModelNew?.calculatedCharges?['totalCalculatedCharge']?.toString() ?? '0'
      ) ?? 0.0;
      print("totalCalculatedCharge order Count  $orderCount");
      print("totalCalculatedCharge and zone id ${Constant.userModel?.zoneId.toString()} $totalCalculatedCharge");
      print("totalCalculatedCharge currentOrder Value id ${orderModel.value.id} ${orderModelNew?.calculatedCharges?['totalCalculatedCharge']}");
      if (docData != null) {
        int requiredOrdersForBonus = int.tryParse(docData['requiredOrdersForBonus'].toString()) ?? 0;
        int bonusAmount = int.tryParse(docData['bonusAmount'].toString()) ?? 0;
        if (orderCount == requiredOrdersForBonus) {
          Get.dialog(
            AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text("🎉 Congratulations!"),
              content: Text("You’ve received a bonus of ₹$bonusAmount for completing $requiredOrdersForBonus orders today!"),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
          print("Bonus given: $bonusAmount");
          print("bonusAmount ${bonusAmount}");
          print("bonusAmount ${requiredOrdersForBonus}");
        } else {
          print("totalCalculatedCharge  1 $totalCalculatedCharge");
        }
      } else {
        print("totalCalculatedCharge  2 $totalCalculatedCharge");
      }
    } catch (e) {
      print("totalCalculatedCharge deliveryAmountBonusAmount ${e.toString()} ");
    }
  }

  Future<double?> fetchToPay(String orderId) async {
    final url = Uri.parse('${Constant.baseUrl}mobile/orders/$orderId/billing/to-pay');
    print("[ToPay] Fetching ToPay for order: $orderId");

    try {
      final response = await http.get(url).timeout(Duration(seconds: 10));

      // Check if response is successful
      if (response.statusCode == 200) {
        // Check if response body is valid JSON (not HTML)
        final responseBody = response.body.trim();
        if (responseBody.startsWith('<!') || responseBody.startsWith('<html')) {
          print("[ToPay] ❌ API returned HTML instead of JSON. Status: ${response.statusCode}");
          return null;
        }

        try {
          final Map<String, dynamic> jsonResponse = json.decode(responseBody);
          if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
            if (jsonResponse['data']['found'] == true) {
              final toPay = (jsonResponse['data']['to_pay'] as num).toDouble();
              print("[ToPay] ✅ Successfully fetched ToPay: $toPay");
              return toPay;
            } else {
              print("[ToPay] ⚠️ Order billing not found (found: false)");
              return null;
            }
          } else {
            print("[ToPay] ⚠️ API returned success: false");
            return null;
          }
        } catch (jsonError) {
          print("[ToPay] ❌ Error parsing ToPay JSON: $jsonError");
          print("[ToPay] Response body: ${responseBody.substring(0, responseBody.length > 200 ? 200 : responseBody.length)}");
          return null;
        }
      } else {
        print("[ToPay] ❌ API returned status ${response.statusCode}");
        print("[ToPay] Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}");
      }

      return null;
    } catch (e) {
      print("[ToPay] ❌ Error fetching ToPay: $e");
      return null;
    }
  }

  double getOrderAmountToCollect() {
    final rawToPay = orderModel.value.toPay;
    final parsedToPay = rawToPay != null
        ? double.tryParse(rawToPay.toString().trim())
        : null;
    if (parsedToPay != null) return parsedToPay;

    final rawTotal = orderModel.value.calculatedCharges?['totalCalculatedCharge'];
    final parsedTotal = rawTotal != null
        ? double.tryParse(rawTotal.toString().trim())
        : null;
    if (parsedTotal != null) return parsedTotal;

    final parsedDeliveryCharge = orderModel.value.deliveryCharge != null
        ? double.tryParse(orderModel.value.deliveryCharge.toString().trim())
        : null;
    return parsedDeliveryCharge ?? 0.0;
  }

  HomeController get homeController => Get.find<HomeController>();

  String _walletUpdatedAmountText() {
    final cc = orderModel.value.calculatedCharges;
    final raw = cc?['totalCalculatedCharge'];
    final fromCalculated = double.tryParse(raw?.toString().trim() ?? '');
    if (fromCalculated != null) {
      return fromCalculated.toStringAsFixed(2);
    }
    final fallback =
        double.tryParse(orderModel.value.deliveryCharge?.toString().trim() ?? '') ??
            0.0;
    return fallback.toStringAsFixed(2);
  }

void _showWalletUpdatedPopup() {
  final amount = _walletUpdatedAmountText();

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Theme.of(Get.context!).cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.green,
                size: 32,
              ),
            ),

            const SizedBox(height: 16),

            // Title
            Text(
              'Wallet Updated'.tr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(Get.context!).textTheme.bodyLarge!.color,
              ),
            ),

            const SizedBox(height: 10),

            // Message
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: 'Your wallet has been updated with\n'.tr,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(Get.context!).textTheme.bodyMedium!.color,
                ),
                children: [
                  TextSpan(
                    text: '₹$amount',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Get.back();
                  Get.back(result: orderModel.value.id ?? true);
                },
                child: Text(
                  'OK'.tr,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: false,
  );
}
  Future<void> completedOrder() async {
    // Prevent duplicate calls
    if (isCompletingOrder.value) {
      print("[DeliverOrderController] Order completion already in progress, ignoring duplicate call");
      return;
    }
    isCompletingOrder.value = true;
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      // Extract totalCalculatedCharge from calculatedCharges
      // Try orderModel first (from arguments), then home currentOrder, then its observable
      dynamic chargeValue = orderModel.value.calculatedCharges?['totalCalculatedCharge'] ??
                           homeController.currentOrder.value.calculatedCharges?['totalCalculatedCharge'];
      num? parsedCharge;
      if (chargeValue == null) {
        // If calculatedCharges doesn't exist, try to use HomeController's totalCalculatedCharge
        parsedCharge = homeController.totalCalculatedCharge.value;
        print("[DeliverOrderController] calculatedCharges not found, using HomeController totalCalculatedCharge: $parsedCharge");
      } else if (chargeValue is num) {
        parsedCharge = chargeValue;
      } else {
        // Try parsing as string
        parsedCharge = num.tryParse(chargeValue.toString());
      }
      // Keep deliveryCharge in sync with computed charge if absent.
      if ((orderModel.value.deliveryCharge ?? '').toString().isEmpty) {
        final fallbackCharge = parsedCharge?.toDouble() ?? 0.0;
        orderModel.value.deliveryCharge = fallbackCharge.toString();
      }
      // Keep tip safe for downstream numeric parsing.
      orderModel.value.tipAmount = orderModel.value.tipAmount ?? '0';

      print("[DeliverOrderController] Set orderModel.deliveryCharge: ${orderModel.value.deliveryCharge}  ${orderModel.value.toPay} ");
      print("[DeliverOrderController] Playing sound");
      await AudioPlayerService.playSound(false);
      print("[DeliverOrderController] Setting status to completed");
      orderModel.value.status = Constant.orderCompleted;
      // Ensure driverID is set
      if (orderModel.value.driverID == null) {
        orderModel.value.driverID = Constant.userModel?.id;
        print("[DeliverOrderController] driverID was null, set to: ${orderModel.value.driverID}");
      }
      print("driverID:   ${orderModel.value.driverID}");
      print("paymentMethod: ${orderModel.value.paymentMethod}");
      print("deliveryCharge: ${orderModel.value.deliveryCharge}");
      print("tipAmount: ${orderModel.value.tipAmount}");
      if (orderModel.value.driverID == null ||
          orderModel.value.paymentMethod == null) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Order data is incomplete. Cannot complete order.");
        return;
      }
      print("[DeliverOrderController] Updating wallet amount");
      final amountToCollect = getOrderAmountToCollect();
      if (amountToCollect <= 0.0) {
        print('[DeliverOrderController][ERROR] Computed amount to collect is invalid: $amountToCollect');
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Order billing info missing. Cannot complete order.");
        return;
      }
      orderModel.value.toPay = amountToCollect.toStringAsFixed(2);
      print('[DeliverOrderController] Set ToPay: ${orderModel.value.toPay}');
      // Update wallet and delivery amount via separate APIs first
      // final ok = await OrderWorkflowService.completeDeliveryOrderBackend(
      //   order: orderModel.value,
      //   driverModel: homeController.driverModel.value,
      // );
      //
      // if (ok != true) {
      //   ShowToastDialog.closeLoader();
      //   ShowToastDialog.showToast("Failed to complete order".tr);
      //   return;
      // }

      // Bonus popup depends on updated completion stats.
      deliveryAmountBonusAmount();
      ShowToastDialog.closeLoader();
      print("[DeliverOrderController] Order completed, closing loader and going back");
      // Mark as completed immediately so API refresh can't re-add it before .then runs
      try {
        Get.find<HomeController>().markOrderAsCompleted(orderModel.value.id);
      } catch (_) {}
      _showWalletUpdatedPopup();
    } catch (e) {
      print("[DeliverOrderController] Error in completedOrder: $e");
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Failed to complete order");
    } finally {
      // Always unlock completion state, including any early-return path.
      isCompletingOrder.value = false;
    }
  }
  // completedOrder() async {
  //   ShowToastDialog.showLoader("Please wait".tr);
  //   await AudioPlayerService.playSound(false);
  //   orderModel.value.status = Constant.orderCompleted;
  //   await FireStoreUtils.updateWallateAmount(orderModel.value);
  //   await FireStoreUtils.setOrder(orderModel.value);
  //   if (Constant.userModel?.vendorID?.isNotEmpty == true) {
  //     Constant.userModel?.orderRequestData?.remove(orderModel.value.id);
  //     Constant.userModel?.inProgressOrderID?.remove(orderModel.value.id);
  //     await FireStoreUtils.updateUser(Constant.userModel!);
  //   }
  //   await FireStoreUtils.getFirestOrderOrNOt(orderModel.value)
  //       .then((value) async {
  //     if (value == true) {
  //       await FireStoreUtils.updateReferralAmount(orderModel.value);
  //     }
  //   });
  //
  //   await SendNotification.sendFcmMessage(Constant.driverCompleted,
  //       orderModel.value.author!.fcmToken.toString(), {});
  //   ShowToastDialog.closeLoader();
  //   Get.back(result: true);
  // }
}


// // ============================================================
// //  deliver_order_controller_optimized.dart
// //
// //  Changes vs original:
// //  1. isCompletingOrder guard prevents duplicate completedOrder() calls
// //  2. toPay cached in state — no repeated HTTP calls during build
// //  3. Cleaner error propagation with typed exceptions
// //  4. markOrderAsCompleted() called before Get.back() to prevent
// //     race condition where HomeScreen re-fetches and re-displays
// //     the just-completed order
// // ============================================================
//
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:get/get.dart';
// import 'package:flutter/material.dart';
//
// import 'package:jippydriver_driver/app/home_screen/controller/home_controller.dart';
// import 'package:jippydriver_driver/app/wallet_screen/controller/wallet_controller.dart';
// import 'package:jippydriver_driver/constant/constant.dart';
// import 'package:jippydriver_driver/constant/send_notification.dart';
// import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
// import 'package:jippydriver_driver/models/order_model.dart';
// import 'package:jippydriver_driver/models/user_model.dart';
// import 'package:jippydriver_driver/services/audio_player_service.dart';
// import 'package:jippydriver_driver/utils/app_logger.dart';
// import 'package:jippydriver_driver/utils/fire_store_utils.dart';
//
// class DeliverOrderController extends GetxController {
//
//   // ── State ───────────────────────────────────────────────────────────
//   final RxBool isLoading          = true.obs;
//   final RxBool conformPickup      = false.obs;
//   final RxBool isCompletingOrder  = false.obs;
//   final Rx<OrderModel> orderModel = OrderModel().obs;
//   final RxInt totalQuantity       = 0.obs;
//
//   // ── Cached toPay (fetched once in onInit) ──────────────────────────
//   double? _cachedToPay;
//   bool    _toPayFetched = false;
//
//   // ── Sub-controllers ─────────────────────────────────────────────────
//   final WalletController walletController = Get.put(WalletController());
//
//   @override
//   void onInit() {
//     AppLogger.log('DeliverOrderController onInit()', tag: 'Controller');
//     _loadArguments();
//     super.onInit();
//   }
//
//   @override
//   void onClose() {
//     AppLogger.log('DeliverOrderController onClose()', tag: 'Controller');
//     super.onClose();
//   }
//
//   // ══════════════════════════════════════════════════════════════════════
//   //  Init
//   // ══════════════════════════════════════════════════════════════════════
//
//   void _loadArguments() {
//     final args = Get.arguments;
//
//     if (args != null) {
//       orderModel.value = args['orderModel'];
//
//       totalQuantity.value = 0; // reset
//
//       for (final p in orderModel.value.products ?? []) {
//         final int qty = (p.quantity ?? 0).toInt(); // ✅ force int
//         totalQuantity.value += qty;
//       }
//     }
//     isLoading.value = false;
//     // Pre-fetch toPay in background so it's ready when completedOrder() is called
//     _prefetchToPay();
//   }
//
//   Future<void> _prefetchToPay() async {
//     if (_toPayFetched) return;
//     try {
//       _cachedToPay = await _fetchToPay(orderModel.value.id ?? '');
//       _toPayFetched = true;
//       AppLogger.log('Pre-fetched toPay: $_cachedToPay', tag: 'ToPay');
//     } catch (e) {
//       AppLogger.log('Pre-fetch toPay error: $e', tag: 'ToPay');
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════
//   //  Checkbox toggle
//   // ══════════════════════════════════════════════════════════════════════
//
//   void confirmPickupFunction() => conformPickup.value = !conformPickup.value;
//
//   // ══════════════════════════════════════════════════════════════════════
//   //  Complete order
//   // ══════════════════════════════════════════════════════════════════════
//
//   Future<void> completedOrder() async {
//     // Duplicate-call guard
//     if (isCompletingOrder.value) {
//       AppLogger.log('completedOrder() already running — ignoring duplicate', tag: 'Guard');
//       return;
//     }
//     isCompletingOrder.value = true;
//     ShowToastDialog.showLoader('Please wait'.tr);
//
//     try {
//       // 1. Validate order data
//       if (orderModel.value.driverID == null) {
//         orderModel.value.driverID = Constant.userModel?.id;
//       }
//
//       _validateOrderFields();
//
//       // 2. Resolve toPay (use pre-fetched value or fetch now)
//       double? toPay = _cachedToPay;
//       if (toPay == null) {
//         toPay = await _fetchToPay(orderModel.value.id ?? '');
//       }
//
//       // Fallback: use existing toPay field from order model
//       if (toPay == null && (orderModel.value.toPay?.isNotEmpty ?? false)) {
//         toPay = double.tryParse(orderModel.value.toPay!);
//       }
//
//       if (toPay == null) {
//         throw Exception('ToPay amount could not be determined for order ${orderModel.value.id}');
//       }
//
//       orderModel.value.toPay  = toPay.toString();
//       orderModel.value.status = Constant.orderCompleted;
//
//       // 3. Audio
//       await AudioPlayerService.playSound(false);
//
//       // 4. Wallet + delivery amount update (parallel)
//       await FireStoreUtils.updateWallateAmount(orderModel.value);
//
//       // 5. Save order to Firestore
//       await FireStoreUtils.setOrder(orderModel.value);
//
//       // 6. Bonus + wallet save (non-blocking)
//       _deliveryAmountBonusAmount();
//
//       // 7. Remove order from other drivers
//       await FireStoreUtils.removeOrderFromOtherDrivers(
//         orderId: orderModel.value.id ?? '',
//         assignedDriverId: orderModel.value.driverID!,
//       );
//
//       // 8. Update driver user — fetch latest first to avoid overwriting
//       //    fields modified by wallet/delivery APIs
//       final latest = await FireStoreUtils.getUserProfile(Constant.userModel?.id ?? '');
//       if (latest != null) {
//         latest.orderRequestData?.remove(orderModel.value.id);
//         latest.inProgressOrderID?.remove(orderModel.value.id);
//         await FireStoreUtils.updateUserWithoutWalletDelivery(latest);
//
//         // Refresh Constant.userModel with latest wallet values
//         final refreshed = await FireStoreUtils.getUserProfile(Constant.userModel?.id ?? '');
//         if (refreshed != null) Constant.userModel = refreshed;
//       } else {
//         // Fallback
//         Constant.userModel?.orderRequestData?.remove(orderModel.value.id);
//         Constant.userModel?.inProgressOrderID?.remove(orderModel.value.id);
//         await FireStoreUtils.updateUserWithoutWalletDelivery(Constant.userModel!);
//       }
//
//       // 9. Referral check
//       final isFirst = await FireStoreUtils.getFirestOrderOrNOt(orderModel.value);
//       if (isFirst == true) {
//         await FireStoreUtils.updateReferralAmount(orderModel.value);
//       }
//
//       // 10. Notify customer
//       if (orderModel.value.author?.fcmToken != null) {
//         await SendNotification.sendFcmMessage(
//           Constant.driverCompleted,
//           orderModel.value.author!.fcmToken.toString(),
//           {},
//         );
//       }
//
//       ShowToastDialog.closeLoader();
//       isCompletingOrder.value = false;
//
//       // 11. Mark completed in HomeController BEFORE Get.back() to prevent re-display
//       try {
//         Get.find<HomeController>().markOrderAsCompleted(orderModel.value.id);
//       } catch (_) {}
//
//       // 12. Return order ID so HomeScreen can track it even if currentOrder was cleared
//       Get.back(result: orderModel.value.id ?? true);
//
//     } on _OrderValidationException catch (e) {
//       ShowToastDialog.closeLoader();
//       ShowToastDialog.showToast(e.message);
//       isCompletingOrder.value = false;
//     } catch (e) {
//       AppLogger.log('completedOrder error: $e', tag: 'Error');
//       ShowToastDialog.closeLoader();
//       ShowToastDialog.showToast('Failed to complete order. Please try again.');
//       isCompletingOrder.value = false;
//     }
//   }
//
//   void _validateOrderFields() {
//     if (orderModel.value.driverID == null) {
//       throw _OrderValidationException('Driver ID is missing');
//     }
//     if (orderModel.value.paymentMethod == null) {
//       throw _OrderValidationException('Payment method is missing');
//     }
//     if (orderModel.value.deliveryCharge == null) {
//       throw _OrderValidationException('Delivery charge is missing');
//     }
//     if (orderModel.value.tipAmount == null) {
//       throw _OrderValidationException('Tip amount is missing');
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════
//   //  Bonus logic
//   // ══════════════════════════════════════════════════════════════════════
//
//   void _deliveryAmountBonusAmount() async {
//     try {
//       final count   = await _getTodayOrderCount();
//       final docData = await _getZoneBonus(Constant.userModel?.zoneId ?? '');
//
//       // Get stored calculated charge from order
//       final order = await FireStoreUtils.getOrderById(orderModel.value.id ?? '');
//       final total = double.tryParse(
//           order?.calculatedCharges?['totalCalculatedCharge']?.toString() ?? '0') ?? 0.0;
//
//       if (docData != null) {
//         final required = int.tryParse(docData['requiredOrdersForBonus'].toString()) ?? 0;
//         final bonus    = int.tryParse(docData['bonusAmount'].toString()) ?? 0;
//
//         if (count == required) {
//           walletController.driverRecordAmountController.value.text =
//               (total + bonus).toStringAsFixed(2);
//           walletController.addWalletBonusSave(
//             bonus: true,
//             zoneId: Constant.userModel?.zoneId ?? '',
//             bonusAmount: bonus,
//             orderModel: orderModel.value,
//           );
//           Get.dialog(AlertDialog(
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             title: const Text('🎉 Congratulations!'),
//             content: Text('You received a ₹$bonus bonus for completing $required orders today!'),
//             actions: [TextButton(onPressed: Get.back, child: const Text('OK'))],
//           ));
//         } else {
//           walletController.driverRecordAmountController.value.text = total.toString();
//           walletController.addWalletBonusSave(
//             bonus: false,
//             zoneId: Constant.userModel?.zoneId ?? '',
//             orderModel: orderModel.value,
//           );
//         }
//       } else {
//         walletController.driverRecordAmountController.value.text = total.toString();
//         walletController.addWalletBonusSave(
//           bonus: false,
//           zoneId: Constant.userModel?.zoneId ?? '',
//           orderModel: orderModel.value,
//         );
//       }
//     } catch (e) {
//       AppLogger.log('_deliveryAmountBonusAmount error: $e', tag: 'Bonus');
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════
//   //  API helpers
//   // ══════════════════════════════════════════════════════════════════════
//
//   Future<double?> _fetchToPay(String orderId) async {
//     if (orderId.isEmpty) return null;
//     try {
//       final res = await http.get(
//         Uri.parse('${Constant.baseUrl}mobile/orders/$orderId/billing/to-pay'),
//       ).timeout(const Duration(seconds: 10));
//
//       if (res.statusCode == 200) {
//         final body = res.body.trim();
//         if (body.startsWith('<')) return null; // HTML error page
//         final j = jsonDecode(body);
//         if (j['success'] == true && j['data']?['found'] == true) {
//           return (j['data']['to_pay'] as num).toDouble();
//         }
//       }
//     } catch (e) {
//       AppLogger.log('_fetchToPay error: $e', tag: 'ToPay');
//     }
//     return null;
//   }
//
//   Future<int> _getTodayOrderCount() async {
//     try {
//       final id  = Constant.userModel?.id;
//       if (id == null) return 0;
//       final res = await http.get(
//         Uri.parse('${Constant.baseUrl}orders/completed/today/$id'),
//       ).timeout(const Duration(seconds: 8));
//       if (res.statusCode == 200) {
//         final j = jsonDecode(res.body);
//         if (j['success'] == true) return j['count'] ?? 0;
//       }
//     } catch (_) {}
//     return 0;
//   }
//
//   Future<Map<String, dynamic>?> _getZoneBonus(String zoneId) async {
//     if (zoneId.isEmpty) return null;
//     try {
//       final res = await http.post(
//         Uri.parse('${Constant.baseUrl}zone/bonus/byZoneId'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'zone_id': zoneId}),
//       ).timeout(const Duration(seconds: 8));
//       if (res.statusCode == 200) {
//         final j = jsonDecode(res.body);
//         if (j['success'] == true && j['data'] != null) return j['data'];
//       }
//     } catch (_) {}
//     return null;
//   }
// }
//
// // ---------------------------------------------------------------------------
// class _OrderValidationException implements Exception {
//   final String message;
//   const _OrderValidationException(this.message);
// }