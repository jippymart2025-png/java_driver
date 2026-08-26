



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
    log('redirectScreen userId=$userId');

    try {
      if (Preferences.getBoolean(Preferences.isFinishOnBoardingKey) == false) {
        Get.offAll(const OnBoardingScreen());
        return;
      }

      final isLogin = await FireStoreUtils.isLogin();
      if (!isLogin) {
        Get.offAll(const LoginScreen());
        return;
      }

      final userModel = await FireStoreUtils.getUserProfile(userId);
      await FireStoreUtils.getSettings();
      await FireStoreUtils.getForceUpdateConfig();

      if (userModel == null) {
        Get.offAll(const LoginScreen());
        return;
      }

      if (userModel.role != Constant.userRoleDriver) {
        Get.offAll(const LoginScreen());
        return;
      }

      if (!_isDriverEnabled(userModel)) {
        Get.offAll(const LoginScreen());
        return;
      }

      if (await isMandatoryUpdateRequired()) {
        Get.offAll(const MandatoryUpdateScreen());
        return;
      }

      // Dedupe: `loginWithEmailAndPassword()` already generated the FCM token
      // and performed the single authoritative `updateUser()`.
      // Here we just reuse the cached token for this session.
      final prefs = await SharedPreferences.getInstance();
      final cachedToken = prefs.getString('fcmToken') ?? '';
      if (cachedToken.trim().isNotEmpty) {
        userModel.fcmToken = cachedToken;
      }
      // Keep global in-memory user available immediately after first login.
      Constant.userModel = userModel;
      Get.offAll(() => DashBoardScreen(userModel: userModel));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(DriverLocationSync.syncDeviceLocationIntoUserModel());
      });

      if (userModel.isDocumentVerify != true) {
        Future.delayed(const Duration(milliseconds: 120),
                () => Get.to(() => const VerificationScreen()));
      }
    } catch (e) {
      log('redirectScreen error: $e');
      Get.offAll(const LoginScreen());
    }
  }

  Future<void> loginWithEmailAndPassword() async {
    // ShowToastDialog.showToast(
    //     "login temporarily disabled"
    // );
    // return;
    ShowToastDialog.showLoader('Please wait'.tr);
    try {
      final response = await http.post(
        Uri.parse('${Constant.baseUrl}driver/login'),
        //Uri.parse('http://187.127.156.147:8084/api/fm/auth/login'),
        headers:
        {
          //const {'Content-Type': 'application/json'},
          'Content-Type': 'application/json',
        'accept': '*/*',
        //'Authorization':
        //'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJjaGFuZGFuYW11bmphQGdtYWlsLmNvbSIsInJvbGVzIjpbIlJPTEVfREVWQURNSU4iXSwidXNlcklkIjo1LCJpYXQiOjE3ODE1ODg0MzYsImV4cCI6MTc4MTY3NDgzNn0.vej38x22jMXmgGpi8McNp6tmVr_P3YPROeYyfSR4jJY',
          },
        body: json.encode({
          'email': emailEditingController.value.text.trim(),
          'password': passwordEditingController.value.text.trim(),
        }),
      );

      log('Login response [${response.statusCode}]: ${response.body}');

      final responseData = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          responseData['success'] == true &&
          responseData['data'] != null) {
        final userData = responseData['data'] as Map<String, dynamic>;
        final userModel = UserModel.fromJson(userData);

        await _saveUserToSharedPreferences(userData);

        if (userModel.role != Constant.userRoleDriver) {
          ShowToastDialog.showToast(
              'This user is not created in driver application.'.tr);
          return;
        }

        if (!_isDriverEnabled(userModel)) {
          ShowToastDialog.showToast(
              'This user is disabled. Please contact the administrator.'.tr);
          return;
        }

        userModel.fcmToken = await NotificationService.getToken();
        // Make the token available for `redirectScreen()` without requiring
        // a second `updateUser()` call.
        await (await SharedPreferences.getInstance())
            .setString('fcmToken', userModel.fcmToken ?? '');
        await FireStoreUtils.updateUser(userModel);
        redirectScreen();
      } else {
        ShowToastDialog.showToast(
            responseData['message'] as String? ?? 'Login failed'.tr);
      }
    } on http.ClientException catch (e) {
      ShowToastDialog.showToast('Network error: ${e.message}'.tr);
    } on FormatException {
      ShowToastDialog.showToast('Invalid response format'.tr);
    } catch (e) {
      log('Login error: $e');
      ShowToastDialog.showToast('An error occurred during login'.tr);
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
            'isDocumentVerify', userData['isDocumentVerify']?.toString() ?? ''),
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