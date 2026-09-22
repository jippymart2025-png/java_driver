import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps [Constant.userModel.location] aligned with device GPS (`latitude` / `longitude`)
/// after login and on app resume, and mirrors it into prefs + optional API update.
///
/// [DashBoardController] registers [afterLocationAppliedToUserModel] so GetX UI refreshes
/// without creating an import cycle.
class DriverLocationSync {
  DriverLocationSync._();

  static bool _inFlight = false;

  /// Optional: dashboard (or other listeners) can refresh reactive UI after location writes.
  static VoidCallback? afterLocationAppliedToUserModel;

  static Future<void> syncDeviceLocationIntoUserModel({
    bool pushToServer = true,
  }) async {
    if (_inFlight) return;
    final user = Constant.userModel;
    if (user == null) return;

    final uid = user.firebaseId ?? user.id?.toString();
    if (uid == null || uid.trim().isEmpty) return;

    _inFlight = true;
    try {
      final pos = await Utils.getCurrentLocation();
      if (pos == null) return;

      final loc = UserLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      user.location = loc;
      Constant.userModel = user;

      afterLocationAppliedToUserModel?.call();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userLocation', jsonEncode(loc.toJson()));

      final raw = prefs.getString('userData');
      if (raw != null && raw.isNotEmpty) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          map['location'] = loc.toJson();
          await prefs.setString('userData', jsonEncode(map));
        } catch (e) {
          debugPrint('DriverLocationSync: userData merge skipped: $e');
        }
      }

      FireStoreUtils.invalidateUserProfileCache(uid);

      // if (pushToServer) {
      //   await FireStoreUtils.updateUserWithoutWalletDelivery(user);
      // }
    } catch (e, st) {
      debugPrint('DriverLocationSync error: $e\n$st');
    } finally {
      _inFlight = false;
    }
  }
}
