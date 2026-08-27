import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/services/http_client_service.dart';
import 'package:jippydriver_driver/services/api_cache_service.dart';
import 'package:jippydriver_driver/app/chat_screens/ChatVideoContainer.dart';
import 'package:jippydriver_driver/app/wallet_screen/screens/model/delivery_amount_model.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/controllers/login_controller.dart';
import 'package:jippydriver_driver/models/conversation_model.dart';
import 'package:jippydriver_driver/models/document_model.dart';
import 'package:jippydriver_driver/models/driver_document_model.dart';
import 'package:jippydriver_driver/models/email_template_model.dart';
import 'package:jippydriver_driver/models/inbox_model.dart';
import 'package:jippydriver_driver/models/mail_setting.dart';
import 'package:jippydriver_driver/models/notification_model.dart';
import 'package:jippydriver_driver/models/on_boarding_model.dart';
import 'package:jippydriver_driver/models/order_model.dart';
import 'package:jippydriver_driver/models/payment_model/cod_setting_model.dart';
import 'package:jippydriver_driver/models/payment_model/flutter_wave_model.dart';
import 'package:jippydriver_driver/models/payment_model/mercado_pago_model.dart';
import 'package:jippydriver_driver/models/payment_model/mid_trans.dart';
import 'package:jippydriver_driver/models/payment_model/orange_money.dart';
import 'package:jippydriver_driver/models/payment_model/pay_fast_model.dart';
import 'package:jippydriver_driver/models/payment_model/pay_stack_model.dart';
import 'package:jippydriver_driver/models/payment_model/paypal_model.dart';
import 'package:jippydriver_driver/models/payment_model/paytm_model.dart';
import 'package:jippydriver_driver/models/payment_model/razorpay_model.dart';
import 'package:jippydriver_driver/models/payment_model/stripe_model.dart';
import 'package:jippydriver_driver/models/payment_model/wallet_setting_model.dart';
import 'package:jippydriver_driver/models/payment_model/xendit.dart';
import 'package:jippydriver_driver/models/referral_model.dart';
import 'package:jippydriver_driver/models/tax_model.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/models/vendor_model.dart';
import 'package:jippydriver_driver/models/wallet_transaction_model.dart';
import 'package:jippydriver_driver/models/withdraw_method_model.dart';
import 'package:jippydriver_driver/models/withdrawal_model.dart';
import 'package:jippydriver_driver/models/zone_model.dart';
import 'package:jippydriver_driver/services/audio_player_service.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:jippydriver_driver/utils/common.dart';
import 'package:jippydriver_driver/utils/preferences.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import '../models/driver_earning_history_model.dart';

class FireStoreUtils {
  /// Strips invalid UTF-16 surrogate/control chars so [json.decode] won't throw.
  static String sanitizeHttpJsonBody(String body) {
    return String.fromCharCodes(
      body.runes.where(
        (int rune) =>
            rune == 0x9 ||
            rune == 0xA ||
            rune == 0xD ||
            (rune >= 0x20 &&
                rune <= 0x10FFFF &&
                (rune < 0xD800 || rune > 0xDFFF)),
      ),
    );
  }

  static FirebaseFirestore fireStore = FirebaseFirestore.instance;
  // Bust old (24h) charges cache once per app run after upgrade.
  static bool _driverChargesCacheBustedOnce = false;
  static final Map<String, _ProfileCacheEntry> _profileCache = {};
  static final Map<String, Future<UserModel?>> _profileInFlight = {};
  static const Duration _profileCacheTtl = Duration(seconds: 20);

  static Future<String> getCurrentUid() async{
    return await LoginController.getFirebaseId();
  }

