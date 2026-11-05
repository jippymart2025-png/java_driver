// import 'dart:async';
// import 'dart:convert';
//
// import 'package:jippydriver_driver/constant/constant.dart';
// import 'package:jippydriver_driver/constant/send_notification.dart';
// import 'package:jippydriver_driver/models/order_model.dart';
// import 'package:jippydriver_driver/models/user_model.dart';
// import 'package:jippydriver_driver/services/auth_http_client.dart';
// import 'package:jippydriver_driver/services/http_client_service.dart';
// import 'package:jippydriver_driver/utils/app_logger.dart';
// import 'package:jippydriver_driver/utils/common.dart';
// import 'package:jippydriver_driver/utils/fire_store_utils.dart';
//
// /// Centralizes multi-step order workflows so controllers don't diverge.
// ///
// /// Notes:
// /// - This service focuses on backend orchestration + model mutation.
// /// - UI-only responsibilities (sounds, dialogs, navigation, local mute flags)
// ///   remain in the calling controllers/widgets.
// class OrderWorkflowService {
//   const OrderWorkflowService();
//
//   /// Backend endpoint that accepts / rejects a driver order and advances the
//   /// order through the driver workflow.
//   ///
//   /// `GET {baseUrl}/api/driver/acceptOrRejectOrderByDriver?orderId=...&driverId=...&status=...&driverLatitude=...&driverLongitude=...`
//   static const String _acceptOrRejectEndpoint =
//       'driver/acceptOrRejectOrderByDriver';
//   static const Duration _workflowTimeout = Duration(seconds: 10);
//
//   /// Single entry point for every driver-driven order status transition.
//   ///
//   /// Talks to the Java backend `acceptOrRejectOrderByDriver` endpoint:
//   ///
//   /// ```text
//   /// {baseUrl}/api/driver/acceptOrRejectOrderByDriver?orderId=jippy202610222&driverId=1&status=ACCEPT&driverLatitude=16.3080&driverLongitude=80.449.0
//   /// ```
//   ///
//   /// The endpoint accepts the following status tokens:
//   /// - `ACCEPT` / `REJECT` -> driver answers a queued order (FCFS assignment)
//   /// - `DRIVER_REACHED`    -> driver reached the pickup / delivery location
//   /// - `DRIVER_PICKS_UP`   -> driver picked the order up
//   /// - `ORDER_COMPLETED`   -> delivery / order completed
//   /// - `WAITING_FOR_DRIVER`-> order is waiting for a driver
//   ///
//   /// The backend responds with `{ "statusCode": "...", "statusMsg": "..." }`.
//   ///
//   /// Returns:
//   /// - `null` when the backend rate-limited (HTTP 429) the call - caller may retry
//   /// - `true` when the status transition was accepted
//   /// - `false` when it was rejected / the backend returned an error
//   static Future<bool?> updateOrderStatusByDriver({
//     required String orderId,
//     required String status,
//     required UserModel driverModel,
//     double? driverLatitude,
//     double? driverLongitude,
//   }) async {
//     final id = orderId.trim();
//     final driverId = driverModel.id?.toString().trim() ?? '';
//     if (id.isEmpty || driverId.isEmpty) return false;
//
//     double? latitude = driverLatitude;
//     double? longitude = driverLongitude;
//     final driverLocation = driverModel.location;
//     if ((latitude == null || longitude == null) && driverLocation != null) {
//       latitude = latitude ?? driverLocation.latitude;
//       longitude = longitude ?? driverLocation.longitude;
//     }
//     if ((latitude == null || longitude == null) && Constant.locationDataFinal != null) {
//       latitude = latitude ?? Constant.locationDataFinal!.latitude;
//       longitude = longitude ?? Constant.locationDataFinal!.longitude;
//     }
//
//     try {
//       final queryParams = <String, String>{
//         'orderId': id,
//         'driverId': driverId,
//         'status': status,
//         'driverLatitude': latitude?.toString() ?? '',
//         'driverLongitude': longitude?.toString() ?? '',
//       };
//       final uri = Uri.parse('${Constant.baseUrl}$_acceptOrRejectEndpoint')
//           .replace(queryParameters: queryParams);
//
//       var response = await AuthHttpClient().get(
//         uri,
//         headers: const {'Accept': 'application/json'},
//         timeout: _workflowTimeout,
//       );
//
//       // Some deployments expose this endpoint as POST instead of GET. Retry
//       // only for method-related responses so normal 4xx errors are not hidden.
//       if (_isMethodNotAllowed(response.statusCode)) {
//         response = await AuthHttpClient().post(
//           uri,
//           headers: await getHeaders(),
//           body: jsonEncode(queryParams),
//           timeout: _workflowTimeout,
//         );
//       }
//
//       // 429 / retry needed
//       if (response.statusCode == 429) return null;
//
//       if (response.statusCode != 200 || response.body.startsWith('<')) {
//         AppLogger.log(
//           'Order status update failed (${response.statusCode}) for order $id '
//           'with status "$status": ${_safeBody(response.body)}',
//           tag: 'API',
//         );
//         return false;
//       }
//
//       final decoded = jsonDecode(response.body);
//       if (decoded is! Map) return false;
//
//       final root = Map<String, dynamic>.from(decoded);
//       final data = _unwrapWorkflowData(root);
//       final statusCode =
//           (data['statusCode'] ?? root['statusCode'] ?? '').toString().trim();
//       final accepted = _isSuccessfulWorkflowStatus(statusCode);
//
//       if (!accepted) {
//         AppLogger.log(
//           'Order status "$status" for order $id was not accepted by the '
//           'backend (statusCode: "$statusCode")',
//           tag: 'API',
//         );
//       }
//
//       return accepted;
//     } on TimeoutException {
//       AppLogger.log('Order status update timeout for $id: $status', tag: 'API');
//       return false;
//     } catch (e, st) {
//       AppLogger.log('Order status update error for $id: $e\n$st', tag: 'API');
//       return false;
//     }
//   }
//
//   /// Assigns [order] to [driverModel] using the backend accept endpoint.
//   ///
//   /// Returns:
//   /// - `null` when backend rate-limits (429)
//   /// - `true` when assignment succeeded
//   /// - `false` when order is no longer available / taken
//   static Future<bool?> acceptOrderBackend({
//     required OrderModel order,
//     required UserModel driverModel,
//   }) async {
//     final orderId = order.id?.toString().trim() ?? '';
//     final driverId = driverModel.id?.toString().trim() ?? '';
//     if (orderId.isEmpty || driverId.isEmpty) return false;
//
//     // Ask the Java backend to run the FCFS accept for this driver via
//     // `driver/acceptOrRejectOrderByDriver` (status=ACCEPT).
//     final result = await updateOrderStatusByDriver(
//       orderId: orderId,
//       status: Constant.backendOrderStatusAccept,
//       driverModel: driverModel,
//     );
//
//     // 429 / retry needed
//     if (result == null) return null;
//
//     // Clean up driver lists in all non-null cases.
//     driverModel.orderRequestData?.remove(orderId);
//
//     if (result == true) {
//       driverModel.inProgressOrderID ??= [];
//       driverModel.inProgressOrderID!.add(orderId);
//
//       // Update driver profile with new lists.
//       await FireStoreUtils.updateUser(driverModel);
//
//       // Invalidate relevant cached API responses.
//       final httpClient = HttpClientService();
//       await httpClient.invalidateCache('orders/$orderId');
//       await httpClient.invalidateCache('users/');
//
//       // Mutate order status for caller convenience.
//       order.status = Constant.driverAccepted;
//       order.driverID = driverId;
//       order.driver = driverModel;
//
//       return true;
//     }
//
//     // Assignment failed (already taken). Still update driver list on backend.
//     await FireStoreUtils.updateUser(driverModel);
//     final httpClient = HttpClientService();
//     await httpClient.invalidateCache('orders/$orderId');
//     await httpClient.invalidateCache('users/');
//
//     return false;
//   }
//
//   /// Rejects [order] for [driverModel] by removing it from this driver's queue only.
//   ///
//   /// Does not update the order document (status / rejectedByDrivers) so the job
//   /// can still be offered to other drivers with no "rejected" status churn.
//   static Future<void> rejectOrderBackend({
//     required OrderModel order,
//     required UserModel driverModel,
//   }) async {
//     final orderId = order.id?.toString().trim() ?? '';
//     final driverId = driverModel.id?.toString().trim() ?? '';
//     if (orderId.isEmpty || driverId.isEmpty) return;
//
//     driverModel.orderRequestData?.remove(orderId);
//
//     // Tell the Java backend via `driver/acceptOrRejectOrderByDriver`
//     // (status=REJECT) that this driver declined the order.
//     final result = await updateOrderStatusByDriver(
//       orderId: orderId,
//       status: Constant.backendOrderStatusReject,
//       driverModel: driverModel,
//     );
//
//     final httpClient = HttpClientService();
//     await httpClient.invalidateCache('orders/$orderId');
//     await httpClient.invalidateCache('users/');
//
//     if (result == false) {
//       // Backend could not process the rejection; keep the local driver list
//       // untouched so the order is not silently lost from the driver's queue.
//       driverModel.orderRequestData?.add(orderId);
//     }
//
//     await FireStoreUtils.updateUser(driverModel);
//   }
//
//   /// Completes a delivery [order] (wallet + order status + customer notification).
//   ///
//   /// Preconditions (expected to already be set by the caller):
//   /// - [order.status] will be set to `orderCompleted` inside this method
//   /// - [order.driverID] and [order.paymentMethod] must be non-null
//   /// - [order.toPay] must be set (used by wallet updates)
//   static Future<bool> completeDeliveryOrderBackend({
//     required OrderModel order,
//     required UserModel driverModel,
//   }) async {
//     final orderId = order.id?.toString().trim() ?? '';
//     if (orderId.isEmpty) return false;
//
//     // Ensure driver id is present for downstream backend operations.
//     order.driverID ??= driverModel.id?.toString();
//     final assignedDriverId = order.driverID?.toString().trim() ?? '';
//     if (assignedDriverId.isEmpty) return false;
//
//     order.status = Constant.orderCompleted;
//
//     // 1) Wallet update + order completion persistence.
//     await FireStoreUtils.updateWallateAmount(order);
//     await FireStoreUtils.setOrder(order);
//
//     // 2) Remove the completed order from other drivers.
//     await FireStoreUtils.removeOrderFromOtherDrivers(
//       orderId: orderId,
//       assignedDriverId: assignedDriverId,
//     );
//
//     // 3) Update driver request/in-progress lists without overwriting
//     //    wallet/delivery amounts managed by separate APIs.
//     final userForUpdate = (Constant.userModel ?? driverModel);
//     userForUpdate.orderRequestData?.remove(orderId);
//     userForUpdate.inProgressOrderID?.remove(orderId);
//
//     // await FireStoreUtils.updateUserWithoutWalletDelivery(userForUpdate);
//
//     // Refresh user to reflect the wallet/delivery mutations from separate APIs.
//     final refreshedUser = await FireStoreUtils.getUserProfile(
//       userForUpdate.id ?? '',
//       forceRefresh: true,
//     );
//     if (refreshedUser != null) {
//       Constant.userModel = refreshedUser;
//     }
//
//     // 4) Referral bonus (if this is the driver's first completed order).
//     final isFirst = await FireStoreUtils.getFirestOrderOrNOt(order);
//     if (isFirst == true) {
//       await FireStoreUtils.updateReferralAmount(order);
//     }
//
//     // 5) Notify customer.
//     String token = order.author?.fcmToken?.toString().trim() ?? '';
//     final customerId =
//         order.authorID?.toString() ??
//             order.author?.id?.toString() ??
//             order.author?.firebaseId?.toString() ??
//             '';
//
//     if (customerId.isNotEmpty) {
//       final customer = await FireStoreUtils.getUserProfile(customerId);
//       if (customer?.fcmToken?.toString().trim().isNotEmpty == true) {
//         token = customer!.fcmToken!.toString().trim();
//       }
//     }
//
//     if (token.isNotEmpty) {
//       await SendNotification.sendFcmMessage(
//         Constant.driverCompleted,
//         token,
//         {
//           'order_id': order.id,
//           'status': Constant.orderCompleted,
//         },
//       );
//     }
//
//     return true;
//   }
//
//   // =========================================================================
//   //  Helpers - accept / reject status endpoint
//   // =========================================================================
//
//   static bool _isMethodNotAllowed(int statusCode) =>
//       statusCode == 405 || statusCode == 415;
//
//   /// The endpoint normally returns the `{statusCode, statusMsg}` payload
//   /// directly, but tolerate the common `{data: {...}}` / `{data: "{...}"}`
//   /// wrappers used by other controllers.
//   static Map<String, dynamic> _unwrapWorkflowData(
//     Map<String, dynamic> root,
//   ) {
//     final rawData = root['data'];
//     if (rawData is Map) {
//       return Map<String, dynamic>.from(rawData);
//     }
//     if (rawData is String && rawData.trim().startsWith('{')) {
//       try {
//         final decoded = jsonDecode(rawData);
//         if (decoded is Map) return Map<String, dynamic>.from(decoded);
//       } catch (_) {}
//     }
//     return root;
//   }
//
//   static bool _isSuccessfulWorkflowStatus(String statusCode) {
//     final normalized = statusCode.trim().toUpperCase();
//     if (normalized.isEmpty) return true;
//     return normalized == '200' ||
//         normalized == 'SUCCESS' ||
//         normalized == 'OK' ||
//         normalized == 'ACCEPTED';
//   }
//
//   static String _safeBody(String body) =>
//       body.length <= 300 ? body : '${body.substring(0, 300)}...';
// }
//



