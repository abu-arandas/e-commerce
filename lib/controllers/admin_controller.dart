import 'package:get/get.dart';

import '../core/utils/app_constants.dart';
import '../core/utils/demo_data.dart';
import '../core/utils/json_parse.dart';
import '../core/utils/supabase_service.dart';
import '../core/utils/uuid.dart';
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

/// Store-wide totals computed by the `admin_stats` SQL function.
///
/// These must be aggregated in the database: the orders grid only pages in the
/// most recent rows, so folding over that list would silently under-report
/// revenue as soon as the store passed one page of orders.
class AdminStats {
  const AdminStats({
    required this.grossRevenue,
    required this.totalOrders,
    required this.pendingOrders,
    required this.revenueOrders,
    required this.revenueByCategory,
  });

  final double grossRevenue;
  final int totalOrders;
  final int pendingOrders;

  /// Orders that contribute to [grossRevenue] (i.e. not cancelled or refunded).
  final int revenueOrders;
  final Map<String, double> revenueByCategory;

  double get averageOrderValue =>
      revenueOrders == 0 ? 0 : grossRevenue / revenueOrders;

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    final rawByCat = json['revenue_by_category'];
    final byCat = <String, double>{};
    if (rawByCat is Map) {
      rawByCat.forEach((k, v) => byCat[k.toString()] = J.toDouble(v));
    }
    return AdminStats(
      grossRevenue: J.toDouble(json['gross_revenue']),
      totalOrders: J.toInt(json['total_orders']),
      pendingOrders: J.toInt(json['pending_orders']),
      revenueOrders: J.toInt(json['revenue_orders']),
      revenueByCategory: byCat,
    );
  }

  /// Fold the same figures out of an in-memory order list (demo mode).
  factory AdminStats.fromOrders(List<Order> orders) {
    bool earns(Order o) =>
        o.status != OrderStatus.cancelled && o.status != OrderStatus.refunded;

    final byCat = <String, double>{};
    for (final o in orders.where(earns)) {
      for (final line in o.lines) {
        final cat = line.category ?? 'Other';
        byCat[cat] = (byCat[cat] ?? 0) + line.lineTotal;
      }
    }
    return AdminStats(
      grossRevenue: orders.where(earns).fold(0.0, (s, o) => s + o.grandTotal),
      totalOrders: orders.length,
      pendingOrders: orders
          .where((o) =>
              o.status == OrderStatus.pending || o.status == OrderStatus.paid)
          .length,
      revenueOrders: orders.where(earns).length,
      revenueByCategory: byCat,
    );
  }
}

/// Back-office controller: dashboard analytics and CMS logic for catalog,
/// promotions, and orders (PRD §3.2). Works against Supabase when configured,
/// otherwise mutates in-memory demo collections so the panels stay interactive.
///
/// Every mutating method returns a `bool` and records a human-readable message
/// in [error] on failure, so the UI can tell the operator that a save did not
/// land instead of optimistically closing the dialog.
class AdminController extends GetxController {
  final RxList<Product> products = <Product>[].obs;
  final RxList<Promotion> promotions = <Promotion>[].obs;

  /// The most recent orders, for the fulfillment grid. Deliberately capped —
  /// dashboard figures come from [stats], not from folding over this list.
  final RxList<Order> orders = <Order>[].obs;
  static const int _ordersPageSize = 100;

