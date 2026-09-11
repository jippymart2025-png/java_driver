import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

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

  num walletAmount;
  num deliveryAmount;

  bool active;
  bool isActive;
  bool isDocumentVerify;

  Timestamp? createdAt;
  String? role;

  UserLocation? location;
  UserBankDetails? userBankDetails;

  List<ShippingAddress> shippingAddress;

  List<String> inProgressOrderID;
  List<dynamic> orderRequestData;

  String? vendorID;
  String zoneId;

  // Nominee
  String? nomineeName;
  String? nomineePhoneNumber;
  bool? isNomineeVerified;

  // Family member
  String? familyMemberName;
  String? familyMemberPhoneNumber;
  bool? isFamilyMemberVerified;

  // KYC
  String? driverKycId;
  String? aadharNumber;
  String? drivingLicenseNumber;
  String? rcCopy;

  // Address
  String? buildingNumber;
  String? road;
  String? landmark;

  String? cityId;
  String? stateId;
  String? areaId;

  UserModel({
    this.id,
    this.firebaseId,
    this.firstName,
    this.lastName,
    this.email,
    this.profilePictureURL,
    this.fcmToken,
    this.countryCode,
    this.phoneNumber,
    this.walletAmount = 0,
    this.deliveryAmount = 0,
    this.active = true,
    this.isActive = true,
    this.isDocumentVerify = false,
    this.createdAt,
    this.role = 'driver',
    this.location,
    this.userBankDetails,
    this.shippingAddress = const [],
    this.inProgressOrderID = const [],
    this.orderRequestData = const [],
    this.vendorID,
    this.zoneId = '',
    this.nomineeName,
    this.nomineePhoneNumber,
    this.isNomineeVerified,
    this.familyMemberName,
    this.familyMemberPhoneNumber,
    this.isFamilyMemberVerified,
    this.driverKycId,
    this.aadharNumber,
    this.drivingLicenseNumber,
    this.rcCopy,
    this.buildingNumber,
    this.road,
    this.landmark,
    this.cityId,
    this.stateId,
    this.areaId,
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String get fullName {
    return [
      firstName,
      lastName,
    ].where((value) => value?.trim().isNotEmpty ?? false).join(' ');
  }

  // ---------------------------------------------------------------------------
  // JSON -> MODEL
  // ---------------------------------------------------------------------------

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _parseString(
        json['id'] ?? json['driverId'],
      ),

      firebaseId: _parseString(
        json['firebase_id'] ??
            json['firebaseId'] ??
            json['id'] ??
            json['driverId'],
      ),

      firstName: _parseString(json['firstName']),
      lastName: _parseString(json['lastName']),
      email: _parseString(json['email']),

      profilePictureURL: _parseString(
        json['profilePicUrl'] ?? json['profilePictureURL'],
      ),

      fcmToken: _parseString(json['fcmToken']),
      countryCode: _parseString(json['countryCode']),
      phoneNumber: _parseString(json['phoneNumber']),

      walletAmount: _parseNum(
        json['wallet_amount'] ?? json['walletAmount'],
      ),

      deliveryAmount: _parseNum(
        json['deliveryAmount'],
      ),

      createdAt: _parseTimestamp(
        json['createdAt'],
      ),

      active: _parseBool(
        json['isActive'],
        defaultValue: true,
      ),

      isActive: _parseBool(
        json['readyToAcceptOrders'],
        defaultValue: true,
      ),

      isDocumentVerify: _parseBool(
        json['isApproved'],
        defaultValue: false,
      ),

      role: _parseString(json['role']) ?? 'driver',

      location: _parseLocation(
        json['location'],
      ),

      userBankDetails: _parseBankDetails(
        json['userBankDetails'],
      ),

      shippingAddress: _parseShippingAddresses(
        json['shippingAddress'],
      ),

      inProgressOrderID: _parseStringList(
        json['inProgressOrderID'],
      ),

      orderRequestData: _parseDynamicList(
        json['orderRequestData'],
      ),

      vendorID: _parseString(
        json['vendorID'],
      ),

      zoneId: _parseString(
        json['zoneId'],
      ) ??
          '',

      nomineeName: _parseString(
        json['nomineeName'],
      ),

      nomineePhoneNumber: _parseString(
        json['nomineePhoneNumber'],
      ),

      isNomineeVerified: _parseNullableBool(
        json['isNomineeVerified'],
      ),

      familyMemberName: _parseString(
        json['familyMemberName'],
      ),

      familyMemberPhoneNumber: _parseString(
        json['familyMemberPhoneNumber'],
      ),

      isFamilyMemberVerified: _parseNullableBool(
        json['isFamilyMemberVerified'],
      ),

      driverKycId: _parseString(
        json['driverKycId'],
      ),

      aadharNumber: _parseString(
        json['aadharNumber'],
      ),

      drivingLicenseNumber: _parseString(
        json['drivingLicenseNumber'],
      ),

      rcCopy: _parseString(
        json['rcCopy'],
      ),

      buildingNumber: _parseString(
        json['buildingNumber'],
      ),

      road: _parseString(
        json['road'],
      ),

      landmark: _parseString(
        json['landmark'],
      ),

      cityId: _parseString(
        json['cityId'],
      ),

      stateId: _parseString(
        json['stateId'],
      ),

      areaId: _parseString(
        json['areaId'],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MODEL -> JSON
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'id': id,
      'firebase_id': firebaseId,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'profilePictureURL': profilePictureURL,
      'fcmToken': fcmToken,
      'countryCode': countryCode,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt,
      'active': active,
      'isActive': isActive,
      'role': role,
      'isApproved': isDocumentVerify,
      'zoneId': zoneId,

      'driverId': id,

      // Nominee
      'nomineeName': nomineeName,
      'nomineePhoneNumber': nomineePhoneNumber,
      'isNomineeVerified': isNomineeVerified,

      // Family member
      'familyMemberName': familyMemberName,
      'familyMemberPhoneNumber': familyMemberPhoneNumber,
      'isFamilyMemberVerified': isFamilyMemberVerified,

      // KYC
      'driverKycId': driverKycId,
      'aadharNumber': aadharNumber,
      'drivingLicenseNumber': drivingLicenseNumber,
      'rcCopy': rcCopy,

      // Address
      'buildingNumber': buildingNumber,
      'road': road,
      'landmark': landmark,
      'cityId': cityId,
      'stateId': stateId,
      'areaId': areaId,
    };

    if (location != null) {
      data['location'] = location!.toJson();
    }

    if (userBankDetails != null) {
      data['userBankDetails'] = userBankDetails!.toJson();
    }

    if (shippingAddress.isNotEmpty) {
      data['shippingAddress'] = shippingAddress
          .map((address) => address.toJson())
          .toList();
    }

    return data;
  }
}

