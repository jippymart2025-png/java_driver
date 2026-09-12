import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jippydriver_driver/app/auth_screen/screens/login_screen.dart';
import 'package:jippydriver_driver/app/auth_screen/widgets/primartbotton.dart';
import 'package:jippydriver_driver/app/auth_screen/controller/otp_controller.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  Timer? _resendTimer;
  int _secondsLeft = 30;
  bool _canResend = false;

  static const _itemCount = 4; // title, subtitle, otp, resend
  static const _duration = Duration(milliseconds: 500);
  static const _stagger = 70;

  @override
  void initState() {
    super.initState();
    AppLogger.log('OtpScreen initState()', tag: 'Screen');

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
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _secondsLeft = 30;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _canResend = true;
        });
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final isDark = themeChange.getThem();

    return GetX<OtpController>(
      init: OtpController(),
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
                      'Verify your number'.tr,
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
                      'Enter the 6-digit code we sent to your mobile number.'
                          .tr,
                      maxLines: 3,
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
                  const SizedBox(height: 36),

                  // ── OTP input ──────────────────────────────────────────
                  Animated(
                    fade: _fadeAnims[2],
                    slide: _slideAnims[2],
                    child: LayoutBuilder(
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
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          enablePinAutofill: true,
                          autoDismissKeyboard: true,
                          enableActiveFill: true,
                          cursorColor: AppThemeData.secondary300,
                          controller: controller.otpController.value,
                          onCompleted: (v) {
                            HapticFeedback.mediumImpact();
                            controller.verifyOTP();
                          },
                          hintCharacter: '–',
                          hintStyle: TextStyle(
                            color: isDark
                                ? AppThemeData.grey600
                                : AppThemeData.grey400,
                            fontFamily: AppThemeData.regular,
                          ),
                          textStyle: TextStyle(
                            fontSize: 20,
                            fontFamily: AppThemeData.bold,
                            color: isDark
                                ? AppThemeData.grey50
                                : AppThemeData.grey900,
                          ),
                          pinTheme: PinTheme(
                            fieldHeight: 54,
                            fieldWidth: fieldWidth,
                            activeFillColor: isDark
                                ? AppThemeData.grey900
                                : AppThemeData.grey50,
                            selectedFillColor: isDark
                                ? AppThemeData.grey900
                                : AppThemeData.grey50,
                            inactiveFillColor: isDark
                                ? AppThemeData.grey900
                                : AppThemeData.grey50,
                            activeColor: AppThemeData.secondary300,
                            selectedColor: AppThemeData.secondary300,
                            inactiveColor: isDark
                                ? AppThemeData.grey800
                                : AppThemeData.grey200,
                            disabledColor: isDark
                                ? AppThemeData.grey800
                                : AppThemeData.grey200,
                            errorBorderColor: Colors.redAccent,
                            shape: PinCodeFieldShape.box,
                            borderRadius: BorderRadius.circular(12),
                            borderWidth: 1.2,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Resend row ─────────────────────────────────────────
                  Animated(
                    fade: _fadeAnims[3],
                    slide: _slideAnims[3],
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Didn't receive the code? ".tr,
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: AppThemeData.regular,
                              color: isDark
                                  ? AppThemeData.grey400
                                  : AppThemeData.grey600,
                            ),
                          ),
                          if (controller.isSendingOtp.value)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppThemeData.driverApp300,
                                ),
                              ),
                            )
                          else if (_canResend)
                            TextButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                controller.otpController.value.clear();
                                controller.sendOTP();
                                _startResendTimer();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Resend'.tr,
                                style: TextStyle(
                                  color: AppThemeData.driverApp300,
                                  fontFamily: AppThemeData.semiBold,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          else
                            Text(
                              'Resend in ${_secondsLeft}s'.tr,
                              style: TextStyle(
                                fontFamily: AppThemeData.semiBold,
                                fontSize: 13,
                                color: isDark
                                    ? AppThemeData.grey500
                                    : AppThemeData.grey500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Log in link ────────────────────────────────────
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
                            FocusManager.instance.primaryFocus?.unfocus();
                            Get.offAll(
                                  () => const LoginScreen(),
                              transition: Transition.leftToRightWithFade,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            );
                          },
                        text: 'Log in'.tr,
                        style: const TextStyle(
                          color: AppThemeData.secondary300,
                          fontFamily: AppThemeData.semiBold,
                          fontSize: 13,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // ── Verify button ──────────────────────────────────
                  PrimaryButton(
                    isLoading: controller.isVerifying.value,
                    label: 'Verify & Continue'.tr,
                    onTap: () => controller.verifyOTP(),
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

// ─────────────────────────────────────────────────────────────────────────────
// Composable animated wrapper — fade + slide
// ─────────────────────────────────────────────────────────────────────────────
class Animated extends StatelessWidget {
  const Animated({
    required this.fade,
    required this.slide,
    required this.child,
  });

  final Animation<double> fade;
  final Animation<Offset> slide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}