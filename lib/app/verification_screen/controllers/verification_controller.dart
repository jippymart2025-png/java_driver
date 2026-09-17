import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:jippydriver_driver/app/dash_board_screen/screens/dash_board_screen.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/app/auth_screen/controller/login_controller.dart';
import 'package:jippydriver_driver/models/document_model.dart';
import 'package:jippydriver_driver/models/driver_document_model.dart';
import 'package:jippydriver_driver/utils/common.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';

class VerificationController extends GetxController {
  // ---------------------------------------------------------------------------
  // API
  // ---------------------------------------------------------------------------

  static String get _uploadDocumentsUrl =>
      '${Constant.baseUrl}fm/outlets/saveOrUpdateDocuments';

  static String get _profilePicUrl =>
      '${Constant.baseUrl}driver/saveOrUpdateProfilePic';

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
  // Profile picture
  // ---------------------------------------------------------------------------

  final Rxn<File> profilePicFile = Rxn<File>();

  final RxBool isUploadingProfilePic = false.obs;

  final RxString profilePicUrl = ''.obs;

  // ---------------------------------------------------------------------------
  // Approval / dashboard redirect
  // ---------------------------------------------------------------------------

  final RxBool isApproved = false.obs;

  Timer? _approvalPollTimer;

  static const Duration _approvalPollInterval = Duration(seconds: 15);

  bool _redirectedToDashboard = false;

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

    profilePicUrl.value = Constant.userModel?.profilePictureURL ?? '';
    isApproved.value = Constant.userModel?.isDocumentVerify == true;

