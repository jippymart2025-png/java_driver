// import 'dart:async';
// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:jippydriver_driver/constant/constant.dart';
// import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
// import 'package:jippydriver_driver/controllers/login_controller.dart';
// import 'package:jippydriver_driver/models/document_model.dart';
// import 'package:jippydriver_driver/models/driver_document_model.dart';
// import 'package:jippydriver_driver/utils/fire_store_utils.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class VerificationController extends GetxController {
//   static const Duration _httpTimeout = Duration(seconds: 45);
//
//   RxBool isLoading = true.obs;
//   RxBool isSubmittingIdentity = false.obs;
//   /// Identity (Aadhaar + DL) saved on the server — fields lock and upload cards read-only.
//   final RxBool isSubmitted = false.obs;
//   final TextEditingController aadhaarNumberController =
//       TextEditingController();
//   final TextEditingController drivingLicenseController =
//       TextEditingController();
//
//   Timer? _identityDraftDebounce;
//
//   /// O(1) lookups for template id → uploaded row (rebuilt when [driverDocumentList] changes).
//   Map<String, Documents> _driverDocById = {};
//
//   int get approvedCount {
//     final templates = documentList;
//     if (templates.isEmpty) return 0;
//     final allowedIds = <String>{
//       for (final t in templates)
//         if ((t.id ?? '').isNotEmpty) t.id!,
//     };
//     if (allowedIds.isEmpty) return 0;
//     var n = 0;
//     for (final d in driverDocumentList) {
//       final id = d.documentId;
//       if (id != null &&
//           allowedIds.contains(id) &&
//           d.status == 'approved') {
//         n++;
//       }
//     }
//     return n;
//   }
//
//   double get verificationProgress {
//     final total = documentList.length;
//     if (total == 0) return 0;
//     return approvedCount / total;
//   }
//
//   Documents findDocument(DocumentModel doc) {
//     final id = doc.id;
//     if (id == null || id.isEmpty) return Documents();
//     return _driverDocById[id] ?? Documents();
//   }
//
//   void _reindexDriverDocuments() {
//     _driverDocById = {
//       for (final d in driverDocumentList)
//         if ((d.documentId ?? '').isNotEmpty) d.documentId!: d,
//     };
//   }
//
//   bool validateMandatoryFields() {
//     final aadhaar = aadhaarNumberController.text.trim();
//     final dl = drivingLicenseController.text.trim();
//     if (aadhaar.isEmpty) {
//       ShowToastDialog.showToast('Aadhaar number is required'.tr);
//       return false;
//     }
//     if (dl.isEmpty) {
//       ShowToastDialog.showToast('Driving license number is required'.tr);
//       return false;
//     }
//     return true;
//   }
//
//   @override
//   void onInit() {
//     super.onInit();
//     aadhaarNumberController.addListener(_schedulePersistIdentityDraft);
//     drivingLicenseController.addListener(_schedulePersistIdentityDraft);
//     getDocument();
//   }
//
//   void _schedulePersistIdentityDraft() {
//     if (isSubmitted.value) return;
//     _identityDraftDebounce?.cancel();
//     _identityDraftDebounce = Timer(const Duration(milliseconds: 450), () {
//       unawaited(_persistIdentityDraft());
//     });
//   }
//
//   Future<void> _persistIdentityDraft() async {
//     if (isSubmitted.value) return;
//     final uid = await LoginController.getFirebaseId();
//     if (uid.isEmpty) return;
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(
//       _draftBlobKey(uid),
//       jsonEncode({
//         'a': aadhaarNumberController.text,
//         'd': drivingLicenseController.text,
//       }),
//     );
//     await prefs.remove(_draftKeyLegacyAadhaar(uid));
//     await prefs.remove(_draftKeyLegacyDl(uid));
//   }
//
//   Future<void> _restoreIdentityDraftIfEmpty() async {
//     if (isSubmitted.value) return;
//     final uid = await LoginController.getFirebaseId();
//     if (uid.isEmpty) return;
//     final prefs = await SharedPreferences.getInstance();
//     String? a;
//     String? d;
//     final blob = prefs.getString(_draftBlobKey(uid));
//     if (blob != null && blob.isNotEmpty) {
//       try {
//         final m = jsonDecode(blob) as Map<String, dynamic>;
//         a = m['a']?.toString();
//         d = m['d']?.toString();
//       } catch (_) {}
//     }
//     a ??= prefs.getString(_draftKeyLegacyAadhaar(uid));
//     d ??= prefs.getString(_draftKeyLegacyDl(uid));
//
//     if (aadhaarNumberController.text.trim().isEmpty &&
//         (a ?? '').trim().isNotEmpty) {
//       aadhaarNumberController.text = a!;
//     }
//     if (drivingLicenseController.text.trim().isEmpty &&
//         (d ?? '').trim().isNotEmpty) {
//       drivingLicenseController.text = d!;
//     }
//   }
//
//   Future<void> _clearIdentityDraft() async {
//     final uid = await LoginController.getFirebaseId();
//     if (uid.isEmpty) return;
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(_draftBlobKey(uid));
//     await prefs.remove(_draftKeyLegacyAadhaar(uid));
//     await prefs.remove(_draftKeyLegacyDl(uid));
//   }
//
//   static String _draftBlobKey(String uid) => 'verif_id_draft_$uid';
//   static String _draftKeyLegacyAadhaar(String uid) =>
//       'verif_id_draft_aadhaar_$uid';
//   static String _draftKeyLegacyDl(String uid) => 'verif_id_draft_dl_$uid';
//
//   @override
//   void onClose() {
//     _identityDraftDebounce?.cancel();
//     aadhaarNumberController.removeListener(_schedulePersistIdentityDraft);
//     drivingLicenseController.removeListener(_schedulePersistIdentityDraft);
//     if (!isSubmitted.value) {
//       unawaited(_persistIdentityDraft());
//     }
//     aadhaarNumberController.dispose();
//     drivingLicenseController.dispose();
//     super.onClose();
//   }
//
//   RxList<DocumentModel> documentList = <DocumentModel>[].obs;
//   RxList<Documents> driverDocumentList = <Documents>[].obs;
//
//   /// Refetch document templates and driver uploads. Use [silent] after inline actions
//   /// (e.g. identity submit) to avoid a full-screen loading flash.
//   ///
//   /// [suppressDraftRestore]: set after identity POST so a lagging GET does not re-apply
//   /// stale drafts over the values you just submitted.
//   Future<void> getDocument({
//     bool silent = false,
//     bool suppressDraftRestore = false,
//   }) async {
//     if (!silent) {
//       isLoading.value = true;
//       update();
//     }
//
//     try {
//       final listFuture =
//           FireStoreUtils.getDocumentList().catchError((Object e, StackTrace _) {
//         debugPrint('getDocumentList: $e');
//         return <DocumentModel>[];
//       });
//       final driverFuture =
//           FireStoreUtils.getDocumentOfDriver().catchError((Object e, StackTrace _) {
//         debugPrint('getDocumentOfDriver: $e');
//         return null;
//       });
//
//       documentList.value = await listFuture;
//       final value = await driverFuture;
//
//       if (value?.documents != null) {
//         driverDocumentList.value = value!.documents!;
//       } else {
//         driverDocumentList.value = [];
//       }
//       _reindexDriverDocuments();
//
//       if (value != null) {
//         final serverA = (value.aadharNo ?? '').trim();
//         final serverD = (value.drivingLicenseNumber ?? '').trim();
//         isSubmitted.value = serverA.isNotEmpty && serverD.isNotEmpty;
//
//         // Never replace typed draft with empty API values (common before submit).
//         if (serverA.isNotEmpty) {
//           aadhaarNumberController.text = value.aadharNo ?? serverA;
//         }
//         if (serverD.isNotEmpty) {
//           drivingLicenseController.text = value.drivingLicenseNumber ?? serverD;
//         }
//
//         if (isSubmitted.value) {
//           await _clearIdentityDraft();
//         } else if (!suppressDraftRestore) {
//           await _restoreIdentityDraftIfEmpty();
//         }
//       } else {
//         isSubmitted.value = false;
//         if (!suppressDraftRestore) {
//           await _restoreIdentityDraftIfEmpty();
//         }
//       }
//     } catch (e, st) {
//       debugPrint('Error in getDocument: $e\n$st');
//       if (!isSubmitted.value && !suppressDraftRestore) {
//         await _restoreIdentityDraftIfEmpty();
//       }
//     } finally {
//       if (!silent) {
//         isLoading.value = false;
//       }
//       update();
//     }
//   }
//
//   Future<bool> submitIdentityDetails() async {
//     final aadhaar = aadhaarNumberController.text.trim();
//     final drivingLicense = drivingLicenseController.text.trim();
//
//     if (aadhaar.isEmpty) {
//       ShowToastDialog.showToast("Aadhaar number is required");
//       return false;
//     }
//     if (drivingLicense.isEmpty) {
//       ShowToastDialog.showToast("Driving license number is required");
//       return false;
//     }
//
//     isSubmittingIdentity.value = true;
//     update();
//     try {
//       final userId = await LoginController.getFirebaseId();
//       final response = await http
//           .post(
//         Uri.parse("${Constant.baseUrl}documents/driver/identity"),
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept': 'application/json',
//         },
//         body: jsonEncode({
//           "user_id": userId,
//           "aadhaar_number": aadhaar,
//           "driving_license_number": drivingLicense,
//         }),
//       )
//           .timeout(_httpTimeout);
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final body = jsonDecode(response.body) as Map<String, dynamic>;
//         if (body['success'] == true) {
//           await _clearIdentityDraft();
//           await getDocument(silent: true, suppressDraftRestore: true);
//           // Keep locked after POST even if GET lags before identity appears on server.
//           isSubmitted.value = true;
//           return true;
//         }
//         final msg = body['message']?.toString();
//         if (msg != null && msg.isNotEmpty) {
//           ShowToastDialog.showToast(msg);
//         }
//       } else {
//         try {
//           final body = jsonDecode(response.body) as Map<String, dynamic>?;
//           final msg = body?['message']?.toString();
//           if (msg != null && msg.isNotEmpty) {
//             ShowToastDialog.showToast(msg);
//           }
//         } catch (_) {}
//       }
//     } on TimeoutException {
//       ShowToastDialog.showToast(
//           'Request timed out. Check your connection and try again.'.tr);
//     } catch (e) {
//       debugPrint("submitIdentityDetails error: $e");
//       ShowToastDialog.showToast(
//           'Could not submit. Please try again.'.tr);
//     } finally {
//       isSubmittingIdentity.value = false;
//       update();
//     }
//     return false;
//   }
// }


import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/controllers/login_controller.dart';
import 'package:jippydriver_driver/models/document_model.dart';
import 'package:jippydriver_driver/models/driver_document_model.dart';
import 'package:jippydriver_driver/utils/common.dart';

class VerificationController extends GetxController {
  // ---------------------------------------------------------------------------
  // API
  // ---------------------------------------------------------------------------

  static String get _uploadDocumentsUrl =>
      '${Constant.baseUrl}fm/outlets/saveOrUpdateDocuments';

  static const Duration _httpTimeout = Duration(seconds: 45);

  // ---------------------------------------------------------------------------
  // Loading states
  // ---------------------------------------------------------------------------

  RxBool isLoading = true.obs;

  RxBool isSubmittingIdentity = false.obs;

  final RxBool isSubmitted = false.obs;

  // ---------------------------------------------------------------------------
  // Document files
  // ---------------------------------------------------------------------------

  final Rxn<File> aadharFile = Rxn<File>();

  final Rxn<File> panFile = Rxn<File>();

  final Rxn<File> rcCopyFile = Rxn<File>();

  final Rxn<File> drivingLicenseFile = Rxn<File>();

  // ---------------------------------------------------------------------------
  // Image picker
  // ---------------------------------------------------------------------------

  final ImagePicker _imagePicker = ImagePicker();

  // ---------------------------------------------------------------------------
  // Document data
  // ---------------------------------------------------------------------------

  RxList<DocumentModel> documentList = <DocumentModel>[].obs;

  RxList<Documents> driverDocumentList = <Documents>[].obs;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void onInit() {
    super.onInit();

    getDocument();
  }

  @override
  void onClose() {
    super.onClose();
  }

  // ---------------------------------------------------------------------------
  // Get document templates + driver documents
  // ---------------------------------------------------------------------------

  Future<void> getDocument() async {
    try {
      isLoading.value = true;

      documentList.assignAll(_buildDocumentTemplates());

      final urls = await _fetchDriverDocUrls();

      final uploaded = <Documents>[];
      urls.forEach((id, url) {
        if (id.isEmpty || url.trim().isEmpty) return;
        uploaded.add(
          Documents(
            documentId: id,
            frontImage: url,
            status: 'uploaded',
          ),
        );
      });

      driverDocumentList.assignAll(uploaded);
    } catch (e) {
      debugPrint('getDocument error: $e');
    } finally {
      isLoading.value = false;
    }

    update();
  }

  // ---------------------------------------------------------------------------
  // Driver document templates (Aadhaar, PAN, RC, Driving License)
  // FSSAI & GST are NOT required for drivers.
  // ---------------------------------------------------------------------------

  List<DocumentModel> _buildDocumentTemplates() {
    return <DocumentModel>[
      DocumentModel(
        id: 'aadhar',
        title: 'Aadhaar Card',
        enable: true,
        frontSide: true,
        backSide: true,
      ),
      DocumentModel(
        id: 'pan',
        title: 'PAN Card',
        enable: true,
        frontSide: true,
        backSide: false,
      ),
      DocumentModel(
        id: 'rc',
        title: 'RC Copy',
        enable: true,
        frontSide: true,
        backSide: true,
      ),
      DocumentModel(
        id: 'drivingLicense',
        title: 'Driving License',
        enable: true,
        frontSide: true,
        backSide: true,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Fetch already-uploaded document URLs from getDriverDetails
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> _fetchDriverDocUrls() async {
    final userId = await LoginController.getFirebaseId();
    if (userId.isEmpty) return <String, String>{};

    try {
      final response = await http
          .get(
            Uri.parse(
              '${Constant.baseUrl}driver/getDriverDetails?driverId=$userId',
            ),
            headers: await getHeaders(),
          )
          .timeout(_httpTimeout);

      if (response.statusCode != 200) return <String, String>{};

      final body = jsonDecode(response.body);

      Map<String, dynamic> data;
      if (body is Map<String, dynamic>) {
        if (body['data'] is Map) {
          data = Map<String, dynamic>.from(body['data'] as Map);
        } else {
          data = body;
        }
      } else {
        data = <String, dynamic>{};
      }

      String value(dynamic v) => v == null ? '' : v.toString().trim();

      return <String, String>{
        'aadhar': value(data['aadharDocUrl']),
        'pan': value(data['panDocUrl']),
        'rc': value(data['rcCopyDocUrl']),
        'drivingLicense': value(data['drivingLicenseDocUrl']),
      };
    } catch (e) {
      debugPrint('_fetchDriverDocUrls error: $e');
    }

    return <String, String>{};
  }

  // ---------------------------------------------------------------------------
  // File for a given document type
  // ---------------------------------------------------------------------------

  File? fileForType(String type) {
    switch (type) {
      case 'aadhar':
        return aadharFile.value;
      case 'pan':
        return panFile.value;
      case 'rc':
        return rcCopyFile.value;
      case 'drivingLicense':
        return drivingLicenseFile.value;
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Pick document
  // ---------------------------------------------------------------------------

  Future<void> pickDocument({
    required String type,
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        return;
      }

      final file = File(pickedFile.path);

      switch (type) {
        case 'aadhar':
          aadharFile.value = file;
          break;

        case 'pan':
          panFile.value = file;
          break;

        case 'rc':
          rcCopyFile.value = file;
          break;

        case 'drivingLicense':
          drivingLicenseFile.value = file;
          break;

        default:
          debugPrint('Unknown document type: $type');
          return;
      }

      Get.back(); // close the camera/gallery source sheet
      update();
    } catch (e) {
      debugPrint('pickDocument error: $e');

      ShowToastDialog.showToast(
        'Unable to select document',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Remove document
  // ---------------------------------------------------------------------------

  void removeDocument(String type) {
    switch (type) {
      case 'aadhar':
        aadharFile.value = null;
        break;

      case 'pan':
        panFile.value = null;
        break;

      case 'rc':
        rcCopyFile.value = null;
        break;

      case 'drivingLicense':
        drivingLicenseFile.value = null;
        break;

      default:
        debugPrint('Unknown document type: $type');
        return;
    }

    update();
  }

  // ---------------------------------------------------------------------------
  // Check whether all required documents are selected
  // ---------------------------------------------------------------------------

  bool validateDocuments() {
    if (aadharFile.value == null) {
      ShowToastDialog.showToast(
        'Please upload Aadhaar document',
      );
      return false;
    }

    if (panFile.value == null) {
      ShowToastDialog.showToast(
        'Please upload PAN document',
      );
      return false;
    }

    if (rcCopyFile.value == null) {
      ShowToastDialog.showToast(
        'Please upload RC copy',
      );
      return false;
    }

    if (drivingLicenseFile.value == null) {
      ShowToastDialog.showToast(
        'Please upload Driving License',
      );
      return false;
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Submit documents
  // ---------------------------------------------------------------------------

  Future<bool> submitDocuments() async {
    if (!validateDocuments()) {
      return false;
    }

    try {
      isSubmittingIdentity.value = true;
      update();

      // -----------------------------------------------------------------------
      // Logged-in driver ID
      // -----------------------------------------------------------------------

      final userId = await LoginController.getFirebaseId();
      final modelId = Constant.userModel?.id ?? '';
      final String driverId =
          modelId.trim().isNotEmpty ? modelId : userId;

      if (driverId.trim().isEmpty) {
        ShowToastDialog.showToast(
          'Driver ID not found. Please login again.',
        );

        return false;
      }

      debugPrint('========================================');
      debugPrint('Uploading driver documents');
      debugPrint('Driver ID: $driverId');
      debugPrint('Entity Type: DRIVER');
      debugPrint('Aadhar: ${aadharFile.value!.path}');
      debugPrint('PAN: ${panFile.value!.path}');
      debugPrint('RC: ${rcCopyFile.value!.path}');
      debugPrint(
        'Driving License: ${drivingLicenseFile.value!.path}',
      );
      debugPrint('========================================');

      // -----------------------------------------------------------------------
      // Multipart request
      // -----------------------------------------------------------------------

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(_uploadDocumentsUrl),
      );

      // -----------------------------------------------------------------------
      // Form fields
      // -----------------------------------------------------------------------

      request.fields['entityId'] = driverId.toString();

      request.fields['entityType'] = 'driver';

      // -----------------------------------------------------------------------
      // Aadhaar
      // -----------------------------------------------------------------------

      request.files.add(
        await http.MultipartFile.fromPath(
          'aadharFile',
          aadharFile.value!.path,
        ),
      );

      // -----------------------------------------------------------------------
      // PAN
      // -----------------------------------------------------------------------

      request.files.add(
        await http.MultipartFile.fromPath(
          'panFile',
          panFile.value!.path,
        ),
      );

      // -----------------------------------------------------------------------
      // RC Copy
      // -----------------------------------------------------------------------

      request.files.add(
        await http.MultipartFile.fromPath(
          'rcCopyFile',
          rcCopyFile.value!.path,
        ),
      );

      // -----------------------------------------------------------------------
      // Driving License
      // -----------------------------------------------------------------------

      request.files.add(
        await http.MultipartFile.fromPath(
          'drivingLicenseFile',
          drivingLicenseFile.value!.path,
        ),
      );



      request.headers.addAll(await getHeaders());
      // -----------------------------------------------------------------------
      // Send request
      // -----------------------------------------------------------------------

      final streamedResponse = await request.send().timeout(
        _httpTimeout,
      );

      final response = await http.Response.fromStream(
        streamedResponse,
      );

      debugPrint(
        'Upload response status: ${response.statusCode}',
      );

      debugPrint(
        'Upload response body: ${response.body}',
      );

      // -----------------------------------------------------------------------
      // Success
      // -----------------------------------------------------------------------

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        isSubmitted.value = true;

        ShowToastDialog.showToast(
          'Documents uploaded successfully',
        );

        // Clear selected files after successful upload.
        aadharFile.value = null;
        panFile.value = null;
        rcCopyFile.value = null;
        drivingLicenseFile.value = null;

        // Refresh documents.
        await getDocument();

        update();

        return true;
      }

      // -----------------------------------------------------------------------
      // API error
      // -----------------------------------------------------------------------

      String message = 'Failed to upload documents';

      try {
        final body = jsonDecode(response.body);

        if (body is Map<String, dynamic>) {
          if (body['message'] != null) {
            message = body['message'].toString();
          } else if (body['error'] != null) {
            message = body['error'].toString();
          }
        }
      } catch (_) {
        if (response.body.isNotEmpty) {
          message = response.body;
        }
      }

      ShowToastDialog.showToast(message);

      return false;
    } on TimeoutException {
      debugPrint('Document upload timeout');

      ShowToastDialog.showToast(
        'Request timed out. Please try again.',
      );

      return false;
    } on SocketException catch (e) {
      debugPrint('Document upload socket error: $e');

      ShowToastDialog.showToast(
        'Unable to connect to server',
      );

      return false;
    } catch (e) {
      debugPrint('Document upload error: $e');

      ShowToastDialog.showToast(
        'Something went wrong while uploading documents',
      );

      return false;
    } finally {
      isSubmittingIdentity.value = false;

      update();
    }
  }

  // ---------------------------------------------------------------------------
  // Backward-compatible method
  // ---------------------------------------------------------------------------
  //
  // If your existing VerificationScreen is still calling:
  //
  // controller.submitIdentityDetails()
  //
  // you don't need to change it immediately.
  //
  // This now uploads the four documents instead of using the old
  // JSON identity API.
  //
  // ---------------------------------------------------------------------------

  Future<bool> submitIdentityDetails() async {
    return await submitDocuments();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool get hasAadhar => aadharFile.value != null;

  bool get hasPan => panFile.value != null;

  bool get hasRcCopy => rcCopyFile.value != null;

  bool get hasDrivingLicense =>
      drivingLicenseFile.value != null;

  bool get allDocumentsSelected =>
      hasAadhar &&
          hasPan &&
          hasRcCopy &&
          hasDrivingLicense;
}