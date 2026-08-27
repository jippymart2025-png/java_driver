import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/controllers/login_controller.dart';
import 'package:jippydriver_driver/models/currency_model.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/utils/notification_service.dart';
import 'package:jippydriver_driver/services/http_client_service.dart';
import 'package:jippydriver_driver/services/api_cache_service.dart';
import 'package:get/get.dart';

class GlobalSettingController extends GetxController {
  @override
  void onInit() {
    notificationInit();
    getCurrentCurrency();
    super.onInit();
  }

  Future<void> getCurrentCurrency() async {
    try {
      final uri = Uri.parse('${Constant.baseUrl}settings/getActiveCurrency');
      // Use HttpClientService with caching - currency rarely changes (24 hours cache)
      final httpClient = HttpClientService();
      final response = await httpClient.get(
        uri,
        cacheStrategy: CacheStrategy.settings, // 24 hours cache
        useCache: true,
        timeout: const Duration(seconds: 5),
        enableRetry: false,
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          Constant.currencyModel = CurrencyModel.fromJson(responseData['data']);
        } else {
          // fallback currency
          Constant.currencyModel = CurrencyModel(
            id: "",
            code: "INR",
            decimalDigits: 2,
            enable: true,
            name: "Indian Rupee",
            symbol: "₹",
            symbolAtRight: false,
          );
        }
      } else {
        log("Failed to fetch currency: ${response.statusCode}");
        // fallback currency
        Constant.currencyModel = CurrencyModel(
          id: "",
          code: "INR",
          decimalDigits: 2,
          enable: true,
          name: "Indian Rupee",
          symbol: "₹",
          symbolAtRight: false,
        );
      }
    } catch (e) {
      log("Error in getCurrentCurrency: $e");
      // fallback currency
      Constant.currencyModel = CurrencyModel(
        id: "",
        code: "INR",
        decimalDigits: 2,
        enable: true,
        name: "Indian Rupee",
        symbol: "₹",
        symbolAtRight: false,
      );
    }
  }

  NotificationService notificationService = NotificationService();

  notificationInit() {
    notificationService.initInfo().then((value) async {
      try {
        String? userId = await LoginController.getFirebaseId();
        String? token = await NotificationService.getToken();
        log(":::::::TOKEN:::::: $token");
        UserModel? userModel = await FireStoreUtils.getUserProfile(userId);
        if (userModel != null) {
          userModel.fcmToken = token;
          await FireStoreUtils.updateUser(userModel);
        }
            } catch (e) {
        log("Error in notificationInit: $e");
      }
    }).catchError((error) {
      log("Error in notificationService.initInfo: $error");
    });
  }
}
