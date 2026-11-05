import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/models/driver_delivery_charge_model.dart';
import 'package:jippydriver_driver/services/auth_http_client.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:jippydriver_driver/utils/common.dart';

/// Calls the Java backend endpoint that returns the driver-specific pickup /
/// delivery charges and the outlet / customer details for an order.
///
/// The backend expects the driver coordinates + order id as query parameters
/// on a `GET` request.
class DriverDeliveryChargeService {
  DriverDeliveryChargeService._();

  static const String _endpoint = 'driver/getDriverDeliveryChargesForOrder';
  static const Duration _timeout = Duration(seconds: 15);

  /// Keys that prove a payload contains real order details rather than just a
  /// workflow status (`{"statusCode":"200","statusMsg":"..."}`).
  static const List<String> _detailKeys = <String>[
    'pickupDistanceKm',
    'deliveryDistanceKm',
    'pickupCharge',
    'deliveryCharge',
    'taxAmount',
    'totalDriverCharge',
    'outletName',
    'outletPhoneNumber',
    'outletAddress',
    'outletLatitude',
    'outletLongitude',
    'customerName',
    'customerPhoneNumber',
    'customerAddress',
    'customerLatitude',
    'customerLongitude',
    'orderTotalAmount',
    'codAvailable',
    'itemsList',
    'items',
    'manifestItems',
  ];

  static Future<DriverDeliveryChargeModel?> fetchForOrder({
    required String orderId,
    required double driverLatitude,
    required double driverLongitude,
  }) async {
    final id = orderId.trim();
    if (id.isEmpty) return null;

    final queryParams = <String, String>{
      // 'driverLatitude': driverLatitude.toString(),
      // 'driverLongitude': driverLongitude.toString(),
      'driverLatitude': "16.3087",
      'driverLongitude': "80.4385",
      'orderId': id,
    };

    try {
      // The backend binds the driver coordinates + order id as query
      // parameters, so send them that way instead of a GET body (a GET body is
      // rejected with 400 by the running Java backend).
      final url = Uri.parse('${Constant.baseUrl}$_endpoint')
          .replace(queryParameters: queryParams);
      var response = await AuthHttpClient().get(
        url,
        headers: await getHeaders(),
        timeout: _timeout,
      );

      // Some deployments expose the endpoint as POST instead of GET. Retry
      // only for method-related responses so normal 4xx errors are not hidden.
      if (_isMethodNotAllowed(response.statusCode)) {
        AppLogger.log(
          'Delivery charges GET returned ${response.statusCode}; retrying as POST',
          tag: 'API',
        );
        response = await AuthHttpClient().post(
          url,
          headers: await getHeaders(),
          body: jsonEncode(queryParams),
          timeout: _timeout,
        );
      }

      if (response.statusCode != 200) {
        AppLogger.log(
          'Delivery charges failed (${response.statusCode}) for order $id: '
          '${_safeBody(response.body)}',
          tag: 'API',
        );
        return null;
      }

      final model = parseResponseBody(response.body, fallbackOrderId: id);
      if (model == null) {
        AppLogger.log(
          'Delivery charges response had no order details for order $id',
          tag: 'API',
        );
        return null;
      }

      AppLogger.log(
        'Delivery charges loaded for order $id: pickup '
        '${model.pickupDistanceKm}km/delivery ${model.deliveryDistanceKm}km, '
        'driver charge ${model.effectiveDriverCharge}',
        tag: 'API',
      );
      return model;
    } on SocketException catch (e) {
      AppLogger.log('Delivery charges network error: $e', tag: 'API');
    } on TimeoutException catch (e) {
      AppLogger.log('Delivery charges timeout: $e', tag: 'API');
    } catch (e, st) {
      AppLogger.log('Delivery charges error: $e\n$st', tag: 'API');
    }

    return null;
  }

  /// Parses a raw JSON response body. Used by the delivery-charge endpoint and
  /// by the accept-order endpoint, which may return the same DTO directly.
  static DriverDeliveryChargeModel? parseResponseBody(
    String body, {
    String fallbackOrderId = '',
  }) {
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.startsWith('<')) return null;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) return null;
      return parsePayload(
        Map<String, dynamic>.from(decoded),
        fallbackOrderId: fallbackOrderId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Parses an already-decoded payload. Tolerates the common `{data: {...}}`
  /// and `{data: "{...}"}` wrappers used by the backend.
  static DriverDeliveryChargeModel? parsePayload(
    Map<String, dynamic> root, {
    String fallbackOrderId = '',
  }) {
    Map<String, dynamic>? nested;
    final rawData = root['data'];
    if (rawData is Map) {
      nested = Map<String, dynamic>.from(rawData);
    } else if (rawData is String && rawData.trim().isNotEmpty) {
      try {
        final decodedData = jsonDecode(rawData);
        if (decodedData is Map) {
          nested = Map<String, dynamic>.from(decodedData);
        }
      } catch (_) {}
    }

    final data = nested ?? root;

    final statusCode = (data['statusCode'] ??
            root['statusCode'] ??
            data['status'] ??
            root['status'])
        ?.toString()
        .trim() ??
        '';
    // On this endpoint the same keys can carry the *order* status (e.g.
    // "DRIVER_PENDING") instead of an API result. Only treat HTTP-like
    // failures as errors so a valid order payload is not discarded.
    final numericCode = int.tryParse(statusCode);
    final normalizedStatus = statusCode.toLowerCase();
    final isApiFailure = (numericCode != null && numericCode != 200) ||
        normalizedStatus == 'failed' ||
        normalizedStatus == 'failure' ||
        normalizedStatus == 'error';
    if (isApiFailure) return null;

    // Ignore status-only responses. This keeps accept/reject responses that
    // only contain `statusCode`/`statusMsg` from clearing the popup values.
    if (!_hasOrderDetails(root) && !_hasOrderDetails(data)) return null;

    return DriverDeliveryChargeModel.fromJson(
      _hasOrderDetails(data) ? data : root,
      fallbackOrderId: fallbackOrderId,
    );
  }

  static bool _hasOrderDetails(Map<String, dynamic> map) =>
      _detailKeys.any(map.containsKey);

  static bool _isMethodNotAllowed(int statusCode) =>
      statusCode == 405 || statusCode == 415;

  static String _safeBody(String body) =>
      body.length <= 300 ? body : '${body.substring(0, 300)}...';
}
