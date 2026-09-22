import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jippydriver_driver/utils/common.dart';

class ForgotPasswordController extends GetxController {
  // static const String userType = "DRIVER";

  Rx<TextEditingController> emailEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> otpEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> newPasswordEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> confirmPasswordEditingController =
      TextEditingController().obs;

  /// 1 = enter email, 2 = enter OTP, 3 = set new password.
  RxInt currentStep = 1.obs;

  /// Email that OTP was sent to, carried across steps 2 & 3.
  RxString verifiedEmail = ''.obs;

  RxBool isLoading = false.obs;

  // ---------------------------------------------------------------------
  // Resend-OTP countdown
  // ---------------------------------------------------------------------
  static const int resendDurationSeconds = 102;

  final RxBool canResend = false.obs;
  final RxInt resendSeconds = resendDurationSeconds.obs;
  Timer? _resendTimer;

  void _startResendTimer() {
    _resendTimer?.cancel();
    canResend.value = false;
    resendSeconds.value = resendDurationSeconds;

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendSeconds.value <= 1) {
        resendSeconds.value = 0;
        canResend.value = true;
        timer.cancel();
      } else {
        resendSeconds.value--;
      }
    });
  }

  // ---------------------------------------------------------------------
  // Step 1: send OTP to the entered email
  // ---------------------------------------------------------------------
  Future<void> sendOtp() async {
    final email = emailEditingController.value.text.trim();
    if (email.isEmpty) {
      ShowToastDialog.showToast("Please enter valid email".tr);
      return;
    }

    try {
      final headers = await getHeaders();
      ShowToastDialog.showLoader("Please wait".tr);
      final response = await http.post(
        Uri.parse(
            "${Constant.baseUrl}fm/forgetPasswordForUserTypeBySendingOtpToMail"),
        headers: headers,
        body: jsonEncode({
          "email": email,
          "userType": Constant.userRoleDriver,
        }),
      );
      ShowToastDialog.closeLoader();

      final data = _tryDecode(response.body);
      if (response.statusCode == 200 && data?['status'] == true) {
        verifiedEmail.value = email;
        ShowToastDialog.showToast(
            (data?['message'] ?? "OTP sent successfully").toString().tr);
        currentStep.value = 2;
        _startResendTimer();
      } else {
        ShowToastDialog.showToast(
            (data?['message'] ?? "Failed to send OTP").toString().tr);
      }
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Something went wrong: $e");
    }
  }

  // ---------------------------------------------------------------------
  // Resend OTP
  // ---------------------------------------------------------------------
  Future<void> resendOtp() async {
    try {
      final headers = await getHeaders();
      ShowToastDialog.showLoader("Please wait".tr);
      final response = await http.post(
        Uri.parse(
            "${Constant.baseUrl}fm/forgetPasswordForUserTypeBySendingOtpToMail"),
        headers: headers,
        body: jsonEncode({
          "email": verifiedEmail.value,
          "userType": Constant.userRoleDriver,
        }),
      );
      ShowToastDialog.closeLoader();

      final data = _tryDecode(response.body);
      if (response.statusCode == 200 && data?['status'] == true) {
        otpEditingController.value.clear();
        ShowToastDialog.showToast(
            (data?['message'] ?? "OTP resent").toString().tr);
        _startResendTimer();
      } else {
        ShowToastDialog.showToast(
            (data?['message'] ?? "Failed to resend OTP").toString().tr);
      }
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Something went wrong: $e");
    }
  }

  // ---------------------------------------------------------------------
  // Step 2: verify the OTP entered by the user
  // ---------------------------------------------------------------------
  Future<void> verifyOtp() async {
    final email = verifiedEmail.value;
    final otp = otpEditingController.value.text.trim();
    if (otp.length != 6) {
      ShowToastDialog.showToast("Please enter the 6-digit OTP".tr);
      return;
    }

    try {
      final headers = await getHeaders();
      ShowToastDialog.showLoader("Please wait".tr);
      final response = await http.post(
        Uri.parse("${Constant.baseUrl}fm/validateForgotPasswordOTP"),
        headers: headers,
        body: jsonEncode({
          "email": email,
          "userType": Constant.userRoleDriver,
          "otp": otp,
        }),
      );
      ShowToastDialog.closeLoader();

      final data = _tryDecode(response.body);
      if (response.statusCode == 200 && data?['status'] == true) {
        ShowToastDialog.showToast(
            (data?['message'] ?? "OTP validated successfully").toString().tr);
        _resendTimer?.cancel();
        currentStep.value = 3;
      } else {
        ShowToastDialog.showToast(
            (data?['message'] ?? "Invalid OTP").toString().tr);
      }
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Something went wrong: $e");
    }
  }

  // ---------------------------------------------------------------------
  // Step 3: set the new password
  // ---------------------------------------------------------------------
  Future<void> updatePassword() async {
    final email = verifiedEmail.value;
    final newPassword = newPasswordEditingController.value.text.trim();
    final confirmPassword = confirmPasswordEditingController.value.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      ShowToastDialog.showToast("Please fill in all fields".tr);
      return;
    }
    if (newPassword.length < 6) {
      ShowToastDialog.showToast("Password must be at least 6 characters".tr);
      return;
    }
    if (newPassword != confirmPassword) {
      ShowToastDialog.showToast("Passwords do not match".tr);
      return;
    }

    try {
      final headers = await getHeaders();
      ShowToastDialog.showLoader("Please wait".tr);
      final response = await http.post(
        Uri.parse("${Constant.baseUrl}fm/updateForgotPassword"),
        headers: headers,
        body: jsonEncode({
          "email": email,
          "userType": Constant.userRoleDriver,
          "newPassword": newPassword,
        }),
      );
      ShowToastDialog.closeLoader();

      final data = _tryDecode(response.body);
      if (response.statusCode == 200 && data?['status'] == true) {
        ShowToastDialog.showToast(
            (data?['message'] ?? "Password updated successfully")
                .toString()
                .tr);
        // Pop everything back to the login screen.
        Get.until((route) => route.isFirst);
      } else {
        ShowToastDialog.showToast(
            (data?['message'] ?? "Failed to update password").toString().tr);
      }
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Something went wrong: $e");
    }
  }

  /// Lets the user step back to re-enter the email or OTP.
  void goToStep(int step) {
    currentStep.value = step;
  }

  Map<String, dynamic>? _tryDecode(String source) {
    try {
      return jsonDecode(source) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  void onClose() {
    _resendTimer?.cancel();
    emailEditingController.value.dispose();
    otpEditingController.value.dispose();
    newPasswordEditingController.value.dispose();
    confirmPasswordEditingController.value.dispose();
    super.onClose();
  }
}
