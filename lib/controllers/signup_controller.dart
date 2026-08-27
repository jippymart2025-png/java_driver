import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/app/auth_screen/login_screen.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/utils/common.dart';
//import 'package:jippydriver_driver/models/zone_model.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/utils/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../models/state_model.dart';
import 'package:jippydriver_driver/models/city_model.dart';
import 'package:jippydriver_driver/models/area_model.dart';
import 'package:jippydriver_driver/app/dash_board_screen/dash_board_screen.dart';
/// OPTIMIZATIONS:
/// 1. validateAndSignup() — all validation lives in the controller, not the view.
/// 2. signUpWithEmailAndPassword: unified null-safety with ?. and ?? operators.
/// 3. Removed dead commented-out code.
/// 4. Controllers disposed in onClose().
/// 5. _buildUserModel() helper removes duplicated field assignments.

class SignupController extends GetxController {
  // ── State ──────────────────────────────────────────────────────────────────
  final firstNameEditingController = TextEditingController().obs;
  final lastNameEditingController = TextEditingController().obs;
  final emailEditingController = TextEditingController().obs;
  final phoneNUmberEditingController = TextEditingController().obs;
  final countryCodeEditingController = TextEditingController().obs;
  final passwordEditingController = TextEditingController().obs;
  final conformPasswordEditingController = TextEditingController().obs;

  final nomineeNameEditingController =
      TextEditingController().obs;

  final nomineePhoneEditingController =
      TextEditingController().obs;

  final familyMemberNameEditingController =
      TextEditingController().obs;

  final familyMemberPhoneEditingController =
      TextEditingController().obs;

  final aadharNumberEditingController =
      TextEditingController().obs;

  final drivingLicenseEditingController =
      TextEditingController().obs;

  final rcNumberEditingController =
      TextEditingController().obs;

  final buildingNumberEditingController =
      TextEditingController().obs;

  final latitude = 0.0.obs;
  final longitude = 0.0.obs;

  final roadEditingController =
      TextEditingController().obs;

  final landmarkEditingController =
      TextEditingController().obs;

  final passwordVisible = true.obs;
  final conformPasswordVisible = true.obs;
  final type = ''.obs;
  final userModel = UserModel().obs;
  //final zoneList = <ZoneModel>[].obs;
  //final selectedZone = ZoneModel().obs;
final stateList = <StateModel>[].obs;
final selectedState = Rxn<StateModel>();
  final selectedCityId = RxnInt();
  RxList<CityModel> cityList = <CityModel>[].obs;

  Rx<CityModel?> selectedCity = Rx<CityModel?>(null);
  final selectedAreaId = RxnInt();
  RxList<AreaModel> areaList = <AreaModel>[].obs;

