import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jippydriver_driver/app/verification_screen/widgets/DocumentUploadCard.dart';
import 'package:jippydriver_driver/app/verification_screen/widgets/SelfieCard.dart';
import 'package:provider/provider.dart';

import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/app/verification_screen/controllers/verification_controller.dart';
import 'package:jippydriver_driver/models/document_model.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final bool isDark = themeChange.getThem();

    return GetBuilder<VerificationController>(
      init: VerificationController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor:
          isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          body: SafeArea(
            child: controller.isLoading.value
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(isDark),
                ),
                SliverToBoxAdapter(
                  child: _buildProgressBar(controller, isDark),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final doc = controller.documentList[index];
                        return DocumentUploadCard(
                          documentModel: doc,
                          file: controller.fileForType(doc.id ?? ''),
                          uploadedUrl:
                          _uploadedUrl(controller, doc.id ?? ''),
                          isDark: isDark,
                          onTap: () =>
                              _showSourceSheet(context, controller, doc),
                          onRemove: () =>
                              controller.removeDocument(doc.id ?? ''),
                        );
                      },
                      childCount: controller.documentList.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildSelfieCard(context, controller, isDark),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
          bottomNavigationBar: controller.isLoading.value
              ? const SizedBox.shrink()
              : SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton(
                onPressed: controller.isSubmittingIdentity.value
                    ? null
                    : () async {
                  final ok =
                  await controller.submitIdentityDetails();
                  if (ok) {
                    ShowToastDialog.showToast(
                      'Documents uploaded successfully',
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppThemeData.driverApp300,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: controller.isSubmittingIdentity.value
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  "Submit Details".tr,
                  style: const TextStyle(
                    fontFamily: AppThemeData.semiBold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _uploadedUrl(VerificationController controller, String id) {
    for (final e in controller.driverDocumentList) {
      if (e.documentId == id && (e.frontImage ?? '').trim().isNotEmpty) {
        return e.frontImage!;
      }
    }
    return '';
  }

  void _showSourceSheet(
      BuildContext context,
      VerificationController controller,
      DocumentModel doc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final dark =
        Provider.of<DarkThemeProvider>(ctx, listen: false).getThem();
        return _DocSourceSheet(
          title: 'Upload ${doc.title}'.tr,
          isDark: dark,
          onCamera: () => controller.pickDocument(
              type: doc.id ?? '', source: ImageSource.camera),
          onGallery: () => controller.pickDocument(
              type: doc.id ?? '', source: ImageSource.gallery),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppThemeData.driverApp300.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.verified_user_rounded,
                color: AppThemeData.driverApp300, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            "Document Verification".tr,
            style: TextStyle(
              color: isDark ? AppThemeData.grey100 : AppThemeData.grey900,
              fontFamily: AppThemeData.bold,
              fontSize: 28,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Complete your profile by uploading the required identity documents below."
                .tr,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppThemeData.grey400 : AppThemeData.grey600,
              fontFamily: AppThemeData.regular,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProgressBar(VerificationController controller, bool isDark) {
    final total = controller.documentList.length;
    if (total == 0) return const SizedBox();

    final done = controller.driverDocumentList
        .where((d) => d.status == 'approved' || d.status == 'uploaded')
        .length;
    final progress = (done / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$done of $total uploaded",
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: AppThemeData.medium,
                  color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                ),
              ),
              Text(
                "${(progress * 100).toInt()}%",
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: AppThemeData.bold,
                  color: AppThemeData.driverApp300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark
                  ? AppThemeData.grey800
                  : AppThemeData.grey200,
              valueColor:
              AlwaysStoppedAnimation<Color>(AppThemeData.driverApp300),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSelfieCard(
      BuildContext context,
      VerificationController controller,
      bool isDark) {
    return SelfieCard(
      isDark: isDark,
      isUploading: controller.isUploadingProfilePic.value,
      photoUrl: controller.profilePicUrl.value,
      localFile: controller.profilePicFile.value,
      onTap: () => _showProfilePicSourceSheet(context, controller),
      onRemove: () => controller.clearProfilePic(),
    );
  }

  void _showProfilePicSourceSheet(
      BuildContext context, VerificationController controller) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final dark =
        Provider.of<DarkThemeProvider>(ctx, listen: false).getThem();
        return _DocSourceSheet(
          title: 'Upload Selfie / Profile Photo'.tr,
          isDark: dark,
          onCamera: () =>
              controller.pickProfilePic(source: ImageSource.camera),
          onGallery: () =>
              controller.pickProfilePic(source: ImageSource.gallery),
        );
      },
    );
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// Source Sheet (camera / gallery picker)
// ─────────────────────────────────────────────────────────────────────────────
class _DocSourceSheet extends StatelessWidget {
  final String title;
  final bool isDark;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _DocSourceSheet({
    required this.title,
    required this.isDark,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontFamily: AppThemeData.bold,
              fontSize: 16,
              color: isDark ? AppThemeData.grey100 : AppThemeData.grey900,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SourceOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera'.tr,
                isDark: isDark,
                onTap: onCamera,
              ),
              _SourceOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery'.tr,
                isDark: isDark,
                onTap: onGallery,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppThemeData.driverApp300.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppThemeData.driverApp300, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppThemeData.medium,
              fontSize: 13,
              color: isDark ? AppThemeData.grey300 : AppThemeData.grey700,
            ),
          ),
        ],
      ),
    );
  }
}