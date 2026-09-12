// import 'dart:convert';
// import 'dart:io';
//
// import 'package:aadhar_auth_service/aadhar_auth_service.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart';
// import 'package:path_provider/path_provider.dart';
//
// import 'package:jippydriver_driver/constant/constant.dart';
// import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
// import 'package:jippydriver_driver/controllers/login_controller.dart';
// import 'package:jippydriver_driver/models/document_model.dart';
// import 'package:jippydriver_driver/models/driver_document_model.dart';
// import 'package:jippydriver_driver/utils/fire_store_utils.dart';
//
// class DetailsUploadController extends GetxController {
//   // ── Document state ────────────────────────────────────
//   final Rx<DocumentModel> documentModel = DocumentModel().obs;
//   final RxBool isSelfieOnly = false.obs;
//   final RxString frontImage = "".obs;
//   final RxString backImage = "".obs;
//   final RxString selfieImage = "".obs;
//   final RxString aadhaarNumber = "".obs;
//   final RxString drivingLicenseNumber = "".obs;
//   final RxBool isLoading = true.obs;
//   final Rx<Documents> documents = Documents().obs;
//
//   // ── Aadhaar state ─────────────────────────────────────
//   final RxBool aadhaarOtpSent = false.obs;
//   final RxBool aadhaarVerified = false.obs;
//   final RxBool aadhaarLoading = false.obs;
//   final TextEditingController aadhaarController = TextEditingController();
//   final TextEditingController otpController = TextEditingController();
//
//   /// Tracks transaction id returned by Aadhaar service
//   String? _aadhaarTxnId;
//   // Configure these from backend/config before enabling live Aadhaar OTP.
//   static const String _aadhaarAuaCode = "";
//   static const String _aadhaarSubAuaCode = "";
//   static const String _aadhaarLicenseKey = "";
//   static const String _aadhaarAsaLicenseKey = "";
//
//   final ImagePicker _imagePicker = ImagePicker();
//
//   // ─────────────────────────────────────────────────────
//   // Lifecycle
//   // ─────────────────────────────────────────────────────
//   @override
//   void onInit() {
//     _getArgument();
//     super.onInit();
//   }
//
//   @override
//   void onClose() {
//     aadhaarController.dispose();
//     otpController.dispose();
//     super.onClose();
//   }
//
//   // ─────────────────────────────────────────────────────
//   // Helpers
//   // ─────────────────────────────────────────────────────
//
//   /// True when the loaded document is Aadhaar (case-insensitive title match)
//   bool get isAadhaarDocument {
//     if (isSelfieOnly.value) return false;
//     final title = documentModel.value.title?.toLowerCase() ?? "";
//     return title.contains("aadhaar") || title.contains("aadhar");
//   }
//
//   // ─────────────────────────────────────────────────────
//   // Init / Data Fetch
//   // ─────────────────────────────────────────────────────
//   void _getArgument() {
//     if (Get.arguments != null) {
//       final args = Get.arguments as Map<String, dynamic>;
//       isSelfieOnly.value = args['selfieOnly'] == true;
//       aadhaarNumber.value = (args['aadhaarNumber'] ?? '').toString().trim();
//       drivingLicenseNumber.value =
//           (args['drivingLicenseNumber'] ?? '').toString().trim();
//       if (!isSelfieOnly.value && args['documentModel'] != null) {
//         documentModel.value = args['documentModel'] as DocumentModel;
//       }
//     }
//     _loadDocument();
//   }
//
//   Future<void> _loadDocument() async {
//     isLoading(true);
//     try {
//       final data = await FireStoreUtils.getDocumentOfDriver();
//       if (data?.documents != null) {
//         final match = data!.documents!
//             .where((e) => e.documentId == documentModel.value.id);
//         if (match.isNotEmpty) {
//           documents.value = match.first;
//           frontImage.value = documents.value.frontImage ?? "";
//           backImage.value = documents.value.backImage ?? "";
//         }
//       }
//
//       // Load existing profile picture as selfie
//       final uid = await LoginController.getFirebaseId();
//       final user = await FireStoreUtils.getUserProfile(uid);
//       if (user?.profilePictureURL != null &&
//           user!.profilePictureURL!.isNotEmpty) {
//         selfieImage.value = user.profilePictureURL!;
//       }
//     } catch (e) {
//       debugPrint("_loadDocument error: $e");
//     }
//     isLoading(false);
//   }
//
//   // ─────────────────────────────────────────────────────
//   // Image Picking
//   // ─────────────────────────────────────────────────────
//   Future<void> pickFile(
//       {required ImageSource source, required String type}) async {
//     final XFile? img = await _imagePicker.pickImage(
//       source: source,
//       imageQuality: 85,
//     );
//     if (img == null) return;
//     Get.back(); // close bottom sheet
//
//     if (type == "front") {
//       frontImage(img.path);
//     } else {
//       backImage(img.path);
//     }
//   }
//
//   Future<void> pickSelfie({required ImageSource source}) async {
//     final XFile? img = await _imagePicker.pickImage(
//       source: source,
//       imageQuality: 85,
//       preferredCameraDevice: CameraDevice.front,
//     );
//     if (img == null) return;
//     Get.back();
//     selfieImage(img.path);
//   }
//
//   // ─────────────────────────────────────────────────────
//   // Aadhaar Authentication (aadhar_auth_service ^0.0.5)
//   // ─────────────────────────────────────────────────────
//   Future<void> sendAadhaarOtp() async {
//     final number = aadhaarController.text.trim();
//     if (number.length != 12) {
//       ShowToastDialog.showToast("Please enter a valid 12-digit Aadhaar number");
//       return;
//     }
//
//     if (_aadhaarAuaCode.isEmpty ||
//         _aadhaarSubAuaCode.isEmpty ||
//         _aadhaarLicenseKey.isEmpty ||
//         _aadhaarAsaLicenseKey.isEmpty) {
//       ShowToastDialog.showToast(
//         "Aadhaar service is not configured yet. Please contact admin.",
//       );
//       return;
//     }
//
//     aadhaarLoading(true);
//     try {
//       final result = await AadhaarAuthService.requestOtp(
//         aadhaarNumber: number,
//         auaCode: _aadhaarAuaCode,
//         subAuaCode: _aadhaarSubAuaCode,
//         licenseKey: _aadhaarLicenseKey,
//         asaLicenseKey: _aadhaarAsaLicenseKey,
//       );
//       if (result['success'] == true) {
//         _aadhaarTxnId =
//             (result['transactionId'] ?? result['txnId'])?.toString();
//         aadhaarOtpSent(true);
//         ShowToastDialog.showToast(result['message']?.toString() ?? "OTP sent successfully");
//       } else {
//         ShowToastDialog.showToast(result['message']?.toString() ?? "Failed to send OTP");
//       }
//     } catch (e) {
//       ShowToastDialog.showToast("Aadhaar OTP error: $e");
//     }
//     aadhaarLoading(false);
//   }
//
//   Future<void> verifyAadhaarOtp() async {
//     final otp = otpController.text.trim();
//     if (otp.length != 6) {
//       ShowToastDialog.showToast("Please enter the 6-digit OTP");
//       return;
//     }
//
//     if (_aadhaarTxnId == null) {
//       ShowToastDialog.showToast("Session expired. Please resend OTP.");
//       return;
//     }
//
//     aadhaarLoading(true);
//     try {
//       final result = await AadhaarAuthService.verifyOtp(
//         aadhaarNumber: aadhaarController.text.trim(),
//         otp: otp,
//         transactionId: _aadhaarTxnId!,
//         auaCode: _aadhaarAuaCode,
//         subAuaCode: _aadhaarSubAuaCode,
//         licenseKey: _aadhaarLicenseKey,
//         asaLicenseKey: _aadhaarAsaLicenseKey,
//       );
//       if (result['success'] == true) {
//         aadhaarVerified(true);
//         ShowToastDialog.showToast(result['message']?.toString() ?? "Aadhaar verified successfully!");
//
//         // Pre-fill front/back from Aadhaar service if available
//         // (Some implementations return masked XML / image URLs)
//         final data = result['data'];
//         if (data != null) {
//           if (data['frontImage'] != null) {
//             frontImage.value = data['frontImage'];
//           }
//           if (data['backImage'] != null) {
//             backImage.value = data['backImage'];
//           }
//         }
//       } else {
//         ShowToastDialog.showToast(
//             result['message']?.toString() ?? "Invalid OTP");
//       }
//     } catch (e) {
//       ShowToastDialog.showToast("OTP verification error: $e");
//     }
//     aadhaarLoading(false);
//   }
//
//   void resetAadhaarFlow() {
//     aadhaarOtpSent(false);
//     aadhaarVerified(false);
//     otpController.clear();
//     _aadhaarTxnId = null;
//   }
//
//   // ─────────────────────────────────────────────────────
//   // Submit Handler (called from UI button)
//   // ─────────────────────────────────────────────────────
//   Future<void> onSubmitPressed() async {
//     if (isSelfieOnly.value) {
//       if (selfieImage.value.isEmpty) {
//         ShowToastDialog.showToast("Please upload your selfie / profile photo.");
//         return;
//       }
//       ShowToastDialog.showLoader("Uploading...");
//       final ok = await _uploadSelfieOnly();
//       ShowToastDialog.closeLoader();
//       if (ok) {
//         ShowToastDialog.showToast("Selfie uploaded successfully");
//         Get.back(result: true);
//       } else {
//         ShowToastDialog.showToast("Selfie upload failed. Please try again.");
//       }
//       return;
//     }
//
//     // Aadhaar doc needs verification first
//     if (isAadhaarDocument && !aadhaarVerified.value) {
//       ShowToastDialog.showToast("Please complete Aadhaar verification first");
//       return;
//     }
//     if (aadhaarNumber.value.isEmpty) {
//       ShowToastDialog.showToast("Aadhaar number is required");
//       return;
//     }
//     if (drivingLicenseNumber.value.isEmpty) {
//       ShowToastDialog.showToast("Driving license number is required");
//       return;
//     }
//
//     if (documentModel.value.frontSide == true && frontImage.value.isEmpty) {
//       ShowToastDialog.showToast("Please upload front side of document.");
//       return;
//     }
//     if (documentModel.value.backSide == true && backImage.value.isEmpty) {
//       ShowToastDialog.showToast("Please upload back side of document.");
//       return;
//     }
//     ShowToastDialog.showLoader("Uploading...");
//     await _uploadAll();
//     ShowToastDialog.closeLoader();
//   }
//
//   Future<bool> _uploadSelfieOnly() async {
//     try {
//       var selfie = await _resolveLocalPath(selfieImage.value);
//       if (selfie.isNotEmpty && !Constant().hasValidUrl(selfie)) {
//         final selfieFile = File(selfie);
//         if (await selfieFile.exists()) {
//           final currentUid = await FireStoreUtils.getCurrentUid();
//           final fileName = selfieFile.path.split('/').last;
//           selfie = await Constant.uploadUserImageToFireStorage(
//             selfieFile,
//             "users/$currentUid",
//             fileName,
//           );
//         }
//       }
//       final uid = await LoginController.getFirebaseId();
//       if (uid.isEmpty) return false;
//       final user = await FireStoreUtils.getUserProfile(uid);
//       if (user == null) return false;
//       user.profilePictureURL = selfie;
//       return await FireStoreUtils.updateUser(user);
//     } catch (e) {
//       debugPrint("_uploadSelfieOnly error: $e");
//       return false;
//     }
//   }
//
//   // ─────────────────────────────────────────────────────
//   // Upload document images only.
//   // ─────────────────────────────────────────────────────
//   Future<void> _uploadAll() async {
//     try {
//       final front = await _resolveLocalPath(frontImage.value);
//       final back = await _resolveLocalPath(backImage.value);
//
//       documents.value
//         ..frontImage = front
//         ..backImage = back
//         ..documentId = documentModel.value.id
//         ..status = "uploaded";
//
//       final docSuccess = await _uploadDocument(documents.value);
//
//       if (docSuccess) {
//         ShowToastDialog.showToast("Uploaded successfully");
//         Get.back(result: true);
//       } else {
//         ShowToastDialog.showToast("Upload failed. Please try again.");
//       }
//     } catch (e) {
//       ShowToastDialog.showToast("Error: $e");
//     }
//   }
//
//   // ─────────────────────────────────────────────────────
//   // HTTP Multipart Upload
//   // ─────────────────────────────────────────────────────
//   Future<bool> _uploadDocument(Documents doc) async {
//     final uid = await LoginController.getFirebaseId();
//
//     try {
//       final request = http.MultipartRequest(
//         'POST',
//         Uri.parse("${Constant.baseUrl}documents/driver/upload"),
//       );
//
//       request.fields.addAll({
//         "user_id": uid,
//         "documentId": doc.documentId ?? "",
//         "type": "driver",
//         "status": doc.status ?? "uploaded",
//         "aadhaar_number": aadhaarNumber.value,
//         "driving_license_number": drivingLicenseNumber.value,
//       });
//
//       await _attachFileIfExists(request, "front_image", doc.frontImage);
//       await _attachFileIfExists(request, "back_image", doc.backImage);
//
//       final res = await request.send();
//       final body = await res.stream.bytesToString();
//
//       debugPrint("Upload status: ${res.statusCode}");
//       debugPrint("Upload response: $body");
//
//       if (res.statusCode == 200) {
//         return json.decode(body)['success'] == true;
//       }
//     } catch (e) {
//       debugPrint("_uploadDocument error: $e");
//     }
//     return false;
//   }
//
//   Future<void> _attachFileIfExists(
//       http.MultipartRequest request, String field, String? path) async {
//     if (path == null || path.isEmpty) return;
//     final file = File(path);
//     if (await file.exists()) {
//       request.files
//           .add(await http.MultipartFile.fromPath(field, file.path));
//     }
//   }
//
//   // ─────────────────────────────────────────────────────
//   // URL → local temp file
//   // ─────────────────────────────────────────────────────
//   Future<String> _resolveLocalPath(String path) async {
//     if (path.isEmpty || !path.startsWith("http")) return path;
//     try {
//       final dir = await getTemporaryDirectory();
//       final file = File(
//           "${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg");
//       final res = await http.get(Uri.parse(path));
//       if (res.statusCode == 200) {
//         await file.writeAsBytes(res.bodyBytes);
//         return file.path;
//       }
//     } catch (e) {
//       debugPrint("_resolveLocalPath error: $e");
//     }
//     return path;
//   }
// }



