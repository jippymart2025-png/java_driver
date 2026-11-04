import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:timelines_plus/timelines_plus.dart';

import 'package:jippydriver_driver/app/dash_board_screen/controller/dash_board_controller.dart';
import 'package:jippydriver_driver/app/home_screen/home_screen.dart';
import 'package:jippydriver_driver/app/home_screen/screens/home_screen_multiple_order/controller/home_screen_multiple_order_controller.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/models/driver_delivery_charge_model.dart';
import 'package:jippydriver_driver/models/order_model.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/themes/round_button_fill.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:jippydriver_driver/widget/my_separator.dart';

class HomeScreenMultipleOrder extends StatelessWidget {
  const HomeScreenMultipleOrder({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return GetX<HomeScreenMultipleOrderController>(
      init: HomeScreenMultipleOrderController(),
      builder: (controller) {
        return Scaffold(
          body: controller.isLoading.value
              ? Constant.loader()
              : Constant.isDriverVerification == true &&
                      Constant.userModel!.isDocumentVerify == false
                  ? _VerificationPending(themeChange: themeChange)
                  : _buildContent(context, themeChange, controller),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    DarkThemeProvider themeChange,
    HomeScreenMultipleOrderController controller,
  ) {
    final isIndependentDriver =
        Constant.userModel?.vendorID?.isEmpty == true;

    return Column(
      children: [
        if (isIndependentDriver &&
            (double.tryParse(
                        controller.driverModel.value.walletAmount.toString()) ??
                    0.0) <
                (double.tryParse(Constant.minimumDepositToRideAccept) ?? 0.0))
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "${'You have to minimum'.tr} ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} ${'wallet amount to receiving Order'.tr}",
              style: TextStyle(
                color: themeChange.getThem()
                    ? AppThemeData.grey50
                    : AppThemeData.grey900,
                fontSize: 14,
                fontFamily: AppThemeData.semiBold,
              ),
            ),
          ),
        Expanded(
          child: DefaultTabController(
            length: isIndependentDriver ? 1 : 2,
            child: Column(
              children: [
                Container(
                  color: themeChange.getThem()
                      ? AppThemeData.grey900
                      : AppThemeData.grey50,
                  child: TabBar(
                    onTap: (value) => controller.selectedTabIndex.value = value,
                    labelStyle: const TextStyle(
                      fontFamily: AppThemeData.semiBold,
                    ),
                    labelColor: AppThemeData.driverApp300,
                    unselectedLabelStyle: const TextStyle(
                      fontFamily: AppThemeData.medium,
                    ),
                    unselectedLabelColor: themeChange.getThem()
                        ? AppThemeData.grey500
                        : AppThemeData.grey400,
                    indicatorColor: AppThemeData.driverApp300,
                    isScrollable: false,
                    dividerColor: Colors.transparent,
                    tabs: [
                      if (isIndependentDriver) Tab(text: "New".tr),
                      Tab(text: "Active".tr),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: TabBarView(
                      children: [
                        if (isIndependentDriver)
                          _OrderList(
                            controller: controller,
                            themeChange: themeChange,
                            orderIds: controller.newOrder,
                            isNewOrder: true,
                            emptyMessage: "New Order not found.".tr,
                          ),
                        _OrderList(
                          controller: controller,
                          themeChange: themeChange,
                          orderIds: controller.activeOrder,
                          isNewOrder: false,
                          emptyMessage: "Active order not found.".tr,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
//  List
// =============================================================================

class _OrderList extends StatelessWidget {
  final HomeScreenMultipleOrderController controller;
  final DarkThemeProvider themeChange;
  final List<dynamic> orderIds;
  final bool isNewOrder;
  final String emptyMessage;

  const _OrderList({
    required this.controller,
    required this.themeChange,
    required this.orderIds,
    required this.isNewOrder,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (orderIds.isEmpty) {
      return Constant.showEmptyView(message: emptyMessage);
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      scrollDirection: Axis.vertical,
      itemCount: orderIds.length,
      itemBuilder: (context, index) {
        final rawId = orderIds[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: FutureBuilder<
              ({OrderModel? order, DriverDeliveryChargeModel? details})>(
            future: controller.fetchOrderBundle(rawId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _loadingCard(themeChange);
              }
              if (snapshot.hasError) {
                return _errorCard(themeChange, '${snapshot.error}');
              }

              final bundle = snapshot.data;
              final order = bundle?.order;
              final orderId = order?.id?.toString() ?? rawId.toString();
              final details = bundle?.details ?? controller.chargesFor(orderId);

              if (order == null && details == null) {
                return const SizedBox.shrink();
              }

              return _OrderBundleCard(
                controller: controller,
                themeChange: themeChange,
                order: order,
                details: details,
                isNewOrder: isNewOrder,
              );
            },
          ),
        );
      },
    );
  }

  Widget _loadingCard(DarkThemeProvider themeChange) => Container(
        height: 120,
        decoration: ShapeDecoration(
          color: themeChange.getThem()
              ? AppThemeData.grey900
              : AppThemeData.grey50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );

  Widget _errorCard(DarkThemeProvider themeChange, String error) => Container(
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          color: themeChange.getThem()
              ? AppThemeData.grey900
              : AppThemeData.grey50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text('Error: $error'),
      );
}

// =============================================================================
//  Card
// =============================================================================

class _OrderBundleCard extends StatelessWidget {
  final HomeScreenMultipleOrderController controller;
  final DarkThemeProvider themeChange;
  final OrderModel? order;
  final DriverDeliveryChargeModel? details;
  final bool isNewOrder;

  const _OrderBundleCard({
    required this.controller,
    required this.themeChange,
    required this.order,
    required this.details,
    required this.isNewOrder,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
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
            _TimelineSection(
              themeChange: themeChange,
              order: order,
              details: details,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: MySeparator(
                color: themeChange.getThem()
                    ? AppThemeData.grey700
                    : AppThemeData.grey200,
              ),
            ),
            _DistanceAndCharges(
              themeChange: themeChange,
              order: order,
              details: details,
              fallbackDistanceKm: _fallbackDistanceKm(),
            ),
            const SizedBox(height: 5),
            _TipRow(
              themeChange: themeChange,
              tip: _tipAmount(),
            ),
            const SizedBox(height: 10),
            if (isNewOrder && order != null) ...[
              Row(
                children: [
                  Expanded(
                    child: RoundedButtonFill(
                      title: "Reject".tr,
                      width: 24,
                      height: 5.5,
                      borderRadius: 10,
                      color: AppThemeData.danger300,
                      textColor: AppThemeData.grey50,
                      onPress: () {
                        AppLogger.log(
                          'User clicked Reject Order button',
                          tag: 'UserAction',
                        );
                        controller.rejectOrder(order!);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RoundedButtonFill(
                      title: "Accept".tr,
                      width: 24,
                      height: 5.5,
                      borderRadius: 10,
                      color: AppThemeData.success400,
                      textColor: AppThemeData.grey50,
                      onPress: () {
                        AppLogger.log(
                          'User clicked Accept Order button',
                          tag: 'UserAction',
                        );
                        controller.acceptOrder(order!);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );

    if (order != null) {
      return InkWell(
        onTap: () {
          Get.to(
            const HomeScreen(isAppBarShow: true),
            arguments: {"orderModel": order},
          );
        },
        child: card,
      );
    }
    return card;
  }

  double _fallbackDistanceKm() {
    final vLat = order?.vendor?.latitudeValue ?? order?.vendor?.latitude;
    final vLng = order?.vendor?.longitudeValue ?? order?.vendor?.longitude;
    final cLat = order?.address?.location?.latitude;
    final cLng = order?.address?.location?.longitude;
    if (vLat != null &&
        vLng != null &&
        cLat != null &&
        cLng != null) {
      return Geolocator.distanceBetween(vLat, vLng, cLat, cLng) / 1000;
    }
    return 0.0;
  }

  double _tipAmount() {
    if (details != null && details!.tipAmount > 0) {
      return details!.tipAmount;
    }
    return double.tryParse(order?.tipAmount?.toString() ?? '0') ?? 0.0;
  }
}

// =============================================================================
//  Timeline
// =============================================================================

class _TimelineSection extends StatelessWidget {
  final DarkThemeProvider themeChange;
  final OrderModel? order;
  final DriverDeliveryChargeModel? details;

  const _TimelineSection({
    required this.themeChange,
    required this.order,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final outletTitle = details?.outletName.trim().isNotEmpty == true
        ? details!.outletName.trim()
        : (order?.vendor?.title ?? 'Restaurant');
    final outletAddress = details?.outletAddress.trim().isNotEmpty == true
        ? details!.outletAddress.trim()
        : (order?.vendor?.location ?? 'Location not available');
    final customerName = details?.customerName.trim() ?? '';
    final customerTitle =
        customerName.isNotEmpty ? customerName : 'Deliver to the'.tr;
    final customerAddress =
        details?.customerAddress.trim().isNotEmpty == true
            ? details!.customerAddress.trim()
            : (order?.address?.getFullAddress() ?? 'Address not available');

    return Timeline.tileBuilder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      theme: TimelineThemeData(nodePosition: 0),
      builder: TimelineTileBuilder.connected(
        contentsAlign: ContentsAlign.basic,
        indicatorBuilder: (context, index) {
          return index == 0
              ? _circleIcon(
                  'assets/icons/ic_building.svg',
                  AppThemeData.primary50,
                  AppThemeData.primary300,
                )
              : _circleIcon(
                  'assets/icons/ic_location.svg',
                  AppThemeData.driverApp50,
                  AppThemeData.driverApp300,
                );
        },
        connectorBuilder: (context, index, connectorType) {
          return const DashedLineConnector(
            color: AppThemeData.grey300,
            gap: 3,
          );
        },
        contentsBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: index == 0
                ? _addressColumn(outletTitle, outletAddress)
                : _addressColumn(customerTitle, customerAddress),
          );
        },
        itemCount: 2,
      ),
    );
  }

  Widget _addressColumn(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: TextAlign.start,
          style: TextStyle(
            fontFamily: AppThemeData.semiBold,
            fontSize: 16,
            color: themeChange.getThem()
                ? AppThemeData.grey50
                : AppThemeData.grey900,
          ),
        ),
        Text(
          subtitle,
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
    );
  }

  Widget _circleIcon(String asset, Color background, Color iconColor) {
    return Container(
      decoration: ShapeDecoration(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(120),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SvgPicture.asset(
          asset,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
      ),
    );
  }
}

// =============================================================================
//  Distance / charges
// =============================================================================

class _DistanceAndCharges extends StatelessWidget {
  final DarkThemeProvider themeChange;
  final OrderModel? order;
  final DriverDeliveryChargeModel? details;
  final double fallbackDistanceKm;

  const _DistanceAndCharges({
    required this.themeChange,
    required this.order,
    required this.details,
    required this.fallbackDistanceKm,
  });

  @override
  Widget build(BuildContext context) {
    if (details != null && details!.hasChargeData) {
      return _apiDetails(details!);
    }
    return _fallbackDetails();
  }

  Widget _apiDetails(DriverDeliveryChargeModel d) {
    return Column(
      children: [
        _row(
          "Pickup Distance".tr,
          '${d.pickupDistanceKm.toStringAsFixed(2)} ${Constant.distanceType}',
        ),
        _row(
          "Delivery Distance".tr,
          '${d.deliveryDistanceKm.toStringAsFixed(2)} ${Constant.distanceType}',
        ),
        if (d.pickupCharge > 0)
          _row(
            "Pickup Charge".tr,
            Constant.amountShow(amount: d.pickupCharge.toString()),
          ),
        if (d.deliveryCharge > 0)
          _row(
            "Delivery Charge".tr,
            Constant.amountShow(amount: d.deliveryCharge.toString()),
          ),
        if (d.taxAmount > 0)
          _row(
            "Tax".tr,
            Constant.amountShow(amount: d.taxAmount.toString()),
          ),
        if (d.orderTotalAmount > 0)
          _row(
            "Order Total".tr,
            Constant.amountShow(amount: d.orderTotalAmount.toString()),
          ),
        _row("COD Available".tr, d.codAvailable ? "Yes".tr : "No".tr),
        const SizedBox(height: 6),
        _totalRow(
          "Total Driver Charge".tr,
          Constant.amountShow(amount: d.effectiveDriverCharge.toString()),
        ),
      ],
    );
  }

  Widget _fallbackDetails() {
    final deliveryCharge = order?.deliveryCharge?.trim() ?? '';
    final hasDeliveryCharge = deliveryCharge.isNotEmpty &&
        (double.tryParse(deliveryCharge) ?? 0) > 0;
    return Column(
      children: [
        _row(
          "Trip Distance".tr,
          '${fallbackDistanceKm.toStringAsFixed(2)} ${Constant.distanceType}',
        ),
        if (hasDeliveryCharge)
          _row(
            "Delivery Charge".tr,
            Constant.amountShow(amount: deliveryCharge),
          ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontFamily: AppThemeData.regular,
                  color: themeChange.getThem()
                      ? AppThemeData.grey300
                      : AppThemeData.grey600,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              value,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontFamily: AppThemeData.semiBold,
                color: themeChange.getThem()
                    ? AppThemeData.grey50
                    : AppThemeData.grey900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );

  Widget _totalRow(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppThemeData.primary50.withOpacity(0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppThemeData.primary200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppThemeData.semiBold,
                  color: themeChange.getThem()
                      ? AppThemeData.grey50
                      : AppThemeData.grey900,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontFamily: AppThemeData.bold,
                color: AppThemeData.primary500,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
}

class _TipRow extends StatelessWidget {
  final DarkThemeProvider themeChange;
  final double tip;

  const _TipRow({required this.themeChange, required this.tip});

  @override
  Widget build(BuildContext context) {
    if (tip <= 0) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            "Tips".tr,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontFamily: AppThemeData.regular,
              color: themeChange.getThem()
                  ? AppThemeData.grey300
                  : AppThemeData.grey600,
              fontSize: 15,
            ),
          ),
        ),
        Text(
          Constant.amountShow(amount: tip.toString()),
          textAlign: TextAlign.start,
          style: TextStyle(
            fontFamily: AppThemeData.semiBold,
            color: themeChange.getThem()
                ? AppThemeData.grey50
                : AppThemeData.grey900,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
//  Verification pending
// =============================================================================

class _VerificationPending extends StatelessWidget {
  final DarkThemeProvider themeChange;

  const _VerificationPending({required this.themeChange});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: ShapeDecoration(
              color: themeChange.getThem()
                  ? AppThemeData.grey700
                  : AppThemeData.grey200,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(120),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SvgPicture.asset("assets/icons/ic_document.svg"),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Document Verification in Pending".tr,
            style: TextStyle(
              color: themeChange.getThem()
                  ? AppThemeData.grey100
                  : AppThemeData.grey800,
              fontSize: 22,
              fontFamily: AppThemeData.semiBold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "Your documents are being reviewed. We will notify you once the verification is complete."
                .tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: themeChange.getThem()
                  ? AppThemeData.grey50
                  : AppThemeData.grey500,
              fontSize: 16,
              fontFamily: AppThemeData.bold,
            ),
          ),
          const SizedBox(height: 20),
          RoundedButtonFill(
            title: "View Status".tr,
            width: 55,
            height: 5.5,
            color: AppThemeData.secondary300,
            textColor: AppThemeData.grey50,
            onPress: () async {
              DashBoardController dashBoardController =
                  Get.put(DashBoardController());
              dashBoardController.drawerIndex.value = 4;
            },
          ),
        ],
      ),
    );
  }
}
