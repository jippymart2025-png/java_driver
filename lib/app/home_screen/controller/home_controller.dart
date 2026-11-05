import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/send_notification.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/app/auth_screen/controller/login_controller.dart';
import 'package:jippydriver_driver/models/driver_delivery_charge_model.dart';
import 'package:jippydriver_driver/models/order_model.dart';
import 'package:jippydriver_driver/models/today_dashboard_response_model.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/models/vendor_model.dart';
import 'package:jippydriver_driver/services/audio_player_service.dart';
import 'package:jippydriver_driver/services/api_cache_service.dart';
import 'package:jippydriver_driver/services/driver_delivery_charge_service.dart';
import 'package:jippydriver_driver/services/order_detail_service.dart';
import 'package:jippydriver_driver/services/order_workflow_service.dart';
import 'package:jippydriver_driver/services/http_client_service.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:jippydriver_driver/utils/common.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/utils/perf_telemetry.dart';
import 'package:jippydriver_driver/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as location;
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:typed_data';
import 'package:location_platform_interface/location_platform_interface.dart';

// ---------------------------------------------------------------------------
//  Lightweight cancel token
// ---------------------------------------------------------------------------
class CancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() => _isCancelled = true;
  void reset()  => _isCancelled = false;
}

// ---------------------------------------------------------------------------
//  HomeController
// ---------------------------------------------------------------------------
class HomeController extends GetxController {

  // ── UI toggle ─────────────────────────────────────────────────────────
  final RxBool arrowDrop = false.obs;
  void changeArrow() => arrowDrop.value = !arrowDrop.value;

  // ── Charge Rx fields ──────────────────────────────────────────────────
  final RxDouble driverToRestaurantDistance   = 0.0.obs;
  final RxDouble restaurantToCustomerDistance = 0.0.obs;
  final RxDouble driverToRestaurantDuration   = 0.0.obs;
  final RxDouble restaurantToCustomerDuration = 0.0.obs;
  final RxDouble driverToRestaurantCharge     = 0.0.obs;
  final RxDouble restaurantToCustomerCharge   = 0.0.obs;
  final RxDouble totalCalculatedCharge        = 0.0.obs;
  final RxDouble surgeFee                     = 0.0.obs;
  final RxDouble creditedBonus = 0.0.obs;
  final RxDouble toPayAmount                  = 0.0.obs;
  final RxBool isNavigatingToMap              = false.obs;

  // ── Driver delivery charges (Java backend) ────────────────────────────
  /// Full response of `getDriverDeliveryChargesForOrder` for the order that
  /// is currently shown in the accept/reject popup. This is the source of
  /// truth for the popup: outlet/customer details, distances, charges, tips,
  /// COD availability and order total.
  final Rxn<DriverDeliveryChargeModel> activeDeliveryCharges =
      Rxn<DriverDeliveryChargeModel>();

  String?   _deliveryChargesOrderId;
  DateTime? _deliveryChargesFetchedAt;
  final Set<String> _deliveryChargesInFlight = <String>{};
  String?   _deliveryChargesFailureOrderId;
  DateTime? _deliveryChargesRetryAt;
  static const Duration _deliveryChargesTtl = Duration(seconds: 30);
  static const Duration _deliveryChargesFailureTtl = Duration(seconds: 60);

  /// Order id returned by `getActiveOrderByDriverId`. When present it is the
  /// authoritative order for this driver, even if the local driver profile
  /// lists are temporarily out of date.
  String? _serverActiveOrderId;


  // ── Core observables ──────────────────────────────────────────────────
  final Rx<OrderModel> currentOrder = OrderModel().obs;
  final Rx<OrderModel> orderModel   = OrderModel().obs;
  final Rx<UserModel>  driverModel  = UserModel().obs;
  final RxBool isLoading = true.obs;
  final RxBool isChange  = false.obs;

  // ── Today dashboard ───────────────────────────────────────────────────
  final Rxn<TodayDashboardData> todayDashboard = Rxn<TodayDashboardData>();
  final RxBool todayDashboardLoading = false.obs;
  DateTime? _todayDashboardLastFetchAt;

  final Rx<LatLng?> driverLatLng = Rx<LatLng?>(null);

  // ── Map ───────────────────────────────────────────────────────────────
  GoogleMapController? mapController;
  flutterMap.MapController osmMapController = flutterMap.MapController();

  final RxMap<PolylineId, Polyline> polyLines   = <PolylineId, Polyline>{}.obs;
  final RxMap<String, Marker>       markers     = <String, Marker>{}.obs;
  final RxList<flutterMap.Marker>   osmMarkers  = <flutterMap.Marker>[].obs;
  final RxList<location.LatLng>     routePoints = <location.LatLng>[].obs;

  BitmapDescriptor? departureIcon;
  BitmapDescriptor? destinationIcon;
  BitmapDescriptor? taxiIcon;

  // ── Marker animation ──────────────────────────────────────────────────
  LatLng? _markerAnimStart;
  LatLng? _markerAnimTarget;
  Timer?  _markerAnimTimer;
  static const Duration _markerAnimDuration = Duration(milliseconds: 300);
  static const int      _markerAnimSteps    = 10;

  // ── Camera ────────────────────────────────────────────────────────────
  bool    hasInitialCameraSet = false;
  bool    _shouldFollowDriver = true;
  LatLng? _lastCameraPos;
  static const double _cameraFollowDistance = 10.0;

  // ── Route cache ───────────────────────────────────────────────────────
  String?       _lastRouteCacheKey;
  List<LatLng>? _cachedPolyline;
  List<LatLng>? _cachedSimplified;
  DateTime?     _lastRouteCalcTime;
  LatLng?       _lastRouteOrigin;
  bool          _routeCallInFlight = false;

  static const Duration _routeCacheDuration  = Duration(minutes: 3);
  static const double   _routeRecalcDistance = 60.0;
  static const double   _coordPrecision      = 0.005;
  static const int      _maxDisplayPoints    = 80;

  // ── Polling ───────────────────────────────────────────────────────────
  Timer?   _pollTimer;
  bool     _isPolling       = false;
  bool     _isRefreshing    = false;
  Duration _pollInterval    = const Duration(seconds: 5);
  int      _noOrderCount    = 0;
  bool     _isAppForeground = true;
  bool     _isConnected     = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  String? _lastETag;
  String? _lastModified;

  // ── Status tracking ───────────────────────────────────────────────────
  String?   _lastKnownStatus;
  DateTime? _lastStatusChangeTime;
  static const Duration _statusCooldown = Duration(seconds: 5);

  // ── Completed-order guard ─────────────────────────────────────────────
  static const Duration _completedRetention = Duration(minutes: 5);
  final Map<String, DateTime> _recentlyCompleted = {};

  // ── Notification dedup ────────────────────────────────────────────────
  final Set<String>           _notifiedOrderIds           = {};
  final Map<String, DateTime> _recentlyHandledOrderMutes = {};
  static const Duration _handledOrderMuteTtl = Duration(seconds: 20);
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // ── Vendor cache ──────────────────────────────────────────────────────
  final Map<String, VendorModel> _vendorCache     = {};
  final Map<String, DateTime>    _vendorCacheTime = {};
  static const Duration _vendorCacheTTL = Duration(hours: 2);

  // ── OSM ───────────────────────────────────────────────────────────────
  bool _osmMapReady = false;
  void setOsmMapReady(bool v) => _osmMapReady = v;

  Rx<location.LatLng> source      = location.LatLng(0, 0).obs;
  Rx<location.LatLng> current     = location.LatLng(0, 0).obs;
  Rx<location.LatLng> destination = location.LatLng(0, 0).obs;

  // ── Debounce ──────────────────────────────────────────────────────────
  Timer? _changeDataDebounce;
  static const Duration _changeDataDelay = Duration(milliseconds: 150);

  // ── Guards ────────────────────────────────────────────────────────────
  // ── Guards ────────────────────────────────────────────────────────────
  bool      _isAcceptingOrder            = false;
  bool      _isRejectingOrder            = false;
  bool get  isAcceptingOrder             => _isAcceptingOrder;
  Timer?    _chargesRecalcDebounce;
  DateTime? _lastGetOrderTime;
  static const Duration _minOrderInterval = Duration(seconds: 2);

  // ── Accept fail cooldown ──────────────────────────────────────────────
  DateTime? _lastAcceptFailAt;
  static const Duration _acceptFailCooldown = Duration(seconds: 3);

  // ── Polyline points ───────────────────────────────────────────────────
  Rx<PolylinePoints> polylinePoints =
      PolylinePoints(apiKey: Constant.mapAPIKey.isNotEmpty ? Constant.mapAPIKey : '').obs;