import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aadhar_auth_service/aadhar_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/app/auth_screen/controller/login_controller.dart';
import 'package:jippydriver_driver/models/document_model.dart';
import 'package:jippydriver_driver/models/driver_document_model.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';

class DetailsUploadController extends GetxController {
  static const Duration _uploadTimeout = Duration(seconds: 90);
  static const Duration _imageDownloadTimeout = Duration(seconds: 35);
  // ── Document state ──────────────────────────────────────────────────
  final Rx<DocumentModel> documentModel = DocumentModel().obs;
  final RxBool isSelfieOnly = false.obs;
  final RxString frontImage = ''.obs;
  final RxString backImage = ''.obs;
  final RxString selfieImage = ''.obs;

  // These are read from arguments and kept in memory — they are NEVER
  // cleared by navigation events because they're plain RxString fields.
  final RxString aadhaarNumber = ''.obs;
  final RxString drivingLicenseNumber = ''.obs;

  final RxBool isLoading = true.obs;
  final RxBool isUploading = false.obs;
  final Rx<Documents> documents = Documents().obs;

  // ── Aadhaar OTP state ───────────────────────────────────────────────
  final RxBool aadhaarOtpSent = false.obs;
  final RxBool aadhaarVerified = false.obs;
  final RxBool aadhaarLoading = false.obs;
  final TextEditingController aadhaarController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  String? _aadhaarTxnId;

