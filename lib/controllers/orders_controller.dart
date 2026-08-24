import 'package:get/get.dart';

import '../core/utils/app_constants.dart';
import '../core/utils/supabase_service.dart';
import '../models/order_model.dart';

/// The signed-in shopper's own order history (PRD §3.1 "Account").
///
/// Live mode reads `orders` scoped by RLS to the caller; demo mode accumulates
/// orders placed during the session so the confirmation page's "View orders"
/// link leads somewhere real either way.
class OrdersController extends GetxController {
  final RxList<Order> orders = <Order>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  /// Orders placed in this session; the only source of history in demo mode,
  /// and an optimistic prefix while a live fetch is in flight.
  final List<Order> _sessionOrders = [];

  Future<void> fetch() async {
    if (!SupabaseService.isReady) {
      orders.assignAll(_sessionOrders.reversed);
      return;
    }
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) {
      // Guest checkout: the order exists but is not linked to an account.
      orders.assignAll(_sessionOrders.reversed);
      return;
    }

    isLoading.value = true;
    error.value = '';
    try {
      final rows = await SupabaseService.client
          .from(AppConstants.tblOrders)
          .select('*, order_items(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      orders.assignAll(
        (rows as List)
            .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
    } catch (e) {
      error.value = 'Could not load your orders right now.';
      orders.assignAll(_sessionOrders.reversed);
    } finally {
      isLoading.value = false;
    }
  }

  /// Record a freshly placed order so it shows up immediately, without waiting
  /// for a round-trip.
  void record(Order order) {
    _sessionOrders.add(order);
    orders.insert(0, order);
  }

  /// Drop everything on sign-out so one account's history never bleeds into
  /// the next session.
  void clear() {
    _sessionOrders.clear();
    orders.clear();
    error.value = '';
  }
}