import 'dart:async';
import 'dart:convert';

import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/send_notification.dart';
import 'package:jippydriver_driver/models/driver_delivery_charge_model.dart';
import 'package:jippydriver_driver/models/order_model.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/services/auth_http_client.dart';
import 'package:jippydriver_driver/services/driver_delivery_charge_service.dart';
import 'package:jippydriver_driver/services/http_client_service.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:jippydriver_driver/utils/common.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';

/// Result of a driver order-status transition.
///
/// [success] keeps the previous semantics:
/// * `null` — the backend rate-limited the call (HTTP 429)
/// * `true` — accepted
/// * `false` — failed / rejected
///
/// [details] is populated when the backend response also contains the order
/// details DTO (the accept endpoint may return them directly).
class OrderWorkflowResult {
  final bool? success;
  final dynamic details;
  final String? errorCode;      // e.g. 'ALREADY_ACCEPTED', 'NO_LOCATION', 'GENERIC'
  final String? errorMessage;

  const OrderWorkflowResult({
    this.success,
    this.details,
    this.errorCode,
    this.errorMessage,
  });

  @override
  String toString() =>
      'OrderWorkflowResult(success: $success, errorCode: $errorCode, '
          'errorMessage: $errorMessage)';
}
/// Centralized backend order workflow.
class OrderWorkflowService {
  const OrderWorkflowService();

