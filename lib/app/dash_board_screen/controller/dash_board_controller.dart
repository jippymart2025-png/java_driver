import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:get/get.dart';
import 'package:google_maps_flutter_platform_interface/src/types/location.dart';
import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/models/zone_model.dart' hide LatLng;
import 'package:location/location.dart' as loc;

import 'package:jippydriver_driver/app/home_screen/controller/home_controller.dart';
import 'package:jippydriver_driver/app/mandatory_update_screen.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/app/auth_screen/controller/login_controller.dart';
import 'package:jippydriver_driver/models/order_model.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:jippydriver_driver/utils/driver_location_sync.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/utils/preferences.dart';
import 'package:jippydriver_driver/utils/version_utils.dart';
import 'package:jippydriver_driver/utils/perf_telemetry.dart';

class DashBoardController extends GetxController with WidgetsBindingObserver {

  // ── Drawer navigation ───────────────────────────────────────────────
  final RxInt drawerIndex = 0.obs;

  // ── User ─────────────────────────────────────────────────────────────
  final Rx<UserModel> userModel = UserModel().obs;

  // ── Theme ─────────────────────────────────────────────────────────────
  final RxString isDarkMode       = 'Light'.obs;
  final RxBool   isDarkModeSwitch = false.obs;

  // ── Back-press double-tap ────────────────────────────────────────────
  DateTime? currentBackPressTime;
  final RxBool canPopNow = false.obs;

  // ── Location ─────────────────────────────────────────────────────────
  final loc.Location _location = loc.Location();
  StreamSubscription<loc.LocationData>? _locationSubscription;

  // Throttle state
  // Watermark used to decide whether we should enqueue a server write.
  UserLocation? _lastThrottleLocation;
  DateTime?     _lastThrottleTime;

  // Tracks last successful server write (for debugging/telemetry).
  UserLocation? _lastWrittenLocation;
  DateTime?     _lastWrittenTime;
  bool _isAppForeground = true;
  bool _locationListenerActive = false;

  // Batch queue (background mode only)
  final List<_LocationWrite> _pendingUpdates = [];
  Timer? _batchTimer;

  // Throttle constants
  static const double _fgMinMeters  = 100.0;
  static const double _bgMinMeters  = 200.0;
  static const Duration _fgMinTime  = Duration(seconds: 30);
  static const Duration _bgMinTime  = Duration(minutes: 1);
  static const Duration _batchDelay = Duration(seconds: 10);
  static const int _maxBatch        = 5;

  // ── Mandatory update guard ───────────────────────────────────────────
  bool _updateCheckedThisSession = false;

  // ══════════════════════════════════════════════════════════════════════
  //  Lifecycle
  // ══════════════════════════════════════════════════════════════════════

  @override
  void onInit() {
    AppLogger.log('DashBoardController onInit()', tag: 'Dashboard');
    DriverLocationSync.afterLocationAppliedToUserModel = () => userModel.refresh();
    WidgetsBinding.instance.addObserver(this);
    _checkMandatoryUpdate();
    getUser();          // fetches user then starts location listener
    // updateDriverOrder();
    _loadTheme();
    // Ensure HomeController is available for HomeScreen
    if (!Get.isRegistered<HomeController>()) {
      Get.put(HomeController());
    }
    super.onInit();
  }

