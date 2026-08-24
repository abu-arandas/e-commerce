import '../core/utils/json_parse.dart';

enum DiscountType {
  percentage,
  fixedAmount,
  freeShipping;

  static DiscountType fromDb(String? v) {
    switch (v) {
      case 'fixed_amount':
        return DiscountType.fixedAmount;
      case 'free_shipping':
        return DiscountType.freeShipping;
      case 'percentage':
      default:
        return DiscountType.percentage;
    }
  }

  String get db => switch (this) {
    DiscountType.percentage => 'percentage',
    DiscountType.fixedAmount => 'fixed_amount',
    DiscountType.freeShipping => 'free_shipping',
  };

  String get label => switch (this) {
    DiscountType.percentage => 'Percentage off',
    DiscountType.fixedAmount => 'Fixed amount off',
    DiscountType.freeShipping => 'Free shipping',
  };
}

/// A promotion rule (PRD §5.4) with optional targeting and usage limits.
class Promotion {
  const Promotion({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.description,
    this.minOrderValue = 0,
    this.usageLimit,
    this.usageCount = 0,
    this.isActive = true,
    this.includedCategories = const [],
    this.excludedCategories = const [],
    this.validFrom,
    this.validUntil,
  });

  final String id;
  final String code;
  final String? description;
  final DiscountType discountType;
  final double discountValue;
  final double minOrderValue;
  final int? usageLimit;
  final int usageCount;
  final bool isActive;
  final List<String> includedCategories;
  final List<String> excludedCategories;
  final DateTime? validFrom;
  final DateTime? validUntil;

  bool get isExpired =>
      validUntil != null && DateTime.now().isAfter(validUntil!);
  bool get isScheduled =>
      validFrom != null && DateTime.now().isBefore(validFrom!);
  bool get usageExhausted => usageLimit != null && usageCount >= usageLimit!;
  bool get isLive => isActive && !isExpired && !isScheduled && !usageExhausted;

  String get valueLabel => switch (discountType) {
    DiscountType.percentage => '${discountValue.toStringAsFixed(0)}% off',
    DiscountType.fixedAmount => '\$${discountValue.toStringAsFixed(0)} off',
    DiscountType.freeShipping => 'Free shipping',
  };

  factory Promotion.fromJson(Map<String, dynamic> json) => Promotion(
    id: J.str(json['id']),
    code: J.str(json['code']),
    description: J.strOrNull(json['description']),
    discountType: DiscountType.fromDb(J.strOrNull(json['discount_type'])),
    discountValue: J.toDouble(json['discount_value']),
    minOrderValue: J.toDouble(json['min_order_value']),
    usageLimit: json['usage_limit'] == null
        ? null
        : J.toInt(json['usage_limit']),
    usageCount: J.toInt(json['usage_count']),
    isActive: J.toBool(json['is_active'], true),
    includedCategories: J.strList(json['included_categories']),
    excludedCategories: J.strList(json['excluded_categories']),
    validFrom: J.dateOrNull(json['valid_from']),
    validUntil: J.dateOrNull(json['valid_until']),
  );

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'code': code,
    'description': description,
    'discount_type': discountType.db,
    'discount_value': discountValue,
    'min_order_value': minOrderValue,
    'usage_limit': usageLimit,
    'is_active': isActive,
    'included_categories': includedCategories,
    'excluded_categories': excludedCategories,
    'valid_from': validFrom?.toIso8601String(),
    'valid_until': validUntil?.toIso8601String(),
  };
}

/// One cart line reduced to what the promotions engine needs: which category
/// it belongs to, and what it is worth. A category-targeted promotion discounts
/// only the lines it covers, so the engine has to see the basket line by line
/// rather than as a single subtotal.
class PromoLine {
  const PromoLine({required this.category, required this.lineTotal});

  final String? category;
  final double lineTotal;

  /// Wire form for the `validate_promotion(text, jsonb)` RPC.
  Map<String, dynamic> toJson() => {
    'category': category,
    'line_total': lineTotal,
  };
}

/// Result of validating a promo code against a cart subtotal — mirrors the
/// jsonb returned by the `validate_promotion` SQL function.
class PromoValidation {
  const PromoValidation({
    required this.valid,
    this.promotionId,
    this.code,
    this.discountType,
    this.discountAmount = 0,
    this.eligibleSubtotal = 0,
    this.freeShipping = false,
    this.description,
    this.reason,
  });

  final bool valid;
  final String? promotionId;
  final String? code;
  final DiscountType? discountType;
  final double discountAmount;

  /// The portion of the basket the discount was computed against. Equal to the
  /// subtotal for an untargeted promotion; only the covered lines otherwise.
  final double eligibleSubtotal;
  final bool freeShipping;
  final String? description;
  final String? reason;

  factory PromoValidation.invalid(String reason) =>
      PromoValidation(valid: false, reason: reason);

  factory PromoValidation.fromJson(Map<String, dynamic> json) =>
      PromoValidation(
        valid: J.toBool(json['valid']),
        promotionId: J.strOrNull(json['promotion_id']),
        code: J.strOrNull(json['code']),
        discountType: json['discount_type'] == null
            ? null
            : DiscountType.fromDb(J.strOrNull(json['discount_type'])),
        discountAmount: J.toDouble(json['discount_amount']),
        eligibleSubtotal: J.toDouble(json['eligible_subtotal']),
        freeShipping: J.toBool(json['free_shipping']),
        description: J.strOrNull(json['description']),
        reason: J.strOrNull(json['reason']),
      );
}
