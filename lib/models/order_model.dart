import '../core/utils/json_parse.dart';

enum OrderStatus {
  pending,
  paid,
  processing,
  shipped,
  delivered,
  cancelled,
  refunded;

  static OrderStatus fromDb(String? v) {
    for (final s in OrderStatus.values) {
      if (s.name == v) return s;
    }
    return OrderStatus.pending;
  }

  String get label => switch (this) {
    OrderStatus.pending => 'Pending',
    OrderStatus.paid => 'Paid',
    OrderStatus.processing => 'Processing',
    OrderStatus.shipped => 'Shipped',
    OrderStatus.delivered => 'Delivered',
    OrderStatus.cancelled => 'Cancelled',
    OrderStatus.refunded => 'Refunded',
  };

  /// Ordered pipeline used by the fulfillment grid's status stepper.
  static const List<OrderStatus> pipeline = [
    OrderStatus.pending,
    OrderStatus.paid,
    OrderStatus.processing,
    OrderStatus.shipped,
    OrderStatus.delivered,
  ];
}

class OrderLine {
  const OrderLine({
    required this.id,
    required this.productTitle,
    required this.sku,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    this.variantName,
    this.sizeLabel,
    this.category,
  });

  final String id;
  final String productTitle;
  final String? variantName;
  final String? sizeLabel;

  /// Snapshotted at checkout so revenue reporting survives a product being
  /// re-categorised, renamed or deleted (order_items.category).
  final String? category;
  final String sku;
  final double unitPrice;
  final int quantity;
  final double lineTotal;

  String get variantSummary => [
    variantName,
    sizeLabel,
  ].where((e) => e != null && e.isNotEmpty).join(' · ');

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
    id: J.str(json['id']),
    productTitle: J.str(json['product_title']),
    variantName: J.strOrNull(json['variant_name']),
    sizeLabel: J.strOrNull(json['size_label']),
    sku: J.str(json['sku']),
    category: J.strOrNull(json['category']),
    unitPrice: J.toDouble(json['unit_price']),
    quantity: J.toInt(json['quantity']),
    lineTotal: J.toDouble(json['line_total']),
  );
}

class Order {
  const Order({
    required this.id,
    required this.status,
    required this.subtotal,
    required this.discountTotal,
    required this.shippingTotal,
    required this.grandTotal,
    this.userId,
    this.promoCode,
    this.contactEmail,
    this.trackingNumber,
    this.lines = const [],
    this.createdAt,
  });

  final String id;
  final String? userId;
  final OrderStatus status;
  final double subtotal;
  final double discountTotal;
  final double shippingTotal;
  final double grandTotal;
  final String? promoCode;
  final String? contactEmail;
  final String? trackingNumber;
  final List<OrderLine> lines;
  final DateTime? createdAt;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);

  /// Short human reference derived from the UUID.
  String get reference =>
      id.length >= 8 ? '#${id.substring(0, 8).toUpperCase()}' : '#$id';

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawLines = (json['order_items'] as List?) ?? const [];
    return Order(
      id: J.str(json['id']),
      userId: J.strOrNull(json['user_id']),
      status: OrderStatus.fromDb(J.strOrNull(json['status'])),
      subtotal: J.toDouble(json['subtotal']),
      discountTotal: J.toDouble(json['discount_total']),
      shippingTotal: J.toDouble(json['shipping_total']),
      grandTotal: J.toDouble(json['grand_total']),
      promoCode: J.strOrNull(json['promo_code']),
      contactEmail: J.strOrNull(json['contact_email']),
      trackingNumber: J.strOrNull(json['tracking_number']),
      createdAt: J.dateOrNull(json['created_at']),
      lines: rawLines
          .map((e) => OrderLine.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
