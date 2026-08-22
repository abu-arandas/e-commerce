# Graph Report - e-commerce  (2026-08-22)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1270 nodes · 1773 edges · 89 communities (68 shown, 21 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `a8e0f783`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 4
- Community 5
- Community 6
- Community 7
- Community 8
- Community 9
- Community 10
- Community 11
- Community 12
- Community 13
- Community 14
- Community 15
- Community 16
- Community 17
- Community 18
- Community 19
- Community 20
- Community 21
- Community 22
- Community 23
- Community 24
- Community 25
- Community 26
- Community 27
- Community 28
- Community 29
- Community 30
- Community 31
- Community 32
- Community 33
- Community 34
- Community 35
- Community 36
- Community 37
- Community 38
- Community 39
- Community 40
- Community 41
- Community 42
- Community 43
- Community 44
- Community 45
- Community 46
- Community 47
- Community 48
- Community 49
- Community 50
- Community 51
- Community 52
- Community 53
- Community 54
- Community 55
- Community 56
- Community 57
- Community 58
- Community 59
- Community 60
- Community 61
- Community 62
- Community 63
- Community 64
- Community 65
- Community 66
- Community 67
- Community 68
- Community 69
- Community 71
- Community 72
- Community 73
- Community 74
- Community 75
- Community 76
- Community 77
- Community 78
- Community 79
- Community 80
- Community 81
- Community 84
- Community 85
- Community 86
- Community 87
- Community 88

## God Nodes (most connected - your core abstractions)
1. `_` - 25 edges
2. `_` - 16 edges
3. `AuthController` - 12 edges
4. `CartController` - 11 edges
5. `CatalogController` - 11 edges
6. `WishlistController` - 9 edges
7. `AdminController` - 8 edges
8. `Product` - 7 edges
9. `public.profiles` - 6 edges
10. `OrdersController` - 6 edges

## Surprising Connections (you probably didn't know these)
- `_PromoCard` --inherits--> `StatelessWidget`  [EXTRACTED]
  lib/views/admin/promotion_builder_view.dart → None  _Bridges community 10 → community 37_
- `PromotionEditorDialog` --inherits--> `StatefulWidget`  [EXTRACTED]
  lib/views/admin/promotion_builder_view.dart → None  _Bridges community 10 → community 27_
- `AdminOrdersView` --inherits--> `StatelessWidget`  [EXTRACTED]
  lib/views/admin/admin_orders_view.dart → None  _Bridges community 84 → community 37_
- `OrderConfirmationView` --inherits--> `StatelessWidget`  [EXTRACTED]
  lib/views/storefront/order_confirmation_view.dart → None  _Bridges community 13 → community 37_
- `AdminController` --inherits--> `GetxController`  [EXTRACTED]
  lib/controllers/admin_controller.dart → None  _Bridges community 87 → community 9_

## Import Cycles
- None detected.

## Communities (89 total, 21 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.04
Nodes (44): app_routes.dart, GetMiddleware, AppPages, redirect, routes, _StaffGuard, AppShadows, AppSpacing (+36 more)

### Community 1 - "Community 1"
Cohesion: 0.04
Nodes (45): activeProducts, activePromotions, _cachedRevenueByCategory, _cachedTotalSkus, colorName, deleteProduct, deletePromotion, _demoOrders (+37 more)

### Community 2 - "Community 2"
Cohesion: 0.05
Nodes (43): AlignmentGeometry, BuildContext, EdgeInsetsGeometry, Fb5Breakpoint get, alignment, atLeast, _bpFromToken, breakpoint (+35 more)

### Community 3 - "Community 3"
Cohesion: 0.06
Nodes (38): dart:js_interop, external _Document get, external _Element? get, external _History get, external _Location get, external _Storage get, external String get, _ (+30 more)

### Community 4 - "Community 4"
Cohesion: 0.06
Nodes (35): int?, category, code, db, description, discountAmount, discountValue, eligibleSubtotal (+27 more)

### Community 5 - "Community 5"
Cohesion: 0.06
Nodes (33): BoxFit, action, align, aspectRatio, _btn, build, compact, disabled (+25 more)

### Community 6 - "Community 6"
Cohesion: 0.06
Nodes (33): add, appliedCode, appliedPromo, applyPromo, categories, clear, clearPromo, decrement (+25 more)

### Community 7 - "Community 7"
Cohesion: 0.06
Nodes (33): _addGroup, admin, build, _BulkResult, _category, _confirmDelete, createState, _description (+25 more)

