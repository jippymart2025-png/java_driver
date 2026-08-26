import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jippydriver_driver/app/wallet_screen/screens/model/delivery_amount_model.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/controllers/login_controller.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/models/withdraw_method_model.dart';
import 'package:jippydriver_driver/models/withdrawal_model.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/models/driver_earning_history_model.dart';

/// How long cached data is considered fresh before a background re-fetch
/// is triggered on next view.
const Duration _kCacheTtl = Duration(minutes: 5);

class DeliveryAmountWalletController extends GetxController {
  // ─── Loading flags ──────────────────────────────────────────────────────────
  final RxBool isLoading = true.obs;
  final RxBool isFetchingMore = false.obs;

  // ─── Pagination ─────────────────────────────────────────────────────────────
  final RxBool hasMore = false.obs;
  int _currentPage = 1;
  static const int _perPage = 20;

  // ─── UI state ───────────────────────────────────────────────────────────────
  final RxInt selectedTabIndex = 0.obs;
  final RxList<String> filterOptions = ['All'].obs;
  final RxString selectedFilter = 'All'.obs;

  // ─── Data ───────────────────────────────────────────────────────────────────
  final RxDouble totalCodAmount = 0.0.obs;
  final Rx<UserModel> userModel = UserModel().obs;
  final Rx<WithdrawMethodModel> withdrawMethodModel = WithdrawMethodModel().obs;
  final RxList<DriverAmountWalletTransactionModel> transactions =
      <DriverAmountWalletTransactionModel>[].obs;
  final RxList<DriverEarningHistoryModel> earningHistory =
      <DriverEarningHistoryModel>[].obs;
  final RxList<WithdrawalModel> withdrawalList = <WithdrawalModel>[].obs;

  // ─── Scroll controller (owned here, passed to view) ─────────────────────────
  final ScrollController earningsScrollController = ScrollController();
  final ScrollController withdrawalScrollController = ScrollController();
  final RxDouble totalEarningsAmount = 0.0.obs;

  // ─── Cache metadata ─────────────────────────────────────────────────────────
  DateTime? _lastFetchedAt;

  // ─── Computed ───────────────────────────────────────────────────────────────
  List<DriverAmountWalletTransactionModel> get filteredTransactions {
    switch (selectedFilter.value) {
      case 'Credit':
        return transactions.where((e) => e.isCredit).toList();
      case 'Debit':
        return transactions.where((e) => e.isDebit).toList();
      default:
        return transactions;
    }
  }

  bool get _isCacheValid =>
      _lastFetchedAt != null &&
          DateTime.now().difference(_lastFetchedAt!) < _kCacheTtl;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    earningsScrollController.addListener(_onEarningsScroll);
    _initialLoad();
  }

  @override
  void onClose() {
    earningsScrollController
      ..removeListener(_onEarningsScroll)
      ..dispose();
    withdrawalScrollController.dispose();
    super.onClose();
  }

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Pull-to-refresh / explicit reload — no full-screen loader.
  Future<void> refresh() async {
    _lastFetchedAt = null;
    try {
      await _fetchAll(forceRefresh: true);
    } catch (e, st) {
      log('DeliveryAmountWalletController.refresh error: $e\n$st');
    }
  }

  // ─── Private helpers ────────────────────────────────────────────────────────

  // Future<void> _fetchAll({required bool forceRefresh}) async {
  //   await Future.wait([
  //     _fetchTransactions(reset: true, force: forceRefresh),
  //     // _fetchWithdrawals(force: forceRefresh),
  //     _loadProfileAndPaymentMethod(),
  //   ]);
  //   _lastFetchedAt = DateTime.now();
  // }
  Future<void> _fetchAll({required bool forceRefresh}) async {
    await Future.wait([
      _fetchTransactions(reset: true, force: forceRefresh), // wallet balance
      _fetchEarningHistory(), // history list
      _loadProfileAndPaymentMethod(),
    ]);
    _lastFetchedAt = DateTime.now();
  }



  Future<void> _initialLoad({bool forceRefresh = false}) async {
    isLoading.value = true;
    try {
      await _fetchAll(forceRefresh: forceRefresh);
    } catch (e, st) {
      log('DeliveryAmountWalletController._initialLoad error: $e\n$st');
    } finally {
      isLoading.value = false;
    }
  }

  void _onEarningsScroll() {
    final pos = earningsScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300 &&
        !isFetchingMore.value &&
        hasMore.value) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (isFetchingMore.value || !hasMore.value) return;
    isFetchingMore.value = true;
    await _fetchTransactions(reset: false, page: _currentPage + 1);
    isFetchingMore.value = false;
  }

  Future<void> _fetchTransactions({
    required bool reset,
    int page = 1,
    bool force = false,
  }) async {
    // Use cache if valid and not a forced reset.
    if (!reset && !force && _isCacheValid && transactions.isNotEmpty) return;

    if (reset) {
      _currentPage = 1;
      hasMore.value = false;
    }

    try {
      final response = await FireStoreUtils.getDriverAmountWalletTransactionsPage(
        page: page,
        perPage: _perPage,
      );
      if (response == null) return;

      if (reset) {
        transactions.assignAll(response.data);
      } else {
        transactions.addAll(response.data);
      }

      totalCodAmount.value = response.summary.totalCodAmount;
      _currentPage = response.pagination.currentPage;
      hasMore.value = response.pagination.hasMore;
    } catch (e, st) {
      log('_fetchTransactions error: $e\n$st');
    }
  }

  // Future<void> _fetchEarningHistory() async {
  //   try {
  //     final result =
  //     await FireStoreUtils.fetchOrderEarningsHistory();
  //
  //     earningHistory.assignAll(result);
  //   } catch (e, st) {
  //     log('_fetchEarningHistory error: $e\n$st');
  //   }
  // }

  Future<void> _fetchEarningHistory() async {
    try {
      final result =
      await FireStoreUtils.fetchOrderEarningsHistory();

      final deliveredOrders = result
          .where((e) => e.orderStatus == "DELIVERED")
          .toList();

      earningHistory.assignAll(deliveredOrders);

      totalEarningsAmount.value = deliveredOrders.fold(
        0.0,
            (sum, item) => sum + (item.totalDeliveryFee ?? 0),
      );
    } catch (e, st) {
      log('_fetchEarningHistory error: $e\n$st');
    }
  }
  // Future<void> _fetchWithdrawals({bool force = false}) async {
  //   if (!force && _isCacheValid && withdrawalList.isNotEmpty) return;
  //   try {
  //     final result = await FireStoreUtils.getWithdrawHistory();
  //     withdrawalList.assignAll(result ?? []);
  //   } catch (e, st) {
  //     log('_fetchWithdrawals error: $e\n$st');
  //   }
  // }

  Future<void> _loadProfileAndPaymentMethod() async {
    try {
      final firebaseId = await LoginController.getFirebaseId();
      final profile = await FireStoreUtils.getUserProfile(firebaseId);
      if (profile != null) {
        userModel.value = profile;
        Constant.userModel = profile;
      }
      final paymentData = await FireStoreUtils.getPaymentSettingsData();
      if (paymentData?['withdrawMethod'] != null) {
        withdrawMethodModel.value =
            WithdrawMethodModel.fromJson(paymentData!['withdrawMethod']);
      }
    } catch (e, st) {
      log('_loadProfileAndPaymentMethod error: $e\n$st');
    }
  }
}