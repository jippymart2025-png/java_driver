import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/models/payment_model/flutter_wave_model.dart';
import 'package:jippydriver_driver/models/payment_model/paypal_model.dart';
import 'package:jippydriver_driver/models/payment_model/razorpay_model.dart';
import 'package:jippydriver_driver/models/payment_model/stripe_model.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/models/withdraw_method_model.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/services/auth_http_client.dart';

class WithdrawMethodSetupController extends GetxController {
  // ── Text controllers ─────────────────────────────────────────────────────
  final accountNumberFlutterWave = TextEditingController().obs;
  final bankCodeFlutterWave = TextEditingController().obs;
  final emailPaypal = TextEditingController().obs;
  final accountIdRazorPay = TextEditingController().obs;
  final accountIdStripe = TextEditingController().obs;

  // ── State ─────────────────────────────────────────────────────────────────
  final userBankDetails = UserBankDetails().obs;
  final withdrawMethodModel = WithdrawMethodModel().obs;
  final isBankDetailsAdded = false.obs;
  final isLoading = true.obs;

  // ── Payment settings ──────────────────────────────────────────────────────
  final razorPayModel = RazorPayModel().obs;
  final paypalDataModel = PayPalModel().obs;
  final stripeSettingData = StripeModel().obs;
  final flutterWaveSettingData = FlutterWaveModel().obs;

  @override
  void onInit() {
    super.onInit();
    // Fetch both in parallel for faster loading
    _initData();
  }

  @override
  void onClose() {
    accountNumberFlutterWave.value.dispose();
    bankCodeFlutterWave.value.dispose();
    emailPaypal.value.dispose();
    accountIdRazorPay.value.dispose();
    accountIdStripe.value.dispose();
    super.onClose();
  }

  // ── Initialise both calls simultaneously ──────────────────────────────────

  Future<void> _initData() async {
    isLoading.value = true;
    await Future.wait([
      _fetchWithdrawMethod(),
      _fetchPaymentSettings(),
    ]);
    isLoading.value = false;
  }

  // ── Public refresh (called after save) ───────────────────────────────────

  Future<void> getPaymentMethod() async {
    await _fetchWithdrawMethod();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _fetchWithdrawMethod() async {
    _clearTextControllers();
    try {
      final value = await FireStoreUtils.getWithdrawMethod();
      if (value != null) {
        withdrawMethodModel.value = value;
        _populateControllers(value);
      }
    } catch (e) {
      debugPrint('Error fetching withdraw method: $e');
    }
  }

  Future<void> _fetchPaymentSettings() async {
    try {
      // Populate bank details from cached user model first (instant)
      final bankDetails = Constant.userModel?.userBankDetails;
      if (bankDetails != null) {
        userBankDetails.value = bankDetails;
        isBankDetailsAdded.value =
            bankDetails.accountNumber.isNotEmpty == true;
      }

      final uri = Uri.parse("${Constant.baseUrl}settings/payment");
      final response =
      await AuthHttpClient().get(uri);

      if (response.statusCode == 200) {
        final json =
        jsonDecode(response.body) as Map<String, dynamic>;
        if (json['success'] == true && json['data'] != null) {
          final data = json['data'] as Map<String, dynamic>;
          razorPayModel.value =
              RazorPayModel.fromJson(data['razorpaySettings'] ?? {});
          paypalDataModel.value =
              PayPalModel.fromJson(data['paypalSettings'] ?? {});
          stripeSettingData.value =
              StripeModel.fromJson(data['stripeSettings'] ?? {});
          flutterWaveSettingData.value =
              FlutterWaveModel.fromJson(data['flutterWave'] ?? {});
        }
      } else {
        debugPrint(
            'Payment settings returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching payment settings: $e');
    }
  }

  void _clearTextControllers() {
    accountNumberFlutterWave.value.clear();
    bankCodeFlutterWave.value.clear();
    emailPaypal.value.clear();
    accountIdRazorPay.value.clear();
    accountIdStripe.value.clear();
  }

  void _populateControllers(WithdrawMethodModel model) {
    final fw = model.flutterWave;
    if (fw != null) {
      accountNumberFlutterWave.value.text = fw.accountNumber ?? '';
      bankCodeFlutterWave.value.text = fw.bankCode ?? '';
    }
    if (model.paypal != null) {
      emailPaypal.value.text = model.paypal!.email ?? '';
    }
    if (model.razorpay != null) {
      accountIdRazorPay.value.text = model.razorpay!.accountId ?? '';
    }
    if (model.stripe != null) {
      accountIdStripe.value.text = model.stripe!.accountId ?? '';
    }
  }
}