import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/send_notification.dart';
import 'package:jippydriver_driver/models/order_model.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/services/http_client_service.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';

/// Centralizes multi-step order workflows so controllers don't diverge.
///
/// Notes:
/// - This service focuses on backend orchestration + model mutation.
/// - UI-only responsibilities (sounds, dialogs, navigation, local mute flags)
///   remain in the calling controllers/widgets.
class OrderWorkflowService {
  const OrderWorkflowService();

  /// Assigns [order] to [driverModel] using the backend FCFS endpoint.
  ///
  /// Returns:
  /// - `null` when backend rate-limits (429)
  /// - `true` when assignment succeeded
  /// - `false` when order is no longer available / taken
  static Future<bool?> acceptOrderBackend({
    required OrderModel order,
    required UserModel driverModel,
  }) async {
    final orderId = order.id?.toString().trim() ?? '';
    final driverId = driverModel.id?.toString().trim() ?? '';
    if (orderId.isEmpty || driverId.isEmpty) return false;

    final result = await FireStoreUtils.assignOrderToDriverFCFS(
      orderId: orderId,
      driverId: driverId,
      driverModel: driverModel,
    );

    // 429 / retry needed
    if (result == null) return null;

    // Clean up driver lists in all non-null cases.
    driverModel.orderRequestData?.remove(orderId);

    if (result == true) {
      driverModel.inProgressOrderID ??= [];
      driverModel.inProgressOrderID!.add(orderId);

      // Update driver profile with new lists.
      await FireStoreUtils.updateUser(driverModel);

      // Invalidate relevant cached API responses.
      final httpClient = HttpClientService();
      await httpClient.invalidateCache('orders/$orderId');
      await httpClient.invalidateCache('users/');

      // Mutate order status for caller convenience.
      order.status = Constant.driverAccepted;
      order.driverID = driverId;
      order.driver = driverModel;

      return true;
    }

    // Assignment failed (already taken). Still update driver list on backend.
    await FireStoreUtils.updateUser(driverModel);
    final httpClient = HttpClientService();
    await httpClient.invalidateCache('orders/$orderId');
    await httpClient.invalidateCache('users/');

    return false;
  }

  /// Rejects [order] for [driverModel] by removing it from this driver's queue only.
  ///
  /// Does not update the order document (status / rejectedByDrivers) so the job
  /// can still be offered to other drivers with no "rejected" status churn.
  static Future<void> rejectOrderBackend({
    required OrderModel order,
    required UserModel driverModel,
  }) async {
    final orderId = order.id?.toString().trim() ?? '';
    final driverId = driverModel.id?.toString().trim() ?? '';
    if (orderId.isEmpty || driverId.isEmpty) return;

    driverModel.orderRequestData?.remove(orderId);

    final httpClient = HttpClientService();
    await httpClient.invalidateCache('orders/$orderId');
    await httpClient.invalidateCache('users/');

    await FireStoreUtils.updateUser(driverModel);
  }

  /// Completes a delivery [order] (wallet + order status + customer notification).
  ///
  /// Preconditions (expected to already be set by the caller):
  /// - [order.status] will be set to `orderCompleted` inside this method
  /// - [order.driverID] and [order.paymentMethod] must be non-null
  /// - [order.toPay] must be set (used by wallet updates)
  static Future<bool> completeDeliveryOrderBackend({
    required OrderModel order,
    required UserModel driverModel,
  }) async {
    final orderId = order.id?.toString().trim() ?? '';
    if (orderId.isEmpty) return false;

    // Ensure driver id is present for downstream backend operations.
    order.driverID ??= driverModel.id?.toString();
    final assignedDriverId = order.driverID?.toString().trim() ?? '';
    if (assignedDriverId.isEmpty) return false;

    order.status = Constant.orderCompleted;

    // 1) Wallet update + order completion persistence.
    await FireStoreUtils.updateWallateAmount(order);
    await FireStoreUtils.setOrder(order);

    // 2) Remove the completed order from other drivers.
    await FireStoreUtils.removeOrderFromOtherDrivers(
      orderId: orderId,
      assignedDriverId: assignedDriverId,
    );

    // 3) Update driver request/in-progress lists without overwriting
    //    wallet/delivery amounts managed by separate APIs.
    final userForUpdate = (Constant.userModel ?? driverModel);
    userForUpdate.orderRequestData?.remove(orderId);
    userForUpdate.inProgressOrderID?.remove(orderId);

    // await FireStoreUtils.updateUserWithoutWalletDelivery(userForUpdate);

    // Refresh user to reflect the wallet/delivery mutations from separate APIs.
    final refreshedUser = await FireStoreUtils.getUserProfile(
      userForUpdate.id ?? '',
      forceRefresh: true,
    );
    if (refreshedUser != null) {
      Constant.userModel = refreshedUser;
    }

    // 4) Referral bonus (if this is the driver's first completed order).
    final isFirst = await FireStoreUtils.getFirestOrderOrNOt(order);
    if (isFirst == true) {
      await FireStoreUtils.updateReferralAmount(order);
    }

    // 5) Notify customer.
    String token = order.author?.fcmToken?.toString().trim() ?? '';
    final customerId =
        order.authorID?.toString() ??
            order.author?.id?.toString() ??
            order.author?.firebaseId?.toString() ??
            '';

    if (customerId.isNotEmpty) {
      final customer = await FireStoreUtils.getUserProfile(customerId);
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
}

