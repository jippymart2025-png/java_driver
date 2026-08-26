// import 'package:jippydriver_driver/constant/constant.dart';
// import 'package:jippydriver_driver/models/withdrawal_model.dart';
// import 'package:jippydriver_driver/themes/app_them_data.dart' show AppThemeData;
// import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
// import 'package:jippydriver_driver/widget/my_separator.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/svg.dart';
// import 'package:get/get.dart';
//
// import '../../model/delivery_amount_model.dart' show DriverAmountWalletTransactionModel;
// import '../controller/delivery_amount_wallet_controller.dart' show DeliveryAmountWalletController;
//
// Widget deliveryWalletTable({required BuildContext context,required DarkThemeProvider themeChange,required DeliveryAmountWalletController controller}){
//   return  Expanded(
//     child: DefaultTabController(
//       length: 2,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           TabBar(
//             onTap: (value) {
//               controller.selectedTabIndex.value = value;
//             },
//             // tabAlignment: TabAlignment.start,
//             labelStyle: const TextStyle(
//                 fontFamily: AppThemeData.semiBold),
//             labelColor: themeChange.getThem()
//                 ? AppThemeData.secondary300
//                 : AppThemeData.secondary300,
//             unselectedLabelStyle: const TextStyle(
//                 fontFamily: AppThemeData.medium),
//             unselectedLabelColor: themeChange.getThem()
//                 ? AppThemeData.grey400
//                 : AppThemeData.grey500,
//             indicatorColor: AppThemeData.secondary300,
//             indicatorWeight: 1,
//             isScrollable: true,
//             dividerColor: Colors.transparent,
//             tabs: [
//               Tab(
//                 text: "Earnings History".tr,
//               ),
//               Tab(
//                 text: "Withdrawal History".tr,
//               ),
//             ],
//           ),
//           Expanded(
//             child: TabBarView(
//               children: [
//                 SafeArea(
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 16, vertical: 10),
//                     child: Column(
//                       crossAxisAlignment:
//                       CrossAxisAlignment.start,
//                       children: [
//                         SizedBox(
//                           width: 150,
//                           child: DropdownButtonFormField<
//                               String>(
//                               borderRadius:
//                               const BorderRadius.all(
//                                   Radius.circular(0)),
//                               hint: Text(
//                                 'Select zone'.tr,
//                                 style: TextStyle(
//                                   fontSize: 14,
//                                   color: themeChange.getThem()
//                                       ? AppThemeData.grey700
//                                       : AppThemeData.grey700,
//                                   fontFamily:
//                                   AppThemeData.regular,
//                                 ),
//                               ),
//                               decoration: InputDecoration(
//                                 errorStyle: const TextStyle(
//                                     color: Colors.red),
//                                 isDense: true,
//                                 filled: true,
//                                 fillColor:
//                                 themeChange.getThem()
//                                     ? AppThemeData.grey900
//                                     : AppThemeData.grey50,
//                                 disabledBorder:
//                                 UnderlineInputBorder(
//                                   borderRadius:
//                                   const BorderRadius.all(
//                                       Radius.circular(
//                                           400)),
//                                   borderSide: BorderSide(
//                                       color: themeChange
//                                           .getThem()
//                                           ? AppThemeData
//                                           .grey900
//                                           : AppThemeData
//                                           .grey50,
//                                       width: 1),
//                                 ),
//                                 focusedBorder:
//                                 OutlineInputBorder(
//                                   borderRadius:
//                                   const BorderRadius.all(
//                                       Radius.circular(
//                                           400)),
//                                   borderSide: BorderSide(
//                                       color: themeChange
//                                           .getThem()
//                                           ? AppThemeData
//                                           .secondary300
//                                           : AppThemeData
//                                           .secondary300,
//                                       width: 1),
//                                 ),
//                                 enabledBorder:
//                                 OutlineInputBorder(
//                                   borderRadius:
//                                   const BorderRadius.all(
//                                       Radius.circular(
//                                           400)),
//                                   borderSide: BorderSide(
//                                       color: themeChange
//                                           .getThem()
//                                           ? AppThemeData
//                                           .grey900
//                                           : AppThemeData
//                                           .grey50,
//                                       width: 1),
//                                 ),
//                                 errorBorder:
//                                 OutlineInputBorder(
//                                   borderRadius:
//                                   const BorderRadius.all(
//                                       Radius.circular(
//                                           400)),
//                                   borderSide: BorderSide(
//                                       color: themeChange
//                                           .getThem()
//                                           ? AppThemeData
//                                           .grey900
//                                           : AppThemeData
//                                           .grey50,
//                                       width: 1),
//                                 ),
//                                 border: OutlineInputBorder(
//                                   borderRadius:
//                                   const BorderRadius.all(
//                                       Radius.circular(
//                                           400)),
//                                   borderSide: BorderSide(
//                                       color: themeChange
//                                           .getThem()
//                                           ? AppThemeData
//                                           .grey900
//                                           : AppThemeData
//                                           .grey50,
//                                       width: 1),
//                                 ),
//                               ),
//                               value: controller
//                                   .selectedDropDownValue
//                                   .value,
//                               onChanged: (value) {
//                                 controller
//                                     .selectedDropDownValue
//                                     .value = value!;
//                                 controller.update();
//                               },
//                               style: TextStyle(
//                                   fontSize: 14,
//                                   color: themeChange.getThem()
//                                       ? AppThemeData.grey50
//                                       : AppThemeData.grey900,
//                                   fontFamily:
//                                   AppThemeData.medium),
//                               items: controller.dropdownValue
//                                   .map((item) {
//                                 return DropdownMenuItem<
//                                     String>(
//                                   value: item,
//                                   child:
//                                   Text(item.toString()),
//                                 );
//                               }).toList()),
//                         ),
//                         const SizedBox(
//                           height: 10,
//                         ),
//                         Expanded(
//                           child: Container(
//                             decoration: ShapeDecoration(
//                               color: themeChange.getThem()
//                                   ? AppThemeData.grey900
//                                   : AppThemeData.grey50,
//                               shape: RoundedRectangleBorder(
//                                 borderRadius:
//                                 BorderRadius.circular(12),
//                               ),
//                             ),
//                             child: Padding(
//                               padding:
//                               const EdgeInsets.all(8.0),
//                               child: transactionCardForOrder(
//                                 themeChange,
//                                 controller.filteredTransactions,
//                               ),
//                             ),
//                           ),
//                         )
//                       ],
//                     ),
//                   ),
//                 ),
//                 controller.withdrawalList.isEmpty
//                     ? Constant.showEmptyView(
//                     message:
//                     "Withdrawal history not found"
//                         .tr)
//                     : Padding(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 16, vertical: 10),
//                   child: Container(
//                     decoration: ShapeDecoration(
//                       color: themeChange.getThem()
//                           ? AppThemeData.grey900
//                           : AppThemeData.grey50,
//                       shape: RoundedRectangleBorder(
//                         borderRadius:
//                         BorderRadius.circular(12),
//                       ),
//                     ),
//                     child: Padding(
//                       padding:
//                       const EdgeInsets.all(8.0),
//                       child: ListView.separated(
//                         padding: EdgeInsets.zero,
//                         shrinkWrap: true,
//                         itemCount: controller
//                             .withdrawalList.length,
//                         itemBuilder:
//                             (context, index) {
//                           WithdrawalModel
//                           walletTractionModel =
//                           controller
//                               .withdrawalList[
//                           index];
//                           return transactionCardWithdrawal(
//                               controller,
//                               themeChange,
//                               walletTractionModel);
//                         },
//                         separatorBuilder:
//                             (BuildContext context,
//                             int index) {
//                           return Padding(
//                             padding: const EdgeInsets
//                                 .symmetric(
//                                 vertical: 5),
//                             child: MySeparator(
//                                 color: themeChange
//                                     .getThem()
//                                     ? AppThemeData
//                                     .grey700
//                                     : AppThemeData
//                                     .grey200),
//                           );
//                         },
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           )
//         ],
//       ),
//     ),
//   );
// }
//
// transactionCardWithdrawal(DeliveryAmountWalletController controller, themeChange,
//     WithdrawalModel transactionModel) {
//   return InkWell(
//     onTap: () async {},
//     child: Padding(
//       padding: const EdgeInsets.symmetric(vertical: 5),
//       child: Row(
//         children: [
//           Container(
//             decoration: ShapeDecoration(
//               shape: RoundedRectangleBorder(
//                 side: BorderSide(
//                     width: 1,
//                     color: themeChange.getThem()
//                         ? AppThemeData.grey800
//                         : AppThemeData.grey100),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: SvgPicture.asset(
//                 "assets/icons/ic_debit.svg",
//                 height: 16,
//                 width: 16,
//               ),
//             ),
//           ),
//           const SizedBox(
//             width: 10,
//           ),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             transactionModel.note.toString(),
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontFamily: AppThemeData.semiBold,
//                               fontWeight: FontWeight.w600,
//                               color: themeChange.getThem()
//                                   ? AppThemeData.grey100
//                                   : AppThemeData.grey800,
//                             ),
//                           ),
//                           Text(
//                             "(${transactionModel.withdrawMethod!.capitalizeString()})",
//                             style: TextStyle(
//                               fontSize: 14,
//                               fontFamily: AppThemeData.medium,
//                               fontWeight: FontWeight.w600,
//                               color: themeChange.getThem()
//                                   ? AppThemeData.grey100
//                                   : AppThemeData.grey800,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     Text(
//                       "-${Constant.amountShow(amount: transactionModel.amount.toString())}",
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontFamily: AppThemeData.medium,
//                         color: AppThemeData.danger300,
//                       ),
//                     )
//                   ],
//                 ),
//                 const SizedBox(
//                   height: 2,
//                 ),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         transactionModel.paymentStatus.toString(),
//                         style: TextStyle(
//                           fontSize: 14,
//                           fontFamily: AppThemeData.semiBold,
//                           fontWeight: FontWeight.w600,
//                           color: transactionModel.paymentStatus == "Success"
//                               ? AppThemeData.success400
//                               : transactionModel.paymentStatus == "Pending"
//                               ? AppThemeData.primary300
//                               : AppThemeData.danger300,
//                         ),
//                       ),
//                     ),
//                     Text(
//                       Constant.timestampToDateTime(
//                           transactionModel.paidDate!),
//                       style: TextStyle(
//                           fontSize: 12,
//                           fontFamily: AppThemeData.medium,
//                           fontWeight: FontWeight.w500,
//                           color: themeChange.getThem()
//                               ? AppThemeData.grey200
//                               : AppThemeData.grey700),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }
//
// transactionCardForOrder(themeChange, List<DriverAmountWalletTransactionModel> list) {
//   return list.isEmpty
//       ? Constant.showEmptyView(message: "Transaction history not found".tr)
//       : Column(
//     children: [
//       Expanded(
//         child: ListView.separated(
//     padding: EdgeInsets.zero,
//     shrinkWrap: true,
//     itemCount: list.length,
//     itemBuilder: (context, index) {
//       DriverAmountWalletTransactionModel walletTractionModel = list[index];
//
//
//
//       return Padding(
//         padding: const EdgeInsets.symmetric(vertical: 5),
//         child: Row(
//           children: [
//             Container(
//               decoration: ShapeDecoration(
//                 shape: RoundedRectangleBorder(
//                   side: BorderSide(
//                       width: 1,
//                       color: themeChange.getThem()
//                           ? AppThemeData.grey800
//                           : AppThemeData.grey100),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: SvgPicture.asset(
//                   walletTractionModel.isCredit
//                       ? "assets/icons/ic_credit.svg"
//                       : "assets/icons/ic_debit.svg",
//                   height: 16,
//                   width: 16,
//                 ),
//               ),
//             ),
//             const SizedBox(
//               width: 10,
//             ),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   (walletTractionModel.bonus ?? false) ? Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                              "Bonus Amount".tr,
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontFamily: AppThemeData.semiBold,
//                             fontWeight: FontWeight.w600,
//                             color: themeChange.getThem()
//                                 ? AppThemeData.primary400
//                                 : AppThemeData.primary400,
//                           ),
//                         ),
//                       ),
//                       Text(walletTractionModel.bonusAmount.toString(),
//                         style: const TextStyle(
//                           fontSize: 16,
//                           fontFamily: AppThemeData.medium,
//                           color: AppThemeData.success400,
//                         ),
//                       )
//                     ],
//                   ) : const SizedBox(),
//                   const SizedBox(
//                     height: 2,
//                   ),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           "Delivery Amount".tr,
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontFamily: AppThemeData.semiBold,
//                             fontWeight: FontWeight.w600,
//                             color: themeChange.getThem()
//                                 ? AppThemeData.grey100
//                                 : AppThemeData.grey800,
//                           ),
//                         ),
//                       ),
//                       Text(
//                         "${walletTractionModel.isCredit ? "+" : "-"}${Constant.amountShow(amount: walletTractionModel.displayAmount.toString())}",
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontFamily: AppThemeData.medium,
//                           color: walletTractionModel.isCredit
//                               ? AppThemeData.success400
//                               : AppThemeData.danger300,
//                         ),
//                       )
//                     ],
//                   ),
//                   const SizedBox(
//                     height: 2,
//                   ),
//                   Text(
//                     walletTractionModel.date == null
//                         ? "-"
//                         : Constant.timestampToDateTime(walletTractionModel.date!),
//                     style: TextStyle(
//                         fontSize: 12,
//                         fontFamily: AppThemeData.medium,
//                         fontWeight: FontWeight.w500,
//                         color: themeChange.getThem()
//                             ? AppThemeData.grey200
//                             : AppThemeData.grey700),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       );
//     },
//     separatorBuilder: (BuildContext context, int index) {
//       return Padding(
//         padding: const EdgeInsets.symmetric(vertical: 5),
//         child: MySeparator(
//             color: themeChange.getThem()
//                 ? AppThemeData.grey700
//                 : AppThemeData.grey200),
//       );
//     },
//   ),
//       ),
//       if (Get.isRegistered<DeliveryAmountWalletController>())
//         GetX<DeliveryAmountWalletController>(
//           builder: (controller) {
//             if (!controller.hasMore.value) return const SizedBox();
//             return Padding(
//               padding: const EdgeInsets.only(top: 8),
//               child: TextButton(
//                 onPressed: controller.isLoadingMore.value
//                     ? null
//                     : controller.loadMoreCodTransactions,
//                 child: controller.isLoadingMore.value
//                     ? const SizedBox(
//                         width: 16,
//                         height: 16,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       )
//                     : Text("Load more".tr),
//               ),
//             );
//           },
//         ),
//     ],
//   );
// }
//
// transactionCard(DeliveryAmountWalletController controller, themeChange,
//     DriverAmountWalletTransactionModel transactionModel) {
//   return InkWell(
//     onTap: () async {},
//     child: Padding(
//       padding: const EdgeInsets.symmetric(vertical: 5),
//       child: Row(
//         children: [
//           Container(
//             decoration: ShapeDecoration(
//               shape: RoundedRectangleBorder(
//                 side: BorderSide(
//                     width: 1,
//                     color: themeChange.getThem()
//                         ? AppThemeData.grey800
//                         : AppThemeData.grey100),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: transactionModel.bonus == false
//                   ? SvgPicture.asset(
//                 "assets/icons/ic_debit.svg",
//                 height: 16,
//                 width: 16,
//               )
//                   : SvgPicture.asset(
//                 "assets/icons/ic_credit.svg",
//                 height: 16,
//                 width: 16,
//               ),
//             ),
//           ),
//           const SizedBox(
//             width: 10,
//           ),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         transactionModel.type.toString(),
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontFamily: AppThemeData.semiBold,
//                           fontWeight: FontWeight.w600,
//                           color: themeChange.getThem()
//                               ? AppThemeData.grey100
//                               : AppThemeData.grey800,
//                         ),
//                       ),
//                     ),
//                     Text(
//                       transactionModel.bonus == false
//                           ? "-${Constant.amountShow(amount: transactionModel.totalEarnings.toString())}"
//                           : Constant.amountShow(
//                           amount: transactionModel.totalEarnings.toString()),
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontFamily: AppThemeData.medium,
//                         color: transactionModel.bonus == true
//                             ? AppThemeData.success400
//                             : AppThemeData.danger300,
//                       ),
//                     )
//                   ],
//                 ),
//                 const SizedBox(
//                   height: 2,
//                 ),
//                 Text(
//                   Constant.timestampToDateTime(transactionModel.date!),
//                   style: TextStyle(
//                       fontSize: 12,
//                       fontFamily: AppThemeData.medium,
//                       fontWeight: FontWeight.w500,
//                       color: themeChange.getThem()
//                           ? AppThemeData.grey200
//                           : AppThemeData.grey700),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }



