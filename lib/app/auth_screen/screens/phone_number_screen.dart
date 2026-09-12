import 'dart:io';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jippydriver_driver/app/auth_screen/screens/login_screen.dart';
import 'package:jippydriver_driver/app/auth_screen/screens/signup_screen.dart';
import 'package:jippydriver_driver/app/auth_screen/widgets/primartbotton.dart';
import 'package:jippydriver_driver/controllers/phone_number_controller.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/themes/text_field_widget.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:provider/provider.dart';
import 'otp_screen.dart';

class PhoneNumberScreen extends StatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  State<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  static const _itemCount = 4; // title, subtitle, link, phone field
  static const _duration = Duration(milliseconds: 500);
  static const _stagger = 70;

  @override
  void initState() {
    super.initState();
    AppLogger.log('PhoneNumberScreen initState()', tag: 'Screen');

    _animController = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds:
          _duration.inMilliseconds + _stagger * (_itemCount - 1)),
    );

    _fadeAnims = List.generate(_itemCount, (i) {
      final total = _animController.duration!.inMilliseconds;
      final start = (_stagger * i) / total;
      final end = ((_stagger * i) + _duration.inMilliseconds) / total;
      return CurvedAnimation(
        parent: _animController,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
      );
    });

    _slideAnims = _fadeAnims
        .map((anim) => Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(anim))
        .toList();

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final isDark = themeChange.getThem();

    return GetX<PhoneNumberController>(
      init: PhoneNumberController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor:
          isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor:
            isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ── Title ──────────────────────────────────────────────
                  Animated(
                    fade: _fadeAnims[0],
                    slide: _slideAnims[0],
                    child: Text(
                      'Enter your mobile number'.tr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                        isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                        fontSize: 26,
                        fontFamily: AppThemeData.bold,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Subtitle ───────────────────────────────────────────
                  Animated(
                    fade: _fadeAnims[1],
                    slide: _slideAnims[1],
                    child: Text(
                      "We'll send you a verification code to confirm it's you."
                          .tr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                        isDark ? AppThemeData.grey400 : AppThemeData.grey600,
                        fontSize: 14,
                        fontFamily: AppThemeData.regular,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Sign-up link ───────────────────────────────────────
                  Animated(
                    fade: _fadeAnims[2],
                    slide: _slideAnims[2],
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: "Don't have an account? ".tr,
                          style: TextStyle(
                            color: isDark
                                ? AppThemeData.grey300
                                : AppThemeData.grey700,
                            fontFamily: AppThemeData.regular,
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              HapticFeedback.lightImpact();
                              Get.to(
                                    () => const SignupScreen(),
                                transition: Transition.rightToLeftWithFade,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                              );
                            },
                          text: 'Sign up'.tr,
                          style: const TextStyle(
                            color: AppThemeData.secondary300,
                            fontFamily: AppThemeData.semiBold,
                            fontSize: 14,
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Phone field ────────────────────────────────────────
                  Animated(
                    fade: _fadeAnims[3],
                    slide: _slideAnims[3],
                    child: TextFieldWidget(
                      title: 'Phone Number'.tr,
                      controller:
                      controller.phoneNUmberEditingController.value,
                      hintText: '00000 00000'.tr,
                      textInputType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(10),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      prefix: CountryCodePicker(
                        onChanged: (value) {
                          controller.countryCodeEditingController.value.text =
                              value.dialCode.toString();
                        },
                        initialSelection: controller
                            .countryCodeEditingController.value.text
                            .isNotEmpty
                            ? controller
                            .countryCodeEditingController.value.text
                            : 'IN',
                        countryFilter: const ['IN'],
                        dialogTextStyle: TextStyle(
                          color: isDark
                              ? AppThemeData.grey50
                              : AppThemeData.grey900,
                          fontWeight: FontWeight.w500,
                          fontFamily: AppThemeData.medium,
                        ),
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
                          fontFamily: AppThemeData.medium,
                        ),
                        searchDecoration: InputDecoration(
                          iconColor: isDark
                              ? AppThemeData.grey50
                              : AppThemeData.grey900,
                        ),
                        searchStyle: TextStyle(
                          color: isDark
                              ? AppThemeData.grey50
                              : AppThemeData.grey900,
                          fontWeight: FontWeight.w500,
                          fontFamily: AppThemeData.medium,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                Platform.isIOS ? 12 : 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Already have account ───────────────────────────
                  Text.rich(
                    textAlign: TextAlign.center,
                    TextSpan(children: [
                      TextSpan(
                        text: 'Already have an account? '.tr,
                        style: TextStyle(
                          color: isDark
                              ? AppThemeData.grey400
                              : AppThemeData.grey600,
                          fontFamily: AppThemeData.regular,
                          fontSize: 13,
                        ),
                      ),
                      TextSpan(
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            HapticFeedback.lightImpact();
                            Get.offAll(
                                  () => const LoginScreen(),
                              transition: Transition.leftToRightWithFade,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            );
                          },
                        text: 'Log in with Email'.tr,
                        style: const TextStyle(
                          color: AppThemeData.secondary300,
                          fontFamily: AppThemeData.semiBold,
                          fontSize: 13,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // ── Send Code button ───────────────────────────────
                  PrimaryButton(
                    isLoading: controller.isSending.value,
                    label: 'Send Code'.tr,
                    onTap: () => controller.sendCode(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

