import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../constant/constant.dart';
import '../../constant/show_toast_dialog 2.dart';
import '../../controllers/login_controller.dart';
import '../../services/audio_player_service.dart';
import '../../themes/app_them_data.dart';
import '../../themes/custom_dialog_box.dart';
import '../../utils/dark_theme_provider.dart';
import '../../utils/fire_store_utils.dart';
import '../../utils/network_image_widget.dart';
import '../auth_screen/login_screen.dart';
import '../verification_screen/verification_screen.dart';
import 'profile_controller.dart';

// ═════════════════════════════════════════════════════════════════════════════
// ProfileScreen
// ═════════════════════════════════════════════════════════════════════════════

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ProfileController());
    final theme = Provider.of<DarkThemeProvider>(context);
    final isDark = theme.getThem();

    return Scaffold(
      backgroundColor: isDark ? AppThemeData.grey900 : const Color(0xFFF2F4F8),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _ProfileSliverAppBar(theme: theme, ctrl: ctrl),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // _ActiveStatusCard(theme: theme, ctrl: ctrl),
                // const SizedBox(height: 22),

                _SectionLabel(label: 'About App'.tr, theme: theme),
                const SizedBox(height: 8),
                _AboutAppCard(theme: theme, ctrl: ctrl),
                const SizedBox(height: 22),

                _SectionLabel(label: 'App Preferences'.tr, theme: theme),
                const SizedBox(height: 8),
                _PreferencesCard(theme: theme, ctrl: ctrl),
                const SizedBox(height: 22),

                _SectionLabel(label: 'Social'.tr, theme: theme),
                const SizedBox(height: 8),
                _SocialCard(theme: theme),
                const SizedBox(height: 22),

                _SectionLabel(label: 'Legal'.tr, theme: theme),
                const SizedBox(height: 8),
                _LegalCard(theme: theme, ctrl: ctrl),
                const SizedBox(height: 28),

                _LogoutButton(theme: theme),
                const SizedBox(height: 12),
                _DeleteAccountButton(theme: theme),
                const SizedBox(height: 24),

                _VersionLabel(theme: theme),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Sliver App Bar
// ═════════════════════════════════════════════════════════════════════════════

class _ProfileSliverAppBar extends StatelessWidget {
  final DarkThemeProvider theme;
  final ProfileController ctrl;

  const _ProfileSliverAppBar({required this.theme, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.getThem();
    return SliverAppBar(
      expandedHeight: 150,
      pinned: false,
      stretch: true,
      backgroundColor: isDark ? AppThemeData.grey900 : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      // title: Text(
      //   'Profile'.tr,
      //   style: TextStyle(
      //     color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
      //     fontFamily: AppThemeData.semiBold,
      //     fontSize: 18,
      //   ),
      // ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground],
        background: _ProfileHeaderContent(theme: theme, ctrl: ctrl),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Profile Header Content
// ═════════════════════════════════════════════════════════════════════════════

class _ProfileHeaderContent extends StatelessWidget {
  final DarkThemeProvider theme;
  final ProfileController ctrl;

  const _ProfileHeaderContent({required this.theme, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.getThem();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppThemeData.grey900, AppThemeData.grey800]
              : [Colors.white, const Color(0xFFEEF2FF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GetX<ProfileController>(
                builder: (c) {
                  final user = c.dashCtrl.userModel.value;
                  return Expanded(
                    child: Row(
                      children: [
                        _GradientAvatar(
                          imageUrl: user.profilePictureURL?.toString() ?? '',
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                user.fullName(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? AppThemeData.grey50
                                      : AppThemeData.grey900,
                                  fontSize: 20,
                                  fontFamily: AppThemeData.semiBold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? AppThemeData.grey400
                                      : AppThemeData.grey500,
                                  fontSize: 13,
                                  fontFamily: AppThemeData.regular,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ActiveBadge(
                                isActive: user.isActive ?? false,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Gradient Avatar
// ═════════════════════════════════════════════════════════════════════════════

class _GradientAvatar extends StatelessWidget {
  final String imageUrl;
  const _GradientAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppThemeData.primary300, AppThemeData.secondary300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipOval(
        child: NetworkImageWidget(imageUrl: imageUrl, height: 74, width: 74),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Active Badge
// ═════════════════════════════════════════════════════════════════════════════

class _ActiveBadge extends StatelessWidget {
  final bool isActive;
  const _ActiveBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppThemeData.primary300 : AppThemeData.danger300;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(color: color, animate: isActive),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active'.tr : 'Inactive'.tr,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontFamily: AppThemeData.medium,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Pulse Dot
// ═════════════════════════════════════════════════════════════════════════════

class _PulseDot extends StatefulWidget {
  final Color color;
  final bool animate;
  const _PulseDot({required this.color, required this.animate});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(begin: 0.85, end: 1.3).animate(
      CurvedAnimation(parent: _ac, curve: Curves.easeInOut),
    );
    if (widget.animate) _ac.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ac.isAnimating) {
      _ac.repeat(reverse: true);
    } else if (!widget.animate && _ac.isAnimating) {
      _ac.stop();
      _ac.value = 0;
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        height: 7,
        width: 7,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Active Status Card
// ═════════════════════════════════════════════════════════════════════════════

// class _ActiveStatusCard extends StatelessWidget {
//   final DarkThemeProvider theme;
//   final ProfileController ctrl;
//
//   const _ActiveStatusCard({required this.theme, required this.ctrl});
//
//   @override
//   Widget build(BuildContext context) {
//     final isDark = theme.getThem();
//     return _Card(
//       isDark: isDark,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//         child: Row(
//           children: [
//             _IconBox(
//               color: AppThemeData.primary300,
//               child: const Icon(
//                 CupertinoIcons.checkmark_shield_fill,
//                 color: AppThemeData.primary300,
//                 size: 18,
//               ),
//             ),
//             const SizedBox(width: 14),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Available Status'.tr,
//                     style: TextStyle(
//                       color: isDark
//                           ? AppThemeData.grey100
//                           : AppThemeData.grey800,
//                       fontFamily: AppThemeData.semiBold,
//                       fontSize: 14,
//                     ),
//                   ),
//                   const SizedBox(height: 2),
//                   Text(
//                     'Toggle your availability for orders'.tr,
//                     style: TextStyle(
//                       color: isDark
//                           ? AppThemeData.grey400
//                           : AppThemeData.grey500,
//                       fontFamily: AppThemeData.regular,
//                       fontSize: 12,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(width: 10),
//             Transform.scale(
//               scale: 0.85,
//               child: GetX<ProfileController>(
//                 builder: (c) => CupertinoSwitch(
//                   value: c.dashCtrl.userModel.value.isActive ?? false,
//                   activeColor: AppThemeData.primary300,
//                   onChanged: (val) => c.toggleActive(val, theme),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// ═════════════════════════════════════════════════════════════════════════════
// About App Card
// ═════════════════════════════════════════════════════════════════════════════

class _AboutAppCard extends StatelessWidget {
  final DarkThemeProvider theme;
  final ProfileController ctrl;

  const _AboutAppCard({required this.theme, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isVendor = Constant.userModel?.vendorID?.isEmpty == true;
    return _MenuCard(
      theme: theme,
      items: [


        _MenuItemData(
          iconAsset: 'assets/icons/ic_profile.svg',
          title: 'Edit Profile'.tr,
          iconColor: AppThemeData.warning300,
          onTap: () => ctrl.navigate(0),
        ),
          _MenuItemData(
            iconAsset: 'assets/icons/ic_notes.svg',
            title: 'Document Verification'.tr,
            iconColor: AppThemeData.warning300,
            onTap: () => ctrl.navigate(1),
          ),
        // _MenuItemData(
        //   iconAsset: 'assets/icons/ic_focus.svg',
        //   title: 'WithdrawMethod Setup'.tr,
        //   onTap: () => ctrl.navigate(4),
        // ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Preferences Card
// ═════════════════════════════════════════════════════════════════════════════

class _PreferencesCard extends StatelessWidget {
  final DarkThemeProvider theme;
  final ProfileController ctrl;

  const _PreferencesCard({required this.theme, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.getThem();
    return _MenuCard(
      theme: theme,
      items: [
        // _MenuItemData(
        //   iconAsset: 'assets/icons/ic_change_language.svg',
        //   title: 'Change Language'.tr,
        //   onTap: () => ctrl.navigate(6),
        // ),
      ],
      extraBottom: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _IconBox(
              color: AppThemeData.primary300,
              child: SvgPicture.asset(
                'assets/icons/ic_light_dark.svg',
                width: 18,
                colorFilter: const ColorFilter.mode(
                    AppThemeData.primary300, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Dark Mode'.tr,
                style: TextStyle(
                  color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                  fontFamily: AppThemeData.semiBold,
                  fontSize: 14,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.85,
              child: GetX<ProfileController>(
                builder: (c) => CupertinoSwitch(
                  value: c.isDarkMode.value,
                  activeColor: AppThemeData.primary300,
                  onChanged: (val) => c.toggleDarkMode(val, theme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Social Card
// ═════════════════════════════════════════════════════════════════════════════

class _SocialCard extends StatelessWidget {
  final DarkThemeProvider theme;
  const _SocialCard({required this.theme});

  Future<void> _handleRateApp() async {
    final inAppReview = InAppReview.instance;
    // Play/App Store listing is the most reliable path; in-app prompt can be
    // silently throttled by store-side policy even when requestReview succeeds.
    try {
      await inAppReview.openStoreListing(
        appStoreId: '6755069616',
      );
    } catch (_) {
      try {
        final isAvailable = await inAppReview.isAvailable();
        if (isAvailable) {
          await inAppReview.requestReview();
          return;
        }
      } catch (_) {}
      ShowToastDialog.showToast('Unable to open app rating. Please try again later.'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _MenuCard(
      theme: theme,
      items: [
        _MenuItemData(
          iconAsset: 'assets/icons/ic_share.svg',
          title: 'Share app'.tr,
          onTap: () => Share.share(
            '${'Check out JippyMart, your ultimate food delivery application!'.tr}'
                '\n\n${'Google Play:'.tr} ${Constant.googlePlayLink}',
            subject: 'Look what I made!'.tr,
          ),
        ),
        _MenuItemData(
          iconAsset: 'assets/icons/ic_rate.svg',
          title: 'Rate the app'.tr,
          onTap: () => _handleRateApp(),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Legal Card
// ═════════════════════════════════════════════════════════════════════════════

class _LegalCard extends StatelessWidget {
  final DarkThemeProvider theme;
  final ProfileController ctrl;
  const _LegalCard({required this.theme, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return _MenuCard(
      theme: theme,
      items: [
        _MenuItemData(
          iconAsset: 'assets/icons/ic_terms_condition.svg',
          title: 'Terms and Conditions'.tr,
          iconColor: AppThemeData.primary300,
          onTap: () => ctrl.navigate(2),
        ),
        _MenuItemData(
          iconAsset: 'assets/icons/ic_privacyPolicy.svg',
          title: 'Privacy Policy'.tr,
          iconColor: AppThemeData.danger300,
          onTap: () => ctrl.navigate(3),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Logout Button
// ═════════════════════════════════════════════════════════════════════════════

class _LogoutButton extends StatelessWidget {
  final DarkThemeProvider theme;
  const _LogoutButton({required this.theme});

  @override
  Widget build(BuildContext context) {
    return _DangerButton(
      iconAsset: 'assets/icons/ic_logout.svg',
      label: 'Log out'.tr,
      filled: true,
      onTap: () => showDialog(
        context: context,
        builder: (_) => CustomDialogBox(
          title: 'Log out'.tr,
          descriptions:
          'Are you sure you want to log out? You will need to enter your credentials to log back in.'
              .tr,
          positiveString: 'Log out'.tr,
          negativeString: 'Cancel'.tr,
          positiveClick: () async {
            await AudioPlayerService.playSound(false);
            Constant.userModel!.fcmToken = '';
            await FireStoreUtils.updateUser(Constant.userModel!);
            LoginController.logout();
          },
          negativeClick: Get.back,
          img: Image.asset('assets/images/ic_logout.gif',
              height: 50, width: 50),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Delete Account Button
// ═════════════════════════════════════════════════════════════════════════════

class _DeleteAccountButton extends StatelessWidget {
  final DarkThemeProvider theme;
  const _DeleteAccountButton({required this.theme});

  @override
  Widget build(BuildContext context) {
    return _DangerButton(
      iconAsset: 'assets/icons/ic_delete.svg',
      label: 'Delete Account'.tr,
      filled: false,
      onTap: () => showDialog(
        context: context,
        builder: (_) => CustomDialogBox(
          title: 'Delete Account'.tr,
          descriptions:
          'Are you sure you want to delete your account? This action is irreversible and will permanently remove all your data.'
              .tr,
          positiveString: 'Delete'.tr,
          negativeString: 'Cancel'.tr,
          positiveClick: () async {
            ShowToastDialog.showLoader('Please wait'.tr);
            final deleted = await FireStoreUtils.deleteUser();
            ShowToastDialog.closeLoader();
            if (deleted == true) {
              ShowToastDialog.showToast('Account deleted successfully'.tr);
              Get.offAll(const LoginScreen());
            } else {
              ShowToastDialog.showToast('Contact Administrator'.tr);
            }
          },
          negativeClick: Get.back,
          img: Image.asset('assets/icons/delete_dialog.gif',
              height: 50, width: 50),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Version Label
// ═════════════════════════════════════════════════════════════════════════════

class _VersionLabel extends StatelessWidget {
  final DarkThemeProvider theme;
  const _VersionLabel({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'V : ${Constant.appVersion}',
        style: TextStyle(
          fontFamily: AppThemeData.medium,
          fontSize: 13,
          color: theme.getThem() ? AppThemeData.grey500 : AppThemeData.grey400,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ── SHARED PRIMITIVES
// ═════════════════════════════════════════════════════════════════════════════

class _MenuItemData {
  final String iconAsset;
  final String title;
  final Color? iconColor;
  final VoidCallback onTap;

  const _MenuItemData({
    required this.iconAsset,
    required this.title,
    required this.onTap,
    this.iconColor,
  });
}

class _MenuCard extends StatelessWidget {
  final DarkThemeProvider theme;
  final List<_MenuItemData> items;
  final Widget? extraBottom;

  const _MenuCard({
    required this.theme,
    required this.items,
    this.extraBottom,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.getThem();
    final divider = Divider(
      height: 1,
      indent: 54,
      color: isDark ? AppThemeData.grey700 : const Color(0xFFEEEEEE),
    );
    return _Card(
      isDark: isDark,
      child: Column(
        children: [
          ...List.generate(items.length, (i) {
            final showDivider = i < items.length - 1 || extraBottom != null;
            return Column(
              children: [
                _MenuTile(theme: theme, item: items[i]),
                if (showDivider) divider,
              ],
            );
          }),
          if (extraBottom != null) extraBottom!,
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final DarkThemeProvider theme;
  final _MenuItemData item;

  const _MenuTile({required this.theme, required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.getThem();
    final accent = item.iconColor ?? AppThemeData.primary300;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _IconBox(
              color: accent,
              child: SvgPicture.asset(
                item.iconAsset,
                width: 18,
                colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                  fontFamily: AppThemeData.semiBold,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: isDark ? AppThemeData.grey500 : AppThemeData.grey400,
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _Card({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppThemeData.grey800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _IconBox extends StatelessWidget {
  final Color color;
  final Widget child;
  const _IconBox({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(child: child),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final DarkThemeProvider theme;
  const _SectionLabel({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: theme.getThem() ? AppThemeData.grey400 : AppThemeData.grey500,
        fontSize: 11,
        fontFamily: AppThemeData.semiBold,
        letterSpacing: 0.9,
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String iconAsset;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _DangerButton({
    required this.iconAsset,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(
          iconAsset,
          width: 18,
          colorFilter: const ColorFilter.mode(
              AppThemeData.danger300, BlendMode.srcIn),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: AppThemeData.danger300,
            fontFamily:
            filled ? AppThemeData.semiBold : AppThemeData.medium,
            fontSize: filled ? 15 : 13,
          ),
        ),
      ],
    );

    if (!filled) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: inner,
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: AppThemeData.danger300.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppThemeData.danger300.withOpacity(0.22)),
        ),
        child: inner,
      ),
    );
  }
}