### Community 8 - "Community 8"
Cohesion: 0.06
Nodes (32): ../core/utils/browser/browser.dart, activeImage, _applyGroup, availableCategories, availableSizes, _cachedCategories, canAddToCart, categoryFilter (+24 more)

### Community 9 - "Community 9"
Cohesion: 0.08
Nodes (31): Bindings, cart_view.dart, ../../controllers/admin_controller.dart, ../../controllers/auth_controller.dart, ../../controllers/cart_controller.dart, ../../controllers/catalog_controller.dart, ../../controllers/orders_controller.dart, GetxController (+23 more)

### Community 10 - "Community 10"
Cohesion: 0.06
Nodes (31): ../../core/utils/uuid.dart, DiscountType, Promotion, _active, admin, build, _code, createState (+23 more)

### Community 11 - "Community 11"
Cohesion: 0.06
Nodes (30): category, contactEmail, createdAt, discountTotal, fromDb, fromJson, grandTotal, id (+22 more)

### Community 12 - "Community 12"
Cohesion: 0.11
Nodes (21): on_auth_user_created, public.addresses, public.current_app_role(), public.order_items, public.orders, public.place_order(), public.products, public.profiles (+13 more)

### Community 13 - "Community 13"
Cohesion: 0.14
Nodes (14): core/routes/app_routes.dart, OrderStatus, build, OrderConfirmationView, orderProgressStep, _OrderProgressTracker, status, _totalRow (+6 more)

### Community 14 - "Community 14"
Cohesion: 0.07
Nodes (26): @visibleForTesting, app_constants.dart, env.dart, json_parse.dart, flatShippingFee, freeShippingThreshold, load, StoreSettings (+18 more)

### Community 15 - "Community 15"
Cohesion: 0.07
Nodes (26): customer,
  catalogManager,
  marketingManager,
  fulfillment,, Address, admin, AppRole, canManageCatalog, canManageOrders, canManagePromotions, city (+18 more)

### Community 16 - "Community 16"
Cohesion: 0.08
Nodes (25): DateTime?, double get, int get, Iterable, allItems, basePrice, category, copyWith (+17 more)

### Community 17 - "Community 17"
Cohesion: 0.08
Nodes (25): double?, colorHex, copyWith, effectivePrice, fromJson, groupId, groupImages, hasStock (+17 more)

### Community 18 - "Community 18"
Cohesion: 0.08
Nodes (25): AppColors, charcoal, danger, gold, goldDeep, goldSoft, info, ink (+17 more)

### Community 19 - "Community 19"
Cohesion: 0.08
Nodes (24): AppRole get, _bindAuthState, error, isLoading, isLoggedIn, isStaff, _loadProfile, _lockoutDuration (+16 more)

### Community 20 - "Community 20"
Cohesion: 0.08
Nodes (24): ../core/utils/json_parse.dart, category, colorName, from, fromJson, imageUrl, key, lineTotal (+16 more)

### Community 21 - "Community 21"
Cohesion: 0.10
Nodes (21): package:flutter_test/flutter_test.dart, package:vanguard_fashion/controllers/admin_controller.dart, package:vanguard_fashion/core/utils/formatters.dart, package:vanguard_fashion/core/utils/json_parse.dart, package:vanguard_fashion/core/utils/uuid.dart, package:vanguard_fashion/models/order_model.dart, package:vanguard_fashion/models/product_model.dart, package:vanguard_fashion/models/user_model.dart (+13 more)

### Community 22 - "Community 22"
Cohesion: 0.08
Nodes (24): all, AppConstants, appName, Categories, freeReturnsDays, lowStockThreshold, rpcAdminStats, rpcPlaceOrder (+16 more)

### Community 23 - "Community 23"
Cohesion: 0.18
Nodes (10): dart:async, MockSupabaseClient, package:mocktail/mocktail.dart, package:vanguard_fashion/core/utils/supabase_service.dart, authController, main, mockAuthClient, mockFilterBuilder (+2 more)

### Community 24 - "Community 24"
Cohesion: 0.20
Nodes (9): Product, package:vanguard_fashion/core/utils/env.dart, package:vanguard_fashion/core/utils/store_settings.dart, addFirstInStock, cart, knitwear, main, settle (+1 more)

