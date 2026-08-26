import 'package:jippydriver_driver/models/order_model.dart';

class OrdersReportResponse {
  final bool success;
  final List<OrderModel> orders;
  final OrdersReportEarnings? earnings;
  final OrdersReportPagination? pagination;

  const OrdersReportResponse({
    required this.success,
    required this.orders,
    this.earnings,
    this.pagination,
  });

  factory OrdersReportResponse.fromJson(Map<String, dynamic> json) {
    final rawOrders = (json['orders'] as List?) ?? const [];
    return OrdersReportResponse(
      success: json['success'] == true,
      orders: rawOrders
          .whereType<Map>()
          .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      earnings: json['earnings'] is Map<String, dynamic>
          ?  OrdersReportEarnings.fromJson(json['earnings'])
          : null,
      pagination: json['pagination'] is Map<String, dynamic>
          ? OrdersReportPagination.fromJson(json['pagination'])
          : null,
    );
  }
}

class OrdersReportEarnings {
  final double totalEarnings;
  final double totalTips;
  final int totalCompleted;
  final double deliveryCharge;

  const OrdersReportEarnings({
    required this.totalEarnings,
    required this.totalTips,
    required this.totalCompleted,
    required this.deliveryCharge,
  });

  factory OrdersReportEarnings.fromJson(Map<String, dynamic> json) {
    return OrdersReportEarnings(
      totalEarnings: _toDouble(json['total_earnings']),
      totalTips: _toDouble(json['total_tips']),
      totalCompleted: _toInt(json['total_completed']),
      deliveryCharge: _toDouble(json['delivery_charge']),
    );
  }
}

class OrdersReportPagination {
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;
  final int from;
  final int to;
  final bool hasMore;

  const OrdersReportPagination({
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
    required this.from,
    required this.to,
    required this.hasMore,
  });

  factory OrdersReportPagination.fromJson(Map<String, dynamic> json) {
    return OrdersReportPagination(
      total: _toInt(json['total']),
      perPage: _toInt(json['per_page']),
      currentPage: _toInt(json['current_page']),
      lastPage: _toInt(json['last_page']),
      from: _toInt(json['from']),
      to: _toInt(json['to']),
      hasMore: json['has_more'] == true,
    );
  }
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim()) ?? 0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim()) ?? 0;
}
