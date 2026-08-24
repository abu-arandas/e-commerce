import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/models/promotion_model.dart';
import 'package:vanguard_fashion/models/user_model.dart';

/// Two pieces of gating logic that had no tests. AppRole decides who reaches the
/// back office (_StaffGuard and AdminScaffold both read isStaff); Promotion.isLive
/// decides whether a discount applies. Both are consulted before money or access
/// changes hands, and both mirror rules the database enforces independently.
void main() {
  group('roles', () {
    test('only the customer role is not staff', () {
      expect(AppRole.customer.isStaff, isFalse);
      for (final r in AppRole.values.where((r) => r != AppRole.customer)) {
        expect(r.isStaff, isTrue, reason: '$r should reach the back office');
      }
    });

    test('each manager role is scoped to its own area', () {
      expect(AppRole.catalogManager.canManageCatalog, isTrue);
      expect(AppRole.catalogManager.canManagePromotions, isFalse);
      expect(AppRole.catalogManager.canManageOrders, isFalse);

      expect(AppRole.marketingManager.canManagePromotions, isTrue);
      expect(AppRole.marketingManager.canManageCatalog, isFalse);

      expect(AppRole.fulfillment.canManageOrders, isTrue);
      expect(AppRole.fulfillment.canManageCatalog, isFalse);
    });

    test('admin can do everything; a customer can do nothing', () {
      expect(AppRole.admin.canManageCatalog, isTrue);
      expect(AppRole.admin.canManagePromotions, isTrue);
      expect(AppRole.admin.canManageOrders, isTrue);

      expect(AppRole.customer.canManageCatalog, isFalse);
      expect(AppRole.customer.canManagePromotions, isFalse);
      expect(AppRole.customer.canManageOrders, isFalse);
    });

    test('an unknown database role falls back to customer, never to staff', () {
      // A typo or a role added server-side must not accidentally grant access.
      for (final v in ['', 'root', 'superuser', 'ADMIN', null]) {
        expect(AppRole.fromDb(v).isStaff, isFalse, reason: 'role $v');
      }
      expect(AppRole.fromDb('admin').isStaff, isTrue);
    });

    test('roles round-trip through their database spelling', () {
      for (final r in AppRole.values) {
        expect(AppRole.fromDb(r.db), r);
      }
    });
  });

  group('promotion liveness', () {
    Promotion promo({
      bool isActive = true,
      DateTime? from,
      DateTime? until,
      int? limit,
      int used = 0,
    }) => Promotion(
      id: 'p',
      code: 'CODE',
      discountType: DiscountType.percentage,
      discountValue: 10,
      isActive: isActive,
      validFrom: from,
      validUntil: until,
      usageLimit: limit,
      usageCount: used,
    );

    final past = DateTime.now().subtract(const Duration(days: 2));
    final future = DateTime.now().add(const Duration(days: 2));

    test('a promotion inside its window with uses left is live', () {
      expect(promo(from: past, until: future).isLive, isTrue);
    });

    test('each disqualifier alone is enough to kill it', () {
      expect(promo(isActive: false).isLive, isFalse, reason: 'deactivated');
      expect(promo(until: past).isLive, isFalse, reason: 'expired');
      expect(promo(from: future).isLive, isFalse, reason: 'not started');
      expect(promo(limit: 5, used: 5).isLive, isFalse, reason: 'limit reached');
    });

    test('usage is exhausted at the limit, not past it', () {
      expect(promo(limit: 5, used: 4).usageExhausted, isFalse);
      expect(promo(limit: 5, used: 5).usageExhausted, isTrue);
      expect(promo(limit: 5, used: 6).usageExhausted, isTrue);
    });

    test('no limit means it never exhausts', () {
      expect(promo(used: 999999).usageExhausted, isFalse);
    });

    test('an open-ended window never expires', () {
      expect(promo(from: past).isExpired, isFalse);
      expect(promo(from: past).isLive, isTrue);
    });

    test('the value label reads correctly per discount type', () {
      expect(
        const Promotion(
          id: 'a',
          code: 'C',
          discountType: DiscountType.percentage,
          discountValue: 25,
        ).valueLabel,
        '25% off',
      );
      expect(
        const Promotion(
          id: 'b',
          code: 'C',
          discountType: DiscountType.fixedAmount,
          discountValue: 15,
        ).valueLabel,
        '\$15 off',
      );
      expect(
        const Promotion(
          id: 'c',
          code: 'C',
          discountType: DiscountType.freeShipping,
          discountValue: 0,
        ).valueLabel,
        'Free shipping',
      );
    });
  });

  group('user display', () {
    AppUser user({
      String? fullName,
      String email = 'ada.lovelace@example.com',
    }) => AppUser(id: 'u', email: email, fullName: fullName);

    test('a full name wins over the email handle', () {
      expect(user(fullName: 'Ada Lovelace').displayName, 'Ada Lovelace');
    });

    test('a blank name falls back to the email handle', () {
      expect(user(fullName: '   ').displayName, 'ada.lovelace');
      expect(user().displayName, 'ada.lovelace');
    });

    test('initials take first and last for a full name', () {
      expect(user(fullName: 'Ada Lovelace').initials, 'AL');
      expect(user(fullName: 'Grace Brewster Hopper').initials, 'GH');
    });

    test('a single name yields one initial', () {
      expect(user(fullName: 'Ada').initials, 'A');
    });

    test('an empty email cannot crash the avatar', () {
      // displayName must never be empty, or initials would index past the end.
      const u = AppUser(id: 'u', email: '');
      expect(u.displayName, 'Guest');
      expect(u.initials, isNotEmpty);
    });

    test('copyWith preserves identity and changes only what is given', () {
      final u = user(fullName: 'Ada Lovelace');
      final promoted = u.copyWith(role: AppRole.admin);

      expect(promoted.id, u.id);
      expect(promoted.email, u.email);
      expect(promoted.fullName, 'Ada Lovelace');
      expect(promoted.role, AppRole.admin);
      expect(u.role, AppRole.customer, reason: 'the original is untouched');
    });
  });
}