### Community 25 - "Community 25"
Cohesion: 0.10
Nodes (20): CatalogController, package:vanguard_fashion/controllers/auth_controller.dart, package:vanguard_fashion/controllers/catalog_controller.dart, package:vanguard_fashion/controllers/wishlist_controller.dart, package:vanguard_fashion/core/utils/demo_data.dart, package:vanguard_fashion/models/promotion_model.dart, package:vanguard_fashion/views/shared/variant_selector.dart, catalog (+12 more)

### Community 26 - "Community 26"
Cohesion: 0.11
Nodes (17): ../../core/utils/seo/seo_service.dart, _AnnouncementBar, build, _CategoryStrip, _cats, _EditorialBand, _Hero, HomeView (+9 more)

### Community 27 - "Community 27"
Cohesion: 0.14
Nodes (20): _BulkVariantDialog, _BulkVariantDialogState, _ColorGroupDialog, _ColorGroupDialogState, ProductCard, _ProductCardState, _OrderHistoryList, _OrderHistoryListState (+12 more)

### Community 28 - "Community 28"
Cohesion: 0.11
Nodes (18): auth_controller.dart, bool get, catalog_controller.dart, ../core/utils/demo_data.dart, count, fetchWishlist, isEmpty, isLoading (+10 more)

### Community 29 - "Community 29"
Cohesion: 0.11
Nodes (18): IconData, _AccessDenied, actions, active, _adminNav, AdminNavItem, AdminScaffold, auth (+10 more)

### Community 30 - "Community 30"
Cohesion: 0.17
Nodes (16): on_auth_user_created, public.addresses, public.order_items, public.orders, public.products, public.profiles, public.promotions, public.variant_groups (+8 more)

### Community 31 - "Community 31"
Cohesion: 0.11
Nodes (17): build, cart, _CartButton, _go, _goShop, _height, label, _NavLink (+9 more)

### Community 32 - "Community 32"
Cohesion: 0.13
Nodes (14): VariantGroup, Object?, R, asStream, catchError, controller, main, _shouldThrow (+6 more)

### Community 33 - "Community 33"
Cohesion: 0.12
Nodes (15): ../../core/utils/env.dart, CartItem, build, cart, _CartLine, CartView, createState, dispose (+7 more)

### Community 34 - "Community 34"
Cohesion: 0.12
Nodes (15): account, adminDashboard, adminOrders, adminProducts, adminPromotions, AppRoutes, cart, checkout (+7 more)

### Community 35 - "Community 35"
Cohesion: 0.12
Nodes (15): _Accordion, _addToCart, _AssuranceRow, _Breadcrumb, build, catalog, createState, description (+7 more)

### Community 36 - "Community 36"
Cohesion: 0.13
Nodes (14): Color get, admin, AdminDashboardView, build, child, _color, _kpi, _LowStock (+6 more)

### Community 37 - "Community 37"
Cohesion: 0.13
Nodes (15): Fb5BreakpointBuilder, FB5Col, FB5Container, FB5Row, _HeaderRow, ProductManagerView, _ProductRow, EmptyState (+7 more)

### Community 38 - "Community 38"
Cohesion: 0.13
Nodes (15): ../../controllers/wishlist_controller.dart, ../../core/theme/app_colors.dart, ../../core/utils/formatters.dart, build, createState, _hover, product, _swatches (+7 more)

### Community 39 - "Community 39"
Cohesion: 0.14
Nodes (13): FormState, auth, build, createState, _demoChip, dispose, _email, _formKey (+5 more)

### Community 40 - "Community 40"
Cohesion: 0.15
Nodes (12): core/bindings/initial_binding.dart, core/routes/app_pages.dart, core/theme/app_theme.dart, core/utils/app_constants.dart, core/utils/store_settings.dart, core/utils/supabase_service.dart, core/utils/url_strategy/url_strategy.dart, build (+4 more)

### Community 41 - "Community 41"
Cohesion: 0.15
Nodes (12): ../../core/theme/app_typography.dart, VariantItem, build, controller, item, onTap, selected, _showSizeGuide (+4 more)

### Community 42 - "Community 42"
Cohesion: 0.17
Nodes (10): app_colors.dart, app_spacing.dart, app_typography.dart, AppTheme, AppTypography, eyebrow, scaleFor, textTheme (+2 more)

### Community 43 - "Community 43"
Cohesion: 0.22
Nodes (8): ../../core/utils/bootstrap5.dart, build, count, ProductGrid, ProductGridSkeleton, products, List, product_card.dart

### Community 44 - "Community 44"
Cohesion: 0.17
Nodes (11): _compact, _date, _dateTime, Formatters, price, priceTrim, stockLabel, _usd (+3 more)

