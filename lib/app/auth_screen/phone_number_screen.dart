import 'dart:io';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:jippydriver_driver/app/auth_screen/login_screen.dart';
import 'package:jippydriver_driver/app/auth_screen/signup_screen.dart';
import 'package:jippydriver_driver/controllers/phone_number_controller.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/themes/text_field_widget.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class PhoneNumberScreen extends StatelessWidget {
  const PhoneNumberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppLogger.log('PhoneNumberScreen build() called', tag: 'Screen');
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final isDark = themeChange.getThem();

    return GetX<PhoneNumberController>(
        init: PhoneNumberController(),
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
            body: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Log In Using Your Mobile Number".tr,
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
                      "Enter your mobile number to quickly access your account and start managing your deliveries."
                          .tr,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: isDark
                              ? AppThemeData.grey50
                              : AppThemeData.grey500,
                          fontSize: 14,
                          height: 1.4,
                          fontFamily: AppThemeData.regular),
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Didn’t Have an account?'.tr,
                            style: TextStyle(
                              color: isDark
                                  ? AppThemeData.grey50
                                  : AppThemeData.grey900,
                              fontFamily: AppThemeData.medium,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const WidgetSpan(
                              child: SizedBox(width: 10)),
                          TextSpan(
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Get.to(() => const SignupScreen(),
                                    transition: Transition.rightToLeft,
                                    duration:
                                        const Duration(milliseconds: 280));
                              },
                            text: 'Sign up'.tr,
                            style: const TextStyle(
                                color: AppThemeData.secondary300,
                                fontFamily: AppThemeData.medium,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                                decorationColor:
                                    AppThemeData.secondary300),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextFieldWidget(
                      title: 'Phone Number'.tr,
                      controller: controller.phoneNUmberEditingController.value,
                      hintText: 'Enter Phone Number'.tr,
                      textInputType:
                          const TextInputType.numberWithOptions(
                              signed: true, decimal: true),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(12),
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9]')),
                      ],
                      prefix: CountryCodePicker(
                        onChanged: (value) {
                          controller.countryCodeEditingController.value.text =
                              value.dialCode.toString();
                        },
                        initialSelection:
                            controller.countryCodeEditingController.value.text
                                .isNotEmpty
                            ? controller.countryCodeEditingController.value.text
                            : 'IN', // Default to India
                        countryFilter: ['IN'], // <-- Only allow India
                        dialogTextStyle: TextStyle(
                            color: isDark
                                ? AppThemeData.grey50
                                : AppThemeData.grey900,
                            fontWeight: FontWeight.w500,
                            fontFamily: AppThemeData.medium),
                        dialogBackgroundColor: isDark
                            ? AppThemeData.grey800
                            : AppThemeData.grey100,
                        comparator: (a, b) =>
                            b.name!.compareTo(a.name.toString()),
                        textStyle: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppThemeData.grey50
                                : AppThemeData.grey900,
                            fontFamily: AppThemeData.medium),
                        searchDecoration: InputDecoration(
                            iconColor: isDark
                                ? AppThemeData.grey50
                                : AppThemeData.grey900),
                        searchStyle: TextStyle(
                            color: isDark
                                ? AppThemeData.grey50
                                : AppThemeData.grey900,
                            fontWeight: FontWeight.w500,
                            fontFamily: AppThemeData.medium),
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
                    padding: EdgeInsets.symmetric(
                        vertical: Platform.isAndroid ? 8 : 24),
                    child: Text.rich(
                      textAlign: TextAlign.center,
                      TextSpan(
                        children: [
                          TextSpan(
                              text: 'Already have an account? '.tr,
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
                            text: 'Log in with Email'.tr,
                            style: const TextStyle(
                                color: AppThemeData.secondary300,
                                fontFamily: AppThemeData.medium,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                                decorationColor:
                                    AppThemeData.secondary300),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _PrimaryButton(
                    isLoading: controller.isSending.value,
                    label: 'Send Code'.tr,
                    onTap: () => controller.sendCode(),
                  ),
                ],
              ),
            ),
          );
        });
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
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