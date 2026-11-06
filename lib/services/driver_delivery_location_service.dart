import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/services/http_client_service.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:jippydriver_driver/utils/perf_telemetry.dart';

/// Sends the driver's live location to the Java backend while an order is
/// being delivered.
///
/// The backend endpoint is:
///
/// ```text
/// POST /api/driver/updatedDriverDeliveryLocation
/// {
///   "driverId": 1,
///   "orderId": "jippy202610222",
///   "latitude": 16.3128,
///   "longitude": 80.4195
/// }
/// ```
///
/// Design notes:
/// - Tracking starts only after `DRIVER_PICKS_UP` and is stopped when the
///   delivery is completed or the active order changes.
/// - The latest GPS fix is supplied by the existing dashboard location stream
///   through [updateLocation]. This avoids opening a second GPS subscription.
/// - A periodic timer makes sure the server receives a heartbeat even when the
///   driver is stationary. Location events can also trigger a send, but never
///   more often than [updateInterval].
/// - Only one request can be in flight at a time, so slow networks cannot
///   build up a queue of stale updates.
class DriverDeliveryLocationService {
  DriverDeliveryLocationService._();

  static final DriverDeliveryLocationService instance =
      DriverDeliveryLocationService._();

  static const String _endpoint = 'driver/updatedDriverDeliveryLocation';
  static const Duration updateInterval = Duration(seconds: 10);
  static const Duration _requestTimeout = Duration(seconds: 8);
  static const Duration _freshFixAge = Duration(seconds: 25);
  static const Duration _usableFixAge = Duration(minutes: 2);
  static const Duration _freshFixRetryDelay = Duration(seconds: 30);

  Timer? _timer;
  String? _orderId;
  String? _driverId;

  double? _latitude;
  double? _longitude;
  DateTime? _fixAt;
  DateTime? _lastFixAttemptAt;

  DateTime? _lastAttemptAt;
  DateTime? _lastSentAt;
  bool _requestInFlight = false;
  int _consecutiveFailures = 0;

  String? get activeOrderId => _orderId;
  bool get isTracking => _orderId != null;
  DateTime? get lastSentAt => _lastSentAt;

  bool isTrackingOrder(String orderId) =>
      _orderId != null && _orderId == orderId.trim();

  /// Starts (or reuses) a tracking session for [orderId].
  ///
  /// Calling this repeatedly for the same order is safe and does not reset the
  /// timer or trigger an extra request.
  void start({required String orderId, String? driverId}) {
    final oid = orderId.trim();
    if (oid.isEmpty) return;

    final did =
        (driverId ??
                Constant.userModel?.id?.toString() ??
                Constant.userModel?.firebaseId ??
                '')
            .trim();
    if (did.isEmpty) {
      AppLogger.log(
        'Delivery location tracking not started: driver id missing for $oid',
        tag: 'Location',
      );
      return;
    }

    if (_orderId == oid && _driverId == did) {
      _scheduleTimer();
      return;
    }

    _cancelTimer();
    _orderId = oid;
    _driverId = did;
    _lastAttemptAt = null;
    _lastSentAt = null;
    _consecutiveFailures = 0;
    _seedLatestFix();

    AppLogger.log(
      'Delivery location tracking started for order $oid '
      '(driver $did, every ${updateInterval.inSeconds}s)',
      tag: 'Location',
    );

    _scheduleTimer();
    unawaited(_sendCurrentLocation());
  }

  /// Stops tracking. When [orderId] is provided, the call is ignored if a
  /// different order is currently being tracked.
  void stop({String? orderId}) {
    if (_orderId == null) return;

    final requestedId = orderId?.trim() ?? '';
    if (requestedId.isNotEmpty && requestedId != _orderId) return;

    final stoppedOrderId = _orderId;
    _cancelTimer();
    _orderId = null;
    _driverId = null;
    _lastAttemptAt = null;
    _consecutiveFailures = 0;

    AppLogger.log(
      'Delivery location tracking stopped for order $stoppedOrderId',
      tag: 'Location',
    );
  }

