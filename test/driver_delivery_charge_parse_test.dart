import 'package:flutter_test/flutter_test.dart';
import 'package:jippydriver_driver/services/driver_delivery_charge_service.dart';

void main() {
  group('DriverDeliveryChargeService.parseResponseBody', () {
    test('parses the order details DTO returned by the backend', () {
      const body = '''
      {
        "pickupDistanceKm": 1.2,
        "deliveryDistanceKm": 3.4,
        "pickupCharge": 12,
        "deliveryCharge": 30,
        "taxAmount": 2,
        "totalDriverCharge": 44,
        "codAvailable": true,
        "outletName": "Sample Outlet",
        "outletPhoneNumber": "9999999999",
        "outletAddress": "Outlet Street",
        "outletLatitude": 16.3,
        "outletLongitude": 80.4,
        "customerName": "Sample Customer",
        "customerPhoneNumber": "8888888888",
        "customerLatitude": 16.4,
        "customerLongitude": 80.5,
        "customerAddress": "Customer Street",
        "tipAmount": 10,
        "orderTotalAmount": 250,
        "orderStatus": "DRIVER_ACCEPTED",
        "itemsList": []
      }
      ''';

      final details = DriverDeliveryChargeService.parseResponseBody(
        body,
        fallbackOrderId: 'order-1',
      );

      expect(details, isNotNull);
      expect(details!.orderId, 'order-1');
      expect(details.statusCode, 'DRIVER_ACCEPTED');
      expect(details.pickupDistanceKm, 1.2);
      expect(details.deliveryDistanceKm, 3.4);
      expect(details.pickupCharge, 12);
      expect(details.deliveryCharge, 30);
      expect(details.taxAmount, 2);
      expect(details.totalDriverCharge, 44);
      expect(details.effectiveDriverCharge, 44);
      expect(details.codAvailable, isTrue);
      expect(details.outletName, 'Sample Outlet');
      expect(details.customerName, 'Sample Customer');
      expect(details.tipAmount, 10);
      expect(details.orderTotalAmount, 250);
    });

    test('parses details wrapped in a data object', () {
      const body = '''
      {
        "statusCode": "200",
        "data": {
          "orderId": "order-2",
          "pickupDistanceKm": 1,
          "deliveryDistanceKm": 2,
          "orderStatus": "DRIVER_PENDING"
        }
      }
      ''';

      final details = DriverDeliveryChargeService.parseResponseBody(body);

      expect(details, isNotNull);
      expect(details!.orderId, 'order-2');
      expect(details.statusCode, 'DRIVER_PENDING');
      expect(details.totalDriverCharge, 0);
      expect(details.effectiveDriverCharge, 0);
    });

    test('ignores status-only responses', () {
      const body = '{"statusCode":"200","statusMsg":"Accepted"}';

      final details = DriverDeliveryChargeService.parseResponseBody(
        body,
        fallbackOrderId: 'order-3',
      );

      expect(details, isNull);
    });
  });
}
