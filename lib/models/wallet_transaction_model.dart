import 'package:cloud_firestore/cloud_firestore.dart';

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
    id = json['id'];
    userId = json['user_id'];
    // paymentMethod = json['payment_method'];
    paymentMethod = json['payment_method'] ?? 'cod';
    orderId = json['orderId'];
    // final hasLegacyAmount = json.containsKey('amount');
    // if (hasLegacyAmount) {
    //   amount = _toDouble(json['amount']);
    //   isTopup = json['isTopUp'] == true;
    // } else {
    //   final credit = _toDouble(json['credit']);
    //   final debit = _toDouble(json['debit']);
    //
    //   if (debit > 0) {
    //     amount = debit;
    //     isTopup = true;
    //   } else if (credit != 0) {
    //     amount = credit.abs();
    //     isTopup = credit > 0;
    //   } else {
    //     amount = 0.0;
    //     isTopup = false;
    //   }
    // }

    final codAmount = json['codAmount'];
    final transactionType = json['transactionType']?.toString();

    amount = _toDouble(codAmount);

// Java API logic
    if (transactionType == 'credit') {
      isTopup = true;
    } else if (transactionType == 'debit') {
      isTopup = false;
    } else {
      isTopup = false;
    }
    orderId = json['order_id'];
    paymentStatus = json['payment_status'];
    //ate = _parseTimestamp(json['date']);
    date = _parseDate(json['createdAt'] ?? json['date']);
    transactionUser = json['transactionUser'] ?? 'customer';
    note = json['note'] ??
        (isTopup == true ? 'Wallet Top-up' : 'Wallet Transaction');
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

  static Timestamp? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return Timestamp.fromDate(parsed);
    }
    return null;
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
