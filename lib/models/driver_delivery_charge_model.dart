/// Response model for
/// `GET /api/driver/getDriverDeliveryChargesForOrder`.
///
/// The backend returns the complete set of details the driver needs to see
/// before accepting / while handling an order:
///
/// ```json
/// {
///   "pickupDistanceKm": 1.2,
///   "deliveryDistanceKm": 3.4,
///   "pickupCharge": 12,
///   "deliveryCharge": 30,
///   "taxAmount": 2,
///   "totalDriverCharge": 44,
///   "codAvailable": true,
///   "outletName": "...",
///   "outletPhoneNumber": "...",
///   "outletAddress": "...",
///   "outletLatitude": 16.3,
///   "outletLongitude": 80.4,
///   "customerName": "...",
///   "customerPhoneNumber": "...",
///   "customerLatitude": 16.4,
///   "customerLongitude": 80.5,
///   "customerAddress": "...",
///   "tipAmount": 10,
///   "orderTotalAmount": 250
/// }
/// ```
class DriverDeliveryChargeModel {
  final String orderId;
  final String statusCode;
  final String statusMsg;

  final double pickupDistanceKm;
  final double deliveryDistanceKm;
  final double pickupCharge;
  final double deliveryCharge;
  final double taxAmount;
  final double totalDriverCharge;

  final bool codAvailable;

  final String outletName;
  final String outletPhoneNumber;
  final String outletAddress;
  final double outletLatitude;
  final double outletLongitude;

  final String customerName;
  final String customerPhoneNumber;
  final String customerAddress;
  final double customerLatitude;
  final double customerLongitude;

  final double tipAmount;
  final double orderTotalAmount;

  const DriverDeliveryChargeModel({
    this.orderId = '',
    this.statusCode = '',
    this.statusMsg = '',
    this.pickupDistanceKm = 0,
    this.deliveryDistanceKm = 0,
    this.pickupCharge = 0,
    this.deliveryCharge = 0,
    this.taxAmount = 0,
    this.totalDriverCharge = 0,
    this.codAvailable = false,
    this.outletName = '',
    this.outletPhoneNumber = '',
    this.outletAddress = '',
    this.outletLatitude = 0,
    this.outletLongitude = 0,
    this.customerName = '',
    this.customerPhoneNumber = '',
    this.customerAddress = '',
    this.customerLatitude = 0,
    this.customerLongitude = 0,
    this.tipAmount = 0,
    this.orderTotalAmount = 0,
  });

  factory DriverDeliveryChargeModel.fromJson(
    Map<String, dynamic> json, {
    String fallbackOrderId = '',
  }) {
    return DriverDeliveryChargeModel(
      orderId: _asString(json['orderId']).isNotEmpty
          ? _asString(json['orderId'])
          : fallbackOrderId,
      statusCode: _asString(json['statusCode']),
      statusMsg: _asString(json['statusMsg']),
      pickupDistanceKm: _asDouble(json['pickupDistanceKm']),
      deliveryDistanceKm: _asDouble(json['deliveryDistanceKm']),
      pickupCharge: _asDouble(json['pickupCharge']),
      deliveryCharge: _asDouble(json['deliveryCharge']),
      taxAmount: _asDouble(json['taxAmount']),
      totalDriverCharge: _asDouble(json['totalDriverCharge']),
      codAvailable: _asBool(json['codAvailable']),
      outletName: _asString(json['outletName']),
      outletPhoneNumber: _asString(json['outletPhoneNumber']),
      outletAddress: _asString(json['outletAddress']),
      outletLatitude: _asDouble(json['outletLatitude']),
      outletLongitude: _asDouble(json['outletLongitude']),
      customerName: _asString(json['customerName']),
      customerPhoneNumber: _asString(json['customerPhoneNumber']),
      customerAddress: _asString(json['customerAddress']),
      customerLatitude: _asDouble(json['customerLatitude']),
      customerLongitude: _asDouble(json['customerLongitude']),
      tipAmount: _asDouble(json['tipAmount']),
      orderTotalAmount: _asDouble(json['orderTotalAmount']),
    );
  }

  /// Total distance the driver is expected to cover.
  double get totalDistanceKm => pickupDistanceKm + deliveryDistanceKm;

  /// `totalDriverCharge` when supplied by the backend, otherwise the sum of
  /// the individual charge components.
  double get effectiveDriverCharge {
    if (totalDriverCharge > 0) return totalDriverCharge;
    return pickupCharge + deliveryCharge + taxAmount + tipAmount;
  }

  /// Whether the API returned enough data for the charge popup.
  bool get hasChargeData =>
      pickupDistanceKm > 0 ||
      deliveryDistanceKm > 0 ||
      pickupCharge > 0 ||
      deliveryCharge > 0 ||
      taxAmount > 0 ||
      totalDriverCharge > 0 ||
      tipAmount > 0 ||
      orderTotalAmount > 0 ||
      codAvailable;

  bool get hasOutletData =>
      outletName.trim().isNotEmpty ||
      outletAddress.trim().isNotEmpty ||
      outletPhoneNumber.trim().isNotEmpty;

  bool get hasCustomerData =>
      customerName.trim().isNotEmpty ||
      customerAddress.trim().isNotEmpty ||
      customerPhoneNumber.trim().isNotEmpty;

  bool get hasOutletCoordinates =>
      outletLatitude != 0 && outletLongitude != 0;

  bool get hasCustomerCoordinates =>
      customerLatitude != 0 && customerLongitude != 0;

  static String _asString(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    return text.toLowerCase() == 'null' ? '' : text;
  }

  static double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0;
  }

  static bool _asBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }
}