// =============================================================================
// PARSING HELPERS
// =============================================================================

String? _parseString(dynamic value) {
  if (value == null) return null;

  final result = value.toString().trim();

  return result.isEmpty ? null : result;
}

num _parseNum(dynamic value) {
  if (value == null) return 0;

  if (value is num) {
    return value;
  }

  if (value is String) {
    return num.tryParse(value.trim()) ?? 0;
  }

  return 0;
}

bool _parseBool(
    dynamic value, {
      required bool defaultValue,
    }) {
  return _parseNullableBool(value) ?? defaultValue;
}

bool? _parseNullableBool(dynamic value) {
  if (value == null) return null;

  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  if (value is String) {
    final normalized = value.trim().toLowerCase();

    switch (normalized) {
      case '1':
      case 'true':
      case 'yes':
      case 'y':
        return true;

      case '0':
      case 'false':
      case 'no':
      case 'n':
        return false;
    }
  }

  return null;
}

// =============================================================================
// TIMESTAMP
// =============================================================================

Timestamp? _parseTimestamp(dynamic value) {
  if (value == null) return null;

  if (value is Timestamp) {
    return value;
  }

  if (value is DateTime) {
    return Timestamp.fromDate(value);
  }

  if (value is int) {
    return Timestamp.fromMillisecondsSinceEpoch(value);
  }

  if (value is String) {
    final parsed = DateTime.tryParse(value);

    if (parsed != null) {
      return Timestamp.fromDate(parsed);
    }

    return null;
  }

  if (value is Map) {
    try {
      final seconds = _parseInt(value['seconds']);
      final nanoseconds = _parseInt(value['nanoseconds']);

      if (seconds != null) {
        return Timestamp(
          seconds,
          nanoseconds ?? 0,
        );
      }
    } catch (_) {
      return null;
    }
  }

  return null;
}

int? _parseInt(dynamic value) {
  if (value == null) return null;

  if (value is int) return value;

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value.trim());
  }

  return null;
}

// =============================================================================
// LOCATION
// =============================================================================

