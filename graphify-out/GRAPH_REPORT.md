# Graph Report - e-commerce  (2026-08-22)

## Corpus Check
- 98 files · ~55,721 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1316 nodes · 1824 edges · 87 communities (66 shown, 21 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e92eaa5d`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Routing & Access Guards
- Admin Controller
- bootstrap5.dart
- Browser JS Interop
- Promotion Model
- ui_kit.dart
- Cart Controller
- product_manager_view.dart
- Catalog Controller
- checkout_view.dart
- Promotion Builder View
- Order Model
- Database Schema
- _BulkVariantDialog
- App Config & Settings
- user_model.dart
- product_model.dart
- Variant Model
- App Color Theme
- auth_controller.dart
- cart_item_model.dart
- package:flutter_test/flutter_test.dart
- App Constants & RPC Names
- Auth Controller Tests
- cart_test.dart
- wishlist_test.dart
- home_view.dart
- State
- wishlist_controller.dart
- Admin Scaffold Navigation
- Initial DB Schema Migration
- Custom App Bar
- Cart Controller Test Fakes
- cart_view.dart
- App Routes Constants
- Product Detail View
- StatelessWidget
- Dev Notes & Learnings
- account_view.dart
- OrdersController
- storefront_scaffold.dart
- variant_selector.dart
- App Theme
- package:get/get.dart
- Formatters Utility
- DB Functions Migration
- orders_controller.dart
- Demo Data
- JSON Parsing Utility
- Model & Utility Tests
- PWA Manifest
- Environment Config
- UUID Utility
- DB Hardening Migration
- Browser Storage Abstraction
- assert_eq
- Browser Storage Stub
- responsive_grid_test.dart
- Promo Edge Function
- SEO Service
- DB Integrity Migration
- URL Strategy
- Web URL Strategy
- Auth Schema Shim
- SEO Stub
- URL Strategy Stub
- Addresses Table
- Wishlists Table
- Order Items Table
- Orders Table
- Products Table
- Profiles Table
- Promotions Table
- Variant Groups Table
- Variant Items Table
- Order Items Table
- Orders Table
- Orders Table
- Promotions Table
- ../../core/theme/app_colors.dart
- Project README
- CLAUDE.md
- package:flutter/material.dart
- 20_contract.sh

## God Nodes (most connected - your core abstractions)
1. `_` - 25 edges
2. `_` - 16 edges
3. `AuthController` - 12 edges
4. `CartController` - 11 edges
5. `CatalogController` - 11 edges
6. `WishlistController` - 9 edges
7. `AdminController` - 8 edges
8. `OrdersController` - 7 edges
9. `Product` - 7 edges
10. `Vanguard Fashion` - 7 edges

## Surprising Connections (you probably didn't know these)
- `AdminController` --inherits--> `GetxController`  [EXTRACTED]
  lib/controllers/admin_controller.dart → None  _Bridges community 21 → community 38_
- `CartController` --inherits--> `GetxController`  [EXTRACTED]
  lib/controllers/cart_controller.dart → None  _Bridges community 38 → community 24_
- `CatalogController` --inherits--> `GetxController`  [EXTRACTED]
  lib/controllers/catalog_controller.dart → None  _Bridges community 38 → community 25_
- `OrdersController` --inherits--> `GetxController`  [EXTRACTED]
  lib/controllers/orders_controller.dart → None  _Bridges community 38 → community 39_
- `Fb5BreakpointBuilder` --inherits--> `StatelessWidget`  [EXTRACTED]
  lib/core/utils/bootstrap5.dart → None  _Bridges community 36 → community 2_

## Import Cycles
- None detected.

## Communities (87 total, 21 thin omitted)

### Community 0 - "Routing & Access Guards"
Cohesion: 0.04
Nodes (44): app_routes.dart, GetMiddleware, AppPages, redirect, routes, _StaffGuard, AppShadows, AppSpacing (+36 more)

### Community 1 - "Admin Controller"
Cohesion: 0.04
Nodes (45): activeProducts, activePromotions, _cachedRevenueByCategory, _cachedTotalSkus, colorName, deleteProduct, deletePromotion, _demoOrders (+37 more)

### Community 2 - "bootstrap5.dart"
Cohesion: 0.04
Nodes (46): AlignmentGeometry, BuildContext, EdgeInsetsGeometry, Fb5Breakpoint get, alignment, atLeast, _bpFromToken, breakpoint (+38 more)

### Community 3 - "Browser JS Interop"
Cohesion: 0.06
Nodes (38): dart:js_interop, external _Document get, external _Element? get, external _History get, external _Location get, external _Storage get, external String get, _ (+30 more)

### Community 4 - "Promotion Model"
Cohesion: 0.06
Nodes (35): int?, category, code, db, description, discountAmount, discountValue, eligibleSubtotal (+27 more)

### Community 5 - "ui_kit.dart"
Cohesion: 0.05
Nodes (40): BoxFit, action, align, aspectRatio, _btn, build, compact, disabled (+32 more)

### Community 6 - "Cart Controller"
Cohesion: 0.06
Nodes (33): add, appliedCode, appliedPromo, applyPromo, categories, clear, clearPromo, decrement (+25 more)

### Community 7 - "product_manager_view.dart"
Cohesion: 0.05
Nodes (36): _addGroup, admin, build, _BulkResult, _category, _confirmDelete, createState, _description (+28 more)

### Community 8 - "Catalog Controller"
Cohesion: 0.06
Nodes (32): ../core/utils/browser/browser.dart, activeImage, _applyGroup, availableCategories, availableSizes, _cachedCategories, canAddToCart, categoryFilter (+24 more)

### Community 9 - "checkout_view.dart"
Cohesion: 0.10
Nodes (20): cart_view.dart, build, cart, CheckoutView, _CheckoutViewState, _city, _country, createState (+12 more)

### Community 10 - "Promotion Builder View"
Cohesion: 0.06
Nodes (31): ../../core/utils/uuid.dart, DiscountType, Promotion, _active, admin, build, _code, createState (+23 more)

### Community 11 - "Order Model"
Cohesion: 0.06
Nodes (30): category, contactEmail, createdAt, discountTotal, fromDb, fromJson, grandTotal, id (+22 more)

### Community 12 - "Database Schema"
Cohesion: 0.11
Nodes (21): on_auth_user_created, public.addresses, public.current_app_role(), public.order_items, public.orders, public.place_order(), public.products, public.profiles (+13 more)

### Community 14 - "App Config & Settings"
Cohesion: 0.08
Nodes (26): @visibleForTesting, app_constants.dart, env.dart, json_parse.dart, flatShippingFee, freeShippingThreshold, load, StoreSettings (+18 more)

### Community 15 - "user_model.dart"
Cohesion: 0.07
Nodes (27): customer,
  catalogManager,
  marketingManager,
  fulfillment,, Address, admin, AppRole, AppUser, canManageCatalog, canManageOrders, canManagePromotions (+19 more)

### Community 16 - "product_model.dart"
Cohesion: 0.08
Nodes (25): bool get, DateTime?, double get, Iterable, allItems, basePrice, category, copyWith (+17 more)

### Community 17 - "Variant Model"
Cohesion: 0.08
Nodes (25): double?, colorHex, copyWith, effectivePrice, fromJson, groupId, groupImages, hasStock (+17 more)

### Community 18 - "App Color Theme"
Cohesion: 0.08
Nodes (25): AppColors, charcoal, danger, gold, goldDeep, goldSoft, info, ink (+17 more)

### Community 19 - "auth_controller.dart"
Cohesion: 0.05
Nodes (38): AppRole get, FormState, _bindAuthState, error, isLoading, isLoggedIn, isStaff, _loadProfile (+30 more)

### Community 20 - "cart_item_model.dart"
Cohesion: 0.08
Nodes (24): ../core/utils/json_parse.dart, category, colorName, from, fromJson, imageUrl, key, lineTotal (+16 more)

### Community 21 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.13
Nodes (17): AdminController, package:flutter_test/flutter_test.dart, package:vanguard_fashion/controllers/admin_controller.dart, package:vanguard_fashion/models/order_model.dart, package:vanguard_fashion/models/product_model.dart, package:vanguard_fashion/models/variant_model.dart, package:vanguard_fashion/views/storefront/order_confirmation_view.dart, main (+9 more)

### Community 22 - "App Constants & RPC Names"
Cohesion: 0.08
Nodes (24): all, AppConstants, appName, Categories, freeReturnsDays, lowStockThreshold, rpcAdminStats, rpcPlaceOrder (+16 more)

### Community 23 - "Auth Controller Tests"
Cohesion: 0.11
Nodes (22): dart:async, GoTrueClient, Mock, MockSupabaseClient, package:mocktail/mocktail.dart, package:vanguard_fashion/core/utils/supabase_service.dart, PostgrestFilterBuilder, PostgrestTransformBuilder (+14 more)

### Community 24 - "cart_test.dart"
Cohesion: 0.12
Nodes (15): dart:convert, CartController, Product, package:vanguard_fashion/controllers/cart_controller.dart, package:vanguard_fashion/core/utils/env.dart, package:vanguard_fashion/core/utils/store_settings.dart, cart, lineFor (+7 more)

### Community 25 - "wishlist_test.dart"
Cohesion: 0.10
Nodes (19): CatalogController, package:vanguard_fashion/controllers/auth_controller.dart, package:vanguard_fashion/controllers/catalog_controller.dart, package:vanguard_fashion/controllers/wishlist_controller.dart, package:vanguard_fashion/core/utils/demo_data.dart, package:vanguard_fashion/views/shared/variant_selector.dart, catalog, main (+11 more)

### Community 26 - "home_view.dart"
Cohesion: 0.11
Nodes (18): ../../core/utils/bootstrap5.dart, ../../core/utils/seo/seo_service.dart, _AnnouncementBar, build, _CategoryStrip, _cats, _EditorialBand, _Hero (+10 more)

### Community 27 - "State"
Cohesion: 0.17
Nodes (16): _ColorGroupDialog, _ColorGroupDialogState, ProductEditorDialog, _ProductEditorDialogState, ProductCard, _ProductCardState, _OrderHistoryList, _OrderHistoryListState (+8 more)

### Community 28 - "wishlist_controller.dart"
Cohesion: 0.11
Nodes (18): auth_controller.dart, catalog_controller.dart, ../core/utils/demo_data.dart, int get, count, fetchWishlist, isEmpty, isLoading (+10 more)

### Community 29 - "Admin Scaffold Navigation"
Cohesion: 0.11
Nodes (18): IconData?, _AccessDenied, actions, active, _adminNav, AdminNavItem, AdminScaffold, auth (+10 more)

### Community 30 - "Initial DB Schema Migration"
Cohesion: 0.17
Nodes (16): on_auth_user_created, public.addresses, public.order_items, public.orders, public.products, public.profiles, public.promotions, public.variant_groups (+8 more)

### Community 31 - "Custom App Bar"
Cohesion: 0.11
Nodes (17): build, cart, _CartButton, _go, _goShop, _height, label, _NavLink (+9 more)

### Community 32 - "Cart Controller Test Fakes"
Cohesion: 0.12
Nodes (16): Fake, VariantGroup, Object?, R, asStream, catchError, controller, FakePostgrestFilterBuilder (+8 more)

### Community 33 - "cart_view.dart"
Cohesion: 0.12
Nodes (15): ../../core/utils/env.dart, CartItem, build, cart, _CartLine, CartView, createState, dispose (+7 more)

### Community 34 - "App Routes Constants"
Cohesion: 0.12
Nodes (15): account, adminDashboard, adminOrders, adminProducts, adminPromotions, AppRoutes, cart, checkout (+7 more)

### Community 35 - "Product Detail View"
Cohesion: 0.12
Nodes (15): _Accordion, _addToCart, _AssuranceRow, _Breadcrumb, build, catalog, createState, description (+7 more)

### Community 36 - "StatelessWidget"
Cohesion: 0.10
Nodes (26): admin_scaffold.dart, Color get, ../../controllers/admin_controller.dart, FB5Col, Order, admin, AdminDashboardView, build (+18 more)

### Community 37 - "Dev Notes & Learnings"
Cohesion: 0.11
Nodes (18): 2023-11-20 - [Performance Optimization], 2024-05-18 - Avoid dart format ., 2024-05-18 - Use GetUtils for validation, 2024-05-19 - Dart Environment Variable Parsing, 2024-05-19 - Dart Type Promotion Convention, 2024-05-24 - Testing Strategy for Data Models \n **Learning:** Data models in Dart/Flutter, specifically those parsing JSON, require exhaustive testing of both valid data and missing/null optional fields (edge cases) to prevent runtime parsing errors. Computations derived from these models (like formatting IDs or calculating totals) should also have dedicated unit tests. \n **Action:** When creating tests for data models, always include JSON fixture-based parsing tests covering all fields (happy path), null/missing optional fields, and unit tests for any getters or calculated properties., 2024-07-28 - Avoid chained map/where/toList in Dart, 2024-08-02 - Caching String Regex Execution (+10 more)

### Community 38 - "account_view.dart"
Cohesion: 0.13
Nodes (18): Bindings, ../../controllers/auth_controller.dart, ../../controllers/cart_controller.dart, ../../controllers/catalog_controller.dart, ../../controllers/orders_controller.dart, ../../controllers/wishlist_controller.dart, GetxController, AuthController (+10 more)

### Community 39 - "OrdersController"
Cohesion: 0.33
Nodes (5): OrdersController, package:vanguard_fashion/controllers/orders_controller.dart, main, order, orders

### Community 40 - "storefront_scaffold.dart"
Cohesion: 0.09
Nodes (22): core/bindings/initial_binding.dart, core/routes/app_pages.dart, ../../core/routes/app_routes.dart, ../../core/theme/app_theme.dart, ../../core/utils/app_constants.dart, core/utils/store_settings.dart, core/utils/url_strategy/url_strategy.dart, custom_app_bar.dart (+14 more)

### Community 41 - "variant_selector.dart"
Cohesion: 0.17
Nodes (11): ../../core/theme/app_typography.dart, VariantItem, build, controller, item, onTap, selected, _showSizeGuide (+3 more)

### Community 42 - "App Theme"
Cohesion: 0.17
Nodes (10): app_colors.dart, app_spacing.dart, app_typography.dart, AppTheme, AppTypography, eyebrow, scaleFor, textTheme (+2 more)

### Community 43 - "package:get/get.dart"
Cohesion: 0.17
Nodes (10): ../../core/utils/formatters.dart, build, createState, _hover, product, _swatches, _tag, package:get/get.dart (+2 more)

### Community 44 - "Formatters Utility"
Cohesion: 0.17
Nodes (11): _compact, _date, _dateTime, Formatters, price, priceTrim, stockLabel, _usd (+3 more)

### Community 45 - "DB Functions Migration"
Cohesion: 0.17
Nodes (8): public.current_app_role(), public.validate_promotion(), public.variant_unit_price(), public.products, public.profiles, public.promotions, public.variant_groups, public.variant_items

### Community 47 - "orders_controller.dart"
Cohesion: 0.17
Nodes (11): ../../core/utils/supabase_service.dart, clear, error, fetch, isLoading, orders, record, _sessionOrders (+3 more)

### Community 48 - "Demo Data"
Cohesion: 0.18
Nodes (10): DemoData, _img, products, promotions, _round2, validatePromo, ../../models/product_model.dart, ../../models/promotion_model.dart (+2 more)

### Community 49 - "JSON Parsing Utility"
Cohesion: 0.18
Nodes (10): date, dateOrNull, J, str, strList, strOrNull, toBool, toDouble (+2 more)

### Community 50 - "Model & Utility Tests"
Cohesion: 0.15
Nodes (10): package:vanguard_fashion/core/utils/formatters.dart, package:vanguard_fashion/core/utils/json_parse.dart, package:vanguard_fashion/core/utils/uuid.dart, package:vanguard_fashion/models/cart_item_model.dart, package:vanguard_fashion/models/promotion_model.dart, package:vanguard_fashion/models/user_model.dart, main, main (+2 more)

### Community 51 - "PWA Manifest"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 52 - "Environment Config"
Cohesion: 0.20
Nodes (9): Env, flatShippingFee, freeShippingThreshold, hasSupabase, supabaseAnonKey, supabaseUrl, static bool get, static const String (+1 more)

### Community 53 - "UUID Utility"
Cohesion: 0.22
Nodes (8): dart:math, isValid, _pattern, _rng, Uuid, v4, static final Random, static final RegExp

### Community 54 - "DB Hardening Migration"
Cohesion: 0.25
Nodes (4): public.place_order(), public.store_settings, public.set_updated_at, trg_store_settings_updated

### Community 55 - "Browser Storage Abstraction"
Cohesion: 0.29
Nodes (6): browser_stub.dart, Browser, read, remove, replaceUrl, write

### Community 56 - "assert_eq"
Cohesion: 0.33
Nodes (5): pg_namespace, pg_proc, assert_eq(), public.order_items, public.variant_items

### Community 57 - "Browser Storage Stub"
Cohesion: 0.40
Nodes (4): readLocal, removeLocal, replaceUrl, writeLocal

### Community 58 - "responsive_grid_test.dart"
Cohesion: 0.40
Nodes (4): package:vanguard_fashion/core/utils/bootstrap5.dart, main, surface, widthsAt

### Community 59 - "Promo Edge Function"
Cohesion: 0.40
Nodes (3): corsHeaders, PromoLine, PromoRequest

### Community 60 - "SEO Service"
Cohesion: 0.50
Nodes (3): SeoService, update, seo_stub.dart

### Community 84 - "../../core/theme/app_colors.dart"
Cohesion: 0.22
Nodes (8): ../../core/theme/app_colors.dart, build, count, ProductGrid, ProductGridSkeleton, products, List, product_card.dart

### Community 85 - "Project README"
Cohesion: 0.18
Nodes (10): A note on `flutter_bootstrap5`, Backend setup (Supabase), Demo promo codes, Exploring the admin panel in demo mode, Getting started, Highlights, Project structure (GetX MVC), Responsive breakpoints (PRD §6.2) (+2 more)

### Community 88 - "package:flutter/material.dart"
Cohesion: 0.13
Nodes (14): ../../core/theme/app_spacing.dart, OrderStatus, build, OrderConfirmationView, orderProgressStep, _OrderProgressTracker, status, _totalRow (+6 more)

### Community 89 - "20_contract.sh"
Cohesion: 0.60
Nodes (5): bad(), ok(), q(), say(), 20_contract.sh script

## Knowledge Gaps
- **814 isolated node(s):** `LowStockEntry`, `productTitle`, `colorName`, `sizeLabel`, `sku` (+809 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **21 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CartController` connect `cart_test.dart` to `Cart Controller Test Fakes`, `cart_view.dart`, `Product Detail View`, `account_view.dart`, `Cart Controller`, `storefront_scaffold.dart`, `checkout_view.dart`, `Custom App Bar`?**
  _High betweenness centrality (0.024) - this node is a cross-community bridge._
- **Why does `AuthController` connect `account_view.dart` to `Routing & Access Guards`, `checkout_view.dart`, `auth_controller.dart`, `Auth Controller Tests`, `wishlist_test.dart`, `wishlist_controller.dart`, `Admin Scaffold Navigation`, `Custom App Bar`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **What connects `LowStockEntry`, `productTitle`, `colorName` to the rest of the system?**
  _814 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Routing & Access Guards` be split into smaller, more focused modules?**
  _Cohesion score 0.043478260869565216 - nodes in this community are weakly interconnected._
- **Should `Admin Controller` be split into smaller, more focused modules?**
  _Cohesion score 0.043478260869565216 - nodes in this community are weakly interconnected._
- **Should `bootstrap5.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.0425531914893617 - nodes in this community are weakly interconnected._
- **Should `Browser JS Interop` be split into smaller, more focused modules?**
  _Cohesion score 0.05547652916073969 - nodes in this community are weakly interconnected._