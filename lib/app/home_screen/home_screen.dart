import 'dart:async';
import 'package:android_pip/android_pip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:timelines_plus/timelines_plus.dart';
import 'package:jippydriver_driver/app/chat_screens/chat_screen.dart';
import 'package:jippydriver_driver/app/home_screen/screens/delivery_order_screen/deliver_order_screen.dart';
import 'package:jippydriver_driver/app/home_screen/screens/pickup_order_screen/pickup_order_screen.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/controllers/dash_board_controller.dart';
import 'package:jippydriver_driver/app/home_screen/controller/home_controller.dart';
import 'package:jippydriver_driver/app/home_screen/widgets/order_bottom_drawer.dart';
import 'package:jippydriver_driver/app/home_screen/widgets/today_dashboard_section.dart';
import 'package:jippydriver_driver/main.dart';
import 'package:jippydriver_driver/models/order_model.dart';
import 'package:jippydriver_driver/services/http_client_service.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/themes/responsive.dart';
import 'package:jippydriver_driver/themes/round_button_fill.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/widget/my_separator.dart';

import '../../widget/expandable_address_text.dart';

// ---------------------------------------------------------------------------
//  HomeScreen
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  final bool? isAppBarShow;
  const HomeScreen({super.key, this.isAppBarShow});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _pipDelayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _pipDelayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = Get.find<HomeController>();
    ctrl.updateAppLifecycleState(state);

    if ((state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) &&
        ModalRoute.of(context)?.isCurrent == true) {
      final hasOrder = ctrl.currentOrder.value.id != null &&
          ctrl.currentOrder.value.driverID == Constant.userModel?.id;
      if (hasOrder) {
        _pipDelayTimer?.cancel();
        _pipDelayTimer =
            Timer(const Duration(seconds: 1), () {
              if (mounted) _enterPip();
            });
      } else {
        isInPipMode.value = false;
      }
    } else if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      _pipDelayTimer?.cancel();
      isInPipMode.value = false;
      ctrl.forceRefreshOrders();
    } else {
      _pipDelayTimer?.cancel();
      isInPipMode.value = false;
    }
  }

  Future<void> _enterPip() async {
    if (isInPipMode.value) return;
    try {
      await AndroidPIP().enterPipMode(aspectRatio: [1, 1]);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) isInPipMode.value = true;
    } catch (_) {
      isInPipMode.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Build
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DarkThemeProvider>(context);
    return GetX<HomeController>(
      init: HomeController(),
      builder: (ctrl) => Scaffold(
        backgroundColor:
        theme.getThem() ? AppThemeData.grey900 : AppThemeData.grey100,
        appBar: widget.isAppBarShow == true ? _buildAppBar(context, theme) : null,
        // ── Bottom drawer (accept/reject or order card) ─────────────────
        bottomSheet: Obx(() {
          final show = _shouldShowDrawer(ctrl);
          return OrderBottomDrawer(
            visible: show,
            child: show
                ? _buildBottomZone(theme, ctrl)
                : const SizedBox.shrink(),
          );
        }),
        body: ctrl.isLoading.value
            ? Constant.loader()
            : _buildBody(theme, ctrl),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context, DarkThemeProvider theme) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
    backgroundColor: colorScheme.surface,
    foregroundColor: colorScheme.onSurface,
    centerTitle: false,
    iconTheme:
    IconThemeData(color: colorScheme.onSurface, size: 20),
    title: Text(
      'Order'.tr,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 18,
        fontFamily: AppThemeData.medium,
      ),
    ),
  );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Body — THE BUG WAS HERE
  //  TodayDashboardSection was outside the Column children list.
  //  Fixed: it is now a proper child after the optional low-balance banner.
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildBody(DarkThemeProvider theme, HomeController ctrl) {
    // Document-verification pending screen
    // if (Constant.userModel?.vendorID?.isEmpty == true &&
    //     Constant.isDriverVerification == true &&
    //     Constant.userModel?.isDocumentVerify == false) {
    //   return _buildVerificationPending(theme);
    // }

    final walletBalance = double.tryParse(
            Constant.userModel!.walletAmount?.toString() ?? '0') ??
        0.0;
    final minimumDeposit = double.tryParse(
            Constant.minimumDepositToRideAccept) ??
        -1000.0;
    final isLowBalance = Constant.userModel?.vendorID?.isEmpty == true &&
        walletBalance < minimumDeposit;

    return RefreshIndicator(
      onRefresh: () => ctrl.forceRefreshOrders(),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        // Extra bottom padding so content is never hidden behind the bottom drawer
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 240),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Optional low-balance warning ──────────────────────────────
            if (isLowBalance)
              _LowBalanceBanner(theme: theme),

            // ── TODAY DASHBOARD (was previously missing / broken) ─────────
            RepaintBoundary(
              child: TodayDashboardSection(theme: theme, ctrl: ctrl),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Bottom-drawer visibility gate
  // ═══════════════════════════════════════════════════════════════════════

  bool _shouldShowDrawer(HomeController ctrl) {
    if (isInPipMode.value) return false;
    final order  = ctrl.currentOrder.value;
    final driver = ctrl.driverModel.value;

    final inReq          =
        driver.orderRequestData?.contains(order.id) ?? false;
    final inProgressHere =
        driver.inProgressOrderID?.contains(order.id) ?? false;
    final noDriver       =
        order.driverID == null || order.driverID!.isEmpty;
    final acceptShow = order.id != null &&
        !inProgressHere &&
        (inReq ||
            ctrl.isAcceptingOrder ||
            order.status == Constant.driverPending ||
            (order.status == Constant.orderAccepted && noDriver)) &&
        noDriver &&
        order.address != null &&
        (order.vendor != null || (order.vendorID?.isNotEmpty ?? false));

    final cardShow = order.id != null &&
        (order.driverID == Constant.userModel?.id || inProgressHere) &&
        (!inReq || order.status == Constant.driverPending);

    return acceptShow || cardShow;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Bottom zone switcher
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildBottomZone(DarkThemeProvider theme, HomeController ctrl) {
    if (isInPipMode.value) return _PipOverlay(ctrl: ctrl, theme: theme);

    final order  = ctrl.currentOrder.value;
    final driver = ctrl.driverModel.value;
    final inReq          =
        driver.orderRequestData?.contains(order.id) ?? false;
    final inProgressHere =
        driver.inProgressOrderID?.contains(order.id) ?? false;
    final noDriver = order.driverID == null || order.driverID!.isEmpty;

    final showAcceptReject = order.id != null &&
        !inProgressHere &&
        (inReq ||
            ctrl.isAcceptingOrder ||
            order.status == Constant.driverPending ||
            (order.status == Constant.orderAccepted && noDriver)) &&
        noDriver &&
        order.address != null &&
        (order.vendor != null || (order.vendorID?.isNotEmpty ?? false));

    final showCard = order.id != null &&
        (order.driverID == Constant.userModel?.id || inProgressHere) &&
        (!inReq || order.status == Constant.driverPending);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => SlideTransition(
        position:
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: showAcceptReject
          ? KeyedSubtree(
        key: const ValueKey('accept_reject'),
        child: _AcceptRejectCard(ctrl: ctrl, theme: theme),
      )
          : showCard
          ? KeyedSubtree(
        key: const ValueKey('order_card'),
        child: _OrderActionsCard(ctrl: ctrl, theme: theme),
      )
          : const KeyedSubtree(
        key: ValueKey('no_order'),
        child: SizedBox.shrink(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Verification pending
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildVerificationPending(DarkThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: ShapeDecoration(
              color: theme.getThem()
                  ? AppThemeData.grey700
                  : AppThemeData.grey200,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(120)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SvgPicture.asset('assets/icons/ic_document.svg'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Document Verification in Pending'.tr,
            style: TextStyle(
              color: theme.getThem()
                  ? AppThemeData.grey100
                  : AppThemeData.grey800,
              fontSize: 22,
              fontFamily: AppThemeData.semiBold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Your documents are being reviewed. We will notify you once the verification is complete.'
                .tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.getThem()
                  ? AppThemeData.grey50
                  : AppThemeData.grey500,
              fontSize: 16,
              fontFamily: AppThemeData.bold,
            ),
          ),
          const SizedBox(height: 20),
          RoundedButtonFill(
            title: 'View Status'.tr,
            width: 55,
            height: 5.5,
            color: AppThemeData.secondary300,
            textColor: AppThemeData.grey50,
            onPress: () {
              final dash = Get.put(DashBoardController());
              dash.drawerIndex.value = 3;
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Low-balance banner (extracted widget — prevents unnecessary rebuilds)
// ─────────────────────────────────────────────────────────────────────────────
class _LowBalanceBanner extends StatelessWidget {
  final DarkThemeProvider theme;
  const _LowBalanceBanner({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppThemeData.danger50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppThemeData.danger200, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppThemeData.danger500, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${'Please Contact your fleet manager your balance reached'.tr}'
                  ' ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept)}',
              style: TextStyle(
                color: theme.getThem()
                    ? AppThemeData.grey50
                    : AppThemeData.grey900,
                fontSize: 13,
                fontFamily: AppThemeData.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  Accept / Reject card
// =============================================================================
class _AcceptRejectCard extends StatelessWidget {
  final HomeController ctrl;
  final DarkThemeProvider theme;
  const _AcceptRejectCard({required this.ctrl, required this.theme});

  @override
  Widget build(BuildContext context) {
    final vendor  = ctrl.currentOrder.value.vendor;
    final address = ctrl.currentOrder.value.address;
    final vLat    = vendor?.latitudeValue;
    final vLng    = vendor?.longitudeValue;
    final cLat    = address?.location?.latitude;
    final cLng    = address?.location?.longitude;
    double km     = 0.0;
    if (vendor != null &&
        address != null &&
        vLat != null &&
        vLng != null &&
        cLat != null &&
        cLng != null) {
      km = Geolocator.distanceBetween(vLat, vLng, cLat, cLng) / 1000;
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: ShapeDecoration(
          color:
          theme.getThem() ? AppThemeData.grey900 : AppThemeData.grey50,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTimeline(vendor, address),
              const SizedBox(height: 8),
              MySeparator(
                color: theme.getThem()
                    ? AppThemeData.grey700
                    : AppThemeData.grey200,
              ),
              const SizedBox(height: 8),
              _ChargeBreakdown(ctrl: ctrl, theme: theme, km: km),
              const SizedBox(height: 10),
              SafeArea(
                child: Row(children: [
                  Expanded(
                    child: RoundedButtonFill(
                      title: 'Reject'.tr,
                      width: 24,
                      height: 5.5,
                      borderRadius: 10,
                      color: AppThemeData.danger300,
                      textColor: AppThemeData.grey50,
                      onPress: () => ctrl.rejectOrder(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RoundedButtonFill(
                      title: 'Accept'.tr,
                      width: 24,
                      height: 5.5,
                      borderRadius: 10,
                      color: AppThemeData.success400,
                      textColor: AppThemeData.grey50,
                      onPress: () async => ctrl.acceptOrder(),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(vendor, address) {
    return Timeline.tileBuilder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      theme: TimelineThemeData(nodePosition: 0),
      builder: TimelineTileBuilder.connected(
        contentsAlign: ContentsAlign.basic,
        indicatorBuilder: (_, index) => index == 0
            ? _circleIcon('assets/icons/ic_building.svg',
            AppThemeData.primary50, AppThemeData.primary300)
            : _circleIcon('assets/icons/ic_location.svg',
            AppThemeData.driverApp50, AppThemeData.driverApp300),
        connectorBuilder: (_, __, ___) =>
        const DashedLineConnector(color: AppThemeData.grey300, gap: 3),
        contentsBuilder: (ctx, index) => Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: index == 0
                ? [
              Text('${vendor?.title ?? 'N/A'}',
                  style: _titleStyle()),
              Text('${vendor?.location ?? 'N/A'}',
                  style: _subtitleStyle()),
            ]
                : [
              Text('Deliver to the'.tr, style: _titleStyle()),
              Text(address?.getFullAddress() ?? 'N/A',
                  style: _subtitleStyle()),
            ],
          ),
        ),
        itemCount: 2,
      ),
    );
  }

  Widget _circleIcon(String asset, Color bg, Color ic) => Container(
    decoration: ShapeDecoration(
      color: bg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(120)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: SvgPicture.asset(asset,
          colorFilter: ColorFilter.mode(ic, BlendMode.srcIn)),
    ),
  );

  TextStyle _titleStyle() => TextStyle(
    fontFamily: AppThemeData.semiBold,
    fontSize: 16,
    color:
    theme.getThem() ? AppThemeData.grey50 : AppThemeData.grey900,
  );

  TextStyle _subtitleStyle() => TextStyle(
    fontFamily: AppThemeData.medium,
    fontSize: 14,
    color: theme.getThem()
        ? AppThemeData.grey300
        : AppThemeData.grey600,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Charge breakdown — reads Rx, zero extra API calls on rebuild
// ─────────────────────────────────────────────────────────────────────────────
class _ChargeBreakdown extends StatelessWidget {
  final HomeController ctrl;
  final DarkThemeProvider theme;
  final double km;
  const _ChargeBreakdown(
      {required this.ctrl, required this.theme, required this.km});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tip      = double.tryParse(
          ctrl.currentOrder.value.tipAmount?.toString() ?? '0') ??
          0.0;
      final surge    = ctrl.surgeFee.value;
      final hasSurge = surge > 0;
      final d2r      = ctrl.driverToRestaurantCharge.value;
      final r2c      = ctrl.restaurantToCustomerCharge.value;
      final total    = d2r + r2c + tip + surge;
      final isVendorDriver =
          ctrl.driverModel.value.vendorID?.isEmpty == true;

      return Column(children: [
        // Distance
        _row('Trip Distance'.tr,
            '${km.toStringAsFixed(2)} ${Constant.distanceType}'),

        // Tip
        if (tip > 0) ...[
          const SizedBox(height: 4),
          _row('Tips'.tr, Constant.amountShow(amount: tip.toString())),
        ],
        const SizedBox(height: 6),

        // Delivery charge breakdown
        if (isVendorDriver) ...[
          _row(
            'Delivery Charge'.tr,
            '${d2r.toStringAsFixed(2)} + ${r2c.toStringAsFixed(2)} = ${(d2r + r2c).toStringAsFixed(2)}',
          ),
          const SizedBox(height: 4),
        ],

        // Surge
        if (hasSurge) _surgeRow(surge),

        const SizedBox(height: 8),
        _totalEarningsBox(total),
      ]);
    });
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(
        child: Text(label,
            style: TextStyle(
              fontFamily: AppThemeData.regular,
              color: theme.getThem()
                  ? AppThemeData.grey300
                  : AppThemeData.grey600,
              fontSize: 15,
            )),
      ),
      Text(value,
          style: TextStyle(
            fontFamily: AppThemeData.semiBold,
            color: theme.getThem()
                ? AppThemeData.grey50
                : AppThemeData.grey900,
            fontSize: 15,
          )),
    ]),
  );

  Widget _surgeRow(double surge) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding:
    const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
    decoration: BoxDecoration(
      color: AppThemeData.success50.withOpacity(0.3),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(children: [
      Expanded(
        child: Row(children: [
          Text('Surge Fee'.tr,
              style: TextStyle(
                fontFamily: AppThemeData.regular,
                color: theme.getThem()
                    ? AppThemeData.grey300
                    : AppThemeData.grey600,
                fontSize: 15,
              )),
          const SizedBox(width: 6),
          const Icon(Icons.trending_up_rounded,
              color: AppThemeData.success400, size: 16),
        ]),
      ),
      Text('+${surge.toStringAsFixed(2)}',
          style: const TextStyle(
            fontFamily: AppThemeData.semiBold,
            color: AppThemeData.success500,
            fontSize: 16,
          )),
    ]),
  );

  Widget _totalEarningsBox(double total) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    decoration: BoxDecoration(
      color: AppThemeData.primary50.withOpacity(0.2),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppThemeData.primary200),
    ),
    child: Row(children: [
      Expanded(
        child: Text('Total Earnings'.tr,
            style: TextStyle(
              fontFamily: AppThemeData.semiBold,
              color: theme.getThem()
                  ? AppThemeData.grey50
                  : AppThemeData.grey900,
              fontSize: 16,
            )),
      ),
      Text(
        total.toStringAsFixed(2),
        style: const TextStyle(
          fontFamily: AppThemeData.bold,
          color: AppThemeData.primary500,
          fontSize: 20,
        ),
      ),
    ]),
  );
}

// =============================================================================
//  Order actions card (active / in-progress orders)
// =============================================================================
class _OrderActionsCard extends StatelessWidget {
  final HomeController ctrl;
  final DarkThemeProvider theme;
  const _OrderActionsCard({required this.ctrl, required this.theme});

  @override
  Widget build(BuildContext context) {
    final order = ctrl.currentOrder.value;
    return Container(
      color: theme.getThem() ? AppThemeData.grey900 : AppThemeData.grey50,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Collapse handle
        GestureDetector(
          onTap: ctrl.changeArrow,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Obx(() => Icon(
              ctrl.arrowDrop.value
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: theme.getThem()
                  ? AppThemeData.grey300
                  : AppThemeData.grey600,
            )),
          ),
        ),

        // Expandable content
        Obx(() => AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: ctrl.arrowDrop.value
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _OrderCardContent(
                ctrl: ctrl, theme: theme, order: order),
          ),
          secondChild: const SizedBox.shrink(),
        )),

        // Navigation section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: _NavigationSection(ctrl: ctrl, theme: theme, order: order),
        ),

        // Action button
        _ActionButton(ctrl: ctrl, theme: theme, order: order),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _OrderCardContent extends StatelessWidget {
  final HomeController ctrl;
  final DarkThemeProvider theme;
  final OrderModel order;
  const _OrderCardContent(
      {required this.ctrl, required this.theme, required this.order});

  @override
  Widget build(BuildContext context) {
    final isPickup = order.status == Constant.orderShipped ||
        order.status == Constant.driverAccepted;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (isPickup) _buildPickupRow() else _buildDeliveryTimeline(),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: MySeparator(
          color: theme.getThem()
              ? AppThemeData.grey700
              : AppThemeData.grey200,
        ),
      ),
      _paymentSection(),
      const SizedBox(height: 4),
    ]);
  }

  Widget _buildPickupRow() => Row(children: [
    _circleIcon('assets/icons/ic_building.svg', AppThemeData.primary50,
        AppThemeData.primary300),
    const SizedBox(width: 10),
    Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${order.vendor?.title}', style: _titleStyle()),
        Text('${order.vendor?.location}', style: _subtitleStyle()),
      ]),
    ),
    const SizedBox(width: 8),
    _phoneBtn(() => Constant.makePhoneCall(
        order.vendor!.phonenumber.toString())),
  ]);

  Widget _buildDeliveryTimeline() => Timeline.tileBuilder(
    shrinkWrap: true,
    padding: EdgeInsets.zero,
    physics: const NeverScrollableScrollPhysics(),
    theme: TimelineThemeData(nodePosition: 0),
    builder: TimelineTileBuilder.connected(
      contentsAlign: ContentsAlign.basic,
      indicatorBuilder: (_, i) => i == 0
          ? _circleIcon('assets/icons/ic_building.svg',
          AppThemeData.primary50, AppThemeData.primary300)
          : _circleIcon('assets/icons/ic_location.svg',
          AppThemeData.driverApp50, AppThemeData.driverApp300),
      connectorBuilder: (_, __, ___) => const DashedLineConnector(
          color: AppThemeData.grey300, gap: 3),
      contentsBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: i == 0
            ? Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${order.vendor?.title}',
                      style: _titleStyle()),
                  Text(
                    '${order.vendor?.location ?? 'N/A'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _subtitleStyle(),
                  ),
                ]),
          ),
          _phoneBtn(() => Constant.makePhoneCall(
              order.vendor!.phonenumber.toString())),
        ])
            : Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deliver to the'.tr, style: _titleStyle()),

                  ExpandableAddressText(
                    text: order.address?.getFullAddress() ?? 'N/A',
                    style: _subtitleStyle(),
                  ),
                ],
              ),
            ),

            _phoneBtn(() async {
              ShowToastDialog.showLoader('Please wait'.tr);
              final c = await FireStoreUtils.getUserProfile(
                  order.authorID.toString());
              ShowToastDialog.closeLoader();
              if (c?.phoneNumber != null) {
                Constant.makePhoneCall(c!.phoneNumber!);
              }
            }),

            const SizedBox(width: 8),
            // _chatBtn(ctx),
          ],
        ),      ),
      itemCount: 2,
    ),
  );

  Widget _chatBtn(BuildContext ctx) => InkWell(
    onTap: () async {
      ShowToastDialog.showLoader('Please wait'.tr);
      final customer = await FireStoreUtils.getUserProfile(
          order.authorID.toString());
      final driver = await FireStoreUtils.getUserProfile(
          order.driverID.toString());
      ShowToastDialog.closeLoader();
      Get.to(const ChatScreen(), arguments: {
        'customerName': customer?.fullName() ?? '',
        'restaurantName': driver?.fullName() ?? '',
        'orderId': order.id,
        'restaurantId': driver?.id,
        'customerId': customer?.id,
        'customerProfileImage': customer?.profilePictureURL ?? '',
        'restaurantProfileImage': driver?.profilePictureURL ?? '',
        'token': customer?.fcmToken,
        'chatType': 'Driver',
      });
    },
    child: _iconCircle(
        child: SvgPicture.asset('assets/icons/ic_wechat.svg')),
  );

  Widget _paymentSection() => Column(
    children: [
      _payRow(
        'Payment Type'.tr,
        order.paymentMethod?.toLowerCase() == 'cod'
            ? 'Cash on delivery'
            : 'Online',
      ),

      if (order.paymentMethod?.toLowerCase() == 'cod') ...[
        const SizedBox(height: 4),

        _payRow(
          'Collect Payment from customer'.tr,
          Constant.amountShow(
            amount: (order.toPay ?? '0').toString(),
          ),
        ),
      ],
    ],
  );

  Widget _payRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(
        child: Text(label,
            style: TextStyle(
              fontFamily: AppThemeData.regular,
              color: theme.getThem()
                  ? AppThemeData.grey300
                  : AppThemeData.grey600,
              fontSize: 15,
            )),
      ),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppThemeData.semiBold,
            color: theme.getThem()
                ? AppThemeData.grey50
                : AppThemeData.grey900,
            fontSize: 15,
          ),
        ),
      ),
    ]),
  );

  Widget _phoneBtn(VoidCallback onTap) =>
      InkWell(onTap: onTap, child: _iconCircle(child: SvgPicture.asset('assets/icons/ic_phone_call.svg')));

  Widget _iconCircle({required Widget child}) => Container(
    width: 42,
    height: 42,
    decoration: ShapeDecoration(
      shape: RoundedRectangleBorder(
        side: BorderSide(
            width: 1,
            color: theme.getThem()
                ? AppThemeData.grey700
                : AppThemeData.grey200),
        borderRadius: BorderRadius.circular(120),
      ),
    ),
    child: Padding(padding: const EdgeInsets.all(9), child: child),
  );

  Widget _circleIcon(String asset, Color bg, Color ic) => Container(
    decoration: ShapeDecoration(
      color: bg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(120)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: SvgPicture.asset(asset,
          colorFilter: ColorFilter.mode(ic, BlendMode.srcIn)),
    ),
  );

  TextStyle _titleStyle() => TextStyle(
    fontFamily: AppThemeData.semiBold,
    fontSize: 16,
    color:
    theme.getThem() ? AppThemeData.grey50 : AppThemeData.grey900,
  );
  TextStyle _subtitleStyle() => TextStyle(
    fontFamily: AppThemeData.medium,
    fontSize: 14,
    color: theme.getThem()
        ? AppThemeData.grey300
        : AppThemeData.grey600,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Navigation section
// ─────────────────────────────────────────────────────────────────────────────
class _NavigationSection extends StatelessWidget {
  final HomeController ctrl;
  final DarkThemeProvider theme;
  final OrderModel order;
  const _NavigationSection(
      {required this.ctrl, required this.theme, required this.order});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isPickup = ctrl.isPickupNavigationState;
      final isDrop   = ctrl.isDropNavigationState;
      if (!isPickup && !isDrop) return const SizedBox.shrink();

      final destLat = isPickup
          ? order.vendor?.latitude
          : order.address?.location?.latitude;
      final canNav  = destLat != null;

      return Container(
        decoration: BoxDecoration(
          color: theme.getThem()
              ? AppThemeData.grey800
              : AppThemeData.grey100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Pickup'.tr, order.vendor?.location ?? 'N/A'),
              const SizedBox(height: 4),
              _infoRow(
                  'Drop'.tr, order.address?.getFullAddress() ?? 'N/A'),
              const SizedBox(height: 8),
          Center(
            child: RoundedButtonFill(
                title: ctrl.isNavigatingToMap.value
                    ? 'Opening Maps...'.tr
                    : (isPickup
                    ? 'Navigate to Restaurant'.tr
                    : 'Navigate to Customer'.tr),
                width: 45,
                height: 5,
                borderRadius: 10,
                color: canNav
                    ? AppThemeData.primary300
                    : AppThemeData.grey400,
                textColor: AppThemeData.grey50,
                onPress: (!canNav || ctrl.isNavigatingToMap.value)
                    ? null
                    : () => ctrl.openCurrentOrderNavigation(),
            ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _infoRow(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 52,
        child: Text(label,
            style: TextStyle(
              fontFamily: AppThemeData.medium,
              fontSize: 12,
              color: theme.getThem()
                  ? AppThemeData.grey300
                  : AppThemeData.grey600,
            )),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppThemeData.semiBold,
              fontSize: 13,
              color: theme.getThem()
                  ? AppThemeData.grey50
                  : AppThemeData.grey900,
            )),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bottom action button
// ─────────────────────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final HomeController ctrl;
  final DarkThemeProvider theme;
  final OrderModel order;
  const _ActionButton(
      {required this.ctrl, required this.theme, required this.order});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _handleTap(context),
      child: SafeArea(
        child: Container(
          color: AppThemeData.driverApp300,
          width: Responsive.width(100, context),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            _label(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppThemeData.grey900,
              fontSize: 16,
              fontFamily: AppThemeData.semiBold,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  String _label() {
    final s = order.status ?? '';
    if (s == Constant.orderShipped || s == Constant.driverAccepted) {
      return 'Reached restaurant for Pickup'.tr;
    }
    if (s == Constant.orderInTransit) {
      return ctrl.driverModel.value.vendorID?.isEmpty == true
          ? 'Reached the Customers Door Steps'.tr
          : 'Order Delivered'.tr;
    }
    if (s == Constant.driverPending) return 'Reached restaurant for Pickup'.tr;
    return 'Order Delivered'.tr;
  }

  Future<void> _handleTap(BuildContext ctx) async {
    final s = order.status ?? '';
    if (s == Constant.orderShipped || s == Constant.driverAccepted) {
      final result = await Get.to(
        const PickupOrderScreen(),
        arguments: {'orderModel': order},
      );
      if (result == true) {
        final cached = ctrl.currentOrder.value;
        cached.status = Constant.orderInTransit;
        ctrl.currentOrder.value = cached;
        ctrl.currentOrder.refresh();
        await Future.delayed(const Duration(milliseconds: 800));
        await ctrl.refreshCurrentOrder(forceRefresh: true);
      }
      return;
    }

    final result = await Get.to(
      const DeliverOrderScreen(),
      arguments: {'orderModel': order},
    );
    if (result == true || result is String) {
      final completedId =
          (result is String ? result : null) ?? order.id?.toString();
      if (completedId != null) {
        ctrl.markOrderAsCompleted(completedId);
        ctrl.driverModel.value.inProgressOrderID
            ?.removeWhere((id) => id?.toString() == completedId);
        ctrl.driverModel.value.orderRequestData
            ?.removeWhere((id) => id?.toString() == completedId);
        final h = HttpClientService();
        await h.invalidateCache('orders/$completedId');
      }
      // Completion backend already updated the driver profile (wallet + order lists).
      // Re-sync the reactive driver model from Constant to avoid an extra write.
      if (Constant.userModel != null) {
        ctrl.driverModel.value = Constant.userModel!;
        ctrl.driverModel.refresh();
      }
      ctrl.currentOrder.value = OrderModel();
      await ctrl.clearMap();
      ctrl.resetStatusTracking();
      if (Constant.singleOrderReceive == false) Get.back();
    }
  }
}

// =============================================================================
//  PiP overlay — minimal: status + earnings only
// =============================================================================
class _PipOverlay extends StatelessWidget {
  final HomeController ctrl;
  final DarkThemeProvider theme;
  const _PipOverlay({required this.ctrl, required this.theme});

  @override
  Widget build(BuildContext context) {
    final order = ctrl.currentOrder.value;
    if (order.id == null) return const SizedBox.shrink();
    return Container(
      color: theme.getThem() ? AppThemeData.grey900 : AppThemeData.grey50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        const Icon(Icons.delivery_dining,
            size: 22, color: AppThemeData.secondary300),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            order.status ?? '',
            style: TextStyle(
              color: theme.getThem()
                  ? AppThemeData.grey50
                  : AppThemeData.grey900,
              fontSize: 14,
              fontFamily: AppThemeData.semiBold,
            ),
          ),
        ),
        Obx(() => Text(
          ctrl.totalCalculatedCharge.value.toInt().toString(),
          style: const TextStyle(
            color: AppThemeData.primary500,
            fontSize: 18,
            fontFamily: AppThemeData.bold,
          ),
        )),
      ]),
    );
  }
}