import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/models/subscription_plan_model.dart';

class UserModel {
  String? id;
  String? firebaseId;
  String? firstName;
  String? lastName;
  String? email;
  String? profilePictureURL;
  String? fcmToken;
  String? countryCode;
  String? phoneNumber;
  num? walletAmount;
  bool? active;
  bool? isActive;
  bool? isDocumentVerify;
  Timestamp? createdAt;
  String? role;
  UserLocation? location;
  UserBankDetails? userBankDetails;
  List<ShippingAddress>? shippingAddress;
  String? carName;
  String? carNumber;
  String? carPictureURL;
  List<dynamic>? inProgressOrderID;
  List<dynamic>? orderRequestData;
  String? vendorID;
  String? zoneId;
  num? rotation;
  String? appIdentifier;
  String? provider;
  String? subscriptionPlanId;
  Timestamp? subscriptionExpiryDate;
  SubscriptionPlanModel? subscriptionPlan;
  num? deliveryAmount;

  UserModel({
    this.id,
    this.firebaseId,
    this.firstName,
    this.lastName,
    this.active,
    this.isActive,
    this.isDocumentVerify,
    this.email,
    this.profilePictureURL,
    this.fcmToken,
    this.countryCode,
    this.phoneNumber,
    this.walletAmount,
    this.createdAt,
    this.role,
    this.location,
    this.shippingAddress,
    this.carName,
    this.carNumber,
    this.carPictureURL,
    this.inProgressOrderID,
    this.orderRequestData,
    this.vendorID,
    this.zoneId,
    this.rotation,
    this.appIdentifier,
    this.provider,
    this.subscriptionPlanId,
    this.subscriptionExpiryDate,
    this.subscriptionPlan,
    this.deliveryAmount,
  });

  String fullName() {
    return "${firstName ?? ''} ${lastName ?? ''}";
  }

