class DriverIncentiveModel {
  final String? date;
  final int? driverId;
  final int? noOfOrders;
  final double? incentiveAmount;

  DriverIncentiveModel({
    this.date,
    this.driverId,
    this.noOfOrders,
    this.incentiveAmount,
  });

  factory DriverIncentiveModel.fromJson(Map<String, dynamic> json) {
    return DriverIncentiveModel(
      date: json['date'],
      driverId: json['driverId'],
      noOfOrders: json['noOfOrders'],
      incentiveAmount:
      (json['incentiveAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DriverIncentiveResponse {
  final List<DriverIncentiveModel> content;
  final bool last;
  final int totalElements;
  final int totalPages;

  DriverIncentiveResponse({
    required this.content,
    required this.last,
    required this.totalElements,
    required this.totalPages,
  });

  factory DriverIncentiveResponse.fromJson(
      Map<String, dynamic> json) {
    return DriverIncentiveResponse(
      content: (json['content'] as List<dynamic>? ?? [])
          .map((e) => DriverIncentiveModel.fromJson(e))
          .toList(),
      last: json['last'] ?? true,
      totalElements: json['totalElements'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
    );
  }
}