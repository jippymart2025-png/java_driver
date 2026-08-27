import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/models/order_model.dart';
import 'package:jippydriver_driver/models/orders_report_response_model.dart';
import 'package:jippydriver_driver/utils/app_logger.dart';
import 'package:get/get.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jippydriver_driver/models/vendor_model.dart';
import 'dart:async';

import 'package:jippydriver_driver/utils/common.dart';

/// Report tabs map to `ordersReport` query `type`: upcoming / settled, or omitted for all.
enum OrderListTab { upcoming, settled, all }

class _TabState {
  List<OrderModel> orders = [];
  int currentPage = 1;
  bool hasMore = true;
  int totalOrders = 0;
  int totalCompleted = 0;
  double totalEarnings = 0;
  double totalTips = 0;
  double totalDeliveryCharge = 0;
  bool hasLoadedOnce = false;
}

class OrderListController extends GetxController {
  RxBool isLoading = true.obs;
  RxBool isLoadingMore = false.obs;
  RxBool hasMore = true.obs;
  RxList<OrderModel> orderList = <OrderModel>[].obs;
  RxInt totalOrders = 0.obs;
  RxInt totalCompleted = 0.obs;
  RxDouble totalEarnings = 0.0.obs;
  RxDouble totalTips = 0.0.obs;
  RxDouble totalDeliveryCharge = 0.0.obs;

  OrderListTab _activeTab = OrderListTab.upcoming;
  OrderListTab get activeTab => _activeTab;
  int get currentTabIndex =>
      OrderListTab.values.indexOf(_activeTab).clamp(0, OrderListTab.values.length - 1);

  final Map<OrderListTab, _TabState> _cache = {
    for (final t in OrderListTab.values) t: _TabState(),
  };

  int _currentPage = 1;
  static const int _perPage = 10;
  bool _fetchingFirstPage = false;
  bool _fetchingMore = false;

  // @override
  // void onInit() {
  //   AppLogger.log('OrderListController onInit() called', tag: 'Controller');
  //   getOrder();
  //   super.onInit();
  // }

  @override
  void onInit() {
    print("ORDER LIST CONTROLLER INIT");
    super.onInit();
    // print("ID => ${Constant.userModel?.id}");
    // print("FIREBASE ID => ${Constant.userModel?.firebaseId}");

    //AppLogger.log('OrderListController onInit() called', tag: 'Controller');

    fetchTotalEarnings();
    fetchOrderHistory();

    super.onInit();
  }
// ---------- THIS FUNCTION IS ADDED NOW-------------
  Future<void> fetchOrderHistory() async {
    print("=== FETCH ORDER HISTORY STARTED ===");
    print("ID => ${Constant.userModel?.id}");
    print("FIREBASE ID => ${Constant.userModel?.firebaseId}");
    print("DRIVER ID SENT => ${Constant.userModel?.id}");

    try {
      isLoading.value = true;
      final response = await http.get(
        Uri.parse(
          '${Constant.baseUrl}driver/fetchOrderEarningsHistory?driverId=${Constant.userModel?.firebaseId}',
        ),
        headers: await getHeaders(),
      );

      print("STATUS => ${response.statusCode}");
      print("BODY => ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        orderList.clear();

        // for (var item in data) {
        //   orderList.add(
        //     OrderModel(
        //       id: item["orderId"].toString(),
        //       status: item["orderStatus"] ?? "",
        //       tipAmount: item["tips"].toString(),
        //       calculatedCharges: {
        //         "totalCalculatedCharge":
        //         item["totalDeliveryFee"].toString(),
        //       },
        //       createdAt: Timestamp.now(),
        //       vendor: VendorModel(
        //         title: item["outletName"] ?? "Restaurant",
        //       ),
        //     ),
        //   );
        // }

        // for (var item in data) {
        //   orderList.add(
        //     OrderModel.fromJson(
        //       Map<String, dynamic>.from(item),
        //     ),
        //   );
        // }

        for (var item in data) {
          final order = OrderModel.fromJson(
            Map<String, dynamic>.from(item),
          );

          print("================================");
          print("ORDER ID => ${order.id}");
          print("PICKUP => ${order.pickUpCharges}");
          print("DELIVER => ${order.deliverCharges}");
          print("SURGE => ${order.surgeFee}");
          print("TIP => ${order.tipAmount}");
          print("STATUS => ${order.status}");
          print("VENDOR => ${order.vendor?.title}");
          print("================================");

          orderList.add(order);
        }
        print("TOTAL ORDERS => ${orderList.length}");
      }
        if (orderList.isNotEmpty) {
          print("FIRST ORDER =>");
          print(orderList.first.id);
          print(orderList.first.pickUpCharges);
          print(orderList.first.deliverCharges);
          print(orderList.first.surgeFee);

      }
    } catch (e) {
      print("fetchOrderHistory error => $e");
    } finally {
      isLoading.value = false;
    }
  }
  //////////fetchTotalEarnings function added now ------
  Future<void> fetchTotalEarnings() async {
    try {
      isLoading.value = true;
      print("BEFORE API");
      final response = await http
          .get(
        Uri.parse(
          '${Constant.baseUrl}driver/fetchTotalEarnings?driverId=${Constant.userModel?.firebaseId}',
        ),
        headers: await getHeaders(),
      )
          .timeout(const Duration(seconds: 15));

      print("AFTER API");

      print("STATUS => ${response.statusCode}");
      print("BODY => ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        totalOrders.value = data['totalOrders'] ?? 0;
        totalCompleted.value = data['completedOrders'] ?? 0;

        totalTips.value =
            double.tryParse(data['totalTips'].toString()) ?? 0.0;

        totalEarnings.value =
            double.tryParse(data['totalEarnings'].toString()) ?? 0.0;

        totalDeliveryCharge.value =
            double.tryParse(data['totalDeliveryCharges'].toString()) ?? 0.0;

        print("SUCCESS:");
        print("totalOrders => ${totalOrders.value}");
        print("totalCompleted => ${totalCompleted.value}");
        print("totalTips => ${totalTips.value}");
        print("totalEarnings => ${totalEarnings.value}");
        print("totalDeliveryCharge => ${totalDeliveryCharge.value}");
      } else {
        print("API FAILED => ${response.statusCode}");
      }
    } on TimeoutException {
      print("fetchTotalEarnings TIMEOUT");
    } catch (e, s) {
      print("fetchTotalEarnings ERROR => $e");
      print(s);
    } finally {
      isLoading.value = false;
    }
  }
  @override
  void onClose() {
    AppLogger.log('OrderListController onClose() called', tag: 'Controller');
    super.onClose();
  }