  // Configure from backend/config before enabling live Aadhaar OTP.
  static const String _aadhaarAuaCode = '';
  static const String _aadhaarSubAuaCode = '';
  static const String _aadhaarLicenseKey = '';
  static const String _aadhaarAsaLicenseKey = '';

  final ImagePicker _imagePicker = ImagePicker();

  // ── Lifecycle ────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _getArgument();
  }

  @override
  void onClose() {
    aadhaarController.dispose();
    otpController.dispose();
    super.onClose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────
  bool get isAadhaarDocument {
    if (isSelfieOnly.value) return false;
    final title = documentModel.value.title?.toLowerCase() ?? '';
    return title.contains('aadhaar') || title.contains('aadhar');
  }

  /// When false, Aadhaar is uploaded like any other document (photos only, no OTP gate).
  bool get isAadhaarOtpConfigured =>
      _aadhaarAuaCode.isNotEmpty &&
      _aadhaarSubAuaCode.isNotEmpty &&
      _aadhaarLicenseKey.isNotEmpty &&
      _aadhaarAsaLicenseKey.isNotEmpty;

  // ── Init ─────────────────────────────────────────────────────────────
  void _getArgument() {
    if (Get.arguments != null) {
      final args = Get.arguments as Map<String, dynamic>;
      isSelfieOnly.value = args['selfieOnly'] == true;
      // Store the identity numbers passed from the parent screen.
      aadhaarNumber.value = (args['aadhaarNumber'] ?? '').toString().trim();
      drivingLicenseNumber.value =
          (args['drivingLicenseNumber'] ?? '').toString().trim();

      if (!isSelfieOnly.value && args['documentModel'] != null) {
        documentModel.value = args['documentModel'] as DocumentModel;
      }
    }
    if (aadhaarNumber.value.isNotEmpty) {
      aadhaarController.text = aadhaarNumber.value;
    }
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    isLoading(true);
    try {
      final uid = await LoginController.getFirebaseId();
      final driverFuture = FireStoreUtils.getDocumentOfDriver();
      final userFuture = uid.isEmpty
          ? Future<UserModel?>.value(null)
          : FireStoreUtils.getUserProfile(uid);

      final batch = await Future.wait<Object?>([
        driverFuture,
        userFuture,
      ]);
      final data = batch[0] as DriverDocumentModel?;
      final user = batch[1] as UserModel?;

      final templateId = documentModel.value.id;
      if (data?.documents != null && (templateId ?? '').isNotEmpty) {
        Documents? row;
        for (final e in data!.documents!) {
          if (e.documentId == templateId) {
            row = e;
            break;
          }
        }
        if (row != null) {
          documents.value = row;
          frontImage.value = row.frontImage ?? '';
          backImage.value = row.backImage ?? '';
        }
      }

      final pic = user?.profilePictureURL;
      if (pic != null && pic.isNotEmpty) {
        selfieImage.value = pic;
      }
    } catch (e, st) {
      debugPrint('_loadDocument error: $e\n$st');
    }
    isLoading(false);
  }

  // ── Image Picking ────────────────────────────────────────────────────
  Future<void> pickFile(
      {required ImageSource source, required String type}) async {
    final XFile? img = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (img == null) return;
    Get.back(); // close bottom sheet
    if (type == 'front') {
      frontImage(img.path);
    } else {
      backImage(img.path);
    }
  }

  Future<void> pickSelfie({required ImageSource source}) async {
    final XFile? img = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 2048,
      maxHeight: 2048,
      preferredCameraDevice: CameraDevice.front,
    );
    if (img == null) return;
    Get.back();
    selfieImage(img.path);
  }

  // ── Aadhaar OTP ──────────────────────────────────────────────────────
  Future<void> sendAadhaarOtp() async {
    final number = aadhaarController.text.trim();
    if (number.length != 12) {
      ShowToastDialog.showToast('Please enter a valid 12-digit Aadhaar number');
      return;
    }

    if (_aadhaarAuaCode.isEmpty ||
        _aadhaarSubAuaCode.isEmpty ||
        _aadhaarLicenseKey.isEmpty ||
        _aadhaarAsaLicenseKey.isEmpty) {
      ShowToastDialog.showToast(
        'Aadhaar service is not configured. Please contact admin.',
      );
      return;
    }

    aadhaarLoading(true);
    try {
      final result = await AadhaarAuthService.requestOtp(
        aadhaarNumber: number,
        auaCode: _aadhaarAuaCode,
        subAuaCode: _aadhaarSubAuaCode,
        licenseKey: _aadhaarLicenseKey,
        asaLicenseKey: _aadhaarAsaLicenseKey,
      );
      if (result['success'] == true) {
        _aadhaarTxnId =
            (result['transactionId'] ?? result['txnId'])?.toString();
        aadhaarOtpSent(true);
        ShowToastDialog.showToast(
            result['message']?.toString() ?? 'OTP sent successfully');
      } else {
        ShowToastDialog.showToast(
            result['message']?.toString() ?? 'Failed to send OTP');
      }
    } catch (e) {
      ShowToastDialog.showToast('Aadhaar OTP error: $e');
    }
    aadhaarLoading(false);
  }

  Future<void> verifyAadhaarOtp() async {
    final otp = otpController.text.trim();
    if (otp.length != 6) {
      ShowToastDialog.showToast('Please enter the 6-digit OTP');
      return;
    }
    if (_aadhaarTxnId == null) {
      ShowToastDialog.showToast('Session expired. Please resend OTP.');
      return;
    }

    aadhaarLoading(true);
    try {
      final result = await AadhaarAuthService.verifyOtp(
        aadhaarNumber: aadhaarController.text.trim(),
        otp: otp,
        transactionId: _aadhaarTxnId!,
        auaCode: _aadhaarAuaCode,
        subAuaCode: _aadhaarSubAuaCode,
        licenseKey: _aadhaarLicenseKey,
        asaLicenseKey: _aadhaarAsaLicenseKey,
      );
      if (result['success'] == true) {
        aadhaarVerified(true);
        ShowToastDialog.showToast(
            result['message']?.toString() ?? 'Aadhaar verified successfully!');
        final data = result['data'];
        if (data != null) {
          if (data['frontImage'] != null) frontImage.value = data['frontImage'];
          if (data['backImage'] != null) backImage.value = data['backImage'];
        }
      } else {
        ShowToastDialog.showToast(
            result['message']?.toString() ?? 'Invalid OTP');
      }
    } catch (e) {
      ShowToastDialog.showToast('OTP verification error: $e');
    }
    aadhaarLoading(false);
  }

  void resetAadhaarFlow() {
    aadhaarOtpSent(false);
    aadhaarVerified(false);
    otpController.clear();
    _aadhaarTxnId = null;
  }

  // ── Submit Handler ───────────────────────────────────────────────────
  Future<void> onSubmitPressed() async {
    if (isSelfieOnly.value) {
      if (selfieImage.value.isEmpty) {
        ShowToastDialog.showToast(
            'Please upload your selfie / profile photo.');
        return;
      }
      isUploading(true);
      ShowToastDialog.showLoader('Uploading...');
      final ok = await _uploadSelfieOnly();
      ShowToastDialog.closeLoader();
      isUploading(false);
      if (ok) {
        ShowToastDialog.showToast('Selfie uploaded successfully');
        Get.back(result: true);
      } else {
        ShowToastDialog.showToast('Selfie upload failed. Please try again.');
      }
      return;
    }

    if (isAadhaarDocument &&
        isAadhaarOtpConfigured &&
        !aadhaarVerified.value) {
      ShowToastDialog.showToast('Please complete Aadhaar verification first');
      return;
    }
    if (aadhaarNumber.value.isEmpty) {
      ShowToastDialog.showToast('Aadhaar number is required');
      return;
    }
    if (drivingLicenseNumber.value.isEmpty) {
      ShowToastDialog.showToast('Driving license number is required');
      return;
    }
    if (documentModel.value.frontSide == true && frontImage.value.isEmpty) {
      ShowToastDialog.showToast('Please upload front side of document.');
      return;
    }
    if (documentModel.value.backSide == true && backImage.value.isEmpty) {
      ShowToastDialog.showToast('Please upload back side of document.');
      return;
    }

    isUploading(true);
    ShowToastDialog.showLoader('Uploading...');
    await _uploadAll();
    ShowToastDialog.closeLoader();
    isUploading(false);
  }

  // ── Upload helpers ───────────────────────────────────────────────────
  Future<bool> _uploadSelfieOnly() async {
    try {
      var selfie = await _resolveLocalPath(selfieImage.value);
      if (selfie.isNotEmpty && !Constant().hasValidUrl(selfie)) {
        final file = File(selfie);
        if (await file.exists()) {
          final uid = await FireStoreUtils.getCurrentUid();
          selfie = await Constant.uploadUserImageToFireStorage(
            file,
            'users/$uid',
            file.path.split('/').last,
          );
        }
      }
      final uid = await LoginController.getFirebaseId();
      if (uid.isEmpty) return false;
      final user = await FireStoreUtils.getUserProfile(uid);
      if (user == null) return false;
      user.profilePictureURL = selfie;
      // Do not send current online state with a profile-photo change — backend expects isActive off (0).
      user.isActive = false;
      return await FireStoreUtils.updateUser(user);
    } catch (e) {
      debugPrint('_uploadSelfieOnly error: $e');
      return false;
    }
  }

  Future<void> _uploadAll() async {
    try {
      var front = await _resolveLocalPath(frontImage.value);
      var back = await _resolveLocalPath(backImage.value);

      // Upload to Firebase Storage if local paths
      if (front.isNotEmpty && !Constant().hasValidUrl(front)) {
        final file = File(front);
        if (await file.exists()) {
          final uid = await FireStoreUtils.getCurrentUid();
          final fileName = file.path.split('/').last;
          front = await Constant.uploadUserImageToFireStorage(
            file,
            'documents/$uid',
            fileName,
          );
        }
      }
      if (back.isNotEmpty && !Constant().hasValidUrl(back)) {
        final file = File(back);
        if (await file.exists()) {
          final uid = await FireStoreUtils.getCurrentUid();
          final fileName = file.path.split('/').last;
          back = await Constant.uploadUserImageToFireStorage(
            file,
            'documents/$uid',
            fileName,
          );
        }
      }

      documents.value
        ..frontImage = front
        ..backImage = back
        ..documentId = documentModel.value.id
        ..status = 'uploaded';

      final ok = await _uploadDocument(documents.value);
      if (ok) {
        ShowToastDialog.showToast('Uploaded successfully');
        Get.back(result: true);
      } else {
        ShowToastDialog.showToast('Upload failed. Please try again.');
      }
    } catch (e) {
      ShowToastDialog.showToast('Error: $e');
    }
  }

  Future<bool> _uploadDocument(Documents doc) async {
    final uid = await LoginController.getFirebaseId();
    try {
      final response = await http.post(
        Uri.parse('${Constant.baseUrl}documents/driver/upload'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': uid,
          'documentId': doc.documentId ?? '',
          'type': 'driver',
          'status': doc.status ?? 'uploaded',
          'aadhaar_number': aadhaarNumber.value,
          'driving_license_number': drivingLicenseNumber.value,
          'front_image': doc.frontImage ?? '',
          'back_image': doc.backImage ?? '',
        }),
      ).timeout(_uploadTimeout);

      debugPrint('Upload [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body)['success'] == true;
      }
    } on TimeoutException {
      debugPrint('_uploadDocument: timeout');
    } catch (e) {
      debugPrint('_uploadDocument error: $e');
    }
    return false;
  }

  Future<String> _resolveLocalPath(String path) async {
    if (path.isEmpty || !path.startsWith('http')) return path;
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final res = await http
          .get(Uri.parse(path))
          .timeout(_imageDownloadTimeout);
      if (res.statusCode == 200) {
        await file.writeAsBytes(res.bodyBytes);
        return file.path;
      }
    } catch (e) {
      debugPrint('_resolveLocalPath error: $e');
    }
    return path;
  }
}