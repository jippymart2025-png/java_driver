import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/routes/transitions_type.dart';
import '../../../themes/app_them_data.dart';
import '../screens/phone_number_screen.dart';

class LoginWithPhoneButton extends StatelessWidget {
  const LoginWithPhoneButton({super.key});

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();

          Get.to(
                () => const PhoneNumberScreen(),
            transition: Transition.rightToLeftWithFade,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        },
        icon: Icon(
          Icons.phone_iphone_rounded,
          size: 20,
          color: Colors.white,
        ),
        label: Text(
          'Log in with Mobile Number'.tr,
          style: TextStyle(
            fontSize: 15,
            fontFamily: AppThemeData.bold,
            color: Colors.white,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppThemeData.driverApp300,
          side:  BorderSide(
            color: AppThemeData.driverApp300,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
