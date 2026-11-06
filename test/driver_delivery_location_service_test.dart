import 'package:flutter_test/flutter_test.dart';
import 'package:jippydriver_driver/services/driver_delivery_location_service.dart';

void main() {
  group('DriverDeliveryLocationService.buildEndpointUri', () {
    test('handles a base URL that already ends with /api/', () {
      final uri = DriverDeliveryLocationService.buildEndpointUri(
        baseUrl: 'http://10.0.2.2:8084/api/',
      );

      expect(
        uri.toString(),
        'http://10.0.2.2:8084/api/driver/updatedDriverDeliveryLocation',
      );
    });

    test('adds /api when the base URL only contains the host', () {
      final uri = DriverDeliveryLocationService.buildEndpointUri(
        baseUrl: 'http://10.0.2.2:8084/',
      );

      expect(
        uri.toString(),
        'http://10.0.2.2:8084/api/driver/updatedDriverDeliveryLocation',
      );
    });
  });

  group('DriverDeliveryLocationService.buildRequestBody', () {
    test('sends a numeric driver id and rounded coordinates', () {
      final body = DriverDeliveryLocationService.buildRequestBody(
        driverId: '1',
        orderId: ' jippy202610222 ',
        latitude: 16.312812345,
        longitude: 80.419545678,
      );

      expect(body, {
        'driverId': 1,
        'orderId': 'jippy202610222',
        'latitude': 16.312812,
        'longitude': 80.419546,
      });
    });

    test('keeps a non-numeric driver id as a string', () {
      final body = DriverDeliveryLocationService.buildRequestBody(
        driverId: 'driver-1',
        orderId: 'order-1',
        latitude: 16.3,
        longitude: 80.4,
      );

      expect(body['driverId'], 'driver-1');
    });
  });
}
