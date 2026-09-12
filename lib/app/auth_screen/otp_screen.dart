import 'package:jippydriver_driver/app/auth_screen/login_screen.dart';
import 'package:jippydriver_driver/controllers/otp_controller.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppLogger.log('OtpScreen build() called', tag: 'Screen');
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final isDark = themeChange.getThem();

    return GetX<OtpController>(
        init: OtpController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: isDark
                ? AppThemeData.surfaceDark
                : AppThemeData.surface,
            appBar: AppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: isDark
                  ? AppThemeData.surfaceDark
                  : AppThemeData.surface,
            ),
            body: controller.isLoading.value
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppThemeData.primary300))
                : SafeArea(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Verify Your Mobile Number".tr,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: isDark
                                    ? AppThemeData.grey50
                                    : AppThemeData.grey900,
                                fontSize: 22,
                                height: 1.2,
                                fontFamily: AppThemeData.semiBold),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Enter the OTP sent to your mobile number to verify and secure your account."
                                .tr,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? AppThemeData.grey200
                                  : AppThemeData.grey700,
                              fontSize: 14,
                              height: 1.4,
                              fontFamily: AppThemeData.regular,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 48),
                          // Responsive OTP boxes: width adapts to screen.
                          LayoutBuilder(
                            builder: (context, constraints) {
                              const length = 6;
                              const gap = 10.0;
                              final fieldWidth = ((constraints.maxWidth -
                                              gap * (length - 1)) /
                                          length)
                                      .clamp(42.0, 52.0)
                                  .toDouble();
                              return PinCodeTextField(
                                length: length,
                                appContext: context,
                                keyboardType: TextInputType.phone,
                                enablePinAutofill: true,
                                autoDismissKeyboard: true,
                                enableActiveFill: true,
                                cursorColor: AppThemeData.secondary300,
                                controller: controller.otpController.value,
                                onCompleted: (v) {
                                  controller.verifyOTP();
                                },
                                hintCharacter: "-",
                                hintStyle: TextStyle(
                                    color: isDark
                                        ? AppThemeData.grey50
                                        : AppThemeData.grey900,
                                    fontFamily: AppThemeData.regular),
                                textStyle: TextStyle(
                                    fontSize: 18,
                                    color: isDark
                                        ? AppThemeData.grey50
                                        : AppThemeData.grey900,
                                    fontFamily: AppThemeData.regular),
                                pinTheme: PinTheme(
                                  fieldHeight: 50,
                                  fieldWidth: fieldWidth,
                                  inactiveFillColor: isDark
                                      ? AppThemeData.grey900
                                      : AppThemeData.grey50,
                                  selectedFillColor: isDark
                                      ? AppThemeData.grey900
                                      : AppThemeData.grey50,
                                  activeFillColor: isDark
                                      ? AppThemeData.grey900
                                      : AppThemeData.grey50,
                                  selectedColor: AppThemeData.secondary300,
                                  activeColor: AppThemeData.secondary300,
                                  inactiveColor: isDark
                                      ? AppThemeData.grey900
                                      : AppThemeData.grey50,
                                  disabledColor: isDark
                                      ? AppThemeData.grey900
                                      : AppThemeData.grey50,
                                  shape: PinCodeFieldShape.box,
                                  errorBorderColor: isDark
                                      ? AppThemeData.grey600
                                      : AppThemeData.grey300,
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(10)),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 36),
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Didn’t receive any code? '.tr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      fontFamily: AppThemeData.medium,
                                      color: isDark
                                          ? AppThemeData.grey100
                                          : AppThemeData.grey800,
                                    ),
                                  ),
                                ),
                                if (controller.isSendingOtp.value)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(left: 8),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color:
                                            AppThemeData.driverApp300,
                                      ),
                                    ),
                                  ) else ...[
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () {
                                      controller.otpController.value.clear();
                                      controller.sendOTP();
                                    },
                                    child: Text(
                                      'Send Again'.tr,
                                      maxLines: 1,
                                      style: TextStyle(
                                          color: AppThemeData.driverApp300,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          fontFamily: AppThemeData.medium,
                                          decoration:
                                              TextDecoration.underline,
                                          decorationColor:
                                              AppThemeData.driverApp300),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            bottomNavigationBar: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text.rich(
                      textAlign: TextAlign.center,
                      TextSpan(
                        children: [
                          TextSpan(
                              text: 'Already Have an account? '.tr,
                              style: TextStyle(
                                color: isDark
                                    ? AppThemeData.grey50
                                    : AppThemeData.grey900,
                                fontFamily: AppThemeData.medium,
                                fontWeight: FontWeight.w500,
                              )),
                          TextSpan(
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Get.offAll(const LoginScreen());
                                },
                              text: 'Log in'.tr,
                              style: const TextStyle(
                                  color: AppThemeData.secondary300,
                                  fontFamily: AppThemeData.medium,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                  decorationColor:
                                      AppThemeData.secondary300)),
                        ],
                      ),
                    ),
                  ),
                  _VerifyButton(
                    isLoading: controller.isVerifying.value,
                    label: 'Verify & Continue'.tr,
                    onTap: () => controller.verifyOTP(),
                  ),
                ],
              ),
            ),
          );
        });
  }
}

class _VerifyButton extends StatelessWidget {
  const _VerifyButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 52,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: isLoading
              ? AppThemeData.driverApp300.withValues(alpha: 0.6)
              : AppThemeData.driverApp300,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppThemeData.grey50,
                  ),
                )
              : Text(
                  label,
                  key: const ValueKey('label'),
                  style: const TextStyle(
                    color: AppThemeData.grey50,
                    fontSize: 16,
                    fontFamily: AppThemeData.semiBold,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}