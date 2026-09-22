import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/controllers/forgot_password_controller.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/themes/responsive.dart';
import 'package:jippydriver_driver/themes/round_button_fill.dart';
import 'package:jippydriver_driver/themes/text_field_widget.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return SafeArea(
      child: GetX<ForgotPasswordController>(
          init: ForgotPasswordController(),
          builder: (controller) {
            return PopScope(
              canPop: controller.currentStep.value == 1,
              child: Scaffold(
                appBar: AppBar(
                  backgroundColor: themeChange.getThem()
                      ? AppThemeData.surfaceDark
                      : AppThemeData.surface,
                ),
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (controller.currentStep.value == 1)
                          _buildEmailStep(controller, themeChange)
                        else if (controller.currentStep.value == 2)
                          _buildOtpStep(controller, themeChange)
                        else
                          _buildResetPasswordStep(controller, themeChange),
                      ],
                    ),
                  ),
                ),
                bottomNavigationBar: _buildBottomButton(
                    controller, themeChange, context),
              ),
            );
          }),
    );
  }

  Widget _buildBottomButton(ForgotPasswordController controller,
      DarkThemeProvider themeChange, BuildContext context) {
    final String title;
    final VoidCallback onTap;
    switch (controller.currentStep.value) {
      case 2:
        title = "Verify OTP".tr;
        onTap = () => controller.verifyOtp();
        break;
      case 3:
        title = "Update Password".tr;
        onTap = () => controller.updatePassword();
        break;
      default:
        title = "Send OTP".tr;
        onTap = () {
          if (controller.emailEditingController.value.text.trim().isEmpty) {
            ShowToastDialog.showToast("Please enter valid email".tr);
          } else {
            controller.sendOtp();
          }
        };
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        color: AppThemeData.driverApp300,
        width: Responsive.width(100, context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppThemeData.grey50,
              fontSize: 16,
              fontFamily: AppThemeData.medium,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Step 1: enter email
  // ---------------------------------------------------------------------
  Widget _buildEmailStep(
      ForgotPasswordController controller, DarkThemeProvider themeChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Forgot Password".tr,
          style: TextStyle(
              color: themeChange.getThem()
                  ? AppThemeData.grey50
                  : AppThemeData.grey900,
              fontSize: 22,
              fontFamily: AppThemeData.semiBold),
        ),
        Text(
          "No worries!! We’ll send you a code to reset your password".tr,
          style: TextStyle(
              color: themeChange.getThem()
                  ? AppThemeData.grey400
                  : AppThemeData.grey500,
              fontSize: 16,
              fontFamily: AppThemeData.regular),
        ),
        const SizedBox(height: 32),
        TextFieldWidget(
          title: 'Email Address'.tr,
          controller: controller.emailEditingController.value,
          hintText: 'Enter email address'.tr,
          prefix: Padding(
            padding: const EdgeInsets.all(12),
            child: SvgPicture.asset(
              "assets/icons/ic_mail.svg",
              colorFilter: ColorFilter.mode(
                themeChange.getThem()
                    ? AppThemeData.grey300
                    : AppThemeData.grey600,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Step 2: enter OTP (6-digit boxed UI)
  // ---------------------------------------------------------------------
  Widget _buildOtpStep(
      ForgotPasswordController controller, DarkThemeProvider themeChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Enter OTP".tr,
          style: TextStyle(
              color: themeChange.getThem()
                  ? AppThemeData.grey50
                  : AppThemeData.grey900,
              fontSize: 22,
              fontFamily: AppThemeData.semiBold),
        ),
        Text(
          "We’ve sent a 6-digit code to ${controller.verifiedEmail.value}",
          style: TextStyle(
              color: themeChange.getThem()
                  ? AppThemeData.grey400
                  : AppThemeData.grey500,
              fontSize: 16,
              fontFamily: AppThemeData.regular),
        ),
        const SizedBox(height: 24),
        _OtpBoxesRow(
          controller: controller,
          isDark: themeChange.getThem(),
        ),
        const SizedBox(height: 24),
        Center(
          child: Obx(
            () => controller.canResend.value
                ? TextButton(
                    onPressed: () => controller.resendOtp(),
                    child: Text(
                      "Resend OTP".tr,
                      style: TextStyle(
                          color: AppThemeData.driverApp300,
                          fontSize: 14,
                          fontFamily: AppThemeData.medium),
                    ),
                  )
                : Text(
                    "Resend in ${controller.resendSeconds.value}s".tr,
                    style: TextStyle(
                        color: themeChange.getThem()
                            ? AppThemeData.grey400
                            : AppThemeData.grey500,
                        fontSize: 14,
                        fontFamily: AppThemeData.regular),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => controller.goToStep(1),
            child: Text(
              "Change Email".tr,
              style: TextStyle(
                  color: themeChange.getThem()
                      ? AppThemeData.grey400
                      : AppThemeData.grey500,
                  fontSize: 14,
                  fontFamily: AppThemeData.medium),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Step 3: set new password
  // ---------------------------------------------------------------------
  Widget _buildResetPasswordStep(
      ForgotPasswordController controller, DarkThemeProvider themeChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Reset Password".tr,
          style: TextStyle(
              color: themeChange.getThem()
                  ? AppThemeData.grey50
                  : AppThemeData.grey900,
              fontSize: 22,
              fontFamily: AppThemeData.semiBold),
        ),
        Text(
          "Set a new password for your account".tr,
          style: TextStyle(
              color: themeChange.getThem()
                  ? AppThemeData.grey400
                  : AppThemeData.grey500,
              fontSize: 16,
              fontFamily: AppThemeData.regular),
        ),
        const SizedBox(height: 32),
        TextFieldWidget(
          title: 'New Password'.tr,
          controller: controller.newPasswordEditingController.value,
          hintText: 'Enter new password'.tr,
          obscureText: true,
          prefix: Padding(
            padding: const EdgeInsets.all(12),
            child: SvgPicture.asset(
              "assets/icons/ic_lock.svg",
              colorFilter: ColorFilter.mode(
                themeChange.getThem()
                    ? AppThemeData.grey300
                    : AppThemeData.grey600,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextFieldWidget(
          title: 'Confirm Password'.tr,
          controller: controller.confirmPasswordEditingController.value,
          hintText: 'Re-enter new password'.tr,
          obscureText: true,
          prefix: Padding(
            padding: const EdgeInsets.all(12),
            child: SvgPicture.asset(
              "assets/icons/ic_lock.svg",
              colorFilter: ColorFilter.mode(
                themeChange.getThem()
                    ? AppThemeData.grey300
                    : AppThemeData.grey600,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        RoundedButtonFill(
          title: "Update Password".tr,
          color: AppThemeData.driverApp300,
          textColor: AppThemeData.grey50,
          onPress: () {
            controller.updatePassword();
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// 6-box OTP input row, synced into controller.otpEditingController
// ---------------------------------------------------------------------
class _OtpBoxesRow extends StatefulWidget {
  final ForgotPasswordController controller;
  final bool isDark;

  const _OtpBoxesRow({required this.controller, required this.isDark});

  @override
  State<_OtpBoxesRow> createState() => _OtpBoxesRowState();
}

class _OtpBoxesRowState extends State<_OtpBoxesRow> {
  static const int otpLength = 6;
  late final List<TextEditingController> _digitControllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _digitControllers =
        List.generate(otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(otpLength, (_) => FocusNode());

    final existing = widget.controller.otpEditingController.value.text;
    for (var i = 0; i < existing.length && i < otpLength; i++) {
      _digitControllers[i].text = existing[i];
    }
  }

  @override
  void dispose() {
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _syncToOtpController() {
    final otp = _digitControllers.map((c) => c.text).join();
    widget.controller.otpEditingController.value.text = otp;
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty) {
      if (index < otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    _syncToOtpController();
  }

  @override
  Widget build(BuildContext context) {
    final boxColor =
        widget.isDark ? AppThemeData.grey800 : const Color(0xFFF5F0EB);
    final textColor =
        widget.isDark ? AppThemeData.grey50 : AppThemeData.grey900;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(otpLength, (index) {
        return SizedBox(
          width: 46,
          height: 52,
          child: TextField(
            controller: _digitControllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontSize: 20,
              fontFamily: AppThemeData.semiBold,
              color: textColor,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: boxColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppThemeData.driverApp300,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (value) => _onChanged(value, index),
          ),
        );
      }),
    );
  }
}
