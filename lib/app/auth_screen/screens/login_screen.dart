import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:jippydriver_driver/app/auth_screen/screens/phone_number_screen.dart';
import 'package:jippydriver_driver/app/auth_screen/screens/signup_screen.dart';
import 'package:jippydriver_driver/app/forgot_password_screen/forgot_password_screen.dart';
import 'package:jippydriver_driver/app/auth_screen/controller/login_controller.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/themes/text_field_widget.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  static const _itemCount = 6; // title, subtitle, link, email, password, forgot
  static const _duration = Duration(milliseconds: 500);
  static const _stagger = 70;

  @override
  void initState() {
    super.initState();
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

    return GetX<LoginController>(
      init: LoginController(),
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
                  _Animated(
                    fade: _fadeAnims[0],
                    slide: _slideAnims[0],
                    child: Text(
                      'Welcome back 👋'.tr,
                      style: TextStyle(
                        color:
                        isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                        fontSize: 28,
                        fontFamily: AppThemeData.bold,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Subtitle ───────────────────────────────────────────
                  _Animated(
                    fade: _fadeAnims[1],
                    slide: _slideAnims[1],
                    child: Text(
                      'Sign in to continue managing your deliveries'.tr,
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
                  _Animated(
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

                  // ── Email field ────────────────────────────────────────
                  _Animated(
                    fade: _fadeAnims[3],
                    slide: _slideAnims[3],
                    child: TextFieldWidget(
                      title: 'Email Address'.tr,
                      controller: controller.emailEditingController.value,
                      hintText: 'you@example.com'.tr,
                      textInputType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefix: _FieldIcon(
                        asset: 'assets/icons/ic_mail.svg',
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Password field ─────────────────────────────────────
                  _Animated(
                    fade: _fadeAnims[4],
                    slide: _slideAnims[4],
                    child: Obx(() => TextFieldWidget(
                      title: 'Password'.tr,
                      controller:
                      controller.passwordEditingController.value,
                      hintText: 'Enter your password'.tr,
                      obscureText: controller.passwordVisible.value,
                      textInputAction: TextInputAction.done,
                      prefix: _FieldIcon(
                        asset: 'assets/icons/ic_lock.svg',
                        isDark: isDark,
                      ),
                      suffix: _PasswordToggle(
                        visible: controller.passwordVisible.value,
                        isDark: isDark,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          controller.passwordVisible.value =
                          !controller.passwordVisible.value;
                        },
                      ),
                    )),
                  ),
                  const SizedBox(height: 12),

                  // ── Forgot password ────────────────────────────────────
                  _Animated(
                    fade: _fadeAnims[5],
                    slide: _slideAnims[5],
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Get.to(
                                () => const ForgotPasswordScreen(),
                            transition: Transition.rightToLeftWithFade,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot Password?'.tr,
                          style: const TextStyle(
                            color: AppThemeData.secondary300,
                            fontSize: 13,
                            fontFamily: AppThemeData.semiBold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Primary: Log in ────────────────────────────────────
                  _PrimaryButton(
                    label: 'Log in'.tr,
                    onTap: () => controller.validateAndLogin(),
                  ),

                  const SizedBox(height: 24),

                  // ── Divider with "or" ──────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: isDark
                              ? AppThemeData.grey800
                              : AppThemeData.grey200,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or'.tr,
                          style: TextStyle(
                            color: isDark
                                ? AppThemeData.grey500
                                : AppThemeData.grey500,
                            fontSize: 12,
                            fontFamily: AppThemeData.medium,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: isDark
                              ? AppThemeData.grey800
                              : AppThemeData.grey200,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Secondary: Phone login ─────────────────────────────
                  const LoginWithPhoneButton(),

                  const SizedBox(height: 32),
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
// Secondary button — Log in with Mobile Number
// ─────────────────────────────────────────────────────────────────────────────
class LoginWithPhoneButton extends StatelessWidget {
  const LoginWithPhoneButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<DarkThemeProvider>(context).getThem();

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          Get.to(
                () => const PhoneNumberScreen(),
            transition: Transition.rightToLeftWithFade,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        },
        icon: Icon(
          Icons.phone_iphone_rounded,
          size: 20,
          color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
        ),
        label: Text(
          'Log in with Mobile Number'.tr,
          style: TextStyle(
            fontSize: 15,
            fontFamily: AppThemeData.semiBold,
            color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor:
          isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          side: BorderSide(
            color: isDark ? AppThemeData.grey800 : AppThemeData.grey200,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Primary button with press-scale + optional loading
// ─────────────────────────────────────────────────────────────────────────────
class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isLoading ? null : (_) => _ctrl.forward(),
      onTapUp: widget.isLoading
          ? null
          : (_) {
        _ctrl.reverse();
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: AppThemeData.driverApp300,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppThemeData.driverApp300.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(AppThemeData.grey50),
            ),
          )
              : Text(
            widget.label,
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

// ─────────────────────────────────────────────────────────────────────────────
// Composable animated wrapper — single source of truth for fade + slide
// ─────────────────────────────────────────────────────────────────────────────
class _Animated extends StatelessWidget {
  const _Animated({
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared field icon
// ─────────────────────────────────────────────────────────────────────────────
class _FieldIcon extends StatelessWidget {
  const _FieldIcon({required this.asset, required this.isDark});

  final String asset;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SvgPicture.asset(
        asset,
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(
          isDark ? AppThemeData.grey400 : AppThemeData.grey500,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Password visibility toggle with AnimatedSwitcher
// ─────────────────────────────────────────────────────────────────────────────
class _PasswordToggle extends StatelessWidget {
  const _PasswordToggle({
    required this.visible,
    required this.isDark,
    required this.onTap,
  });

  final bool visible;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: SvgPicture.asset(
            visible
                ? 'assets/icons/ic_password_show.svg'
                : 'assets/icons/ic_password_close.svg',
            key: ValueKey(visible),
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              isDark ? AppThemeData.grey400 : AppThemeData.grey500,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}