  void updatePolylinePoints() {
    polylinePoints.value =
        PolylinePoints(apiKey: Constant.mapAPIKey.isNotEmpty ? Constant.mapAPIKey : '');
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Lifecycle
  // ══════════════════════════════════════════════════════════════════════

  @override
  void onInit() {
    _getArguments();
    _setIcons();
    _initLocalNotifications();
    _initConnectivity();
    getDriver();
    // unawaited(_warmUpDriverCharges());
    ensureTodayDashboardLoaded();
    _startPolling();
    super.onInit();
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    _changeDataDebounce?.cancel();
    _markerAnimTimer?.cancel();
    _chargesRecalcDebounce?.cancel();
    _connectivitySub?.cancel();
    _tryCleanupCache();
    super.onClose();
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Today dashboard
  // ══════════════════════════════════════════════════════════════════════


  // ══════════════════════════════════════════════════════════════════════
  //  Accept precondition — ensure usable driver coordinates
  // ══════════════════════════════════════════════════════════════════════

  /// Guarantees that the driver has usable GPS coordinates before the
  /// ACCEPT API is called.
  ///
  /// The Java backend rejects the accept request with
  /// "Driver latitude or longitude unavailable" when the coords are
  /// missing, which used to surface as the misleading
  /// "Order accepted by another driver" snackbar.
  ///
  /// Resolution order matches [_resolveDriverLatLngForCharges]:
  /// 1. `driverLatLng`         (live position stream)
  /// 2. `Constant.locationDataFinal`
  /// 3. `driverModel.value.location`
  /// 4. `Utils.getCurrentLocation()`  (fresh GPS fix)
  /// 5. `Geolocator.getLastKnownPosition()`  (last resort)
  Future<bool> _ensureDriverLocation() async {
    if (_hasUsableDriverLocation()) return true;

    AppLogger.log(
      'Driver location missing on accept — attempting fresh fix',
      tag: 'OrderWorkflow',
    );

    // Fresh GPS fix.
    try {
      final pos = await Utils.getCurrentLocation();
      if (pos != null &&
          _isUsableDriverCoord(pos.latitude, pos.longitude)) {
        driverModel.value.location = UserLocation(
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
        driverLatLng.value = LatLng(pos.latitude, pos.longitude);
        Constant.locationDataFinal = pos as LocationData?;
        driverModel.refresh();

        // Persist so the backend also sees fresh coordinates.
        try {
          await FireStoreUtils.updateUser(driverModel.value);
        } catch (e) {
          AppLogger.log(
            '_ensureDriverLocation: updateUser failed: $e',
            tag: 'OrderWorkflow',
          );
        }

        AppLogger.log(
          '_ensureDriverLocation: refreshed via Utils '
              '(lat=${pos.latitude}, lng=${pos.longitude})',
          tag: 'OrderWorkflow',
        );
        return true;
      }
    } catch (e) {
      AppLogger.log(
        '_ensureDriverLocation: Utils.getCurrentLocation error: $e',
        tag: 'OrderWorkflow',
      );
    }

    // Last known fix from the platform.
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          _isUsableDriverCoord(last.latitude, last.longitude)) {
        driverModel.value.location = UserLocation(
          latitude: last.latitude,
          longitude: last.longitude,
        );
        driverLatLng.value = LatLng(last.latitude, last.longitude);
        driverModel.refresh();

        try {
          await FireStoreUtils.updateUser(driverModel.value);
        } catch (_) {}

        AppLogger.log(
          '_ensureDriverLocation: refreshed via getLastKnownPosition '
              '(lat=${last.latitude}, lng=${last.longitude})',
          tag: 'OrderWorkflow',
        );
        return true;
      }
    } catch (e) {
      AppLogger.log(
        '_ensureDriverLocation: getLastKnownPosition error: $e',
        tag: 'OrderWorkflow',
      );
    }

    AppLogger.log(
      'Driver location still unavailable after refresh',
      tag: 'OrderWorkflow',
    );
    return false;
  }

  /// True if any of the three location sources has usable coordinates.
  bool _hasUsableDriverLocation() {
    final dl = driverLatLng.value;
    if (_isUsableDriverCoord(dl?.latitude, dl?.longitude)) return true;

    final lf = Constant.locationDataFinal;
    if (_isUsableDriverCoord(lf?.latitude, lf?.longitude)) return true;

    final loc = driverModel.value.location;
    if (_isUsableDriverCoord(loc?.latitude, loc?.longitude)) return true;

    return false;
  }

  void ensureTodayDashboardLoaded() {
    final last = _todayDashboardLastFetchAt;
    if (todayDashboardLoading.value) return;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 20)) return;
    fetchTodayDashboard();
  }

  Future<void> fetchTodayDashboard({bool forceRefresh = false}) async {
    final driverId =
    (driverModel.value.id?.toString().trim().isNotEmpty ?? false)
        ? driverModel.value.id!.toString().trim()
        : (Constant.userModel?.id?.toString().trim() ?? '');

    if (driverId.isEmpty) return;

    // todayDashboardLoading.value = true;

    try {
    final today = DateTime.now();

    final date =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final url = Uri.parse(
      '${Constant.baseUrl}driver/fetchEarnings?driverId=$driverId&date=$date',
    );

      debugPrint("FINAL DRIVER ID = $driverId");
      debugPrint("URL = $url");

      final httpClient = HttpClientService();

      final response = await httpClient.get(
        url,
        headers: await getHeaders(),
        cacheStrategy: CacheStrategy.custom,
        customTTL: const Duration(seconds: 20),
        useCache: true,
        forceRefresh: forceRefresh,
        timeout: const Duration(seconds: 12),
        enableRetry: true,
      );

      debugPrint("STATUS CODE : ${response.statusCode}");
      debugPrint("RESPONSE BODY : ${response.body}");

      if (response.statusCode == 200) {
        if (response.body.startsWith('<')) return;

        final raw = jsonDecode(response.body);

        if (raw is Map<String, dynamic>) {
          debugPrint("RAW JAVA RESPONSE : $raw");

          final dashboardData = TodayDashboardData.fromJson(raw);

          todayDashboard.value = dashboardData;
          todayDashboard.refresh();

          debugPrint(
            "UPDATED -> Orders: ${dashboardData.totalOrdersToday}",
          );

          debugPrint(
            "UPDATED -> Earnings: ${dashboardData.totalEarningsToday}",
          );

          debugPrint(
            "UPDATED -> Incentive Bonus: ${dashboardData.driverIncentiveBonus}",
          );

          _todayDashboardLastFetchAt = DateTime.now();
        }
      } else {
        debugPrint("API ERROR : ${response.statusCode}");
        debugPrint("API BODY : ${response.body}");
      }
    } catch (e, stackTrace) {
      debugPrint("ERROR : $e");
      debugPrint("STACKTRACE : $stackTrace");

      AppLogger.log(
        'Today dashboard fetch failed: $e',
        tag: 'API',
      );
    } finally {
      todayDashboardLoading.value = false;
    }
  }
  // ══════════════════════════════════════════════════════════════════════
  //  Init helpers
  // ══════════════════════════════════════════════════════════════════════

  void _getArguments() {
    final args = Get.arguments;
    if (args != null) orderModel.value = args['orderModel'];
  }

  Future<void> _setIcons() async {
    if (Constant.selectedMapType == 'google') {
      final dep    = await Constant().getBytesFromAsset(
          'assets/images/location_black3x.png', 100);
      final dest   = await Constant().getBytesFromAsset(
          'assets/images/location_orange3x.png', 100);
      final driver = await Constant().getBytesFromAsset(
          'assets/images/food_delivery.png', 120);
      departureIcon   = BitmapDescriptor.fromBytes(dep);
      destinationIcon = BitmapDescriptor.fromBytes(dest);
      taxiIcon        = BitmapDescriptor.fromBytes(driver);
    }
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings();
    await _localNotifications.initialize(
        const InitializationSettings(android: android, iOS: ios));
  }

  void _initConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final was = _isConnected;
      _isConnected = results.any((r) => r != ConnectivityResult.none);
      if (!was && _isConnected) {
        AppLogger.log('Network restored', tag: 'Poll');
        if (!_isPolling) _startPolling();
      } else if (was && !_isConnected) {
        AppLogger.log('Network lost', tag: 'Poll');
        _pollTimer?.cancel();
        _isPolling = false;
      }
    });
    Connectivity().checkConnectivity().then((r) {
      _isConnected = r.any((x) => x != ConnectivityResult.none);
    });
  }

  void _tryCleanupCache() {
    try { ApiCacheService().forceCleanup(); } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════
  //  App lifecycle
  // ══════════════════════════════════════════════════════════════════════

  void updateAppLifecycleState(AppLifecycleState state) {
    final wasFg = _isAppForeground;
    _isAppForeground = state == AppLifecycleState.resumed;
    if (wasFg && !_isAppForeground) {
      _tryCleanupCache();
      if (_isPolling) _restartPolling(const Duration(seconds: 30));
    } else if (!wasFg && _isAppForeground) {
      _noOrderCount = 0;
      if (_isPolling) _restartPolling(const Duration(seconds: 5));
      forceRefreshOrders();
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Marker animation
  // ══════════════════════════════════════════════════════════════════════

  void _animateMarkerTo(LatLng target) {
    if (taxiIcon == null) return;
    _markerAnimTimer?.cancel();

    final start = _markerAnimStart ?? target;
    _markerAnimStart  = start;
    _markerAnimTarget = target;

    int step = 0;
    _markerAnimTimer = Timer.periodic(
      Duration(
          milliseconds:
          _markerAnimDuration.inMilliseconds ~/ _markerAnimSteps),
          (t) {
        step++;
        final progress = step / _markerAnimSteps;
        final curved =
        Curves.easeOut.transform(progress.clamp(0.0, 1.0));
        final pos = LatLng(
          _lerpD(start.latitude,  target.latitude,  curved),
          _lerpD(start.longitude, target.longitude, curved),
        );
        _writeDriverMarker(pos);
        driverLatLng.value = pos;
        if (step >= _markerAnimSteps) {
          t.cancel();
          _markerAnimStart = target;
        }
      },
    );
  }

  void _writeDriverMarker(LatLng pos) {
    if (taxiIcon == null) return;
    final existing = markers.value['Driver'];
    if (existing != null) {
      final p = existing.position;
      if ((p.latitude  - pos.latitude).abs()  < 1e-7 &&
          (p.longitude - pos.longitude).abs() < 1e-7) return;
    }
    final updated = Map<String, Marker>.from(markers.value);
    updated['Driver'] = Marker(
      markerId: const MarkerId('Driver'),
      position: pos,
      icon: taxiIcon!,
      // rotation: (driverModel.value.rotation ?? 0.0).toDouble(),
      anchor: const Offset(0.5, 0.5),
    );
    markers.value = updated;
  }

  static double _lerpD(double a, double b, double t) => a + (b - a) * t;

  void updateDriverMarkerPosition({bool updateCamera = false}) {
    if (driverModel.value.location?.latitude  == null ||
        driverModel.value.location?.longitude == null ||
        taxiIcon == null ||
        Constant.selectedMapType == 'osm') return;

    final target = LatLng(
      driverModel.value.location!.latitude!,
      driverModel.value.location!.longitude!,
    );

    if (_markerAnimStart != null &&
        _distanceBetween(_markerAnimStart!, target) < 1.0) {
      if (updateCamera) _smoothCameraFollow(target);
      return;
    }

    _animateMarkerTo(target);
    if (updateCamera) _smoothCameraFollow(target);
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Camera
  // ══════════════════════════════════════════════════════════════════════

  void setCameraFollowDriver(bool v) => _shouldFollowDriver = v;

  void _smoothCameraFollow(LatLng pos) {
    if (mapController == null || !_shouldFollowDriver) return;
    if (_lastCameraPos != null &&
        _distanceBetween(_lastCameraPos!, pos) < _cameraFollowDistance) return;
    mapController!.animateCamera(CameraUpdate.newLatLng(pos));
    _lastCameraPos = pos;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Polling
  // ══════════════════════════════════════════════════════════════════════

  void _startPolling() {
    if (_isPolling || !_isConnected) return;
    _isPolling    = true;
    _noOrderCount = 0;
    _pollInterval = _isAppForeground
        ? const Duration(seconds: 5)
        : const Duration(seconds: 20);
    _schedulePoll();
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _onPollTick());
  }

  Future<void> _onPollTick() async {
    if (_isRefreshing || !_isConnected) return;
    try {
      PerfTelemetry.inc('poll_requests');
      await refreshHomeScreen();
      final hasOrders =
          (driverModel.value.orderRequestData?.isNotEmpty  ?? false) ||
              (driverModel.value.inProgressOrderID?.isNotEmpty ?? false) ||
              currentOrder.value.id != null;
      final desired = _computePollInterval(hasOrders);
      if (desired != _pollInterval) {
        _pollInterval = desired;
        _schedulePoll();
      }
    } catch (e) {
      AppLogger.log('Poll error: $e', tag: 'Poll');
    }
  }

  Duration _computePollInterval(bool hasOrders) {
    if (hasOrders) {
      _noOrderCount = 0;
      return _isAppForeground
          ? const Duration(seconds: 5)
          : const Duration(seconds: 10);
    }
    _noOrderCount++;
    final base = _noOrderCount == 1 ? 10 : _noOrderCount == 2 ? 20 : 30;
    final secs = _isAppForeground ? base : (base * 2).clamp(30, 60);
    return Duration(seconds: secs);
  }

  void _restartPolling(Duration interval) {
    if (!_isPolling) return;
    _pollInterval = interval;
    _schedulePoll();
  }

  Future<void> forceRefreshOrders() async {
    if (_isRefreshing) return;
    await Future.wait<Object?>([
      refreshHomeScreen().catchError((_, __) => false),
      fetchTodayDashboard(forceRefresh: true).catchError((_, __) => null),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Order status helpers
  // ══════════════════════════════════════════════════════════════════════

  void resetStatusTracking() {
    _lastKnownStatus      = null;
    _lastStatusChangeTime = null;
  }

  void _notifyOrderUiChanged({bool refreshOrder = true}) {
    PerfTelemetry.inc('home_order_ui_refreshes');
    if (refreshOrder) currentOrder.refresh();
  }

  void markOrderAsCompleted(String? id) {
    if (id == null || id.isEmpty) return;
    _recentlyCompleted[id] = DateTime.now();
  }

  void _cleanupCompletedIds() {
    final cutoff = DateTime.now().subtract(_completedRetention);
    _recentlyCompleted.removeWhere((_, t) => t.isBefore(cutoff));
  }

  void _filterCompletedFromUser(UserModel m) {
    _cleanupCompletedIds();
    if (_recentlyCompleted.isEmpty) return;
    final ids = _recentlyCompleted.keys.toSet();
    m.inProgressOrderID.removeWhere((id) => ids.contains(id.toString()));
    m.orderRequestData.removeWhere((id) => ids.contains(id?.toString()));
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Charge calculations
  // ══════════════════════════════════════════════════════════════════════

  /// Loads the authoritative driver delivery charges from the Java backend.
  ///
  /// The call needs the driver's current GPS coordinates, so it is executed
  /// lazily (after the order popup is already visible) and cached per order.
  Future<void> _loadDriverDeliveryCharges(
    String orderId, {
    bool forceRefresh = false,
  }) async {
    final id = orderId.trim();
    if (id.isEmpty) return;

    if (!forceRefresh &&
        _deliveryChargesOrderId == id &&
        activeDeliveryCharges.value != null) {
      final fetchedAt = _deliveryChargesFetchedAt;
      if (fetchedAt != null &&
          DateTime.now().difference(fetchedAt) < _deliveryChargesTtl) {
        return;
      }
    }

    final retryAt = _deliveryChargesRetryAt;
    if (!forceRefresh &&
        _deliveryChargesFailureOrderId == id &&
        retryAt != null &&
        DateTime.now().isBefore(retryAt)) {
      return;
    }

    if (_deliveryChargesInFlight.contains(id)) return;
    _deliveryChargesInFlight.add(id);
    try {
      final coords = await _resolveDriverLatLngForCharges();
      if (coords == null) {
        AppLogger.log(
          'Delivery charges skipped for $id: driver location unavailable',
          tag: 'API',
        );
        return;
      }

      final details = await DriverDeliveryChargeService.fetchForOrder(
        orderId: id,
        driverLatitude: coords.lat,
        driverLongitude: coords.lng,
      );

      if (details == null) {
        _deliveryChargesFailureOrderId = id;
        _deliveryChargesRetryAt =
            DateTime.now().add(_deliveryChargesFailureTtl);
        return;
      }

      // The driver may have moved on to another order while the request was
      // in flight; never attach stale details to the new order.
      if (currentOrder.value.id != id) return;

      _setActiveDeliveryCharges(id, details);
      currentOrder.refresh();
    } catch (e) {
      AppLogger.log('Delivery charges apply error for $id: $e', tag: 'API');
    } finally {
      _deliveryChargesInFlight.remove(id);
    }
  }

  /// Stores the authoritative backend details for [orderId] and applies them
  /// to the current order. Safe to call with the accept response, so the popup
  /// is populated immediately without a second network request.
  void _setActiveDeliveryCharges(
    String orderId,
    DriverDeliveryChargeModel details,
  ) {
    _deliveryChargesOrderId = orderId;
    _deliveryChargesFetchedAt = DateTime.now();
    _deliveryChargesFailureOrderId = null;
    _deliveryChargesRetryAt = null;
    activeDeliveryCharges.value = details;
    if (currentOrder.value.id == orderId) {
      _applyDriverDeliveryCharges(details);
    }
  }

  /// Applies order details returned by the accept-order API. This is the fast
  /// path that makes the popup appear right after tapping Accept.
  void applyAcceptedOrderDetails(
    String orderId,
    DriverDeliveryChargeModel details,
  ) {
    final id = orderId.trim();
    if (id.isEmpty) return;
    if (currentOrder.value.id == id) {
      _setActiveDeliveryCharges(id, details);
      currentOrder.refresh();
    }
  }

  /// Merges the backend response into the currently displayed order and the
  /// reactive charge values used by the popup.
  void _applyDriverDeliveryCharges(DriverDeliveryChargeModel details) {
    final order = currentOrder.value;
    if (order.id == null || order.id!.isEmpty) return;

    // Distances / charges shown in the popup. These come from the backend
    // only — the app no longer estimates routes or charges locally.
    driverToRestaurantDistance.value = details.pickupDistanceKm;
    restaurantToCustomerDistance.value = details.deliveryDistanceKm;
    driverToRestaurantCharge.value = details.pickupCharge;
    restaurantToCustomerCharge.value = details.deliveryCharge;
    totalCalculatedCharge.value = details.effectiveDriverCharge;

    order.pickUpDistanceInKms = details.pickupDistanceKm;
    order.deliveryDistanceInKms = details.deliveryDistanceKm;
    order.pickUpCharges = details.pickupCharge;
    order.deliverCharges = details.deliveryCharge;
    order.tipAmount = details.tipAmount.toString();
    order.deliveryCharge = details.deliveryCharge.toString();
    if (details.orderTotalAmount > 0) {
      order.toPay = details.orderTotalAmount.toString();
    }

    // Prefer the outlet details supplied by the charges API.
    if (details.hasOutletData || details.hasOutletCoordinates) {
      final vendor = order.vendor ?? VendorModel();
      if (details.outletName.trim().isNotEmpty) {
        vendor.title = details.outletName.trim();
      }
      if (details.outletAddress.trim().isNotEmpty) {
        vendor.location = details.outletAddress.trim();
      }
      if (details.outletPhoneNumber.trim().isNotEmpty) {
        vendor.phonenumber = details.outletPhoneNumber.trim();
      }
      if (details.hasOutletCoordinates) {
        vendor.latitude = details.outletLatitude;
        vendor.longitude = details.outletLongitude;
      }
      order.vendor = vendor;
      order.vendorID ??= vendor.id;
    }

    // Prefer the customer address supplied by the charges API.
    if (details.hasCustomerData || details.hasCustomerCoordinates) {
      final address = order.address ?? ShippingAddress();
      if (details.customerAddress.trim().isNotEmpty) {
        address.address = details.customerAddress.trim();
      }
      if (details.hasCustomerCoordinates) {
        address.location = UserLocation(
          latitude: details.customerLatitude,
          longitude: details.customerLongitude,
        );
      }
      order.address = address;
    }

    // Persist the backend charge values in the same shape the rest of the app
    // reads from `OrderModel.calculatedCharges`.
    _updateOrderWithCharges();
  }

  void _clearDriverDeliveryCharges() {
    activeDeliveryCharges.value = null;
    _deliveryChargesOrderId = null;
    _deliveryChargesFetchedAt = null;
    _deliveryChargesFailureOrderId = null;
    _deliveryChargesRetryAt = null;
  }

  // ── Popup visibility ──────────────────────────────────────────────────
  // The backend's active order + delivery charge details are authoritative.
  // Do not depend on the Firestore request/in-progress lists here: they are
  // frequently stale, which used to leave the driver without a popup.

  /// Backend details only when they belong to the order currently displayed.
  DriverDeliveryChargeModel? get currentDeliveryCharges {
    final details = activeDeliveryCharges.value;
    return details?.orderId == currentOrder.value.id ? details : null;
  }

  bool get _hasOrderPopupData {
    final order = currentOrder.value;
    final oid = order.id;
    if (oid == null || oid.isEmpty) return false;

    final details = activeDeliveryCharges.value;
    final matches = details != null && details.orderId == oid;
    final hasVendor = order.vendor != null ||
        (order.vendorID?.isNotEmpty ?? false) ||
        (matches &&
            (details.hasOutletData || details.hasOutletCoordinates));
    final hasCustomer = order.address != null ||
        (matches &&
            (details.hasCustomerData || details.hasCustomerCoordinates));
    return hasVendor && hasCustomer;
  }

  bool get _isActiveOrderForDriver {
    final order = currentOrder.value;
    final oid = order.id;
    if (oid == null || oid.isEmpty) return false;

    final status = order.status;
    final isActiveStatus = status == Constant.driverAccepted ||
        status == Constant.orderShipped ||
        status == Constant.orderInTransit;
    if (!isActiveStatus) return false;

    final driverId =
        driverModel.value.id?.toString() ?? Constant.userModel?.id?.toString();
    if (driverId != null && order.driverID == driverId) return true;
    if (driverModel.value.inProgressOrderID?.contains(oid) ?? false) {
      return true;
    }
    if (_serverActiveOrderId == oid) return true;

    // If the backend explicitly assigned this order to a different driver,
    // cached delivery details must not keep the popup alive.
    final assignedDriverId = order.driverID;
    if (assignedDriverId != null &&
        assignedDriverId.isNotEmpty &&
        driverId != null &&
        assignedDriverId != driverId) {
      return false;
    }

    final details = activeDeliveryCharges.value;
    if (details != null && details.orderId == oid) return true;
    return false;
  }

  /// Accept / reject popup for a new order request.
  bool get showAcceptRejectPopup {
    if (!_hasOrderPopupData || _isActiveOrderForDriver) return false;

    final order = currentOrder.value;
    final status = order.status;
    final isPending = status == Constant.driverPending ||
        status == Constant.orderAccepted ||
        status == Constant.orderPlaced;
    if (!isPending) return false;

    final driverId =
        driverModel.value.id?.toString() ?? Constant.userModel?.id?.toString();
    final assignedToOther = order.driverID != null &&
        order.driverID!.isNotEmpty &&
        order.driverID != driverId;
    return !assignedToOther;
  }

  /// Active-order card shown after the driver accepts an order.
  bool get showActiveOrderPopup {
    if (!_hasOrderPopupData || !_isActiveOrderForDriver) return false;

    final status = currentOrder.value.status;
    return status != Constant.orderCompleted &&
        status != Constant.orderCancelled &&
        status != Constant.orderRejected &&
        status != Constant.driverRejected;
  }

  /// Applies the backend charges. The app never estimates distances or
  /// delivery charges locally: if the backend copy is missing it is fetched,
  /// otherwise the cached copy is reused.
  Future<void> calculateOrderChargesInitial(
      {bool fetchSurgeAndToPay = true}) async {
    final id = currentOrder.value.id;
    if (id == null || id.isEmpty) return;

    final backendDetails = activeDeliveryCharges.value;
    if (backendDetails != null && _deliveryChargesOrderId == id) {
      _applyDriverDeliveryCharges(backendDetails);
    } else {
      await _loadDriverDeliveryCharges(id);
    }

    if (!fetchSurgeAndToPay) {
      if (currentOrder.value.paymentMethod?.toLowerCase() == 'cod') {
        final tip = double.tryParse(
                currentOrder.value.tipAmount?.toString() ?? '0') ??
            0.0;
        toPayAmount.value =
            totalCalculatedCharge.value + surgeFee.value + tip;
      }
      return;
    }

    // final fee = await _fetchSurgeFee(id);
    // surgeFee.value = fee ?? 0.0;

    // if (currentOrder.value.paymentMethod?.toLowerCase() == 'cod') {
    //   // final tp = await _fetchToPay(id);
    //   toPayAmount.value =
    //       tp ?? (totalCalculatedCharge.value + surgeFee.value);
    // }
  }

  Future<void> calculateOrderCharges() async {
    await calculateOrderChargesInitial();
    _updateOrderWithCharges();
  }

  /// Location updates only matter while the backend charges are not loaded.
  /// Once they are cached, no local recalculation is performed.
  void notifyDriverLocationUpdated() {
    final id = currentOrder.value.id;
    if (id == null || id.isEmpty) return;
    if (activeDeliveryCharges.value != null &&
        _deliveryChargesOrderId == id) {
      return;
    }

    _chargesRecalcDebounce?.cancel();
    _chargesRecalcDebounce =
        Timer(const Duration(milliseconds: 700), () async {
      if (currentOrder.value.id == null) return;
      try {
        await calculateOrderChargesInitial(fetchSurgeAndToPay: false);
      } catch (e) {
        AppLogger.log('Charges: refresh error: $e', tag: 'Charges');
      }
    });
  }

  bool _isUsableDriverCoord(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat == 0 && lng == 0) return false;
    if (lat.abs() > 90 || lng.abs() > 180) return false;
    return true;
  }

  // ── Coord helpers ──────────────────────────────────────────────────────

  ({double lat, double lng})? _customerDropLatLng(ShippingAddress? a) {
    if (a == null) return null;
    final lat = a.location?.latitude;
    final lng = a.location?.longitude;
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }

  // ── _syncVendorAndChargesForCurrentOrder ──────────────────────────────

  Future<void> _syncVendorAndChargesForCurrentOrder() async {
    final oid = currentOrder.value.id?.toString();
    if (oid == null || oid.isEmpty) return;

    final backendDetails = activeDeliveryCharges.value;
    if (backendDetails != null && _deliveryChargesOrderId == oid) {
      _applyDriverDeliveryCharges(backendDetails);
      final fetchedAt = _deliveryChargesFetchedAt;
      if (fetchedAt == null ||
          DateTime.now().difference(fetchedAt) >= _deliveryChargesTtl) {
        unawaited(_loadDriverDeliveryCharges(oid));
      }
      return;
    }

    await _loadDriverDeliveryCharges(oid);

    if (currentOrder.value.vendor == null &&
        (currentOrder.value.vendorID?.isNotEmpty ?? false)) {
      await _fetchVendorData(currentOrder.value.vendorID!);
    }
  }

  void _logDriverCoordSnapshot(String phase) {
    final oid = currentOrder.value.id;
    final dl  = driverLatLng.value;
    final lf  = Constant.locationDataFinal;
    AppLogger.log(
      '$phase order=$oid '
          'driverLatLng=${dl?.latitude.toStringAsFixed(6)},'
          '${dl?.longitude.toStringAsFixed(6)} '
          'locDataFinal=${lf?.latitude},${lf?.longitude} '
          'modelLoc=${driverModel.value.location?.latitude},'
          '${driverModel.value.location?.longitude}',
      tag: 'Charges',
    );
  }

  Future<({double lat, double lng, String source})?>
  _resolveDriverLatLngForCharges() async {
    _logDriverCoordSnapshot('DriverCoords: before resolve');

    double? lat;
    double? lng;
    var source = '';

    final dl = driverLatLng.value;
    if (_isUsableDriverCoord(dl?.latitude, dl?.longitude)) {
      lat = dl!.latitude; lng = dl.longitude; source = 'driverLatLng';
    }

    if (!_isUsableDriverCoord(lat, lng)) {
      final lf = Constant.locationDataFinal;
      if (_isUsableDriverCoord(lf?.latitude, lf?.longitude)) {
        lat = lf!.latitude; lng = lf.longitude;
        source = 'Constant.locationDataFinal';
      }
    }

    if (!_isUsableDriverCoord(lat, lng)) {
      final loc = driverModel.value.location;
      if (_isUsableDriverCoord(loc?.latitude, loc?.longitude)) {
        lat = loc!.latitude; lng = loc.longitude;
        source = 'driverModel.location';
      }
    }

    if (!_isUsableDriverCoord(lat, lng)) {
      try {
        final pos = await Utils.getCurrentLocation();
        if (pos != null &&
            _isUsableDriverCoord(pos.latitude, pos.longitude)) {
          lat = pos.latitude; lng = pos.longitude;
          source = 'Utils.getCurrentLocation';
          driverModel.value.location =
              UserLocation(latitude: pos.latitude, longitude: pos.longitude);
          driverLatLng.value = LatLng(pos.latitude, pos.longitude);
          driverModel.refresh();
        }
      } catch (e) {
        AppLogger.log(
            'DriverCoords: Utils.getCurrentLocation error: $e',
            tag: 'Charges');
      }
    }

    if (!_isUsableDriverCoord(lat, lng)) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null &&
            _isUsableDriverCoord(last.latitude, last.longitude)) {
          lat = last.latitude; lng = last.longitude;
          source = 'Geolocator.getLastKnownPosition';
          driverModel.value.location =
              UserLocation(latitude: last.latitude, longitude: last.longitude);
          driverLatLng.value = LatLng(last.latitude, last.longitude);
          driverModel.refresh();
        }
      } catch (e) {
        AppLogger.log(
            'DriverCoords: getLastKnownPosition error: $e', tag: 'Charges');
      }
    }

    if (!_isUsableDriverCoord(lat, lng)) {
      _logDriverCoordSnapshot('DriverCoords: FAILED all sources');
      return null;
    }

    AppLogger.log(
        'DriverCoords: OK source=$source lat=$lat lng=$lng', tag: 'Charges');
    return (lat: lat!, lng: lng!, source: source);
  }

  void _updateOrderWithCharges() {
    final surge = surgeFee.value;
    final tip   =
        double.tryParse(currentOrder.value.tipAmount?.toString() ?? '0') ??
            0.0;
    final backendDetails = activeDeliveryCharges.value;
    final useBackendTotal = backendDetails != null &&
        _deliveryChargesOrderId == currentOrder.value.id?.toString();
    final total = useBackendTotal
        ? backendDetails.effectiveDriverCharge
        : totalCalculatedCharge.value + surge + tip;
    currentOrder.value.calculatedCharges = {
      'driverToRestaurantDistance'     : driverToRestaurantDistance.value,
      'driverToRestaurantDuration'     : driverToRestaurantDuration.value,
      'driverToRestaurantCharge'       : driverToRestaurantCharge.value,
      'restaurantToCustomerDistance'   : restaurantToCustomerDistance.value,
      'restaurantToCustomerDuration'   : restaurantToCustomerDuration.value,
      'restaurantToCustomerCharge'     : restaurantToCustomerCharge.value,
      'tipsAmount'                     : currentOrder.value.tipAmount,
      'surgeAmount'                    : surge.toString(),
      'totalCalculatedCharge'          : '$total',
      'calculatedAt'                   : FieldValue.serverTimestamp(),
    };
  }

  // Future<double?> _fetchSurgeFee(String orderId) async {
  //   try {
  //     final res = await AuthHttpClient().get(
  //       Uri.parse(
  //         '${Constant.baseUrl}mobile/orders/$orderId/billing/surge-fee',
  //       ),
  //       timeout: const Duration(seconds: 6),
  //     );
  //     if (res.statusCode == 200) {
  //       final j = jsonDecode(res.body);
  //       if (j['success'] == true) {
  //         final v = j['data']?['total_surge_fee'];
  //         if (v != null) return (v as num).toDouble();
  //       }
  //     }
  //   } catch (_) {}
  //   return null;
  // }

  // Future<double?> _fetchToPay(String orderId) async {
  //   try {
  //     final res = await AuthHttpClient().get(
  //       Uri.parse(
  //         '${Constant.baseUrl}mobile/orders/$orderId/billing/to-pay',
  //       ),
  //       timeout: const Duration(seconds: 6),
  //     );
  //     if (res.statusCode == 200) {
  //       final j = jsonDecode(res.body);
  //       if (j['success'] == true && j['data']?['found'] == true) {
  //         return (j['data']['to_pay'] as num).toDouble();
  //       }
  //     }
  //   } catch (_) {}
  //   return null;
  // }

  // Future<double?> fetchOrderSurgeFeePublic(String orderId) =>
  //     _fetchSurgeFee(orderId);

  // ══════════════════════════════════════════════════════════════════════
  //  changeData
  // ══════════════════════════════════════════════════════════════════════

  void changeData() {
    PerfTelemetry.inc('route_update_triggers');
    _changeDataDebounce?.cancel();
    _changeDataDebounce = Timer(_changeDataDelay, _changeDataInternal);
  }

  Future<void> _changeDataInternal() async {
    if (Constant.mapType == 'inappmap') {
      if (Constant.selectedMapType == 'osm') {
        _getOSMPolyline();
      } else {
        if (Constant.mapAPIKey.isEmpty) {
          try {
            await FireStoreUtils.getSettings();
            if (Constant.mapAPIKey.isNotEmpty) updatePolylinePoints();
          } catch (_) {}
        }
        await _getDirections();
      }
    }
    final pending = currentOrder.value.status == Constant.driverPending;
    if (pending && !_isAcceptingOrder && !_isRejectingOrder) {
      await AudioPlayerService.playSound(true);
    } else {
      await AudioPlayerService.playSound(false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Google Maps directions (map polyline — separate from charge calc)
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _getDirections() async {
    if (currentOrder.value.id == null) return;
    if (_routeCallInFlight) return;

    final dLoc = driverModel.value.location;
    if (dLoc?.latitude == null) return;
    final curPos = LatLng(dLoc!.latitude!, dLoc.longitude!);

    if (_lastRouteOrigin != null &&
        _distanceBetween(_lastRouteOrigin!, curPos) < _routeRecalcDistance) {
      _applyCachedRoute();
      return;
    }

    final cacheKey = _buildRouteCacheKey(curPos);
    if (cacheKey == _lastRouteCacheKey &&
        _cachedSimplified != null &&
        _lastRouteCalcTime != null &&
        DateTime.now().difference(_lastRouteCalcTime!) < _routeCacheDuration) {
      _applyCachedRoute();
      _animateMarkerTo(curPos);
      return;
    }

    _routeCallInFlight = true;
    try {
      await _doDirectionFetch(curPos, cacheKey);
    } finally {
      _routeCallInFlight = false;
    }
  }

  Future<void> _doDirectionFetch(LatLng origin, String cacheKey) async {
    PerfTelemetry.inc('route_calls');
    final status = currentOrder.value.status ?? '';
    LatLng? dest;

    if (status == Constant.orderShipped || status == Constant.driverAccepted) {
      final v = currentOrder.value.vendor;
      if (v == null) return;
      dest = LatLng(
        v.latitudeValue  ?? v.latitude  ?? v.coordinates?.latitude  ?? 0.0,
        v.longitudeValue ?? v.longitude ?? v.coordinates?.longitude ?? 0.0,
      );
    } else if (status == Constant.orderInTransit) {
      final loc = currentOrder.value.address?.location;
      if (loc == null) return;
      dest = LatLng(loc.latitude ?? 0.0, loc.longitude ?? 0.0);
    } else if (status == Constant.driverPending) {
      final v = currentOrder.value.vendor;
      if (v == null) return;
      dest = LatLng(
        v.latitudeValue  ?? v.latitude  ?? v.coordinates?.latitude  ?? 0.0,
        v.longitudeValue ?? v.longitude ?? v.coordinates?.longitude ?? 0.0,
      );
    } else {
      return;
    }

    final result = await polylinePoints.value.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin:      PointLatLng(origin.latitude, origin.longitude),
        destination: PointLatLng(dest.latitude, dest.longitude),
        mode:        TravelMode.driving,
      ),
    );

    final coords =
    result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    if (coords.isEmpty) return;

    _lastRouteOrigin   = origin;
    _lastRouteCacheKey = cacheKey;
    _cachedPolyline    = List.from(coords);
    _cachedSimplified  = _simplifyPolyline(coords);
    _lastRouteCalcTime = DateTime.now();

    _applyCachedRoute();
    _buildMarkersForStatus(origin, dest, status);
  }

  void _buildMarkersForStatus(LatLng origin, LatLng dest, String status) {
    final nm = <String, Marker>{};

    if ((status == Constant.orderShipped || status == Constant.driverAccepted) &&
        departureIcon != null) {
      nm['Departure'] = Marker(
          markerId: const MarkerId('Departure'),
          position: dest,
          icon: departureIcon!);
    } else if (status == Constant.orderInTransit && destinationIcon != null) {
      nm['Destination'] = Marker(
          markerId: const MarkerId('Destination'),
          position: dest,
          icon: destinationIcon!);
    } else if (status == Constant.driverPending) {
      if (departureIcon != null) {
        nm['Departure'] = Marker(
            markerId: const MarkerId('Departure'),
            position: dest,
            icon: departureIcon!);
      }
      final cust = _customerDropLatLng(currentOrder.value.address);
      if (cust != null && destinationIcon != null) {
        nm['Destination'] = Marker(
            markerId: const MarkerId('Destination'),
            position: LatLng(cust.lat, cust.lng),
            icon: destinationIcon!);
      }
    }

    _animateMarkerTo(origin);
    nm['Driver'] = markers.value['Driver'] ??
        Marker(
          markerId: const MarkerId('Driver'),
          position: origin,
          icon: taxiIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
        );

    markers.value = nm;
  }

  void _applyCachedRoute() {
    if (_cachedSimplified == null || _cachedSimplified!.isEmpty) return;
    const id = PolylineId('poly');
    polyLines.value = {
      id: Polyline(
        polylineId: id,
        color: AppThemeData.secondary300,
        points: _cachedSimplified!,
        width: 7,
        geodesic: true,
      ),
    };
  }

  List<LatLng> _simplifyPolyline(List<LatLng> pts) {
    if (pts.length <= _maxDisplayPoints) return pts;
    final step = (pts.length / _maxDisplayPoints).ceil();
    final out  = <LatLng>[pts.first];
    for (int i = step; i < pts.length - step; i += step) out.add(pts[i]);
    if (out.last != pts.last) out.add(pts.last);
    return out;
  }

  String _buildRouteCacheKey(LatLng origin) {
    final oLat   = _snap(origin.latitude);
    final oLng   = _snap(origin.longitude);
    final status = currentOrder.value.status ?? '';
    final id     = currentOrder.value.id ?? '';
    return '$id-$status-$oLat,$oLng';
  }

  double _snap(double v) => (v / _coordPrecision).round() * _coordPrecision;

  void _clearRouteCache() {
    _lastRouteCacheKey = null;
    _cachedPolyline    = null;
    _cachedSimplified  = null;
    _lastRouteCalcTime = null;
    _lastRouteOrigin   = null;
    _routeCallInFlight = false;
    _markerAnimTimer?.cancel();
  }

  // ══════════════════════════════════════════════════════════════════════
  //  clearMap
  // ══════════════════════════════════════════════════════════════════════

  Future<void> clearMap() async {
    await AudioPlayerService.playSound(false);
    if (Constant.selectedMapType != 'osm') {
      markers.value   = {};
      polyLines.value = {};
    } else {
      osmMarkers.value  = [];
      routePoints.value = [];
      _osmMapReady = false;
    }
    _clearRouteCache();
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Accept / Reject
  // ══════════════════════════════════════════════════════════════════════

  Future<void> acceptOrder() async {
    if (_isAcceptingOrder) {
      AppLogger.log(
        'Accept API skipped: already processing another accept request',
        tag: 'OrderWorkflow',
      );
      return;
    }

    // Cooldown: prevents the "same snackbar again and again" loop when the
    // same precondition keeps failing while the active-order poller keeps
    // re-surfacing the same order.
    if (_lastAcceptFailAt != null &&
        DateTime.now().difference(_lastAcceptFailAt!) < _acceptFailCooldown) {
      AppLogger.log(
        'Accept suppressed (cooldown ${_acceptFailCooldown.inSeconds}s)',
        tag: 'OrderWorkflow',
      );
      return;
    }

    final orderId = currentOrder.value.id?.toString().trim() ?? '';
    final driverId = driverModel.value.id?.toString().trim() ?? '';

    AppLogger.log(
      'Accept button triggered | orderId=$orderId | driverId=$driverId '
          '| status=${currentOrder.value.status}',
      tag: 'OrderWorkflow',
    );

    if (orderId.isEmpty || driverId.isEmpty) {
      AppLogger.log(
        'Accept API skipped: missing orderId or driverId',
        tag: 'OrderWorkflow',
      );
      ShowToastDialog.showToast('Order or driver ID missing');
      return;
    }

    if (currentOrder.value.status == Constant.driverAccepted &&
        currentOrder.value.driverID?.toString() == driverId) {
      AppLogger.log(
        'Accept API skipped: order already accepted by this driver',
        tag: 'OrderWorkflow',
      );
      return;
    }

    // Fail fast if the driver has no usable location. This is exactly why
    // the backend was returning "Driver latitude or longitude unavailable".
    if (!await _ensureDriverLocation()) {
      _lastAcceptFailAt = DateTime.now();
      AppLogger.log(
        'Accept blocked: driver location unavailable',
        tag: 'OrderWorkflow',
      );
      ShowToastDialog.showToast(
        'Enable GPS / location to accept orders',
      );
      return;
    }

    _changeDataDebounce?.cancel();
    _isAcceptingOrder = true;

    try {
      await AudioPlayerService.playSound(false);
      ShowToastDialog.showLoader('Please wait'.tr);

      AppLogger.log(
        'Calling acceptOrderBackend | orderId=$orderId | driverId=$driverId',
        tag: 'OrderWorkflow',
      );

      final result = await OrderWorkflowService.acceptOrderBackend(
        order: currentOrder.value,
        driverModel: driverModel.value,
      );

      AppLogger.log(
        'acceptOrderBackend response | success=${result.success} '
            '| code=${result.errorCode}',
        tag: 'OrderWorkflow',
      );

      // Rate limited.
      if (result.success == null) {
        _lastAcceptFailAt = DateTime.now();
        Get.snackbar(
          'Rate Limited',
          result.errorMessage ?? 'Please wait and try again.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      if (result.success == true) {
        _lastAcceptFailAt = null;

        _markOrderHandledAndMute(orderId);
        _notifiedOrderIds.remove(orderId);

        _lastKnownStatus      = Constant.driverAccepted;
        _lastStatusChangeTime = DateTime.now();

        // Update local state immediately.
        currentOrder.value.status   = Constant.driverAccepted;
        currentOrder.value.driverID = driverId;
        currentOrder.value.driver   = driverModel.value;

        if (result.details != null) {
          applyAcceptedOrderDetails(orderId, result.details!);
        }

        _notifyOrderUiChanged();

        ShowToastDialog.showToast('Order accepted!'.tr);

        AppLogger.log(
          'Order accepted successfully: $orderId',
          tag: 'OrderWorkflow',
        );

        // Follow-up operations should not undo a successful API acceptance.
        try {
          await calculateOrderCharges();
          await FireStoreUtils.setOrder(currentOrder.value);

          if (currentOrder.value.author?.fcmToken != null) {
            await SendNotification.sendFcmMessage(
              Constant.driverAcceptedNotification,
              currentOrder.value.author!.fcmToken.toString(),
              {},
            );
          }

          if (currentOrder.value.vendor?.fcmToken != null) {
            await SendNotification.sendFcmMessage(
              Constant.driverAcceptedNotification,
              currentOrder.value.vendor!.fcmToken.toString(),
              {},
            );
          }
        } catch (e) {
          AppLogger.log(
            'Post-accept operation failed: $e',
            tag: 'OrderWorkflow',
          );
        }
        return;
      }

      // ---- success == false ----
      _lastAcceptFailAt = DateTime.now();

      final code    = result.errorCode;
      final message = result.errorMessage;

      AppLogger.log(
        'Order acceptance rejected by backend: $orderId | '
            'code=$code | message=$message',
        tag: 'OrderWorkflow',
      );

      // Only this case means another driver genuinely took the order.
      if (code == 'ALREADY_ACCEPTED') {
        _notifiedOrderIds.remove(orderId);

        currentOrder.value = OrderModel();
        _clearDriverDeliveryCharges();

        await clearMap();
        update();

        Get.snackbar(
          'Unavailable',
          message ?? 'Order accepted by another driver.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Validation failures — keep the order on screen so the driver can
      // fix the precondition and retry deliberately.
      if (code == 'NO_LOCATION' || code == 'MISSING_IDS') {
        _notifiedOrderIds.remove(orderId);
        _notifyOrderUiChanged();

        Get.snackbar(
          code == 'NO_LOCATION' ? 'Location Required' : 'Missing Info',
          message ?? 'Please fix the issue and retry.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Any other backend failure — keep the order, show the real reason.
      _notifiedOrderIds.remove(orderId);
      _notifyOrderUiChanged();

      Get.snackbar(
        'Could not accept',
        message ?? 'Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e, stackTrace) {
      _lastAcceptFailAt = DateTime.now();

      AppLogger.log(
        'acceptOrder exception: $e\n$stackTrace',
        tag: 'OrderWorkflow',
      );

      Get.snackbar(
        'Error',
        'Failed to accept order. Try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      ShowToastDialog.closeLoader();
      await AudioPlayerService.playSound(false);
      _isAcceptingOrder = false;
    }
  }

  Future<void> rejectOrder() async {
    _changeDataDebounce?.cancel();
    _isRejectingOrder = true;
    await AudioPlayerService.playSound(false);
    try {
      final id = currentOrder.value.id;
      if (id != null) _markOrderHandledAndMute(id);
      _notifiedOrderIds.remove(id);

      await OrderWorkflowService.rejectOrderBackend(
        order:       currentOrder.value,
        driverModel: driverModel.value,
      );

      currentOrder.value = OrderModel();
      _clearDriverDeliveryCharges();
      await clearMap();
      _notifyOrderUiChanged(refreshOrder: false);

      if (Constant.singleOrderReceive == false) Get.back();
    } finally {
      await AudioPlayerService.playSound(false);
      _isRejectingOrder = false;
    }
  }

  bool get isPickupNavigationState {
    final status = currentOrder.value.status ?? '';
    return status == Constant.driverAccepted  ||
        status == Constant.orderShipped    ||
        status == Constant.driverPending   ||
        status == Constant.orderAccepted;
  }

  bool get isDropNavigationState {
    final status = currentOrder.value.status ?? '';
    return status == Constant.orderInTransit;
  }

  Future<void> openCurrentOrderNavigation() async {
    if (isNavigatingToMap.value) return;
    final order     = currentOrder.value;
    final originLat = driverModel.value.location?.latitude;
    final originLng = driverModel.value.location?.longitude;

    double? destLat;
    double? destLng;
    if (isPickupNavigationState) {
      destLat = order.vendor?.latitude;
      destLng = order.vendor?.longitude;
    } else if (isDropNavigationState) {
      destLat = order.address?.location?.latitude;
      destLng = order.address?.location?.longitude;
    }

    if (destLat == null || destLng == null) {
      Get.snackbar('Navigation unavailable',
          'Location coordinates are missing for this order.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isNavigatingToMap.value = true;
    try {
      final opened = (originLat != null && originLng != null)
          ? await Utils.openGoogleMaps(
          originLat, originLng, destLat, destLng)
          : await Utils.openGoogleMapsToDestination(destLat, destLng);
      if (!opened) {
        Get.snackbar('Unable to open maps',
            'Google Maps could not be opened on this device.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      Get.snackbar('Unable to open maps',
          'Something went wrong while opening navigation.',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isNavigatingToMap.value = false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Driver profile
  // ══════════════════════════════════════════════════════════════════════

  Future<void> getDriver() async {
    final userId = await LoginController.getFirebaseId();
    try {
      // Uses the shared getDriverDetails cache (FireStoreUtils), not a raw call.
      final userDetails = await FireStoreUtils.getDriverDetailsData(userId);
      if (userDetails.isNotEmpty) {
          final prev   = driverModel.value.orderRequestData?.toList();
          final parsed = UserModel.fromJson(userDetails);
          _filterCompletedFromUser(parsed);
          driverModel.value = parsed;
          if (Constant.userModel == null || Constant.userModel!.id == null) {
            Constant.userModel = parsed;
          }

          if (driverModel.value.id != null) {
            isLoading.value = false;
            changeData();
            fetchTodayDashboard(forceRefresh: true);

            final curr   = driverModel.value.orderRequestData?.toList();
            final hasNew = (curr?.isNotEmpty ?? false) &&
                (prev == null || curr.toString() != prev.toString());

            if (hasNew) {
              final newIds = curr
                  ?.where((id) => prev == null || !prev.contains(id))
                  .toList() ??
                  [];
              for (final oid in newIds) {
                if (oid.isNotEmpty && !_isOrderMuted(oid)) {
                  await _showOrderNotification(oid);
                  await AudioPlayerService.playSound(true);
                }
              }
              await Future.delayed(const Duration(milliseconds: 500));
            }
            await getCurrentOrder();
          }
        }
    } catch (e) {
      AppLogger.log('getDriver error: $e', tag: 'API');
    } finally {
      // Always release the loader so the home screen never stays stuck,
      // even if the API call fails or returns no driver id. Fall back to the
      // in-memory user so existing data still renders.
      if (isLoading.value) {
        if (driverModel.value.id == null && Constant.userModel != null) {
          driverModel.value = Constant.userModel!;
        }
        isLoading.value = false;
      }
    }

    // Resolve the authoritative active order immediately instead of waiting
    // for the first polling tick. This is what feeds the order id into
    // `getDriverDeliveryChargesForOrder`.
    unawaited(refreshHomeScreen());
  }

  // ══════════════════════════════════════════════════════════════════════
  //  getCurrentOrder
  // ══════════════════════════════════════════════════════════════════════

  Future<void> getCurrentOrder() async {
    if (_lastGetOrderTime != null &&
        DateTime.now().difference(_lastGetOrderTime!) < _minOrderInterval) {
      return;
    }
    _lastGetOrderTime = DateTime.now();

    final inProgress = driverModel.value.inProgressOrderID ?? [];
    final requests   = driverModel.value.orderRequestData  ?? [];
    final serverActiveOrderId = _serverActiveOrderId;

    final currentIsServerActive = serverActiveOrderId != null &&
        currentOrder.value.id == serverActiveOrderId;
    // Keep an order that the backend already knows is active even when the
    // cached driver-profile lists have not caught up yet.
    final keepBackendActive = _isActiveOrderForDriver;

    if (currentOrder.value.id != null &&
        !currentIsServerActive &&
        !keepBackendActive &&
        !inProgress.contains(currentOrder.value.id) &&
        !requests.contains(currentOrder.value.id)) {
      if (_isAcceptingOrder) return;
      final isPendingNoDriver =
          currentOrder.value.status == Constant.driverPending &&
              (currentOrder.value.driverID?.isEmpty ?? true);
      if (!isPendingNoDriver) {
        currentOrder.value = OrderModel();
        _clearDriverDeliveryCharges();
        await clearMap();
        await AudioPlayerService.playSound(false);
        return;
      }
    }

    String? firstId;

    // `getActiveOrderByDriverId` is authoritative. If it returned an order,
    // show that order even when the local driver profile lists are stale.
    if (serverActiveOrderId != null && serverActiveOrderId.isNotEmpty) {
      firstId = serverActiveOrderId;
    } else {
      final validProgress =
      inProgress.where((id) => id?.isNotEmpty ?? false).toList();
      if (validProgress.isNotEmpty) {
        firstId = validProgress.first;
      } else {
        final validReqs = requests
            .where((id) =>
        (id?.isNotEmpty ?? false) && id != currentOrder.value.id)
            .toList();
        if (validReqs.isNotEmpty) firstId = validReqs.first;
      }
    }

    if (firstId == null) return;
    if (currentOrder.value.id == firstId) {
      await _syncVendorAndChargesForCurrentOrder();
      return;
    }

    // New order — clear leg caches so there is no cross-order contamination
    await _fetchAndDisplayOrder(firstId,
        inProgress: inProgress, requests: requests);
  }

  /// Legacy driver endpoint fallback for older backends.
  ///
  /// `GET {baseUrl}driver/get-current-reject-accept?order_id=...&exclude_statuses=...`
  ///
  /// Returns the order (including its current accept / reject / pickup status)
  /// or `null` when the backend cannot serve it, so callers can fall through to
  /// the legacy restaurant endpoint / primary API.
  Future<OrderModel?> _fetchLegacyDriverCurrentOrder(
    String orderId, {
    bool useCache = true,
    bool forceRefresh = false,
  }) async {
    final id = orderId.trim();
    if (id.isEmpty) return null;

    final h = HttpClientService();
    if (forceRefresh) {
      await h.invalidateCache('orders/$id');
    }

    try {
      final res = await h.get(
        Uri.parse(
            '${Constant.baseUrl}driver/acceptOrRejectOrderByDriver'
                '?order_id=$id'
                '&driverId='
                'ACCEPT'),
        headers: {'Accept': 'application/json'},
        cacheStrategy: CacheStrategy.order,
        useCache: !forceRefresh,
        forceRefresh: forceRefresh,
        timeout: const Duration(seconds: 10),
      );
      if (res.statusCode == 200 && !res.body.startsWith('<')) {
        final d = jsonDecode(res.body);
        if (d['success'] == true && d['order'] != null) {
          return OrderModel.fromJson(d['order']);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _fetchAndDisplayOrder(
      String orderId, {
        required List inProgress,
        required List requests,
      }) async {
    // Primary endpoint: the CO service's complete order details. The same
    // response also carries the charges, so reuse it for the popup instead of
    // making a second network request.
    final bundle = await OrderDetailService.fetchOrderBundle(orderId);
    OrderModel? fetched = bundle.order;

    // Legacy driver endpoint (kept only as a fallback for older backends).
    if (fetched == null) {
      fetched = await _fetchLegacyDriverCurrentOrder(orderId);
    }

    // Legacy restaurant endpoint (kept only as a fallback for older backends).
    if (fetched == null) {
      try {
        final h   = HttpClientService();
        final res = await h.get(
          Uri.parse('${Constant.baseUrl}restaurant/orders/$orderId'),
          headers: {'Accept': 'application/json'},
          cacheStrategy: CacheStrategy.order,
          useCache: true,
          timeout: const Duration(seconds: 10),
        );
        if (res.statusCode == 200 && !res.body.startsWith('<')) {
          final d = jsonDecode(res.body);
          if (d['success'] == true && d['data'] != null) {
            fetched = OrderModel.fromJson(d['data']);
          }
        }
      } catch (_) {}
    }

    if (fetched == null || fetched.id == null) {
      inProgress.remove(orderId);
      requests.remove(orderId);
      await FireStoreUtils.updateUser(driverModel.value);
      if (currentOrder.value.id == orderId) {
        currentOrder.value = OrderModel();
        _clearDriverDeliveryCharges();
        await clearMap();
        await AudioPlayerService.playSound(false);
      }
      return;
    }

    if (fetched.status == Constant.orderCompleted ||
        fetched.status == 'Order Completed') {
      markOrderAsCompleted(fetched.id);
      driverModel.value.inProgressOrderID?.remove(fetched.id);
      driverModel.value.orderRequestData?.remove(fetched.id);
      await FireStoreUtils.updateUser(driverModel.value);
      if (currentOrder.value.id == fetched.id) {
        currentOrder.value = OrderModel();
        _clearDriverDeliveryCharges();
        await clearMap();
      }
      resetStatusTracking();
      _notifyOrderUiChanged(refreshOrder: false);
      return;
    }

    currentOrder.value = fetched;
    if (_deliveryChargesOrderId != fetched.id) {
      _clearDriverDeliveryCharges();
    }
    if (bundle.details != null) {
      _setActiveDeliveryCharges(fetched.id!, bundle.details!);
    }
    _lastKnownStatus      = fetched.status;
    _lastStatusChangeTime = DateTime.now();

    if (currentOrder.value.vendor == null &&
        (currentOrder.value.vendorID?.isNotEmpty ?? false)) {
      await _fetchVendorData(currentOrder.value.vendorID!);
    }
    await calculateOrderChargesInitial();

    changeData();
    _notifyOrderUiChanged();
  }

  // ══════════════════════════════════════════════════════════════════════
  //  refreshCurrentOrder
  // ══════════════════════════════════════════════════════════════════════

  Future<void> refreshCurrentOrder({bool forceRefresh = false}) async {
    if (currentOrder.value.id == null) return;
    try {
      final orderId = currentOrder.value.id!;

      // Primary endpoint: CO complete order details + charges in one call.
      final bundle = await OrderDetailService.fetchOrderBundle(orderId);
      OrderModel? refreshed = bundle.order;

      // Legacy driver endpoint (kept only as a fallback for older backends).
      refreshed ??= await _fetchLegacyDriverCurrentOrder(
        orderId,
        useCache: !forceRefresh,
        forceRefresh: forceRefresh,
      );

      // Legacy restaurant endpoint (kept only as a fallback for older backends).
      if (refreshed == null) {
        final h = HttpClientService();
        final res = await h.get(
          Uri.parse('${Constant.baseUrl}restaurant/orders/$orderId'),
          cacheStrategy: CacheStrategy.order,
          useCache: !forceRefresh,
          forceRefresh: forceRefresh,
        );
        if (res.statusCode == 200 && !res.body.startsWith('<')) {
          final body = jsonDecode(res.body);
          if (body['success'] == true && body['data'] != null) {
            refreshed = OrderModel.fromJson(body['data']);
          }
        }
      }

      if (refreshed == null) return;
      final priority  = {
        Constant.driverPending: 1,
        Constant.driverAccepted: 2,
        Constant.orderShipped: 2,
        Constant.orderInTransit: 3,
        Constant.orderCompleted: 4,
      };
      final cur = priority[currentOrder.value.status] ?? 0;
      final nw  = priority[refreshed.status] ?? 0;

      if (refreshed.status == Constant.orderCompleted) {
        markOrderAsCompleted(currentOrder.value.id);
        driverModel.value.inProgressOrderID?.remove(currentOrder.value.id);
        driverModel.value.orderRequestData?.remove(currentOrder.value.id);
        await FireStoreUtils.updateUser(driverModel.value);
        currentOrder.value = OrderModel();
        _clearDriverDeliveryCharges();
        await clearMap();
        resetStatusTracking();
        _notifyOrderUiChanged(refreshOrder: false);
        return;
      }

      if (nw >= cur || forceRefresh) {
        final changed =
            _lastKnownStatus != null && _lastKnownStatus != refreshed.status;
        currentOrder.value = refreshed;
        if (changed) {
          _lastStatusChangeTime = DateTime.now();
          _lastKnownStatus      = refreshed.status;
          currentOrder.refresh();
        } else {
          _lastKnownStatus = refreshed.status;
        }
      }

      if (bundle.details != null) {
        _setActiveDeliveryCharges(orderId, bundle.details!);
      }

      if (currentOrder.value.vendor == null &&
          (currentOrder.value.vendorID?.isNotEmpty ?? false)) {
        await _fetchVendorData(currentOrder.value.vendorID!);
      }

      await _syncVendorAndChargesForCurrentOrder();
      changeData();
      _notifyOrderUiChanged(refreshOrder: false);
    } catch (e) {
      AppLogger.log('refreshCurrentOrder error: $e', tag: 'API');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  refreshHomeScreen
  // ══════════════════════════════════════════════════════════════════════

  String? _extractActiveOrderId(Map<String, dynamic> map) {
    final raw = map['orderId'] ??
        map['order_id'] ??
        map['activeOrderId'] ??
        map['active_order_id'];
    if (raw == null) return null;
    final id = raw.toString().trim();
    if (id.isEmpty || id.toLowerCase() == 'null') return null;
    return id;
  }

  bool _looksLikeDriverPayload(Map<String, dynamic> map) {
    const driverKeys = {
      'id',
      'driverId',
      'firebaseId',
      'firebase_id',
      'firstName',
      'lastName',
      'fullName',
      'phoneNumber',
      'email',
      'role',
      'walletAmount',
      'wallet_amount',
      'isActive',
      'readyToAcceptOrders',
      'isApproved',
      'orderRequestData',
      'inProgressOrderID',
    };
    return driverKeys.any(map.containsKey);
  }

  Future<bool> refreshHomeScreen() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final userId = await LoginController.getFirebaseId();
      final prev   = driverModel.value.orderRequestData?.toList();

      final headers = await getHeaders();
      if (_lastETag     != null) headers['If-None-Match']     = _lastETag!;
      if (_lastModified != null) headers['If-Modified-Since'] = _lastModified!;

      final h   = HttpClientService();
      final res = await h.get(
        Uri.parse('${Constant.baseUrl}driver/getActiveOrderByDriverId?driverId=$userId'),
        headers: headers,
        cacheStrategy: CacheStrategy.driverProfile,
        useCache: true,
        forceRefresh: _lastETag != null || _lastModified != null,
      );

      if (res.statusCode == 304) return false;
      if (res.statusCode != 200) return false;

      final etag = res.headers['etag'];
      final lm   = res.headers['last-modified'];
      if (etag != null) _lastETag     = etag;
      if (lm   != null) _lastModified = lm;

      final j = jsonDecode(res.body);
      if (j is! Map) return false;

      final root = Map<String, dynamic>.from(j);
      final userDetails = root['data'] is Map
          ? Map<String, dynamic>.from(root['data'] as Map)
          : root;
      final activeOrderId = _extractActiveOrderId(root) ??
          _extractActiveOrderId(userDetails);

      // `getActiveOrderByDriverId` may answer with only a status + order id
      // (the driver profile has its own `getDriverDetails` endpoint). Never
      // overwrite the loaded driver with that sparse payload.
      _serverActiveOrderId = activeOrderId;

      final looksLikeDriver = _looksLikeDriverPayload(userDetails);
      if (!looksLikeDriver && activeOrderId == null && userDetails.isEmpty) {
        return false;
      }

      if (looksLikeDriver) {
        if (!userDetails.containsKey('role')) {
          userDetails['role'] = Constant.userRoleDriver;
        }
        if (!userDetails.containsKey('active')) {
          userDetails['active'] = true;
        }
        if (!userDetails.containsKey('isActive')) {
          userDetails['isActive'] = true;
        }

        final parsed = UserModel.fromJson(userDetails);
        _filterCompletedFromUser(parsed);
        driverModel.value = parsed;
      }

      final curr   = driverModel.value.orderRequestData?.toList();
      final hasNew = (curr?.isNotEmpty ?? false) &&
          (prev == null || curr.toString() != prev.toString());

      if (hasNew) {
        final newIds =
            curr?.where((id) => prev == null || !prev.contains(id)).toList() ??
                [];
        for (final oid in newIds) {
          if (oid.isNotEmpty && !_isOrderMuted(oid)) {
            await _showOrderNotification(oid);
            await AudioPlayerService.playSound(true);
          }
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (activeOrderId != null && currentOrder.value.id != activeOrderId) {
        // A new active order is reported by the backend — load it and pass its
        // id to `getDriverDeliveryChargesForOrder` from there. Bypass the
        // short getCurrentOrder throttle: this id just arrived from the server
        // and must not be skipped because of an earlier poll/startup call.
        _lastGetOrderTime = null;
        await getCurrentOrder();
      } else if (currentOrder.value.id != null) {
        final shouldRefresh = _lastStatusChangeTime == null ||
            DateTime.now().difference(_lastStatusChangeTime!) >
                _statusCooldown;
        if (shouldRefresh) await refreshCurrentOrder();
      } else {
        await getCurrentOrder();
      }

      _notifyOrderUiChanged(refreshOrder: false);
      return true;
    } catch (e) {
      AppLogger.log('refreshHomeScreen error: $e', tag: 'API');
      await getCurrentOrder();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Vendor cache
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _fetchVendorData(String vendorId) async {
    if (_vendorCache.containsKey(vendorId)) {
      final age = DateTime.now().difference(_vendorCacheTime[vendorId]!);
      if (age < _vendorCacheTTL) {
        final cached = _vendorCache[vendorId]!;
        if (!identical(currentOrder.value.vendor, cached)) {
          currentOrder.value.vendor = cached;
          update();
        }
        return;
      }
      _vendorCache.remove(vendorId);
    }

    try {
      final h   = HttpClientService();
      final res = await h.get(
        Uri.parse('${Constant.baseUrl}restaurant/vendors/$vendorId'),
        headers: {'Accept': 'application/json'},
        cacheStrategy: CacheStrategy.vendor,
        useCache: true,
        timeout: const Duration(seconds: 10),
      );
      if (res.statusCode == 200 && !res.body.startsWith('<')) {
        final d = jsonDecode(res.body);
        if (d['success'] == true && d['data'] is Map<String, dynamic>) {
          final v =
          VendorModel.fromJson(d['data'] as Map<String, dynamic>);
          _vendorCache[vendorId]     = v;
          _vendorCacheTime[vendorId] = DateTime.now();
          currentOrder.value.vendor  = v;
          update();
          return;
        }
      }
    } catch (_) {}

    try {
      final snap = await firestore.FirebaseFirestore.instance
          .collection('vendors')
          .doc(vendorId)
          .get();
      if (snap.exists && snap.data() != null) {
        final v = VendorModel.fromJson(
            Map<String, dynamic>.from(snap.data()!));
        _vendorCache[vendorId]     = v;
        _vendorCacheTime[vendorId] = DateTime.now();
        currentOrder.value.vendor  = v;
        update();
      }
    } catch (e) {
      AppLogger.log('Vendor Firestore error: $e', tag: 'VendorCache');
    }
  }

  static Future<VendorModel?> getVendorById(String vendorId) async {
    if (vendorId.isEmpty) return null;
    try {
      HomeController? ctrl;
      try { ctrl = Get.find<HomeController>(); } catch (_) {}
      if (ctrl != null && ctrl._vendorCache.containsKey(vendorId)) {
        final age =
        DateTime.now().difference(ctrl._vendorCacheTime[vendorId]!);
        if (age < _vendorCacheTTL) return ctrl._vendorCache[vendorId];
      }
      final h   = HttpClientService();
      final res = await h.get(
        Uri.parse('${Constant.baseUrl}restaurant/vendors/$vendorId'),
        headers: {'Accept': 'application/json'},
        cacheStrategy: CacheStrategy.vendor,
        useCache: true,
      );
      if (res.statusCode == 200 && !res.body.startsWith('<')) {
        final d = jsonDecode(res.body);
        if (d['success'] == true && d['data'] is Map<String, dynamic>) {
          final v =
          VendorModel.fromJson(d['data'] as Map<String, dynamic>);
          ctrl?._vendorCache[vendorId]     = v;
          ctrl?._vendorCacheTime[vendorId] = DateTime.now();
          return v;
        }
      }
    } catch (_) {}
    return null;
  }

  void clearVendorCache() {
    _vendorCache.clear();
    _vendorCacheTime.clear();
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Notifications
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _showOrderNotification(String orderId) async {
    if (_notifiedOrderIds.contains(orderId)) return;
    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        'New Order',
        'Order $orderId is waiting for you!',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'order_channel',
            'Orders',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('order_ringtone'),
            enableVibration: true,
            vibrationPattern: Int64List.fromList([1000, 1000, 1000, 1000]),
          ),
          iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true),
        ),
        payload: orderId,
      );
      _notifiedOrderIds.add(orderId);
    } catch (e) {
      AppLogger.log('Notification error: $e', tag: 'Notifications');
    }
  }

  void _markOrderHandledAndMute(String orderId) {
    if (orderId.isEmpty) return;
    _recentlyHandledOrderMutes[orderId] = DateTime.now();
  }

  bool _isOrderMuted(String orderId) {
    if (orderId.isEmpty) return false;
    final at = _recentlyHandledOrderMutes[orderId];
    if (at == null) return false;
    if (DateTime.now().difference(at) > _handledOrderMuteTtl) {
      _recentlyHandledOrderMutes.remove(orderId);
      return false;
    }
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  OSM helpers
  // ══════════════════════════════════════════════════════════════════════

  void _getOSMPolyline() {
    try {
      if (currentOrder.value.id == null) return;
      final status = currentOrder.value.status;
      final dLoc   = driverModel.value.location;
      if (dLoc?.latitude == null) return;

      if (status == Constant.orderShipped ||
          status == Constant.driverAccepted) {
        final v = currentOrder.value.vendor;
        if (v == null) return;
        current.value = location.LatLng(dLoc!.latitude!, dLoc.longitude!);
        destination.value = location.LatLng(
          v.latitudeValue  ?? v.latitude  ?? v.coordinates?.latitude  ?? 0.0,
          v.longitudeValue ?? v.longitude ?? v.coordinates?.longitude ?? 0.0,
        );
        Future.delayed(const Duration(milliseconds: 500), _animateToSource);
        fetchRoute(current.value, destination.value)
            .then((_) => _setOSMMarkers());
      } else if (status == Constant.orderInTransit) {
        final loc = currentOrder.value.address?.location;
        if (loc == null) return;
        current.value = location.LatLng(dLoc!.latitude!, dLoc.longitude!);
        destination.value =
            location.LatLng(loc.latitude ?? 0.0, loc.longitude ?? 0.0);
        _setOSMMarkers();
        fetchRoute(current.value, destination.value)
            .then((_) => _setOSMMarkers());
        Future.delayed(const Duration(milliseconds: 500), _animateToSource);
      } else if (status == Constant.driverPending) {
        final v = currentOrder.value.vendor;
        if (v == null) return;
        current.value = location.LatLng(dLoc!.latitude!, dLoc.longitude!);
        destination.value = location.LatLng(
          v.latitudeValue  ?? v.latitude  ?? v.coordinates?.latitude  ?? 0.0,
          v.longitudeValue ?? v.longitude ?? v.coordinates?.longitude ?? 0.0,
        );
        Future.delayed(const Duration(milliseconds: 500), _animateToSource);
        fetchRoute(current.value, destination.value)
            .then((_) => _setOSMMarkers());
      }
    } catch (e) {
      AppLogger.log('OSM polyline error: $e', tag: 'OSM');
    }
  }

  void _setOSMMarkers() {
    osmMarkers.value = [
      flutterMap.Marker(
        point: current.value,
        width: 45, height: 45, rotate: true,
        child: Image.asset('assets/images/food_delivery.png'),
      ),
      flutterMap.Marker(
        point: source.value,
        width: 40, height: 40,
        child: Image.asset('assets/images/location_black3x.png'),
      ),
      flutterMap.Marker(
        point: destination.value,
        width: 40, height: 40,
        child: Image.asset('assets/images/location_orange3x.png'),
      ),
    ];
  }

  void _animateToSource() {
    if (!_osmMapReady) return;
    try {
      osmMapController.move(
        location.LatLng(
          driverModel.value.location?.latitude  ?? 0.0,
          driverModel.value.location?.longitude ?? 0.0,
        ),
        16,
      );
    } catch (_) {}
  }

  Future<void> fetchRoute(
      location.LatLng src, location.LatLng dst) async {
    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/'
              '${src.longitude},${src.latitude};'
              '${dst.longitude},${dst.latitude}'
              '?overview=full&geometries=geojson');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final d      = jsonDecode(res.body);
        final coords = d['routes']?[0]?['geometry']?['coordinates'];
        if (coords is List) {
          routePoints.value = coords
              .whereType<List>()
              .where((c) => c.length >= 2)
              .map((c) =>
              location.LatLng(c[1].toDouble(), c[0].toDouble()))
              .toList();
        }
      }
    } catch (e) {
      AppLogger.log('fetchRoute error: $e', tag: 'OSM');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Utility
  // ══════════════════════════════════════════════════════════════════════

  double _distanceBetween(LatLng a, LatLng b) {
    const r    = 6371000.0;
    final dLat = _rad(b.latitude  - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final x    = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  double _rad(double deg) => deg * math.pi / 180.0;
}