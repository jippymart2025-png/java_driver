import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:jippydriver_driver/app/wallet_screen/controller/wallet_controller.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/models/wallet_transaction_model.dart';
import 'package:jippydriver_driver/models/withdrawal_model.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/themes/responsive.dart';
import 'package:jippydriver_driver/themes/round_button_fill.dart';
import 'package:jippydriver_driver/themes/text_field_widget.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/controllers/login_controller.dart';
import 'package:jippydriver_driver/widget/my_separator.dart';

class WalletScreen extends StatelessWidget {
  final bool isAppBarShow;

  const WalletScreen({super.key, this.isAppBarShow = false});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DarkThemeProvider>(context);
    final bool isDark = theme.getThem();

    return GetX<WalletController>(
      init: WalletController(),
      builder: (controller) {
        if (controller.isLoading.value) {
          return Scaffold(
            backgroundColor:
            isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            appBar: _buildAppBar(isDark),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          appBar: isAppBarShow ? _buildAppBar(isDark) : null,
          body: RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              controller: controller.scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Wallet Balance Card ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: _WalletBalanceCard(
                    controller: controller,
                    isDark: isDark,
                  ),
                ),

                // ── Section Header ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Obx(
                        () => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => controller.isIncentiveTab.value = false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Transaction History'.tr,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.semiBold,
                                    fontSize: 17,
                                    color: !controller.isIncentiveTab.value
                                        ? AppThemeData.secondary300
                                        : (isDark
                                        ? AppThemeData.grey400
                                        : AppThemeData.grey500),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 2,
                                  width: 120,
                                  color: !controller.isIncentiveTab.value
                                      ? AppThemeData.secondary300
                                      : Colors.transparent,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 90),

                          GestureDetector(
                            onTap: () => controller.isIncentiveTab.value = true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Incentive History'.tr,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.semiBold,
                                    fontSize: 17,
                                    color: controller.isIncentiveTab.value
                                        ? AppThemeData.secondary300
                                        : (isDark
                                        ? AppThemeData.grey400
                                        : AppThemeData.grey500),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 2,
                                  width: 100,
                                  color: controller.isIncentiveTab.value
                                      ? AppThemeData.secondary300
                                      : Colors.transparent,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // SliverToBoxAdapter(
                //   child: Padding(
                //     padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                //     child: Text(
                //       'Transaction History'.tr,
                //       style: TextStyle(
                //         fontFamily: AppThemeData.semiBold,
                //         fontSize: 15,
                //         color: isDark
                //             ? AppThemeData.grey100
                //             : AppThemeData.grey800,
                //       ),
                //     ),
                //   ),
                // ),

            //====================Incentive Filter (All / Current Month)======================

                // ── Incentive Filter (All / Current Month) ─────────────────────
                SliverToBoxAdapter(
                  child: Obx(
                        () => controller.isIncentiveTab.value
                        ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text(
                              'All',
                              style: TextStyle(
                                color: controller.incentiveFilter.value == 'all'
                                    ? AppThemeData.grey900
                                    : AppThemeData.grey700,
                                fontFamily: AppThemeData.semiBold,
                              ),
                            ),
                            selected:
                            controller.incentiveFilter.value == 'all',
                            selectedColor: AppThemeData.secondary300.withOpacity(0.75),
                            backgroundColor: isDark
                                ? AppThemeData.grey800
                                : AppThemeData.grey100,
                            onSelected: (_) async {
                              controller.incentiveFilter.value = 'all';
                              await controller.fetchIncentiveHistory(
                                reset: true,
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          ChoiceChip(
                            label: Text(
                              'Current Month',
                              style: TextStyle(
                                color: controller.incentiveFilter.value == 'currentMonth'
                                    ? AppThemeData.grey900
                                    : AppThemeData.grey700,
                                fontFamily: AppThemeData.semiBold,
                              ),
                            ),
                            selected:
                            controller.incentiveFilter.value ==
                                'currentMonth',
                            selectedColor: AppThemeData.secondary300.withOpacity(0.75),
                            backgroundColor: isDark
                                ? AppThemeData.grey800
                                : AppThemeData.grey100,
                            onSelected: (_) async {
                              controller.incentiveFilter.value =
                              'currentMonth';
                              await controller.fetchIncentiveHistory(
                                reset: true,
                              );
                            },
                          ),
                        ],
                      ),
                    )
                        : const SizedBox.shrink(),
                  ),
                ),
            //
            //     SliverToBoxAdapter(
            //       child: Obx(
            //             () => controller.isIncentiveTab.value
            //             ? Padding(
            //           padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            //           child: DropdownButtonFormField<String>(
            //             value: controller.incentiveFilter.value,
            //             decoration: const InputDecoration(
            //               border: OutlineInputBorder(),
            //               isDense: true,
            //             ),
            //             items: const [
            //               DropdownMenuItem(
            //                 value: 'all',
            //                 child: Text('All'),
            //               ),
            //               DropdownMenuItem(
            //                 value: 'currentMonth',
            //                 child: Text('Current Month'),
            //               ),
            //             ],
            //             onChanged: (value) async {
            //               if (value == null) return;
            //
            //               controller.incentiveFilter.value = value;
            //
            //               await controller.fetchIncentiveHistory(
            //                 reset: true,
            //               );
            //             },
            //           ),
            //         )
            //             : const SizedBox.shrink(),
            //       ),
            //     ),
                // ── Transaction List ────────────────────────────────────────
                // ── Transaction / Incentive List ────────────────────────────
                if (!controller.isIncentiveTab.value)

                // TRANSACTION HISTORY
                  (controller.transactions.isEmpty && !controller.isLoading.value)
                      ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Constant.showEmptyView(
                        message: 'Transaction history not found'.tr,
                      ),
                    ),
                  )
                      : SliverPadding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverList.separated(
                      itemCount: controller.transactions.length,
                      itemBuilder: (_, index) => _TransactionTile(
                        model: controller.transactions[index],
                        isDark: isDark,
                      ),
                      separatorBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: MySeparator(
                          color: isDark
                              ? AppThemeData.grey700
                              : AppThemeData.grey200,
                        ),
                      ),
                    ),
                  )

                else

                // INCENTIVE HISTORY
                  (controller.incentives.isEmpty)
                      ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Constant.showEmptyView(
                        message: 'Incentive history not found'.tr,
                      ),
                    ),
                  )
                      : SliverPadding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverList.separated(
                      itemCount: controller.incentives.length,
                      itemBuilder: (_, index) {
                        final incentive = controller.incentives[index];

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${incentive.noOfOrders ?? 0} Orders',
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: AppThemeData.semiBold,
                              color: isDark
                                  ? AppThemeData.grey100
                                  : AppThemeData.grey800,
                            ),
                          ),
                          subtitle: Text(
                            incentive.date ?? '',
                          ),
                          trailing: Text(
                            Constant.amountShow(
                              amount: (incentive.incentiveAmount ?? 0)
                                  .toString(),
                            ),
                            style: const TextStyle(
                              color: AppThemeData.success400,
                              fontFamily: AppThemeData.semiBold,
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: MySeparator(
                          color: isDark
                              ? AppThemeData.grey700
                              : AppThemeData.grey200,
                        ),
                      ),
                    ),
                  ),
                  //   : SliverPadding(
                  // padding: const EdgeInsets.symmetric(
                  //     horizontal: 16, vertical: 8),

                  // sliver: SliverList.separated(
                  //   itemCount: controller.transactions.length,
                  //   itemBuilder: (_, index) => _TransactionTile(
                  //     model: controller.transactions[index],
                  //     isDark: isDark,
                  //   ),
                  //   separatorBuilder: (_, __) => Padding(
                  //     padding: const EdgeInsets.symmetric(vertical: 4),
                  //     child: MySeparator(
                  //       color: isDark
                  //           ? AppThemeData.grey700
                  //           : AppThemeData.grey200,
                  //     ),
                  //   ),
                  // ),
                //     SliverList.separated(
                //       itemCount: controller.transactions.length +
                //           (controller.isFetchingMore.value ? 1 : 0),
                //
                //       itemBuilder: (_, index) {
                //         if (index == controller.transactions.length) {
                //           return const Padding(
                //             padding: EdgeInsets.symmetric(vertical: 16),
                //             child: Center(child: CircularProgressIndicator()),
                //           );
                //         }
                //
                //         return _TransactionTile(
                //           model: controller.transactions[index],
                //           isDark: isDark,
                //         );
                //       },
                //
                //       separatorBuilder: (_, __) => Padding(
                //         padding: const EdgeInsets.symmetric(vertical: 4),
                //         child: MySeparator(
                //           color: isDark
                //               ? AppThemeData.grey700
                //               : AppThemeData.grey200,
                //         ),
                //       ),
                //     )
                // ),

                // ── Pagination Footer ───────────────────────────────────────

                SliverToBoxAdapter(
                  child: Obx(() {
                    if (controller.isFetchingMore.value) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (!controller.hasMore.value && controller.transactions.isNotEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'No more transactions'.tr,
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: AppThemeData.medium,
                              color: isDark
                                  ? AppThemeData.grey500
                                  : AppThemeData.grey400,
                            ),
                          ),
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  }),
                ),
                // SliverToBoxAdapter(
                //   child: Obx(() {
                //     if (controller.isFetchingMore.value) {
                //       return const Padding(
                //         padding: EdgeInsets.symmetric(vertical: 16),
                //         child: Center(child: CircularProgressIndicator()),
                //       );
                //     }
                //     if (!controller.hasMore.value &&
                //         controller.transactions.isNotEmpty) {
                //       return Padding(
                //         padding: const EdgeInsets.symmetric(vertical: 16),
                //         child: Center(
                //           child: Text(
                //             'No more transactions'.tr,
                //             style: TextStyle(
                //               fontSize: 13,
                //               fontFamily: AppThemeData.medium,
                //               color: isDark
                //                   ? AppThemeData.grey500
                //                   : AppThemeData.grey400,
                //             ),
                //           ),
                //         ),
                //       );
                //     }
                //     return const SizedBox.shrink();
                //   }),
                // ),

                // ── Bottom safe area ────────────────────────────────────────
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        );
      },
    );
  }

  AppBar? _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
      centerTitle: false,
      iconTheme: IconThemeData(
        color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
        size: 20,
      ),
      title: Text(
        'Wallet'.tr,
        style: TextStyle(
          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
          fontSize: 18,
          fontFamily: AppThemeData.medium,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wallet Balance Card
// ─────────────────────────────────────────────────────────────────────────────

class _WalletBalanceCard extends StatelessWidget {
  final WalletController controller;
  final bool isDark;

  const _WalletBalanceCard({
    required this.controller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOverdrawn = controller.totalWalletAmount.value < -1000;
    final bool canVerify = Constant.isDriverVerification == false &&
        controller.userModel.value.isDocumentVerify == false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          image: DecorationImage(
            image: AssetImage('assets/images/wallet.png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              // ── Label ──────────────────────────────────────────────────────
              // Text(
              //   'My Wallet'.tr,
              //   style: const TextStyle(
              //     color: AppThemeData.grey900,
              //     fontSize: 16,
              //     fontFamily: AppThemeData.regular,
              //   ),
              // ),
              Text(
                controller.isIncentiveTab.value
                    ? 'Total Incentives'.tr
                    : 'My Wallet'.tr,
                style: const TextStyle(
                  color: AppThemeData.grey900,
                  fontSize: 16,
                  fontFamily: AppThemeData.regular,
                ),
              ),

              // ── Balance ────────────────────────────────────────────────────
              // Text(
              //   Constant.amountShow(
              //     amount: controller.totalWalletAmount.value.toString(),
              //   ),
              Text(
                Constant.amountShow(
                  amount: controller.isIncentiveTab.value
                      ? controller.totalIncentiveAmount.value.toString()
                      : controller.totalWalletAmount.value.toString(),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppThemeData.grey900,
                  fontSize: 40,
                  fontFamily: AppThemeData.bold,
                ),
              ),

              // ── Overdrawn warning ──────────────────────────────────────────
              if (isOverdrawn) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red),
                  ),
                  child: const Text(
                    'Please Contact Your Fleet Manager',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                      fontFamily: AppThemeData.bold,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Withdraw Button ────────────────────────────────────────────
              // if (!canVerify)
              //   Padding(
              //     padding: const EdgeInsets.symmetric(horizontal: 16),
              //     child: SizedBox(
              //       width: double.infinity,
              //       child: RoundedButtonFill(
              //         title: 'TopUp'.tr,
              //         width: 24,
              //         height: 5.5,
              //         color: AppThemeData.grey50,
              //         textColor: AppThemeData.grey900,
              //         borderRadius: 200,
              //         onPress: () {
              //           if (controller.hasValidPaymentMethod) {
              //             _showWithdrawalSheet(context, controller);
              //           } else {
              //             ShowToastDialog.showToast(
              //               'Please enter payment method'.tr,
              //             );
              //           }
              //         },
              //       ),
              //     ),
              //   ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWithdrawalSheet(
      BuildContext context, WalletController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.8,
        child: _WithdrawalSheet(controller: controller),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transaction Tile  (const-constructable for ListView reuse)
// ─────────────────────────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  final WalletTransactionModel model;
  final bool isDark;

  const _TransactionTile({required this.model, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bool isCredit = model.isTopup == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // ── Icon ────────────────────────────────────────────────────────
          _iconBox(
            assetPath: isCredit
                ? 'assets/icons/ic_credit.svg'
                : 'assets/icons/ic_debit.svg',
            isDark: isDark,
          ),
          const SizedBox(width: 12),

          // ── Details ──────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        model.note.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontFamily: AppThemeData.semiBold,
                          color: isDark
                              ? AppThemeData.grey100
                              : AppThemeData.grey800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCredit
                          ? Constant.amountShow(
                          amount: model.amount.toString())
                          : '-${Constant.amountShow(amount: model.amount.toString())}',
                      style: TextStyle(
                        fontSize: 15,
                        fontFamily: AppThemeData.medium,
                        color: isCredit
                            ? AppThemeData.success400
                            : AppThemeData.danger300,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  model.date == null
                      ? '-'
                      // : Constant.timestampToDateTime(model.date!),
                     // : Constant.timestampToDateTime(model.date as Timestamp),
                     : Constant.timestampToDateTime(Timestamp.fromDate(model.date!)),
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: AppThemeData.medium,
                    color:
                    isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBox({required String assetPath, required bool isDark}) {
    return Container(
      width: 44,
      height: 44,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SvgPicture.asset(assetPath),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Withdrawal Bottom Sheet  (extracted to its own widget for clarity)
// ─────────────────────────────────────────────────────────────────────────────

class _WithdrawalSheet extends StatelessWidget {
  final WalletController controller;

  const _WithdrawalSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DarkThemeProvider>(context);
    final bool isDark = theme.getThem();

    return Obx(
          () => Scaffold(
        backgroundColor:
        isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Withdrawal'.tr,
                        style: TextStyle(
                          color: isDark
                              ? AppThemeData.grey100
                              : AppThemeData.grey800,
                          fontSize: 18,
                          fontFamily: AppThemeData.semiBold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: Get.back,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // ── Amount field ──────────────────────────────────────────
              TextFieldWidget(
                title: 'Withdrawal amount'.tr,
                controller: controller.amountController,
                hintText: 'Enter withdrawal amount'.tr,
                textInputType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                ],
                prefix: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Text(
                    Constant.currencyModel!.symbol.toString(),
                    style: TextStyle(
                      color:
                      isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                      fontFamily: AppThemeData.semiBold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              // ── Notes field ───────────────────────────────────────────
              TextFieldWidget(
                title: 'Notes'.tr,
                controller: controller.noteController,
                hintText: 'Add Notes'.tr,
              ),

              // ── Method selector (Bank only visible; others hidden) ─────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Select Withdraw Method'.tr,
                  style: TextStyle(
                    color:
                    isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                    fontSize: 16,
                    fontFamily: AppThemeData.medium,
                  ),
                ),
              ),

              _MethodOption(
                value: 0,
                groupValue: controller.selectedWithdrawMethod.value,
                label: 'Bank Transfer'.tr,
                iconPath: 'assets/icons/ic_building_four.svg',
                isSvg: true,
                isDark: isDark,
                onChanged: (v) => controller.selectedWithdrawMethod.value = v,
              ),
            ],
          ),
        ),

        bottomNavigationBar: Container(
          color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          padding:
          const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 32),
          child: RoundedButtonFill(
            title: 'Withdraw'.tr,
            height: 5.5,
            color: AppThemeData.primary300,
            textColor: AppThemeData.grey50,
            fontSizes: 16,
            onPress: () => _submit(context, controller),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(
      BuildContext context, WalletController controller) async {
    final rawAmount = controller.amountController.text.trim();

    if (rawAmount.isEmpty) {
      ShowToastDialog.showToast('Please enter amount'.tr);
      return;
    }

    final double? amount = double.tryParse(rawAmount);
    if (amount == null) {
      ShowToastDialog.showToast('Invalid amount'.tr);
      return;
    }

    if (amount < controller.minimumWithdrawal) {
      ShowToastDialog.showToast(
        '${'Withdraw amount must be greater or equal to'.tr} '
            '${Constant.amountShow(amount: Constant.minimumAmountToWithdrawal)}',
      );
      return;
    }

    final withdrawHistory = WithdrawalModel(
      amount: rawAmount,
      driverID: controller.userModel.value.id,
      paymentStatus: 'Pending',
      paidDate: Timestamp.now(),
      id: Constant.getUuid(),
      note: controller.noteController.text.trim(),
      withdrawMethod: controller.selectedMethodKey,
    );

    await FireStoreUtils.withdrawWalletAmount(withdrawHistory);

    final userId = await LoginController.getFirebaseId();
    await FireStoreUtils.updateUserWallet(
      amount: '-$rawAmount',
      userId: userId,
    );

    controller
      ..deductFromWallet(amount)
      ..amountController.clear()
      ..noteController.clear();

    Get.back();

    FireStoreUtils.sendPayoutMail(
      amount: rawAmount,
      payoutrequestid: withdrawHistory.id.toString(),
    );

    // Refresh transaction list in background
    controller.refresh();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment method radio row
// ─────────────────────────────────────────────────────────────────────────────

class _MethodOption extends StatelessWidget {
  final int value;
  final int groupValue;
  final String label;
  final String iconPath;
  final bool isSvg;
  final bool isDark;
  final ValueChanged<int> onChanged;

  const _MethodOption({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.iconPath,
    required this.isSvg,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            // Icon box
            Container(
              width: 50,
              height: 50,
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: isDark
                        ? AppThemeData.grey700
                        : AppThemeData.grey200,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: isSvg
                    ? SvgPicture.asset(iconPath)
                    : Image.asset(iconPath),
              ),
            ),
            const SizedBox(width: 12),

            // Label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color:
                  isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                  fontSize: 15,
                  fontFamily: AppThemeData.medium,
                ),
              ),
            ),

            // Radio
            Radio<int>(
              value: value,
              groupValue: groupValue,
              activeColor: AppThemeData.secondary300,
              onChanged: (v) => onChanged(v!),
            ),
          ],
        ),
      ),
    );
  }
}