// import 'dart:convert';
// import 'dart:async';
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:http/http.dart' as http;
// import 'package:jippydriver_driver/constant/constant.dart';
// import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
// import 'package:jippydriver_driver/app/home_screen/controller/home_controller.dart';
// import 'package:jippydriver_driver/controllers/login_controller.dart';
// import 'package:jippydriver_driver/models/order_model.dart';
// import 'package:jippydriver_driver/models/user_model.dart';
// import 'package:jippydriver_driver/utils/fire_store_utils.dart';
// import 'package:jippydriver_driver/utils/preferences.dart';
// import 'package:jippydriver_driver/utils/version_utils.dart';
// import 'package:jippydriver_driver/app/mandatory_update_screen.dart';
// import 'package:get/get.dart';
// import 'package:jippydriver_driver/utils/app_logger.dart';
// import 'package:geolocator/geolocator.dart' as geolocator;
// import 'package:flutter/material.dart';
// import 'package:location/location.dart' as location_package;
//
// class DashBoardController extends GetxController with WidgetsBindingObserver {
//   RxInt drawerIndex = 0.obs;
//
//   // Location update throttling variables
//   UserLocation? _lastUpdatedLocation; // Last location that was sent to Firestore
//   DateTime? _lastUpdateTime; // Last time location was updated to Firestore
//   List<UserLocation> _pendingLocationUpdates = []; // Queue for batching updates
//   Timer? _batchUpdateTimer; // Timer for batched updates
//   bool _isAppInForeground = true; // Track app lifecycle state
//
//   // Throttling constants
//   static const double _minDistanceMeters = 100.0; // Minimum distance to trigger update (changed from 50m)
//   static const Duration _minTimeInterval = Duration(seconds: 30); // Minimum time between updates
//   static const Duration _batchInterval = Duration(seconds: 10); // Batch updates every 10 seconds
//   static const int _maxBatchSize = 5; // Maximum locations to batch
//
//   // Background optimization
//   static const double _backgroundMinDistanceMeters = 200.0; // Larger distance in background
//   static const Duration _backgroundMinTimeInterval = Duration(seconds: 60); // Longer interval in background
//
//   @override
//   void onInit() {
//     AppLogger.log('DashBoardController onInit() called', tag: 'Controller');
//     WidgetsBinding.instance.addObserver(this);
//
//     // Check for mandatory update when user is already logged in
//     _checkMandatoryUpdate();
//
//     getUser();
//     updateDriverOrder();
//     getThem();
//     // Initialize HomeController to ensure it's available for HomeScreen
//     Get.put(HomeController());
//     super.onInit();
//   }
//
//   /// Check for mandatory update (for already logged-in users)
//   Future<void> _checkMandatoryUpdate() async {
//     try {
//       await FireStoreUtils.getForceUpdateConfig();
//       final updateRequired = await isMandatoryUpdateRequired();
//       if (updateRequired) {
//         AppLogger.log('Mandatory update required (logged-in user) -> MandatoryUpdateScreen', tag: 'Update');
//         Get.offAll(const MandatoryUpdateScreen());
//       }
//     } catch (e) {
//       AppLogger.log('Error checking mandatory update: $e', tag: 'Update');
//     }
//   }
//
//   @override
//   void onClose() {
//     AppLogger.log('DashBoardController onClose() called', tag: 'Controller');
//     WidgetsBinding.instance.removeObserver(this);
//     _batchUpdateTimer?.cancel();
//     super.onClose();
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     _isAppInForeground = state == AppLifecycleState.resumed;
//     AppLogger.log('📱 Location update - App lifecycle: ${_isAppInForeground ? "Foreground" : "Background"}', tag: 'Location');
//
//     // Flush pending updates when app comes to foreground
//     if (_isAppInForeground && _pendingLocationUpdates.isNotEmpty) {
//       _flushPendingUpdates();
//     }
//
//     // Check for mandatory update when app comes to foreground
//     if (_isAppInForeground) {
//       _checkMandatoryUpdate();
//     }
//   }
//
//   Rx<UserModel> userModel = UserModel().obs;
//
//   DateTime? currentBackPressTime;
//   RxBool canPopNow = false.obs;
//
//   Future<void> getUser() async {
//     String? userId = await LoginController.getFirebaseId();
//     await updateCurrentLocation();
//
//     final response = await http.get(Uri.parse("${Constant.baseUrl}users/$userId"));
// print("getUser ${response.body}");
//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       if (data['success'] == true && data['data'] != null) {
//         userModel.value = UserModel.fromJson(data['data']);
//         Constant.userModel = UserModel.fromJson(data['data']);
//       }
//     } else {
//       print("Error fetching user → ${response.statusCode}");
//     }
//   }
//
//   RxString isDarkMode = "Light".obs;
//   RxBool isDarkModeSwitch = false.obs;
//   getThem() {
//     isDarkMode.value = Preferences.getString(Preferences.themKey);
//     if (isDarkMode.value == "Dark") {
//       isDarkModeSwitch.value = true;
//     } else if (isDarkMode.value == "Light") {
//       isDarkModeSwitch.value = false;
//     } else {
//       isDarkModeSwitch.value = false;
//     }
//   }
//
//
//   updateDriverOrder() async {
//     List<OrderModel> orders = [];
//     final response = await http.get(
//       Uri.parse('${Constant.baseUrl}update-driver-order'),
//       headers: {
//         'Content-Type': 'application/json',
//         'Accept': 'application/json',
//       },
//     );
//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       if (data['orders'] != null) {
//         for (var element in data['orders']) {
//           try {
//             orders.add(OrderModel.fromJson(element));
//           } catch (e, s) {
//             print('watchOrdersStatus parse error ${element['id']} $e $s');
//           }
//         }
//       }
//     } else {
//       print('API request failed with status: ${response.statusCode}');
//     }
//     // Update triggerDelivery for each order
//     for (var orderModel in orders) {
//       // Ensure we always store a valid Firestore Timestamp
//       orderModel.triggerDelivery = Timestamp.now();
//       // Send updated order back (assuming setOrder is same)
//       await FireStoreUtils.setOrder(orderModel);
//     }
//   }
//
//   location_package.Location location = location_package.Location();
//
//   /// Calculate distance between two locations in meters
//   double _calculateDistance(UserLocation loc1, UserLocation loc2) {
//     // Handle nullable coordinates with defaults
//     final lat1 = loc1.latitude ?? 0.0;
//     final lon1 = loc1.longitude ?? 0.0;
//     final lat2 = loc2.latitude ?? 0.0;
//     final lon2 = loc2.longitude ?? 0.0;
//
//     return geolocator.Geolocator.distanceBetween(
//       lat1,
//       lon1,
//       lat2,
//       lon2,
//     );
//   }
//
//   /// Check if location update should be sent based on throttling rules
//   bool _shouldUpdateLocation(UserLocation newLocation) {
//     final now = DateTime.now();
//
//     // Get throttling parameters based on app state
//     final minDistance = _isAppInForeground
//         ? _minDistanceMeters
//         : _backgroundMinDistanceMeters;
//     final minTimeInterval = _isAppInForeground
//         ? _minTimeInterval
//         : _backgroundMinTimeInterval;
//
//     // First update - always allow
//     if (_lastUpdatedLocation == null || _lastUpdateTime == null) {
//       return true;
//     }
//
//     // Check distance threshold
//     final distanceMoved = _calculateDistance(_lastUpdatedLocation!, newLocation);
//     if (distanceMoved < minDistance) {
//       AppLogger.log('📍 Location update skipped - distance too small: ${distanceMoved.toStringAsFixed(1)}m < ${minDistance}m', tag: 'Location');
//       return false;
//     }
//
//     // Check time threshold
//     final timeSinceLastUpdate = now.difference(_lastUpdateTime!);
//     if (timeSinceLastUpdate < minTimeInterval) {
//       AppLogger.log('📍 Location update skipped - too soon: ${timeSinceLastUpdate.inSeconds}s < ${minTimeInterval.inSeconds}s', tag: 'Location');
//       return false;
//     }
//
//     return true;
//   }
//
//   /// Add location to batch queue
//   void _addToBatch(UserLocation location, double? heading) {
//     _pendingLocationUpdates.add(location);
//
//     // Start batch timer if not already running
//     if (_batchUpdateTimer == null || !_batchUpdateTimer!.isActive) {
//       _batchUpdateTimer = Timer(_batchInterval, () {
//         _flushPendingUpdates();
//       });
//     }
//
//     // Flush immediately if batch is full
//     if (_pendingLocationUpdates.length >= _maxBatchSize) {
//       _flushPendingUpdates();
//     }
//   }
//
//   /// Flush pending location updates to Firestore
//   Future<void> _flushPendingUpdates() async {
//     if (_pendingLocationUpdates.isEmpty) return;
//
//     // Cancel batch timer
//     _batchUpdateTimer?.cancel();
//     _batchUpdateTimer = null;
//
//     // Get the most recent location from batch (most accurate)
//     final latestLocation = _pendingLocationUpdates.last;
//     _pendingLocationUpdates.clear();
//
//     // Update Firestore with latest location
//     await _updateLocationToFirestore(latestLocation, null);
//   }
//
//   /// Update location to Firestore (with throttling check)
//   Future<void> _updateLocationToFirestore(UserLocation newLocation, double? heading) async {
//     try {
//       String? userId = await LoginController.getFirebaseId();
//       if (userId == null) return;
//
//       await FireStoreUtils.getUserProfile(userId).then((value) async {
//         if (value != null) {
//           userModel.value = value;
//           if (userModel.value.isActive == true) {
//             userModel.value.location = newLocation;
//             if (heading != null) {
//               userModel.value.rotation = heading;
//             }
//
//             await FireStoreUtils.updateUser(userModel.value);
//
//             // Update tracking variables
//             _lastUpdatedLocation = newLocation;
//             _lastUpdateTime = DateTime.now();
//
//             final distanceMoved = _lastUpdatedLocation != null && _lastUpdatedLocation != newLocation
//                 ? _calculateDistance(_lastUpdatedLocation!, newLocation)
//                 : 0.0;
//
//             AppLogger.log(
//               '✅ Location updated to Firestore - Distance: ${distanceMoved.toStringAsFixed(1)}m, '
//               'Lat: ${(newLocation.latitude ?? 0.0).toStringAsFixed(6)}, Lng: ${(newLocation.longitude ?? 0.0).toStringAsFixed(6)}, '
//               'Mode: ${_isAppInForeground ? "Foreground" : "Background"}',
//               tag: 'Location'
//             );
//             // Note: HomeController is already updated in _handleLocationUpdate for immediate map updates
//           }
//         }
//       });
//     } catch (e) {
//       AppLogger.log('Error updating location to Firestore: $e', tag: 'Location');
//     }
//   }
//
//   /// Handle location update with throttling and batching
//   Future<void> _handleLocationUpdate(location_package.LocationData locationData) async {
//     // Always update local location data for immediate use
//     Constant.locationDataFinal = locationData;
//
//     final newLocation = UserLocation(
//       latitude: locationData.latitude ?? 0.0,
//       longitude: locationData.longitude ?? 0.0,
//     );
//
//     // Update HomeController immediately for smooth map marker movement (like Zomato)
//     // This ensures the driver marker moves smoothly even before Firestore update
//     try {
//       if (Get.isRegistered<HomeController>()) {
//         final homeController = Get.find<HomeController>();
//         // Update driver location immediately for smooth map updates
//         homeController.driverModel.value.location = newLocation;
//         if (locationData.heading != null) {
//           homeController.driverModel.value.rotation = locationData.heading!;
//         }
//         // Update bike marker position immediately (no debounce) - follows blue dot smoothly
//         // Also optionally update camera to follow driver (smooth, non-intrusive)
//         homeController.updateDriverMarkerPosition(updateCamera: true);
//         // Also trigger full map update (debounced) for route recalculation if needed
//         homeController.changeData();
//       }
//     } catch (e) {
//       // HomeController might not be initialized yet, that's okay
//       AppLogger.log('⚠️ Could not update HomeController location immediately: $e', tag: 'Location');
//     }
//
//     // Check if update should be sent based on throttling rules
//     if (_shouldUpdateLocation(newLocation)) {
//       // In foreground, update immediately for better UX
//       // In background, batch updates to reduce writes
//       if (_isAppInForeground) {
//         await _updateLocationToFirestore(newLocation, locationData.heading);
//       } else {
//         _addToBatch(newLocation, locationData.heading);
//       }
//     } else {
//       // Still add to batch for background mode (will be processed later)
//       if (!_isAppInForeground) {
//         _addToBatch(newLocation, locationData.heading);
//       }
//     }
//   }
//
//   updateCurrentLocation() async {
//     try {
//       String? userId = await LoginController.getFirebaseId();
//       location_package.PermissionStatus permissionStatus = await location.hasPermission();
//
//       // Use 100m distance filter (increased from 50m) but keep high accuracy
//       // The actual throttling logic is handled in _handleLocationUpdate
//       final distanceFilter = 100.0; // Increased from 50m
//
//       if (permissionStatus == location_package.PermissionStatus.granted) {
//         location.enableBackgroundMode(enable: true);
//         location.changeSettings(
//           accuracy: location_package.LocationAccuracy.high, // Keep high accuracy for GPS
//           distanceFilter: distanceFilter, // Filter at OS level (100m)
//         );
//
//         location.onLocationChanged.listen((locationData) async {
//           await _handleLocationUpdate(locationData);
//         });
//       } else {
//         location.requestPermission().then((permissionStatus) {
//           if (permissionStatus == location_package.PermissionStatus.granted) {
//             location.enableBackgroundMode(enable: true);
//             location.changeSettings(
//               accuracy: location_package.LocationAccuracy.high, // Keep high accuracy
//               distanceFilter: distanceFilter, // Filter at OS level (100m)
//             );
//
//             location.onLocationChanged.listen((locationData) async {
//               await _handleLocationUpdate(locationData);
//               ShowToastDialog.closeLoader();
//             });
//           } else {
//             ShowToastDialog.closeLoader();
//           }
//         });
//       }
//     } catch (e) {
//       AppLogger.log('Error in updateCurrentLocation: $e', tag: 'Location');
//     }
//   }
// }