  Rx<AreaModel?> selectedArea = Rx<AreaModel?>(null);
  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _getArguments();
  }

  @override
  void onClose() {
    firstNameEditingController.value.dispose();
    lastNameEditingController.value.dispose();
    emailEditingController.value.dispose();
    phoneNUmberEditingController.value.dispose();
    //countryCodeEditingController.value.dispose();
    passwordEditingController.value.dispose();
    nomineeNameEditingController.value.dispose();
    nomineePhoneEditingController.value.dispose();
    familyMemberNameEditingController.value.dispose();
    familyMemberPhoneEditingController.value.dispose();
    aadharNumberEditingController.value.dispose();
    drivingLicenseEditingController.value.dispose();
    rcNumberEditingController.value.dispose();
    buildingNumberEditingController.value.dispose();
    roadEditingController.value.dispose();
    landmarkEditingController.value.dispose();
    //conformPasswordEditingController.value.dispose();
    super.onClose();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Called by the UI. All validation lives here — view stays dumb.
  Future<void> validateAndSignup() async {
    final isThirdParty = type.value == 'google' ||
        type.value == 'apple' ||
        type.value == 'mobileNumber';

    final firstName = firstNameEditingController.value.text.trim();
    final lastName = lastNameEditingController.value.text.trim();
    final email = emailEditingController.value.text.trim();
    final phone = phoneNUmberEditingController.value.text.trim();
    final password = passwordEditingController.value.text.trim();
    final confirmPassword = conformPasswordEditingController.value.text.trim();
    final fcmToken = await NotificationService.getToken();

    final body = {
    'type': 'email',
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'password': password,
    'phone_number': phone,
    'fcm_token': fcmToken,
    'app_identifier': Platform.isAndroid ? 'android' : 'ios',
      };

    if (firstName.isEmpty) {
      ShowToastDialog.showToast('Please enter first name'.tr);
      return;
    }
    if (lastName.isEmpty) {
      ShowToastDialog.showToast('Please enter last name'.tr);
      return;
    }
    if (email.isEmpty) {
      ShowToastDialog.showToast('Please enter email address'.tr);
      return;
    }

    if (!GetUtils.isEmail(email)) {
      ShowToastDialog.showToast('Please enter a valid email'.tr);
      return;
    }
    if (phone.isEmpty) {
      ShowToastDialog.showToast('Please enter phone number'.tr);
      return;
    }

    if (phone.length != 10) {
      ShowToastDialog.showToast('Phone number must be 10 digits'.tr);
      return;
    }

    final nomineeName =
    nomineeNameEditingController.value.text.trim();

    if (nomineeName.isEmpty) {
      ShowToastDialog.showToast(
        'Please enter nominee name'.tr,
      );
      return;
    }

    final nomineePhone =
    nomineePhoneEditingController.value.text.trim();

    if (nomineePhone.isEmpty) {
      ShowToastDialog.showToast(
        'Please enter nominee phone number'.tr,
      );
      return;
    }
    final familyMemberName =
    familyMemberNameEditingController.value.text.trim();

    if (familyMemberName.isEmpty) {
      ShowToastDialog.showToast(
        'Please enter family member name'.tr,
      );
      return;
    }

    final familyMemberPhone =
    familyMemberPhoneEditingController.value.text.trim();

    if (familyMemberPhone.isEmpty) {
      ShowToastDialog.showToast(
        'Please enter family member phone number'.tr,
      );
      return;
    }

    if (familyMemberPhone.length != 10) {
      ShowToastDialog.showToast(
        'Family member phone number must be 10 digits'.tr,
      );
      return;
    }

    if (nomineePhone.length != 10) {
      ShowToastDialog.showToast(
        'Nominee phone number must be 10 digits'.tr,
      );
      return;
    }

    final aadharNumber =
    aadharNumberEditingController.value.text.trim();

    if (aadharNumber.isEmpty) {
      ShowToastDialog.showToast(
        'Please enter Aadhaar number'.tr,
      );
      return;
    }

    if (aadharNumber.length != 12) {
      ShowToastDialog.showToast(
        'Aadhaar number must be 12 digits'.tr,
      );
      return;
    }

    final drivingLicense =
    drivingLicenseEditingController.value.text.trim();

    if (drivingLicense.isEmpty) {
      ShowToastDialog.showToast(
        'Please enter driving license number'.tr,
      );
      return;
    }

    final rcNumber =
    rcNumberEditingController.value.text.trim();

    if (rcNumber.isEmpty) {
      ShowToastDialog.showToast(
        'Please enter RC number'.tr,
      );
      return;
    }

    final buildingNumber =
    buildingNumberEditingController.value.text.trim();

    if (buildingNumber.isEmpty) {
      ShowToastDialog.showToast(
        'Please enter building number'.tr,
      );
      return;
    }
    final road =
    roadEditingController.value.text.trim();

    if (road.isEmpty) {
      ShowToastDialog.showToast(
        'Please enter road'.tr,
      );
      return;
    }
    final landmark =
    landmarkEditingController.value.text.trim();

    if (landmark.isEmpty) {
      ShowToastDialog.showToast(
        'Please enter landmark'.tr,
      );
      return;
    }
    if (selectedState.value == null) {
      ShowToastDialog.showToast(
        'Please select state'.tr,
      );
      return;
    }
    if (selectedCity.value == null) {
      ShowToastDialog.showToast(
        'Please select city'.tr,
      );
      return;
    }
    if (selectedArea.value == null) {
      ShowToastDialog.showToast(
        'Please select area'.tr,
      );
      return;
    }
    if (!isThirdParty) {
      if (password.isEmpty) {
        ShowToastDialog.showToast('Please enter password'.tr);
        return;
      }

      final passwordRegex = RegExp(
        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@#$%^&+=!]).{8,20}$',
      );

      if (!passwordRegex.hasMatch(password)) {
        ShowToastDialog.showToast(
          'Password must contain uppercase, lowercase, number and special character'.tr,
        );
        return;
      }

      if (confirmPassword.isEmpty) {
        ShowToastDialog.showToast('Please enter confirm password'.tr);
        return;
      }

      if (password != confirmPassword) {
        ShowToastDialog.showToast(
          "Please make sure your passwords match".tr,
        );
        return;
      }
    }
    signUpWithEmailAndPassword();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _getArguments() async {
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      type.value = args['type'] as String? ?? '';
      userModel.value = args['userModel'] as UserModel? ?? UserModel();

      switch (type.value) {
        case 'mobileNumber':
          phoneNUmberEditingController.value.text =
              userModel.value.phoneNumber ?? '';
          countryCodeEditingController.value.text =
              userModel.value.countryCode ?? '+91';
          break;
        case 'google':
        case 'apple':
          emailEditingController.value.text = userModel.value.email ?? '';
          firstNameEditingController.value.text =
              userModel.value.firstName ?? '';
          lastNameEditingController.value.text = userModel.value.lastName ?? '';
          break;
      }
    }

    // Default country code
    if (countryCodeEditingController.value.text.isEmpty) {
      countryCodeEditingController.value.text = '+91';
    }

    // try {
    //   final zones = await FireStoreUtils.getZone();
    //   zoneList.value = zones ?? [];
    //   log('Loaded ${zoneList.length} zones');
    // } catch (e) {
    //   log('Error loading zones: $e');
    //   zoneList.value = [];
    // }
    await fetchStates();
  }

  Future<void> fetchStates() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${Constant.baseUrl}fm/location/fetchStates',
        ),
        headers: await getHeaders(),
      );

      print('Status Code: ${response.statusCode}');
      print('States Response: ${response.body}');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        stateList.value =
            data.map((e) => StateModel.fromJson(e)).toList();

        log('Loaded ${stateList.length} states');
      }
    } catch (e) {
      log('Error fetching states: $e');
    }
  }
  //--------FETCH CITIES---------
  Future<void> fetchCities(int stateId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${Constant.baseUrl}fm/location/fetchCityInState?stateId=$stateId',
        ),
        headers:  await getHeaders()
      );

      print('City Status Code: ${response.statusCode}');
      print('City Response: ${response.body}');

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        cityList.value =
            data.map((e) => CityModel.fromJson(e)).toList();

        selectedCity.value = null; // ADD THIS LINE

        print('Loaded ${cityList.length} cities');
      }
    } catch (e) {
      print('City Error: $e');
    }
  }

  //---------FETCH AREAS------------
  Future<void> fetchAreas(int cityId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${Constant.baseUrl}fm/location/fetchAreaInCity?cityId=$cityId',
        ),
        headers: await getHeaders()
      );

      print('Area Status Code: ${response.statusCode}');
      print('Area Response: ${response.body}');

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        areaList.value =
            data.map((e) => AreaModel.fromJson(e)).toList();
        selectedArea.value = null;

        print('Loaded ${areaList.length} areas');
      }
    } catch (e) {
      print('Area Error: $e');
    }
  }

  /// Populates userModel with form values — avoids repeating the same
  /// assignments in both code paths.
  Future<void> _buildUserModel({String? id, String? provider}) async {
    userModel.value
      ..id = id ?? userModel.value.id
      ..firstName = firstNameEditingController.value.text.trim()
      ..lastName = lastNameEditingController.value.text.trim()
      ..email = emailEditingController.value.text.trim().toLowerCase()
      ..phoneNumber = phoneNUmberEditingController.value.text.trim()
      // ..role = Constant.userRoleDriver
      ..fcmToken = await NotificationService.getToken()
      ..active = Constant.autoApproveDriver == true
      ..isDocumentVerify = Constant.isDriverVerification != true
      ..countryCode = countryCodeEditingController.value.text
      ..createdAt = Timestamp.now();
      //..createdAt = DateTime.now()
      //..zoneId = selectedZone.value.id
      // ..appIdentifier = Platform.isAndroid ? 'android' : 'ios'
      // ..provider = provider ?? userModel.value.provider;
  }

  Future<void> signUpWithEmailAndPassword() async {

    ShowToastDialog.showLoader('Please wait'.tr);

    try {
      final isThirdParty =
          type.value == 'google' ||
              type.value == 'apple' ||
              type.value == 'mobileNumber';

      if (isThirdParty) {
        await _buildUserModel();

        final updated =
        await _updateUserWithoutIsActive(userModel.value);

        if (updated) {
          _handlePostSignup();
        } else {
          ShowToastDialog.showToast(
            'Failed to save user data'.tr,
          );
        }
      } else {
        await _signupWithApi();
      }
    } on SocketException {
      ShowToastDialog.showToast(
        'No internet connection'.tr,
      );
    } catch (e) {
      log('Signup error: $e');
      ShowToastDialog.showToast(
        'Something went wrong'.tr,
      );
    } finally {
      ShowToastDialog.closeLoader();
    }
  }


  Future<void> _signupWithApi() async {
    final body = {
      'firstName': firstNameEditingController.value.text.trim(),
      'lastName': lastNameEditingController.value.text.trim(),
      'phoneNumber': phoneNUmberEditingController.value.text.trim(),
      'email': emailEditingController.value.text.trim().toLowerCase(),
      'nomineeName': nomineeNameEditingController.value.text.trim(),
      'nomineePhoneNumber': nomineePhoneEditingController.value.text.trim(),
      'familyMemberName': familyMemberNameEditingController.value.text.trim(),
      'familyMemberPhoneNumber':
      familyMemberPhoneEditingController.value.text.trim(),
      'aadharNumber': aadharNumberEditingController.value.text.trim(),
      'drivingLicenseNumber':
      drivingLicenseEditingController.value.text.trim(),
      'buildingNumber': buildingNumberEditingController.value.text.trim(),
      'road': roadEditingController.value.text.trim(),
      'landmark': landmarkEditingController.value.text.trim(),
      'stateId': selectedState.value?.stateId,
      'cityId': selectedCity.value?.cityId,
      'areaId': selectedArea.value?.areaId,
      'password': passwordEditingController.value.text.trim(),
      'latitude' : latitude.value,
      'longitude' : longitude.value,

      // Temporary RC value
      'rcCopy': rcNumberEditingController.value.text.trim().isEmpty
          ? 'temp_rc_copy'
          : rcNumberEditingController.value.text.trim(),
    };

    try {
      log(
        'Signup Request: '
            '${const JsonEncoder.withIndent('  ').convert(body)}',
      );

      final url = Uri.parse(
        '${Constant.baseUrl}driver/postDriverDetails',
      );

      log('Signup API URL: $url');

      final response = await http
          .post(
        url,
        headers: await getHeaders(),
        body: jsonEncode(body),
      )
          .timeout(
        const Duration(seconds: 30),
      );

      log(
        'Signup Response [${response.statusCode}]: '
            '${response.body}',
      );

      Map<String, dynamic> responseData;

      try {
        final decodedResponse = jsonDecode(response.body);

        if (decodedResponse is Map<String, dynamic>) {
          responseData = decodedResponse;
        } else {
          ShowToastDialog.showToast(
            'Invalid server response'.tr,
          );
          return;
        }
      } catch (e) {
        log('JSON Decode Error: $e');

        ShowToastDialog.showToast(
          'Invalid server response'.tr,
        );

        return;
      }

      // ============================
      // SUCCESS
      // ============================

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        final driverId = responseData['driverId'];

        log('Driver ID: $driverId');

        ShowToastDialog.showToast(
          responseData['message']?.toString() ??
              'Registration successful. Please login.',
        );

        // Go to Login Screen
        Get.offAll(
              () => const LoginScreen(),
        );

        return;
      }

      // ============================
      // API ERROR
      // ============================

      ShowToastDialog.showToast(
        responseData['message']?.toString() ??
            'Signup failed',
      );
    } on TimeoutException {
      log('Signup API request timed out');

      ShowToastDialog.showToast(
        'Request timed out. Please try again.'.tr,
      );
    } on SocketException {
      log('Signup API network error');

      ShowToastDialog.showToast(
        'No internet connection. Please try again.'.tr,
      );
    } catch (e) {
      log('Signup API Error: $e');

      ShowToastDialog.showToast(
        'Something went wrong. Please try again.'.tr,
      );
    }
  }
  Future<bool> _updateUserWithoutIsActive(UserModel user) async {
    try {
      final payload = user.toJson();
      payload.remove('isActive');

      if (payload['createdAt'] is Timestamp) {
        payload['createdAt'] =
            (payload['createdAt'] as Timestamp)
                .millisecondsSinceEpoch;
      }

      log("UPDATE URL => ${Constant.baseUrl}driver-sql/users/update");
      log("UPDATE PAYLOAD => ${json.encode(payload)}");
      // final response = await http.post(
      //   Uri.parse('${Constant.baseUrl}driver-sql/users/update'),
      //   headers: const {
      //     'Content-Type': 'application/json',
      //   },
      //   body: json.encode(payload),
      // );
      final driverId = payload['id'];

      final response = await http.put(
        Uri.parse(
          '${Constant.baseUrl}driver/updateDriverDetails?driverId=$driverId',
        ),
        headers: await getHeaders(),
        body: jsonEncode({
          "firstName": user.firstName,
          "lastName": user.lastName,
          "phoneNumber": user.phoneNumber,
          "email": user.email,
        }),
      );

      // if (response.statusCode == 200) {
      //   final responseData =
      //   json.decode(response.body) as Map<String, dynamic>;
      //
      //   if (responseData['success'] == true) {
      //     Constant.userModel = user;
      //     return true;
      //   }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData =
        json.decode(response.body) as Map<String, dynamic>;

        log('UPDATE SUCCESS => $responseData');

        Constant.userModel = user;
        return true;

      }

      log(
        'Update user failed. Status: ${response.statusCode}, Body: ${response.body}',
      );

      return false;
    } catch (e) {
  log('Failed to update user without isActive: $e');
  return false;
  }
  }

  void _handlePostSignup() {
    if (Constant.autoApproveDriver == true) {
      ShowToastDialog.showToast('Account created successfully'.tr);
    } else {
      ShowToastDialog.showToast(
          'Thank you for signing up. Your application is under review — we\'ll notify you once it\'s approved.'
              .tr);
    }
    // Get.offAll(const LoginScreen());
    Get.offAll(() => const DashBoardScreen());
  }
}
