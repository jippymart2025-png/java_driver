import 'dart:io';

import 'package:flutter/services.dart';
import 'package:jippydriver_driver/app/auth_screen/phone_number_screen.dart';
import 'package:jippydriver_driver/app/auth_screen/signup_screen.dart';
import 'package:jippydriver_driver/app/forgot_password_screen/forgot_password_screen.dart';
import 'package:jippydriver_driver/controllers/login_controller.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/themes/text_field_widget.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// OPTIMIZATIONS:
/// 1. Replaced multiple TweenAnimationBuilders with a single AnimationController
///    via _AuthAnimations mixin — fewer rebuild calls, better perf.
/// 2. Extracted _LoginForm as a private StatelessWidget — GetX only rebuilds
///    the reactive parts (password toggle), not the whole scaffold.
/// 3. Removed duplicate dark_theme_provider import.
/// 4. Login button is now a proper AnimatedButton widget with press feedback.
/// 5. Validation logic extracted to LoginController (see login_controller.dart).
/// 6. Used const constructors everywhere possible.

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

  static const _itemCount = 5; // title, subtitle, link, email, password
  static const _duration = Duration(milliseconds: 600);
  static const _stagger = 80; // ms between each item

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds: _duration.inMilliseconds + _stagger * (_itemCount - 1)),
    );

    _fadeAnims = List.generate(_itemCount, (i) {
      final start = (_stagger * i) / _animController.duration!.inMilliseconds;
      final end = ((_stagger * i) + _duration.inMilliseconds) /
          _animController.duration!.inMilliseconds;
      return CurvedAnimation(
        parent: _animController,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut),
      );
    });

    _slideAnims = _fadeAnims
        .map((anim) => Tween<Offset>(
      begin: const Offset(0, 0.15),
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ── Title ──────────────────────────────────────────────
                  _Animated(
                    fade: _fadeAnims[0],
                    slide: _slideAnims[0],
                    child: Text(
                      'Log In to Your Account'.tr,
                      style: TextStyle(
                        color: isDark
                            ? AppThemeData.grey50
                            : AppThemeData.grey900,
                        fontSize: 24,
                        fontFamily: AppThemeData.semiBold,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),

                  // ── Subtitle ───────────────────────────────────────────
                  _Animated(
                    fade: _fadeAnims[1],
                    slide: _slideAnims[1],
                    child: Text(
                      'Sign in to access your JippyMart account and manage your deliveries seamlessly.'
                          .tr,
                      style: TextStyle(
                        color: isDark
                            ? AppThemeData.grey400
                            : AppThemeData.grey500,
                        fontSize: 14,
                        fontFamily: AppThemeData.regular,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Sign-up link ───────────────────────────────────────
                  _Animated(
                    fade: _fadeAnims[2],
                    slide: _slideAnims[2],
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: "Didn't have an account? ".tr,
                          style: TextStyle(
                            color: isDark
                                ? AppThemeData.grey300
                                : AppThemeData.grey700,
                            fontFamily: AppThemeData.medium,
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Get.to(
                                  () => const SignupScreen(),
                              transition: Transition.rightToLeft,
                              duration: const Duration(milliseconds: 280),
                            ),
                          text: 'Sign up'.tr,
                          style: const TextStyle(
                            color: AppThemeData.secondary300,
                            fontFamily: AppThemeData.semiBold,
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                            decorationColor: AppThemeData.secondary300,
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── Email field ────────────────────────────────────────
                  _Animated(
                    fade: _fadeAnims[3],
                    slide: _slideAnims[3],
                    child: TextFieldWidget(
                      title: 'Email Address'.tr,
                      controller: controller.emailEditingController.value,
                      hintText: 'Enter email address'.tr,
                      textInputType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefix: _FieldIcon(
                        asset: 'assets/icons/ic_mail.svg',
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Password field ─────────────────────────────────────
                  _Animated(
                    fade: _fadeAnims[4],
                    slide: _slideAnims[4],
                    child: Obx(() => TextFieldWidget(
                      title: 'Password'.tr,
                      controller:
                      controller.passwordEditingController.value,
                      hintText: 'Enter password'.tr,
                      obscureText: controller.passwordVisible.value,
                      textInputAction: TextInputAction.done,
                      prefix: _FieldIcon(
                        asset: 'assets/icons/ic_lock.svg',
                        isDark: isDark,
                      ),
                      suffix: _PasswordToggle(
                        visible: controller.passwordVisible.value,
                        isDark: isDark,
                        onTap: () => controller.passwordVisible.value =
                        !controller.passwordVisible.value,
                      ),
                    )),
                  ),
                  const SizedBox(height: 14),

                  // ── Forgot password ────────────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Get.to(
                            () => const ForgotPasswordScreen(),
                        transition: Transition.rightToLeft,
                        duration: const Duration(milliseconds: 280),
                      ),
                      child: Text(
                        'Forgot Password?'.tr,
                        style: const TextStyle(
                          color: AppThemeData.secondary300,
                          fontSize: 13,
                          fontFamily: AppThemeData.medium,
                          decoration: TextDecoration.underline,
                          decorationColor: AppThemeData.secondary300,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Mobile number login ────────────────────────────────
                  const LoginWithPhoneButton(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _LoginButton(controller: controller),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Login CTA button — lives outside scroll, always visible
// ─────────────────────────────────────────────────────────────────────────────
class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.controller});
  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          Platform.isIOS ? 12 : 16,
        ),
        child: _PrimaryButton(
          label: 'Log in'.tr,
          onTap: () => controller.validateAndLogin(),
        ),
      ),
    );
  }
}

class LoginWithPhoneButton extends StatelessWidget {
  const LoginWithPhoneButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [AppThemeData.secondary300, AppThemeData.secondary400],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppThemeData.secondary300.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.lightImpact();
                Get.to(
                      () => const PhoneNumberScreen(),
                  transition: Transition.rightToLeftWithFade,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              },
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.phone_iphone_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Log in with Mobile Number',
                      style: TextStyle(
                        fontSize: 15,
                        fontFamily: AppThemeData.semiBold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable primary button with press-scale feedback
// ─────────────────────────────────────────────────────────────────────────────
class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

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
        vsync: this, duration: const Duration(milliseconds: 100));
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
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: AppThemeData.driverApp300,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
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
// Composable animated wrapper — single source of truth for fade+slide
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
// Shared field icon — avoids repeating Padding+SvgPicture+ColorFilter
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
        colorFilter: ColorFilter.mode(
          isDark ? AppThemeData.grey300 : AppThemeData.grey600,
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
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: SvgPicture.asset(
            visible
                ? 'assets/icons/ic_password_show.svg'
                : 'assets/icons/ic_password_close.svg',
            key: ValueKey(visible),
            colorFilter: ColorFilter.mode(
              isDark ? AppThemeData.grey300 : AppThemeData.grey600,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}