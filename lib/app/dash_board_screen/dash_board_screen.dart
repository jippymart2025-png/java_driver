import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:jippydriver_driver/app/home_screen/home_screen.dart';
import 'package:jippydriver_driver/app/dash_board_screen/widgets/dashboard_bottom_nav_bar.dart';
import 'package:jippydriver_driver/app/order_list_screen/order_list_screen.dart';
import 'package:jippydriver_driver/app/wallet_screen/wallet_screen.dart';
import 'package:jippydriver_driver/app/wallet_screen/screens/delivery_amount_wallet_screen/delivery_amount_wallet_screen.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/controllers/dash_board_controller.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/main.dart';
import '../profile/profile_screen.dart'; // isInPipMode

// ===========================================================================
//  DashBoardScreen
// ===========================================================================
class DashBoardScreen extends StatefulWidget {
  final UserModel? userModel;
  const DashBoardScreen({super.key, this.userModel});

  @override
  State<DashBoardScreen> createState() => _DashBoardScreenState();
}

class _DashBoardScreenState extends State<DashBoardScreen> {

  // Controller is created ONCE here and reused by DrawerView via Get.find()
  late final DashBoardController _ctrl;
  bool _isForcingInactive = false;
  bool _isTogglingActive = false;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(DashBoardController());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enforceActiveRules();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DarkThemeProvider>(context);

    return Scaffold(
      appBar: _buildAppBar(theme),
      body: Obx(() {
        if (isInPipMode.value) {
          return const HomeScreen(isAppBarShow: false);
        }
        return IndexedStack(
          index: _ctrl.drawerIndex.value.clamp(0, 3),
          children: const [
            HomeScreen(isAppBarShow: false),
            OrderListScreen(),
            WalletScreen(isAppBarShow: false),
            ProfileScreen(),
          ],
        );
      }),
      bottomNavigationBar: Obx(() => DashboardBottomNavBar(
            currentIndex: _ctrl.drawerIndex.value.clamp(0, 3),
            onTap: (index) => _ctrl.drawerIndex.value = index,
          )),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────
  AppBar _buildAppBar(DarkThemeProvider theme) {
    final bgColor = theme.getThem() ? AppThemeData.grey900 : AppThemeData.grey50;
    final textColor = theme.getThem() ? AppThemeData.grey50 : AppThemeData.grey900;

    return AppBar(
      backgroundColor: bgColor,
      centerTitle: true,
      title: Text(
        'Jippy Food Delivery'.tr,
        style: TextStyle(
          color: textColor,
          fontSize: 17,
          fontFamily: AppThemeData.semiBold,
        ),
      ),
      actions: [
        if (Constant.userModel?.vendorID?.isEmpty == true)
          InkWell(
            onTap: () => Get.to(const DeliveryAmountWalletScreen(isAppBarShow: true)),
            child: SvgPicture.asset('assets/icons/delivery_wallet.svg', height: 28, width: 28),
          ),
        const SizedBox(width: 20),
        // InkWell(
        //   onTap: () => Get.to(const EditProfileScreen()),
        //   child: SvgPicture.asset('assets/icons/ic_user_business.svg'),
        // ),
        // const SizedBox(width: 10),
      ],
      leadingWidth: 90,
      leading: Center(
        child: Transform.scale(
          scale: 1.0,
          child: Obx(() {
            final isDocVerified = _ctrl.userModel.value.isDocumentVerify == true;
            final isActiveValue = isDocVerified
                ? (_ctrl.userModel.value.isActive ?? false)
                : false;
            return CupertinoSwitch(
              value: isActiveValue,
              activeColor: AppThemeData.primary300,
              onChanged: (val) async {
                if (_isTogglingActive) return;
                await _toggleActiveFromAppBar(val);
              },
            );
          }),
        ),
      ),
    );
  }

  Future<void> _toggleActiveFromAppBar(bool value) async {
    if (_isTogglingActive) return;
    final user = _ctrl.userModel.value;
    if ((user.isActive ?? false) == value) return;
    _isTogglingActive = true;

    try {
      final isDocVerified = user.isDocumentVerify == true;
      final docVerificationRequired = !isDocVerified;

      /// ❌ BLOCK turning ON if not verified
      if (docVerificationRequired && value == true) {
        ShowToastDialog.showToast(
          'Complete the verification steps to enable availability.'.tr,
        );

        /// Keep local/UI off but don't send a second backend toggle call.
        final forceOff = UserModel.fromJson(user.toJson());
        forceOff.isActive = false;
        _ctrl.userModel.value = forceOff;
        _ctrl.userModel.refresh();
        return;
      }

      /// ✅ Persist via readyToAcceptIsToggle
      final driverId = int.tryParse(user.id ?? '');
      if (driverId == null) {
        ShowToastDialog.showToast("Failed to update status");
        _ctrl.userModel.refresh(); // revert visually
        return;
      }

      final success = await FireStoreUtils.toggleReadyToAccept(
        driverId: driverId,
        ready: value,
      );

      if (success) {
        /// ✅ Update local state ONLY after success
        final updated = UserModel.fromJson(user.toJson());
        updated.isActive = value;

        updated.inProgressOrderID = user.inProgressOrderID;
        updated.orderRequestData = user.orderRequestData;

        _ctrl.userModel.value = updated;
        _ctrl.userModel.refresh();
        Constant.userModel = updated;

        /// Start location listener only after active state is saved.
        if (value) {
          await _ctrl.updateCurrentLocation();
        }
      } else {
        /// ❌ Revert UI if API fails
        ShowToastDialog.showToast("Failed to update status");
        _ctrl.userModel.refresh(); // revert visually
      }
    } finally {
      _isTogglingActive = false;
    }
  }

  Future<void> _enforceActiveRules() async {
    if (_isForcingInactive) return;
    final isDocVerified = _ctrl.userModel.value.isDocumentVerify == true;
    final isActive = _ctrl.userModel.value.isActive == true;
    if (!isDocVerified && isActive) {
      _isForcingInactive = true;
      try {
        final forced = UserModel.fromJson(_ctrl.userModel.value.toJson());
        forced.isActive = false;
        _ctrl.userModel.value = forced;
        final success = await FireStoreUtils.updateUser(forced);
        if (success) {
          Constant.userModel = forced;
        }
        _ctrl.userModel.refresh();
      } finally {
        _isForcingInactive = false;
      }
    }
  }

}
