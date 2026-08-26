import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jippydriver_driver/app/wallet_screen/screens/model/delivery_amount_model.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/controllers/login_controller.dart';
import 'package:jippydriver_driver/models/payment_model/flutter_wave_model.dart';
import 'package:jippydriver_driver/models/payment_model/paypal_model.dart';
import 'package:jippydriver_driver/models/payment_model/razorpay_model.dart';
import 'package:jippydriver_driver/models/payment_model/stripe_model.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/models/wallet_transaction_model.dart';
import 'package:jippydriver_driver/models/withdraw_method_model.dart';
import 'package:jippydriver_driver/models/withdrawal_model.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/services/wallet_api_service.dart';
import 'package:jippydriver_driver/models/driver_incentive_model.dart';

class WalletController extends GetxController {
  // ─── Loading & Pagination State ────────────────────────────────────────────
  final RxBool isLoading = true.obs;
  final RxBool isIncentiveTab = false.obs;
  final RxBool isFetchingMore = false.obs;
  final RxBool hasMore = true.obs;


  int _currentPage = 1;
  static const int _perPage = 20;

  int incentivePage = 0;
  final RxBool incentiveHasMore = true.obs;

  // ─── Form Controllers ───────────────────────────────────────────────────────
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  // ─── Data ───────────────────────────────────────────────────────────────────
  final Rx<UserModel> userModel = UserModel().obs;
  final RxDouble totalWalletAmount = 0.0.obs;
  final RxList<WalletTransactionModel> transactions = <WalletTransactionModel>[].obs;
  final RxList<DriverIncentiveModel> incentives = <DriverIncentiveModel>[].obs;

  final RxDouble totalIncentiveAmount = 0.0.obs;

  final RxString incentiveFilter = 'all'.obs;

  final RxList<WithdrawalModel> withdrawalList = <WithdrawalModel>[].obs;




  // ─── Earnings breakdowns (kept for future use) ──────────────────────────────
  final RxList<DriverAmountWalletTransactionModel> dailyEarningList =
      <DriverAmountWalletTransactionModel>[].obs;
  final RxList<DriverAmountWalletTransactionModel> monthlyEarningList =
      <DriverAmountWalletTransactionModel>[].obs;
  final RxList<DriverAmountWalletTransactionModel> yearlyEarningList =
      <DriverAmountWalletTransactionModel>[].obs;

  // ─── UI State ───────────────────────────────────────────────────────────────
  final RxInt selectedWithdrawMethod = 0.obs;


  // ─── Payment Settings ───────────────────────────────────────────────────────
  final Rx<WithdrawMethodModel> withdrawMethodModel = WithdrawMethodModel().obs;
  final Rx<PayPalModel> payPalModel = PayPalModel().obs;
  final Rx<StripeModel> stripeModel = StripeModel().obs;
  final Rx<FlutterWaveModel> flutterWaveModel = FlutterWaveModel().obs;
  final Rx<RazorPayModel> razorPayModel = RazorPayModel().obs;

  // ─── Scroll controller for infinite scroll ──────────────────────────────────
  final ScrollController scrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    _initialLoad();
    scrollController.addListener(_onScroll);
  }

  @override
  void onClose() {
    amountController.dispose();
    noteController.dispose();
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.onClose();
  }

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Full refresh — clears list and fetches page 1.
  // Future<void> refresh() async {
  //   _currentPage = 1;
  //   hasMore.value = true;
  //   transactions.clear();
  //   await _fetchPage();
  // }

  Future<void> refresh() async {
    _currentPage = 1;
    hasMore.value = true;

    transactions.clear();
    incentives.clear();
    await _fetchPage();

    if (isIncentiveTab.value) {
      await fetchIncentiveHistory(reset: true);
    }
  }

  // ─── Private helpers ────────────────────────────────────────────────────────

  Future<void> _initialLoad() async {
    isLoading.value = true;

    await Future.wait([
      _fetchPage(),
      fetchIncentiveHistory(),
    ]);

    isLoading.value = false;
  }

  Future<void> _fetchPage() async {
    if (!hasMore.value) return;

    try {
      // final response = await FireStoreUtils.getWalletTransaction(
      //   page: _currentPage,
      //   perPage: _perPage,
      // final driverId = await LoginController.getFirebaseId();
      //final driverId = "1";
      final driverId = "5";

      log("DRIVER ID = $driverId");
      final response = await ApiService.getWalletTransactions(
        page: _currentPage,
        perPage: _perPage,
        driverId: driverId,
      );

      if (response == null) return;

      // Update wallet balance only on first page (authoritative value)
      log("TOTAL WALLET = ${response.totalWalletAmount}");
      if (_currentPage == 1) {
        totalWalletAmount.value = response.totalWalletAmount;
        userModel.update((u) => u?.walletAmount = response.totalWalletAmount);
      }

      final newItems = response.data;
      transactions.addAll(newItems);

      // Determine if more pages exist
      hasMore.value = newItems.length >= _perPage;
      if (hasMore.value) _currentPage++;
    } catch (e, st) {
      log('WalletController._fetchPage error: $e\n$st');
    }
  }

  Future<void> fetchIncentiveHistory({
    bool reset = true,
  }) async {
    try {

      log("USER ID = ${userModel.value.id}");
      log("FIREBASE ID = ${userModel.value.firebaseId}");

      if (reset) {
        incentivePage = 0;
        incentives.clear();
      }

      final response =
      await ApiService.getDriverIncentiveHistory(
        driverId: 1,
        filter: incentiveFilter.value,
        page: incentivePage,
        size: 20,
      );

      if (response == null) return;

      incentives.addAll(response.content);

      totalIncentiveAmount.value = incentives.fold(
        0.0,
            (sum, item) =>
        sum + (item.incentiveAmount ?? 0),
      );

      incentiveHasMore.value = !response.last;

      if (!response.last) {
        incentivePage++;
      }

      log(
        "INCENTIVES COUNT = ${incentives.length}",
      );

      log(
        "TOTAL INCENTIVE = ${totalIncentiveAmount.value}",
      );
    } catch (e, st) {
      log(
        'fetchIncentiveHistory error: $e\n$st',
      );
    }
  }

  void _onScroll() {
    final threshold = scrollController.position.maxScrollExtent - 200;
    if (scrollController.position.pixels >= threshold &&
        !isFetchingMore.value &&
        hasMore.value) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    isFetchingMore.value = true;
    await _fetchPage();
    isFetchingMore.value = false;
  }

  // ─── Withdrawal helpers ─────────────────────────────────────────────────────

  String get selectedMethodKey {
    switch (selectedWithdrawMethod.value) {
      case 1:
        return 'flutterwave';
      case 2:
        return 'paypal';
      case 3:
        return 'razorpay';
      case 4:
        return 'stripe';
      default:
        return 'bank';
    }
  }

  bool get hasValidPaymentMethod =>
      (Constant.userModel?.userBankDetails?.accountNumber.isNotEmpty ?? false) ||
          withdrawMethodModel.value.id != null;

  double get minimumWithdrawal =>
      double.tryParse(Constant.minimumAmountToWithdrawal) ?? 0;

  get driverRecordAmountController => null;

  /// Called after a successful withdrawal to sync local balance.
  void deductFromWallet(double amount) {
    totalWalletAmount.value -= amount;
    userModel.update((u) => u?.walletAmount = totalWalletAmount.value);
  }
}