  // UserModel.fromJson(Map<String, dynamic> json) {
  //   if (json['id'] != null) {
  //     id = json['id'].toString();
  //   }
  //   firebaseId = json['id']?.toString();
  //   email = json['email'];
  //   firstName = json['firstName'];
  //   lastName = json['lastName'];
  //   profilePictureURL = json['profile_pic'];
  //   fcmToken = json['fcmToken'];
  //   countryCode = json['countryCode'];
  //   phoneNumber = json['phone'];
  //   walletAmount = json['wallet_amount'] ?? 0;
  //   deliveryAmount = json['deliveryAmount'] ?? 0;
  //   if (json['createdAt'] != null) {
  //     if (json['createdAt'] is Timestamp) {
  //       createdAt = json['createdAt'];
  //     } else if (json['createdAt'] is String) {
  //       try {
  //         final dateTime = DateTime.parse(json['createdAt']);
  //         createdAt = Timestamp.fromDate(dateTime);
  //       } catch (e) {
  //         createdAt = null;
  //       }
  //     } else if (json['createdAt'] is Map) {
  //       try {
  //         createdAt = Timestamp(
  //           json['createdAt']['seconds'] ?? 0,
  //           json['createdAt']['nanoseconds'] ?? 0,
  //         );
  //       } catch (e) {
  //         createdAt = null;
  //       }
  //     }
  //   } else {
  //     createdAt = null;
  //   }
  //
  //   active = json['active'] == 1 || json['active'] == true;
  //   isActive = json['isActive'] == 1 || json['isActive'] == true;
  //   isDocumentVerify = json['isDocumentVerify'] == "1" || json['isDocumentVerify'] == true || json['isDocumentVerify'] == 1;
  //   print("isDocumentVerify  ${isDocumentVerify}");
  //   role = json['role'] ?? 'user';
  //
  //   // Fix for location handling
  //   if (json['location'] != null && json['location'] is List) {
  //     final locationList = json['location'] as List;
  //     if (locationList.isNotEmpty) {
  //       final firstItem = locationList.first;
  //       if (firstItem is Map<String, dynamic>) {
  //         location = UserLocation.fromJson(firstItem);
  //       } else {
  //         location = null;
  //       }
  //     } else {
  //       location = null;
  //     }
  //   } else if (json['location'] != null && json['location'] is Map<String, dynamic>) {
  //     location = UserLocation.fromJson(json['location'] as Map<String, dynamic>);
  //   } else {
  //     location = null;
  //   }
  //
  //   // Fix for userBankDetails handling
  //   if (json['userBankDetails'] != null && json['userBankDetails'] is List) {
  //     final list = json['userBankDetails'] as List;
  //     if (list.isNotEmpty) {
  //       final firstItem = list.first;
  //       if (firstItem is Map<String, dynamic>) {
  //         userBankDetails = UserBankDetails.fromJson(firstItem);
  //       } else {
  //         userBankDetails = null;
  //       }
  //     } else {
  //       userBankDetails = null;
  //     }
  //   } else if (json['userBankDetails'] != null && json['userBankDetails'] is Map<String, dynamic>) {
  //     userBankDetails = UserBankDetails.fromJson(json['userBankDetails'] as Map<String, dynamic>);
  //   } else {
  //     userBankDetails = null;
  //   }
  //
  //   // Fix for shippingAddress handling
  //   if (json['shippingAddress'] != null) {
  //     if (json['shippingAddress'] is List) {
  //       final list = json['shippingAddress'] as List;
  //       shippingAddress = <ShippingAddress>[];
  //       for (var item in list) {
  //         if (item is Map<String, dynamic>) {
  //           shippingAddress!.add(ShippingAddress.fromJson(item));
  //         }
  //       }
  //     } else if (json['shippingAddress'] is Map<String, dynamic>) {
  //       shippingAddress = <ShippingAddress>[];
  //       shippingAddress!.add(ShippingAddress.fromJson(json['shippingAddress'] as Map<String, dynamic>));
  //     } else {
  //       shippingAddress = null;
  //     }
  //   } else {
  //     shippingAddress = null;
  //   }
  //
  //   carName = json['carName'];
  //   carNumber = json['carNumber'];
  //   carPictureURL = json['carPictureURL'];
  //   inProgressOrderID = json['inProgressOrderID'] ?? [];
  //   orderRequestData = json['orderRequestData'] ?? [];
  //   vendorID = json['vendorID'] ?? '';
  //   zoneId = json['zoneId'] ?? '';
  //   rotation = json['rotation'];
  //   appIdentifier = json['appIdentifier'];
  //   provider = json['provider'];
  //   subscriptionPlanId = json['subscriptionPlanId'];
  //
  //   // Handle subscriptionExpiryDate
  //   if (json['subscriptionExpiryDate'] != null) {
  //     if (json['subscriptionExpiryDate'] is Timestamp) {
  //       subscriptionExpiryDate = json['subscriptionExpiryDate'];
  //     } else if (json['subscriptionExpiryDate'] is String) {
  //       try {
  //         final dateTime = DateTime.parse(json['subscriptionExpiryDate']);
  //         subscriptionExpiryDate = Timestamp.fromDate(dateTime);
  //       } catch (e) {
  //         subscriptionExpiryDate = null;
  //       }
  //     } else if (json['subscriptionExpiryDate'] is Map) {
  //       try {
  //         subscriptionExpiryDate = Timestamp(
  //           json['subscriptionExpiryDate']['seconds'] ?? 0,
  //           json['subscriptionExpiryDate']['nanoseconds'] ?? 0,
  //         );
  //       } catch (e) {
  //         subscriptionExpiryDate = null;
  //       }
  //     }
  //   } else {
  //     subscriptionExpiryDate = null;
  //   }
  //
  //   // Handle subscription_plan
  //   if (json['subscription_plan'] != null) {
  //     if (json['subscription_plan'] is Map<String, dynamic>) {
  //       subscriptionPlan = SubscriptionPlanModel.fromJson(json['subscription_plan'] as Map<String, dynamic>);
  //     } else if (json['subscription_plan'] is String) {
  //       // If it's just a string, create a basic SubscriptionPlanModel
  //       subscriptionPlan = SubscriptionPlanModel(
  //         id: 'temp_id',
  //         name: json['subscription_plan'] as String,
  //         // Add other default values as needed
  //       );
  //     } else {
  //       subscriptionPlan = null;
  //     }
  //   } else {
  //     subscriptionPlan = null;
  //   }
  // }
  UserModel.fromJson(Map<String, dynamic> json) {
    if (json['id'] != null) {
      id = json['id'].toString();
    }
    firebaseId = json['firebase_id']?.toString() ?? json['id']?.toString();
    email = json['email'];
    firstName = json['firstName'];
    lastName = json['lastName'];
    profilePictureURL = json['profilePictureURL'] ?? json['profile_pic'];
    fcmToken = json['fcmToken'];
    countryCode = json['countryCode'];
    if (json['phoneNumber'] != null) {
      if (json['phoneNumber'] is int) {
        phoneNumber = json['phoneNumber'].toString();
      } else if (json['phoneNumber'] is String) {
        phoneNumber = json['phoneNumber'];
      } else {
        phoneNumber = json['phoneNumber']?.toString();
      }
    } else if (json['phone'] != null) {
      // Fallback to 'phone' field if 'phoneNumber' doesn't exist
      if (json['phone'] is int) {
        phoneNumber = json['phone'].toString();
      } else if (json['phone'] is String) {
        phoneNumber = json['phone'];
      } else {
        phoneNumber = json['phone']?.toString();
      }
    }
    walletAmount = json['wallet_amount'] is String
        ? double.tryParse(json['wallet_amount']) ?? 0
        : (json['wallet_amount'] ?? 0);
    deliveryAmount = json['deliveryAmount'] is String
        ? double.tryParse(json['deliveryAmount']) ?? 0
        : (json['deliveryAmount'] ?? 0);

    // Handle createdAt
    if (json['createdAt'] != null) {
      if (json['createdAt'] is Timestamp) {
        createdAt = json['createdAt'];
      } else if (json['createdAt'] is String) {
        try {
          final dateTime = DateTime.parse(json['createdAt']);
          createdAt = Timestamp.fromDate(dateTime);
        } catch (e) {
          createdAt = null;
        }
      } else if (json['createdAt'] is Map) {
        try {
          createdAt = Timestamp(
            json['createdAt']['seconds'] ?? 0,
            json['createdAt']['nanoseconds'] ?? 0,
          );
        } catch (e) {
          createdAt = null;
        }
      } else if (json['createdAt'] is int) {
        createdAt = Timestamp.fromMillisecondsSinceEpoch(json['createdAt']);
      }
    } else {
      createdAt = null;
    }

    bool? _parseNullableBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final v = value.trim().toLowerCase();
        if (v == '1' || v == 'true' || v == 'yes') return true;
        if (v == '0' || v == 'false' || v == 'no') return false;
      }
      return null;
    }

    active = _parseNullableBool(json['active']);
    isActive = _parseNullableBool(json['isActive']);
    // Backend may send one of the two keys; mirror to avoid accidental false writes.
    if (active == null && isActive != null) active = isActive;
    if (isActive == null && active != null) isActive = active;
    isDocumentVerify =
        json['isDocumentVerify'] == "1" ||
        json['isDocumentVerify'] == true ||
        json['isDocumentVerify'] == 1;
    print("isDocumentVerify  $isDocumentVerify");
    role = json['role'] ?? 'user';

    // Fix for location handling - check if it's a string that needs parsing
    if (json['location'] != null) {
      dynamic locationData = json['location'];

      if (locationData is String) {
        try {
          final parsed = jsonDecode(locationData);
          if (parsed is Map<String, dynamic>) {
            location = UserLocation.fromJson(parsed);
          }
        } catch (e) {
          print('Error parsing location string: $e');
          location = null;
        }
      } else if (locationData is List) {
        final locationList = locationData as List;
        if (locationList.isNotEmpty) {
          final firstItem = locationList.first;
          if (firstItem is Map<String, dynamic>) {
            location = UserLocation.fromJson(firstItem);
          } else {
            location = null;
          }
        } else {
          location = null;
        }
      } else if (locationData is Map<String, dynamic>) {
        location = UserLocation.fromJson(locationData as Map<String, dynamic>);
      } else {
        location = null;
      }
    } else {
      location = null;
    }

    // Fix for userBankDetails handling - check if it's a string that needs parsing
    if (json['userBankDetails'] != null) {
      dynamic bankDetailsData = json['userBankDetails'];

      if (bankDetailsData is String) {
        try {
          final parsed = jsonDecode(bankDetailsData);
          if (parsed is Map<String, dynamic>) {
            userBankDetails = UserBankDetails.fromJson(parsed);
          }
        } catch (e) {
          print('Error parsing userBankDetails string: $e');
          userBankDetails = null;
        }
      } else if (bankDetailsData is List) {
        final list = bankDetailsData as List;
        if (list.isNotEmpty) {
          final firstItem = list.first;
          if (firstItem is Map<String, dynamic>) {
            userBankDetails = UserBankDetails.fromJson(firstItem);
          } else {
            userBankDetails = null;
          }
        } else {
          userBankDetails = null;
        }
      } else if (bankDetailsData is Map<String, dynamic>) {
        userBankDetails = UserBankDetails.fromJson(
          bankDetailsData as Map<String, dynamic>,
        );
      } else {
        userBankDetails = null;
      }
    } else {
      userBankDetails = null;
    }

    // Fix for shippingAddress handling - check if it's a string that needs parsing
    if (json['shippingAddress'] != null) {
      dynamic shippingData = json['shippingAddress'];

      if (shippingData is String) {
        try {
          final parsed = jsonDecode(shippingData);
          if (parsed is List) {
            shippingAddress = <ShippingAddress>[];
            for (var item in parsed) {
              if (item is Map<String, dynamic>) {
                shippingAddress!.add(ShippingAddress.fromJson(item));
              }
            }
          } else if (parsed is Map<String, dynamic>) {
            shippingAddress = <ShippingAddress>[];
            shippingAddress!.add(ShippingAddress.fromJson(parsed));
          }
        } catch (e) {
          print('Error parsing shippingAddress string: $e');
          shippingAddress = null;
        }
      } else if (shippingData is List) {
        final list = shippingData as List;
        shippingAddress = <ShippingAddress>[];
        for (var item in list) {
          if (item is Map<String, dynamic>) {
            shippingAddress!.add(ShippingAddress.fromJson(item));
          }
        }
      } else if (shippingData is Map<String, dynamic>) {
        shippingAddress = <ShippingAddress>[];
        shippingAddress!.add(
          ShippingAddress.fromJson(shippingData as Map<String, dynamic>),
        );
      } else {
        shippingAddress = null;
      }
    } else {
      shippingAddress = null;
    }

    carName = json['carName'];
    carNumber = json['carNumber'];
    carPictureURL = json['carPictureURL'];

    // Fix for inProgressOrderID - check if it's a string that needs parsing
    if (json['inProgressOrderID'] != null) {
      dynamic orderIdData = json['inProgressOrderID'];
      if (orderIdData is String) {
        try {
          final parsed = jsonDecode(orderIdData);
          if (parsed is List) {
            inProgressOrderID = parsed;
          } else {
            inProgressOrderID = [];
          }
        } catch (e) {
          print('Error parsing inProgressOrderID string: $e');
          inProgressOrderID = [];
        }
      } else if (orderIdData is List) {
        inProgressOrderID = orderIdData;
      } else {
        inProgressOrderID = [];
      }
    } else {
      inProgressOrderID = [];
    }

    // Fix for orderRequestData - check if it's a string that needs parsing
    if (json['orderRequestData'] != null) {
      dynamic orderRequestDataJson = json['orderRequestData'];
      if (orderRequestDataJson is String) {
        try {
          final parsed = jsonDecode(orderRequestDataJson);
          if (parsed is List) {
            orderRequestData = parsed;
          } else {
            orderRequestData = [];
          }
        } catch (e) {
          print('Error parsing orderRequestData string: $e');
          orderRequestData = [];
        }
      } else if (orderRequestDataJson is List) {
        orderRequestData = orderRequestDataJson;
      } else {
        orderRequestData = [];
      }
    } else {
      orderRequestData = [];
    }

    vendorID = json['vendorID'] ?? '';
    zoneId = json['zoneId'] ?? '';
    rotation = json['rotation'] is String
        ? double.tryParse(json['rotation']) ?? 0
        : (json['rotation'] ?? 0);
    appIdentifier = json['appIdentifier'];
    provider = json['provider'];
    subscriptionPlanId = json['subscriptionPlanId'];

    // Handle subscriptionExpiryDate
    if (json['subscriptionExpiryDate'] != null) {
      if (json['subscriptionExpiryDate'] is Timestamp) {
        subscriptionExpiryDate = json['subscriptionExpiryDate'];
      } else if (json['subscriptionExpiryDate'] is String) {
        try {
          final dateTime = DateTime.parse(json['subscriptionExpiryDate']);
          subscriptionExpiryDate = Timestamp.fromDate(dateTime);
        } catch (e) {
          subscriptionExpiryDate = null;
        }
      } else if (json['subscriptionExpiryDate'] is Map) {
        try {
          subscriptionExpiryDate = Timestamp(
            json['subscriptionExpiryDate']['seconds'] ?? 0,
            json['subscriptionExpiryDate']['nanoseconds'] ?? 0,
          );
        } catch (e) {
          subscriptionExpiryDate = null;
        }
      } else if (json['subscriptionExpiryDate'] is int) {
        subscriptionExpiryDate = Timestamp.fromMillisecondsSinceEpoch(
          json['subscriptionExpiryDate'],
        );
      }
    } else {
      subscriptionExpiryDate = null;
    }

    if (json['subscription_plan'] != null) {
      if (json['subscription_plan'] is Map<String, dynamic>) {
        subscriptionPlan = SubscriptionPlanModel.fromJson(
          json['subscription_plan'] as Map<String, dynamic>,
        );
      } else if (json['subscription_plan'] is String) {
        try {
          final parsed = jsonDecode(json['subscription_plan']);
          if (parsed is Map<String, dynamic>) {
            subscriptionPlan = SubscriptionPlanModel.fromJson(parsed);
          } else {
            subscriptionPlan = SubscriptionPlanModel(
              id: 'temp_id',
              name: json['subscription_plan'] as String,
            );
          }
        } catch (e) {
          subscriptionPlan = SubscriptionPlanModel(
            id: 'temp_id',
            name: json['subscription_plan'] as String,
          );
        }
      } else {
        subscriptionPlan = null;
      }
    } else {
      subscriptionPlan = null;
    }
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['firebase_id'] = firebaseId;
    data['email'] = email;
    data['firstName'] = firstName;
    data['lastName'] = lastName;
    data['profilePictureURL'] = profilePictureURL;
    data['fcmToken'] = fcmToken;
    data['countryCode'] = countryCode;
    data['phoneNumber'] = phoneNumber;
    // data['wallet_amount'] = walletAmount ?? 0;
    // data['deliveryAmount'] = deliveryAmount ?? 0;
    data['createdAt'] = createdAt;
    data['active'] = active;
    data['isActive'] = isActive;
    data['role'] = role;
    data['isDocumentVerify'] = isDocumentVerify;
    data['zoneId'] = zoneId;
    if (location != null) {
      data['location'] = location!.toJson();
    }

    if (userBankDetails != null) {
      data['userBankDetails'] = userBankDetails!.toJson();
    }

    if (shippingAddress != null) {
      data['shippingAddress'] = shippingAddress!
          .map((v) => v.toJson())
          .toList();
    }

    if (role == Constant.userRoleDriver) {
      data['vendorID'] = vendorID;
      data['carName'] = carName;
      data['carNumber'] = carNumber;
      data['carPictureURL'] = carPictureURL;
      data['inProgressOrderID'] = inProgressOrderID;
      data['orderRequestData'] = orderRequestData;
      data['rotation'] = rotation;
    }

    if (role == Constant.userRoleVendor) {
      data['vendorID'] = vendorID;
      data['subscriptionPlanId'] = subscriptionPlanId;
      data['subscriptionExpiryDate'] = subscriptionExpiryDate;
      data['subscription_plan'] = subscriptionPlan?.toJson();
    }

    data['appIdentifier'] = appIdentifier;
    data['provider'] = provider;

    return data;
  }
}

