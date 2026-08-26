// File: wallet_card.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:jippydriver_driver/app/wallet_screen/screens/delivery_amount_wallet_screen/controller/delivery_amount_wallet_controller.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/themes/responsive.dart';
import 'package:jippydriver_driver/themes/round_button_fill.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';

class DeliveryWalletCard extends StatelessWidget {
  final DeliveryAmountWalletController controller;

  const DeliveryWalletCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final bool isDark =
    Provider.of<DarkThemeProvider>(context).getThem();

    final bool canWithdraw = !(Constant.isDriverVerification == false &&
        controller.userModel.value.isDocumentVerify == false);

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
              // ── Label ────────────────────────────────────────────────────
              Text(
                'My Wallet'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppThemeData.grey900,
                  fontSize: 16,
                  fontFamily: AppThemeData.regular,
                ),
              ),

              // ── Balance ──────────────────────────────────────────────────
              Obx(
                    () => Text(
                  Constant.amountShow(
                    //amount: controller.totalCodAmount.value.toString(),
                    amount: controller.totalEarningsAmount.value.toString(),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppThemeData.grey900,
                    fontSize: 40,
                    fontFamily: AppThemeData.bold,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Withdraw button ──────────────────────────────────────────
              // if (canWithdraw)
              //   Padding(
              //     padding: const EdgeInsets.symmetric(horizontal: 16),
              //     child: SizedBox(
              //       width: double.infinity,
              //       child: RoundedButtonFill(
              //         title: 'Withdraw'.tr,
              //         width: 24,
              //         height: 5.5,
              //         color: AppThemeData.grey50,
              //         textColor: AppThemeData.grey900,
              //         borderRadius: 200,
              //         onPress: () {
              //           final bool hasBank =
              //               Constant.userModel?.userBankDetails?.accountNumber
              //                   .isNotEmpty ==
              //                   true;
              //           final bool hasMethod =
              //               controller.withdrawMethodModel.value.id != null;
              //
              //           if (!hasBank && !hasMethod) {
              //             ShowToastDialog.showToast(
              //                 'Please enter payment method'.tr);
              //             return;
              //           }
              //           // TODO: open withdrawal bottom sheet
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
}