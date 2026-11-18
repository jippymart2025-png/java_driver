import 'package:flutter_test/flutter_test.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/models/order_model.dart';
import 'package:jippydriver_driver/services/driver_delivery_charge_service.dart';
import 'package:jippydriver_driver/services/order_detail_service.dart';

void main() {
  group('OrderModel.mapStatus', () {
    test('treats a manually assigned order as an active (accepted) order', () {
      expect(
        OrderModel.mapStatus('DRIVER_MANUAL_ASSIGNMENT'),
        Constant.driverAccepted,
      );
    });

    test('keeps the existing accepted / in-progress mappings', () {
      expect(OrderModel.mapStatus('DRIVER_ACCEPTED'), Constant.driverAccepted);
      expect(OrderModel.mapStatus('DRIVER_REACHED'), Constant.orderShipped);
      expect(OrderModel.mapStatus('DRIVER_PICKS_UP'), Constant.orderInTransit);
    });

    test('builds an active order from the real manual-assignment response', () async {
      const body = '''
      {
        "pickupDistanceKm": 1.552,
        "deliveryDistanceKm": 3.00,
        "pickupCharge": 15.52,
        "deliveryCharge": 0.00,
        "taxAmount": 0.00,
        "totalDriverCharge": 15.52,
        "codAvailable": true,
        "outletName": "pullaReddy",
        "outletPhoneNumber": "9653269864",
        "outletAddress": "94-26, tgh64h, tg544gy",
        "outletLatitude": 16.2997,
        "outletLongitude": 80.4385,
        "customerName": "Ahivam",
        "customerPhoneNumber": "6362303308",
        "customerLatitude": 16.3177,
        "customerLongitude": 80.4385,
        "customerAddress": "Flat No:309, JNR Apartments",
        "tipAmount": 0.00,
        "orderTotalAmount": 246.50,
        "itemsList": [],
        "orderStatus": "DRIVER_MANUAL_ASSIGNMENT"
      }
      ''';

      final details = DriverDeliveryChargeService.parseResponseBody(
        body,
        fallbackOrderId: 'jippy202611127',
      );

      expect(details, isNotNull);
      final bundle = await OrderDetailService.fetchOrderBundle(
        'jippy202611127',
        knownDetails: details,
      );

      expect(bundle.order, isNotNull);
      expect(bundle.order!.id, 'jippy202611127');
      expect(bundle.order!.status, Constant.driverAccepted);
      expect(bundle.order!.vendor, isNotNull);
      expect(bundle.order!.address, isNotNull);
    });
  });
}
