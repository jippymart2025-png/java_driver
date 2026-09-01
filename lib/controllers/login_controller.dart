



import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/app/auth_screen/login_screen.dart';
import 'package:jippydriver_driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:jippydriver_driver/app/mandatory_update_screen.dart';
import 'package:jippydriver_driver/app/on_boarding_screen.dart';
import 'package:jippydriver_driver/app/verification_screen/verification_screen.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:jippydriver_driver/utils/driver_location_sync.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/utils/notification_service.dart';
import 'package:jippydriver_driver/utils/preferences.dart';
import 'package:jippydriver_driver/utils/version_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/common.dart';

/// OPTIMIZATIONS:
/// 1. Added validateAndLogin() — separates UI validation from business logic.
/// 2. _saveUserToSharedPreferences uses a single prefs instance and batches
///    Future.wait where possible for parallel writes.
/// 3. Removed dead commented-out code (Firebase Auth methods) — kept in
///    version control if needed.
/// 4. Static helpers (getFirebaseId, logout) remain static — they don't need
///    instance state.
/// 5. Proper resource cleanup in onClose().
class LoginController extends GetxController {
  // ── State ──────────────────────────────────────────────────────────────────
  final emailEditingController = TextEditingController().obs;
  final passwordEditingController = TextEditingController().obs;
  final passwordVisible = true.obs;