  /// Drops in-memory profile cache so the next [getUserProfile] fetch sees fresh data.
  static void invalidateUserProfileCache(String uuid) {
    if (uuid.trim().isEmpty) return;
    _profileCache.remove(uuid);
  }
  static Future<bool> isLogin() async {
    bool isLogin = false;
    String? userId =await  LoginController.getFirebaseId();
    try {
      isLogin = await userExistOrNot(userId)
          .timeout(const Duration(seconds: 6), onTimeout: () {
        log("isLogin timeout - returning false");
        return false;
      });
    } catch (e) {
      log("isLogin error: $e - returning false");
      isLogin = false;
    }
      return isLogin;
  }
  static Future<bool> userExistOrNot(String uid) async {
    try {
      final response = await http.get(
        Uri.parse('${Constant.baseUrl}driver-sql/users/$uid/exists'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] == true;
        } else {
          log("API returned success: false");
          return false;
        }
      } else {
        log("Failed to check user exist: ${response.statusCode} - ${response.body}");
        return false;
      }
    } on TimeoutException catch (e) {
      log("userExistOrNot timeout: $e");
      return false;
    } catch (e) {
      log("userExistOrNot error: $e");
      return false;
    }
  }
  static Future<UserModel?> getUserProfile(String uuid, {bool forceRefresh = false}) async {
    if (uuid.trim().isEmpty) return null;

    final cached = _profileCache[uuid];
    if (!forceRefresh && cached != null && !cached.isExpired) {
      return cached.user;
    }
    if (!forceRefresh && _profileInFlight.containsKey(uuid)) {
      return _profileInFlight[uuid];
    }

    final future = () async {
      try {
        final httpClient = HttpClientService();
        final response = await httpClient.get(
          Uri.parse('${Constant.baseUrl}driver/getDriverDetails?driverId=$uuid'),
          headers: await getHeaders(),
          cacheStrategy: CacheStrategy.driverProfile,
          customTTL: _profileCacheTtl,
          useCache: !forceRefresh,
          forceRefresh: forceRefresh,
          timeout: const Duration(seconds: 10),
        );
        if (response.statusCode == 200) {
          final cleaned = sanitizeHttpJsonBody(response.body);
          final Map<String, dynamic> data = json.decode(cleaned);

          Map<String, dynamic> userDetails;
          if (data.containsKey('data') && data['data'] is Map) {
            userDetails = data['data'] as Map<String, dynamic>;
          } else {
            userDetails = data;
          }

          if (userDetails.isNotEmpty) {
            if (userDetails.containsKey('driverId') && !userDetails.containsKey('id')) {
              userDetails['id'] = userDetails['driverId'];
            }
            if (!userDetails.containsKey('role')) {
              userDetails['role'] = 'driver';
            }
            if (!userDetails.containsKey('active')) {
              userDetails['active'] = true;
            }
            if (!userDetails.containsKey('isActive')) {
              userDetails['isActive'] = true;
            }

            final user = UserModel.fromJson(userDetails);
            _profileCache[uuid] = _ProfileCacheEntry(
              user: user,
              cachedAt: DateTime.now(),
            );
            return user;
          }
        }
        if (response.statusCode != 404) {
          log("Failed to get user profile: ${response.statusCode} - ${response.body}");
        }
      } on TimeoutException catch (e) {
        log("getUserProfile timeout: $e");
      } catch (e) {
        log("getUserProfile error: $e");
      } finally {
        _profileInFlight.remove(uuid);
      }
      return null;
    }();

    _profileInFlight[uuid] = future;
    return future;
  }
  static Future<bool?> updateUserWalletHomeScreen({
    required String amount,
    required String userId
  }) async {
    try {
      var bodys = {
        'user_id': userId,
        'amount': double.parse(amount),
      };
      print("updateUserWalletHomeScreen ${bodys} ");
      print("updateUserWalletHomeScreen ${amount} ");
      final response = await http.post(
        Uri.parse('${Constant.baseUrl}driver-sql/delivery-amount/update'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(bodys),
      );
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] ?? true;
      } else {
        // Handle error response
        print('API Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error updating wallet: $e');
      return false;
    }
  }
  static Future<bool?> updateUserWallet({
    required String amount,
    required String userId
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${Constant.baseUrl}driver-sql/wallet/update'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'amount': double.parse(amount),
        }),
      );
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] ?? true;
      } else {
        // Handle error response
        print('API Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error updating wallet: $e');
      return false;
    }
  }
  static Future<bool?> updateUserDeliveryAmount(
      {required String amount, required String userId,OrderModel? orderModel}) async {
    bool isAdded = false;
    await getUserProfile(userId).then((value) async {
      if (value != null) {
        UserModel userModel = value;
        // userModel.deliveryAmount =
            // double.parse(orderModel?.deliveryCharge.toString()??'0');
        // userModel.walletAmount =
        // -double.parse(orderModel?.toPay?.toString() ?? '0');
        print("updateUserDeliveryAmount ${userModel.toJson()}");
        // double.parse(userModel.deliveryAmount.toString()) +
            //     double.parse(amount);
        // IMPORTANT: Use updateUserWithoutWalletDelivery to avoid interfering with
        // wallet/delivery amounts that are managed by separate APIs
        await FireStoreUtils.updateUserWithoutWalletDelivery(userModel).then((value) {
          isAdded = value;
        });
      }
    });
    return isAdded;
  }
  static Future<bool> updateUser(UserModel userModel) async {
    try {
      log("updateUser ${userModel.toJson()}");
      final response = await http.post(
        Uri.parse('${Constant.baseUrl}driver-sql/users/update'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(userModel.toJson()),
      );
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          Constant.userModel = userModel;
          log("User updated successfully: ${responseData['message']}");
          return true;
        } else {
          log("Failed to update user: ${responseData['message'] ?? 'Unknown error'}");
          return false;
        }
      } else {
        log("Failed to update user: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (error) {
      log("Failed to update user: $error");
      return false;
    }
  }

  /// Fallback parser for Terms & Conditions / Privacy HTML when json.decode fails
  /// Exposed as public so UI screens can call it directly when needed.
  static Future<String> extractHtmlFromSettings({
    required bool isPrivacy,
  }) async {
    try {
      final httpClient = HttpClientService();
      final response = await httpClient.get(
        Uri.parse('${Constant.baseUrl}driver-sql/settings'),
        cacheStrategy: CacheStrategy.settings,
        useCache: true,
        timeout: const Duration(seconds: 15),
      );
      if (response.statusCode != 200) return '';

      // Work on a sanitized copy (remove control characters only)
      final body = response.body.replaceAll(
        RegExp(r'[\u0000-\u001F]'),
        '',
      );

      // Remove all whitespace so we can reliably find keys regardless of formatting/newlines
      final text = body.replaceAll(RegExp(r'\s+'), '');

      // Choose the JSON path prefix where the HTML string starts
      final prefix = isPrivacy
          ? '"privacyPolicy":{"privacy_policy":"'
          : '"termsAndConditions":{"termsAndConditions":"';

      final start = text.indexOf(prefix);
      if (start == -1) {
        log('extractHtmlFromSettings: prefix not found (isPrivacy=$isPrivacy)');
        return '';
      }

      final valueStart = start + prefix.length;
      final buffer = StringBuffer();
      bool escaped = false;

      // Manually parse until the closing unescaped quote of this JSON string
      for (int i = valueStart; i < text.length; i++) {
        final ch = text[i];
        if (escaped) {
          buffer.write('\\$ch'); // keep escape sequences (we'll unescape later)
          escaped = false;
        } else if (ch == r'\\') {
          escaped = true;
        } else if (ch == '"') {
          // End of this JSON string value
          break;
        } else {
          buffer.write(ch);
        }
      }

      var escapedHtml = buffer.toString();

      // Unescape common JSON string escapes to get clean HTML
      var html = escapedHtml
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\n', '\n')
          .replaceAll(r'\\r', '')
          .replaceAll(r'\\t', '\t')
          .replaceAll(r'\\\\', '\\');

      log('extractHtmlFromSettings: extracted length=${html.length} isPrivacy=$isPrivacy');
      return html;
    } catch (e, stack) {
      log('_extractHtmlFromSettings error: $e\n$stack');
      return '';
    }
  }

  /// Update user without walletAmount and deliveryAmount fields
  /// This is used during order completion to avoid overwriting wallet/delivery amounts
  /// that are managed by separate APIs (driver-sql/wallet/update and driver-sql/delivery-amount/update)
  static Future<bool> updateUserWithoutWalletDelivery(UserModel userModel) async {
    try {
      Map<String, dynamic> userData = userModel.toJson();
      userData.remove('wallet_amount');
      userData.remove('deliveryAmount');
      log("updateUserWithoutWalletDelivery ${userData}");
      final response = await http.post(
        Uri.parse('${Constant.baseUrl}driver-sql/users/update'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(userData),
      );
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Don't update Constant.userModel here - it should be refreshed from API
          log("User updated successfully (without wallet/delivery): ${responseData['message']}");
          return true;
        } else {
          log("Failed to update user: ${responseData['message'] ?? 'Unknown error'}");
          return false;
        }
      } else {
        log("Failed to update user: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (error) {
      log("Failed to update user: $error");
      return false;
    }
  }
  static Future<List<OnBoardingModel>> getOnBoardingList() async {
    try {
      final response = await http.get(
        Uri.parse('${Constant.baseUrl}driver-sql/onboarding'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['data'];
          // Filter by type "driverApp" as in the original Firebase query
          final filteredData = data.where((item) => item['type'] == 'driverApp').toList();
          List<OnBoardingModel> onBoardingModel = filteredData
              .map((item) => OnBoardingModel.fromJson(item))
              .toList();
          return onBoardingModel;
        } else {
          throw Exception('API returned success: false');
        }
      } else {
        throw HttpException('Failed to load onboarding data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      log('Error fetching onboarding list: $e');
      return []; // Return empty list on error to maintain compatibility
    }
  }
  static Future<List<VendorModel>> getVendors() async {
    List<VendorModel> vendorList = [];
    try {
      if (Constant.selectedZone == null) {
        debugPrint('No zone selected');
        return vendorList;
      }
      final String zoneId = Constant.selectedZone!.id.toString();
      final response = await http.get(
        Uri.parse('${Constant.baseUrl}driver-sql/vendors?zone_id=$zoneId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['data'];

          for (var element in data) {
            try {
              debugPrint(element.toString());
              vendorList.add(VendorModel.fromJson(element));
            } catch (e) {
              debugPrint('VendorModel Parse error: $e');
            }
          }
          return vendorList;
        } else {
          throw Exception('API returned success: false');
        }
      } else {
        throw HttpException('Failed to load vendors. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in getVendors: $e');
      return vendorList; // Return empty list on error
    }
  }

  static Future<bool?> setWalletTransaction(
      WalletTransactionModel walletTransactionModel) async {
    try {
      final response = await http.post(
         Uri.parse('${Constant.baseUrl}driver/wallet/transaction'),

        headers: {
          'Content-Type': 'application/json',
          // Add any other required headers like authorization
        },
        body: jsonEncode(walletTransactionModel.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        log("Wallet transaction added successfully");
        return true;
      } else {
        log("Failed to add wallet transaction: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (error) {
      log("Failed to update user: $error");
      return false;
    }
  }
  static Future<bool?> setDriverWalletRecord(
      Map<String, dynamic> driverWalletTransaction) async {
    try {
      print("transactionModel id ${driverWalletTransaction['id']}");
      final response = await http.post(
        Uri.parse('${Constant.baseUrl}driver/wallet/withdraw-method'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(driverWalletTransaction),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Driver wallet record added successfully");
        return true;
      } else {
        // Handle different error status codes
        print("Failed to add driver wallet record: ${response.statusCode}");
        return false;
      }
    } catch (error) {
      print("Failed to update user: $error");
      return false;
    }
  }
  static Future<Map<String, dynamic>> getDriverCharges({
    bool forceRefresh = false,
  }) async {
    // Fallback defaults (kept in sync with HomeController defaults)
    const pickupDefault = 3.0;
    const deliveryFirstSlabKmDefault = 4.0;
    const deliveryRsPerKmFirstSlabDefault = 8.0;
    const deliveryRsPerKmBeyondDefault = 10.0;
    const deliveryShortTripMaxKmDefault = 2.0;
    const deliveryShortTripBaseChargeDefault = 21.0;

    double toDouble(dynamic v, double fallback) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim()) ?? fallback;
      return fallback;
    }

    try {
      final httpClient = HttpClientService();
      if (!_driverChargesCacheBustedOnce) {
        _driverChargesCacheBustedOnce = true;
        // Previously this endpoint was cached with a 24h TTL (settings strategy).
        // Clear it once so updated backend prices reflect quickly.
        try {
          await httpClient.invalidateCache('driver-sql/charges');
        } catch (_) {}
      }
      final response = await httpClient.get(
        Uri.parse('${Constant.baseUrl}driver-sql/charges'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        // Charges should be cached, but not for 24h (backend may update).
        cacheStrategy: CacheStrategy.custom,
        customTTL: const Duration(hours: 1),
        useCache: true,
        forceRefresh: forceRefresh,
        timeout: const Duration(seconds: 8),
        enableRetry: true,
      );

      final body = response.body.trim();
      if (response.statusCode != 200 || body.startsWith('<')) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final jsonResponse = json.decode(body);
      if (jsonResponse is! Map<String, dynamic>) {
        throw Exception('Unexpected JSON shape');
      }

      if (jsonResponse['success'] != true) {
        throw Exception('API returned success=false');
      }

      final dataRaw = jsonResponse['data'];
      final data =
          dataRaw is Map ? Map<String, dynamic>.from(dataRaw) : <String, dynamic>{};

      final pickup = toDouble(data['pickup_rs_per_km'], pickupDefault);
      final firstSlabKm =
          toDouble(data['delivery_first_slab_km'], deliveryFirstSlabKmDefault);
      final firstSlabRate = toDouble(
        data['delivery_rs_per_km_first_slab'],
        deliveryRsPerKmFirstSlabDefault,
      );
      final beyondRate = toDouble(
        data['delivery_rs_per_km_beyond'],
        deliveryRsPerKmBeyondDefault,
      );
      final shortTripMaxKm = toDouble(
        data['delivery_short_trip_max_km'],
        deliveryShortTripMaxKmDefault,
      );
      final shortTripBaseCharge = toDouble(
        data['delivery_short_trip_base_charge'],
        deliveryShortTripBaseChargeDefault,
      );

      log(
        'Driver charges loaded '
        '(forceRefresh=$forceRefresh) '
        'pickup=$pickup firstSlabKm=$firstSlabKm '
        'firstSlabRate=$firstSlabRate beyondRate=$beyondRate '
        'shortTrip≤${shortTripMaxKm}km=flat₹$shortTripBaseCharge',
      );

      return {
        'pickup_rs_per_km': pickup,
        'delivery_first_slab_km': firstSlabKm,
        'delivery_rs_per_km_first_slab': firstSlabRate,
        'delivery_rs_per_km_beyond': beyondRate,
        'delivery_short_trip_max_km': shortTripMaxKm,
        'delivery_short_trip_base_charge': shortTripBaseCharge,
      };
    } catch (e) {
      // Don't break the app if charges fetch fails; caller will use defaults.
      print('❌ Error fetching driver charges (using defaults): $e');
      return {
        'pickup_rs_per_km': pickupDefault,
        'delivery_first_slab_km': deliveryFirstSlabKmDefault,
        'delivery_rs_per_km_first_slab': deliveryRsPerKmFirstSlabDefault,
        'delivery_rs_per_km_beyond': deliveryRsPerKmBeyondDefault,
        'delivery_short_trip_max_km': deliveryShortTripMaxKmDefault,
        'delivery_short_trip_base_charge': deliveryShortTripBaseChargeDefault,
      };
    }
  }

 static Future<void> getSettings({bool forceRefresh = false}) async {
    try {
      bool _readBool(dynamic value, {bool defaultValue = false}) {
        if (value is bool) return value;
        if (value is num) return value != 0;
        if (value is String) {
          final v = value.trim().toLowerCase();
          if (v == 'true' || v == '1' || v == 'yes') return true;
          if (v == 'false' || v == '0' || v == 'no') return false;
        }
        return defaultValue;
      }

      print('getSettings ${Constant.baseUrl}driver-sql/settings');
      // Use HttpClientService with caching - settings rarely change (24 hours cache)
      final httpClient = HttpClientService();
      final response = await httpClient.get(
        Uri.parse('${Constant.baseUrl}driver-sql/settings'),
        cacheStrategy: CacheStrategy.settings, // 24 hours cache
        useCache: !forceRefresh,
        forceRefresh: forceRefresh,
        timeout: const Duration(seconds: 5),
        enableRetry: false,
      );
      if (response.statusCode == 200) {
        // Check for HTML responses (error pages)
        if (response.body.trim().startsWith('<!') || response.body.trim().startsWith('<html')) {
          log('getSettings - Received HTML response instead of JSON');
          return;
        }
        // Some backends may include invalid control characters in the JSON string,
        // which can cause `json.decode` to throw "Invalid argument (string): Contains invalid characters".
        final cleaned = sanitizeHttpJsonBody(response.body);
        final jsonResponse = json.decode(cleaned);
        log('getSettings - Response decoded, success: ${jsonResponse['success']}');
        if (jsonResponse['success'] == true) {
          final data = jsonResponse['data'];
          log('getSettings - Data keys: ${data?.keys.toList()}');
          // Process globalSettings
          final globalSettings = data['globalSettings'];
          if (globalSettings != null) {
            Constant.orderRingtoneUrl = globalSettings['order_ringtone_url'] ?? '';
            Constant.isSelfDeliveryFeature =
                _readBool(globalSettings['isSelfDelivery']);
            Preferences.setString(Preferences.orderRingtone, Constant.orderRingtoneUrl);
            final appDriverColor = globalSettings['app_driver_color'];
            if (appDriverColor != null) {
              AppThemeData.driverApp300 = Color(int.parse(appDriverColor.replaceFirst("#", "0xff")));
            }
            if (Constant.orderRingtoneUrl.isNotEmpty) {
              await AudioPlayerService.initAudio();
            }
          }
          // Process googleMapKey
          try {
            final googleMapKey = data['googleMapKey'];
            log('getSettings - googleMapKey data: $googleMapKey, type: ${googleMapKey?.runtimeType}');
            if (googleMapKey != null) {
              // Handle both Map and direct string cases
              if (googleMapKey is Map<String, dynamic> || googleMapKey is Map) {
                final keyValue = (googleMapKey as dynamic)["key"];
                if (keyValue != null) {
                  Constant.mapAPIKey = keyValue.toString();
                  log('getSettings - ✅ Set mapAPIKey from Map["key"]: ${Constant.mapAPIKey.isNotEmpty ? "SET (${Constant.mapAPIKey.length} chars)" : "EMPTY"}');
                } else {
                  log('getSettings - ⚠️ googleMapKey Map exists but "key" field is null or missing');
                }
              } else if (googleMapKey is String) {
                Constant.mapAPIKey = googleMapKey;
                log('getSettings - ✅ Set mapAPIKey from String: ${Constant.mapAPIKey.isNotEmpty ? "SET (${Constant.mapAPIKey.length} chars)" : "EMPTY"}');
              } else {
                log('getSettings - ⚠️ googleMapKey is neither Map nor String: ${googleMapKey.runtimeType}, value: $googleMapKey');
                // Try to convert to string as last resort
                try {
                  Constant.mapAPIKey = googleMapKey.toString();
                  if (Constant.mapAPIKey.isNotEmpty && Constant.mapAPIKey != 'null') {
                    log('getSettings - ✅ Set mapAPIKey from toString(): ${Constant.mapAPIKey.length} chars');
                  }
                } catch (e) {
                  log('getSettings - ❌ Failed to convert googleMapKey to string: $e');
                }
              }
            } else {
              log('getSettings - ⚠️ googleMapKey is null in data');
            }
          } catch (e, stackTrace) {
            log('getSettings - ❌ Error processing googleMapKey: $e');
            log('getSettings - Stack trace: $stackTrace');
          }
          log('getSettings - Final mapAPIKey value: ${Constant.mapAPIKey.isNotEmpty ? "✅ SET (${Constant.mapAPIKey.length} chars)" : "❌ EMPTY"}');
          
          // Also update polylinePoints with the new API key if it was set
          if (Constant.mapAPIKey.isNotEmpty) {
            // Note: polylinePoints is in HomeController, so we can't update it here
            // But we can log that it should be updated
            log('getSettings - mapAPIKey is now set, should update polylinePoints in HomeController');
          }
          
          // Process notification_setting
          final rawNotificationSetting = data['notification_setting'];
          Map<String, dynamic>? notificationSetting;
          if (rawNotificationSetting is Map) {
            notificationSetting =
                Map<String, dynamic>.from(rawNotificationSetting);
          } else if (rawNotificationSetting is String &&
              rawNotificationSetting.trim().isNotEmpty) {
            try {
              final decoded = jsonDecode(rawNotificationSetting);
              if (decoded is Map) {
                notificationSetting = Map<String, dynamic>.from(decoded);
              }
            } catch (_) {}
          }
          if (notificationSetting != null) {
            final projectId = notificationSetting['projectId'] ??
                notificationSetting['project_id'] ??
                notificationSetting['projectid'] ??
                '';

            final senderId = notificationSetting['senderId'] ??
                notificationSetting['sender_id'] ??
                '';

            final serviceJson = notificationSetting['serviceJson'] ??
                notificationSetting['service_json'] ??
                notificationSetting['serviceJsonUrl'] ??
                notificationSetting['service_json_url'] ??
                notificationSetting['serviceJsonFile'] ??
                notificationSetting['service_json_file'] ??
                '';

            // Keep a non-empty value so notification code can resolve project id later.
            Constant.senderId = (projectId.toString().trim().isNotEmpty
                    ? projectId.toString()
                    : senderId.toString())
                .trim();
            Constant.jsonNotificationFileURL = serviceJson.toString().trim();

            if (Constant.senderId.isEmpty ||
                Constant.jsonNotificationFileURL.isEmpty) {
              log('getSettings notification_setting missing config. '
                  'senderIdLen=${Constant.senderId.length} '
                  'serviceJsonLen=${Constant.jsonNotificationFileURL.length} '
                  'keys=${notificationSetting.keys.toList()}');
            }
          }
          final restaurantNearBy = data['RestaurantNearBy'];
          if (restaurantNearBy != null) {
            Constant.distanceType = restaurantNearBy["distanceType"] ?? '';
          }
          // Process privacyPolicy
          final privacyPolicy = data['privacyPolicy'];
          if (privacyPolicy != null) {
            final html = privacyPolicy["privacy_policy"] ?? '';
            Constant.privacyPolicy = html;
            if (html.isNotEmpty) {
              await Preferences.setString(Preferences.cachedPrivacyPolicy, html);
            }
          }
          // Process termsAndConditions
          final termsAndConditions = data['termsAndConditions'];
          if (termsAndConditions != null) {
            final html = termsAndConditions["termsAndConditions"] ?? '';
            Constant.termsAndConditions = html;
            if (html.isNotEmpty) {
              await Preferences.setString(Preferences.cachedTermsAndConditions, html);
            }
          }
          // Process Version (includes mandatory update control from backend)
          final version = data['Version'];
          if (version != null) {
            Constant.googlePlayLink = version["googlePlayLink"] ?? '';
            Constant.appStoreLink = version["appStoreLink"] ?? '';
            Constant.appVersion = version["app_version"] ?? '';
            Constant.forceUpdateRequired = version["force_update"] == true;
            Constant.minAppVersion = (version["min_app_version"] ?? version["minAppVersion"] ?? '').toString().trim();
          }
          // Process referral_amount
          final referralAmount = data['referral_amount'];
          if (referralAmount != null) {
            Constant.referralAmount = referralAmount['referralAmount']?.toString() ?? '';
          }
          // Process emailSetting
          final emailSetting = data['emailSetting'];
          if (emailSetting != null) {
            Constant.mailSettings = MailSettings.fromJson(emailSetting);
          }
          final placeHolderImage = data['placeHolderImage'];
          if (placeHolderImage != null) {
            Constant.placeHolderImage = placeHolderImage['image'] ?? '';
          }
          // Process document_verification_settings
          final docVerification = data['document_verification_settings'];
          if (docVerification != null) {
            Constant.isDriverVerification =
                _readBool(docVerification['isDriverVerification']);
            print("Constant.isDriverVerification ${ docVerification['isDriverVerification']}  ${ Constant.isDriverVerification}");
          }
          // Process DriverNearBy
          final driverNearBy = data['DriverNearBy'];
          if (driverNearBy != null) {
            Constant.minimumDepositToRideAccept = driverNearBy['minimumDepositToRideAccept']?.toString() ?? '';
            Constant.minimumAmountToWithdrawal = driverNearBy['minimumAmountToWithdrawal']?.toString() ?? '';
            Constant.driverLocationUpdate = driverNearBy['driverLocationUpdate']?.toString() ?? '';
            Constant.singleOrderReceive =
                _readBool(driverNearBy['singleOrderReceive']);
            Constant.selectedMapType = driverNearBy["selectedMapType"] ?? '';
            Constant.mapType = driverNearBy["mapType"] ?? '';
            Constant.autoApproveDriver =
                _readBool(driverNearBy["auto_approve_driver"]);
            log("Constant.singleOrderReceive :: ${Constant.singleOrderReceive}");
          }
        } else {
          log('API returned success: false');
        }
      } else {
        log('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      log(e.toString());
    }
  }

  /// Fetches force-update config from GET driver-sql/forceupdate.
  /// Response: { googlePlayLink, appStoreLink, app_version, force_update, min_app_version }
  /// or { success: true, data: { ... } }. Updates Constant and returns true on success.
  static Future<bool> getForceUpdateConfig() async {
    try {
      final response = await http.get(
        Uri.parse('${Constant.baseUrl}driver-sql/forceupdate'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;
      final decoded = json.decode(response.body);
      final Map<String, dynamic> data = decoded is Map && decoded['data'] != null
          ? Map<String, dynamic>.from(decoded['data'] as Map)
          : Map<String, dynamic>.from(decoded as Map);
      Constant.googlePlayLink = (data['googlePlayLink'] ?? '').toString();
      Constant.appStoreLink = (data['appStoreLink'] ?? '').toString();
      Constant.appVersion = (data['app_version'] ?? '').toString();
      Constant.forceUpdateRequired = data['force_update'] == true;
      Constant.minAppVersion = (data['min_app_version'] ?? data['minAppVersion'] ?? '').toString().trim();
      Constant.showUpdate = data['show_update'] == true;
      log('getForceUpdateConfig: min_app_version=${Constant.minAppVersion}, force_update=${Constant.forceUpdateRequired}, show_update=${Constant.showUpdate}');
      return true;
    } catch (e) {
      log('getForceUpdateConfig error: $e');
      return false;
    }
  }

  static Future<List<ZoneModel>?> getZone() async {
    List<ZoneModel> zoneList = [];
    try {
      print("getZone ") ;
      // Use HttpClientService with caching - zones rarely change (2 hours cache)
      final httpClient = HttpClientService();
      final response = await httpClient.get(
        Uri.parse('${Constant.baseUrl}restaurant/zones'),
        headers: {
          'Content-Type': 'application/json',
        },
        cacheStrategy: CacheStrategy.custom, // Custom TTL for zones
        customTTL: const Duration(hours: 2), // Zones change rarely, cache for 2 hours
        useCache: true,
      );
      print("getZone ${response.body}") ;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Check if response is successful
        if (responseData['success'] != true) {
          print("API returned unsuccessful response");
          return [];
        }

        // Get the data array
        List<dynamic> zonesData = responseData['data'] ?? [];

        print("Found ${zonesData.length} zones in API response");

        for (var element in zonesData) {
          try {
            // Check if zone is published (handles both int and bool)
            final publishValue = element['publish'];
            final isPublished = publishValue == 1 || publishValue == true;

            if (isPublished) {
              ZoneModel zoneModel = ZoneModel.fromJson(element);
              zoneList.add(zoneModel);
              print("Added zone: ${zoneModel.name}");
            }
          } catch (e) {
            print("Error parsing zone: $e");
          }
        }
      } else {
        print("Failed to load zones: ${response.statusCode}");
        return [];
      }
    } catch (e, s) {
      log('APIUtils.getZone $e $s');
      return [];
    }

    print("Returning ${zoneList.length} zones");
    return zoneList;
  }
  // static Future<WalletTransactionsApiResponse?> getWalletTransaction({
  //   int page = 1,
  //   int perPage = 10,
  // }) async {
  //   try {
  //     final String driverId = await FireStoreUtils.getCurrentUid();
  //     final response = await http.get(
  //
  //       Uri.parse('${Constant.baseUrl}driver-sql/wallet/transactions?page=$page&per_page=$perPage&driver_id=$driverId'),
  //       //Uri.parse('http://187.127.156.147:8084/api/driver/insertOrUpdateDriverCodBalance'),
  //
  //
  //     );
  //
  //     if (response.statusCode == 200) {
  //       final decoded = json.decode(response.body);
  //       if (decoded is! Map<String, dynamic>) {
  //         log('Wallet API returned unexpected payload');
  //         return null;
  //       }
  //       final parsed = WalletTransactionsApiResponse.fromJson(decoded);
  //       if (parsed.success) {
  //         return parsed;
  //       } else {
  //         log('API returned success: false');
  //         return null;
  //       }
  //     } else {
  //       log('HTTP error: ${response.statusCode}');
  //       return null;
  //     }
  //   } catch (error) {
  //     log(error.toString());
  //     return null;
  //   }
  // }


  static Future<WalletTransactionsApiResponse?> getWalletTransaction({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final String driverId = await FireStoreUtils.getCurrentUid();

      //3rd screen COD Wallet api
      final response = await http.get(
        Uri.parse(
          '${Constant.baseUrl}driver-sql/wallet/transactions'
              '?page=$page&per_page=$perPage&driver_id=$driverId',
        ),
      );

      if (response.statusCode != 200) {
        log('HTTP error: ${response.statusCode}');
        return null;
      }

      final decoded = json.decode(response.body);

      ///Normalize Java List response
      Map<String, dynamic> normalized;

      if (decoded is List) {
        normalized = {
          "success": true,
          "data": decoded,
          "summary": {
            "total_wallet_amount": 0
          }
        };
      } else if (decoded is Map<String, dynamic>) {
        normalized = decoded;
      } else {
        log('Invalid API format: ${decoded.runtimeType}');
        return null;
      }

      ///Safe parsing
      final parsed =
      WalletTransactionsApiResponse.fromJson(normalized);

      //Safety check
      return parsed;
    } catch (error) {
      log('Wallet API Exception: $error');
      return null;
    }
  }

  static Future<DriverAmountWalletApiResponse?> getDriverAmountWalletTransactionsPage({
    int page = 1,
    int perPage = 10,
    bool forceRefresh = false,
  }) async {
    try {
      final driverId = await FireStoreUtils.getCurrentUid();
      if (driverId.isEmpty) {
        log("Driver ID is empty");
        return null;
      }

      final httpClient = HttpClientService();
      final response = await httpClient.get(
        Uri.parse('${Constant.baseUrl}driver-sql/wallet/delivery-records?driver_id=$driverId&page=$page&per_page=$perPage'),
        //Uri.parse('http://187.127.156.147:8084/api/driver/insertOrUpdateDriverCodBalance'),

        //headers: {'Content-Type': 'application/json', 'Accept': 'application/json',
        //'Authorization':'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJtdW5qYWNoYW5kYW5hQGdtYWlsLmNvbSIsInJvbGVzIjpbXSwidXNlcklkIjo3LCJpYXQiOjE3ODAwNjAzNTAsImV4cCI6MTc4MDE0Njc1MH0.4rij5DuY0iIigzBybMorrhjpxM5fOvkx34g0uXYtMQc'},
        cacheStrategy: CacheStrategy.custom,
        customTTL: const Duration(seconds: 25),
        useCache: !forceRefresh,
        forceRefresh: forceRefresh,
        timeout: const Duration(seconds: 12),
      );

      if (response.statusCode != 200) {
        log("API error: ${response.statusCode} - ${response.body}");
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        log("Unexpected response shape for delivery records API");
        return null;
      }

      final parsed = DriverAmountWalletApiResponse.fromJson(decoded);
      if (!parsed.success) {
        log("Delivery records API returned success=false");
      }
      return parsed;
    } catch (error) {
      log("Exception: ${error.toString()}");
      return null;
    }
  }

  static Future<List<DriverAmountWalletTransactionModel>?> getDriverAmountWalletTransaction() async {
    final response = await getDriverAmountWalletTransactionsPage(page: 1, perPage: 10);
    return response?.data;
  }


  static Future<List<DriverEarningHistoryModel>>
  fetchOrderEarningsHistory({
    bool forceRefresh = false,
  }) async {
    try {
      // final driverId = await FireStoreUtils.getCurrentUid();

      // if (driverId.isEmpty) {
      //   return [];
      // }
      //
      // final httpClient = HttpClientService();
      //
      // log("EARNINGS URL => ${Constant.baseUrl}...");
      // final response = await httpClient.get(
      //
      //   Uri.parse(
      //     '${Constant.baseUrl}driver/fetchOrderEarningsHistory?driverId=$driverId',
      //   ),
      //
      //   cacheStrategy: CacheStrategy.custom,
      //   customTTL: const Duration(seconds: 25),
      //   useCache: !forceRefresh,
      //   forceRefresh: forceRefresh,
      //   timeout: const Duration(seconds: 12),
      // );

      final driverId = "4"; // TEMP FIX
      final httpClient = HttpClientService();

      final url =
          // '${Constant.baseUrl}driver/fetchOrderEarningsHistory?driverId=$driverId';

          '${Constant.baseUrl}driver/fetchOrderEarningsHistory?driverId=$driverId';

      log("EARNINGS URL => $url");

      final response = await httpClient.get(
        Uri.parse(url),
        headers: await getHeaders()
        // cacheStrategy: CacheStrategy.custom,
        // customTTL: const Duration(seconds: 25),
        // useCache: !forceRefresh,
        // forceRefresh: forceRefresh,
        // timeout: const Duration(seconds: 12),
      );

      log("STATUS => ${response.statusCode}");
      log("BODY => ${response.body}");

      if (response.statusCode != 200) {
        log('Error: ${response.statusCode}');
        return [];
      }

      // final decoded = jsonDecode(response.body);
      //
      // if (decoded is! List) {
      //   return [];
      // }
      //
      // return decoded
      //     .map((e) => DriverEarningHistoryModel.fromJson(e))
      //     .toList();
      final decoded = jsonDecode(response.body);

      List dataList = [];

      if (decoded is List) {
        dataList = decoded;
      }
      else if (decoded is Map && decoded['data'] != null) {
        dataList = decoded['data'];
      }
      else if (decoded is Map && decoded['transactions'] != null) {
        dataList = decoded['transactions'];
      }
      else {
        log("Unexpected API format => $decoded");
        return [];
      }

      return dataList
          .map((e) => DriverEarningHistoryModel.fromJson(e))
          .toList();
    } catch (e) {
      log('fetchOrderEarningsHistory: $e');
      return [];
    }
  }
  /// Fetches payment gateway settings, persists them to [Preferences], and
  /// returns the raw `data` map (useful for fields not stored in prefs, e.g.
  /// withdraw method).
  static Future<Map<String, dynamic>?> getPaymentSettingsData() async {
    try {
      final httpClient = HttpClientService();
      final response = await httpClient.get(
        Uri.parse('${Constant.baseUrl}settings/payment'),

        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization' : 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJjaGFuZGFuYW11bmphQGdtYWlsLmNvbSIsInJvbGVzIjpbIlJPTEVfREVWQURNSU4iXSwidXNlcklkIjo1LCJpYXQiOjE3ODE2OTc0OTIsImV4cCI6MTc4MTc4Mzg5Mn0.aWAuZXJ_cvR869SLhto7ZPqrHz1CK6kZkIDvoK9S9x4',
        },
        cacheStrategy: CacheStrategy.settings,
        useCache: true,
        timeout: const Duration(seconds: 15),
      );


      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final Map<String, dynamic> paymentData = responseData['data'];

          // Process each payment method
          if (paymentData['payFastSettings'] != null) {
            PayFastModel payFastModel = PayFastModel.fromJson(paymentData['payFastSettings']);
            await Preferences.setString(
                Preferences.payFastSettings,
                jsonEncode(payFastModel.toJson())
            );
          }

          if (paymentData['MercadoPago'] != null) {
            MercadoPagoModel mercadoPagoModel = MercadoPagoModel.fromJson(paymentData['MercadoPago']);
            await Preferences.setString(
                Preferences.mercadoPago,
                jsonEncode(mercadoPagoModel.toJson())
            );
          }

          if (paymentData['paypalSettings'] != null) {
            PayPalModel payPalModel = PayPalModel.fromJson(paymentData['paypalSettings']);
            await Preferences.setString(
                Preferences.paypalSettings,
                jsonEncode(payPalModel.toJson())
            );
          }

          if (paymentData['stripeSettings'] != null) {
            StripeModel stripeModel = StripeModel.fromJson(paymentData['stripeSettings']);
            await Preferences.setString(
                Preferences.stripeSettings,
                jsonEncode(stripeModel.toJson())
            );
          }

          if (paymentData['flutterWave'] != null) {
            FlutterWaveModel flutterWaveModel = FlutterWaveModel.fromJson(paymentData['flutterWave']);
            await Preferences.setString(
                Preferences.flutterWave,
                jsonEncode(flutterWaveModel.toJson())
            );
          }

          if (paymentData['payStack'] != null) {
            PayStackModel payStackModel = PayStackModel.fromJson(paymentData['payStack']);
            await Preferences.setString(
                Preferences.payStack,
                jsonEncode(payStackModel.toJson())
            );
          }

          if (paymentData['PaytmSettings'] != null) {
            PaytmModel paytmModel = PaytmModel.fromJson(paymentData['PaytmSettings']);
            await Preferences.setString(
                Preferences.paytmSettings,
                jsonEncode(paytmModel.toJson())
            );
          }

          if (paymentData['walletSettings'] != null) {
            WalletSettingModel walletSettingModel = WalletSettingModel.fromJson(paymentData['walletSettings']);
            await Preferences.setString(
                Preferences.walletSettings,
                jsonEncode(walletSettingModel.toJson())
            );
          }

          if (paymentData['razorpaySettings'] != null) {
            RazorPayModel razorPayModel = RazorPayModel.fromJson(paymentData['razorpaySettings']);
            await Preferences.setString(
                Preferences.razorpaySettings,
                jsonEncode(razorPayModel.toJson())
            );
          }

          if (paymentData['CODSettings'] != null) {
            CodSettingModel codSettingModel = CodSettingModel.fromJson(paymentData['CODSettings']);
            await Preferences.setString(
                Preferences.codSettings,
                jsonEncode(codSettingModel.toJson())
            );
          }

          if (paymentData['midtrans_settings'] != null) {
            MidTrans midTrans = MidTrans.fromJson(paymentData['midtrans_settings']);
            await Preferences.setString(
                Preferences.midTransSettings,
                jsonEncode(midTrans.toJson())
            );
          }

          if (paymentData['orange_money_settings'] != null) {
            OrangeMoney orangeMoney = OrangeMoney.fromJson(paymentData['orange_money_settings']);
            await Preferences.setString(
                Preferences.orangeMoneySettings,
                jsonEncode(orangeMoney.toJson())
            );
          }

          if (paymentData['xendit_settings'] != null) {
            Xendit xendit = Xendit.fromJson(paymentData['xendit_settings']);
            await Preferences.setString(
                Preferences.xenditSettings,
                jsonEncode(xendit.toJson())
            );
          }
          return paymentData;
        }
        print('Failed to load payment settings: ${responseData['message']}');
        return null;
      }
      print('HTTP error ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      print('Error fetching payment settings: $e');
      return null;
    }
  }


  static Future<OrderModel?> getOrderById(String orderId) async {
    OrderModel? orderModel;
    try {
      final response = await http.get(
        Uri.parse('${Constant.baseUrl}restaurant/orders/$orderId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        orderModel = OrderModel.fromJson(responseData);
      } else if (response.statusCode == 404) {
        orderModel = null;
      } else {
        throw Exception('Failed to load order: ${response.statusCode}');
      }
    } catch (e, s) {
      log('APIUtils.getOrderById $e $s');
      return null;
    }
    return orderModel;
  }
  static Future<DeliveryCharge?> getDeliveryCharge() async {
    DeliveryCharge? deliveryCharge;
    try {
      final response = await http.get(
        Uri.parse('${Constant.baseUrl}restaurant/delivery-charge'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          deliveryCharge = DeliveryCharge.fromJson(responseData['data']);
        }
      } else {
        throw Exception('Failed to load delivery charge: ${response.statusCode}');
      }
    } catch (e, s) {
      log('APIUtils.getDeliveryCharge $e $s');
      return null;
    }
    return deliveryCharge;
  }

  static Future<List<TaxModel>?> getTaxList() async {
    List<TaxModel> taxList = [];

    try {
      // Get location coordinates
      List<Placemark> placeMarks = await placemarkFromCoordinates(
          Constant.selectedLocation.location?.latitude ?? 0.0,
          Constant.selectedLocation.location?.longitude ?? 0.0);

      final String country = placeMarks.first.country ?? 'India';

      // Make API call
      final response = await http.get(
        Uri.parse('${Constant.baseUrl}driver-sql/tax?country=$country'),
        headers: {
          'Content-Type': 'application/json',
          // Add any other required headers like authorization
          // 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Assuming the API returns a list of tax records
        if (responseData is List) {
          for (var element in responseData) {
            // Filter for enabled taxes on client side since API might not support it
            if (element['enable'] == true) {
              TaxModel taxModel = TaxModel.fromJson(element);
              taxList.add(taxModel);
            }
          }
        }
        // If the API returns an object with a data field containing the list
        else if (responseData is Map && responseData['data'] is List) {
          for (var element in responseData['data']) {
            // Filter for enabled taxes on client side
            if (element['enable'] == true) {
              TaxModel taxModel = TaxModel.fromJson(element);
              taxList.add(taxModel);
            }
          }
        }
      } else {
        log("getTaxList API error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (error) {
      log("getTaxList error: ${error.toString()}");
      return null;
    }

    return taxList;
  }
  static Future<bool?> setOrder(OrderModel orderModel) async {
    bool isAdded = false;
    try {
      log("setOrder ${orderModel.toJson()}");
      final Map<String, dynamic> data = orderModel.toJson();
      data.removeWhere((key, value) => value == null);
      // Don't modify createdAt when updating orders - exclude it from updates
      // Only include createdAt if this is a new order (id is null or empty)
      if (orderModel.id != null && orderModel.id!.isNotEmpty) {
        data.remove('createdAt');
        log("Excluded createdAt from order update to prevent modification");
      }
      final sanitizedData = _sanitizeForJson(data);
      log("Sending data: ${jsonEncode(sanitizedData)}");
      final response = await http.post(
        Uri.parse('${Constant.baseUrl}restaurant/orders'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(sanitizedData),
      ).timeout(const Duration(seconds: 30));
      log("Response status: ${response.statusCode}");
      log("Response body: ${response.body}");
      if (response.statusCode == 200 || response.statusCode == 201) {
        isAdded = true;
        log("Order set successfully");
      } else {
        log("🔥 Failed to update or set order: ${response.statusCode} - ${response.body}");
        isAdded = false;
      }
    } on TimeoutException catch (e) {
      log("🔥 Timeout while setting order: $e");
      isAdded = false;
    } catch (error) {
      log("🔥 Failed to update or set order: $error");
      log("🔥 Stack trace: ${StackTrace.current}");
      isAdded = false;
    }
    return isAdded;
  }

  /// Update only the status field of an order (optimized - doesn't update entire order)
  /// This is more efficient than setOrder when only status needs to be changed
  /// Uses dedicated driver-sql endpoint for status-only updates to avoid full order replacement
  static Future<bool?> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    bool isUpdated = false;
    try {
      log("updateOrderStatus - Order ID: $orderId, Status: $status");
      
      // Try dedicated driver-sql endpoint for status updates first (if it exists)
      // This endpoint should only update status field, not entire order
      try {
        final response = await http.post(
          Uri.parse('${Constant.baseUrl}driver-sql/orders/$orderId/status'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'status': status,
          }),
        ).timeout(const Duration(seconds: 10));
        
        log("Status update response status (driver-sql): ${response.statusCode}");
        log("Status update response body: ${response.body}");
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          final jsonResponse = jsonDecode(response.body);
          if (jsonResponse['success'] == true) {
            isUpdated = true;
            log("Order status updated successfully via driver-sql endpoint");
            return isUpdated;
          }
        }
      } catch (driverSqlError) {
        log("driver-sql status endpoint not available, trying PATCH: $driverSqlError");
      }
      
      // Try PATCH method for partial update
      try {
        final response = await http.patch(
          Uri.parse('${Constant.baseUrl}restaurant/orders/$orderId'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'status': status,
          }),
        ).timeout(const Duration(seconds: 30));
        
        log("Status update response status (PATCH): ${response.statusCode}");
        log("Status update response body: ${response.body}");
        
        if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
          isUpdated = true;
          log("Order status updated successfully via PATCH");
          return isUpdated;
        }
      } catch (patchError) {
        log("PATCH method not supported: $patchError");
      }
      
      // Last resort: Use POST but warn that backend needs to support partial updates
      // NOTE: This will only work if backend merges updates instead of full replace
      // If backend does full replace, this will overwrite other fields with null/defaults
      log("⚠️ WARNING: Using POST fallback - backend must support partial updates");
      log("⚠️ If backend does full replace, this will overwrite order data!");
      
      final response = await http.post(
        Uri.parse('${Constant.baseUrl}restaurant/orders'),
        headers: {
          'Content-Type': 'application/json',
          'X-Partial-Update': 'true', // Hint to backend this is a partial update
        },
        body: jsonEncode({
          'id': orderId,
          'status': status,
        }),
      ).timeout(const Duration(seconds: 30));
      
      log("Status update response status (POST fallback): ${response.statusCode}");
      log("Status update response body: ${response.body}");
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        isUpdated = true;
        log("Order status updated via POST fallback (backend must merge, not replace)");
      } else {
        log("🔥 Failed to update order status: ${response.statusCode} - ${response.body}");
        isUpdated = false;
      }
    } on TimeoutException catch (e) {
      log("🔥 Timeout while updating order status: $e");
      isUpdated = false;
    } catch (error) {
      log("🔥 Failed to update order status: $error");
      log("🔥 Stack trace: ${StackTrace.current}");
      isUpdated = false;
    }
    return isUpdated;
  }

// Helper function to sanitize data for JSON encoding
  static dynamic _sanitizeForJson(dynamic data) {
    if (data == null) return null;

    // Handle NaN values
    if (data is double && data.isNaN) {
      return 0.0; // or null, depending on your needs
    }

    if (data is Map<String, dynamic>) {
      final Map<String, dynamic> result = {};
      for (final key in data.keys) {
        result[key] = _sanitizeForJson(data[key]);
      }
      return result;
    } else if (data is List) {
      return data.map((item) => _sanitizeForJson(item)).toList();
    } else if (data is Timestamp) {
      return data.millisecondsSinceEpoch;
    } else if (data is DateTime) {
      return data.millisecondsSinceEpoch;
    } else if (data is GeoPoint) {
      return {
        'latitude': data.latitude,
        'longitude': data.longitude,
        '_type': 'geopoint'
      };
    } else if (data is num || data is String || data is bool) {
      return data;
    } else {
      // Try to convert to string as fallback
      try {
        return data.toString();
      } catch (e) {
        return null;
      }
    }
  }
  static Future<EmailTemplateModel?> getEmailTemplates(String type) async {
    EmailTemplateModel? emailTemplateModel;
    try {
      final response = await http.get(
        Uri.parse('${Constant.baseUrl}restaurant/email-templates/$type'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final dynamic templateData = responseData['data'] ?? responseData;
        print("------>");
        print(templateData);
        if (templateData != null) {
          emailTemplateModel = EmailTemplateModel.fromJson(templateData);
        }
      } else if (response.statusCode == 404) {
        // Email template not found
        print("------>");
        print("Email template not found for type: $type");
        emailTemplateModel = null;
      } else {
        throw Exception('Failed to load email template: ${response.statusCode}');
      }
    } catch (e, s) {
      log('APIUtils.getEmailTemplates $e $s');
      return null;
    }
    return emailTemplateModel;
  }

  /// Total earnings shown on home `_ChargeBreakdown` / `_totalEarningsBox` (d2r + r2c + tip +
  /// surge). The app stores that value on the order in [OrderModel.calculatedCharges]
  /// `totalCalculatedCharge` via `HomeController._updateOrderWithCharges`.
  static String _walletHomeScreenEarningsAmount(OrderModel order) {
    final cc = order.calculatedCharges;
    if (cc != null) {
      final raw = cc['totalCalculatedCharge'];
      if (raw != null) {
        final v = double.tryParse(raw.toString().trim());
        if (v != null) return v.toStringAsFixed(2);
      }
    }
    final fallback =
        double.tryParse(order.deliveryCharge?.toString().trim() ?? '') ?? 0.0;
    return fallback.toStringAsFixed(2);
  }

  static updateWallateAmount(OrderModel orderModel) async {
    log('[updateWallateAmount] START - Order ID: ${orderModel.id}');
    double subTotal = 0.0;
    double specialDiscount = 0.0;
    double taxAmount = 0.0;
    for (var element in orderModel.products!) {
      if (double.parse(element.discountPrice.toString()) <= 0) {
        subTotal = subTotal +
            double.parse(element.price.toString()) *
                double.parse(element.quantity.toString()) +
            (double.parse(element.extrasPrice.toString()) *
                double.parse(element.quantity.toString()));
      } else {
        subTotal = subTotal +
            double.parse(element.discountPrice.toString()) *
                double.parse(element.quantity.toString()) +
            (double.parse(element.extrasPrice.toString()) *
                double.parse(element.quantity.toString()));
      }
    }
    if (orderModel.specialDiscount != null) {
      if (orderModel.specialDiscount != null ||
          orderModel.specialDiscount!['special_discount'] != null) {
        specialDiscount = double.parse(
            orderModel.specialDiscount!['special_discount'].toString());
      }
    }
    // var totalamount = total - discount - specialDiscount;
    double basePrice =
        (subTotal / (1 + (double.parse(orderModel.adminCommission!) / 100))) -
            double.parse(orderModel.discount.toString()) -
            specialDiscount;
    if (orderModel.taxSetting != null) {
      for (var element in orderModel.taxSetting!) {
        taxAmount = taxAmount +
            Constant.calculateTax(
                amount: (subTotal -
                        double.parse(orderModel.discount.toString()) -
                        specialDiscount)
                    .toString(),
                taxModel: element);
      }
    }
    num driverAmount = 0;
    if (orderModel.paymentMethod!.toLowerCase() != "cod") {
      driverAmount += (double.parse(orderModel.deliveryCharge!) +
          double.parse(orderModel.tipAmount!));
    } else {
      //driverAmount += -(basePrice + taxAmount);
      print('[Wallet Deduction][COD] Order: ${orderModel.id}, ToPay: ${orderModel.toPay}, Deducting from wallet: -${orderModel.toPay}');
      driverAmount += -double.parse(orderModel.toPay.toString());
    }
    // Debug print: show deduction info
    final userId = orderModel.driverID??'';
    final userProfile = await getUserProfile(userId);
    final oldWallet = userProfile?.walletAmount ?? 0.0;
    final newWallet = oldWallet + double.parse(driverAmount.toString());

    print("orderModel.deliveryChargeorderModel.deliveryCharge ${orderModel.deliveryCharge.toString()}");
    print('[Wallet Deduction] Order: ${orderModel.id}, Driver: $userId, Old Wallet: $oldWallet, Change: ${driverAmount.toString()}, New Wallet: $newWallet');
    log('[updateWallateAmount] Calling updateUserWallet with amount: ${driverAmount.toString()}');
    await FireStoreUtils.updateUserWallet(
        userId: userId, amount: driverAmount.toString());
    final homeScreenEarnings = _walletHomeScreenEarningsAmount(orderModel);
    log('[updateWallateAmount] Calling updateUserWalletHomeScreen with amount: $homeScreenEarnings');
    await FireStoreUtils.updateUserWalletHomeScreen(
        userId: userId, amount: homeScreenEarnings);
    log('[updateWallateAmount] END - Order ID: ${orderModel.id}');
  }

  static sendTopUpMail(
      {required String amount,
      required String paymentMethod,
      required String tractionId}) async {
    EmailTemplateModel? emailTemplateModel =
        await FireStoreUtils.getEmailTemplates(Constant.walletTopup);

    String newString = emailTemplateModel!.message.toString();
    newString = newString.replaceAll(
        "{username}",
        (Constant.userModel?.firstName.toString() ?? '') +
            (Constant.userModel?.lastName.toString() ?? ''));
    newString = newString.replaceAll(
        "{date}", DateFormat('yyyy-MM-dd').format(Timestamp.now().toDate()));
    newString =
        newString.replaceAll("{amount}", Constant.amountShow(amount: amount));
    newString =
        newString.replaceAll("{paymentmethod}", paymentMethod.toString());
    newString = newString.replaceAll("{transactionid}", tractionId.toString());
    newString = newString.replaceAll(
        "{newwalletbalance}.",
        Constant.amountShow(
            amount: Constant.userModel?.walletAmount.toString() ?? '0'));
    await Constant.sendMail(
        subject: emailTemplateModel.subject,
        isAdmin: emailTemplateModel.isSendToAdmin,
        body: newString,
        recipients: [Constant.userModel?.email ?? '']);
  }

  static Future<List<Map<String, dynamic>>> getVendorProducts(String id) async {
    final url = "${Constant.baseUrl}restaurant/vendors/$id";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      /// Assuming API returns:
      /// {
      ///   "success": true,
      ///   "data": [ { product1 }, { product2 } ]
      /// }
      return List<Map<String, dynamic>>.from(data["data"]);
    } else {
      throw Exception("Failed to load vendor products");
    }
  }

 static Future<List<Map<String, dynamic>>> getVendorCategories() async {
    final url = "${Constant.baseUrl}restaurant/vendor-categories";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      /// Expected API format:
      /// {
      ///   "success": true,
      ///   "data": [ {...}, {...} ]
      /// }
      return List<Map<String, dynamic>>.from(data["data"]);
    } else {
      throw Exception("Failed to load vendor categories");
    }
  }

  static Future<List> getVendorCuisines(String id) async {
    List tagList = [];
    List prodTagList = [];
    List<Map<String, dynamic>> productsQuery = await getVendorProducts(id);
    for (var document in productsQuery) {
      if (document.containsKey("categoryID") &&
          document['categoryID'].toString().isNotEmpty) {
        prodTagList.add(document['categoryID']);
      }
    }
    List<Map<String, dynamic>> catData = await getVendorCategories();
    for (var document in catData) {
      if (document.containsKey("id") &&
          document["id"].toString().isNotEmpty &&
          document.containsKey("title") &&
          document["title"].toString().isNotEmpty &&
          prodTagList.contains(document["id"])) {
        tagList.add(document["title"]);
      }
    }
    return tagList;
  }


  static Future<NotificationModel?> getNotificationContent(String type) async {
    NotificationModel? notificationModel;
    try {
      String url = '${Constant.baseUrl}firestore/notifications/$type';
        print("getNotificationContent ${url}");
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
          },
        );
        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = json.decode(response.body);
          // Assuming the API returns the notification data directly or wrapped in a 'data' field
          final dynamic notificationData = responseData['data'] ?? responseData;
          print("------>");
          print(notificationData);
          notificationModel = NotificationModel.fromJson(notificationData);
        } else if (response.statusCode == 404) {
          // Notification not found - return default notification
          print("------>");
          print("Notification not found, using default");
          notificationModel = NotificationModel(
            id: "",
            message: "Notification setup is pending",
            subject: "setup notification",
            type: type,
          );
        } else {
          throw Exception('Failed to load notification: ${response.statusCode}');
        }
      } catch (e, s) {
        log('APIUtils.getNotificationContent $e $s');
        // Return default notification on error
        notificationModel = NotificationModel(
          id: "",
          message: "Notification setup is pending",
          subject: "setup notification",
          type: type,
        );
      }
      return notificationModel;
    }
    static Future<bool?> deleteUser() async {
      try {
        String? userId = await LoginController.getFirebaseId();
        // Delete user from database via API
        final response = await http.delete(
          Uri.parse('${Constant.baseUrl}driver-sql/users/$userId'),
        );

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);
          if (jsonResponse['success'] == true) {
            return true;
          } else {
            print('API returned error: ${jsonResponse['message']}');
            return false;
          }
        } else {
          print('API Error: ${response.statusCode}');
          return false;
        }
      } catch (e, s) {
        print('deleteUser error: $e $s');
        return false;
      }
    }

    static Future<List<DocumentModel>> getDocumentList() async {
      try {
        final response = await http.get(
          Uri.parse('${Constant.baseUrl}documents/driver/list'),
          headers: {
            'Content-Type': 'application/json',
          },
        );
        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);
          if (jsonResponse['success'] == true) {
            List<DocumentModel> documentList = [];
            for (var element in jsonResponse['data']) {
              DocumentModel documentModel = DocumentModel.fromJson(element);
              documentList.add(documentModel);
            }
            return documentList;
          } else {
            throw Exception('API Error: ${jsonResponse['message']}');
          }
        } else {
          throw Exception('HTTP Error: ${response.statusCode}');
        }
      } catch (error) {
        log(error.toString());
        rethrow; // or return an empty list: return [];
      }
    }
    static Future<DriverDocumentModel?> getDocumentOfDriver() async {
      String? userId = await LoginController.getFirebaseId();

      DriverDocumentModel? driverDocumentModel;
      print("getDocumentOfDriver ${Constant.baseUrl}driver/documents/$userId ");
      try {
        final response = await http.get(
          Uri.parse('${Constant.baseUrl}driver/documents/$userId'),
          headers: {
            'Content-Type': 'application/json',
          },
        );
        print("getDocumentOfDriver ${response.body} ");

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = json.decode(response.body);

          // Check if data exists in response
          if (responseData['data'] != null) {
            driverDocumentModel = DriverDocumentModel.fromJson(responseData);
          } else if (responseData['exists'] == true) {
            // Handle the case where API might return exists flag
            return null;
          }
        } else if (response.statusCode == 404) {
          // Document not found
          return null;
        } else {
          // Handle other error status codes
          throw Exception('Failed to load document: ${response.statusCode}');
        }
      } catch (e) {
        print('Error fetching driver document: $e');
        throw Exception('Failed to load driver document');
      }

      return driverDocumentModel;
    }
    static Future<InboxModel> addDriverInbox(InboxModel inboxModel) async {
      try {
        final response = await http.post(
          Uri.parse('${Constant.baseUrl}chat-driver/inbox'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(inboxModel.toJson()),
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          return inboxModel;
        } else {
          throw Exception('Failed to add driver inbox: ${response.statusCode}');
        }
      } catch (e) {
        throw Exception('Failed to add driver inbox: $e');
      }
    }

    static Future<ConversationModel> addDriverChat(ConversationModel conversationModel) async {
      try {
        final response = await http.post(
          Uri.parse('${Constant.baseUrl}chat-driver/thread'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(conversationModel.toJson()),
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          return conversationModel;
        } else {
          throw Exception('Failed to add driver chat: ${response.statusCode}');
        }
      } catch (e) {
        throw Exception('Failed to add driver chat: $e');
      }
    }


    static Future<ConversationModel> addRestaurantChat(ConversationModel conversationModel) async {
      try {
        final response = await http.post(
          Uri.parse('${Constant.baseUrl}chat-restaurant/thread'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode(conversationModel.toJson()),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return conversationModel;
        } else {
          throw Exception('Failed to add chat: ${response.statusCode}');
        }
      } catch (e) {
        throw Exception('Failed to add chat: $e');
      }
    }

    static Future<Url> uploadChatImageToFireStorage(
        File image, BuildContext context) async {
      ShowToastDialog.showLoader("Please wait");
      var uniqueID = const Uuid().v4();
      Reference upload =
          FirebaseStorage.instance.ref().child('images/$uniqueID.png');
      UploadTask uploadTask = upload.putFile(image);
      var storageRef = (await uploadTask.whenComplete(() {})).ref;
      var downloadUrl = await storageRef.getDownloadURL();
      var metaData = await storageRef.getMetadata();
      ShowToastDialog.closeLoader();
      return Url(
          mime: metaData.contentType ?? 'image', url: downloadUrl.toString());
    }

    // static Future<ChatVideoContainer> uploadChatVideoToFireStorage(File video, BuildContext context) async {
    //   ShowToastDialog.showLoader("Please wait");
    //   var uniqueID = const Uuid().v4();
    //   Reference upload = FirebaseStorage.instance.ref().child('videos/$uniqueID.mp4');
    //   SettableMetadata metadata = SettableMetadata(contentType: 'video');
    //   UploadTask uploadTask = upload.putFile(video, metadata);
    //   var storageRef = (await uploadTask.whenComplete(() {})).ref;
    //   var downloadUrl = await storageRef.getDownloadURL();
    //   var metaData = await storageRef.getMetadata();
    //   final uint8list = await VideoThumbnail.thumbnailFile(video: downloadUrl, thumbnailPath: (await getTemporaryDirectory()).path, imageFormat: ImageFormat.PNG);
    //   final file = File(uint8list ?? '');
    //   String thumbnailDownloadUrl = await uploadVideoThumbnailToFireStorage(file);
    //   ShowToastDialog.closeLoader();
    //   return ChatVideoContainer(videoUrl: Url(url: downloadUrl.toString(), mime: metaData.contentType ?? 'video'), thumbnailUrl: thumbnailDownloadUrl);
    // }

    static Future<ChatVideoContainer?> uploadChatVideoToFireStorage(
        BuildContext context, File video) async {
      try {
        ShowToastDialog.showLoader("Uploading video...");
        final String uniqueID = const Uuid().v4();
        final Reference videoRef =
            FirebaseStorage.instance.ref('videos/$uniqueID.mp4');
        final UploadTask uploadTask = videoRef.putFile(
          video,
          SettableMetadata(contentType: 'video/mp4'),
        );
        await uploadTask;
        final String videoUrl = await videoRef.getDownloadURL();
        ShowToastDialog.showLoader("Generating thumbnail...");
        File thumbnail = await VideoCompress.getFileThumbnail(
          video.path,
          quality: 75, // 0 - 100
          position: -1, // Get the first frame
        );

        final String thumbnailID = const Uuid().v4();
        final Reference thumbnailRef =
            FirebaseStorage.instance.ref('thumbnails/$thumbnailID.jpg');
        final UploadTask thumbnailUploadTask = thumbnailRef.putData(
          thumbnail.readAsBytesSync(),
          SettableMetadata(contentType: 'image/jpeg'),
        );
        await thumbnailUploadTask;
        final String thumbnailUrl = await thumbnailRef.getDownloadURL();
        var metaData = await thumbnailRef.getMetadata();
        ShowToastDialog.closeLoader();

        return ChatVideoContainer(
            videoUrl: Url(
                url: videoUrl.toString(),
                mime: metaData.contentType ?? 'video',
                videoThumbnail: thumbnailUrl),
            thumbnailUrl: thumbnailUrl);
      } catch (e) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Error: ${e.toString()}");
        return null;
      }
    }

    static Future<String> uploadVideoThumbnailToFireStorage(File file) async {
      var uniqueID = const Uuid().v4();
      Reference upload =
          FirebaseStorage.instance.ref().child('thumbnails/$uniqueID.png');
      UploadTask uploadTask = upload.putFile(file);
      var downloadUrl =
          await (await uploadTask.whenComplete(() {})).ref.getDownloadURL();
      return downloadUrl.toString();
    }

    static Future<WithdrawMethodModel?> getWithdrawMethod() async {
      try {
        final response = await http.get(
          Uri.parse('${Constant.baseUrl}driver/wallet/withdraw-method?userId=${getCurrentUid()}'),
          headers: {
            'Content-Type': 'application/json',
          },
        );
        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);
          // Assuming the API returns the data directly or in a 'data' field
          if (jsonResponse is Map<String, dynamic> && jsonResponse.isNotEmpty) {
            return WithdrawMethodModel.fromJson(jsonResponse);
          } else if (jsonResponse['data'] != null) {
            return WithdrawMethodModel.fromJson(jsonResponse['data']);
          }
          return null;
        } else if (response.statusCode == 404) {
          // No data found - equivalent to empty docs in Firebase
          return null;
        } else {
          // Handle other error status codes
          throw Exception('Failed to load withdraw method: ${response.statusCode}');
        }
      } catch (e) {
        // Handle network errors or parsing errors
        print('Error fetching withdraw method: $e');
        return null;
      }
    }

    static Future<WithdrawMethodModel?> setWithdrawMethod(
        WithdrawMethodModel withdrawMethodModel) async {
      try {
        String? userId = await LoginController.getFirebaseId();

        // Prepare the data
        if (withdrawMethodModel.id == null) {
          withdrawMethodModel.id = const Uuid().v4();
          withdrawMethodModel.userId = userId;
        }

        final response = await http.post(
          Uri.parse('${Constant.baseUrl}driver/wallet/withdraw-method'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode(withdrawMethodModel.toJson()),
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          final jsonResponse = json.decode(response.body);
          if (jsonResponse is Map<String, dynamic>) {
            if (jsonResponse['data'] != null) {
              return WithdrawMethodModel.fromJson(jsonResponse['data']);
            } else {
              return WithdrawMethodModel.fromJson(jsonResponse);
            }
          }
          // If API doesn't return the object, return the original with updates
          return withdrawMethodModel;
        } else {
          throw Exception('Failed to set withdraw method: ${response.statusCode}');
        }
      } catch (e) {
        print('Error setting withdraw method: $e');
        return null;
      }
    }
    static Future<List<WithdrawalModel>?> getWithdrawHistory() async {
      try {
        final response = await http.get(
          Uri.parse('${Constant.baseUrl}driver-sql/wallet/withdraw?driverID=${Constant.userModel!.id.toString()}'),
        );
        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);
          if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
            List<WithdrawalModel> walletTransactionList = [];
            for (var element in jsonResponse['data']) {
              WithdrawalModel walletTransactionModel = WithdrawalModel.fromJson(element);
              walletTransactionList.add(walletTransactionModel);
            }
            return walletTransactionList;
          } else {
            print('API returned error: ${jsonResponse['message']}');
            return [];
          }
        } else {
          print('API Error: ${response.statusCode}');
          return [];
        }
      } catch (e) {
        print('Error fetching withdrawal history: $e');
        return [];
      }
    }

    static sendPayoutMail(
        {required String amount, required String payoutrequestid}) async {
      EmailTemplateModel? emailTemplateModel =
          await FireStoreUtils.getEmailTemplates(Constant.payoutRequest);
      String body = emailTemplateModel!.subject.toString();
      body = body.replaceAll("{userid}", Constant.userModel!.id.toString());
      String newString = emailTemplateModel.message.toString();
      newString =
          newString.replaceAll("{username}", Constant.userModel!.fullName());
      newString =
          newString.replaceAll("{userid}", Constant.userModel!.id.toString());
      newString =
          newString.replaceAll("{amount}", Constant.amountShow(amount: amount));
      newString =
          newString.replaceAll("{payoutrequestid}", payoutrequestid.toString());
      newString = newString.replaceAll("{usercontactinfo}",
          "${Constant.userModel!.email}\n${Constant.userModel!.phoneNumber}");
      await Constant.sendMail(
          subject: body,
          isAdmin: emailTemplateModel.isSendToAdmin,
          body: newString,
          recipients: [Constant.userModel!.email],);
    }


    static Future<bool> withdrawWalletAmount(WithdrawalModel userModel) async {
      try {
        final response = await http.post(
          Uri.parse('${Constant.baseUrl}driver-sql/wallet/withdraw'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode(userModel.toJson()),
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          return true;
        } else {
          log("Failed to withdraw wallet amount: ${response.statusCode} - ${response.body}");
          return false;
        }
      } catch (error) {
        log("Error withdrawing wallet amount: $error");
        return false;
      }
    }

    static Future<bool> getFirestOrderOrNOt(OrderModel orderModel) async {
      try {
        final response = await http.get(
          Uri.parse('${Constant.baseUrl}driver-sql/orders/${orderModel.authorID}/is-first'),
          headers: {
            'Content-Type': 'application/json',
          },
        );
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            return responseData['data']['isFirstOrder'] ?? false;
          } else {
            log("API returned error: ${responseData['message']}");
            return false;
          }
        } else {
          log("Failed to check first order: ${response.statusCode} - ${response.body}");
          return false;
        }
      } catch (error) {
        log("Error checking first order: $error");
        return false;
      }
    }
    static Future updateReferralAmount(OrderModel orderModel) async {
      ReferralModel? referralModel;

      try {
        // Replace Firebase call with API call
        final response = await http.get(
          Uri.parse('${Constant.baseUrl}driver-sql/referrals/${orderModel.authorID}'),
        );

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);
          if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
            referralModel = ReferralModel.fromJson(jsonResponse['data']);
          } else {
            return;
          }
        } else {
          print('API Error: ${response.statusCode}');
          return;
        }
      } catch (e) {
        // Handle network/parsing errors
        print('Error fetching referral data: $e');
        return;
      }

      if (referralModel.referralBy != null &&
          referralModel.referralBy!.isNotEmpty) {
        WalletTransactionModel transactionModel = WalletTransactionModel(
            id: Constant.getUuid(),
            amount: double.parse(Constant.referralAmount.toString()),
            date: DateTime.now(),
            paymentMethod: "Referral Amount",
            transactionUser: "user",
            userId: referralModel.referralBy,
            isTopup: true,
            note: "You referral user has complete his this order #${orderModel.id}",
            paymentStatus: "success"
        );
        await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
          if (value == true) {
            await FireStoreUtils.updateUserWallet(
                amount: Constant.referralAmount.toString(),
                userId: referralModel!.referralBy.toString()
            ).then((value) {});
          }
        });
      } else {
        return;
      }
      }

    /// Atomically assign an order to a driver using Firestore transaction (FCFS locking)
    /// Returns: true on success, false on failure, null on rate limit (429)
    static Future<bool?> assignOrderToDriverFCFS({
      required String orderId,
      required String driverId,
      required UserModel driverModel,
    }) async {
      try {
        final response = await http.post(
          Uri.parse('${Constant.baseUrl}driver-sql/orders/assign'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'driver_id': driverId,
            'order_id': orderId,
          }),
        ).timeout(Duration(seconds: 10));

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);
          return jsonResponse['success'] == true;
        } else if (response.statusCode == 429) {
          // Rate limit - return null to indicate retry needed
          print('API Rate Limited (429): Too many requests');
          return null;
        } else {
          print('API Error: ${response.statusCode}');
          return false;
        }
      } catch (e) {
        print('Error assigning order to driver: $e');
        return false;
      }
    }

    static Future<void> removeOrderFromOtherDrivers({
      required String orderId,
      required String assignedDriverId,
    }) async {
      try {
        final response = await http.post(
          Uri.parse('${Constant.baseUrl}driver-sql/orders/remove-from-others'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'assigned_driver_id': assignedDriverId,
            'order_id': orderId,
          }),
        );
        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);
          if (jsonResponse['success'] != true) {
            print('Failed to remove order from other drivers');
          }
        } else {
          // Handle API error
          print('API Error: ${response.statusCode}');
        }
      } catch (e) {
        // Handle network/parsing errors
        print('Error removing order from other drivers: $e');
      }
    }
  }

  class _ProfileCacheEntry {
    final UserModel user;
    final DateTime cachedAt;

    const _ProfileCacheEntry({
      required this.user,
      required this.cachedAt,
    });

    bool get isExpired =>
        DateTime.now().difference(cachedAt) > FireStoreUtils._profileCacheTtl;
  }
