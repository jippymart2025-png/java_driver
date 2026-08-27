// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:provider/provider.dart';
//
// import 'package:jippydriver_driver/constant/constant.dart';
// import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
// import 'package:jippydriver_driver/controllers/verification_controller.dart';
// import 'package:jippydriver_driver/models/document_model.dart';
// import 'package:jippydriver_driver/models/driver_document_model.dart';
// import 'package:jippydriver_driver/themes/app_them_data.dart';
// import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
// import 'verification_details_upload_screen.dart';
//
// class VerificationScreen extends StatelessWidget {
//   const VerificationScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final themeChange = Provider.of<DarkThemeProvider>(context);
//     final bool isDark = themeChange.getThem();
//
//     return GetBuilder<VerificationController>(
//       init: VerificationController(),
//       builder: (controller) {
//         return Scaffold(
//           backgroundColor:
//           isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
//           body: SafeArea(
//             child: controller.isLoading.value
//                 ? const Center(child: CircularProgressIndicator())
//                 : CustomScrollView(
//               slivers: [
//                 SliverToBoxAdapter(
//                   child: _buildHeader(isDark),
//                 ),
//                 SliverToBoxAdapter(
//                   child: _buildProgressBar(controller, isDark),
//                 ),
//                 SliverToBoxAdapter(
//                   child: _buildMandatoryIdentityFields(controller, isDark),
//                 ),
//                 SliverPadding(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 16, vertical: 8),
//                   sliver: SliverList(
//                     delegate: SliverChildBuilderDelegate(
//                           (context, index) {
//                         final hasSelfie =
//                             (Constant.userModel?.profilePictureURL ?? "")
//                                 .trim()
//                                 .isNotEmpty;
//                         if (index == controller.documentList.length) {
//                           return _DocumentCard(
//                             documentModel: DocumentModel(
//                               title: "Selfie / Profile Photo",
//                               frontSide: true,
//                               backSide: false,
//                             ),
//                             documents: Documents(
//                               status: hasSelfie ? "uploaded" : "pending",
//                             ),
//                             isDark: isDark,
//                             onTap: () {
//                               if (!_validateMandatoryFields(controller)) {
//                                 return;
//                               }
//                               Get.to(
//                                 const VerificationDetailsUploadScreen(),
//                                 arguments: {
//                                   'selfieOnly': true,
//                                   'aadhaarNumber':
//                                       controller.aadhaarNumberController.text.trim(),
//                                   'drivingLicenseNumber':
//                                       controller.drivingLicenseController.text.trim(),
//                                 },
//                                 transition: Transition.cupertino,
//                               )?.then((value) {
//                                 if (value == true) {
//                                   controller.getDocument();
//                                 }
//                               });
//                             },
//                           );
//                         }
//                         final doc = controller.documentList[index];
//                         final uploadedDoc = _findDocument(
//                             controller.driverDocumentList.toList(), doc);
//                         return _DocumentCard(
//                           documentModel: doc,
//                           documents: uploadedDoc,
//                           isDark: isDark,
//                           onTap: () {
//                             if (!_validateMandatoryFields(controller)) {
//                               return;
//                             }
//                             Get.to(
//                               const VerificationDetailsUploadScreen(),
//                               arguments: {
//                                 'documentModel': doc,
//                                 'aadhaarNumber':
//                                     controller.aadhaarNumberController.text.trim(),
//                                 'drivingLicenseNumber':
//                                     controller.drivingLicenseController.text.trim(),
//                               },
//                               transition: Transition.cupertino,
//                             )?.then((value) {
//                               if (value == true) {
//                                 controller.getDocument();
//                               }
//                             });
//                           },
//                         );
//                       },
//                       childCount: controller.documentList.length + 1,
//                     ),
//                   ),
//                 ),
//                 const SliverToBoxAdapter(
//                     child: SizedBox(height: 24)),
//               ],
//             ),
//           ),
//           bottomNavigationBar: controller.isLoading.value
//               ? const SizedBox.shrink()
//               : SafeArea(
//                   child: Padding(
//                     padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
//                     child: ElevatedButton(
//                       onPressed: controller.isSubmittingIdentity.value
//                           ? null
//                           : () async {
//                               final ok = await controller.submitIdentityDetails();
//                               if (ok) {
//                                 Get.to(() => const _VerificationPendingScreen());
//                               } else {
//                                 ShowToastDialog.showToast(
//                                   "Failed to submit details. Please try again.",
//                                 );
//                               }
//                             },
//                       style: ElevatedButton.styleFrom(
//                         minimumSize: const Size.fromHeight(52),
//                         backgroundColor: AppThemeData.driverApp300,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                       child: controller.isSubmittingIdentity.value
//                           ? const SizedBox(
//                               height: 20,
//                               width: 20,
//                               child: CircularProgressIndicator(
//                                 color: Colors.white,
//                                 strokeWidth: 2,
//                               ),
//                             )
//                           : Text(
//                               "Submit Details".tr,
//                               style: const TextStyle(
//                                 fontFamily: AppThemeData.semiBold,
//                                 fontSize: 15,
//                               ),
//                             ),
//                     ),
//                   ),
//                 ),
//         );
//       },
//     );
//   }
//
//   Documents _findDocument(List<Documents> list, DocumentModel doc) {
//     final match = list.where((e) => e.documentId == doc.id);
//     return match.isNotEmpty ? match.first : Documents();
//   }
//
//   Widget _buildHeader(bool isDark) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             width: 48,
//             height: 48,
//             decoration: BoxDecoration(
//               color: AppThemeData.driverApp300.withOpacity(0.12),
//               borderRadius: BorderRadius.circular(14),
//             ),
//             child: Icon(Icons.verified_user_rounded,
//                 color: AppThemeData.driverApp300, size: 26),
//           ),
//           const SizedBox(height: 12),
//           Text(
//             "Document Verification".tr,
//             style: TextStyle(
//               color: isDark ? AppThemeData.grey100 : AppThemeData.grey900,
//               fontFamily: AppThemeData.bold,
//               fontSize: 28,
//               height: 1.2,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             "Complete your profile by uploading the required identity documents below."
//                 .tr,
//             style: TextStyle(
//               fontSize: 14,
//               color: isDark ? AppThemeData.grey400 : AppThemeData.grey600,
//               fontFamily: AppThemeData.regular,
//               height: 1.5,
//             ),
//           ),
//           const SizedBox(height: 20),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildProgressBar(VerificationController controller, bool isDark) {
//     // Selfie is optional and not part of required verification count.
//     final total = controller.documentList.length;
//     if (total == 0) return const SizedBox();
//
//     final approved = controller.driverDocumentList
//         .where((d) => d.status == "approved")
//         .length;
//     final progress = approved / total;
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 "$approved of $total verified",
//                 style: TextStyle(
//                   fontSize: 13,
//                   fontFamily: AppThemeData.medium,
//                   color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
//                 ),
//               ),
//               Text(
//                 "${(progress * 100).toInt()}%",
//                 style: TextStyle(
//                   fontSize: 13,
//                   fontFamily: AppThemeData.bold,
//                   color: AppThemeData.driverApp300,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           ClipRRect(
//             borderRadius: BorderRadius.circular(100),
//             child: LinearProgressIndicator(
//               value: progress,
//               minHeight: 6,
//               backgroundColor: isDark
//                   ? AppThemeData.grey800
//                   : AppThemeData.grey200,
//               valueColor:
//               AlwaysStoppedAnimation<Color>(AppThemeData.driverApp300),
//             ),
//           ),
//           const SizedBox(height: 16),
//         ],
//       ),
//     );
//   }
//
//   bool _validateMandatoryFields(VerificationController controller) {
//     final aadhaar = controller.aadhaarNumberController.text.trim();
//     final dl = controller.drivingLicenseController.text.trim();
//     if (aadhaar.isEmpty) {
//       ShowToastDialog.showToast("Aadhaar number is required".tr);
//       return false;
//     }
//     if (dl.isEmpty) {
//       ShowToastDialog.showToast("Driving license number is required".tr);
//       return false;
//     }
//     return true;
//   }
//
//   Widget _buildMandatoryIdentityFields(
//       VerificationController controller, bool isDark) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
//       child: Container(
//         padding: const EdgeInsets.all(14),
//         decoration: BoxDecoration(
//           color: isDark ? AppThemeData.grey900 : Colors.white,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(
//             color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
//           ),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               "Required Details".tr,
//               style: TextStyle(
//                 color: isDark ? AppThemeData.grey100 : AppThemeData.grey900,
//                 fontFamily: AppThemeData.semiBold,
//                 fontSize: 14,
//               ),
//             ),
//             const SizedBox(height: 10),
//             TextField(
//               controller: controller.aadhaarNumberController,
//               keyboardType: TextInputType.text,
//               decoration: InputDecoration(
//                 labelText: "Aadhaar Number *".tr,
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 isDense: true,
//               ),
//             ),
//             const SizedBox(height: 10),
//             TextField(
//               controller: controller.drivingLicenseController,
//               keyboardType: TextInputType.text,
//               decoration: InputDecoration(
//                 labelText: "Driving License Number *".tr,
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 isDense: true,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class _VerificationPendingScreen extends StatelessWidget {
//   const _VerificationPendingScreen();
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: SafeArea(
//         child: Center(
//           child: Padding(
//             padding: const EdgeInsets.all(24),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Icon(
//                   Icons.hourglass_top_rounded,
//                   size: 56,
//                   color: AppThemeData.primary300,
//                 ),
//                 const SizedBox(height: 16),
//                 Text(
//                   "Please wait until approval".tr,
//                   style: const TextStyle(
//                     fontSize: 20,
//                     fontFamily: AppThemeData.semiBold,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   "Your verification details were submitted. We will notify you once approved."
//                       .tr,
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(
//                     fontSize: 14,
//                     fontFamily: AppThemeData.regular,
//                   ),
//                 ),
//
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class _DocumentCard extends StatelessWidget {
//   final DocumentModel documentModel;
//   final Documents documents;
//   final bool isDark;
//   final VoidCallback onTap;
//
//   const _DocumentCard({
//     required this.documentModel,
//     required this.documents,
//     required this.isDark,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final status = documents.status ?? "";
//     final statusConfig = _statusConfig(status);
//
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 12),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           onTap: onTap,
//           borderRadius: BorderRadius.circular(16),
//           child: AnimatedContainer(
//             duration: const Duration(milliseconds: 200),
//             decoration: BoxDecoration(
//               color: isDark ? AppThemeData.grey900 : Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(
//                 color: statusConfig['borderColor'] as Color,
//                 width: 1.5,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: (isDark ? Colors.black : Colors.grey.shade200)
//                       .withOpacity(0.5),
//                   blurRadius: 8,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Padding(
//               padding:
//               const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//               child: Row(
//                 children: [
//                   // Icon container
//                   Container(
//                     width: 48,
//                     height: 48,
//                     decoration: BoxDecoration(
//                       color: (statusConfig['color'] as Color).withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Icon(
//                       statusConfig['icon'] as IconData,
//                       color: statusConfig['color'] as Color,
//                       size: 22,
//                     ),
//                   ),
//                   const SizedBox(width: 14),
//                   // Content
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           "${documentModel.title}",
//                           style: TextStyle(
//                             color: isDark
//                                 ? AppThemeData.grey100
//                                 : AppThemeData.grey900,
//                             fontFamily: AppThemeData.bold,
//                             fontSize: 15,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           _sideLabel(),
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: isDark
//                                 ? AppThemeData.grey400
//                                 : AppThemeData.grey600,
//                             fontFamily: AppThemeData.regular,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   // Status badge
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 10, vertical: 5),
//                     decoration: BoxDecoration(
//                       color: (statusConfig['color'] as Color).withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: Text(
//                       statusConfig['label'] as String,
//                       style: TextStyle(
//                         color: statusConfig['color'] as Color,
//                         fontFamily: AppThemeData.medium,
//                         fontSize: 12,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   Icon(
//                     Icons.chevron_right_rounded,
//                     color: isDark ? AppThemeData.grey500 : AppThemeData.grey400,
//                     size: 20,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   String _sideLabel() {
//     final parts = <String>[];
//     if (documentModel.frontSide == true) parts.add("Front");
//     if (documentModel.backSide == true) parts.add("Back");
//     return "${parts.join(' & ')} Photo";
//   }
//
//   Map<String, dynamic> _statusConfig(String status) {
//     switch (status) {
//       case "approved":
//         return {
//           'label': "Verified",
//           'color': Colors.green,
//           'icon': Icons.check_circle_rounded,
//           'borderColor': Colors.green.withOpacity(0.3),
//         };
//       case "rejected":
//         return {
//           'label': "Rejected",
//           'color': Colors.red,
//           'icon': Icons.cancel_rounded,
//           'borderColor': Colors.red.withOpacity(0.3),
//         };
//       case "uploaded":
//         return {
//           'label': "In Review",
//           'color': AppThemeData.primary300,
//           'icon': Icons.hourglass_top_rounded,
//           'borderColor': AppThemeData.primary300.withOpacity(0.3),
//         };
//       default:
//         return {
//           'label': "Pending",
//           'color': Colors.orange,
//           'icon': Icons.upload_file_rounded,
//           'borderColor': Colors.orange.withOpacity(0.2),
//         };
//     }
//   }
// }



// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:provider/provider.dart';
//
// import 'package:jippydriver_driver/constant/constant.dart';
// import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
// import 'package:jippydriver_driver/controllers/verification_controller.dart';
// import 'package:jippydriver_driver/models/document_model.dart';
// import 'package:jippydriver_driver/models/driver_document_model.dart';
// import 'package:jippydriver_driver/themes/app_them_data.dart';
// import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
// import 'verification_details_upload_screen.dart';
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Verification Screen
// // ─────────────────────────────────────────────────────────────────────────────
// class VerificationScreen extends StatelessWidget {
//   const VerificationScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final themeChange = Provider.of<DarkThemeProvider>(context);
//     final bool isDark = themeChange.getThem();
//
//     // Use Get.put so the controller instance is shared and survives
//     // navigation to the upload sub-screen.
//     return GetBuilder<VerificationController>(
//       init: Get.isRegistered<VerificationController>()
//           ? Get.find<VerificationController>()
//           : Get.put(VerificationController()),
//       builder: (controller) {
//         return Obx(() {
//           if (controller.isLoading.value) {
//             return Scaffold(
//               backgroundColor:
//               isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
//               body: const Center(child: CircularProgressIndicator()),
//             );
//           }
//           return Scaffold(
//             backgroundColor:
//             isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
//             body: SafeArea(
//               child: RefreshIndicator(
//                 color: AppThemeData.driverApp300,
//                 onRefresh: () => controller.getDocument(silent: true),
//                 child: CustomScrollView(
//                   physics: const AlwaysScrollableScrollPhysics(
//                     parent: BouncingScrollPhysics(),
//                   ),
//                   cacheExtent: 280,
//                   slivers: [
//                   SliverToBoxAdapter(child: _Header(isDark: isDark)),
//                   SliverToBoxAdapter(
//                     child: _ProgressBar(
//                       controller: controller,
//                       isDark: isDark,
//                     ),
//                   ),
//                   // Identity fields — only editable before submission
//                   SliverToBoxAdapter(
//                     child: _IdentityFields(
//                       controller: controller,
//                       isDark: isDark,
//                     ),
//                   ),
//                   SliverPadding(
//                     padding:
//                     const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                     sliver: SliverList(
//                       delegate: SliverChildBuilderDelegate(
//                         (context, index) => RepaintBoundary(
//                           child: _buildDocItem(
//                               context, index, controller, isDark),
//                         ),
//                         childCount: controller.documentList.length + 1,
//                         addAutomaticKeepAlives: false,
//                         addRepaintBoundaries: false,
//                       ),
//                     ),
//                   ),
//                   const SliverToBoxAdapter(child: SizedBox(height: 24)),
//                 ],
//                 ),
//               ),
//             ),
//             // Show Submit button only when not yet submitted
//             bottomNavigationBar: controller.isSubmitted.value
//                 ? _SubmittedBanner(
//                     isDark: isDark,
//                     isDocumentVerified:
//                         Constant.userModel?.isDocumentVerify == true,
//                   )
//                 : _SubmitButton(controller: controller, isDark: isDark),
//           );
//         });
//       },
//     );
//   }
//
//   Widget _buildDocItem(
//       BuildContext context,
//       int index,
//       VerificationController controller,
//       bool isDark,
//       ) {
//     final isSelfieCard = index == controller.documentList.length;
//
//     if (isSelfieCard) {
//       final hasSelfie =
//           (Constant.userModel?.profilePictureURL ?? '').trim().isNotEmpty;
//       return _DocumentCard(
//         documentModel: DocumentModel(
//           title: 'Selfie / Profile Photo',
//           frontSide: true,
//           backSide: false,
//         ),
//         // Selfie is not sent for admin review — avoid "In Review" like KYC docs.
//         documents: Documents(status: hasSelfie ? 'profile_photo' : 'pending'),
//         isDark: isDark,
//         isLocked: false,
//         onTap: () => _navigateToUpload(
//           context,
//           controller,
//           selfieOnly: true,
//         ),
//       );
//     }
//
//     final doc = controller.documentList[index];
//     final uploaded = controller.findDocument(doc);
//     return _DocumentCard(
//       documentModel: doc,
//       documents: uploaded,
//       isDark: isDark,
//       isLocked: false,
//       onTap: () => _navigateToUpload(
//         context,
//         controller,
//         documentModel: doc,
//       ),
//     );
//   }
//
//   void _navigateToUpload(
//       BuildContext context,
//       VerificationController controller, {
//         bool selfieOnly = false,
//         DocumentModel? documentModel,
//       }) {
//     if (!controller.validateMandatoryFields()) return;
//
//     Get.to(
//       const VerificationDetailsUploadScreen(),
//       // Pass the controller instance tag so the upload screen can find it
//       arguments: {
//         'selfieOnly': selfieOnly,
//         if (documentModel != null) 'documentModel': documentModel,
//         'aadhaarNumber': controller.aadhaarNumberController.text.trim(),
//         'drivingLicenseNumber':
//         controller.drivingLicenseController.text.trim(),
//       },
//       transition: Transition.cupertino,
//     )?.then((value) {
//       if (value == true) {
//         controller.getDocument(silent: true);
//       }
//     });
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Header
// // ─────────────────────────────────────────────────────────────────────────────
// class _Header extends StatelessWidget {
//   final bool isDark;
//   const _Header({required this.isDark});
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             width: 48,
//             height: 48,
//             decoration: BoxDecoration(
//               color: AppThemeData.driverApp300.withOpacity(0.12),
//               borderRadius: BorderRadius.circular(14),
//             ),
//             child: Icon(Icons.verified_user_rounded,
//                 color: AppThemeData.driverApp300, size: 26),
//           ),
//           const SizedBox(height: 12),
//           Text(
//             'Document Verification'.tr,
//             style: TextStyle(
//               color: isDark ? AppThemeData.grey100 : AppThemeData.grey900,
//               fontFamily: AppThemeData.bold,
//               fontSize: 28,
//               height: 1.2,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Complete your profile by uploading the required identity documents below.'
//                 .tr,
//             style: TextStyle(
//               fontSize: 14,
//               color: isDark ? AppThemeData.grey400 : AppThemeData.grey600,
//               fontFamily: AppThemeData.regular,
//               height: 1.5,
//             ),
//           ),
//           const SizedBox(height: 20),
//         ],
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Progress Bar
// // ─────────────────────────────────────────────────────────────────────────────
// class _ProgressBar extends StatelessWidget {
//   final VerificationController controller;
//   final bool isDark;
//   const _ProgressBar({required this.controller, required this.isDark});
//
//   @override
//   Widget build(BuildContext context) {
//     final total = controller.documentList.length;
//     if (total == 0) return const SizedBox.shrink();
//
//     return Obx(() {
//       final progress = controller.verificationProgress;
//       final approved = controller.approvedCount;
//
//       return Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   '$approved of $total verified',
//                   style: TextStyle(
//                     fontSize: 13,
//                     fontFamily: AppThemeData.medium,
//                     color:
//                     isDark ? AppThemeData.grey300 : AppThemeData.grey600,
//                   ),
//                 ),
//                 Text(
//                   '${(progress * 100).toInt()}%',
//                   style: TextStyle(
//                     fontSize: 13,
//                     fontFamily: AppThemeData.bold,
//                     color: AppThemeData.driverApp300,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             ClipRRect(
//               borderRadius: BorderRadius.circular(100),
//               child: LinearProgressIndicator(
//                 value: progress,
//                 minHeight: 6,
//                 backgroundColor: isDark
//                     ? AppThemeData.grey800
//                     : AppThemeData.grey200,
//                 valueColor:
//                 AlwaysStoppedAnimation<Color>(AppThemeData.driverApp300),
//               ),
//             ),
//             const SizedBox(height: 16),
//           ],
//         ),
//       );
//     });
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Identity Fields — locked after submission
// // ─────────────────────────────────────────────────────────────────────────────
// class _IdentityFields extends StatelessWidget {
//   final VerificationController controller;
//   final bool isDark;
//   const _IdentityFields({required this.controller, required this.isDark});
//
//   @override
//   Widget build(BuildContext context) {
//     return Obx(() {
//       final locked = controller.isSubmitted.value;
//
//       return Padding(
//         padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
//         child: Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: isDark ? AppThemeData.grey900 : Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(
//               color: locked
//                   ? AppThemeData.driverApp300.withOpacity(0.35)
//                   : (isDark
//                   ? AppThemeData.grey700
//                   : AppThemeData.grey200),
//             ),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   Text(
//                     'Required Details'.tr,
//                     style: TextStyle(
//                       color: isDark
//                           ? AppThemeData.grey100
//                           : AppThemeData.grey900,
//                       fontFamily: AppThemeData.semiBold,
//                       fontSize: 14,
//                     ),
//                   ),
//                   if (locked) ...[
//                     const SizedBox(width: 8),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 8, vertical: 3),
//                       decoration: BoxDecoration(
//                         color: Colors.green.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           const Icon(Icons.lock_rounded,
//                               size: 11, color: Colors.green),
//                           const SizedBox(width: 4),
//                           Text(
//                             'Saved',
//                             style: TextStyle(
//                               color: Colors.green,
//                               fontFamily: AppThemeData.medium,
//                               fontSize: 11,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//               const SizedBox(height: 12),
//               _IdentityTextField(
//                 controller: controller.aadhaarNumberController,
//                 label: 'Aadhaar Number *',
//                 icon: Icons.credit_card_rounded,
//                 isDark: isDark,
//                 enabled: !locked,
//               ),
//               const SizedBox(height: 10),
//               _IdentityTextField(
//                 controller: controller.drivingLicenseController,
//                 label: 'Driving License Number *',
//                 icon: Icons.directions_car_rounded,
//                 isDark: isDark,
//                 enabled: !locked,
//               ),
//             ],
//           ),
//         ),
//       );
//     });
//   }
// }
//
// class _IdentityTextField extends StatelessWidget {
//   final TextEditingController controller;
//   final String label;
//   final IconData icon;
//   final bool isDark;
//   final bool enabled;
//
//   const _IdentityTextField({
//     required this.controller,
//     required this.label,
//     required this.icon,
//     required this.isDark,
//     required this.enabled,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return TextField(
//       controller: controller,
//       enabled: enabled,
//       keyboardType: TextInputType.text,
//       style: TextStyle(
//         color: isDark ? AppThemeData.grey100 : AppThemeData.grey900,
//         fontFamily: AppThemeData.medium,
//         fontSize: 14,
//       ),
//       decoration: InputDecoration(
//         labelText: label.tr,
//         prefixIcon: Icon(icon,
//             color: enabled
//                 ? AppThemeData.driverApp300
//                 : (isDark ? AppThemeData.grey600 : AppThemeData.grey400),
//             size: 20),
//         isDense: true,
//         contentPadding:
//         const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
//         filled: !enabled,
//         fillColor: isDark
//             ? AppThemeData.grey800.withOpacity(0.5)
//             : AppThemeData.grey100,
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(
//               color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(
//               color: isDark ? AppThemeData.grey700 : AppThemeData.grey300),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide:
//           BorderSide(color: AppThemeData.driverApp300, width: 1.5),
//         ),
//         disabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(
//               color: isDark
//                   ? AppThemeData.grey800
//                   : AppThemeData.grey200),
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Submit Button
// // ─────────────────────────────────────────────────────────────────────────────
// class _SubmitButton extends StatelessWidget {
//   final VerificationController controller;
//   final bool isDark;
//   const _SubmitButton({required this.controller, required this.isDark});
//
//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
//         child: Obx(() => ElevatedButton(
//           onPressed: controller.isSubmittingIdentity.value
//               ? null
//               : () async {
//             final ok =
//             await controller.submitIdentityDetails();
//             if (ok) {
//               ShowToastDialog.showToast(
//                   'Details submitted successfully!'.tr);
//             } else {
//               ShowToastDialog.showToast(
//                   'Failed to submit. Please try again.'.tr);
//             }
//           },
//           style: ElevatedButton.styleFrom(
//             minimumSize: const Size.fromHeight(52),
//             backgroundColor: AppThemeData.driverApp300,
//             foregroundColor: Colors.white,
//             shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(14)),
//             elevation: 0,
//           ),
//           child: controller.isSubmittingIdentity.value
//               ? const SizedBox(
//             height: 20,
//             width: 20,
//             child: CircularProgressIndicator(
//                 color: Colors.white, strokeWidth: 2),
//           )
//               : Text(
//             'Submit Details'.tr,
//             style: const TextStyle(
//               fontFamily: AppThemeData.semiBold,
//               fontSize: 15,
//             ),
//           ),
//         )),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Submitted Banner — replaces the button after submission
// // ─────────────────────────────────────────────────────────────────────────────
// class _SubmittedBanner extends StatelessWidget {
//   final bool isDark;
//   /// Matches API `isDocumentVerify == 1` (parsed to bool on [UserModel]).
//   final bool isDocumentVerified;
//   const _SubmittedBanner({
//     required this.isDark,
//     this.isDocumentVerified = false,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final color =
//         isDocumentVerified ? Colors.green : AppThemeData.primary300;
//     return SafeArea(
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
//         child: Container(
//           height: 52,
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.1),
//             borderRadius: BorderRadius.circular(14),
//             border: Border.all(color: color.withOpacity(0.3)),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(
//                 isDocumentVerified
//                     ? Icons.verified_rounded
//                     : Icons.hourglass_top_rounded,
//                 color: color,
//                 size: 18,
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 isDocumentVerified
//                     ? 'Documents Approved'.tr
//                     : 'Under Review — Awaiting Approval'.tr,
//                 style: TextStyle(
//                   color: color,
//                   fontFamily: AppThemeData.semiBold,
//                   fontSize: 14,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Document Card
// // ─────────────────────────────────────────────────────────────────────────────
// class _DocumentCard extends StatelessWidget {
//   final DocumentModel documentModel;
//   final Documents documents;
//   final bool isDark;
//   final bool isLocked;
//   final VoidCallback onTap;
//
//   const _DocumentCard({
//     required this.documentModel,
//     required this.documents,
//     required this.isDark,
//     required this.isLocked,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final status = documents.status ?? '';
//     final cfg = _statusConfig(status);
//
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 12),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           onTap: isLocked ? null : onTap,
//           borderRadius: BorderRadius.circular(16),
//           child: AnimatedContainer(
//             duration: const Duration(milliseconds: 200),
//             decoration: BoxDecoration(
//               color: isDark ? AppThemeData.grey900 : Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(
//                   color: cfg['borderColor'] as Color, width: 1.5),
//               boxShadow: [
//                 BoxShadow(
//                   color: (isDark ? Colors.black : Colors.grey.shade200)
//                       .withOpacity(0.5),
//                   blurRadius: 8,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Padding(
//               padding: const EdgeInsets.symmetric(
//                   horizontal: 16, vertical: 16),
//               child: Row(
//                 children: [
//                   // Icon
//                   Container(
//                     width: 48,
//                     height: 48,
//                     decoration: BoxDecoration(
//                       color:
//                       (cfg['color'] as Color).withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Icon(cfg['icon'] as IconData,
//                         color: cfg['color'] as Color, size: 22),
//                   ),
//                   const SizedBox(width: 14),
//                   // Title + subtitle
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           '${documentModel.title}',
//                           style: TextStyle(
//                             color: isDark
//                                 ? AppThemeData.grey100
//                                 : AppThemeData.grey900,
//                             fontFamily: AppThemeData.bold,
//                             fontSize: 15,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           _sideLabel(),
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: isDark
//                                 ? AppThemeData.grey400
//                                 : AppThemeData.grey600,
//                             fontFamily: AppThemeData.regular,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   // Status badge
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 10, vertical: 5),
//                     decoration: BoxDecoration(
//                       color:
//                       (cfg['color'] as Color).withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: Text(
//                       cfg['label'] as String,
//                       style: TextStyle(
//                         color: cfg['color'] as Color,
//                         fontFamily: AppThemeData.medium,
//                         fontSize: 12,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   Icon(
//                     isLocked
//                         ? Icons.lock_outline_rounded
//                         : Icons.chevron_right_rounded,
//                     color: isDark
//                         ? AppThemeData.grey500
//                         : AppThemeData.grey400,
//                     size: 20,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   String _sideLabel() {
//     final parts = <String>[];
//     if (documentModel.frontSide == true) parts.add('Front');
//     if (documentModel.backSide == true) parts.add('Back');
//     if (parts.isEmpty) return 'Photo';
//     return '${parts.join(' & ')} Photo';
//   }
//
//   Map<String, dynamic> _statusConfig(String status) {
//     switch (status) {
//       case 'approved':
//         return {
//           'label': 'Verified',
//           'color': Colors.green,
//           'icon': Icons.check_circle_rounded,
//           'borderColor': Colors.green.withOpacity(0.3),
//         };
//       case 'rejected':
//         return {
//           'label': 'Rejected',
//           'color': Colors.red,
//           'icon': Icons.cancel_rounded,
//           'borderColor': Colors.red.withOpacity(0.3),
//         };
//       case 'uploaded':
//         return {
//           'label': 'In Review',
//           'color': AppThemeData.primary300,
//           'icon': Icons.hourglass_top_rounded,
//           'borderColor': AppThemeData.primary300.withOpacity(0.3),
//         };
//       case 'profile_photo':
//         return {
//           'label': 'Uploaded',
//           'color': Colors.green,
//           'icon': Icons.check_circle_rounded,
//           'borderColor': Colors.green.withOpacity(0.3),
//         };
//       default:
//         return {
//           'label': 'Pending',
//           'color': Colors.orange,
//           'icon': Icons.upload_file_rounded,
//           'borderColor': Colors.orange.withOpacity(0.2),
//         };
//     }
//   }
// }