  /// Switch tab: restores cached list when that tab was already loaded (no extra API call).
  void selectTabByIndex(int index) {
    if (index < 0 || index >= OrderListTab.values.length) return;
    selectTab(OrderListTab.values[index]);
  }

  void selectTab(OrderListTab tab) {
    if (tab == _activeTab) return;
    _copyObservablesToCache(_activeTab);
    _activeTab = tab;
    final cached = _cache[tab]!;
    if (cached.hasLoadedOnce) {
      _applyCacheToObservables(cached);
      isLoading.value = false;
      return;
    }
    getOrder();
  }

  Future<void> refreshCurrentTab() async {
    _cache[_activeTab]!.hasLoadedOnce = false;
    await Future.wait([
      fetchOrderHistory(),
      fetchTotalEarnings(),
    ]);
  }

  void _copyObservablesToCache(OrderListTab tab) {
    final c = _cache[tab]!;
    c.orders = List<OrderModel>.from(orderList);
    c.currentPage = _currentPage;
    c.hasMore = hasMore.value;
    c.totalOrders = totalOrders.value;
    c.totalCompleted = totalCompleted.value;
    c.totalEarnings = totalEarnings.value;
    c.totalTips = totalTips.value;
    c.totalDeliveryCharge = totalDeliveryCharge.value;
  }

  void _applyCacheToObservables(_TabState c) {
    orderList.assignAll(c.orders);
    _currentPage = c.currentPage;
    hasMore.value = c.hasMore;
    totalOrders.value = c.totalOrders;
    totalCompleted.value = c.totalCompleted;
    totalEarnings.value = c.totalEarnings;
    totalTips.value = c.totalTips;
    totalDeliveryCharge.value = c.totalDeliveryCharge;
  }

  void _markTabCachedFromNetwork() {
    final c = _cache[_activeTab]!;
    _copyObservablesToCache(_activeTab);
    c.hasLoadedOnce = true;
  }

  Uri _buildOrdersUrl({
    required OrderListTab tab,
    int page = 1,
    int perPage = _perPage,
  }) {

    final driverId = Constant.userModel?.id?.toString() ?? "1";
    print("Constant.userModel = ${Constant.userModel}");
    print("Constant.userModel.id = ${Constant.userModel?.id}");

    return Uri.parse(

      '${Constant.baseUrl}driver/fetchOrderEarningsHistory?driverId=$driverId',
    );
  }

  //final String driverId = Constant.userModel?.firebaseId ?? '';
    // final String driverId =
    // (Constant.userModel?.id ?? 0).toString();
    // final params = <String, String>{
    //   'driver_id': driverId,
    //   'page': page.toString(),
    //   'per_page': perPage.toString(),
    // };
    // switch (tab) {
    //   case OrderListTab.upcoming:
    //     params['type'] = 'upcoming';
    //     break;
    //   case OrderListTab.settled:
    //     params['type'] = 'settled';
    //     break;
    //   case OrderListTab.all:
    //     break;
    // }
   //return Uri.parse('${Constant.baseUrl}ordersReport').replace(queryParameters: params);
    //return Uri.parse('http://187.127.156.147:8084/api/driver/fetchTotalEarnings?driverId=4');
    // return Uri.parse(
    //   'http://187.127.156.147:8084/api/driver/fetchOrderEarningsHistory?driverId=${Constant.userModel?.id ?? 2}',
    // );
   // final int driverId = Constant.userModel?.id ?? 1;

