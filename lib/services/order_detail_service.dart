import 'dart:async';
import 'dart:convert';

import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/models/order_model.dart';
import 'package:jippydriver_driver/services/auth_http_client.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';

/// Loads a single order from the Java backend.
///
/// The legacy driver endpoints (`driver/get-current-reject-accept` and
/// `restaurant/orders/{id}`) are not exposed by the running Java backend. The
/// customer/order service exposes
/// `GET /api/co/customers/getOrderCompleteDetails?orderId=...`, which returns
/// everything the driver popup needs (status, customer, outlet, items, price
/// breakup). This service is the single place that knows how to call it and
/// map it into [OrderModel].
class OrderDetailService {
  OrderDetailService._();

  static const String _endpoint = 'co/customers/getOrderCompleteDetails';
  static const Duration _timeout = Duration(seconds: 10);

  /// Returns the order, or `null` when it cannot be loaded. Callers may fall
  /// back to the legacy endpoints on `null`.
  static Future<OrderModel?> fetchOrder(String orderId) async {
    final id = orderId.trim();
    if (id.isEmpty) return null;

    try {
      final uri = Uri.parse(
        '${Constant.baseUrl}$_endpoint',
      ).replace(queryParameters: {'orderId': id});

      final response = await AuthHttpClient().get(
        uri,
        headers: const {'Accept': 'application/json'},
        timeout: _timeout,
      );

      if (response.statusCode != 200 || response.body.startsWith('<')) {
        AppLogger.log(
          'Order details failed (${response.statusCode}) for order $id: '
          '${_safeBody(response.body)}',
          tag: 'API',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;

      final root = Map<String, dynamic>.from(decoded);
      final data = _unwrapData(root);
      if (data.isEmpty) return null;

      final order = OrderModel.fromCompleteDetailsJson(data);
      if (order.id == null || order.id!.trim().isEmpty) return null;

      AppLogger.log(
        'Order details loaded for $id: status=${order.status}, '
        'vendor=${order.vendor?.title}, total=${order.toPay}',
        tag: 'API',
      );
      return order;
    } on TimeoutException catch (e) {
      AppLogger.log('Order details timeout for $id: $e', tag: 'API');
    } catch (e, st) {
      AppLogger.log('Order details error for $id: $e\n$st', tag: 'API');
    }

    return null;
  }

  /// The endpoint returns its DTO directly, but tolerate the common
  /// `{data: {...}}` / `{data: "{...}"}` wrappers used by other controllers.
  static Map<String, dynamic> _unwrapData(Map<String, dynamic> root) {
    final rawData = root['data'];
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }
    if (rawData is String && rawData.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(rawData);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return root;
  }

  static String _safeBody(String body) =>
      body.length <= 300 ? body : '${body.substring(0, 300)}...';
}