// ignore_for_file: file_names
// File: transcation_delivery_table.dart
//
// All former free-function widgets have been converted to StatelessWidget
// subclasses so Flutter's element tree can diff and skip rebuilding
// siblings correctly.  The public entry-point widget (DeliveryWalletTable)
// keeps a compatible surface so call-sites need minimal changes:
//
//   OLD: deliveryWalletTable(context: ctx, themeChange: tc, controller: c)
//   NEW: DeliveryWalletTable(controller: c)  — theme resolved internally

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:jippydriver_driver/app/wallet_screen/screens/delivery_amount_wallet_screen/controller/delivery_amount_wallet_controller.dart';
import 'package:jippydriver_driver/app/wallet_screen/screens/model/delivery_amount_model.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/models/withdrawal_model.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:jippydriver_driver/widget/my_separator.dart';
import 'package:provider/provider.dart';
import 'package:jippydriver_driver/models/driver_earning_history_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point
// ─────────────────────────────────────────────────────────────────────────────

class DeliveryWalletTable extends StatelessWidget {
  final DeliveryAmountWalletController controller;

  const DeliveryWalletTable({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final bool isDark =
    Provider.of<DarkThemeProvider>(context).getThem();

    return Expanded(
      child: DefaultTabController(
        length: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tab Bar ────────────────────────────────────────────────────
            _DeliveryTabBar(isDark: isDark, controller: controller),

            // ── Tab Views ──────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                children: [
                  _EarningsTab(controller: controller, isDark: isDark),
                  // _WithdrawalsTab(controller: controller, isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab Bar
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryTabBar extends StatelessWidget {
  final bool isDark;
  final DeliveryAmountWalletController controller;

  const _DeliveryTabBar({required this.isDark, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TabBar(
      onTap: (i) => controller.selectedTabIndex.value = i,
      labelStyle:
      const TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 14),
      labelColor: AppThemeData.secondary300,
      unselectedLabelStyle:
      const TextStyle(fontFamily: AppThemeData.medium, fontSize: 14),
      unselectedLabelColor:
      isDark ? AppThemeData.grey400 : AppThemeData.grey500,
      indicatorColor: AppThemeData.secondary300,
      indicatorWeight: 2,
      // isScrollable removed — caused tab content overflow on small screens
      dividerColor: Colors.transparent,
      tabs: [
        Tab(text: 'Earnings History'.tr),
        // Tab(text: 'Withdrawal History'.tr),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Earnings Tab — filter chips + infinite-scroll SliverList
// ─────────────────────────────────────────────────────────────────────────────

class _EarningsTab extends StatelessWidget {
  final DeliveryAmountWalletController controller;
  final bool isDark;

  const _EarningsTab({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      //final list = controller.filteredTransactions;
      final list = controller.earningHistory;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filter chips (replaces DropdownButtonFormField) ───────────────
          _FilterRow(controller: controller, isDark: isDark),

          // ── List (scrollable — hosts pull-to-refresh) ───────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: list.isEmpty
                  ? CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Constant.showEmptyView(
                              message: 'Transaction history not found'.tr,
                            ),
                          ),
                        ),
                      ],
                    )
                  : CustomScrollView(
                      controller: controller.earningsScrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          sliver: SliverList.separated(
                            itemCount: list.length,
                            itemBuilder: (_, i) => EarningsTile(
                              model: list[i],
                              isDark: isDark,
                            ),
                            separatorBuilder: (_, __) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: MySeparator(
                                color: isDark
                                    ? AppThemeData.grey700
                                    : AppThemeData.grey200,
                              ),
                            ),
                          ),
                        ),

                        // ── Pagination footer ─────────────────────────────
                        SliverToBoxAdapter(
                          child: Obx(() {
                            if (controller.isFetchingMore.value) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            }
                            if (!controller.hasMore.value &&
                                list.isNotEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
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

                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
            ),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Withdrawals Tab
// ─────────────────────────────────────────────────────────────────────────────

class _WithdrawalsTab extends StatelessWidget {
  final DeliveryAmountWalletController controller;
  final bool isDark;

  const _WithdrawalsTab({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = controller.withdrawalList;

      if (list.isEmpty) {
        return Center(
          child: Constant.showEmptyView(
            message: 'Withdrawal history not found'.tr,
          ),
        );
      }

      return CustomScrollView(
        controller: controller.withdrawalScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverList.separated(
              itemCount: list.length,
              itemBuilder: (_, i) =>
                  WithdrawalTile(model: list[i], isDark: isDark),
              separatorBuilder: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: MySeparator(
                  color:
                  isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chip row — replaces DropdownButtonFormField
// ─────────────────────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final DeliveryAmountWalletController controller;
  final bool isDark;

  const _FilterRow({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(
          () => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: controller.filterOptions.map((option) {
              final bool selected =
                  controller.selectedFilter.value == option;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    option.tr,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: AppThemeData.medium,
                      color: selected
                          ? AppThemeData.grey50
                          : (isDark
                          ? AppThemeData.grey300
                          : AppThemeData.grey700),
                    ),
                  ),
                  selected: selected,
                  selectedColor: AppThemeData.secondary300,
                  backgroundColor: isDark
                      ? AppThemeData.grey800
                      : AppThemeData.grey100,
                  side: BorderSide.none,
                  onSelected: (_) =>
                  controller.selectedFilter.value = option,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Earnings Tile  (public so DeliveryAmountWalletScreen can reuse it)
// ─────────────────────────────────────────────────────────────────────────────

class EarningsTile extends StatelessWidget {
  //final DriverAmountWalletTransactionModel model;
  final DriverEarningHistoryModel model;
  final bool isDark;

  const EarningsTile({super.key, required this.model, required this.isDark});

  @override
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(
            assetPath: 'assets/icons/ic_credit.svg',
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        model.outletName ?? 'Restaurant',
                        maxLines: 2,
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
                    Flexible(
                      child: Text(
                        '+${Constant.amountShow(
                          amount: (model.totalDeliveryFee ?? 0).toString(),
                        )}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 15,
                          fontFamily: AppThemeData.medium,
                          color: AppThemeData.success400,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  model.createdAt ?? '-',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: AppThemeData.medium,
                    color: isDark
                        ? AppThemeData.grey400
                        : AppThemeData.grey500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // Widget build(BuildContext context) {
  //   // final bool isBonus = model.bonus == true;
  //   // final bool isCredit = model.isCredit;
  //
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 6),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         // ── Icon ──────────────────────────────────────────────────────────
  //         _IconBox(
  //           assetPath: isCredit
  //               ? 'assets/icons/ic_credit.svg'
  //               : 'assets/icons/ic_debit.svg',
  //           isDark: isDark,
  //         ),
  //         const SizedBox(width: 12),
  //
  //         // ── Content ───────────────────────────────────────────────────────
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
                // Bonus row — only rendered when present
                // if (isBonus) ...[
                //   Row(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Expanded(
                //         child: Text(
                //           'Bonus Amount'.tr,
                //           maxLines: 2,
                //           overflow: TextOverflow.ellipsis,
                //           style: const TextStyle(
                //             fontSize: 14,
                //             fontFamily: AppThemeData.semiBold,
                //             color: AppThemeData.primary400,
                //           ),
                //         ),
                //       ),
                //       Flexible(
                //         child: Text(
                //           model.bonusAmount?.toString() ?? '0',
                //           maxLines: 1,
                //           overflow: TextOverflow.ellipsis,
                //           textAlign: TextAlign.end,
                //           style: const TextStyle(
                //             fontSize: 14,
                //             fontFamily: AppThemeData.medium,
                //             color: AppThemeData.success400,
                //           ),
                //         ),
                //       ),
                //     ],
                //   ),
                //   const SizedBox(height: 2),
                // ],

                // Delivery amount row
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceBetween, // ✅ BEST
                //   crossAxisAlignment: CrossAxisAlignment.start,
                //   children: [
                //     Expanded(
                //       child: Text(
                //         model.bonus != null && model.displayAmount > 0
                //             ? 'Delivery Amount (+${Constant.amountShow(amount: model.bonus.toString())} Bonus)'.tr
                //             : 'Delivery Amount'.tr,
                //         maxLines: 3,
                //         overflow: TextOverflow.ellipsis,
                //         style: TextStyle(
                //           fontSize: 15,
                //           fontFamily: AppThemeData.semiBold,
                //           color: isDark
                //               ? AppThemeData.grey100
                //               : AppThemeData.grey800,
                //         ),
                //       ),
                //     ),
                //     Flexible(
                //       child: Text(
                //         '${isCredit ? '+' : '-'}${Constant.amountShow(amount: model.displayAmount.toString())}',
                //         maxLines: 1,
                //         overflow: TextOverflow.ellipsis,
                //         textAlign: TextAlign.end,
                //         style: TextStyle(
                //           fontSize: 15,
                //           fontFamily: AppThemeData.medium,
                //           color: isCredit
                //               ? AppThemeData.success400
                //               : AppThemeData.danger300,
                //         ),
                //       ),
                //     ),
                //   ],
                // ),
                // const SizedBox(height: 2),

  //
  //       Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Expanded(
  //             child: Text(
  //               model.outletName ?? 'Restaurant',
  //               maxLines: 2,
  //               overflow: TextOverflow.ellipsis,
  //               style: TextStyle(
  //                 fontSize: 15,
  //                 fontFamily: AppThemeData.semiBold,
  //                 color: isDark
  //                     ? AppThemeData.grey100
  //                     : AppThemeData.grey800,
  //               ),
  //             ),
  //           ),
  //           Flexible(
  //             child: Text(
  //               '+${Constant.amountShow(amount: (model.totalDeliveryFee ?? 0).toString())}',
  //               maxLines: 1,
  //               overflow: TextOverflow.ellipsis,
  //               textAlign: TextAlign.end,
  //               style: const TextStyle(
  //                 fontSize: 15,
  //                 fontFamily: AppThemeData.medium,
  //                 color: AppThemeData.success400,
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //               // Date
  //               Text(
  //                 // model.date == null
  //                 //     ? '-'
  //                 //     : Constant.timestampToDateTime(model.date!),
  //                 model.createdAt ?? '-'
  //                 style: TextStyle(
  //                   fontSize: 12,
  //                   fontFamily: AppThemeData.medium,
  //                   color:
  //                   isDark ? AppThemeData.grey400 : AppThemeData.grey500,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}

// ─────────────────────────────────────────────────────────────────────────────
// Withdrawal Tile  (public so DeliveryAmountWalletScreen can reuse it)
// ─────────────────────────────────────────────────────────────────────────────

class WithdrawalTile extends StatelessWidget {
  final WithdrawalModel model;
  final bool isDark;

  const WithdrawalTile({super.key, required this.model, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final Color statusColor = model.paymentStatus == 'Success'
        ? AppThemeData.success400
        : model.paymentStatus == 'Pending'
        ? AppThemeData.primary300
        : AppThemeData.danger300;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _IconBox(isDark: isDark, assetPath: 'assets/icons/ic_debit.svg'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
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
                          Text(
                            '(${model.withdrawMethod?.capitalizeString() ?? '-'})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: AppThemeData.medium,
                              color: isDark
                                  ? AppThemeData.grey300
                                  : AppThemeData.grey600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '-${Constant.amountShow(amount: model.amount.toString())}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 15,
                          fontFamily: AppThemeData.medium,
                          color: AppThemeData.danger300,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        model.paymentStatus.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: AppThemeData.semiBold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        model.paidDate != null
                            ? Constant.timestampToDateTime(model.paidDate!)
                            : '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: AppThemeData.medium,
                          color: isDark
                              ? AppThemeData.grey400
                              : AppThemeData.grey500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared icon box
// ─────────────────────────────────────────────────────────────────────────────

class _IconBox extends StatelessWidget {
  final String assetPath;
  final bool isDark;

  const _IconBox({required this.assetPath, required this.isDark});

  @override
  Widget build(BuildContext context) {
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