class UserLocation {
  double? latitude;
  double? longitude;

  UserLocation({this.latitude, this.longitude});

  static double? _scalarToDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  static double? _coordFromJson(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      final d = _scalarToDouble(v);
      if (d != null) return d;
    }
    return null;
  }

  /// Parses lat/lng from Firestore [GeoPoint], nested maps, GeoJSON Point, or [lng, lat] lists.
  static UserLocation? tryParseCoords(dynamic data) {
    if (data == null) return null;
    if (data is GeoPoint) {
      return UserLocation(latitude: data.latitude, longitude: data.longitude);
    }
    if (data is List) {
      if (data.length < 2) return null;
      final a = _scalarToDouble(data[0]);
      final b = _scalarToDouble(data[1]);
      if (a == null || b == null) return null;
      // Same convention as route decoding in HomeController: [lng, lat]
      return UserLocation(latitude: b, longitude: a);
    }
    if (data is! Map) return null;
    final json = Map<String, dynamic>.from(data);
    var lat = _coordFromJson(json, const [
      'latitude',
      'lat',
      'Lat',
      '_latitude',
    ]);
    var lng = _coordFromJson(json, const [
      'longitude',
      'lng',
      'long',
      'Lon',
      '_longitude',
    ]);
    if (lat != null && lng != null) {
      return UserLocation(latitude: lat, longitude: lng);
    }
    final geom = json['geometry'];
    if (geom is Map) {
      final gm = Map<String, dynamic>.from(geom);
      final loc = gm['location'];
      if (loc is Map) {
        final lm = Map<String, dynamic>.from(loc);
        lat ??= _coordFromJson(lm, const ['lat', 'latitude']);
        lng ??= _coordFromJson(lm, const ['lng', 'longitude']);
      }
    }
    if (lat != null && lng != null) {
      return UserLocation(latitude: lat, longitude: lng);
    }
    if (json['type']?.toString() == 'Point' && json['coordinates'] is List) {
      final c = json['coordinates'] as List;
      if (c.length >= 2) {
        final a = _scalarToDouble(c[0]);
        final b = _scalarToDouble(c[1]);
        if (a != null && b != null) {
          return UserLocation(latitude: b, longitude: a);
        }
      }
    }
    if (json['coordinates'] is Map) {
      final cm = Map<String, dynamic>.from(json['coordinates'] as Map);
      lat ??= _coordFromJson(cm, const ['latitude', 'lat', '_latitude']);
      lng ??= _coordFromJson(cm, const ['longitude', 'lng', '_longitude']);
    }
    if (lat != null && lng != null) {
      return UserLocation(latitude: lat, longitude: lng);
    }
    return null;
  }

  UserLocation.fromJson(Map<String, dynamic> json) {
    final parsed = tryParseCoords(json);
    latitude = parsed?.latitude;
    longitude = parsed?.longitude;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    return data;
  }
}

