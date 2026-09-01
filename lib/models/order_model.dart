import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:jippydriver_driver/models/cart_product_model.dart';
import 'package:jippydriver_driver/models/tax_model.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/models/vendor_model.dart';

class OrderModel {
  ShippingAddress? address;
  String? status;
  String? couponId;
  String? vendorID;
  String? driverID;
  num? discount;
  String? authorID;
  String? estimatedTimeToPrepare;
  Timestamp? createdAt;
  Timestamp? triggerDelivery;
  List<TaxModel>? taxSetting;
  String? paymentMethod;
  List<CartProductModel>? products;
  String? adminCommissionType;
  VendorModel? vendor;
  String? id;
  String? adminCommission;
  String? couponCode;
  Map<String, dynamic>? specialDiscount;
  String? deliveryCharge;
  Timestamp? scheduleTime;
  String? tipAmount;
  String? notes;
  UserModel? author;
  UserModel? driver;
  bool? takeAway;
  List<dynamic>? rejectedByDrivers;
  String? toPay;
  Map<String, dynamic>? calculatedCharges;

  //Newly added fields

  double? pickUpDistanceInKms;
  double? deliveryDistanceInKms;

  num? pickUpCharges;
  num? deliverCharges;
  num? surgeFee;

  //Newly added fields

  OrderModel({
    this.address,
    this.status,
    this.couponId,
    this.vendorID,
    this.driverID,
    this.discount,
    this.authorID,
    this.estimatedTimeToPrepare,
    this.createdAt,
    this.triggerDelivery,
    this.taxSetting,
    this.paymentMethod,
    this.products,
    this.adminCommissionType,
    this.vendor,
    this.id,
    this.adminCommission,
    this.couponCode,
    this.specialDiscount,
    this.deliveryCharge,
    this.scheduleTime,
    this.tipAmount,
    this.notes,
    this.author,
    this.driver,
    this.takeAway,
    this.rejectedByDrivers,
    this.toPay,
    this.calculatedCharges,

    //Newly added fields
    this.pickUpDistanceInKms,
    this.deliveryDistanceInKms,
    this.pickUpCharges,
    this.deliverCharges,
    this.surgeFee,
    //Newly added
  });