    // return Uri.parse(
    //   'http://187.127.156.147:8084/api/driver/fetchOrderEarningsHistory?driverId=$driverId',
    // );


  Future<void> getOrder() async {
    print("GET ORDER BLOCKED");
    if (_fetchingFirstPage) return;
    final tabForRequest = _activeTab;
    _fetchingFirstPage = true;

    try {
      isLoading.value = true;
      orderList.clear();
      _currentPage = 1;
      hasMore.value = true;
      totalOrders.value = 0;
      totalCompleted.value = 0;
      totalEarnings.value = 0;
      totalTips.value = 0;
      totalDeliveryCharge.value = 0;


      print(
        "GET ORDER URL => ${_buildOrdersUrl(tab: tabForRequest, page: 1)}",
      );

      final response = await http
          .get(_buildOrdersUrl(tab: tabForRequest, page: 1), headers: await getHeaders())
          .timeout(const Duration(seconds: 15));

      if (_activeTab != tabForRequest) return;

      if (response.statusCode == 200) {
        _handleSuccess(response.body, tabForRequest, isFirstPage: true);
        _markTabCachedFromNetwork();
        // } else {
        //   log('getOrder() – HTTP ${response.statusCode}');
        // }

      }else {
    print("GET ORDER STATUS => ${response.statusCode}");
    print("GET ORDER BODY => ${response.body}");
    }
    } catch (e) {
      log('getOrder() error: $e');
    } finally {
      _fetchingFirstPage = false;
      if (_activeTab == tabForRequest) {
        isLoading.value = false;
      }
      // Switched tab while this request was in flight — load the new tab if needed.
      if (_activeTab != tabForRequest && !_cache[_activeTab]!.hasLoadedOnce) {
        Future.microtask(() => getOrder());
      } else if (_activeTab != tabForRequest) {
        isLoading.value = false;
      }
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value || _fetchingMore) return;
    final tabForRequest = _activeTab;
    _fetchingMore = true;

    try {
      isLoadingMore.value = true;
      final nextPage = _currentPage + 1;

      final response = await http
          .get(_buildOrdersUrl(tab: tabForRequest, page: nextPage), headers: await getHeaders())
          .timeout(const Duration(seconds: 15));

      if (_activeTab != tabForRequest) return;

      if (response.statusCode == 200) {
        _currentPage = nextPage;
        _handleSuccess(response.body, tabForRequest, isFirstPage: false);
        _markTabCachedFromNetwork();
      } else {
        log('loadMore() – HTTP ${response.statusCode}');
      }
    } catch (e) {
      log('loadMore() error: $e');
    } finally {
      if (_activeTab == tabForRequest) {
        isLoadingMore.value = false;
      }
      _fetchingMore = false;
    }
  }

  void _handleSuccess(
    String body,
    OrderListTab tabForResponse, {
    required bool isFirstPage,
  }) {
    if (_activeTab != tabForResponse) return;
    try {
      final Map<String, dynamic> data = jsonDecode(body);
      final report = OrdersReportResponse.fromJson(data);

      if (!report.success) {
        if (!isFirstPage) _currentPage--;
        hasMore.value = false;
        return;
      }

      final pagination = report.pagination;
      if (pagination != null) {
        final int currentPage = pagination.currentPage;
        final int lastPage = pagination.lastPage;
        hasMore.value = currentPage < lastPage;
        totalOrders.value = pagination.total;
      } else {
        hasMore.value = report.orders.length >= _perPage;
      }

      final earnings = report.earnings;
      if (earnings != null && isFirstPage) {
        totalEarnings.value = earnings.totalEarnings;
        totalTips.value = earnings.totalTips;
        totalCompleted.value = earnings.totalCompleted;
        totalDeliveryCharge.value = earnings.deliveryCharge;
      }

      orderList.addAll(report.orders);

      if (totalOrders.value == 0) totalOrders.value = orderList.length;
      if (earnings == null && isFirstPage) {
        double fallbackEarnings = 0;
        double fallbackTips = 0;
        int fallbackCompleted = 0;
        for (final order in report.orders) {
          if ((order.status ?? '').toLowerCase() == 'order completed') {
            fallbackCompleted++;
          }
          final m = order.calculatedCharges ?? const {};
          fallbackEarnings += _toDouble(m['totalCalculatedCharge']) ?? 0;
          fallbackTips += _toDouble(order.tipAmount) ?? 0;
        }
        totalEarnings.value = fallbackEarnings;
        totalTips.value = fallbackTips;
        totalCompleted.value = fallbackCompleted;
        totalDeliveryCharge.value = totalEarnings.value - totalTips.value;

        print("CONTROLLER UPDATED");
        print("totalEarnings => ${totalEarnings.value}");
        print("totalTips => ${totalTips.value}");
        print("totalOrders => ${totalOrders.value}");
        print("totalCompleted => ${totalCompleted.value}");
      }
    } catch (e) {
      log('_handleSuccess() parse error: $e');
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }
}