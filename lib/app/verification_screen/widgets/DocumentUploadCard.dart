import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../../../models/document_model.dart';
import '../../../themes/app_them_data.dart';

class DocumentUploadCard extends StatelessWidget {
  final DocumentModel documentModel;
  final File? file;
  final String uploadedUrl;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const DocumentUploadCard({
    required this.documentModel,
    required this.file,
    required this.uploadedUrl,
    required this.isDark,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocal = file != null;
    final hasUrl = uploadedUrl.trim().isNotEmpty;
    final uploaded = hasLocal || hasUrl;
    final accent = uploaded ? Colors.green : Colors.orange;

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
                // Thumbnail / placeholder
                _buildThumb(uploaded, hasLocal, accent),
                const SizedBox(width: 14),
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${documentModel.title}',
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
                        _sideLabel(),
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
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    uploaded ? 'Uploaded' : 'Pending',
                    style: TextStyle(
                      color: accent,
                      fontFamily: AppThemeData.medium,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (hasLocal)
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
                    color: isDark
                        ? AppThemeData.grey500
                        : AppThemeData.grey400,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumb(bool uploaded, bool hasLocal, Color accent) {
    if (!uploaded) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.badge_rounded, color: accent, size: 26),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 56,
        height: 56,
        child: hasLocal
            ? Image.file(file!, fit: BoxFit.cover)
            : CachedNetworkImage(
          imageUrl: uploadedUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) =>
          const Center(child: CircularProgressIndicator()),
          errorWidget: (_, __, ___) =>
          const Icon(Icons.broken_image),
        ),
      ),
    );
  }

  String _sideLabel() {
    final parts = <String>[];
    if (documentModel.frontSide == true) parts.add('Front');
    if (documentModel.backSide == true) parts.add('Back');
    if (parts.isEmpty) return 'Photo';
    return '${parts.join(' & ')} Photo';
  }
}
