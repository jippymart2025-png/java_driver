// import 'dart:convert';
// import 'dart:io';
//
// import 'package:get/get_connect/http/src/response/response.dart' as http;
// import 'package:jippydriver_driver/constant/constant.dart';
// import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
// import 'package:jippydriver_driver/controllers/login_controller.dart';
// import 'package:jippydriver_driver/models/user_model.dart';
// import 'package:jippydriver_driver/models/zone_model.dart';
// import 'package:jippydriver_driver/utils/fire_store_utils.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:image_picker/image_picker.dart';
//
// class EditProfileController extends GetxController {
//   RxBool isLoading = true.obs;
//
//
//
//   RxBool isUploadingProfileImage = false.obs;
//   Rx<UserModel> userModel = UserModel().obs;
//
//   Rx<TextEditingController> firstNameController = TextEditingController().obs;
//   Rx<TextEditingController> lastNameController = TextEditingController().obs;
//   Rx<TextEditingController> emailController = TextEditingController().obs;
//   Rx<TextEditingController> phoneNumberController = TextEditingController().obs;
//   Rx<TextEditingController> countryCodeController =
//       TextEditingController(text: "+91").obs;
//
//   Rx<ZoneModel> selectedZone = ZoneModel().obs;
//   RxList<ZoneModel> zoneList = <ZoneModel>[].obs;
//
//
//   final ImagePicker _imagePicker = ImagePicker();
//
//   RxString profileImage = "".obs;
//
//   @override
//   void onInit() {
//     super.onInit();
//     _applyUserData(Constant.userModel);
//     getData();
//   }
//
//   Future<void> getData() async {
//     debugPrint("EditProfileController");
//     try {
//       final zones = await FireStoreUtils.getZone();
//       if (zones != null) {
//         zoneList.assignAll(zones);
//       }
//
//       String userId = await LoginController.getFirebaseId();
//       if (userId.trim().isEmpty) {
//         userId = Constant.userModel?.id?.toString() ?? '';
//       }
//
//       final profile = userId.trim().isEmpty
//           ? null
//           : await FireStoreUtils.getUserProfile(userId, forceRefresh: true);
//       _applyUserData(profile ?? Constant.userModel);
//       _syncSelectedZone();
//     } finally {
//       isLoading.value = false;
//     }
//   }
//
//   void _applyUserData(UserModel? data) {
//     if (data == null) return;
//     userModel.value = data;
//     firstNameController.value.text = data.firstName ?? '';
//     lastNameController.value.text = data.lastName ?? '';
//     emailController.value.text = data.email ?? '';
//     phoneNumberController.value.text = data.phoneNumber ?? '';
//     countryCodeController.value.text = data.countryCode ?? '+91';
//     profileImage.value = data.profilePictureURL ?? '';
//     _syncSelectedZone();
//   }
//
//   void _syncSelectedZone() {
//     if (zoneList.isEmpty) return;
//     final zoneId = userModel.value.zoneId;
//     if (zoneId == null) return;
//     for (final element in zoneList) {
//       if (element.id == zoneId) {
//         selectedZone.value = element;
//         break;
//       }
//     }
//   }
//
//   saveData() async {
//     ShowToastDialog.showLoader("Please wait...".tr);
//     if (Constant().hasValidUrl(profileImage.value) == false &&
//         profileImage.value.isNotEmpty) {
//       profileImage.value = await Constant.uploadUserImageToFireStorage(
//         File(profileImage.value),
//         "profileImage/${FireStoreUtils.getCurrentUid()}",
//         File(profileImage.value).path.split('/').last,
//       );
//     }
//
//     userModel.value.firstName = firstNameController.value.text;
//     userModel.value.lastName = lastNameController.value.text;
//     userModel.value.profilePictureURL = profileImage.value;
//     userModel.value.zoneId = selectedZone.value.id;
//
//     await FireStoreUtils.updateUser(userModel.value).then((value) {
//       ShowToastDialog.closeLoader();
//       Get.back(result: true);
//     });
//   }
//
//
//   Future<void> pickFile({
//     required ImageSource source,
//   }) async {
//     try {
//       debugPrint("====================================");
//       debugPrint("Opening Image Picker");
//       debugPrint("Source: $source");
//       debugPrint("====================================");
//
//       final XFile? image =
//       await _imagePicker.pickImage(
//         source: source,
//
//         // Compress image
//         imageQuality: 80,
//
//         // Limit image size
//         maxWidth: 1200,
//         maxHeight: 1200,
//       );
//
//       // User cancelled
//       if (image == null) {
//         debugPrint("Image selection cancelled");
//         return;
//       }
//
//       debugPrint("Selected image: ${image.path}");
//
//       // Close bottom sheet
//       Get.back();
//
//       // ----------------------------------------------------------
//       // SHOW LOCAL IMAGE IMMEDIATELY
//       // ----------------------------------------------------------
//
//       profileImage.value = image.path;
//
//       // ----------------------------------------------------------
//       // UPLOAD TO API
//       // ----------------------------------------------------------
//
//       await uploadProfileImage(
//         File(image.path),
//       );
//     } on PlatformException catch (e) {
//       debugPrint("Image picker PlatformException: $e");
//
//       ShowToastDialog.showToast(
//         "${"failed_to_pick".tr} :\n$e",
//       );
//     } catch (e) {
//       debugPrint("pickFile error: $e");
//
//       ShowToastDialog.showToast(
//         "Failed to select image",
//       );
//     }
//   }
//   Future<bool> uploadProfileImage(
//       File imageFile,
//       ) async {
//     try {
//       // ----------------------------------------------------------
//       // CHECK FILE
//       // ----------------------------------------------------------
//
//       if (!await imageFile.exists()) {
//         debugPrint("Image file does not exist");
//
//         ShowToastDialog.showToast(
//           "Image file not found",
//         );
//
//         return false;
//       }
//
//       // ----------------------------------------------------------
//       // LOADING
//       // ----------------------------------------------------------
//
//       isUploadingProfileImage.value = true;
//
//       ShowToastDialog.showLoader(
//         "Uploading profile picture...",
//       );
//
//       // ----------------------------------------------------------
//       // GET USER ID
//       // ----------------------------------------------------------
//
//       String userId =
//       await LoginController.getFirebaseId();
//
//       debugPrint("Firebase ID: $userId");
//
//       // Fallback
//       if (userId.trim().isEmpty) {
//         userId =
//             Constant.userModel?.id?.toString() ?? '';
//       }
//
//       // ----------------------------------------------------------
//       // CHECK USER ID
//       // ----------------------------------------------------------
//
//       if (userId.trim().isEmpty) {
//         ShowToastDialog.closeLoader();
//
//         ShowToastDialog.showToast(
//           "User ID not found",
//         );
//
//         return false;
//       }
//
//       debugPrint("====================================");
//       debugPrint("PROFILE IMAGE UPLOAD");
//       debugPrint("User ID: $userId");
//       debugPrint("Image: ${imageFile.path}");
//       debugPrint("====================================");
//
//       // ----------------------------------------------------------
//       // API URL
//       // ----------------------------------------------------------
//
//       final Uri url = Uri.parse(
//         "$baseUrl/api/driver/saveOrUpdateProfilePic",
//       );
//
//       debugPrint("API URL: $url");
//
//       // ----------------------------------------------------------
//       // CREATE MULTIPART REQUEST
//       // ----------------------------------------------------------
//
//       final request =
//       http.MultipartRequest(
//         "POST",
//         url,
//       );
//
//       // ----------------------------------------------------------
//       // HEADERS
//       // ----------------------------------------------------------
//
//       request.headers.addAll({
//         "accept": "*/*",
//       });
//
//       // ----------------------------------------------------------
//       // FORM FIELDS
//       // ----------------------------------------------------------
//
//       request.fields["userId"] =
//           userId;
//
//       request.fields["profilePicUrl"] =
//       "";
//
//       request.fields["userType"] =
//       "DRIVER";
//
//       // ----------------------------------------------------------
//       // IMAGE FILE
//       // ----------------------------------------------------------
//
//       final multipartFile =
//       await http.MultipartFile.fromPath(
//         "profilePicFile",
//         imageFile.path,
//       );
//
//       request.files.add(
//         multipartFile,
//       );
//
//       debugPrint("Multipart fields:");
//       debugPrint(request.fields);
//
//       debugPrint("Multipart files:");
//       debugPrint(request.files);
//
//       // ----------------------------------------------------------
//       // SEND REQUEST
//       // ----------------------------------------------------------
//
//       debugPrint("Sending profile image request...");
//
//       final streamedResponse =
//       await request.send();
//
//       // ----------------------------------------------------------
//       // CONVERT RESPONSE
//       // ----------------------------------------------------------
//
//       final response =
//       await http.Response.fromStream(
//         streamedResponse,
//       );
//
//       debugPrint("====================================");
//       debugPrint(
//         "Response Status: ${response.statusCode}",
//       );
//       debugPrint(
//         "Response Body: ${response.body}",
//       );
//       debugPrint("====================================");
//
//       ShowToastDialog.closeLoader();
//
//       // ----------------------------------------------------------
//       // SUCCESS
//       // ----------------------------------------------------------
//
//       if (response.statusCode >= 200 &&
//           response.statusCode < 300) {
//         debugPrint(
//           "Profile image uploaded successfully",
//         );
//
//         // --------------------------------------------------------
//         // TRY TO READ API RESPONSE
//         // --------------------------------------------------------
//
//         String? imageUrl;
//
//         if (response.body.isNotEmpty) {
//           try {
//             final dynamic responseData =
//             jsonDecode(response.body);
//
//             debugPrint(
//               "Parsed API response: $responseData",
//             );
//
//             if (responseData is Map) {
//               imageUrl =
//                   responseData["profilePicUrl"]
//                       ?.toString();
//
//               imageUrl ??=
//                   responseData["profilePictureURL"]
//                       ?.toString();
//
//               imageUrl ??=
//                   responseData["profilePictureUrl"]
//                       ?.toString();
//
//               imageUrl ??=
//                   responseData["url"]
//                       ?.toString();
//
//               // Sometimes API returns:
//               // { "data": { "profilePicUrl": "..." } }
//
//               if (imageUrl == null &&
//                   responseData["data"] is Map) {
//                 final data =
//                 responseData["data"];
//
//                 imageUrl =
//                     data["profilePicUrl"]
//                         ?.toString();
//
//                 imageUrl ??=
//                     data["profilePictureURL"]
//                         ?.toString();
//
//                 imageUrl ??=
//                     data["url"]
//                         ?.toString();
//               }
//             }
//           } catch (e) {
//             debugPrint(
//               "Response is not JSON: $e",
//             );
//           }
//         }
//
//         // --------------------------------------------------------
//         // UPDATE IMAGE URL
//         // --------------------------------------------------------
//
//         if (imageUrl != null &&
//             imageUrl.isNotEmpty &&
//             imageUrl != "null") {
//           debugPrint(
//             "New profile image URL: $imageUrl",
//           );
//
//           profileImage.value =
//               imageUrl;
//
//           userModel.value
//               .profilePictureURL =
//               imageUrl;
//         }
//
//         ShowToastDialog.showToast(
//           "Profile picture updated successfully",
//         );
//
//         return true;
//       }
//
//       // ----------------------------------------------------------
//       // API ERROR
//       // ----------------------------------------------------------
//
//       debugPrint(
//         "Profile image upload failed",
//       );
//
//       debugPrint(
//         "Status: ${response.statusCode}",
//       );
//
//       debugPrint(
//         "Body: ${response.body}",
//       );
//
//       ShowToastDialog.showToast(
//         "Failed to update profile picture",
//       );
//
//       return false;
//     } catch (e) {
//       ShowToastDialog.closeLoader();
//
//       debugPrint(
//         "uploadProfileImage error: $e",
//       );
//
//       ShowToastDialog.showToast(
//         "Something went wrong while uploading image",
//       );
//
//       return false;
//     } finally {
//       isUploadingProfileImage.value = false;
//     }
//   }
//
//   @override
//   void onClose() {
//     firstNameController.value.dispose();
//     lastNameController.value.dispose();
//     emailController.value.dispose();
//     phoneNumberController.value.dispose();
//     countryCodeController.value.dispose();
//     super.onClose();
//   }
// }


