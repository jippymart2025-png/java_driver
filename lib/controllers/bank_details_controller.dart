import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/controllers/dash_board_controller.dart';
import 'package:jippydriver_driver/controllers/login_controller.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';

class BankDetailsController extends GetxController {
  // ── Text controllers ─────────────────────────────────────────────────────
  final bankNameController = TextEditingController().obs;
  final branchNameController = TextEditingController().obs;
  final holderNameController = TextEditingController().obs;
  final accountNoController = TextEditingController().obs;
  final otherInfoController = TextEditingController().obs;

  // ── State ─────────────────────────────────────────────────────────────────
  final isLoading = true.obs;
  final userModel = UserModel().obs;

  final DashBoardController _dashBoardController =
  Get.find<DashBoardController>();

  @override
  void onInit() {
    super.onInit();
    _loadCurrentUser();
  }

  @override
  void onClose() {
    bankNameController.value.dispose();
    branchNameController.value.dispose();
    holderNameController.value.dispose();
    accountNoController.value.dispose();
    otherInfoController.value.dispose();
    super.onClose();
  }

  // ── Load user ─────────────────────────────────────────────────────────────

  Future<void> _loadCurrentUser() async {
    try {
      final userId = await LoginController.getFirebaseId();
      final value = await FireStoreUtils.getUserProfile(userId);
      if (value != null) {
        userModel.value = value;
        _populateFromBankDetails(value.userBankDetails);
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _populateFromBankDetails(UserBankDetails? details) {
    if (details == null) return;
    bankNameController.value.text = details.bankName ?? '';
    branchNameController.value.text = details.branchName ?? '';
    holderNameController.value.text = details.holderName ?? '';
    accountNoController.value.text = details.accountNumber ?? '';
    otherInfoController.value.text = details.otherDetails ?? '';
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> saveBank() async {
    ShowToastDialog.showLoader("Please wait".tr);

    try {
      final details = userModel.value.userBankDetails ?? UserBankDetails();

      details
        ..accountNumber = accountNoController.value.text.trim()
        ..bankName = bankNameController.value.text.trim()
        ..branchName = branchNameController.value.text.trim()
        ..holderName = holderNameController.value.text.trim()
        ..otherDetails = otherInfoController.value.text.trim();

      userModel.value.userBankDetails = details;

      await FireStoreUtils.updateUser(userModel.value);

      await _dashBoardController.getUser();

      ShowToastDialog.showToast(
        "Bank details saved successfully".tr,
      );

      Get.back();
    } catch (e, stackTrace) {
      debugPrint('Error saving bank: $e');
      debugPrintStack(stackTrace: stackTrace);

      ShowToastDialog.showToast(
        "Failed to save. Please try again.".tr,
      );
    } finally {
      ShowToastDialog.closeLoader();
    }
  }
}