  final Rxn<AdminStats> stats = Rxn<AdminStats>();

  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  Future<void> refreshAll() async {
    isLoading.value = true;
    error.value = '';
    try {
      await Future.wait([_loadProducts(), _loadPromotions(), _loadOrders()]);
      await _loadStats();
    } catch (e) {
      error.value = 'Failed to load admin data: ${_message(e)}';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadProducts() async {
    if (SupabaseService.isReady) {
      final rows = await SupabaseService.client
          .from(AppConstants.tblProducts)
          .select(AppConstants.productTree)
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
          .limit(_ordersPageSize);
      orders.assignAll((rows as List)
          .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList());
    } else {
      orders.assignAll(DemoData.orders());
    }
  }

  Future<void> _loadStats() async {
    if (SupabaseService.isReady) {
      final res = await SupabaseService.client.rpc(AppConstants.rpcAdminStats);
      stats.value = AdminStats.fromJson(Map<String, dynamic>.from(res as Map));
    } else {
      stats.value = AdminStats.fromOrders(orders);
    }
  }

  // ---------------------------------------------------------------------------
  // Dashboard analytics
  // ---------------------------------------------------------------------------
  int get totalProducts => products.length;
  int get activeProducts => products.where((p) => p.isActive).length;
  int get totalSkus => products.fold(0, (sum, p) => sum + p.allItems.length);
  int get activePromotions => promotions.where((p) => p.isLive).length;

  double get grossRevenue => stats.value?.grossRevenue ?? 0;
  int get totalOrders => stats.value?.totalOrders ?? orders.length;
  int get pendingOrders => stats.value?.pendingOrders ?? 0;
  double get averageOrderValue => stats.value?.averageOrderValue ?? 0;
  Map<String, double> get revenueByCategory =>
      stats.value?.revenueByCategory ?? const {};

  List<LowStockEntry> get lowStock {
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
    return entries;
  }

  List<Order> get recentOrders => orders.take(8).toList();

  // ---------------------------------------------------------------------------
  // Catalog CMS
  // ---------------------------------------------------------------------------

  /// Persists a product together with its colour groups and size variants, in
  /// one transaction. Returns false and sets [error] if the save failed.
  Future<bool> saveProduct(Product product) async {
    isSaving.value = true;
    error.value = '';
    try {
      if (SupabaseService.isReady) {
        await SupabaseService.client.rpc(
          AppConstants.rpcSaveProduct,
          params: {'p_product': product.toRpcJson()},
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
      return true;
    } catch (e) {
      error.value = 'Could not save “${product.title}”: ${_message(e)}';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> toggleProductActive(Product product) =>
      saveProduct(product.copyWith(isActive: !product.isActive));

  Future<bool> deleteProduct(String id) async {
    error.value = '';
    try {
      if (SupabaseService.isReady) {
        await SupabaseService.client
            .from(AppConstants.tblProducts)
            .delete()
            .eq('id', id);
      }
      products.removeWhere((p) => p.id == id);
      return true;
    } catch (e) {
      error.value = 'Could not delete that product: ${_message(e)}';
      return false;
    }
  }

  /// Bulk-generate size variants for a colour group (PRD §3.2 "generate
  /// grandchild variants … with unique SKUs … in bulk"). [skuPrefix] is combined
  /// with each size to form the SKU, e.g. `CASH-TURT-BLU` + `M` → `CASH-TURT-BLU-M`.
  ///
  /// [existing] items are preserved; a generated SKU that collides with one of
  /// them is skipped rather than duplicated, so running the generator twice is
  /// additive instead of destructive.
  List<VariantItem> generateVariants({
    required String groupId,
    required String skuPrefix,
    required List<String> sizes,
    required int stockPerSize,
    double? priceOverride,
    List<VariantItem> existing = const [],
  }) {
    final result = [...existing];
    final seenSkus = existing.map((e) => e.sku.toUpperCase()).toSet();
    var nextOrder = existing.isEmpty
        ? 0
        : existing.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

    for (final raw in sizes) {
      final size = raw.trim();
      if (size.isEmpty) continue;
      final sku = '$skuPrefix-${size.toUpperCase()}';
      if (!seenSkus.add(sku.toUpperCase())) continue;
      result.add(VariantItem(
        id: Uuid.v4(),
        groupId: groupId,
        sku: sku,
        sizeLabel: size,
        stockQuantity: stockPerSize,
        priceOverride: priceOverride,
        sortOrder: nextOrder++,
      ));
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Promotions CMS
  // ---------------------------------------------------------------------------
  Future<bool> savePromotion(Promotion promo) async {
    isSaving.value = true;
    error.value = '';
    try {
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
      return true;
    } catch (e) {
      error.value = 'Could not save code ${promo.code}: ${_message(e)}';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deletePromotion(String id) async {
    error.value = '';
    try {
      if (SupabaseService.isReady) {
        await SupabaseService.client
            .from(AppConstants.tblPromotions)
            .delete()
            .eq('id', id);
      }
      promotions.removeWhere((p) => p.id == id);
      return true;
    } catch (e) {
      error.value = 'Could not delete that promotion: ${_message(e)}';
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Orders / fulfillment
  // ---------------------------------------------------------------------------

  /// Statuses that take an order out of circulation and should return its
  /// reserved stock to the shelf.
  static const Set<OrderStatus> _restockingStatuses = {
    OrderStatus.cancelled,
    OrderStatus.refunded,
  };

  Future<bool> updateOrderStatus(Order order, OrderStatus status) async {
    if (status == order.status) return true;
    error.value = '';

    // Only restock on the transition *into* a cancelled/refunded state; going
    // cancelled → refunded must not credit the stock twice. `restock_order` is
    // additionally idempotent server-side via orders.restocked_at.
    final shouldRestock = _restockingStatuses.contains(status) &&
        !_restockingStatuses.contains(order.status);

    try {
      if (SupabaseService.isReady) {
        await SupabaseService.client
            .from(AppConstants.tblOrders)
            .update({'status': status.name}).eq('id', order.id);
        if (shouldRestock) {
          await SupabaseService.client.rpc(
            AppConstants.rpcRestockOrder,
            params: {'p_order_id': order.id},
          );
          await _loadProducts(); // stock changed
        }
        await _loadOrders();
        await _loadStats();
      } else {
        final idx = orders.indexWhere((o) => o.id == order.id);
        if (idx >= 0) {
          orders[idx] = order.copyWith(status: status);
          orders.refresh();
        }
        if (shouldRestock) _restockLocally(order);
        stats.value = AdminStats.fromOrders(orders);
      }
      return true;
    } catch (e) {
      error.value = 'Could not update ${order.reference}: ${_message(e)}';
      return false;
    }
  }

  /// Demo-mode mirror of `restock_order`, so cancelling an order visibly
  /// restores stock in the catalog and low-stock panels.
  void _restockLocally(Order order) {
    final bySku = {for (final l in order.lines) l.sku: l.quantity};
    if (bySku.isEmpty) return;

    for (var pi = 0; pi < products.length; pi++) {
      final p = products[pi];
      var touched = false;
      final groups = p.groups.map((g) {
        final items = g.items.map((i) {
          final qty = bySku[i.sku];
          if (qty == null) return i;
          touched = true;
          return i.copyWith(stockQuantity: i.stockQuantity + qty);
        }).toList();
        return g.copyWith(items: items);
      }).toList();
      if (touched) products[pi] = p.copyWith(groups: groups);
    }
    products.refresh();
  }

  /// Trims Postgres' error envelope down to the message an operator can act on.
  String _message(Object error) {
    final text = error.toString();
    final match = RegExp(r'message: ([^,}]+)').firstMatch(text);
    return match?.group(1)?.trim() ?? text;
  }
}
