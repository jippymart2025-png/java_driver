class WalletTransactionModel {
  String? userId;
  String? paymentMethod;
  double? amount;
  bool? isTopup;
  String? orderId;
  String? paymentStatus;

  // Timestamp? date;
  DateTime? date;
  String? id;
  String? transactionUser;
  String? note;

  WalletTransactionModel({
    this.userId,
    this.paymentMethod,
    this.amount,
    this.isTopup,
    this.orderId,
    this.paymentStatus,
    this.date,
    this.id,
    this.transactionUser,
    this.note,
  });

  WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    id = json['id'] ?? json['transactionId']?.toString();
    userId = json['user_id'] ?? json['driverWalletId']?.toString();
    paymentMethod = json['payment_method'] ?? 'cod';
    orderId = json['orderId'] ?? json['order_id'];

    final codAmount = json['codAmount'] ?? json['amount'];
    final transactionType =
        json['transactionType']?.toString() ?? json['type']?.toString() ?? '';

    amount = _toDouble(codAmount);

    // Java API returns transactionType in UPPERCASE (credit/debit),
    // so treat it case-insensitively.
    if (transactionType.toLowerCase() == 'credit') {
      isTopup = true;
    } else if (transactionType.toLowerCase() == 'debit') {
      isTopup = false;
    } else {
      isTopup = json['isTopUp'] == true;
    }

    paymentStatus = json['payment_status'];
    date = _parseDate(json['createdAt'] ?? json['date']);
    transactionUser = json['transactionUser'] ?? 'customer';

    final rawNote = json['note'];
    final oid = orderId;
    if (rawNote != null) {
      note = rawNote;
    } else if (oid != null && oid.isNotEmpty) {
      note = 'Order #$oid';
    } else {
      note = isTopup == true ? 'Wallet Top-up' : 'Wallet Transaction';
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['user_id'] = userId;
    data['payment_method'] = paymentMethod;
    data['amount'] = amount;
    data['isTopUp'] = isTopup;
    data['order_id'] = orderId;
    data['payment_status'] = paymentStatus;
    data['date'] = date;
    data['transactionUser'] = transactionUser;
    data['note'] = note;
    return data;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }


// Added this method now
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}

class WalletTransactionsApiResponse {
  final bool success;
  final List<WalletTransactionModel> data;
  final double totalWalletAmount;
  final String? message;

  WalletTransactionsApiResponse({
    required this.success,
    required this.data,
    required this.totalWalletAmount,
    this.message,
  });

  factory WalletTransactionsApiResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['data'];
    final records = <WalletTransactionModel>[];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          records.add(WalletTransactionModel.fromJson(item));
        }
      }
    }
    records.sort((a, b) {
      final dateA = a.date;
      final dateB = b.date;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    final summary = json['summary'];
    final totalAmount = summary is Map<String, dynamic>
        ? _toAmount(summary['total_wallet_amount'])
        : 0.0;

    return WalletTransactionsApiResponse(
      success: json['success'] == true,
      data: records,
      totalWalletAmount: totalAmount,
      message: json['message']?.toString(),
    );
  }

  static double _toAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