import 'dart:convert';
import 'dart:io';

import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/controllers/login_controller.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/models/zone_model.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../utils/common.dart';

class EditProfileController extends GetxController {
  // ============================================================
  // LOADING
  // ============================================================

  RxBool isLoading = true.obs;

  RxBool isUploadingProfileImage = false.obs;

  // ============================================================
  // USER
  // ============================================================

  Rx<UserModel> userModel = UserModel().obs;

  // ============================================================
  // TEXT CONTROLLERS
  // ============================================================

  Rx<TextEditingController> firstNameController =
      TextEditingController().obs;

  Rx<TextEditingController> lastNameController =
      TextEditingController().obs;

  Rx<TextEditingController> emailController =
      TextEditingController().obs;

  Rx<TextEditingController> phoneNumberController =
      TextEditingController().obs;

  Rx<TextEditingController> countryCodeController =
      TextEditingController(text: "+91").obs;

  // ============================================================
  // ZONE
  // ============================================================

  Rx<ZoneModel> selectedZone = ZoneModel().obs;

  RxList<ZoneModel> zoneList = <ZoneModel>[].obs;

  // ============================================================
  // IMAGE
  // ============================================================

  final ImagePicker _imagePicker = ImagePicker();

  RxString profileImage = "".obs;

  // ============================================================
  // API
  // ============================================================