    OrderModel.fromJson(Map<String, dynamic> json) {
    try {
    // Handle address coming as Map or JSON string (also shipping_* aliases from some APIs)
    dynamic rawAddress = json['address'] ??
        json['shipping_address'] ??
        json['shippingAddress'];
    if (rawAddress != null) {
      if (rawAddress is Map) {
        address = ShippingAddress.fromJson(
            Map<String, dynamic>.from(rawAddress));
      } else if (rawAddress is String) {
        try {
          final addressJson = jsonDecode(rawAddress);
          if (addressJson is Map) {
            address = ShippingAddress.fromJson(
                Map<String, dynamic>.from(addressJson));
          }
        } catch (e) {
          debugPrint('Error decoding address JSON string: $e');
          address = null;
        }
      } else {
        address = null;
      }
    } else {
      address = null;
    }
    /////status = json['status'];
    status = json['status'] ?? json['orderStatus'];
    couponId = json['couponId'];
    vendorID = json['vendorID']?.toString();
    driverID = json['driverID']?.toString();
    discount = _parseNum(json['discount']);
    authorID = json['authorID']?.toString();
    estimatedTimeToPrepare = json['estimatedTimeToPrepare'];
    // Handle createdAt coming from Firestore Timestamp, milliseconds, or null
    createdAt = _parseTimestamp(json['createdAt']);
    // Some APIs/collections use "triggerDelevery" (typo) – keep backward compatible
    triggerDelivery = _parseTimestamp(json['triggerDelevery'] ?? json['triggerDelivery']) ?? Timestamp.now();
    if (json['taxSetting'] != null) {
      taxSetting = <TaxModel>[];
      json['taxSetting'].forEach((v) {
        taxSetting!.add(TaxModel.fromJson(v));
      });
    }
    paymentMethod = json['payment_method'];
    if (json['products'] != null) {
      products = <CartProductModel>[];
      json['products'].forEach((v) {
        products!.add(CartProductModel.fromJson(v));
      });
    }
    adminCommissionType = json['adminCommissionType'];
    // Handle vendorID - can come from 'vendorID' field or 'vendor' field if it's just an ID string
    vendorID = json['vendorID']?.toString() ?? 
               (json['vendor'] is String && json['vendor'] != null ? json['vendor']?.toString() : null);
    
    // Handle vendor coming as Map, JSON string, or null
    /////////////// COMMENTED
    // if (json['vendor'] != null) {
    //   if (json['vendor'] is Map) {
    //     try {
    //       vendor = VendorModel.fromJson(Map<String, dynamic>.from(json['vendor']));
    //       // Ensure vendorID is set from vendor object if not already set
    //       if (vendorID == null && vendor?.id != null) {
    //         vendorID = vendor!.id;
    //       }
    //     } catch (e) {
    //       debugPrint('Error parsing vendor Map: $e');
    //       vendor = null;
    //     }
    //   } else if (json['vendor'] is String) {
    //     try {
    //       final vendorString = json['vendor'] as String;
    //       // Try to parse as JSON string first
    //       final vendorJson = jsonDecode(vendorString);
    //       if (vendorJson is Map) {
    //         vendor = VendorModel.fromJson(Map<String, dynamic>.from(vendorJson));
    //         // Ensure vendorID is set from vendor object if not already set
    //         if (vendorID == null && vendor?.id != null) {
    //           vendorID = vendor!.id;
    //         }
    //       } else {
    //         // If it's not a JSON string, treat it as vendorID
    //         vendorID = vendorString;
    //         vendor = null;
    //       }
    //     } catch (e) {
    //       // If JSON decode fails, treat the string as vendorID
    //       debugPrint('Error decoding vendor JSON string: $e - treating as vendorID');
    //       vendorID = json['vendor']?.toString();
    //       vendor = null;
    //     }
    //   } else {
    //     // vendor is not null but not Map or String - set vendorID if possible
    //     vendorID = json['vendor']?.toString();
    //     vendor = null;
    //   }
    // } else {
    //   // vendor is null - vendorID should already be set from vendorID field above
    //   vendor = null;
   // }////////////////// COMMENTED

    if (json['vendor'] != null) {
      if (json['vendor'] is Map) {
        try {
          vendor = VendorModel.fromJson(
            Map<String, dynamic>.from(json['vendor']),
          );

          if (vendorID == null && vendor?.id != null) {
            vendorID = vendor!.id;
          }
        } catch (e) {
          debugPrint('Error parsing vendor Map: $e');
          vendor = null;
        }
      }
    }

// NEW API SUPPORT
      if (vendor == null && json['outletName'] != null) {
        vendor = VendorModel();
        vendor!.title = json['outletName'].toString();
      }
    /////id = json['id']?.toString();
    id = json['id']?.toString() ??
        json['orderId']?.toString();
    adminCommission = json['adminCommission']?.toString();
    couponCode = json['couponCode']?.toString();
    // Handle specialDiscount coming as Map or JSON string
    if (json['specialDiscount'] != null) {
      if (json['specialDiscount'] is Map) {
        specialDiscount = Map<String, dynamic>.from(json['specialDiscount']);
      } else if (json['specialDiscount'] is String) {
        try {
          final specialDiscountJson = jsonDecode(json['specialDiscount']);
          if (specialDiscountJson is Map) {
            specialDiscount = Map<String, dynamic>.from(specialDiscountJson);
          }
        } catch (e) {
          debugPrint('Error decoding specialDiscount JSON string: $e');
          specialDiscount = null;
        }
      }
    }
    // Safely parse deliveryCharge (can be num, string, null)
    ///////deliveryCharge = _parseNum(json['deliveryCharge'])?.toString() ?? '0.0';
    deliveryCharge =
        _parseNum(
          json['deliveryCharge'] ??
              json['totalDeliveryFee'],
        )?.toString() ??
            '0.0';
    // Handle scheduleTime from Timestamp or milliseconds
    scheduleTime = _parseTimestamp(json['scheduleTime']);
    // Safely parse tip amount (can be num, string, null)
    ///////tipAmount = _parseNum(json['tip_amount'])?.toString() ?? '0.0';
    tipAmount =
        _parseNum(
          json['tip_amount'] ??
              json['tips'],
        )?.toString() ??
            '0.0';

      //Added newly
      pickUpDistanceInKms =
          double.tryParse(json['pickUpDistanceInKms']?.toString() ?? '0');

      deliveryDistanceInKms =
          double.tryParse(json['deliveryDistanceInKms']?.toString() ?? '0');

      pickUpCharges = _parseNum(json['pickUpCharges']);

      deliverCharges = _parseNum(json['deliverCharges']);

      surgeFee = _parseNum(json['surgeFee']);
    notes = json['notes'];
    // Handle author coming as Map or JSON string
    if (json['author'] != null) {
      if (json['author'] is Map) {
        author = UserModel.fromJson(Map<String, dynamic>.from(json['author']));
      } else if (json['author'] is String) {
        try {
          final authorJson = jsonDecode(json['author']);
          if (authorJson is Map) {
            author = UserModel.fromJson(Map<String, dynamic>.from(authorJson));
          }
        } catch (e) {
          debugPrint('Error decoding author JSON string: $e');
          author = null;
        }
      }
    }
    // Handle driver coming as Map or JSON string
    if (json['driver'] != null) {
      if (json['driver'] is Map) {
        driver = UserModel.fromJson(Map<String, dynamic>.from(json['driver']));
      } else if (json['driver'] is String) {
        try {
          final driverJson = jsonDecode(json['driver']);
          if (driverJson is Map) {
            driver = UserModel.fromJson(Map<String, dynamic>.from(driverJson));
          }
        } catch (e) {
          debugPrint('Error decoding driver JSON string: $e');
          driver = null;
        }
      }
    }
    takeAway = _parseBool(json['takeAway']);
    rejectedByDrivers = _parseList(json['rejectedByDrivers']);
    toPay = json['ToPay']?.toString();
    // Handle calculatedCharges coming as Map or JSON string
    if (json['calculatedCharges'] != null) {
      if (json['calculatedCharges'] is Map) {
        calculatedCharges = Map<String, dynamic>.from(json['calculatedCharges']);
      } else if (json['calculatedCharges'] is String) {
        try {
          final calculatedChargesJson = jsonDecode(json['calculatedCharges']);
          if (calculatedChargesJson is Map) {
            calculatedCharges = Map<String, dynamic>.from(calculatedChargesJson);
          }
        } catch (e) {
          debugPrint('Error decoding calculatedCharges JSON string: $e');
          calculatedCharges = null;
        }
      }
    }
    } catch (e, stackTrace) {
      debugPrint('Error parsing OrderModel from JSON: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON keys: ${json.keys.toList()}');
      // Re-throw to let caller handle it
      rethrow;
    }
  }
  bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    if (value is num) {
      return value == 1;
    }
    return null;
  }

  /// Safely parse a numeric value that may come as int, double, String or null.
  num? _parseNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value);
    }
    return null;
  }

  /// Safely parse a timestamp that may come as:
  /// - Firestore [Timestamp]
  /// - millisecondsSinceEpoch (int or String)
  /// - ISO8601 String
  /// - or null
  Timestamp? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value;
    if (value is int) {
      return Timestamp.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      // Try parsing as milliseconds string (e.g., "1764675379043")
      final milliseconds = int.tryParse(value);
      if (milliseconds != null) {
        return Timestamp.fromMillisecondsSinceEpoch(milliseconds);
      }
      try {
        final dt = DateTime.tryParse(value);
        if (dt != null) {
          return Timestamp.fromDate(dt);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Safely parse a list that may come as:
  /// - List
  /// - JSON String (e.g., "[]" or "[1,2,3]")
  /// - or null
  List<dynamic>? _parseList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    if (value is String) {
      try {
        // Try to parse as JSON string
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded;
        }
      } catch (_) {
        // If parsing fails, return empty list
        return [];
      }
    }
    return [];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (address != null) {
      data['address'] = address!.toJson();
    }

    data['status'] = status;
    data['couponId'] = couponId;
    data['vendorID'] = vendorID;
    data['driverID'] = driverID;
    data['discount'] = discount;
    data['authorID'] = authorID;
    data['estimatedTimeToPrepare'] = estimatedTimeToPrepare;

    // Convert Timestamp to milliseconds
    data['createdAt'] = createdAt?.millisecondsSinceEpoch;
    data['triggerDelivery'] = triggerDelivery?.millisecondsSinceEpoch;

    if (taxSetting != null) {
      data['taxSetting'] = taxSetting!.map((v) => v.toJson()).toList();
    }

    data['payment_method'] = paymentMethod;

    if (products != null) {
      data['products'] = products!.map((e) => e.toJson()).toList();
    }

    data['adminCommissionType'] = adminCommissionType;
    if (vendor != null) {
      final vendorJson = vendor!.toJson();
      _convertGeoPointsInMap(vendorJson);
      data['vendor'] = vendorJson;
    }
    data['id'] = id;
    data['adminCommission'] = adminCommission;
    data['couponCode'] = couponCode;
    data['specialDiscount'] = specialDiscount;
    data['deliveryCharge'] = deliveryCharge;
    // data['scheduleTime'] = scheduleTime;

    data['tip_amount'] = tipAmount;
    data['notes'] = notes;

    if (author != null) {
      data['author'] = author!.toJson();
    }

    if (driver != null) {
      data['driver'] = driver!.toJson();
    }

    data['takeAway'] = takeAway;
    data['rejectedByDrivers'] = rejectedByDrivers;
    data['ToPay'] = toPay;
    data['calculatedCharges'] = calculatedCharges;

    return data;
  }

  // Helper method to convert GeoPoint objects in a map
  void _convertGeoPointsInMap(Map<String, dynamic> map) {
    for (final key in map.keys.toList()) {
      final value = map[key];

      if (value is GeoPoint) {
        map[key] = {
          'latitude': value.latitude,
          'longitude': value.longitude,
          '_type': 'geopoint' // Optional: Add a type indicator
        };
      } else if (value is Map<String, dynamic>) {
        _convertGeoPointsInMap(value);
      } else if (value is List) {
        for (var i = 0; i < value.length; i++) {
          if (value[i] is Map<String, dynamic>) {
            _convertGeoPointsInMap(value[i]);
          } else if (value[i] is GeoPoint) {
            value[i] = {
              'latitude': value[i].latitude,
              'longitude': value[i].longitude,
              '_type': 'geopoint'
            };
          }
        }
      }
    }
  }
}