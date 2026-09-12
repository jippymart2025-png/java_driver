import 'dart:async';
import 'dart:developer';

import 'package:jippydriver_driver/app/auth_screen/screens/login_screen.dart';
import 'package:jippydriver_driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:jippydriver_driver/app/on_boarding_screen.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/app/auth_screen/controller/login_controller.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/utils/notification_service.dart';
import 'package:jippydriver_driver/utils/preferences.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:get/get.dart';

class SplashController extends GetxController {
  final loginController = Get.put(LoginController());
  @override
  void onInit() {
    AppLogger.log('SplashController onInit() called', tag: 'Controller');
    Timer(const Duration(seconds: 3), () => loginController.redirectScreen());
    super.onInit();
  }
  @override
  void onClose() {
    AppLogger.log('SplashController onClose() called', tag: 'Controller');
    super.onClose();
  }
}