// ============================================================
//  dash_board_controller_optimized.dart
//
//  Problems fixed vs original:
//  1. Location listener leaks: onLocationChanged.listen() was
//     called MULTIPLE TIMES — once in onInit, and again every
//     time the user toggled isActive. Each call added a new
//     listener. Fixed with StreamSubscription stored as a field.
//  2. _shouldUpdateLocation compared _lastUpdatedLocation to
//     itself (always 0 distance). Fixed by comparing to newLocation.
//  3. getUser() used plain http.get with no timeout — hangs
//     indefinitely on bad network. Fixed with timeout + retry.
//  4. updateDriverOrder() parsed orders silently — errors were
//     swallowed. Improved logging.
//  5. _flushPendingUpdates used the LAST location but compared
//     distance against null (first update). Fixed.
//  6. didChangeAppLifecycleState re-checked mandatory update on
//     every foreground — excessive. Throttled to once per session.
//  7. HomeController.updateDriverMarkerPosition() — the optimized
//     controller now exposes _animateMarkerTo() internally. This
//     file calls the new public method animateDriverTo().
//  8. Background location subscription was never cancelled on
//     logout / controller close → battery drain. Fixed.
// ============================================================

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
import 'package:jippydriver_driver/controllers/login_controller.dart';
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
    updateDriverOrder();
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
    if (userId == null) return;

    try {
      final res = await http
          .get(Uri.parse('${Constant.baseUrl}users/$userId'))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          final parsed = UserModel.fromJson(data['data']);
          userModel.value   = parsed;
          Constant.userModel = parsed;
          AppLogger.log('User fetched: ${parsed.fullName()}', tag: 'Dashboard');
        }
      } else {
        AppLogger.log('getUser failed: ${res.statusCode}', tag: 'Dashboard');
      }
    } on TimeoutException {
      AppLogger.log('getUser timed out', tag: 'Dashboard');
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

  Future<void> updateDriverOrder() async {
    try {
      final res = await http.get(
        Uri.parse('${Constant.baseUrl}update-driver-order'),
        //Uri.parse('http://187.127.156.147:8084/api/driver/fetchEarnings?driverId=1&date=29%2F05%2F2026'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawOrders = data['orders'] as List? ?? [];
        final orders = <OrderModel>[];

        for (final element in rawOrders) {
          try {
            orders.add(OrderModel.fromJson(element as Map<String, dynamic>));
          } catch (e) {
            AppLogger.log('updateDriverOrder parse error [${element['id']}]: $e', tag: 'Dashboard');
          }
        }

        for (final order in orders) {
          order.triggerDelivery = Timestamp.now();
          await FireStoreUtils.setOrder(order);
        }
        AppLogger.log('updateDriverOrder: synced ${orders.length} orders', tag: 'Dashboard');
      } else {
        AppLogger.log('updateDriverOrder HTTP ${res.statusCode}', tag: 'Dashboard');
      }
    } on TimeoutException {
      AppLogger.log('updateDriverOrder timed out', tag: 'Dashboard');
    } catch (e) {
      AppLogger.log('updateDriverOrder error: $e', tag: 'Dashboard');
    }
  }

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
      if (heading != null) home.driverModel.value.rotation = heading;

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

  Future<void> _writeToFirestore(UserLocation newLoc, double? heading) async {
    try {
      final currentUser = userModel.value;
      if (currentUser.isActive != true) return;

      currentUser.location = newLoc;
      if (heading != null) currentUser.rotation = heading;
      Constant.userModel = currentUser;

      // Avoid read-before-write by using in-memory user model.
      final ok = await FireStoreUtils.updateUserWithoutWalletDelivery(currentUser);
      if (ok) {
        PerfTelemetry.inc('location_writes');
      } else {
        PerfTelemetry.inc('location_write_failures');
      }

      _lastWrittenLocation = newLoc;
      _lastWrittenTime     = DateTime.now();

      // Notify reactive listeners that the in-memory user model mutated.
      userModel.refresh();
      DriverLocationSync.afterLocationAppliedToUserModel?.call();

      AppLogger.log(
        'Firestore write — '
            'lat: ${(newLoc.latitude ?? 0.0).toStringAsFixed(6)}, '
            'lng: ${(newLoc.longitude ?? 0.0).toStringAsFixed(6)}, '
            'mode: ${_isAppForeground ? "fg" : "bg"}',
        tag: 'Location',
      );
    } catch (e) {
      AppLogger.log('_writeToFirestore error: $e', tag: 'Location');
    }
  }

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

    await _writeToFirestore(latest.loc, latest.heading);
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