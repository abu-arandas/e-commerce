import 'package:get/get.dart';

import '../core/utils/app_constants.dart';
import '../core/utils/demo_data.dart';
import '../core/utils/json_parse.dart';
import '../core/utils/supabase_service.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/promotion_model.dart';
import '../models/variant_model.dart';

/// A denormalised low-stock alert row for the fulfillment dashboard.
class LowStockEntry {
  const LowStockEntry({
    required this.productTitle,
    required this.colorName,
    required this.sizeLabel,
    required this.sku,
    required this.stock,
    required this.threshold,
  });
  final String productTitle;
  final String colorName;
  final String sizeLabel;
  final String sku;
  final int stock;
  final int threshold;

  bool get isOut => stock <= 0;
}

/// Back-office controller: dashboard analytics and CMS logic for catalog,
/// promotions, and orders (PRD §3.2). Works against Supabase when configured,
/// otherwise mutates in-memory demo collections so the panels stay interactive.
class AdminController extends GetxController {
  final RxList<Product> products = <Product>[].obs;
  final RxList<Promotion> promotions = <Promotion>[].obs;
  final RxList<Order> orders = <Order>[].obs;

  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  Map<String, double>? _cachedRevenueByCategory;
  // Cached totals
  final RxInt _cachedTotalSkus = 0.obs;

  late final RxList<LowStockEntry> _lowStock = <LowStockEntry>[].obs;

  @override
  void onInit() {
    super.onInit();
    ever(products, (_) => _cachedRevenueByCategory = null);
    ever(orders, (_) => _cachedRevenueByCategory = null);

    // Performance optimization: calculate SKUs once reactively instead of dynamically
    // flattening the deep product/group/item tree on every getter access.
    ever(products, (_) => _updateTotalSkus());

    // Re-evaluate low stock whenever the products list changes
    ever(products, (_) => _updateLowStock());

    refreshAll();
  }

  void _updateTotalSkus() {
    _cachedTotalSkus.value = products.fold<int>(0, (sum, p) => sum + p.allItems.length);
  }