  @override
  void onClose() {
    AppLogger.log('DashBoardController onClose()', tag: 'Dashboard');
    DriverLocationSync.afterLocationAppliedToUserModel = null;
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationListener();
    if (_pendingUpdates.isNotEmpty) unawaited(_flushBatch());
    _batchTimer?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isFg = state == AppLifecycleState.resumed;
    final wasFg = _isAppForeground;
    _isAppForeground = isFg;

    if (!wasFg && isFg) {
      AppLogger.log('App foregrounded', tag: 'Dashboard');
      unawaited(DriverLocationSync.syncDeviceLocationIntoUserModel());
      // Flush any batched background locations immediately
      if (_pendingUpdates.isNotEmpty) unawaited(_flushBatch());
      // Only re-check update once per session after the initial check
      if (_updateCheckedThisSession) _checkMandatoryUpdate();
    } else if (wasFg && !isFg) {
      AppLogger.log('App backgrounded', tag: 'Dashboard');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Mandatory update
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _checkMandatoryUpdate() async {
    try {
      await FireStoreUtils.getForceUpdateConfig();
      if (await isMandatoryUpdateRequired()) {
        AppLogger.log('Mandatory update required → MandatoryUpdateScreen', tag: 'Update');
        Get.offAll(const MandatoryUpdateScreen());
        return;
      }
      _updateCheckedThisSession = true;
    } catch (e) {
      AppLogger.log('Mandatory update check error: $e', tag: 'Update');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  User fetch
  // ══════════════════════════════════════════════════════════════════════

  Future<void> getUser() async {
    final userId = await LoginController.getFirebaseId();
    if (userId.isEmpty) return;

    try {
      // Uses the shared getDriverDetails cache (FireStoreUtils).
      final parsed = await FireStoreUtils.getUserProfile(userId);
      if (parsed != null) {
        userModel.value   = parsed;
        Constant.userModel = parsed;
        // AppLogger.log('User fetched: ${parsed.fullName()}', tag: 'Dashboard');
      }
    } catch (e) {
      AppLogger.log('getUser error: $e', tag: 'Dashboard');
    }

    // Start location tracking AFTER user data is loaded so isActive is known
    await _startLocationListener();
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Theme
  // ══════════════════════════════════════════════════════════════════════

  void _loadTheme() {
    isDarkMode.value = Preferences.getString(Preferences.themKey);
    isDarkModeSwitch.value = isDarkMode.value == 'Dark';
  }

  // kept for external calls (DrawerView still calls getThem())
  void getThem() => _loadTheme();

  // ══════════════════════════════════════════════════════════════════════
  //  Driver order sync
  // ══════════════════════════════════════════════════════════════════════

  // Future<void> updateDriverOrder() async {
  //   try {
  //     final res = await http.get(
  //       Uri.parse('${Constant.baseUrl}update-driver-order'),
  //       //Uri.parse('http://187.127.156.147:8084/api/driver/fetchEarnings?driverId=1&date=29%2F05%2F2026'),
  //       headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
  //     ).timeout(const Duration(seconds: 15));
  //
  //     if (res.statusCode == 200) {
  //       final data = jsonDecode(res.body);
  //       final rawOrders = data['orders'] as List? ?? [];
  //       final orders = <OrderModel>[];
  //
  //       for (final element in rawOrders) {
  //         try {
  //           orders.add(OrderModel.fromJson(element as Map<String, dynamic>));
  //         } catch (e) {
  //           AppLogger.log('updateDriverOrder parse error [${element['id']}]: $e', tag: 'Dashboard');
  //         }
  //       }
  //
  //       for (final order in orders) {
  //         order.triggerDelivery = Timestamp.now();
  //         await FireStoreUtils.setOrder(order);
  //       }
  //       AppLogger.log('updateDriverOrder: synced ${orders.length} orders', tag: 'Dashboard');
  //     } else {
  //       AppLogger.log('updateDriverOrder HTTP ${res.statusCode}', tag: 'Dashboard');
  //     }
  //   } on TimeoutException {
  //     AppLogger.log('updateDriverOrder timed out', tag: 'Dashboard');
  //   } catch (e) {
  //     AppLogger.log('updateDriverOrder error: $e', tag: 'Dashboard');
  //   }
  // }

  // ══════════════════════════════════════════════════════════════════════
  //  Location listener — single subscription, never leaked
  // ══════════════════════════════════════════════════════════════════════

  /// Call once from getUser() after user data is loaded.
  /// Also called from DrawerView when driver toggles isActive ON.
  Future<void> _startLocationListener() async {
    // Guard: never create a second subscription
    if (_locationListenerActive) {
      AppLogger.log('Location listener already active', tag: 'Location');
      return;
    }

    try {
      var permission = await _location.hasPermission();
      if (permission != loc.PermissionStatus.granted) {
        permission = await _location.requestPermission();
      }
      if (permission != loc.PermissionStatus.granted) {
        AppLogger.log('Location permission denied', tag: 'Location');
        return;
      }

      await _location.enableBackgroundMode(enable: true);
      await _location.changeSettings(
        accuracy: loc.LocationAccuracy.high,
        distanceFilter: 30, // OS-level pre-filter; fine-grained throttle in _onLocation
      );

      _locationSubscription = _location.onLocationChanged.listen(
        _onLocation,
        onError: (e) => AppLogger.log('Location stream error: $e', tag: 'Location'),
      );
      _locationListenerActive = true;
      AppLogger.log('Location listener started', tag: 'Location');
    } catch (e) {
      AppLogger.log('_startLocationListener error: $e', tag: 'Location');
    }
  }

  /// Public: called from DrawerView when user toggles isActive ON
  Future<void> updateCurrentLocation() async {
    await _startLocationListener();
  }

  void _stopLocationListener() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationListenerActive = false;
    AppLogger.log('Location listener stopped', tag: 'Location');
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Location event handler
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLocation(loc.LocationData data) async {
    // Always update Constant so other widgets can read fresh coords
    Constant.locationDataFinal = data;

    // Do not coerce null GPS to 0,0 — that breaks distance/charge math.
    final newLoc = UserLocation(
      latitude: data.latitude,
      longitude: data.longitude,
    );

    // ── Immediate HomeController update (smooth marker + camera) ──────
    // This runs on EVERY location event (no throttle) so the bike icon
    // glides smoothly, independently of Firestore write frequency.
    _updateHomeControllerImmediate(newLoc, data.heading);

    // ── Throttled & coalesced Firestore write ───────────────────────
    if (!_shouldWrite(newLoc)) return;
    // Always enqueue (foreground + background) so writes are coalesced.
    _queueForBatch(newLoc, data.heading);
  }

  void _updateHomeControllerImmediate(UserLocation loc, double? heading) {
    try {
      if (!Get.isRegistered<HomeController>()) return;
      final home = Get.find<HomeController>();
      home.driverModel.value.location = loc;
      // if (heading != null) home.driverModel.value.rotation = heading;

      if (loc.latitude != null && loc.longitude != null) {
        try {
          final driverLat = loc.latitude!;
          final driverLng = loc.longitude!;
          home.driverLatLng.value =
              LatLng(driverLat, driverLng) as LatLng?;
        } catch (_) {
          home.updateDriverMarkerPosition(updateCamera: true);
        }
        home.notifyDriverLocationUpdated();
      }

      // Debounced route/direction update
      home.changeData();
    } catch (e) {
      AppLogger.log('HomeController update error: $e', tag: 'Location');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Throttle logic
  // ══════════════════════════════════════════════════════════════════════

  bool _shouldWrite(UserLocation newLoc) {
    final minDist = _isAppForeground ? _fgMinMeters : _bgMinMeters;
    final minTime = _isAppForeground ? _fgMinTime   : _bgMinTime;
    final now     = DateTime.now();

    // First write always allowed
    if (_lastThrottleLocation == null || _lastThrottleTime == null) return true;

    final dist = _distance(_lastThrottleLocation!, newLoc);
    if (dist < minDist) {
      AppLogger.log(
        'Write skipped — dist ${dist.toStringAsFixed(1)}m < ${minDist}m',
        tag: 'Location',
      );
      return false;
    }

    final elapsed = now.difference(_lastThrottleTime!);
    if (elapsed < minTime) {
      AppLogger.log(
        'Write skipped — elapsed ${elapsed.inSeconds}s < ${minTime.inSeconds}s',
        tag: 'Location',
      );
      return false;
    }

    return true;
  }

  double _distance(UserLocation a, UserLocation b) =>
      geolocator.Geolocator.distanceBetween(
        a.latitude  ?? 0.0,
        a.longitude ?? 0.0,
        b.latitude  ?? 0.0,
        b.longitude ?? 0.0,
      );

  // ══════════════════════════════════════════════════════════════════════
  //  Firestore write
  // ══════════════════════════════════════════════════════════════════════

  // Future<void> _writeToFirestore(UserLocation newLoc, double? heading) async {
  //   try {
  //     final currentUser = userModel.value;
  //     if (currentUser.isActive != true) return;
  //
  //     currentUser.location = newLoc;
  //     // if (heading != null) currentUser.rotation = heading;
  //     Constant.userModel = currentUser;
  //
  //     // Avoid read-before-write by using in-memory user model.
  //     // final ok = await FireStoreUtils.updateUserWithoutWalletDelivery(currentUser);
  //     if (ok) {
  //       PerfTelemetry.inc('location_writes');
  //     } else {
  //       PerfTelemetry.inc('location_write_failures');
  //     }
  //
  //     _lastWrittenLocation = newLoc;
  //     _lastWrittenTime     = DateTime.now();
  //
  //     // Notify reactive listeners that the in-memory user model mutated.
  //     userModel.refresh();
  //     DriverLocationSync.afterLocationAppliedToUserModel?.call();
  //
  //     AppLogger.log(
  //       'Firestore write — '
  //           'lat: ${(newLoc.latitude ?? 0.0).toStringAsFixed(6)}, '
  //           'lng: ${(newLoc.longitude ?? 0.0).toStringAsFixed(6)}, '
  //           'mode: ${_isAppForeground ? "fg" : "bg"}',
  //       tag: 'Location',
  //     );
  //   } catch (e) {
  //     AppLogger.log('_writeToFirestore error: $e', tag: 'Location');
  //   }
  // }

  // ══════════════════════════════════════════════════════════════════════
  //  Background batch
  // ══════════════════════════════════════════════════════════════════════

  void _queueForBatch(UserLocation loc, double? heading) {
    // Advance throttle watermark immediately so multiple location events
    // before the next flush don't enqueue extra writes.
    _lastThrottleLocation = loc;
    _lastThrottleTime = DateTime.now();

    _pendingUpdates.add(_LocationWrite(loc: loc, heading: heading));

    _batchTimer ??= Timer(_batchDelay, _flushBatch);

    if (_pendingUpdates.length >= _maxBatch) unawaited(_flushBatch());
  }

  Future<void> _flushBatch() async {
    _batchTimer?.cancel();
    _batchTimer = null;

    if (_pendingUpdates.isEmpty) return;

    // Use most recent location from batch
    final latest = _pendingUpdates.last;
    _pendingUpdates.clear();

    // await _writeToFirestore(latest.loc, latest.heading);
  }
}

class _LocationWrite {
  final UserLocation loc;
  final double? heading;

  const _LocationWrite({
    required this.loc,
    required this.heading,
  });
}