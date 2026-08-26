import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/models/wallet_transaction_model.dart';
import 'package:jippydriver_driver/models/driver_incentive_model.dart';
import 'package:jippydriver_driver/utils/common.dart';

class ApiService {

  static Future<WalletTransactionsApiResponse?> getWalletTransactions({
    required String driverId,
    String? token,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final response = await http.get(

        Uri.parse(
          '${Constant.baseUrl}driver/getDriverWalletTransactions?driverId=$driverId',
        ),
        headers: await getHeaders()
      );


      log("STATUS: ${response.statusCode}");
      log("BODY: ${response.body}");

      if (response.statusCode != 200) {
        log('API Error: ${response.statusCode}');
        return null;
      }

      final decoded = json.decode(response.body);

      // final normalized = decoded is List
      //     ? {
      //   "success": true,
      //   "data": decoded,
      //   "summary": {"total_wallet_amount": 0}
      // }
      //     : decoded;
      double total = 0;

      if (decoded is List) {
        for (final item in decoded) {
          final amount = ((item['codAmount'] ?? 0) as num).toDouble();

          if (item['transactionType'] == 'credit') {
            total += amount;
          } else if (item['transactionType'] == 'debit') {
            total -= amount;
          }
        }
      }

      final normalized = decoded is List
          ? {
        "success": true,
        "data": decoded,
        "summary": {
          "total_wallet_amount": total,
        }
      }
          : decoded;
      final parsed =
      WalletTransactionsApiResponse.fromJson(normalized);

      log("TRANSACTION COUNT = ${parsed.data.length}");
      log("TOTAL WALLET FROM API = ${parsed.totalWalletAmount}");

      return parsed;

      return WalletTransactionsApiResponse.fromJson(normalized);
    } catch (e) {
      log('Wallet API Exception: $e');
      return null;
    }
  }
  static Future<DriverIncentiveResponse?> getDriverIncentiveHistory({
    required int driverId,
    String filter = 'all',
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${Constant.baseUrl}driver/getDriverIncentiveHistory'
              '?driverId=$driverId'
              '&filter=$filter'
              '&page=$page'
              '&size=$size',
        ),
        headers: await getHeaders()
      );

      log(
        'INCENTIVE API => ${response.statusCode} ${response.body}',
      );

      if (response.statusCode == 200) {
        return DriverIncentiveResponse.fromJson(
          jsonDecode(response.body),
        );
      }

      return null;
    } catch (e, st) {
      log(
        'getDriverIncentiveHistory error: $e\n$st',
      );
      return null;
    }
  }

}