    _startApprovalPolling();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkApprovalAndRedirect());
    });

    getDocument();
  }

  @override
  void onClose() {
    _stopApprovalPolling();
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

      profilePicUrl.value = urls['profilePic'] ?? '';
      final approvedValue = urls['isApproved'] ?? '';
      urls.remove('profilePic');
      urls.remove('isApproved');

      isApproved.value =
          approvedValue == 'true' || approvedValue == '1';

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

      await _checkApprovalAndRedirect();
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

  Future<Map<String, String>> _fetchDriverDocUrls({
    bool forceRefresh = false,
  }) async {
    final userId = await LoginController.getFirebaseId();
    if (userId.isEmpty) return <String, String>{};

    try {
      // Uses the shared getDriverDetails cache (FireStoreUtils), so repeated
      // calls reuse the same data instead of re-hitting the API.
      final data = await FireStoreUtils.getDriverDetailsData(
        userId,
        forceRefresh: forceRefresh,
      );
      if (data.isEmpty) return <String, String>{};

      String value(dynamic v) => v == null ? '' : v.toString().trim();

      return <String, String>{
        'aadhar': value(data['aadharDocUrl']),
        'pan': value(data['panDocUrl']),
        'rc': value(data['rcCopyDocUrl']),
        'drivingLicense': value(data['drivingLicenseDocUrl']),
        'profilePic': value(data['profilePicUrl']),
        'isApproved': value(data['isApproved']),
      };
    } catch (e) {
      debugPrint('_fetchDriverDocUrls error: $e');
    }

    return <String, String>{};
  }

  // ---------------------------------------------------------------------------
  // Refresh driver details (getDriverDetails) after a successful upload
  // ---------------------------------------------------------------------------

  Future<void> refreshAfterUpload() async {
    try {
      // Force a fresh fetch (post-upload), then the shared cache serves it.
      final urls = await _fetchDriverDocUrls(forceRefresh: true);

      profilePicUrl.value = urls['profilePic'] ?? '';
      final approvedValue = urls['isApproved'] ?? '';
      urls.remove('profilePic');
      urls.remove('isApproved');

      isApproved.value =
          approvedValue == 'true' || approvedValue == '1';

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

      final userId = await LoginController.getFirebaseId();
      if (userId.isNotEmpty) {
        // No forceRefresh: reuses the data just fetched above via the shared
        // getDriverDetails cache, so no extra API call.
        final user = await FireStoreUtils.getUserProfile(
          userId,
        );
        if (user != null) {
          Constant.userModel = user;
          isApproved.value = user.isDocumentVerify == true;
          if ((user.profilePictureURL ?? '').trim().isNotEmpty) {
            profilePicUrl.value = user.profilePictureURL!;
          }
        }
      }

      await _checkApprovalAndRedirect();
    } catch (e) {
      debugPrint('refreshAfterUpload error: $e');
    }

    update();
  }

  // ---------------------------------------------------------------------------
  // Approval polling / dashboard redirect
  // ---------------------------------------------------------------------------

  void _startApprovalPolling() {
    _approvalPollTimer?.cancel();
    _approvalPollTimer = Timer.periodic(
      _approvalPollInterval,
      (_) => unawaited(_pollApproval()),
    );
  }

  void _stopApprovalPolling() {
    _approvalPollTimer?.cancel();
    _approvalPollTimer = null;
  }

  Future<void> _pollApproval() async {
    try {
      final userId = await LoginController.getFirebaseId();
      if (userId.isEmpty) return;

      // Cache-backed: only hits the network when the short TTL expires,
      // instead of hammering getDriverDetails every poll.
      final user = await FireStoreUtils.getUserProfile(
        userId,
      );
      if (user != null) {
        Constant.userModel = user;
        isApproved.value = user.isDocumentVerify == true;
        await _checkApprovalAndRedirect();
      }
    } catch (e) {
      debugPrint('_pollApproval error: $e');
    }
  }

  Future<void> _checkApprovalAndRedirect() async {
    if (!isApproved.value || _redirectedToDashboard) return;

    _stopApprovalPolling();
    _redirectedToDashboard = true;

    Get.offAll(
          () => DashBoardScreen(
        userModel: Constant.userModel,
      ),
    );
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
  // Profile picture
  // ---------------------------------------------------------------------------

  Future<void> pickProfilePic({required ImageSource source}) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1280,
        maxHeight: 1280,
        preferredCameraDevice: CameraDevice.front,
      );

      if (pickedFile == null) {
        return;
      }

      Get.back(); // close the camera/gallery source sheet

      profilePicFile.value = File(pickedFile.path);
      update();

      final ok = await submitProfilePic();
      if (ok) {
        ShowToastDialog.showToast(
          'Profile photo uploaded successfully',
        );
      } else {
        ShowToastDialog.showToast(
          'Profile photo upload failed. Please try again.',
        );
      }
    } catch (e) {
      debugPrint('pickProfilePic error: $e');

      ShowToastDialog.showToast(
        'Unable to select profile photo',
      );
    }
  }

  Future<bool> submitProfilePic() async {
    final file = profilePicFile.value;
    if (file == null) {
      return false;
    }

    final userId = await LoginController.getFirebaseId();
    final modelId = Constant.userModel?.id ?? '';
    final String driverId = modelId.trim().isNotEmpty ? modelId : userId;

    if (driverId.trim().isEmpty) {
      ShowToastDialog.showToast(
        'Driver ID not found. Please login again.',
      );
      return false;
    }

    isUploadingProfilePic.value = true;
    update();

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(_profilePicUrl),
      );

      request.fields['userId'] = driverId;
      request.fields['userType'] = 'driver';
      request.fields['profilePicUrl'] = '';

      request.files.add(
        await http.MultipartFile.fromPath(
          'profilePicFile',
          file.path,
        ),
      );

      final token = await getAuthToken();
      request.headers.addAll({
        'accept': '*/*',
        if (token != null && token.isNotEmpty) 'Authorization': token,
      });

      final streamedResponse = await request.send().timeout(_httpTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint(
        'Profile pic upload status: ${response.statusCode}',
      );
      debugPrint(
        'Profile pic upload body: ${response.body}',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        profilePicFile.value = null;

        // Reload from getDriverDetails so the new photo shows on the UI.
        await refreshAfterUpload();

        return true;
      }

      String message = 'Failed to upload profile photo';
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
      ShowToastDialog.showToast(
        'Request timed out. Please try again.',
      );
      return false;
    } on SocketException catch (e) {
      debugPrint('Profile pic upload socket error: $e');
      ShowToastDialog.showToast(
        'Unable to connect to server',
      );
      return false;
    } catch (e) {
      debugPrint('Profile pic upload error: $e');
      ShowToastDialog.showToast(
        'Something went wrong while uploading profile photo',
      );
      return false;
    } finally {
      isUploadingProfilePic.value = false;
      update();
    }
  }

  void clearProfilePic() {
    profilePicFile.value = null;
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

        // Refresh documents + profile from getDriverDetails.
        await refreshAfterUpload();

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