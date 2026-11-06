import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/app/home_screen/screens/pickup_order_screen/controller/pickup_order_controller.dart';
import 'package:jippydriver_driver/models/cart_product_model.dart';
import 'package:jippydriver_driver/services/driver_delivery_location_service.dart';
import 'package:jippydriver_driver/services/order_workflow_service.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/themes/responsive.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:jippydriver_driver/utils/network_image_widget.dart';
import 'package:jippydriver_driver/widget/my_separator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class PickupOrderScreen extends StatelessWidget {
  const PickupOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppLogger.log('PickupOrderScreen build() called', tag: 'Screen');
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<PickupOrderController>(
        init: PickupOrderController(),
        global: false,
        builder: (controller) {
          return controller.isLoading.value
              ? Constant.loader()
              : Scaffold(
                  appBar: AppBar(
                    backgroundColor: themeChange.getThem()
                        ? AppThemeData.grey900
                        : AppThemeData.grey50,
                    centerTitle: false,
                    titleSpacing: 0,
                    iconTheme: const IconThemeData(
                        color: AppThemeData.grey900, size: 20),
                    title: Text(
                      Constant.orderId(
                              orderId:
                                  controller.orderModel.value.id.toString())
                          .tr,
                      style: TextStyle(
                          color: themeChange.getThem()
                              ? AppThemeData.grey50
                              : AppThemeData.grey900,
                          fontSize: 18,
                          fontFamily: AppThemeData.medium),
                    ),
                  ),
                  body: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                              child: Image.asset(
                                  "assets/images/order_pickup.gif")),
                          Text(
                            "Order Ready to pickup".tr,
                            style: TextStyle(
                                color: themeChange.getThem()
                                    ? AppThemeData.grey50
                                    : AppThemeData.grey900,
                                fontSize: 22,
                                fontFamily: AppThemeData.regular),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Text(
                            "Your order has been ready pickup the order and deliver to the customer’s locations."
                                .tr,
                            style: TextStyle(
                                color: themeChange.getThem()
                                    ? AppThemeData.grey50
                                    : AppThemeData.grey500,
                                fontFamily: AppThemeData.regular),
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          Text(
                            "Item and Deliver to the".tr,
                            style: TextStyle(
                                color: themeChange.getThem()
                                    ? AppThemeData.grey100
                                    : AppThemeData.grey800,
                                fontSize: 16,
                                fontFamily: AppThemeData.medium),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Container(
                            decoration: ShapeDecoration(
                              color: themeChange.getThem()
                                  ? AppThemeData.grey900
                                  : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: controller
                                        .orderModel.value.products?.length ?? 0,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemBuilder: (context, index) {
                                      if (controller.orderModel.value.products == null || 
                                          index >= controller.orderModel.value.products!.length) {
                                        return Container();
                                      }
                                      CartProductModel product = controller
                                          .orderModel.value.products![index];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 5),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                          Radius.circular(14)),
                                                  child: Stack(
                                                    children: [
                                                      NetworkImageWidget(
                                                        imageUrl: product.photo
                                                            .toString(),
                                                        height:
                                                            Responsive.height(
                                                                8, context),
                                                        width: Responsive.width(
                                                            16, context),
                                                        fit: BoxFit.cover,
                                                      ),
                                                      Container(
                                                        height:
                                                            Responsive.height(
                                                                8, context),
                                                        width: Responsive.width(
                                                            16, context),
                                                        decoration:
                                                            BoxDecoration(
                                                          gradient:
                                                              LinearGradient(
                                                            begin:
                                                                const Alignment(
                                                                    -0.00,
                                                                    -1.00),
                                                            end:
                                                                const Alignment(
                                                                    0, 1),
                                                            colors: [
                                                              Colors.black
                                                                  .withOpacity(
                                                                      0),
                                                              const Color(
                                                                  0xFF111827)
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 10,
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              "${product.name}",
                                                              textAlign:
                                                                  TextAlign
                                                                      .start,
                                                              style: TextStyle(
                                                                fontFamily:
                                                                    AppThemeData
                                                                        .regular,
                                                                color: themeChange
                                                                        .getThem()
                                                                    ? AppThemeData
                                                                        .grey50
                                                                    : AppThemeData
                                                                        .grey900,
                                                                fontSize: 16,
                                                              ),
                                                            ),
                                                          ),
                                                          Text(
                                                            "x ${product.quantity}",
                                                            textAlign:
                                                                TextAlign.start,
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  AppThemeData
                                                                      .regular,
                                                              color: themeChange
                                                                      .getThem()
                                                                  ? AppThemeData
                                                                      .grey50
                                                                  : AppThemeData
                                                                      .grey900,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            product.variantInfo == null ||
                                                    product.variantInfo!
                                                        .variantOptions!.isEmpty
                                                ? Container()
                                                : Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 5,
                                                        vertical: 10),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "Variants".tr,
                                                          textAlign:
                                                              TextAlign.start,
                                                          style: TextStyle(
                                                            fontFamily:
                                                                AppThemeData
                                                                    .semiBold,
                                                            color: themeChange
                                                                    .getThem()
                                                                ? AppThemeData
                                                                    .grey300
                                                                : AppThemeData
                                                                    .grey600,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 5,
                                                        ),
                                                        Wrap(
                                                          spacing: 6.0,
                                                          runSpacing: 6.0,
                                                          children: [
                                                            Container(
                                                              decoration: ShapeDecoration(
                                                                color: themeChange.getThem()
                                                                    ? AppThemeData.grey800
                                                                    : AppThemeData.grey100,
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius: BorderRadius.circular(8),
                                                                ),
                                                              ),
                                                              child: Padding(
                                                                padding: const EdgeInsets.symmetric(
                                                                  horizontal: 16,
                                                                  vertical: 5,
                                                                ),
                                                                child: Text(
                                                                  "${product.variantInfo!.variantOptions!.values.first}",
                                                                  textAlign: TextAlign.start,
                                                                  style: TextStyle(
                                                                    fontFamily: AppThemeData.medium,
                                                                    color: themeChange.getThem()
                                                                        ? AppThemeData.grey500
                                                                        : AppThemeData.grey400,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        )                                                      ],
                                                    ),
                                                  ),
                                            product.extras == null ||
                                                    product.extras!.isEmpty
                                                ? const SizedBox()
                                                : Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Text(
                                                        "Addons".tr,
                                                        textAlign:
                                                            TextAlign.start,
                                                        style: TextStyle(
                                                          fontFamily:
                                                              AppThemeData
                                                                  .semiBold,
                                                          color: themeChange
                                                                  .getThem()
                                                              ? AppThemeData
                                                                  .grey300
                                                              : AppThemeData
                                                                  .grey600,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      Wrap(
                                                        spacing: 6.0,
                                                        runSpacing: 6.0,
                                                        children: List.generate(
                                                          product
                                                              .extras!.length,
                                                          (i) {
                                                            return Container(
                                                              decoration:
                                                                  ShapeDecoration(
                                                                color: themeChange.getThem()
                                                                    ? AppThemeData
                                                                        .grey800
                                                                    : AppThemeData
                                                                        .grey100,
                                                                shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            8)),
                                                              ),
                                                              child: Padding(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        16,
                                                                    vertical:
                                                                        5),
                                                                child: Text(
                                                                  product
                                                                      .extras![
                                                                          i]
                                                                      .toString(),
                                                                  textAlign:
                                                                      TextAlign
                                                                          .start,
                                                                  style:
                                                                      TextStyle(
                                                                    fontFamily:
                                                                        AppThemeData
                                                                            .medium,
                                                                    color: themeChange.getThem()
                                                                        ? AppThemeData
                                                                            .grey500
                                                                        : AppThemeData
                                                                            .grey400,
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ).toList(),
                                                      ),
                                                    ],
                                                  ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  InkWell(
                                    onTap: (){
                                      controller.confirmPickupFunction();
                                    },
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          side: const BorderSide(
                                            color: AppThemeData.success400,
                                            width: 1.5,
                                          ),
                                          value: controller.conformPickup.value,
                                          activeColor: AppThemeData.success400,
                                          focusColor: AppThemeData.success400,
                                          onChanged: (value) {
                                            if (value != null) {
                                              controller.conformPickup.value =
                                                  value;
                                            }
                                          },
                                        ),
                                        Text(
                                          "Confirm Pickup".tr,
                                          style: TextStyle(
                                              color: themeChange.getThem()
                                                  ? AppThemeData.success400
                                                  : AppThemeData.success400,
                                              fontSize: 16,
                                              fontFamily: AppThemeData.medium),
                                        ),
                                      ],

                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: MySeparator(
                                        color: themeChange.getThem()
                                            ? AppThemeData.grey700
                                            : AppThemeData.grey200),
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Pickup Instructions: ".tr,
                                        style: TextStyle(
                                          fontFamily: AppThemeData.medium,
                                          fontSize: 14,
                                          color: themeChange.getThem()
                                              ? AppThemeData.grey400
                                              : AppThemeData.grey600,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          "${controller.orderModel.value.notes ?? ''}",
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                            fontFamily: AppThemeData.regular,
                                            color: themeChange.getThem()
                                                ? AppThemeData.grey50
                                                : AppThemeData.grey900,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: MySeparator(
                                        color: themeChange.getThem()
                                            ? AppThemeData.grey700
                                            : AppThemeData.grey200),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        decoration: ShapeDecoration(
                                          color: AppThemeData.driverApp50,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(120),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: SvgPicture.asset(
                                            "assets/icons/ic_location.svg",
                                            colorFilter: ColorFilter.mode(
                                                AppThemeData.driverApp300,
                                                BlendMode.srcIn),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Deliver to the".tr,
                                              textAlign: TextAlign.start,
                                              style: TextStyle(
                                                fontFamily:
                                                    AppThemeData.semiBold,
                                                fontSize: 16,
                                                color: themeChange.getThem()
                                                    ? AppThemeData.grey50
                                                    : AppThemeData.grey900,
                                              ),
                                            ),
                                            Text(
                                              controller
                                                  .orderModel.value.address!
                                                  .getFullAddress(),
                                              textAlign: TextAlign.start,
                                              style: TextStyle(
                                                fontFamily: AppThemeData.medium,
                                                fontSize: 14,
                                                color: themeChange.getThem()
                                                    ? AppThemeData.grey300
                                                    : AppThemeData.grey600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  bottomNavigationBar: InkWell(
                    onTap: () async {
                      if (controller.conformPickup.value == false) {
                        ShowToastDialog.showToast("Conform pickup order".tr);
                      } else {
                        ShowToastDialog.showLoader("Please wait".tr);
                        // Update the order status (DRIVER_PICKS_UP) through the
                        // new co/updateOrderStatus endpoint (with legacy
                        // acceptOrRejectOrderByDriver as a fallback).
                        final orderId = controller.orderModel.value.id ?? '';
                        if (orderId.isNotEmpty) {
                          final ok = await OrderWorkflowService.updateDriverWorkflowStatus(
                            orderId: orderId,
                            orderStatus: Constant.backendOrderStatusDriverPickedUp,
                            driverModel: Constant.userModel,
                            outletId:
                                controller.orderModel.value.vendorID?.toString(),
                          );
                          if (ok == false) {
                            ShowToastDialog.closeLoader();
                            ShowToastDialog.showToast(
                              "Failed to update order status. Please try again.".tr,
                            );
                            return;
                          }

                          // The order is now picked up. Start sending the
                          // driver's location every 10 seconds until delivery.
                          DriverDeliveryLocationService.instance.start(
                            orderId: orderId,
                            driverId: Constant.userModel?.id?.toString(),
                          );

                          // if (ok == true) {
                          //   // Update local model for UI consistency
                          //   controller.orderModel.value.status = Constant.orderInTransit;
                          //
                          //   // Notify customer after status update succeeds.
                          //   final order = controller.orderModel.value;
                          //   String token =
                          //       order.author?.fcmToken?.toString().trim() ?? '';
                          //   final customerId = order.authorID?.toString() ??
                          //       order.author?.id?.toString() ??
                          //       order.author?.firebaseId?.toString() ??
                          //       '';
                          //   if (customerId.isNotEmpty) {
                          //     // Always fetch fresh token by customerId.
                          //     final customer =
                          //         await FireStoreUtils.getUserProfile(customerId);
                          //     token = customer?.fcmToken?.toString().trim() ?? token;
                          //   }
                          //
                          //   if (token.isNotEmpty) {
                          //     print('[FCM][Pickup] orderId=$orderId '
                          //         'tokenPreview=${token.length > 10 ? token.substring(0, 10) + '...' : token}');
                          //     final sent = await SendNotification.sendFcmMessage(
                          //       Constant.orderInTransit,
                          //       token,
                          //       {
                          //         'order_id': orderId,
                          //         'status': Constant.orderInTransit,
                          //       },
                          //     );
                          //     print('[FCM][Pickup] send result: $sent');
                          //     if (sent != true) {
                          //       ShowToastDialog.showToast(
                          //         'Failed to send pickup notification'.tr,
                          //       );
                          //     }
                          //   } else {
                          //     ShowToastDialog.showToast(
                          //       'Customer token missing'.tr,
                          //     );
                          //   }
                          // }
                        }
                        ShowToastDialog.closeLoader();
                        Get.back(result: true);
                      }
                    },
                    child: SafeArea(
                      child: Container(
                        color: AppThemeData.driverApp300,
                        width: Responsive.width(100, context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            "Picked Order".tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: themeChange.getThem()
                                  ? AppThemeData.grey50
                                  : AppThemeData.grey50,
                              fontSize: 16,
                              fontFamily: AppThemeData.medium,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
        });
  }
}
