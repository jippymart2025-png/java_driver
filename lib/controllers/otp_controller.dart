import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/controllers/login_controller.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:jippydriver_driver/utils/common.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/utils/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OtpController extends GetxController {
  Rx<TextEditingController> otpController = TextEditingController().obs;

  RxString countryCode = "".obs;
  RxString phoneNumber = "".obs;
  RxString userType = "DRIVER".obs;
  RxBool isLoading = true.obs;
  RxBool isSendingOtp = false.obs;
  RxBool isVerifying = false.obs;

  @override
  void onInit() {
    AppLogger.log('OtpController onInit() called', tag: 'Controller');
    getArgument();
    super.onInit();
  }

  @override
  void onClose() {
    AppLogger.log('OtpController onClose() called', tag: 'Controller');
    otpController.value.dispose();
    super.onClose();
  }

  getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      countryCode.value = argumentData['countryCode'] ?? "";
      phoneNumber.value = argumentData['phoneNumber'] ?? "";
      userType.value = argumentData['userType'] ?? "DRIVER";
    }
    isLoading.value = false;
    update();
  }

  /// Resends a new login OTP to the registered mobile number.
  Future<void> sendOTP() async {
    if (isSendingOtp.value) return;

    isSendingOtp.value = true;
    ShowToastDialog.showLoader("please wait...".tr);
    try {
      final response = await http.post(
        Uri.parse('${Constant.baseUrl}fm/auth/resend-login-otp'),
        headers: await getHeaders(),
        body: json.encode({
          'userType': userType.value,
          'mobileNumber': phoneNumber.value,
        }),
      );

      AppLogger.log(
        'resend-login-otp response [${response.statusCode}]: ${response.body}',
        tag: 'Auth',
      );

      Map<String, dynamic> responseData;
      try {
        responseData = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        ShowToastDialog.showToast("Invalid response from server".tr);
        return;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        ShowToastDialog.showToast(
          responseData['message']?.toString() ?? 'OTP resent'.tr,
        );
      } else {
        ShowToastDialog.showToast(
          responseData['message']?.toString().trim() ??
              responseData['error']?.toString().trim() ??
              'Failed to resend OTP'.tr,
        );
      }
    } on http.ClientException catch (e) {
      AppLogger.log('Network error: $e', tag: 'Auth');
      ShowToastDialog.showToast('Network error: ${e.message}'.tr);
    } catch (e) {
      AppLogger.log('resend-login-otp error: $e', tag: 'Auth');
      ShowToastDialog.showToast('An error occurred'.tr);
    } finally {
      ShowToastDialog.closeLoader();
      isSendingOtp.value = false;
    }
  }

  /// Verifies the OTP and completes the full driver login flow (same as
  /// username/password login).
  Future<void> verifyOTP() async {
    if (isVerifying.value) return;

    final otp = otpController.value.text.trim();

    if (otp.length != 6) {
      ShowToastDialog.showToast("Enter valid OTP".tr);
      return;
    }

    isVerifying.value = true;
    ShowToastDialog.showLoader('Verify OTP'.tr);

    try {
      final response = await http.post(
        Uri.parse('${Constant.baseUrl}fm/auth/verify-login-otp'),
        headers: await getHeaders(),
        body: json.encode({
          'userType': userType.value,
          'mobileNumber': phoneNumber.value,
          'otp': otp,
        }),
      );

      AppLogger.log(
        'verify-login-otp response [${response.statusCode}]: ${response.body}',
        tag: 'Auth',
      );

      Map<String, dynamic> responseData;
      try {
        responseData = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        ShowToastDialog.showToast("Invalid response from server".tr);
        return;
      }

      /*
       * ============================================================
       * SUCCESS RESPONSE
       *
       * Actual API response:
       *
       * {
       *   "jwt": "...",
       *   "userType": "DRIVER",
       *   "userId": 2,
       *   "roles": ["ROLE_DRIVER"]
       * }
       * ============================================================
       */

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData['jwt'] != null) {
        final jwt = responseData['jwt'].toString().trim();
        final verifiedUserType =
            responseData['userType']?.toString().trim().toUpperCase() ?? '';
        final userId = responseData['userId']?.toString().trim() ?? '';

        AppLogger.log('JWT received: ${jwt.isNotEmpty}', tag: 'Auth');
        AppLogger.log('userType: $verifiedUserType', tag: 'Auth');
        AppLogger.log('userId: $userId', tag: 'Auth');

        if (verifiedUserType != 'DRIVER') {
          ShowToastDialog.showToast(
            'This user is not created in driver application.'.tr,
          );
          return;
        }

        if (userId.isEmpty) {
          ShowToastDialog.showToast(
            'Invalid user ID received from server.'.tr,
          );
          return;
        }

        // ------------------------------------------------------------
        // Save authentication information
        // ------------------------------------------------------------

        final prefs = await SharedPreferences.getInstance();

        await Future.wait([
          prefs.setString('jwt', jwt),
          prefs.setString('accessToken', jwt),
          prefs.setString('userId', userId),
          prefs.setString('firebase_id', userId),
          prefs.setString('userEmail', phoneNumber.value),
          prefs.setString('userRole', Constant.userRoleDriver),
          prefs.setString('userType', verifiedUserType),
          prefs.setString('phoneNumber', phoneNumber.value),
          prefs.setString('countryCode', countryCode.value),
          prefs.setBool('isLoggedIn', true),
        ]);

        // ------------------------------------------------------------
        // Get FCM token
        // ------------------------------------------------------------

        try {
          final fcmToken = await NotificationService.getToken();
          if (fcmToken != null && fcmToken.trim().isNotEmpty) {
            await prefs.setString('fcmToken', fcmToken.trim());
          }
        } catch (e) {
          AppLogger.log('FCM token error: $e', tag: 'Auth');
        }

        AppLogger.log('✅ OTP login successful', tag: 'Auth');
        AppLogger.log('✅ Driver ID: $userId', tag: 'Auth');

        // ------------------------------------------------------------
        // Save JWT to FlutterSecureStorage for getHeaders()
        // ------------------------------------------------------------

        await saveAuthToken(jwt);

        // ------------------------------------------------------------
        // Fetch full driver details from getDriverDetails API
        // ------------------------------------------------------------

        try {
          final driverResponse = await http.get(
            Uri.parse(
              '${Constant.baseUrl}driver/getDriverDetails?driverId=$userId',
            ),
            headers: await getHeaders(),
          );

          AppLogger.log(
            'getDriverDetails response [${driverResponse.statusCode}]: '
            '${driverResponse.body}',
            tag: 'Auth',
          );

          if (driverResponse.statusCode >= 200 &&
              driverResponse.statusCode < 300) {
            final driverData = json.decode(driverResponse.body);

            Map<String, dynamic> userDetails;

            if (driverData is Map<String, dynamic>) {
              if (driverData['data'] is Map) {
                userDetails =
                    Map<String, dynamic>.from(driverData['data'] as Map);
              } else {
                userDetails = Map<String, dynamic>.from(driverData);
              }
            } else {
              userDetails = {};
            }

            if (userDetails.isNotEmpty) {
              FireStoreUtils.cacheDriverDetailsData(userId, userDetails);

              final UserModel userModel = UserModel.fromJson(userDetails);
              userDetails = userModel.toJson();
              userModel.role ??= Constant.userRoleDriver;

              await LoginController().saveUserToSharedPreferences(
                userModel.toJson(),
              );

              Constant.userModel = userModel;

              AppLogger.log(
                '✅ Driver UserModel loaded: '
                'id=${userModel.id}, name=${userModel.fullName}',
                tag: 'Auth',
              );
            }
          } else {
            AppLogger.log(
              '⚠️ getDriverDetails failed: ${driverResponse.statusCode}',
              tag: 'Auth',
            );
          }
        } catch (e) {
          AppLogger.log('⚠️ getDriverDetails error: $e', tag: 'Auth');
        }

        // ------------------------------------------------------------
        // Continue to existing redirect flow (dashboard / verification)
        // ------------------------------------------------------------

        await LoginController().redirectScreen();

        return;
      }

      // ------------------------------------------------------------
      // OTP VERIFICATION FAILED
      // ------------------------------------------------------------

      String message = responseData['message']?.toString().trim() ??
          responseData['error']?.toString().trim() ??
          'Invalid OTP'.tr;

      if (message.isEmpty) {
        message = 'Invalid OTP'.tr;
      }

      ShowToastDialog.showToast(message);
    } on http.ClientException catch (e) {
      AppLogger.log('Network error: $e', tag: 'Auth');
      ShowToastDialog.showToast('Network error: ${e.message}'.tr);
    } catch (e) {
      AppLogger.log('verify-login-otp error: $e', tag: 'Auth');
      ShowToastDialog.showToast('An error occurred during OTP verification'.tr);
    } finally {
      ShowToastDialog.closeLoader();
      isVerifying.value = false;
    }
  }
}