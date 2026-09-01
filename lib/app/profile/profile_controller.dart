import 'package:get/get.dart';

import '../../constant/constant.dart';
import '../../constant/show_toast_dialog 2.dart';
import '../../controllers/dash_board_controller.dart';
import '../../models/user_model.dart';
import '../../utils/dark_theme_provider.dart';
import '../../utils/fire_store_utils.dart';
import '../../utils/preferences.dart';
import '../../controllers/edit_profile_controller.dart';
import '../edit_profile_screen/edit_profile_screen.dart';
import '../terms_and_condition/terms_and_condition_screen.dart';
import '../verification_screen/verification_screen.dart';
import '../withdraw_method_setup_screens/withdraw_method_setup_screen.dart';

class ProfileController extends GetxController {
  // ── Dependencies ────────────────────────────────────────────────────
  final DashBoardController _dashCtrl = Get.find<DashBoardController>();

  /// Same instance as internally held; profile UI cannot access `_dashCtrl`.
  DashBoardController get dashCtrl => _dashCtrl;

  // ── Observables ─────────────────────────────────────────────────────

  /// Mirrors DashBoardController's userModel so the Profile UI can react
  /// to changes without owning the source of truth.
  UserModel get user => _dashCtrl.userModel.value;

  RxBool get isActive => (_dashCtrl.userModel.value.isActive ?? false).obs;
  RxBool get isDarkMode => _dashCtrl.isDarkModeSwitch;

  // ── Available-status toggle ─────────────────────────────────────────

  Future<void> toggleActive(bool value, DarkThemeProvider theme) async {
    final docRequired = Constant.isDriverVerification == true &&
        _dashCtrl.userModel.value.isDocumentVerify != true;

    if (docRequired) {
      ShowToastDialog.showToast(
        'Document verification is pending. Please complete it first.'.tr,
      );
      return;
    }

    final updated = UserModel.fromJson(_dashCtrl.userModel.value.toJson());
    updated.isActive          = value;
    // updated.inProgressOrderID = Constant.userModel?.inProgressOrderID;
    // updated.orderRequestData  = Constant.userModel?.orderRequestData;

    _dashCtrl.userModel.value = updated;

    if (value) await _dashCtrl.updateCurrentLocation();

    final success = await FireStoreUtils.updateUser(updated);
    if (success) {
      Constant.userModel = updated;
      _dashCtrl.userModel.refresh();
    }
  }

  // ── Dark-mode toggle ────────────────────────────────────────────────

  void toggleDarkMode(bool value, DarkThemeProvider theme) {
    _dashCtrl.isDarkModeSwitch.value = value;
    if (value) {
      Preferences.setString(Preferences.themKey, 'Dark');
      theme.darkTheme = 0;
    } else if (_dashCtrl.isDarkMode.value == 'Light') {
      Preferences.setString(Preferences.themKey, 'Light');
      theme.darkTheme = 1;
    } else {
      Preferences.setString(Preferences.themKey, '');
      theme.darkTheme = 2;
    }
  }

  // ── Navigation helper ───────────────────────────────────────────────

  /// Index 4 = Document Verification → dedicated screen.
  /// All other indices set the dashboard tab and pop back.
  void navigate(int index) {
    if (index == 0) {
      if (Get.isRegistered<EditProfileController>()) {
        // Controller is permanent; force refresh so first-login data appears.
        Get.find<EditProfileController>().getData();
      }
      Get.to(() => const EditProfileScreen());
      return;
    }

    if (index == 1) {
      Get.to(() => const VerificationScreen());
      return;
    }

    if (index == 2) {
      Get.to(() => const TermsAndConditionScreen(type: "terms"));
      return;
    }

    if (index == 3) {
      Get.to(() => const TermsAndConditionScreen(type: "privacy"));
      return;
    }
    if (index == 4) {
      Get.to(() => const WithdrawMethodSetupScreen());
      return;
    }
  }
}