class ShippingAddress {
  String? id;
  String? address;
  String? addressAs;
  String? landmark;
  String? locality;
  UserLocation? location;
  bool? isDefault;

  ShippingAddress({
    this.address,
    this.landmark,
    this.locality,
    this.location,
    this.isDefault,
    this.addressAs,
    this.id,
  });

  ShippingAddress.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    address = json['address'];
    landmark = json['landmark'];
    locality = json['locality'];

    // Handle isDefault that could be bool, int, or string
    if (json['isDefault'] != null) {
      if (json['isDefault'] is bool) {
        isDefault = json['isDefault'];
      } else if (json['isDefault'] is int) {
        isDefault = json['isDefault'] == 1;
      } else if (json['isDefault'] is String) {
        isDefault =
            json['isDefault'] == '1' ||
            json['isDefault'].toLowerCase() == 'true';
      } else {
        isDefault = null;
      }
    } else {
      isDefault = null;
    }
    addressAs = json['addressAs'];
    location = UserLocation.tryParseCoords(json['location']);
    location ??= UserLocation.tryParseCoords(json['coordinates']);
    location ??= UserLocation.tryParseCoords(
      json['geoPoint'] ?? json['geopoint'],
    );
    if (location == null ||
        location!.latitude == null ||
        location!.longitude == null) {
      final flat = UserLocation.tryParseCoords(json);
      if (flat?.latitude != null && flat?.longitude != null) {
        location = flat;
      }
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['address'] = address;
    data['landmark'] = landmark;
    data['locality'] = locality;
    data['isDefault'] = isDefault;
    data['addressAs'] = addressAs;
    if (location != null) {
      data['location'] = location!.toJson();
    }
    return data;
  }

  String getFullAddress() {
    return '$locality ${landmark == null || landmark!.isEmpty ? "" : landmark.toString()}';
  }
}

class UserBankDetails {
  String bankName;
  String branchName;
  String holderName;
  String accountNumber;
  String otherDetails;

  UserBankDetails({
    this.bankName = '',
    this.otherDetails = '',
    this.branchName = '',
    this.accountNumber = '',
    this.holderName = '',
  });

  factory UserBankDetails.fromJson(Map<String, dynamic> parsedJson) {
    return UserBankDetails(
      bankName: parsedJson['bankName'] ?? '',
      branchName: parsedJson['branchName'] ?? '',
      holderName: parsedJson['holderName'] ?? '',
      accountNumber: parsedJson['accountNumber'] ?? '',
      otherDetails: parsedJson['otherDetails'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bankName': bankName,
      'branchName': branchName,
      'holderName': holderName,
      'accountNumber': accountNumber,
      'otherDetails': otherDetails,
    };
  }
}
