import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/models/driver_delivery_charge_model.dart';
import 'package:jippydriver_driver/services/auth_http_client.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:jippydriver_driver/utils/common.dart';

/// Calls the Java backend endpoint that returns the driver-specific pickup /
/// delivery charges and the outlet / customer details for an order.
///
/// The endpoint is documented as `GET` with a JSON body, so a plain
/// `http.get` cannot be used (Dart's `http.get` does not support a body).
class DriverDeliveryChargeService {
  DriverDeliveryChargeService._();

  static const String _endpoint = 'driver/getDriverDeliveryChargesForOrder';
  static const Duration _timeout = Duration(seconds: 15);

  static Future<DriverDeliveryChargeModel?> fetchForOrder({
    required String orderId,
    required double driverLatitude,
    required double driverLongitude,
  }) async {
    final id = orderId.trim();
    if (id.isEmpty) return null;

    final body = jsonEncode({
      'driverLatitude': driverLatitude,
      'driverLongitude': driverLongitude,
      'orderId': id,
    });

    try {
      final url = Uri.parse('${Constant.baseUrl}$_endpoint');
      var response = await _getWithBody(url, body);

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
          body: body,
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

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;

      final root = Map<String, dynamic>.from(decoded);

      // The endpoint normally returns the DTO directly, but tolerate the
      // common `{data: {...}}` / `{data: "{...}"}` wrappers used elsewhere in
      // this backend.
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
      final normalisedStatus = statusCode.toLowerCase();
      final statusIsSuccess = statusCode.isEmpty ||
          statusCode == '200' ||
          normalisedStatus == 'success' ||
          normalisedStatus == 'ok';
      if (!statusIsSuccess) {
        AppLogger.log(
          'Delivery charges API returned status "$statusCode" for order $id',
          tag: 'API',
        );
        return null;
      }

      final model = DriverDeliveryChargeModel.fromJson(
        data,
        fallbackOrderId: id,
      );

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

  static bool _isMethodNotAllowed(int statusCode) =>
      statusCode == 405 || statusCode == 415;

  static Future<http.Response> _getWithBody(Uri url, String body) async {
    var headers = await getHeaders();

    Future<http.Response> send() async {
      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;
      final streamed = await request.send().timeout(_timeout);
      return http.Response.fromStream(streamed);
    }

    var response = await send();
    if (AuthHttpClient.isUnauthorized(response.statusCode)) {
      final refreshed = await AuthHttpClient.handleUnauthorized(response);
      if (refreshed) {
        headers = await getHeaders();
        response = await send();
      }
    }
    return response;
  }

  static String _safeBody(String body) =>
      body.length <= 300 ? body : '${body.substring(0, 300)}...';
}
