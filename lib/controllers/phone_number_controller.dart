import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/app/auth_screen/otp_screen.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:jippydriver_driver/utils/common.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PhoneNumberController extends GetxController {
  Rx<TextEditingController> phoneNUmberEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> countryCodeEditingController =
      TextEditingController().obs;
  RxBool isSending = false.obs;

  @override
  void onInit() {
    AppLogger.log('PhoneNumberController onInit() called', tag: 'Controller');
    super.onInit();
  }

  @override
  void onClose() {
    AppLogger.log('PhoneNumberController onClose() called', tag: 'Controller');
    phoneNUmberEditingController.value.dispose();
    countryCodeEditingController.value.dispose();
    super.onClose();
  }

  Future<void> sendCode() async {
    if (isSending.value) return;

    final mobileNumber = phoneNUmberEditingController.value.text.trim();

    if (mobileNumber.isEmpty) {
      ShowToastDialog.showToast("Please enter mobile number".tr);
      return;
    }
    if (mobileNumber.length < 10) {
      ShowToastDialog.showToast("Please enter a valid mobile number".tr);
      return;
    }

    isSending.value = true;

    try {
      ShowToastDialog.showLoader("please wait...".tr);

      final response = await http.post(
        Uri.parse('${Constant.baseUrl}fm/auth/send-login-otp'),
        headers: await getHeaders(),
        body: json.encode({
          'userType': 'DRIVER',
          'mobileNumber': mobileNumber,
        }),
      );

      AppLogger.log(
        'send-login-otp response [${response.statusCode}]: ${response.body}',
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
          responseData['message']?.toString() ?? 'OTP sent'.tr,
        );

        Get.to(const OtpScreen(), arguments: {
          "countryCode": countryCodeEditingController.value.text,
          "phoneNumber": mobileNumber,
        });
      } else {
        SendShowMessage(responseData);
      }
    } on http.ClientException catch (e) {
      AppLogger.log('Network error: $e', tag: 'Auth');
      ShowToastDialog.showToast('Network error: ${e.message}'.tr);
    } catch (e) {
      AppLogger.log('send-login-otp error: $e', tag: 'Auth');
      ShowToastDialog.showToast('An error occurred'.tr);
    } finally {
      ShowToastDialog.closeLoader();
      isSending.value = false;
    }
  }

  void SendShowMessage(Map<String, dynamic> responseData) {
    final message = responseData['message']?.toString().trim() ??
        responseData['error']?.toString().trim() ??
        'Failed to send OTP'.tr;
    ShowToastDialog.showToast(
        message.isEmpty ? 'Failed to send OTP'.tr : message);
  }
}