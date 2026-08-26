class TodayDashboardData {
final int totalOrdersToday;
final double totalEarningsToday;
final double driverIncentiveBonus;
final String? date;

const TodayDashboardData({
  required this.totalOrdersToday,
  required this.totalEarningsToday,
  required this.driverIncentiveBonus,
  this.date,
});

  factory TodayDashboardData.fromJson(Map<String, dynamic> json) {
    return TodayDashboardData(
      totalOrdersToday: _toInt(json['ordersCountToday']),
      totalEarningsToday: _toDouble(json['totalEarningsToday']),
      driverIncentiveBonus: _toDouble(json['driverIncentiveBonus']),
      date: json['currentDate']?.toString(),
    );
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}