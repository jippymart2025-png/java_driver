import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';

import '../../../themes/app_them_data.dart';

class SelfieCard extends StatelessWidget {
  final bool isDark;
  final bool isUploading;
  final String photoUrl;
  final File? localFile;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const SelfieCard({
    required this.isDark,
    required this.isUploading,
    required this.photoUrl,
    required this.localFile,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocal = localFile != null;
    final hasUrl = photoUrl.trim().isNotEmpty;
    final uploaded = hasLocal || hasUrl;
    final accent = isUploading ? AppThemeData.primary300 : (uploaded ? Colors.green : Colors.orange);
    final status = isUploading
        ? 'Uploading'
        : (uploaded ? 'Uploaded' : 'Pending');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppThemeData.grey900 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accent.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : Colors.grey.shade200)
                      .withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: hasLocal
                        ? Image.file(localFile!, fit: BoxFit.cover)
                        : hasUrl
                        ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator()),
                      errorWidget: (_, __, ___) =>
                      const Icon(Icons.person_rounded),
                    )
                        : Container(
                      color: accent.withOpacity(0.1),
                      child: Icon(Icons.face_rounded,
                          color: accent, size: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selfie / Profile Photo'.tr,
                        style: TextStyle(
                          color: isDark
                              ? AppThemeData.grey100
                              : AppThemeData.grey900,
                          fontFamily: AppThemeData.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isUploading ? 'Uploading photo…' : 'Photo',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppThemeData.grey400
                              : AppThemeData.grey600,
                          fontFamily: AppThemeData.regular,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: status == 'Uploading'
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2),
                  )
                      : Text(
                    status,
                    style: TextStyle(
                      color: accent,
                      fontFamily: AppThemeData.medium,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (hasLocal && !isUploading)
                  InkWell(
                    onTap: onRemove,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.red.shade400,
                        size: 20,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? AppThemeData.grey500 : AppThemeData.grey400,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
