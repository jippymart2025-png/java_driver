import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jippydriver_driver/app/wallet_screen/screens/model/delivery_amount_model.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/app/auth_screen/controller/login_controller.dart';
import 'package:jippydriver_driver/models/payment_model/flutter_wave_model.dart';
import 'package:jippydriver_driver/models/payment_model/paypal_model.dart';
import 'package:jippydriver_driver/models/payment_model/razorpay_model.dart';
import 'package:jippydriver_driver/models/payment_model/stripe_model.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/models/wallet_transaction_model.dart';
import 'package:jippydriver_driver/models/withdraw_method_model.dart';
import 'package:jippydriver_driver/models/withdrawal_model.dart';
import 'package:jippydriver_driver/services/wallet_api_service.dart';
import 'package:jippydriver_driver/models/driver_incentive_model.dart';

class WalletController extends GetxController {
  // ─── Loading & Pagination State ────────────────────────────────────────────
  final RxBool isLoading = true.obs;
  final RxBool isIncentiveTab = false.obs;
  final RxBool isFetchingMore = false.obs;
  final RxBool hasMore = true.obs;

  int incentivePage = 0;
  final RxBool incentiveHasMore = true.obs;
  final RxBool isFetchingMoreIncentive = false.obs;
  final RxBool isIncentiveLoading = false.obs;

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
    if (Constant.userModel != null) {
      userModel.value = Constant.userModel!;
    }
    scrollController.addListener(_onScroll);
    _initialLoad();
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

  /// Full refresh — clears both lists and re-fetches from page 1.
  Future<void> refresh() async {
    hasMore.value = true;
    transactions.clear();
    await _fetchPage();
    await fetchIncentiveHistory(reset: true);
  }

  // ─── Private helpers ────────────────────────────────────────────────────────

  /// Resolve the numeric database id the Java API expects.
  Future<String> _resolveDriverId() async {
    final uid = Constant.userModel?.id;
    if (uid != null && uid.trim().isNotEmpty) return uid.trim();
    return await LoginController.getFirebaseId();
  }

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
      final driverId = await _resolveDriverId();
      final response = await ApiService.getWalletTransactions(
        driverId: driverId,
      );
      if (response == null) return;

      // The API returns the complete list in a single response — no
      // server-side paging — so replace the whole list on every fetch.
      transactions.assignAll(response.data);

      // Wallet balance is derived from the full list (authoritative).
      totalWalletAmount.value = response.totalWalletAmount;
      userModel.update((u) => u?.walletAmount = response.totalWalletAmount);

      hasMore.value = false;
    } catch (e, st) {
      log('WalletController._fetchPage error: $e\n$st');
    }
  }

  Future<void> fetchIncentiveHistory({
    bool reset = true,
  }) async {
    isIncentiveLoading.value = true;
    try {
      // The Java API expects the numeric database driver id.
      final String? userId = Constant.userModel?.id;
      final int? driverId = int.tryParse(userId ?? '');

      // Never send driverId <= 0.
      if (driverId == null || driverId <= 0) {
        log("❌ INVALID DRIVER ID: $userId");
        return;
      }

      if (reset) {
        incentivePage = 0;
        incentives.clear();
        incentiveHasMore.value = true;
        totalIncentiveAmount.value = 0;
      }

      log("✅ DRIVER ID SENT TO API = $driverId");
      log("FILTER = ${incentiveFilter.value}");
      log("PAGE = $incentivePage");
      log("SIZE = 20");

      final response = await ApiService.getDriverIncentiveHistory(
        driverId: driverId,
        filter: incentiveFilter.value,
        page: incentivePage,
        size: 20,
      );

      if (response == null) return;

      incentives.addAll(response.content);

      totalIncentiveAmount.value = incentives.fold(
        0.0,
            (sum, item) => sum + (item.incentiveAmount ?? 0),
      );

      incentiveHasMore.value = !response.last;

      if (incentiveHasMore.value) {
        incentivePage++;
      }

      log("✅ INCENTIVES COUNT = ${incentives.length}");
      log("✅ TOTAL INCENTIVE = ${totalIncentiveAmount.value}");
      log("✅ HAS MORE = ${incentiveHasMore.value}");
    } catch (e, st) {
      log('fetchIncentiveHistory error: $e\n$st');
    } finally {
      isIncentiveLoading.value = false;
    }
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;

    final threshold = scrollController.position.maxScrollExtent - 200;
    if (scrollController.position.pixels < threshold) return;

    if (isIncentiveTab.value) {
      if (!isFetchingMoreIncentive.value && incentiveHasMore.value) {
        _loadMoreIncentives();
      }
    } else if (!isFetchingMore.value && hasMore.value) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    isFetchingMore.value = true;
    await _fetchPage();
    isFetchingMore.value = false;
  }

  Future<void> _loadMoreIncentives() async {
    isFetchingMoreIncentive.value = true;
    await fetchIncentiveHistory(reset: false);
    isFetchingMoreIncentive.value = false;
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