  bool _isDriverEnabled(UserModel userModel) {
    // Keep auth decision simple: only `active` controls login access.
    return userModel.active == true;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void onInit() {
    AppLogger.log('LoginController onInit()', tag: 'Controller');
    super.onInit();
  }

  @override
  void onClose() {
    AppLogger.log('LoginController onClose()', tag: 'Controller');
    emailEditingController.value.dispose();
    passwordEditingController.value.dispose();
    super.onClose();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Called directly by the UI — keeps all validation here so the view stays
  /// dumb.
  void validateAndLogin() {
    final email = emailEditingController.value.text.trim();
    final password = passwordEditingController.value.text.trim();

    if (email.isEmpty || !GetUtils.isEmail(email)) {
      ShowToastDialog.showToast('Please enter a valid email address'.tr);
      return;
    }
    if (password.isEmpty) {
      ShowToastDialog.showToast('Please enter your password'.tr);
      return;
    }
    loginWithEmailAndPassword();
  }

  Future<void> redirectScreen() async {
    final userId = await LoginController.getFirebaseId();

    log('======================================');
    log('redirectScreen()');
    log('Firebase userId: $userId');
    log('======================================');

    try {
      // ---------------------------------------------------------
      // 1. Check onboarding
      // ---------------------------------------------------------
      final isOnboardingFinished =
      Preferences.getBoolean(Preferences.isFinishOnBoardingKey);

      if (isOnboardingFinished == false) {
        log('Onboarding not completed');

        Get.offAll(
              () => const OnBoardingScreen(),
        );

        return;
      }

      // ---------------------------------------------------------
      // 2. Check login
      // ---------------------------------------------------------
      final isLoggedIn = await isUserLoggedIn();

      if (!isLoggedIn) {
        log('User is not logged in');

        Get.offAll(
              () => const LoginScreen(),
        );

        return;
      }

      // ---------------------------------------------------------
      // 3. Load user from NEW SERVER / SharedPreferences
      // ---------------------------------------------------------
      //
      // IMPORTANT:
      // Do NOT load Firestore user first here.
      //
      // Your new API returns:
      //
      // "isApproved": true
      //
      // UserModel converts that into:
      //
      // isDocumentVerify = true
      //
      // So SharedPreferences/new-server data should be
      // the authoritative source.
      // ---------------------------------------------------------

      UserModel? userModel;

      try {
        userModel = await getUserFromSharedPreferences();
      } catch (e, stackTrace) {
        log(
          'getUserFromSharedPreferences failed: $e',
          stackTrace: stackTrace,
        );
      }

      // ---------------------------------------------------------
      // 4. User not found
      // ---------------------------------------------------------
      if (userModel == null) {
        log('❌ UserModel is null');

        Get.offAll(
              () => const LoginScreen(),
        );

        return;
      }

      // ---------------------------------------------------------
      // 5. DEBUG USER DATA
      // ---------------------------------------------------------
      log('======================================');
      log('USER DATA');
      log('driverId: ${userModel.id}');
      log('email: ${userModel.email}');
      log('role: ${userModel.role}');
      log('isDocumentVerify: ${userModel.isDocumentVerify}');
      log('active: ${userModel.active}');
      log('isActive: ${userModel.isActive}');
      log('======================================');

      // ---------------------------------------------------------
      // 6. Load application settings
      // ---------------------------------------------------------
      try {
        await FireStoreUtils.getSettings();
      } catch (e) {
        log('getSettings failed: $e');
      }

      try {
        await FireStoreUtils.getForceUpdateConfig();
      } catch (e) {
        log('getForceUpdateConfig failed: $e');
      }

      // ---------------------------------------------------------
      // 7. Check driver role
      // ---------------------------------------------------------
      if (userModel.role != Constant.userRoleDriver) {
        log(
          '❌ Invalid role: ${userModel.role}, '
              'expected: ${Constant.userRoleDriver}',
        );

        Get.offAll(
              () => const LoginScreen(),
        );

        return;
      }

      // ---------------------------------------------------------
      // 8. Check driver enabled/active
      // ---------------------------------------------------------
      if (!_isDriverEnabled(userModel)) {
        log('❌ Driver is disabled/inactive');

        Get.offAll(
              () => const LoginScreen(),
        );

        return;
      }

      // ---------------------------------------------------------
      // 9. Mandatory update check
      // ---------------------------------------------------------
      if (await isMandatoryUpdateRequired()) {
        log('⚠️ Mandatory update required');

        Get.offAll(
              () => const MandatoryUpdateScreen(),
        );

        return;
      }

      // ---------------------------------------------------------
      // 10. Restore FCM token
      // ---------------------------------------------------------
      try {
        final prefs = await SharedPreferences.getInstance();

        final cachedToken = prefs.getString('fcmToken') ?? '';

        if (cachedToken.trim().isNotEmpty) {
          userModel.fcmToken = cachedToken;

          log('FCM token restored from SharedPreferences');
        }
      } catch (e) {
        log('FCM token restore failed: $e');
      }

      // ---------------------------------------------------------
      // 11. Set global user
      // ---------------------------------------------------------
      Constant.userModel = userModel;

      // ---------------------------------------------------------
      // 12. APPROVAL CHECK
      // ---------------------------------------------------------
      //
      // API:
      //
      // "isApproved": true
      //
      // becomes:
      //
      // userModel.isDocumentVerify == true
      //
      // Therefore:
      //
      // true  -> Dashboard
      // false -> Verification
      // null  -> Verification
      //
      // ---------------------------------------------------------

      if (userModel.isDocumentVerify == true) {
        // =======================================================
        // APPROVED DRIVER
        // =======================================================

        log('======================================');
        log('✅ DRIVER APPROVED');
        log('isDocumentVerify = true');
        log('Opening Dashboard');
        log('======================================');

        Get.offAll(
              () => DashBoardScreen(
            userModel: userModel!,
          ),
        );

        // Sync location after dashboard is loaded.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(
            DriverLocationSync.syncDeviceLocationIntoUserModel(),
          );
        });
      } else {
        // =======================================================
        // NOT APPROVED DRIVER
        // =======================================================

        log('======================================');
        log('⚠️ DRIVER NOT APPROVED');
        log('isDocumentVerify = ${userModel.isDocumentVerify}');
        log('Opening Verification Screen');
        log('======================================');

        Get.offAll(
              () => const VerificationScreen(),
        );
      }
    } catch (e, stackTrace) {
      // ---------------------------------------------------------
      // GLOBAL ERROR
      // ---------------------------------------------------------
      log(
        'redirectScreen error: $e',
        stackTrace: stackTrace,
      );

      Get.offAll(
            () => const LoginScreen(),
      );
    }
  }
  Future<void> loginWithEmailAndPassword() async {
    ShowToastDialog.showLoader('Please wait'.tr);

    try {
      final email = emailEditingController.value.text.trim();
      final password = passwordEditingController.value.text.trim();

      final response = await http.post(
        Uri.parse('${Constant.baseUrl}fm/auth/login'),
        headers: await getHeaders(),
        body: json.encode({
          'username': email,
          'password': password,
        }),
      );

      log(
        'Login response [${response.statusCode}]: ${response.body}',
      );

      Map<String, dynamic> responseData;

      try {
        responseData = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        log('Invalid JSON response: $e');

        ShowToastDialog.showToast(
          'Invalid response from server'.tr,
        );

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
     *   "userId": 12,
     *   "roles": []
     * }
     * ============================================================
     */

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData['jwt'] != null) {
        final jwt = responseData['jwt'].toString().trim();
        final userType =
            responseData['userType']?.toString().trim().toUpperCase() ?? '';
        final userId = responseData['userId']?.toString().trim() ?? '';

        log('JWT received: ${jwt.isNotEmpty}');
        log('userType: $userType');
        log('userId: $userId');

        // ------------------------------------------------------------
        // Validate driver
        // ------------------------------------------------------------

        if (userType != 'DRIVER') {
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
          prefs.setString('userEmail', email),
          prefs.setString('userRole', Constant.userRoleDriver),
          prefs.setString('userType', userType),
          prefs.setBool('isLoggedIn', true),
        ]);

        // ------------------------------------------------------------
        // Get FCM token
        // ------------------------------------------------------------

        try {
          final fcmToken = await NotificationService.getToken();

          if (fcmToken != null && fcmToken.trim().isNotEmpty) {
            await prefs.setString(
              'fcmToken',
              fcmToken.trim(),
            );
          }
        } catch (e) {
          log('FCM token error: $e');
        }

        log('✅ Login successful');
        log('✅ Driver ID: $userId');
        log('✅ JWT saved');

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
            headers: await getHeaders()
          );

          log('getDriverDetails response [${driverResponse.statusCode}]: ${driverResponse.body}');

          if (driverResponse.statusCode >= 200 &&
              driverResponse.statusCode < 300) {
            final driverData =
            json.decode(driverResponse.body);

            Map<String, dynamic> userDetails;

            if (driverData is Map<String, dynamic>) {
              if (driverData['data'] is Map) {
                userDetails = Map<String, dynamic>.from(
                  driverData['data'] as Map,
                );
              } else {
                userDetails = Map<String, dynamic>.from(
                  driverData,
                );
              }
            } else {
              userDetails = {};
            }

            if (userDetails.isNotEmpty) {
              // Parse using UserModel
              final UserModel userModel =
              UserModel.fromJson(userDetails);

              // Keep the same normalized data
              userDetails = userModel.toJson();

              // Make sure role exists
              userModel.role ??= Constant.userRoleDriver;

              // Save model data
              await _saveUserToSharedPreferences(
                userModel.toJson(),
              );

              // Keep the model globally available
              Constant.userModel = userModel;

              log(
                '✅ Driver UserModel loaded: '
                    'id=${userModel.id}, '
                    'name=${userModel.fullName()}',
              );
            }
          } else {
            log('⚠️ getDriverDetails failed: ${driverResponse.statusCode}');
          }
        } catch (e) {
          log('⚠️ getDriverDetails error: $e');
        }

        // ------------------------------------------------------------
        // Continue to existing redirect flow
        // ------------------------------------------------------------

        await redirectScreen();

        return;
      }

      /*
     * ============================================================
     * OLD API RESPONSE SUPPORT
     *
     * If your backend sometimes still returns:
     *
     * {
     *   "success": true,
     *   "data": {...}
     * }
     * ============================================================
     */

      if (response.statusCode == 200 &&
          responseData['success'] == true &&
          responseData['data'] != null) {
        final userData =
        responseData['data'] as Map<String, dynamic>;

        final userModel = UserModel.fromJson(userData);

        if (userModel.role != Constant.userRoleDriver) {
          ShowToastDialog.showToast(
            'This user is not created in driver application.'.tr,
          );
          return;
        }

        if (!_isDriverEnabled(userModel)) {
          ShowToastDialog.showToast(
            'This user is disabled. Please contact the administrator.'.tr,
          );
          return;
        }

        await _saveUserToSharedPreferences(userData);

        try {
          userModel.fcmToken =
          await NotificationService.getToken();

          await prefsSetFcmToken(userModel.fcmToken);
        } catch (e) {
          log('FCM token error: $e');
        }

        await FireStoreUtils.updateUser(userModel);

        await redirectScreen();

        return;
      }

      /*
     * ============================================================
     * LOGIN FAILED
     * ============================================================
     */

      String message =
          responseData['message']?.toString().trim() ??
              responseData['error']?.toString().trim() ??
              'Login failed'.tr;

      if (message.isEmpty) {
        message = 'Login failed'.tr;
      }

      ShowToastDialog.showToast(message);
    } on http.ClientException catch (e) {
      log('Network error: $e');

      ShowToastDialog.showToast(
        'Network error: ${e.message}'.tr,
      );
    } on FormatException catch (e) {
      log('Format error: $e');

      ShowToastDialog.showToast(
        'Invalid response format'.tr,
      );
    } catch (e, stackTrace) {
      log(
        'Login error: $e',
        stackTrace: stackTrace,
      );

      ShowToastDialog.showToast(
        'An error occurred during login'.tr,
      );
    } finally {
      ShowToastDialog.closeLoader();
    }
  }
  // ── SharedPreferences helpers ──────────────────────────────────────────────

  Future<void> _saveUserToSharedPreferences(
      Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      bool _readBool(dynamic value, {bool defaultValue = false}) {
        if (value is bool) return value;
        if (value is num) return value != 0;
        if (value is String) {
          final v = value.trim().toLowerCase();
          if (v == '1' || v == 'true' || v == 'yes') return true;
          if (v == '0' || v == 'false' || v == 'no') return false;
        }
        return defaultValue;
      }

      int _readInt(dynamic value, {int defaultValue = 0}) {
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) return int.tryParse(value.trim()) ?? defaultValue;
        return defaultValue;
      }

      double _readDouble(dynamic value, {double defaultValue = 0.0}) {
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value.trim()) ?? defaultValue;
        return defaultValue;
      }

      String _readString(dynamic value, {String defaultValue = ''}) {
        if (value == null) return defaultValue;
        return value.toString();
      }

      final resolvedUserId = _readString(userData['id']).trim();
      final resolvedFirebaseId = [
        _readString(userData['firebase_id']).trim(),
        _readString(userData['firebaseId']).trim(),
        resolvedUserId,
      ].firstWhere((v) => v.isNotEmpty, orElse: () => '');

      // Write everything in parallel using Future.wait
      await Future.wait([
        prefs.setString('userData', json.encode(userData)),
        prefs.setBool('isLoggedIn', true),
        prefs.setString('userId', resolvedUserId),
        prefs.setString('firebase_id', resolvedFirebaseId),
        prefs.setString('userEmail', _readString(userData['email'])),
        prefs.setString('userPassword', _readString(userData['password'])),
        prefs.setString('userRole', _readString(userData['role'])),
        prefs.setString('firstName', _readString(userData['firstName'])),
        prefs.setString('lastName', _readString(userData['lastName'])),
        prefs.setString('phoneNumber', _readString(userData['phoneNumber'])),
        prefs.setString('countryCode', _readString(userData['countryCode'])),
        prefs.setString('fcmToken', _readString(userData['fcmToken'])),
        prefs.setString('appIdentifier', _readString(userData['appIdentifier'])),
        prefs.setString('provider', _readString(userData['provider'])),
        prefs.setString('zoneId', _readString(userData['zoneId'])),
        prefs.setBool('isActive', _readBool(userData['isActive'])),
        prefs.setString(
            'isApproved', userData['isDocumentVerify']?.toString() ?? ''),
        prefs.setInt('active', _readInt(userData['active'])),
        prefs.setDouble('wallet_amount', _readDouble(userData['wallet_amount'])),
        prefs.setDouble('deliveryAmount', _readDouble(userData['deliveryAmount'])),
        prefs.setString('carName', _readString(userData['carName'])),
        prefs.setString('carNumber', _readString(userData['carNumber'])),
        prefs.setString('carPictureURL', _readString(userData['carPictureURL'])),
        prefs.setString('subscriptionPlanId', _readString(userData['subscriptionPlanId'])),
        if (userData['createdAt'] != null)
          prefs.setString('createdAt', userData['createdAt'].toString()),
        if (userData['location'] != null)
          prefs.setString('userLocation', json.encode(userData['location'])),
        if (userData['userBankDetails'] != null)
          prefs.setString(
              'userBankDetails', json.encode(userData['userBankDetails'])),
        if (userData['subscriptionExpiryDate'] != null)
          prefs.setString('subscriptionExpiryDate',
              userData['subscriptionExpiryDate'].toString()),
      ]);

      log('✅ User data saved — id=${userData['id']}, email=${userData['email']}');
    } catch (e) {
      log('❌ Error saving user to SharedPreferences: $e');
    }
  }

  Future<void> prefsSetFcmToken(String? token) async {
    if (token == null || token.trim().isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'fcmToken',
      token.trim(),
    );
  }

  Future<UserModel?> getUserFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('userData');
      if (userJson == null) return null;
      return UserModel.fromJson(json.decode(userJson) as Map<String, dynamic>);
    } catch (e) {
      log('Error reading user from SharedPreferences: $e');
      return null;
    }
  }

  Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<String> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userEmail') ?? '';
  }

  Future<String> getUserPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userPassword') ?? '';
  }

  static Future<String> getFirebaseId() async {
    final prefs = await SharedPreferences.getInstance();
    final firebaseId = (prefs.getString('firebase_id') ?? '').trim();
    if (firebaseId.isNotEmpty) return firebaseId;
    return (prefs.getString('userId') ?? '').trim();
  }

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('firebase_id') ?? '';

      final keysToRemove = [
        'userData', 'isLoggedIn', 'userId', 'firebase_id', 'userEmail',
        'userPassword', 'userRole', 'firstName', 'lastName', 'phoneNumber',
        'countryCode', 'fcmToken', 'appIdentifier', 'provider', 'zoneId',
        'isActive', 'isDocumentVerify', 'active', 'wallet_amount',
        'deliveryAmount', 'createdAt', 'carName', 'carNumber', 'carPictureURL',
        'userLocation', 'userBankDetails', 'subscriptionPlanId',
        'subscriptionExpiryDate',
        if (uid.isNotEmpty) ...[
          'verif_id_draft_$uid',
          'verif_id_draft_aadhaar_$uid',
          'verif_id_draft_dl_$uid',
        ],
      ];

      await Future.wait(keysToRemove.map(prefs.remove));
      Get.offAll(const LoginScreen());
      log('✅ All user data cleared from SharedPreferences');
    } catch (e) {
      log('❌ Logout error: $e');
    }
  }

  // ── Utility ────────────────────────────────────────────────────────────────
  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  // Keep singleton reference if needed elsewhere
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
}