  static const String _acceptOrRejectEndpoint =
      'driver/acceptOrRejectOrderByDriver';

  /// Updates an order status by outlet and driver. Used for the post-accept
  /// workflow transitions: `DRIVER_REACHED`, `DRIVER_PICKS_UP` and
  /// `ORDER_COMPLETED`.
  static const String _updateOrderStatusEndpoint = 'co/updateOrderStatus';

  static const Duration _workflowTimeout = Duration(seconds: 20);

  /// Builds an absolute API URL from [Constant.baseUrl], supporting both
  /// `http://host:8084/api/` and `http://host:8084/` formats.
  static Uri _apiUri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    String baseUrl = Constant.baseUrl.trim();

    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    final String endpoint = baseUrl.endsWith('/api')
        ? '$baseUrl/$path'
        : '$baseUrl/api/$path';

    final uri = Uri.parse(endpoint);

    return queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }

  // ============================================================
  // ACCEPT ORDER
  // ============================================================

  static Future<OrderWorkflowResult> acceptOrderBackend({
    required OrderModel order,
    required UserModel driverModel,
  }) async {
    final orderId = order.id?.toString().trim() ?? '';
    final driverId = driverModel.id?.toString().trim() ?? '';

    AppLogger.log(
      'acceptOrderBackend START | orderId=$orderId | driverId=$driverId',
      tag: 'OrderWorkflow',
    );

    if (orderId.isEmpty || driverId.isEmpty) {
      AppLogger.log(
        'API NOT CALLED: Order ID or Driver ID missing',
        tag: 'OrderWorkflow',
      );

      return const OrderWorkflowResult(success: false);
    }

    try {
      AppLogger.log(
        'Calling updateOrderStatusByDriver NOW | '
            'orderId=$orderId | status=ACCEPT',
        tag: 'OrderWorkflow',
      );

      // Actual Java Spring Boot API call.
      final result = await updateOrderStatusByDriver(
        orderId: orderId,
        status: 'ACCEPT',
        driverModel: driverModel,
      );

      AppLogger.log(
        'updateOrderStatusByDriver RESPONSE | '
            'success=${result.success} | orderId=$orderId',
        tag: 'OrderWorkflow',
      );

      if (result.success == null) {
        AppLogger.log(
          'API rate limited: $orderId',
          tag: 'OrderWorkflow',
        );

        return const OrderWorkflowResult(success: null);
      }

      if (result.success != true) {
        AppLogger.log(
          'API returned failure for order: $orderId',
          tag: 'OrderWorkflow',
        );

        return const OrderWorkflowResult(success: false);
      }

      // Update driver order lists.
      driverModel.orderRequestData ??= [];

      driverModel.orderRequestData!.removeWhere(
            (id) => id.toString() == orderId,
      );

      driverModel.inProgressOrderID ??= [];

      if (!driverModel.inProgressOrderID!.contains(orderId)) {
        driverModel.inProgressOrderID!.add(orderId);
      }

      // Update local order.
      order.status = Constant.driverAccepted;
      order.driverID = driverId;
      order.driver = driverModel;

      // These are follow-up operations, not the acceptance API itself.
      try {
        await FireStoreUtils.updateUser(driverModel);

        final httpClient = HttpClientService();

        await httpClient.invalidateCache('orders/$orderId');
        await httpClient.invalidateCache('users/');
      } catch (e) {
        AppLogger.log(
          'Post-accept sync/cache error: $e',
          tag: 'OrderWorkflow',
        );
      }

      AppLogger.log(
        'Order $orderId successfully accepted by driver $driverId',
        tag: 'OrderWorkflow',
      );

      return OrderWorkflowResult(
        success: true,
        details: result.details,
      );
    } catch (e, stackTrace) {
      AppLogger.log(
        'acceptOrderBackend API exception: $e\n$stackTrace',
        tag: 'OrderWorkflow',
      );

      rethrow;
    }
  }
  // ============================================================
  // REJECT ORDER
  // ============================================================

  static Future<bool?> rejectOrderBackend({
    required OrderModel order,
    required UserModel driverModel,
    String reason = 'Rejected by driver',
  }) async {
    final orderId = order.id?.toString().trim() ?? '';
    final driverId = driverModel.id?.toString().trim() ?? '';

    if (orderId.isEmpty || driverId.isEmpty) {
      AppLogger.log(
        'Order ID or Driver ID missing',
        tag: 'OrderWorkflow',
      );
      return false;
    }

    // Call Java Spring Boot API.
    final result = await updateOrderStatusByDriver(
      orderId: orderId,
      status: 'REJECT',
      driverModel: driverModel,
      reason: reason,
    );

    // Preserve the local order if the API fails.
    if (result.success != true) {
      AppLogger.log(
        'Order $orderId rejection failed',
        tag: 'OrderWorkflow',
      );
      return result.success;
    }

    // Remove order only after successful backend response.
    driverModel.orderRequestData?.remove(orderId);

    await FireStoreUtils.updateUser(driverModel);

    // Invalidate cache.
    final httpClient = HttpClientService();

    await httpClient.invalidateCache('orders/$orderId');
    await httpClient.invalidateCache('users/');

    AppLogger.log(
      'Order $orderId successfully rejected by driver $driverId',
      tag: 'OrderWorkflow',
    );

    return true;
  }

  // ============================================================
  // COMMON ACCEPT / REJECT API
  // ============================================================

  static Future<OrderWorkflowResult> updateOrderStatusByDriver({
    required String orderId,
    required String status,
    required UserModel driverModel,
    double? driverLatitude,
    double? driverLongitude,
    String? reason,
  }) async {
    final id = orderId.trim();
    final driverId = driverModel.id?.toString().trim() ?? '';

    if (id.isEmpty || driverId.isEmpty) {
      return const OrderWorkflowResult(success: false);
    }

    try {
      // Get driver's current coordinates from available location data.
      double? latitude = driverLatitude;
      double? longitude = driverLongitude;

      final driverLocation = driverModel.location;

      if (driverLocation != null) {
        latitude ??= driverLocation.latitude;
        longitude ??= driverLocation.longitude;
      }

      // Fallback to the application's current location.
      if (latitude == null || longitude == null) {
        final location = Constant.locationDataFinal;

        if (location != null) {
          latitude ??= location.latitude;
          longitude ??= location.longitude;
        }
      }

      if (latitude == null || longitude == null) {
        AppLogger.log(
          'Driver latitude or longitude unavailable',
          tag: 'OrderWorkflow',
        );
        return const OrderWorkflowResult(success: false);
      }

      // Prepare query parameters exactly as defined in Swagger.
      final queryParams = <String, String>{
        'orderId': id,
        'driverId': driverId,
        'status': status,
        // 'driverLatitude': latitude.toString(),
        // 'driverLongitude': longitude.toString(),
        'driverLatitude': "16.3080",
        'driverLongitude': "80.4490",
      };

      if (reason != null && reason.trim().isNotEmpty) {
        queryParams['reason'] = reason.trim();
      }

      // Support both Constant.baseUrl formats:
      // http://host:8084/api/
      // http://host:8084/
      final uri = _apiUri(
        _acceptOrRejectEndpoint,
        queryParameters: queryParams,
      );

      AppLogger.log(
        'Calling driver order API: $uri',
        tag: 'OrderWorkflow',
      );

      // IMPORTANT: POST request with existing authentication headers.
      final response = await AuthHttpClient().post(
        uri,
        headers: await getHeaders(),
        timeout: _workflowTimeout,
      );

      AppLogger.log(
        'Driver API status: ${response.statusCode}',
        tag: 'OrderWorkflow',
      );

      AppLogger.log(
        'Driver API response: ${response.body}',
        tag: 'OrderWorkflow',
      );

      // Rate limit.
      if (response.statusCode == 429) {
        return const OrderWorkflowResult(success: null);
      }

      // HTTP failure.
      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        AppLogger.log(
          'API failed: ${response.statusCode} ${response.body}',
          tag: 'OrderWorkflow',
        );
        return const OrderWorkflowResult(success: false);
      }

      // Some successful endpoints return an empty response.
      if (response.body.trim().isEmpty) {
        return const OrderWorkflowResult(success: true);
      }

      if (response.body.trim().startsWith('<')) {
        AppLogger.log(
          'Unexpected HTML response from driver API',
          tag: 'OrderWorkflow',
        );
        return const OrderWorkflowResult(success: false);
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        return const OrderWorkflowResult(success: true);
      }

      final root = Map<String, dynamic>.from(decoded);
      final details = DriverDeliveryChargeService.parsePayload(
        root,
        fallbackOrderId: id,
      );

      final data = _unwrapWorkflowData(root);

      final statusCode =
      (data['statusCode'] ?? root['statusCode'] ?? '')
          .toString()
          .trim();

      final statusMessage =
      (data['statusMsg'] ?? root['statusMsg'] ?? '')
          .toString();

      AppLogger.log(
        'Backend statusCode: $statusCode, message: $statusMessage',
        tag: 'OrderWorkflow',
      );

      return OrderWorkflowResult(
        success: _isSuccessfulWorkflowStatus(statusCode),
        details: details,
      );
    } on TimeoutException {
      AppLogger.log(
        'Driver order API timeout: $id ($status)',
        tag: 'OrderWorkflow',
      );
      return const OrderWorkflowResult(success: false);
    } catch (e, stackTrace) {
      AppLogger.log(
        'Driver order API exception: $e\n$stackTrace',
        tag: 'OrderWorkflow',
      );
      return const OrderWorkflowResult(success: false);
    }
  }

  // ============================================================
  // POST-ACCEPT STATUS API (co/updateOrderStatus)
  // ============================================================

  /// Updates the order status through `POST /api/co/updateOrderStatus`.
  ///
  /// The backend expects a JSON body such as:
  /// ```json
  /// {"orderId":"jippy202610232","driverId":1,"orderStatus":"ORDER_COMPLETED","outletId":37}
  /// ```
  /// `driverId` and `outletId` are only sent when they are numeric because
  /// the backend DTO declares them as integers.
  static Future<bool> updateOrderStatusByOutletAndDriver({
    required String orderId,
    required String orderStatus,
    UserModel? driverModel,
    String? driverId,
    String? outletId,
  }) async {
    final id = orderId.trim();
    final status = orderStatus.trim();

    if (id.isEmpty || status.isEmpty) {
      AppLogger.log(
        'Order ID or order status missing for co/updateOrderStatus',
        tag: 'OrderWorkflow',
      );
      return false;
    }

    final resolvedDriverId = driverId?.trim().isNotEmpty == true
        ? driverId!.trim()
        : driverModel?.id?.toString().trim() ?? '';

    final body = <String, dynamic>{
      'orderId': id,
      'orderStatus': status,
    };

    final numericDriverId = int.tryParse(resolvedDriverId);
    if (numericDriverId != null) {
      body['driverId'] = numericDriverId;
    }

    final numericOutletId = int.tryParse(outletId?.trim() ?? '');
    if (numericOutletId != null) {
      body['outletId'] = numericOutletId;
    }

    try {
      final uri = _apiUri(_updateOrderStatusEndpoint);
      final encodedBody = jsonEncode(body);

      AppLogger.log(
        'Calling co/updateOrderStatus: $uri body=$encodedBody',
        tag: 'OrderWorkflow',
      );

      final response = await AuthHttpClient().put(
        uri,
        headers: await getHeaders(),
        body: encodedBody,
        timeout: _workflowTimeout,
      );

      AppLogger.log(
        'co/updateOrderStatus status: ${response.statusCode}',
        tag: 'OrderWorkflow',
      );

      AppLogger.log(
        'co/updateOrderStatus response: ${response.body}',
        tag: 'OrderWorkflow',
      );

      if (response.statusCode == 429) return false;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        AppLogger.log(
          'co/updateOrderStatus failed: ${response.statusCode} ${response.body}',
          tag: 'OrderWorkflow',
        );
        return false;
      }

      if (response.body.trim().isEmpty) return true;

      if (response.body.trim().startsWith('<')) {
        AppLogger.log(
          'Unexpected HTML response from co/updateOrderStatus',
          tag: 'OrderWorkflow',
        );
        return false;
      }

      final decoded = () {
        try {
          return jsonDecode(response.body);
        } catch (_) {
          return null;
        }
      }();

      // Some backends return a plain-text "SUCCESS" instead of JSON.
      if (decoded == null) {
        final text = response.body.trim().toLowerCase();
        return text != 'failed' &&
            text != 'failure' &&
            text != 'error';
      }

      if (decoded is! Map) return true;

      final root = Map<String, dynamic>.from(decoded);
      final data = _unwrapWorkflowData(root);

      final explicitSuccess = data['success'] ?? root['success'];
      if (explicitSuccess is bool) return explicitSuccess;

      final statusCode =
          (data['statusCode'] ?? root['statusCode'] ?? '')
              .toString()
              .trim();

      if (statusCode.isEmpty) return true;

      final numericCode = int.tryParse(statusCode);
      final normalized = statusCode.toLowerCase();

      final isApiFailure = (numericCode != null && numericCode != 200) ||
          normalized == 'failed' ||
          normalized == 'failure' ||
          normalized == 'error';

      return !isApiFailure;
    } on TimeoutException {
      AppLogger.log(
        'co/updateOrderStatus timeout: $id ($status)',
        tag: 'OrderWorkflow',
      );
      return false;
    } catch (e, stackTrace) {
      AppLogger.log(
        'co/updateOrderStatus exception: $e\n$stackTrace',
        tag: 'OrderWorkflow',
      );
      return false;
    }
  }

  /// High-level status transition used by the driver UI.
  ///
  /// Calls the new `co/updateOrderStatus` endpoint first and falls back to the
  /// legacy `driver/acceptOrRejectOrderByDriver` endpoint so a transient failure
  /// in one route does not leave the local UI out of sync with the backend.
  static Future<bool> updateDriverWorkflowStatus({
    required String orderId,
    required String orderStatus,
    UserModel? driverModel,
    String? outletId,
  }) async {
    final result = await updateOrderStatusByOutletAndDriver(
      orderId: orderId,
      orderStatus: orderStatus,
      driverModel: driverModel,
      outletId: outletId,
    );

    if (result) return true;

    final fallbackDriver = driverModel ?? Constant.userModel;
    if (fallbackDriver == null) return false;

    AppLogger.log(
      'co/updateOrderStatus failed for $orderId ($orderStatus); '
      'falling back to driver/acceptOrRejectOrderByDriver',
      tag: 'OrderWorkflow',
    );

    final fallback = await updateOrderStatusByDriver(
      orderId: orderId,
      status: orderStatus,
      driverModel: fallbackDriver,
    );

    return fallback.success == true;
  }

  // ============================================================
  // COMPLETE DELIVERY ORDER
  // ============================================================

  static Future<bool> completeDeliveryOrderBackend({
    required OrderModel order,
    required UserModel driverModel,
  }) async {
    final orderId = order.id?.toString().trim() ?? '';

    if (orderId.isEmpty) return false;

    order.driverID ??= driverModel.id?.toString();

    final assignedDriverId =
        order.driverID?.toString().trim() ?? '';

    if (assignedDriverId.isEmpty) return false;

    order.status = Constant.orderCompleted;

    // Update wallet and order.
    await FireStoreUtils.updateWallateAmount(order);
    await FireStoreUtils.setOrder(order);

    // Remove completed order from other drivers.
    await FireStoreUtils.removeOrderFromOtherDrivers(
      orderId: orderId,
      assignedDriverId: assignedDriverId,
    );

    // Update driver request lists.
    final userForUpdate = Constant.userModel ?? driverModel;

    userForUpdate.orderRequestData?.remove(orderId);
    userForUpdate.inProgressOrderID?.remove(orderId);

    // Refresh driver profile.
    final refreshedUser = await FireStoreUtils.getUserProfile(
      userForUpdate.id ?? '',
      forceRefresh: true,
    );

    if (refreshedUser != null) {
      Constant.userModel = refreshedUser;
    }

    // Referral bonus for first completed order.
    final isFirst = await FireStoreUtils.getFirestOrderOrNOt(order);

    if (isFirst == true) {
      await FireStoreUtils.updateReferralAmount(order);
    }

    // Notify customer.
    String token =
        order.author?.fcmToken?.toString().trim() ?? '';

    final customerId =
        order.authorID?.toString() ??
            order.author?.id?.toString() ??
            order.author?.firebaseId?.toString() ??
            '';

    if (customerId.isNotEmpty) {
      final customer =
      await FireStoreUtils.getUserProfile(customerId);

      if (customer?.fcmToken?.toString().trim().isNotEmpty == true) {
        token = customer!.fcmToken!.toString().trim();
      }
    }

    if (token.isNotEmpty) {
      await SendNotification.sendFcmMessage(
        Constant.driverCompleted,
        token,
        {
          'order_id': order.id,
          'status': Constant.orderCompleted,
        },
      );
    }

    return true;
  }

  // ============================================================
  // RESPONSE HELPERS
  // ============================================================

  static Map<String, dynamic> _unwrapWorkflowData(
      Map<String, dynamic> root,
      ) {
    final rawData = root['data'];

    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }

    if (rawData is String &&
        rawData.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(rawData);

        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    return root;
  }

  static bool _isSuccessfulWorkflowStatus(String statusCode) {
    final normalized = statusCode.trim().toUpperCase();

    if (normalized.isEmpty) return true;

    return normalized == '200' ||
        normalized == 'SUCCESS' ||
        normalized == 'OK' ||
        normalized == 'ACCEPTED';
  }
}
