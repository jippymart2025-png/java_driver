class DriverEarningHistoryModel {
  int? orderId;
  String? outletName;
  double? totalDeliveryFee;
  String? createdAt;
  String? orderStatus;

  DriverEarningHistoryModel({
    this.orderId,
    this.outletName,
    this.totalDeliveryFee,
    this.createdAt,
    this.orderStatus,
  });

  factory DriverEarningHistoryModel.fromJson(
      Map<String, dynamic> json) {
    return DriverEarningHistoryModel(
      orderId: json['orderId'],
      outletName: json['outletName'],
      totalDeliveryFee:
      (json['totalDeliveryFee'] as num?)?.toDouble(),
      createdAt: json['createdAt'],
      orderStatus: json['orderStatus'], //
    );
  }
}