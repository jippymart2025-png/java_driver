import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/models/cart_product_model.dart';
import 'package:jippydriver_driver/models/driver_delivery_charge_model.dart';
import 'package:jippydriver_driver/models/order_model.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/models/vendor_model.dart';
import 'package:jippydriver_driver/services/driver_delivery_charge_service.dart';
import 'package:jippydriver_driver/utils/utils.dart';

/// Loads a single order from the Java backend.
///
/// The driver-facing order details are served by
/// `GET /api/driver/getDriverDeliveryChargesForOrder`, which returns the pickup
/// / delivery distances, driver charges, COD info, tip, order total and the
/// outlet + customer details the driver popup needs.
///
/// The legacy driver endpoints (`driver/get-current-reject-accept` and
/// `restaurant/orders/{id}`) are not exposed by the running Java backend, so
/// this service is the single place that knows how to call the delivery charges
/// API and map it into [OrderModel].
class OrderDetailService {
  OrderDetailService._();

  /// Returns the order, or `null` when it cannot be loaded. Callers may fall
  /// back to the legacy endpoints on `null`.
  static Future<OrderModel?> fetchOrder(String orderId) async {
    final id = orderId.trim();
    if (id.isEmpty) return null;

    final details = await DriverDeliveryChargeService.fetchForOrder(
      orderId: id,
      driverLatitude: await _resolveLatitude() ?? 0.0,
      driverLongitude: await _resolveLongitude() ?? 0.0,
    );

    if (details == null) return null;

    return _buildOrder(id, details);
  }

  static Future<double?> _resolveLatitude() async {
    final latitude = Constant.userModel?.location?.latitude ??
        Constant.locationDataFinal?.latitude;
    if (latitude != null) return latitude;
    final position = await Utils.getCurrentLocation();
    return position?.latitude;
  }

  static Future<double?> _resolveLongitude() async {
    final longitude = Constant.userModel?.location?.longitude ??
        Constant.locationDataFinal?.longitude;
    if (longitude != null) return longitude;
    final position = await Utils.getCurrentLocation();
    return position?.longitude;
  }

  /// Maps the `getDriverDeliveryChargesForOrder` DTO into the
  /// [OrderModel] shape used by the driver popup / home screen.
  static OrderModel _buildOrder(
    String orderId,
    DriverDeliveryChargeModel details,
  ) {
    final vendor = VendorModel()
      ..title = details.outletName.trim()
      ..location = details.outletAddress.trim()
      ..phonenumber = details.outletPhoneNumber.trim()
      ..latitude = details.outletLatitude
      ..longitude = details.outletLongitude;

    final hasCustomerLocation =
        details.customerLatitude != 0 && details.customerLongitude != 0;

    return OrderModel()
      ..id = details.orderId.isNotEmpty ? details.orderId : orderId
      ..status = OrderModel.mapStatus(details.statusCode)
      ..vendorID = details.outletName
      ..vendor = vendor
      ..address = ShippingAddress(
        address: details.customerAddress.trim(),
        location: hasCustomerLocation
            ? UserLocation(
                latitude: details.customerLatitude,
                longitude: details.customerLongitude,
              )
            : null,
      )
      ..deliveryCharge =
          details.deliveryCharge > 0 ? details.deliveryCharge.toString() : null
      ..tipAmount = details.tipAmount > 0 ? details.tipAmount.toString() : null
      ..toPay = details.orderTotalAmount > 0 ? details.orderTotalAmount.toString() : null
      ..pickUpDistanceInKms =
          details.pickupDistanceKm > 0 ? details.pickupDistanceKm : null
      ..deliveryDistanceInKms =
          details.deliveryDistanceKm > 0 ? details.deliveryDistanceKm : null
      ..pickUpCharges =
          details.pickupCharge > 0 ? details.pickupCharge : null
      ..deliverCharges =
          details.deliveryCharge > 0 ? details.deliveryCharge : null
      ..calculatedCharges = <String, dynamic>{
        'driverToRestaurantDistance': details.pickupDistanceKm,
        'driverToRestaurantCharge': details.pickupCharge,
        'restaurantToCustomerDistance': details.deliveryDistanceKm,
        'restaurantToCustomerCharge': details.deliveryCharge,
        'tipsAmount': details.tipAmount.toString(),
        'totalCalculatedCharge': details.effectiveDriverCharge.toString(),
      }
      ..products = details.products.isEmpty
          ? null
          : List<CartProductModel>.from(details.products);
  }
}
