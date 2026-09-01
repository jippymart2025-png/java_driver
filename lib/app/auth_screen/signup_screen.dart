import 'dart:io';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:jippydriver_driver/app/auth_screen/login_screen.dart';
//import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/controllers/signup_controller.dart';
//import 'package:jippydriver_driver/models/zone_model.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
//import 'package:jippydriver_driver/themes/responsive.dart';
import 'package:jippydriver_driver/themes/text_field_widget.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:jippydriver_driver/models/state_model.dart';
import 'package:jippydriver_driver/models/city_model.dart';
import 'package:jippydriver_driver/models/area_model.dart';

import '../SelectLocationScreen/SelectLocationScreen.dart';

/// OPTIMIZATIONS:
/// 1. Single AnimationController replaces 11 separate TweenAnimationBuilders.
/// 2. Validation logic moved to SignupController.validateAndSignup().
/// 3. Extracted reusable widgets (_FieldIcon, _PasswordToggle, _Animated,
///    _PrimaryButton) — shared with LoginScreen to reduce code duplication.
/// 4. Zone dropdown extracted to _ZoneDropdown for clarity.
/// 5. Password section conditionally built once via Obx, not nested widgets.
/// 6. Used const constructors throughout.

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  // title, subtitle, link, name row, email, phone, zone, password, confirm, button
  static const _itemCount = 19;
  static const _duration = Duration(milliseconds: 550);
  static const _stagger = 60; // ms

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
      final start = (_stagger * i) / _animController.duration!.inMilliseconds;
      final end = ((_stagger * i) + _duration.inMilliseconds) /
          _animController.duration!.inMilliseconds;
      return CurvedAnimation(
        parent: _animController,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut),
      );
    });

    _slideAnims = _fadeAnims
        .map((a) => Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(a))
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

    return GetX<SignupController>(
      init: SignupController(),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title ────────────────────────────────────────────
                  _Animated(
                    fade: _fadeAnims[0],
                    slide: _slideAnims[0],
                    child: Text(
                      'Create an Account'.tr,
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
                  const SizedBox(height: 8),

                  // ── Subtitle ─────────────────────────────────────────
                  _Animated(
                    fade: _fadeAnims[1],
                    slide: _slideAnims[1],
                    child: Text(
                      'Sign up now to start your journey as a JippyMart driver and begin earning with every delivery.'
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

                  // ── Login link ───────────────────────────────────────
                  _Animated(
                    fade: _fadeAnims[2],
                    slide: _slideAnims[2],
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: 'Already have an account? '.tr,
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
                            ..onTap = () => Get.offAll(
                                  () => const LoginScreen(),
                              transition: Transition.rightToLeft,
                              duration: const Duration(milliseconds: 280),
                            ),
                          text: 'Log in'.tr,
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
                  const SizedBox(height: 32),

                  // ── First & Last name row ────────────────────────────
                  _Animated(
                    fade: _fadeAnims[3],
                    slide: _slideAnims[3],
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFieldWidget(
                            title: 'First Name'.tr,
                            controller:
                            controller.firstNameEditingController.value,
                            hintText: 'First Name'.tr,
                            textInputAction: TextInputAction.next,
                            prefix: _FieldIcon(
                              asset: 'assets/icons/ic_user.svg',
                              isDark: isDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFieldWidget(
                            title: 'Last Name'.tr,
                            controller:
                            controller.lastNameEditingController.value,
                            hintText: 'Last Name'.tr,
                            textInputAction: TextInputAction.next,
                            prefix: _FieldIcon(
                              asset: 'assets/icons/ic_user.svg',
                              isDark: isDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Email ────────────────────────────────────────────
                  _Animated(
                    fade: _fadeAnims[4],
                    slide: _slideAnims[4],
                    child: Obx(() => TextFieldWidget(
                      title: 'Email Address'.tr,
                      textInputType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      controller: controller.emailEditingController.value,
                      hintText: 'Enter Email Address'.tr,
                      enable: controller.type.value != 'google' &&
                          controller.type.value != 'apple',
                      prefix: _FieldIcon(
                        asset: 'assets/icons/ic_mail.svg',
                        isDark: isDark,
                      ),
                    )),
                  ),
                  const SizedBox(height: 16),

                  // ── Phone number ─────────────────────────────────────
                  _Animated(
                    fade: _fadeAnims[5],
                    slide: _slideAnims[5],
                    child: Obx(() => TextFieldWidget(
                      title: 'Phone Number'.tr,
                      controller:
                      controller.phoneNUmberEditingController.value,
                      hintText: 'Enter Phone Number'.tr,
                      enable: controller.type.value != 'mobileNumber',
                      textInputType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10), // 👈 limit to 10 digits

                      ],
                      prefix: CountryCodePicker(
                        enabled: controller.type.value != 'mobileNumber',
                        onChanged: (value) {
                          controller.countryCodeEditingController.value
                              .text = value.dialCode.toString();
                        },
                        initialSelection: controller
                            .countryCodeEditingController.value.text,
                        countryFilter: const ['IN'],
                        showDropDownButton: false,
                        showFlag: true,
                        textStyle: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppThemeData.grey50
                              : AppThemeData.grey900,
                          fontFamily: AppThemeData.medium,
                        ),
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
                      ),
                    )),
                  ),
                  const SizedBox(height: 16),

                  //----------------Nominee Name--------------------

                    _Animated(
                    fade: _fadeAnims[6],
                    slide: _slideAnims[6],
                    child: TextFieldWidget(
                      title: 'Nominee Name'.tr,
                      controller: controller.nomineeNameEditingController.value,
                      hintText: 'Enter Nominee Name'.tr,
                      textInputAction: TextInputAction.next,
                      prefix: _FieldIcon(
                        asset: 'assets/icons/ic_user.svg',
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),


                  //--------------Nominee Phone Number---------
                  _Animated(
                    fade: _fadeAnims[7],
                    slide: _slideAnims[7],
                    child: TextFieldWidget(
                      title: 'Nominee Phone Number'.tr,
                      controller: controller.nomineePhoneEditingController.value,
                      hintText: 'Enter Nominee Phone Number'.tr,
                      textInputType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      prefix: _FieldIcon(
                        asset: 'assets/icons/ic_call.svg',
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  //-----------Family Member Name--------

                  _Animated(
                    fade: _fadeAnims[8],
                    slide: _slideAnims[8],
                    child: TextFieldWidget(
                      title: 'Family Member Name'.tr,
                      controller: controller.familyMemberNameEditingController.value,
                      hintText: 'Enter Family Member Name'.tr,
                      textInputAction: TextInputAction.next,
                      prefix: _FieldIcon(
                        asset: 'assets/icons/ic_user.svg',
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  //----------- Family Member Phone Number------
                  _Animated(
                    fade: _fadeAnims[9],
                    slide: _slideAnims[9],
                    child: TextFieldWidget(
                      title: 'Family Member Phone Number'.tr,
                      controller: controller.familyMemberPhoneEditingController.value,
                      hintText: 'Enter Family Member Phone Number'.tr,
                      textInputType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      prefix: _FieldIcon(
                        asset: 'assets/icons/ic_call.svg',
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  //--------Aadhar Number---------
                  _Animated(
                    fade: _fadeAnims[10],
                    slide: _slideAnims[10],
                    child: TextFieldWidget(
                      title: 'Aadhar Number'.tr,
                      controller: controller.aadharNumberEditingController.value,
                      hintText: 'XXXX XXXX XXXX',
                      textInputType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                        //AadhaarInputFormatter(),
                      ],
                      prefix: _FieldIcon(
                        asset: 'assets/icons/ic_user.svg',
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    // child: Text(
                    //   'Format: 1234 5678 9012',
                    //   style: TextStyle(
                    //     fontSize: 12,
                    //     color: isDark
                    //         ? AppThemeData.grey400
                    //         : AppThemeData.grey600,
                    //   ),
                    // ),
                  ),
                  const SizedBox(height: 16),

                  //--------Driving License Number---------
                  _Animated(
                    fade: _fadeAnims[11],
                    slide: _slideAnims[11],
                    child: TextFieldWidget(
                      title: 'Driving License Number'.tr,
                      controller: controller.drivingLicenseEditingController.value,
                      hintText: 'Enter Driving License Number'.tr,
                      textInputAction: TextInputAction.next,

                      prefix: _FieldIcon(
                        asset: 'assets/icons/ic_card.svg',
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  //--------RC Number-------
                  _Animated(
                    fade: _fadeAnims[12],
                    slide: _slideAnims[12],
                    child: TextFieldWidget(
                      title: 'RC Number'.tr,
                      controller: controller.rcNumberEditingController.value,
                      hintText: 'Enter RC Number'.tr,
                      textInputAction: TextInputAction.next,
                      prefix: _FieldIcon(
                        asset: 'assets/icons/ic_card.svg',
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  //--------BUILDING NUMBER----------

                  _Animated(
                    fade: _fadeAnims[13],
                    slide: _slideAnims[13],
                    child: TextFieldWidget(
                      title: 'Building Number'.tr,
                      controller:
                      controller.buildingNumberEditingController.value,
                      hintText: 'Select location from map'.tr,

                      readOnly: true,

                      onTap: () async {
                        final result = await Get.to(
                              () => SelectLocationScreen(),
                        );

                        if (result == null) {
                          return;
                        }

                        if (result is Map<String, dynamic>) {
                          controller
                              .buildingNumberEditingController
                              .value
                              .text =
                              result['address']?.toString() ?? '';

                          controller.latitude.value =
                              (result['latitude'] as num?)
                                  ?.toDouble() ??
                                  0.0;

                          controller.longitude.value =
                              (result['longitude'] as num?)
                                  ?.toDouble() ??
                                  0.0;

                          debugPrint(
                            'ADDRESS: '
                                '${controller.buildingNumberEditingController.value.text}',
                          );

                          debugPrint(
                            'LATITUDE: ${controller.latitude.value}',
                          );

                          debugPrint(
                            'LONGITUDE: ${controller.longitude.value}',
                          );
                        }
                      },

                      textInputAction:
                      TextInputAction.next,

                      prefix: _FieldIcon(
                        asset: 'assets/icons/ic_location.svg',
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  //-------ROAD-------
                  _Animated(
                    fade: _fadeAnims[14],
                    slide: _slideAnims[14],
                    child: TextFieldWidget(
                      title: 'Road'.tr,
                      controller: controller.roadEditingController.value,
                      hintText: 'Enter Road Name'.tr,
                      textInputAction: TextInputAction.next,
                      prefix: _FieldIcon(
                        asset: 'assets/icons/ic_location.svg',
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  //--------Landmark------
                  _Animated(
                    fade: _fadeAnims[15],
                    slide: _slideAnims[15],
                    child: TextFieldWidget(
                      title: 'Landmark'.tr,
                      controller: controller.landmarkEditingController.value,
                      hintText: 'Enter Landmark'.tr,
                      textInputAction: TextInputAction.next,
                      prefix: _FieldIcon(
                        asset: 'assets/icons/ic_location.svg',
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  //----Location-----
                  Text(
                    'Location'.tr,
                    style: TextStyle(
                      fontFamily: AppThemeData.semiBold,
                      fontSize: 16,
                      color: isDark
                          ? AppThemeData.grey100
                          : AppThemeData.grey900,
                    ),
                  ),
                  const SizedBox(height: 12),

                  //-------State Dropdown
                  //-------State + City
                  _Animated(
                    fade: _fadeAnims[16],
                    slide: _slideAnims[16],
                    child: Column(
                      children: [

                        // STATE DROPDOWN
                        Obx(
                              () => DropdownButtonFormField<StateModel>(
                            value: controller.selectedState.value,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            hint: const Text('Select State'),
                            items: controller.stateList.map((state) {
                              return DropdownMenuItem<StateModel>(
                                value: state,
                                child: Text(state.stateName),
                              );
                            }).toList(),
                                onChanged: (value) {
                                  controller.selectedState.value = value;

                                  controller.selectedCity.value = null;
                                  controller.cityList.clear();

                                  controller.selectedArea.value = null;
                                  controller.areaList.clear();

                                  if (value != null) {
                                    controller.fetchCities(value.stateId!);
                                  }
                                },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // CITY DROPDOWN
                        Obx(
                              () => DropdownButtonFormField<CityModel>(
                            value: controller.selectedCity.value,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            hint: const Text('Select City'),
                            items: controller.cityList.map((city) {
                              return DropdownMenuItem<CityModel>(
                                value: city,
                                  child: Text(city.cityName ?? ''),
                              );
                            }).toList(),
                            onChanged: (value) {
                              controller.selectedCity.value = value;
                              controller.selectedArea.value = null;

                              controller.areaList.clear();

                              if (value != null) {
                                controller.fetchAreas(value.cityId!);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  //-----Area Dropdown
                  _Animated(
                    fade: _fadeAnims[17],
                    slide: _slideAnims[17],
                    child: Obx(
                          () => DropdownButtonFormField<AreaModel>(
                        value: controller.selectedArea.value,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Select Area'),
                        items: controller.areaList.map((area) {
                          return DropdownMenuItem<AreaModel>(
                            value: area,
                            child: Text(area.areaName ?? ''),
                          );
                        }).toList(),
                        onChanged: (value) {
                          controller.selectedArea.value = value;
                        },
                      ),
                    ),
                  ),




                  // ── Zone dropdown ────────────────────────────────────
                  // _Animated(
                  //   fade: _fadeAnims[6],
                  //   slide: _slideAnims[6],
                  //   child: _ZoneDropdown(
                  //     controller: controller,
                  //     isDark: isDark,
                  //   ),
                  // ),
                  const SizedBox(height: 16),

                  // ── Password fields (email signup only) ──────────────
                  _Animated(
                    fade: _fadeAnims[18],
                    slide: _slideAnims[18],
                    child: Obx(() {
                      final isThirdParty = controller.type.value == 'google' ||
                          controller.type.value == 'apple' ||
                          controller.type.value == 'mobileNumber';
                      if (isThirdParty) return const SizedBox.shrink();
                      return Column(
                        children: [
                          // Password
                          Obx(() => TextFieldWidget(
                            title: 'Password'.tr,
                            controller:
                            controller.passwordEditingController.value,
                            hintText: 'Enter Password'.tr,
                            obscureText: controller.passwordVisible.value,
                            textInputAction: TextInputAction.next,
                            prefix: _FieldIcon(
                              asset: 'assets/icons/ic_lock.svg',
                              isDark: isDark,
                            ),
                            suffix: _PasswordToggle(
                              visible: controller.passwordVisible.value,
                              isDark: isDark,
                              onTap: () => controller
                                  .passwordVisible.value = !controller
                                  .passwordVisible.value,
                            ),
                          )),

                          const SizedBox(height: 16),
                          // Confirm password
                          Obx(() => TextFieldWidget(
                            title: 'Confirm Password'.tr,
                            controller: controller
                                .conformPasswordEditingController.value,
                            hintText: 'Re-enter Password'.tr,
                            obscureText:
                            controller.conformPasswordVisible.value,
                            textInputAction: TextInputAction.done,
                            prefix: _FieldIcon(
                              asset: 'assets/icons/ic_lock.svg',
                              isDark: isDark,
                            ),
                            suffix: _PasswordToggle(
                              visible:
                              controller.conformPasswordVisible.value,
                              isDark: isDark,
                              onTap: () => controller
                                  .conformPasswordVisible.value =
                              !controller
                                  .conformPasswordVisible.value,
                            ),
                          )),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _SignupButton(controller: controller),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Signup CTA button
// ─────────────────────────────────────────────────────────────────────────────
class _SignupButton extends StatelessWidget {
  const _SignupButton({required this.controller});
  final SignupController controller;

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
          label: 'Sign up'.tr,
          onTap: () => controller.validateAndSignup(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Zone dropdown — extracted for readability
// ─────────────────────────────────────────────────────────────────────────────
// class _ZoneDropdown extends StatelessWidget {
//   const _ZoneDropdown({
//     required this.controller,
//     required this.isDark,
//   });
//   final SignupController controller;
//   final bool isDark;
//
//   OutlineInputBorder _border(Color color) => OutlineInputBorder(
//     borderRadius: BorderRadius.circular(10),
//     borderSide: BorderSide(color: color, width: 1),
//   );
//
//   @override
//   Widget build(BuildContext context) {
//     final borderColor = isDark ? AppThemeData.grey900 : AppThemeData.grey50;
//     final focusBorderColor = AppThemeData.secondary300;
//     final fillColor = isDark ? AppThemeData.grey900 : AppThemeData.grey50;
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Zone'.tr,
//           style: TextStyle(
//             fontFamily: AppThemeData.semiBold,
//             fontSize: 14,
//             color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
//           ),
//         ),
//         const SizedBox(height: 6),
//         Obx(() => DropdownButtonFormField<ZoneModel>(
//           hint: Text(
//             'Select zone'.tr,
//             style: TextStyle(
//               fontSize: 14,
//               color: AppThemeData.grey700,
//               fontFamily: AppThemeData.regular,
//             ),
//           ),
//           decoration: InputDecoration(
//             isDense: true,
//             filled: true,
//             fillColor: fillColor,
//             disabledBorder: _border(borderColor),
//             enabledBorder: _border(borderColor),
//             focusedBorder: _border(focusBorderColor),
//             errorBorder: _border(Colors.red),
//             border: _border(borderColor),
//             contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 12, vertical: 14),
//           ),
//           value: controller.selectedZone.value.id == null
//               ? null
//               : controller.selectedZone.value,
//           onChanged: (value) {
//             if (value != null) controller.selectedZone.value = value;
//           },
//             fontSize: 14,
//             color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
//             fontFamily: AppThemeData.medium,
//           ),
//           items: controller.zoneList.map((zone) {
//             return DropdownMenuItem<ZoneModel>(
//               value: zone,
//               child: Text(zone.name ?? ''),
//             );
//           }).toList(),
//         )),
//       ],
//     );
//   }
// }

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets (same as in login_screen.dart — consider moving to a shared
// file e.g. auth_widgets.dart to avoid duplication in a real project)
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