  /// Feeds the latest GPS fix from the dashboard location stream.
  ///
  /// This is intentionally cheap: it only stores the fix and, when a session is
  /// active and the 10-second window has elapsed, starts one non-blocking send.
  void updateLocation(
    double latitude,
    double longitude, {
    DateTime? timestamp,
  }) {
    if (!_isUsableCoordinate(latitude, longitude)) return;

    _latitude = latitude;
    _longitude = longitude;
    _fixAt = timestamp ?? DateTime.now();

    if (_orderId == null || _requestInFlight) return;

    final now = DateTime.now();
    final nextAllowedAt = _lastAttemptAt?.add(updateInterval);
    if (nextAllowedAt == null || !now.isBefore(nextAllowedAt)) {
      unawaited(_sendCurrentLocation());
    }
  }

  /// Sends the best available position immediately. Useful when the app
  /// returns to the foreground or when a pickup has just been confirmed.
  Future<void> sendNow() => _sendCurrentLocation(force: true);

  void _scheduleTimer() {
    if (_orderId == null || _timer != null) return;
    _timer = Timer.periodic(
      updateInterval,
      (_) => unawaited(_sendCurrentLocation()),
    );
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _seedLatestFix() {
    final live = Constant.locationDataFinal;
    if (_isUsableCoordinate(live?.latitude, live?.longitude)) {
      _latitude = live!.latitude;
      _longitude = live.longitude;
      _fixAt = DateTime.now();
      return;
    }

    final profile = Constant.userModel?.location;
    if (_isUsableCoordinate(profile?.latitude, profile?.longitude)) {
      _latitude = profile!.latitude;
      _longitude = profile.longitude;
      // Profile coordinates may be old, so mark them as unverified. The first
      // send will try to obtain a fresher platform fix.
      _fixAt = null;
    }
  }

  Future<void> _sendCurrentLocation({bool force = false}) async {
    if (_orderId == null || _requestInFlight || _driverId == null) return;

    final now = DateTime.now();
    if (!force &&
        _lastAttemptAt != null &&
        now.difference(_lastAttemptAt!) < updateInterval) {
      return;
    }

    _requestInFlight = true;
    _lastAttemptAt = now;

    try {
      final position = await _resolvePosition();
      if (position == null || _orderId == null) return;

      final orderId = _orderId!;
      final driverId = _driverId!;
      final body = buildRequestBody(
        driverId: driverId,
        orderId: orderId,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      final response = await HttpClientService().post(
        buildEndpointUri(),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
        useDeduplication: false,
        timeout: _requestTimeout,
        maxRetries: 1,
      );

      // The driver may have completed the order while this request was in
      // flight. Do not treat that as a tracking failure.
      if (_orderId != orderId) return;

      if (_isSuccessfulResponse(response)) {
        _lastSentAt = DateTime.now();
        _consecutiveFailures = 0;
        PerfTelemetry.inc('driver_location_updates');
      } else {
        _recordFailure(
          'HTTP ${response.statusCode} for order $orderId: '
          '${_safeBody(response.body)}',
        );
      }
    } on TimeoutException {
      _recordFailure('Request timed out for order $_orderId');
    } catch (e) {
      _recordFailure('Request failed for order $_orderId: $e');
    } finally {
      _requestInFlight = false;
    }
  }

  Future<({double latitude, double longitude})?> _resolvePosition() async {
    final now = DateTime.now();

    if (_isUsableCoordinate(_latitude, _longitude) &&
        _fixAt != null &&
        now.difference(_fixAt!) <= _freshFixAge) {
      return (latitude: _latitude!, longitude: _longitude!);
    }

    if (!await _hasLocationPermission()) {
      // Fall back to the last known fix rather than repeatedly asking for
      // permission. This keeps the polling loop silent and battery friendly.
      if (_isUsableCoordinate(_latitude, _longitude) &&
          _fixAt != null &&
          now.difference(_fixAt!) <= _usableFixAge) {
        return (latitude: _latitude!, longitude: _longitude!);
      }
      return null;
    }

    // Asking the platform for a fresh fix every 10 seconds is expensive.
    // Reuse the cached fix while it is still useful, and retry a fresh fix at
    // most once per [_freshFixRetryDelay].
    final lastAttempt = _lastFixAttemptAt;
    if (lastAttempt != null &&
        now.difference(lastAttempt) < _freshFixRetryDelay) {
      return _usableCachedPosition();
    }
    _lastFixAttemptAt = now;

    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (_isUsableCoordinate(lastKnown?.latitude, lastKnown?.longitude)) {
        final age = now.difference(lastKnown!.timestamp);
        if (age <= _usableFixAge) {
          _setFix(lastKnown.latitude, lastKnown.longitude, lastKnown.timestamp);
          return (latitude: lastKnown.latitude, longitude: lastKnown.longitude);
        }
      }
    } catch (_) {
      // Last-known position is a best-effort optimisation only.
    }

    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _requestTimeout,
        ),
      );
      if (_isUsableCoordinate(current.latitude, current.longitude)) {
        _setFix(current.latitude, current.longitude, current.timestamp);
        return (latitude: current.latitude, longitude: current.longitude);
      }
    } catch (_) {
      // Fall through to the cached fix below.
    }

    return _usableCachedPosition();
  }

  ({double latitude, double longitude})? _usableCachedPosition() {
    if (!_isUsableCoordinate(_latitude, _longitude) || _fixAt == null) {
      return null;
    }
    if (DateTime.now().difference(_fixAt!) > _usableFixAge) return null;
    return (latitude: _latitude!, longitude: _longitude!);
  }

  void _setFix(double latitude, double longitude, DateTime? timestamp) {
    _latitude = latitude;
    _longitude = longitude;
    _fixAt = timestamp ?? DateTime.now();
  }

  Future<bool> _hasLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  void _recordFailure(String message) {
    _consecutiveFailures++;
    PerfTelemetry.inc('driver_location_update_failures');

    // Log the first failure and then every fifth one to avoid filling the
    // console while a driver is in a low-network area.
    if (_consecutiveFailures == 1 || _consecutiveFailures % 5 == 0) {
      AppLogger.log(
        '$message (failure #$_consecutiveFailures)',
        tag: 'Location',
      );
    }
  }

  static bool _isSuccessfulResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) return false;

    final body = response.body.trim();
    if (body.isEmpty || body.startsWith('<')) return body.isEmpty;

    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return true;

      final root = Map<String, dynamic>.from(decoded);
      final data = root['data'] is Map
          ? Map<String, dynamic>.from(root['data'] as Map)
          : root;

      final success = data['success'] ?? root['success'];
      if (success is bool) return success;

      final statusCode = (data['statusCode'] ?? root['statusCode'] ?? '')
          .toString()
          .trim();
      if (statusCode.isEmpty) return true;

      final numericCode = int.tryParse(statusCode);
      final normalized = statusCode.toLowerCase();
      return !((numericCode != null && numericCode != 200) ||
          normalized == 'failed' ||
          normalized == 'failure' ||
          normalized == 'error');
    } catch (_) {
      // A non-JSON 2xx response is still a successful update.
      return true;
    }
  }

  static bool _isUsableCoordinate(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    if (latitude == 0 && longitude == 0) return false;
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude.abs() <= 90 &&
        longitude.abs() <= 180;
  }

  /// Builds `{baseUrl}/api/driver/updatedDriverDeliveryLocation` for both
  /// supported base URL formats (`.../api/` and `.../`).
  static Uri buildEndpointUri({String? baseUrl}) {
    var base = (baseUrl ?? Constant.baseUrl).trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (!base.endsWith('/api')) {
      base = '$base/api';
    }
    return Uri.parse('$base/$_endpoint');
  }

  /// Request body for the backend. `driverId` is sent as a JSON number when it
  /// is numeric because the Java DTO declares it as an integer.
  static Map<String, dynamic> buildRequestBody({
    required String driverId,
    required String orderId,
    required double latitude,
    required double longitude,
  }) {
    final numericDriverId = int.tryParse(driverId.trim());
    return <String, dynamic>{
      'driverId': numericDriverId ?? driverId.trim(),
      'orderId': orderId.trim(),
      'latitude': double.parse(latitude.toStringAsFixed(6)),
      'longitude': double.parse(longitude.toStringAsFixed(6)),
    };
  }

  static String _safeBody(String body) =>
      body.length <= 200 ? body : '${body.substring(0, 200)}...';
}