  Future<void> refreshAll() async {
    isLoading.value = true;
    error.value = '';
    try {
      await Future.wait(
          [_loadProducts(), _loadPromotions(), _loadOrders(), _loadStats()]);
    } catch (e) {
      error.value = 'Failed to load admin data: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadProducts() async {
    if (SupabaseService.isReady) {
      final rows = await SupabaseService.client
          .from(AppConstants.tblProducts)
          .select('*, variant_groups(*, variant_items(*))')
          .order('created_at');
      products.assignAll((rows as List)
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList());
    } else {
      products.assignAll(DemoData.products());
    }
  }

  Future<void> _loadPromotions() async {
    if (SupabaseService.isReady) {
      final rows = await SupabaseService.client
          .from(AppConstants.tblPromotions)
          .select()
          .order('created_at', ascending: false);
      promotions.assignAll((rows as List)
          .map((e) => Promotion.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList());
    } else {
      promotions.assignAll(DemoData.promotions());
    }
  }

  Future<void> _loadOrders() async {
    if (SupabaseService.isReady) {
      final rows = await SupabaseService.client
          .from(AppConstants.tblOrders)
          .select('*, order_items(*)')
          .order('created_at', ascending: false)
          .limit(100);
      orders.assignAll((rows as List)
          .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList());
    } else {
      orders.assignAll(_demoOrders());
    }
  }

  /// Dashboard totals aggregated in the database.
  ///
  /// The order list is paged (the most recent 100), so folding revenue over it
  /// under-reports as soon as the store passes one page. `admin_stats()` sums
  /// over every order; these hold its answer, and the getters below fall back
  /// to the local fold in demo mode.
  final Rxn<Map<String, dynamic>> _stats = Rxn<Map<String, dynamic>>();

  Future<void> _loadStats() async {
    if (!SupabaseService.isReady) {
      _stats.value = null;
      return;
    }
    try {
      final res = await SupabaseService.client.rpc(AppConstants.rpcAdminStats);
      _stats.value = Map<String, dynamic>.from(res as Map);
    } catch (_) {
      _stats.value = null; // fall back to the local fold
    }
  }

  // ---------------------------------------------------------------------------
  // Dashboard analytics
  // ---------------------------------------------------------------------------
  int get totalProducts => products.length;
  int get activeProducts => products.where((p) => p.isActive).length;

  // Uses a cached reactive value updated when the products list changes
  // to avoid O(N*M) flattening cost on every build cycle.
  int get totalSkus => _cachedTotalSkus.value;

  int get totalOrders =>
      J.toInt(_stats.value?['total_orders'], orders.length);

  int get pendingOrders => J.toInt(
      _stats.value?['pending_orders'],
      orders
          .where((o) =>
              o.status == OrderStatus.pending || o.status == OrderStatus.paid)
          .length);

  double get grossRevenue => J.toDouble(
      _stats.value?['gross_revenue'],
      orders
          .where((o) =>
              o.status != OrderStatus.cancelled &&
              o.status != OrderStatus.refunded)
          .fold(0.0, (sum, o) => sum + o.grandTotal));

  double get averageOrderValue {
    // Averaged over the orders that contributed revenue, so cancellations and
    // refunds do not drag the figure down.
    final n = J.toInt(_stats.value?['revenue_orders'], orders.length);
    return n == 0 ? 0 : grossRevenue / n;
  }

  int get activePromotions => promotions.where((p) => p.isLive).length;

  List<LowStockEntry> get lowStock => _lowStock;

  void _updateLowStock() {
    final entries = <LowStockEntry>[];
    for (final p in products) {
      for (final g in p.groups) {
        for (final i in g.items) {
          if (i.stockQuantity <= i.lowStockThreshold) {
            entries.add(LowStockEntry(
              productTitle: p.title,
              colorName: g.name,
              sizeLabel: i.sizeLabel,
              sku: i.sku,
              stock: i.stockQuantity,
              threshold: i.lowStockThreshold,
            ));
          }
        }
      }
    }
    entries.sort((a, b) => a.stock.compareTo(b.stock));
    _lowStock.assignAll(entries);
  }

  /// Revenue split by product category (for the dashboard breakdown chart).
  Map<String, double> get revenueByCategory {
    if (_cachedRevenueByCategory != null) {
      return _cachedRevenueByCategory!;
    }

    final serverBreakdown = _stats.value?['revenue_by_category'];
    if (serverBreakdown is Map) {
      return _cachedRevenueByCategory = {
        for (final e in serverBreakdown.entries)
          e.key.toString(): J.toDouble(e.value),
      };
    }

    // Demo/simple attribution: distribute each order's total across its lines'
    // products by matching titles to catalog categories.
    final byCat = <String, double>{};
    final titleToCat = {for (final p in products) p.title: p.category ?? 'Other'};
    for (final o in orders) {
      for (final line in o.lines) {
        // Prefer the category snapshotted on the line; fall back to matching
        // the live catalogue by title for rows written before that column.
        final cat = line.category ?? titleToCat[line.productTitle] ?? 'Other';
        byCat[cat] = (byCat[cat] ?? 0) + line.lineTotal;
      }
    }

    _cachedRevenueByCategory = byCat;
    return byCat;
  }

  List<Order> get recentOrders => orders.take(8).toList();

  // ---------------------------------------------------------------------------
  // Catalog CMS
  // ---------------------------------------------------------------------------
  Future<void> saveProduct(Product product) async {
    if (SupabaseService.isReady) {
      // save_product() writes the product together with its colour groups and
      // SKUs, and prunes what the editor removed. A plain table upsert wrote
      // only the product row, silently dropping the whole variant tree.
      await SupabaseService.client.rpc(
        AppConstants.rpcSaveProduct,
        params: {'p_product': _productPayload(product)},
      );
      await _loadProducts();
    } else {
      final idx = products.indexWhere((p) => p.id == product.id);
      if (idx >= 0) {
        products[idx] = product;
      } else {
        products.add(product);
      }
      products.refresh();
    }
  }

  /// The product with its groups and items nested, matching what
  /// `save_product(jsonb)` expects.
  Map<String, dynamic> _productPayload(Product product) => {
        ...product.toJson(),
        'groups': [
          for (final g in product.groups)
            {
              ...g.toJson(),
              'items': [for (final i in g.items) i.toJson()],
            },
        ],
      };

  Future<void> toggleProductActive(Product product) async {
    await saveProduct(product.copyWith(isActive: !product.isActive));
  }

  Future<void> deleteProduct(String id) async {
    if (SupabaseService.isReady) {
      await SupabaseService.client.from(AppConstants.tblProducts).delete().eq('id', id);
    }
    products.removeWhere((p) => p.id == id);
  }

  /// Bulk-generate size variants for a colour group (PRD §3.2 "generate
  /// grandchild variants … with unique SKUs … in bulk"). [skuPrefix] is combined
  /// with each size to form the SKU, e.g. `CASH-TURT-BLU` + `M` → `CASH-TURT-BLU-M`.
  List<VariantItem> generateVariants({
    required String groupId,
    required String skuPrefix,
    required List<String> sizes,
    required int stockPerSize,
    double? priceOverride,
  }) {
    final items = <VariantItem>[];
    for (var i = 0; i < sizes.length; i++) {
      final size = sizes[i].trim();
      if (size.isEmpty) continue;
      items.add(VariantItem(
        id: '',
        groupId: groupId,
        sku: '$skuPrefix-${size.toUpperCase()}',
        sizeLabel: size,
        stockQuantity: stockPerSize,
        priceOverride: priceOverride,
        sortOrder: i,
      ));
    }
    return items;
  }

  // ---------------------------------------------------------------------------
  // Promotions CMS
  // ---------------------------------------------------------------------------
  Future<void> savePromotion(Promotion promo) async {
    if (SupabaseService.isReady) {
      await SupabaseService.client
          .from(AppConstants.tblPromotions)
          .upsert(promo.toJson());
      await _loadPromotions();
    } else {
      final idx = promotions.indexWhere((p) => p.id == promo.id);
      if (idx >= 0) {
        promotions[idx] = promo;
      } else {
        promotions.add(promo);
      }
      promotions.refresh();
    }
  }

  Future<void> deletePromotion(String id) async {
    if (SupabaseService.isReady) {
      await SupabaseService.client.from(AppConstants.tblPromotions).delete().eq('id', id);
    }
    promotions.removeWhere((p) => p.id == id);
  }

  // ---------------------------------------------------------------------------
  // Orders / fulfillment
  // ---------------------------------------------------------------------------
  Future<void> updateOrderStatus(Order order, OrderStatus status) async {
    if (SupabaseService.isReady) {
      await SupabaseService.client
          .from(AppConstants.tblOrders)
          .update({'status': status.name}).eq('id', order.id);
      await _loadOrders();
    } else {
      final idx = orders.indexWhere((o) => o.id == order.id);
      if (idx >= 0) {
        orders[idx] = Order(
          id: order.id,
          userId: order.userId,
          status: status,
          subtotal: order.subtotal,
          discountTotal: order.discountTotal,
          shippingTotal: order.shippingTotal,
          grandTotal: order.grandTotal,
          promoCode: order.promoCode,
          contactEmail: order.contactEmail,
          trackingNumber: order.trackingNumber,
          lines: order.lines,
          createdAt: order.createdAt,
        );
        orders.refresh();
      }
    }
  }

  // ---- Demo order fixtures ----
  List<Order> _demoOrders() {
    final now = DateTime.now();
    return [
      Order(
        id: 'ord-1001-aaaa-aaaa-aaaaaaaaaaaa',
        status: OrderStatus.paid,
        subtotal: 434,
        discountTotal: 86.8,
        shippingTotal: 0,
        grandTotal: 347.2,
        promoCode: 'FALL20',
        contactEmail: 'ada@example.com',
        createdAt: now.subtract(const Duration(hours: 3)),
        lines: const [
          OrderLine(id: 'l1', productTitle: 'Cashmere Turtleneck', variantName: 'Midnight Blue', sizeLabel: 'M', sku: 'CASH-TURT-BLU-M', unitPrice: 245, quantity: 1, lineTotal: 245),
          OrderLine(id: 'l2', productTitle: 'Tailored Wool Trouser', variantName: 'Charcoal', sizeLabel: '32', sku: 'WOOL-TROU-CHR-32', unitPrice: 189, quantity: 1, lineTotal: 189),
        ],
      ),
      Order(
        id: 'ord-1002-bbbb-bbbb-bbbbbbbbbbbb',
        status: OrderStatus.processing,
        subtotal: 320,
        discountTotal: 0,
        shippingTotal: 12,
        grandTotal: 332,
        contactEmail: 'grace@example.com',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        lines: const [
          OrderLine(id: 'l3', productTitle: 'Bias-Cut Silk Slip Dress', variantName: 'Onyx', sizeLabel: 'S', sku: 'SILK-SLIP-ONX-S', unitPrice: 320, quantity: 1, lineTotal: 320),
        ],
      ),
      Order(
        id: 'ord-1003-cccc-cccc-cccccccccccc',
        status: OrderStatus.shipped,
        subtotal: 410,
        discountTotal: 0,
        shippingTotal: 0,
        grandTotal: 410,
        contactEmail: 'linus@example.com',
        trackingNumber: 'VF-TRACK-88213',
        createdAt: now.subtract(const Duration(days: 2, hours: 5)),
        lines: const [
          OrderLine(id: 'l4', productTitle: 'Structured Cotton Trench', variantName: 'Sand', sizeLabel: 'M', sku: 'TRENCH-SND-M', unitPrice: 410, quantity: 1, lineTotal: 410),
        ],
      ),
      Order(
        id: 'ord-1004-dddd-dddd-dddddddddddd',
        status: OrderStatus.delivered,
        subtotal: 490,
        discountTotal: 15,
        shippingTotal: 0,
        grandTotal: 475,
        promoCode: 'WELCOME15',
        contactEmail: 'edsger@example.com',
        createdAt: now.subtract(const Duration(days: 4)),
        lines: const [
          OrderLine(id: 'l5', productTitle: 'Cashmere Turtleneck', variantName: 'Crimson', sizeLabel: 'L', sku: 'CASH-TURT-CRM-L', unitPrice: 245, quantity: 2, lineTotal: 490),
        ],
      ),
    ];
  }
}