UserLocation? _parseLocation(dynamic value) {
  if (value == null) return null;

  if (value is String) {
    try {
      final decoded = jsonDecode(value);

      return UserLocation.tryParseCoords(decoded);
    } catch (_) {
      return null;
    }
  }

  return UserLocation.tryParseCoords(value);
}

// =============================================================================
// SHIPPING ADDRESSES
// =============================================================================

List<ShippingAddress> _parseShippingAddresses(
    dynamic value,
    ) {
  if (value == null) {
    return [];
  }

  dynamic data = value;

  if (value is String) {
    try {
      data = jsonDecode(value);
    } catch (_) {
      return [];
    }
  }

  if (data is Map) {
    return [
      ShippingAddress.fromJson(
        Map<String, dynamic>.from(data),
      ),
    ];
  }

  if (data is List) {
    return data
        .whereType<Map>()
        .map(
          (item) => ShippingAddress.fromJson(
        Map<String, dynamic>.from(item),
      ),
    )
        .toList();
  }

  return [];
}

// =============================================================================
// STRING LIST
// =============================================================================

List<String> _parseStringList(dynamic value) {
  if (value == null) {
    return [];
  }

  dynamic data = value;

  if (value is String) {
    try {
      data = jsonDecode(value);
    } catch (_) {
      return [value];
    }
  }

  if (data is List) {
    return data
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  return [];
}

// =============================================================================
// DYNAMIC LIST
// =============================================================================

List<dynamic> _parseDynamicList(dynamic value) {
  if (value == null) {
    return [];
  }

  dynamic data = value;

  if (value is String) {
    try {
      data = jsonDecode(value);
    } catch (_) {
      return [];
    }
  }

  if (data is List) {
    return List<dynamic>.from(data);
  }

  return [];
}

// =============================================================================
// BANK DETAILS
// =============================================================================

UserBankDetails? _parseBankDetails(
    dynamic value,
    ) {
  if (value == null) {
    return null;
  }

  dynamic data = value;

  if (value is String) {
    try {
      data = jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  if (data is Map) {
    return UserBankDetails.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  if (data is List && data.isNotEmpty) {
    final first = data.first;

    if (first is Map) {
      return UserBankDetails.fromJson(
        Map<String, dynamic>.from(first),
      );
    }
  }

  return null;
}

// =============================================================================
// USER LOCATION
// =============================================================================

class UserLocation {
  double? latitude;
  double? longitude;

  UserLocation({
    this.latitude,
    this.longitude,
  });

  static double? _scalarToDouble(dynamic value) {
    if (value == null) return null;

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.trim());
    }

    return null;
  }

  static double? _coordFromJson(
      Map<String, dynamic> json,
      List<String> keys,
      ) {
    for (final key in keys) {
      final value = _scalarToDouble(json[key]);

      if (value != null) {
        return value;
      }
    }

    return null;
  }

  /// Supports:
  /// - Firestore GeoPoint
  /// - [longitude, latitude]
  /// - latitude/longitude maps
  /// - GeoJSON Point
  /// - nested geometry/location
  static UserLocation? tryParseCoords(
      dynamic data,
      ) {
    if (data == null) {
      return null;
    }

    // Firestore GeoPoint
    if (data is GeoPoint) {
      return UserLocation(
        latitude: data.latitude,
        longitude: data.longitude,
      );
    }

    // [longitude, latitude]
    if (data is List) {
      if (data.length < 2) {
        return null;
      }

      final first = _scalarToDouble(data[0]);
      final second = _scalarToDouble(data[1]);

      if (first == null || second == null) {
        return null;
      }

      return UserLocation(
        latitude: second,
        longitude: first,
      );
    }

    if (data is! Map) {
      return null;
    }

    final json = Map<String, dynamic>.from(data);

    double? latitude = _coordFromJson(
      json,
      const [
        'latitude',
        'lat',
        'Lat',
        '_latitude',
      ],
    );

    double? longitude = _coordFromJson(
      json,
      const [
        'longitude',
        'lng',
        'long',
        'Lon',
        '_longitude',
      ],
    );

    if (latitude != null && longitude != null) {
      return UserLocation(
        latitude: latitude,
        longitude: longitude,
      );
    }

    // geometry.location
    final geometry = json['geometry'];

    if (geometry is Map) {
      final geometryMap = Map<String, dynamic>.from(
        geometry,
      );

      final location = geometryMap['location'];

      if (location is Map) {
        final locationMap = Map<String, dynamic>.from(
          location,
        );

        latitude ??= _coordFromJson(
          locationMap,
          const [
            'lat',
            'latitude',
          ],
        );

        longitude ??= _coordFromJson(
          locationMap,
          const [
            'lng',
            'longitude',
          ],
        );
      }
    }

    if (latitude != null && longitude != null) {
      return UserLocation(
        latitude: latitude,
        longitude: longitude,
      );
    }

    // GeoJSON Point
    if (json['type']?.toString() == 'Point' &&
        json['coordinates'] is List) {
      final coordinates = json['coordinates'] as List;

      if (coordinates.length >= 2) {
        final longitude = _scalarToDouble(
          coordinates[0],
        );

        final latitude = _scalarToDouble(
          coordinates[1],
        );

        if (latitude != null && longitude != null) {
          return UserLocation(
            latitude: latitude,
            longitude: longitude,
          );
        }
      }
    }

    // coordinates object
    if (json['coordinates'] is Map) {
      final coordinates = Map<String, dynamic>.from(
        json['coordinates'] as Map,
      );

      latitude ??= _coordFromJson(
        coordinates,
        const [
          'latitude',
          'lat',
          '_latitude',
        ],
      );

      longitude ??= _coordFromJson(
        coordinates,
        const [
          'longitude',
          'lng',
          '_longitude',
        ],
      );
    }

    if (latitude != null && longitude != null) {
      return UserLocation(
        latitude: latitude,
        longitude: longitude,
      );
    }

    return null;
  }

  factory UserLocation.fromJson(
      Map<String, dynamic> json,
      ) {
    final parsed = tryParseCoords(json);

    return UserLocation(
      latitude: parsed?.latitude,
      longitude: parsed?.longitude,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

// =============================================================================
// SHIPPING ADDRESS
// =============================================================================

class ShippingAddress {
  String? id;
  String? address;
  String? addressAs;
  String? landmark;
  String? locality;
  UserLocation? location;
  bool? isDefault;

  ShippingAddress({
    this.id,
    this.address,
    this.addressAs,
    this.landmark,
    this.locality,
    this.location,
    this.isDefault,
  });

  factory ShippingAddress.fromJson(
      Map<String, dynamic> json,
      ) {
    return ShippingAddress(
      id: _parseString(json['id']),
      address: _parseString(json['address']),
      addressAs: _parseString(json['addressAs']),
      landmark: _parseString(json['landmark']),
      locality: _parseString(json['locality']),
      isDefault: _parseNullableBool(
        json['isDefault'],
      ),
      location: _parseShippingLocation(json),
    );
  }

  static UserLocation? _parseShippingLocation(
      Map<String, dynamic> json,
      ) {
    UserLocation? location;

    location = UserLocation.tryParseCoords(
      json['location'],
    );

    location ??= UserLocation.tryParseCoords(
      json['coordinates'],
    );

    location ??= UserLocation.tryParseCoords(
      json['geoPoint'] ?? json['geopoint'],
    );

    if (location != null &&
        location.latitude != null &&
        location.longitude != null) {
      return location;
    }

    return UserLocation.tryParseCoords(json);
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'id': id,
      'address': address,
      'landmark': landmark,
      'locality': locality,
      'isDefault': isDefault,
      'addressAs': addressAs,
    };

    final locationData = location;

    if (locationData != null) {
      data['location'] = locationData.toJson();
    }

    return data;
  }

  String getFullAddress() {
    final parts = <String>[];

    if (locality?.trim().isNotEmpty ?? false) {
      parts.add(locality!.trim());
    }

    if (landmark?.trim().isNotEmpty ?? false) {
      parts.add(landmark!.trim());
    }

    if (address?.trim().isNotEmpty ?? false) {
      parts.add(address!.trim());
    }

    return parts.join(', ');
  }
}

// =============================================================================
// BANK DETAILS
// =============================================================================

class UserBankDetails {
  String bankName;
  String branchName;
  String holderName;
  String accountNumber;
  String otherDetails;

  UserBankDetails({
    this.bankName = '',
    this.branchName = '',
    this.holderName = '',
    this.accountNumber = '',
    this.otherDetails = '',
  });

  factory UserBankDetails.fromJson(
      Map<String, dynamic> json,
      ) {
    return UserBankDetails(
      bankName: _parseString(json['bankName']) ?? '',
      branchName: _parseString(json['branchName']) ?? '',
      holderName: _parseString(json['holderName']) ?? '',
      accountNumber: _parseString(json['accountNumber']) ?? '',
      otherDetails: _parseString(json['otherDetails']) ?? '',
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