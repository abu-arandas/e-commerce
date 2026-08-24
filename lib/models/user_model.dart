import '../core/utils/json_parse.dart';

/// Application roles (PRD §2). Storefront customers plus the three back-office
/// personas, and a super `admin`.
enum AppRole {
  customer,
  catalogManager,
  marketingManager,
  fulfillment,
  admin;

  static AppRole fromDb(String? v) {
    switch (v) {
      case 'catalog_manager':
        return AppRole.catalogManager;
      case 'marketing_manager':
        return AppRole.marketingManager;
      case 'fulfillment':
        return AppRole.fulfillment;
      case 'admin':
        return AppRole.admin;
      case 'customer':
      default:
        return AppRole.customer;
    }
  }

  String get db => switch (this) {
    AppRole.customer => 'customer',
    AppRole.catalogManager => 'catalog_manager',
    AppRole.marketingManager => 'marketing_manager',
    AppRole.fulfillment => 'fulfillment',
    AppRole.admin => 'admin',
  };

  String get label => switch (this) {
    AppRole.customer => 'Customer',
    AppRole.catalogManager => 'Catalog Manager',
    AppRole.marketingManager => 'Marketing Manager',
    AppRole.fulfillment => 'Fulfillment Specialist',
    AppRole.admin => 'Administrator',
  };

  bool get isStaff => this != AppRole.customer;
  bool get canManageCatalog =>
      this == AppRole.catalogManager || this == AppRole.admin;
  bool get canManagePromotions =>
      this == AppRole.marketingManager || this == AppRole.admin;
  bool get canManageOrders =>
      this == AppRole.fulfillment || this == AppRole.admin;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.fullName,
    this.role = AppRole.customer,
    this.phone,
  });

  final String id;
  final String email;
  final String? fullName;
  final AppRole role;
  final String? phone;

  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty) {
      return fullName!.trim();
    }
    final handle = email.split('@').first;
    return handle.isEmpty ? 'Guest' : handle;
  }

  String get initials {
    final n = displayName.trim();
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts.first[0] + parts.last[0]).toUpperCase();
    }
    return n.isNotEmpty ? n.substring(0, 1).toUpperCase() : '?';
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: J.str(json['id']),
    email: J.str(json['email']),
    fullName: J.strOrNull(json['full_name']),
    role: AppRole.fromDb(J.strOrNull(json['role'])),
    phone: J.strOrNull(json['phone']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'role': role.db,
    'phone': phone,
  };

  AppUser copyWith({String? fullName, AppRole? role, String? phone}) => AppUser(
    id: id,
    email: email,
    fullName: fullName ?? this.fullName,
    role: role ?? this.role,
    phone: phone ?? this.phone,
  );
}

class Address {
  const Address({
    required this.id,
    required this.line1,
    required this.city,
    this.label,
    this.line2,
    this.region,
    this.postalCode,
    this.country = 'US',
    this.isDefault = false,
  });

  final String id;
  final String? label;
  final String line1;
  final String? line2;
  final String city;
  final String? region;
  final String? postalCode;
  final String country;
  final bool isDefault;

  String get formatted {
    final parts = <String>[
      line1,
      if (line2 != null && line2!.isNotEmpty) line2!,
      [
        city,
        region,
        postalCode,
      ].where((e) => e != null && e.isNotEmpty).join(', '),
      country,
    ];
    return parts.where((e) => e.trim().isNotEmpty).join('\n');
  }

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    id: J.str(json['id']),
    label: J.strOrNull(json['label']),
    line1: J.str(json['line1']),
    line2: J.strOrNull(json['line2']),
    city: J.str(json['city']),
    region: J.strOrNull(json['region']),
    postalCode: J.strOrNull(json['postal_code']),
    country: J.str(json['country'], 'US'),
    isDefault: J.toBool(json['is_default']),
  );

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'label': label,
    'line1': line1,
    'line2': line2,
    'city': city,
    'region': region,
    'postal_code': postalCode,
    'country': country,
    'is_default': isDefault,
  };
}