### Community 45 - "Community 45"
Cohesion: 0.17
Nodes (8): public.current_app_role(), public.validate_promotion(), public.variant_unit_price(), public.products, public.profiles, public.promotions, public.variant_groups, public.variant_items

### Community 46 - "Community 46"
Cohesion: 0.18
Nodes (10): custom_app_bar.dart, AppFooter, build, child, _links, scrollable, showFooter, _StickyCartBar (+2 more)

### Community 47 - "Community 47"
Cohesion: 0.18
Nodes (10): clear, error, fetch, isLoading, orders, record, _sessionOrders, RxBool (+2 more)

### Community 48 - "Community 48"
Cohesion: 0.18
Nodes (10): DemoData, _img, products, promotions, _round2, validatePromo, ../models/product_model.dart, ../models/promotion_model.dart (+2 more)

### Community 49 - "Community 49"
Cohesion: 0.18
Nodes (10): date, dateOrNull, J, str, strList, strOrNull, toBool, toDouble (+2 more)

### Community 50 - "Community 50"
Cohesion: 0.22
Nodes (8): dart:convert, package:get/get.dart, package:vanguard_fashion/controllers/cart_controller.dart, package:vanguard_fashion/models/cart_item_model.dart, main, cart, lineFor, main

### Community 51 - "Community 51"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 52 - "Community 52"
Cohesion: 0.20
Nodes (9): Env, flatShippingFee, freeShippingThreshold, hasSupabase, supabaseAnonKey, supabaseUrl, static bool get, static const String (+1 more)

### Community 53 - "Community 53"
Cohesion: 0.22
Nodes (8): dart:math, isValid, _pattern, _rng, Uuid, v4, static final Random, static final RegExp

### Community 54 - "Community 54"
Cohesion: 0.25
Nodes (4): public.place_order(), public.store_settings, public.set_updated_at, trg_store_settings_updated

### Community 55 - "Community 55"
Cohesion: 0.29
Nodes (6): browser_stub.dart, Browser, read, remove, replaceUrl, write

### Community 56 - "Community 56"
Cohesion: 0.33
Nodes (5): pg_namespace, pg_proc, assert_eq(), public.order_items, public.variant_items

### Community 57 - "Community 57"
Cohesion: 0.40
Nodes (4): readLocal, removeLocal, replaceUrl, writeLocal

### Community 58 - "Community 58"
Cohesion: 0.40
Nodes (4): package:vanguard_fashion/core/utils/bootstrap5.dart, main, surface, widthsAt

### Community 59 - "Community 59"
Cohesion: 0.40
Nodes (3): corsHeaders, PromoLine, PromoRequest

### Community 60 - "Community 60"
Cohesion: 0.50
Nodes (3): SeoService, update, seo_stub.dart

### Community 84 - "Community 84"
Cohesion: 0.20
Nodes (9): admin_scaffold.dart, ../../core/theme/app_spacing.dart, Order, admin, AdminOrdersView, build, order, _OrderTile (+1 more)

### Community 85 - "Community 85"
Cohesion: 0.22
Nodes (10): GoTrueClient, Mock, PostgrestTransformBuilder, SupabaseClient, SupabaseQueryBuilder, MockGoTrueClient, MockPostgrestTransformBuilder, MockSupabaseClient (+2 more)

### Community 86 - "Community 86"
Cohesion: 0.50
Nodes (4): Fake, PostgrestFilterBuilder, MockPostgrestFilterBuilder, FakePostgrestFilterBuilder

### Community 87 - "Community 87"
Cohesion: 0.50
Nodes (3): AdminController, admin, main

## Knowledge Gaps
- **783 isolated node(s):** `PromoLine`, `PromoRequest`, `AppPages`, `redirect`, `routes` (+778 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **21 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AuthController` connect `Community 9` to `Community 0`, `Community 38`, `Community 39`, `Community 19`, `Community 23`, `Community 25`, `Community 28`, `Community 29`, `Community 31`?**
  _High betweenness centrality (0.028) - this node is a cross-community bridge._
- **Why does `CartController` connect `Community 9` to `Community 32`, `Community 33`, `Community 35`, `Community 6`, `Community 46`, `Community 50`, `Community 24`, `Community 31`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **What connects `PromoLine`, `PromoRequest`, `AppPages` to the rest of the system?**
  _783 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.043478260869565216 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.043478260869565216 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.045454545454545456 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.05547652916073969 - nodes in this community are weakly interconnected._