  // ============================================================
  // INIT
  // ============================================================

  @override
  void onInit() {
    super.onInit();

    _applyUserData(Constant.userModel);

    getData();
  }

  // ============================================================
  // GET DATA
  // ============================================================

  Future<void> getData() async {
    debugPrint("====================================");
    debugPrint("EditProfileController getData()");
    debugPrint("====================================");

    try {
      // ----------------------------------------------------------
      // GET ZONES
      // ----------------------------------------------------------

      final zones = await FireStoreUtils.getZone();

      if (zones != null) {
        zoneList.assignAll(zones);
      }

      // ----------------------------------------------------------
      // GET USER ID
      // ----------------------------------------------------------

      String userId =
      await LoginController.getFirebaseId();

      debugPrint("Firebase User ID: $userId");

      if (userId.trim().isEmpty) {
        userId =
            Constant.userModel?.id?.toString() ?? '';
      }

      debugPrint("Final User ID: $userId");

      // ----------------------------------------------------------
      // GET PROFILE
      // ----------------------------------------------------------

      final profile = userId.trim().isEmpty
          ? null
          : await FireStoreUtils.getUserProfile(
        userId,
        forceRefresh: true,
      );

      _applyUserData(
        profile ?? Constant.userModel,
      );

      _syncSelectedZone();
    } catch (e) {
      debugPrint("getData error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================================
  // APPLY USER DATA
  // ============================================================

  void _applyUserData(UserModel? data) {
    if (data == null) {
      return;
    }

    userModel.value = data;

    firstNameController.value.text =
        data.firstName ?? '';

    lastNameController.value.text =
        data.lastName ?? '';

    emailController.value.text =
        data.email ?? '';

    phoneNumberController.value.text =
        data.phoneNumber ?? '';

    countryCodeController.value.text =
        data.countryCode ?? '+91';

    profileImage.value =
        data.profilePictureURL ?? '';

    _syncSelectedZone();
  }

  // ============================================================
  // SYNC ZONE
  // ============================================================

  void _syncSelectedZone() {
    if (zoneList.isEmpty) {
      return;
    }

    final zoneId = userModel.value.zoneId;

    if (zoneId == null) {
      return;
    }

    for (final element in zoneList) {
      if (element.id == zoneId) {
        selectedZone.value = element;
        break;
      }
    }
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> pickFile({
    required ImageSource source,
  }) async {
    try {
      debugPrint("====================================");
      debugPrint("Opening Image Picker");
      debugPrint("Source: $source");
      debugPrint("====================================");

      final XFile? image =
      await _imagePicker.pickImage(
        source: source,

        // Compress image
        imageQuality: 80,

        // Limit image size
        maxWidth: 1200,
        maxHeight: 1200,
      );

      // User cancelled
      if (image == null) {
        debugPrint("Image selection cancelled");
        return;
      }

      debugPrint("Selected image: ${image.path}");

      // Close bottom sheet
      Get.back();

      // ----------------------------------------------------------
      // SHOW LOCAL IMAGE IMMEDIATELY
      // ----------------------------------------------------------

      profileImage.value = image.path;

      // ----------------------------------------------------------
      // UPLOAD TO API
      // ----------------------------------------------------------

      await uploadProfileImage(
        File(image.path),
      );
    } on PlatformException catch (e) {
      debugPrint("Image picker PlatformException: $e");

      ShowToastDialog.showToast(
        "${"failed_to_pick".tr} :\n$e",
      );
    } catch (e) {
      debugPrint("pickFile error: $e");

      ShowToastDialog.showToast(
        "Failed to select image",
      );
    }
  }

  // ============================================================
  // UPLOAD PROFILE IMAGE
  // ============================================================

  Future<bool> uploadProfileImage(
      File imageFile,
      ) async {
    try {
      // ----------------------------------------------------------
      // CHECK FILE
      // ----------------------------------------------------------

      if (!await imageFile.exists()) {
        debugPrint("Image file does not exist");

        ShowToastDialog.showToast(
          "Image file not found",
        );

        return false;
      }

      // ----------------------------------------------------------
      // LOADING
      // ----------------------------------------------------------

      isUploadingProfileImage.value = true;

      ShowToastDialog.showLoader(
        "Uploading profile picture...",
      );

      // ----------------------------------------------------------
      // GET USER ID
      // ----------------------------------------------------------

      String userId =
      await LoginController.getFirebaseId();

      debugPrint("Firebase ID: $userId");

      // If Firebase ID is empty, use your backend user ID
      if (userId.trim().isEmpty) {
        userId =
            Constant.userModel?.id?.toString() ?? '';
      }

      // ----------------------------------------------------------
      // CHECK USER ID
      // ----------------------------------------------------------

      if (userId.trim().isEmpty) {
        ShowToastDialog.closeLoader();

        ShowToastDialog.showToast(
          "User ID not found",
        );

        return false;
      }

      debugPrint("====================================");
      debugPrint("PROFILE IMAGE UPLOAD");
      debugPrint("User ID: $userId");
      debugPrint("Image: ${imageFile.path}");
      debugPrint("====================================");

      // ----------------------------------------------------------
      // API URL
      // ----------------------------------------------------------

      final Uri url = Uri.parse(
        "${Constant.baseUrl}driver/saveOrUpdateProfilePic",
      );

      debugPrint("API URL: $url");

      // ----------------------------------------------------------
      // CREATE MULTIPART REQUEST
      // ----------------------------------------------------------

      final request = http.MultipartRequest(
        "POST",
        url,
      );

      // ----------------------------------------------------------
      // HEADERS
      // ----------------------------------------------------------

      final headers = await getHeaders();

      request.headers.addAll(headers);

      debugPrint("Headers: ${request.headers}");

      // ----------------------------------------------------------
      // FORM FIELDS
      // ----------------------------------------------------------

      request.fields["userId"] = userId;

      request.fields["profilePicUrl"] = "";

      request.fields["userType"] = "DRIVER";

      // ----------------------------------------------------------
      // IMAGE FILE
      // ----------------------------------------------------------

      final multipartFile =
      await http.MultipartFile.fromPath(
        "profilePicFile",
        imageFile.path,
      );

      request.files.add(
        multipartFile,
      );

      // ----------------------------------------------------------
      // DEBUG
      // ----------------------------------------------------------

      debugPrint("====================================");
      debugPrint("Multipart fields:");
      debugPrint("${request.fields}");

      debugPrint("Multipart files:");
      debugPrint("${request.files}");
      debugPrint("====================================");

      // ----------------------------------------------------------
      // SEND REQUEST
      // ----------------------------------------------------------

      debugPrint(
        "Sending profile image request...",
      );

      final streamedResponse =
      await request.send();

      // ----------------------------------------------------------
      // CONVERT RESPONSE
      // ----------------------------------------------------------

      final response =
      await http.Response.fromStream(
        streamedResponse,
      );

      debugPrint("====================================");
      debugPrint(
        "Response Status: ${response.statusCode}",
      );
      debugPrint(
        "Response Body: ${response.body}",
      );
      debugPrint("====================================");

      ShowToastDialog.closeLoader();

      // ----------------------------------------------------------
      // SUCCESS
      // ----------------------------------------------------------

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        debugPrint(
          "Profile image uploaded successfully",
        );

        // --------------------------------------------------------
        // TRY TO READ API RESPONSE
        // --------------------------------------------------------

        String? imageUrl;

        if (response.body.isNotEmpty) {
          try {
            final dynamic responseData =
            jsonDecode(response.body);

            debugPrint(
              "Parsed API response: $responseData",
            );

            if (responseData is Map) {
              imageUrl =
                  responseData["profilePicUrl"]
                      ?.toString();

              imageUrl ??=
                  responseData["profilePictureURL"]
                      ?.toString();

              imageUrl ??=
                  responseData["profilePictureUrl"]
                      ?.toString();

              imageUrl ??=
                  responseData["url"]
                      ?.toString();

              // --------------------------------------------------
              // CHECK data OBJECT
              // --------------------------------------------------

              if (imageUrl == null &&
                  responseData["data"] is Map) {
                final data =
                responseData["data"];

                imageUrl =
                    data["profilePicUrl"]
                        ?.toString();

                imageUrl ??=
                    data["profilePictureURL"]
                        ?.toString();

                imageUrl ??=
                    data["profilePictureUrl"]
                        ?.toString();

                imageUrl ??=
                    data["url"]
                        ?.toString();
              }
            }
          } catch (e) {
            debugPrint(
              "Response is not JSON: $e",
            );
          }
        }

        // --------------------------------------------------------
        // UPDATE IMAGE URL
        // --------------------------------------------------------

        if (imageUrl != null &&
            imageUrl.isNotEmpty &&
            imageUrl != "null") {
          debugPrint(
            "New profile image URL: $imageUrl",
          );

          profileImage.value = imageUrl;

          userModel.value.profilePictureURL =
              imageUrl;
        }

        // --------------------------------------------------------
        // SUCCESS MESSAGE
        // --------------------------------------------------------

        ShowToastDialog.showToast(
          "Profile picture updated successfully",
        );

        return true;
      }

      // ----------------------------------------------------------
      // API ERROR
      // ----------------------------------------------------------

      debugPrint(
        "Profile image upload failed",
      );

      debugPrint(
        "Status: ${response.statusCode}",
      );

      debugPrint(
        "Body: ${response.body}",
      );

      ShowToastDialog.showToast(
        "Failed to update profile picture",
      );

      return false;
    } catch (e, stackTrace) {
      ShowToastDialog.closeLoader();

      debugPrint(
        "uploadProfileImage error: $e",
      );

      debugPrint(
        "StackTrace: $stackTrace",
      );

      ShowToastDialog.showToast(
        "Something went wrong while uploading image",
      );

      return false;
    } finally {
      isUploadingProfileImage.value = false;
    }
  }
  // ============================================================
  // SAVE OTHER PROFILE DATA
  // ============================================================

  Future<void> saveData() async {
    try {
      ShowToastDialog.showLoader(
        "Please wait...".tr,
      );

      // ----------------------------------------------------------
      // UPDATE USER MODEL
      // ----------------------------------------------------------

      userModel.value.firstName =
          firstNameController.value.text;

      userModel.value.lastName =
          lastNameController.value.text;

      userModel.value.profilePictureURL =
          profileImage.value;

      userModel.value.zoneId =
          selectedZone.value.id;

      // ----------------------------------------------------------
      // UPDATE FIRESTORE USER
      // ----------------------------------------------------------

      await FireStoreUtils.updateUser(
        userModel.value,
      );

      ShowToastDialog.closeLoader();

      Get.back(
        result: true,
      );
    } catch (e) {
      ShowToastDialog.closeLoader();

      debugPrint(
        "saveData error: $e",
      );

      ShowToastDialog.showToast(
        "Failed to update profile",
      );
    }
  }

  // ============================================================
  // CLOSE
  // ============================================================

  @override
  void onClose() {
    firstNameController.value.dispose();
    lastNameController.value.dispose();
    emailController.value.dispose();
    phoneNumberController.value.dispose();
    countryCodeController.value.dispose();

    super.onClose();
  }
}