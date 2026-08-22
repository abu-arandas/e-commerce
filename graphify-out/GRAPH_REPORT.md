# Graph Report - e-commerce  (2026-08-22)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1278 nodes · 1785 edges · 84 communities (65 shown, 19 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 48,276 input · 3,468 output

## Graph Freshness
- Built from commit: `71244935`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Routing & Layout Guards
- Admin Controller
- Bootstrap5 Responsive Utils
- Browser JS Interop
- Promotion Model
- UI Kit Components
- Cart Controller
- Product Manager View
- Catalog Controller
- Cart & Checkout Views
- Promotion Builder View
- Order Model
- Database Schema
- Orders Controller Tests
- App Config & Settings
- User Model & Roles
- Product Model
- Variant Model
- App Color Theme
- Auth Controller
- Cart Item Model
- Admin Controller Tests
- App Constants & RPC Names
- Auth Controller Tests
- Cart Persistence Tests
- Catalog Variant Tests
- Home & Shop Views
- Admin Dialogs & Auth Views
- Wishlist Controller
- Admin Navigation Scaffold
- Initial DB Schema Migration
- App Bar Navigation
- Cart Controller Tests
- Cart View & Order Summary
- App Routes
- Product Detail View
- Admin Dashboard View
- Responsive UI Widgets
- App Bindings
- Login View
- App Bootstrap & Entry
- Variant Selector
- App Theme & Typography
- Product Grid & Order Confirmation
- Formatters Utility
- DB Functions Migration
- Storefront Scaffold
- Orders Controller
- Demo Data
- JSON Parsing Utility
- Model & Utility Tests
- PWA Manifest
- Environment Config
- UUID Utility
- DB Hardening Migration
- Browser Storage Abstraction
- SQL Assertions Tests
- Browser Stub Storage
- Admin & Layout Tests
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
- Product Card Widget

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
- `AdminController` --inherits--> `GetxController`  [EXTRACTED]
  lib/controllers/admin_controller.dart → None  _Bridges community 58 → community 38_
- `CartController` --inherits--> `GetxController`  [EXTRACTED]
  lib/controllers/cart_controller.dart → None  _Bridges community 24 → community 38_
- `CatalogController` --inherits--> `GetxController`  [EXTRACTED]
  lib/controllers/catalog_controller.dart → None  _Bridges community 25 → community 38_
- `_AnnouncementBar` --inherits--> `StatelessWidget`  [EXTRACTED]
  lib/views/storefront/home_view.dart → None  _Bridges community 26 → community 37_

## Import Cycles
- None detected.

## Communities (84 total, 19 thin omitted)

### Community 0 - "Routing & Layout Guards"
Cohesion: 0.04
Nodes (44): app_routes.dart, GetMiddleware, AppPages, redirect, routes, _StaffGuard, AppShadows, AppSpacing (+36 more)

### Community 1 - "Admin Controller"
Cohesion: 0.04
Nodes (45): activeProducts, activePromotions, _cachedRevenueByCategory, _cachedTotalSkus, colorName, deleteProduct, deletePromotion, _demoOrders (+37 more)

### Community 2 - "Bootstrap5 Responsive Utils"
Cohesion: 0.05
Nodes (43): AlignmentGeometry, BuildContext, EdgeInsetsGeometry, Fb5Breakpoint get, alignment, atLeast, _bpFromToken, breakpoint (+35 more)

### Community 3 - "Browser JS Interop"
Cohesion: 0.06
Nodes (38): dart:js_interop, external _Document get, external _Element? get, external _History get, external _Location get, external _Storage get, external String get, _ (+30 more)

### Community 4 - "Promotion Model"
Cohesion: 0.06
Nodes (35): int?, category, code, db, description, discountAmount, discountValue, eligibleSubtotal (+27 more)

### Community 5 - "UI Kit Components"
Cohesion: 0.06
Nodes (33): BoxFit, action, align, aspectRatio, _btn, build, compact, disabled (+25 more)

### Community 6 - "Cart Controller"
Cohesion: 0.06
Nodes (33): add, appliedCode, appliedPromo, applyPromo, categories, clear, clearPromo, decrement (+25 more)

### Community 7 - "Product Manager View"
Cohesion: 0.06
Nodes (33): _addGroup, admin, build, _BulkResult, _category, _confirmDelete, createState, _description (+25 more)

### Community 8 - "Catalog Controller"
Cohesion: 0.06
Nodes (32): ../core/utils/browser/browser.dart, activeImage, _applyGroup, availableCategories, availableSizes, _cachedCategories, canAddToCart, categoryFilter (+24 more)

### Community 9 - "Cart & Checkout Views"
Cohesion: 0.11
Nodes (18): cart_view.dart, build, cart, _city, _country, createState, dispose, _email (+10 more)

### Community 10 - "Promotion Builder View"
Cohesion: 0.07
Nodes (29): ../../core/utils/uuid.dart, DiscountType, Promotion, _active, admin, build, _code, createState (+21 more)

### Community 11 - "Order Model"
Cohesion: 0.06
Nodes (30): category, contactEmail, createdAt, discountTotal, fromDb, fromJson, grandTotal, id (+22 more)

### Community 12 - "Database Schema"
Cohesion: 0.11
Nodes (21): on_auth_user_created, public.addresses, public.current_app_role(), public.order_items, public.orders, public.place_order(), public.products, public.profiles (+13 more)

### Community 13 - "Orders Controller Tests"
Cohesion: 0.33
Nodes (5): OrdersController, package:vanguard_fashion/controllers/orders_controller.dart, main, order, orders

### Community 14 - "App Config & Settings"
Cohesion: 0.08
Nodes (26): @visibleForTesting, app_constants.dart, env.dart, json_parse.dart, flatShippingFee, freeShippingThreshold, load, StoreSettings (+18 more)

### Community 15 - "User Model & Roles"
Cohesion: 0.07
Nodes (27): customer,
  catalogManager,
  marketingManager,
  fulfillment,, Address, admin, AppRole, AppUser, canManageCatalog, canManageOrders, canManagePromotions (+19 more)

### Community 16 - "Product Model"
Cohesion: 0.08
Nodes (24): DateTime?, Iterable, allItems, basePrice, category, copyWith, createdAt, description (+16 more)

### Community 17 - "Variant Model"
Cohesion: 0.08
Nodes (25): double?, colorHex, copyWith, effectivePrice, fromJson, groupId, groupImages, hasStock (+17 more)

### Community 18 - "App Color Theme"
Cohesion: 0.08
Nodes (25): AppColors, charcoal, danger, gold, goldDeep, goldSoft, info, ink (+17 more)

### Community 19 - "Auth Controller"
Cohesion: 0.08
Nodes (23): AppRole get, _bindAuthState, error, isLoading, isLoggedIn, isStaff, _loadProfile, _lockoutDuration (+15 more)

### Community 20 - "Cart Item Model"
Cohesion: 0.08
Nodes (24): ../core/utils/json_parse.dart, double get, category, colorName, from, fromJson, imageUrl, key (+16 more)

### Community 21 - "Admin Controller Tests"
Cohesion: 0.17
Nodes (11): package:vanguard_fashion/controllers/admin_controller.dart, package:vanguard_fashion/models/order_model.dart, package:vanguard_fashion/models/product_model.dart, package:vanguard_fashion/models/variant_model.dart, main, main, main, main (+3 more)

### Community 22 - "App Constants & RPC Names"
Cohesion: 0.08
Nodes (24): all, AppConstants, appName, Categories, freeReturnsDays, lowStockThreshold, rpcAdminStats, rpcPlaceOrder (+16 more)

### Community 23 - "Auth Controller Tests"
Cohesion: 0.10
Nodes (24): dart:async, Fake, GoTrueClient, Mock, MockSupabaseClient, package:mocktail/mocktail.dart, package:vanguard_fashion/core/utils/supabase_service.dart, PostgrestFilterBuilder (+16 more)

### Community 24 - "Cart Persistence Tests"
Cohesion: 0.10
Nodes (19): dart:convert, CartController, Product, package:vanguard_fashion/controllers/cart_controller.dart, package:vanguard_fashion/core/utils/demo_data.dart, package:vanguard_fashion/core/utils/env.dart, package:vanguard_fashion/core/utils/store_settings.dart, cart (+11 more)

### Community 25 - "Catalog Variant Tests"
Cohesion: 0.11
Nodes (17): CatalogController, package:get/get.dart, package:vanguard_fashion/controllers/auth_controller.dart, package:vanguard_fashion/controllers/catalog_controller.dart, package:vanguard_fashion/controllers/wishlist_controller.dart, package:vanguard_fashion/views/shared/variant_selector.dart, main, catalog (+9 more)

### Community 26 - "Home & Shop Views"
Cohesion: 0.11
Nodes (17): ../../core/utils/seo/seo_service.dart, _AnnouncementBar, build, _CategoryStrip, _cats, _EditorialBand, _Hero, HomeView (+9 more)

### Community 27 - "Admin Dialogs & Auth Views"
Cohesion: 0.16
Nodes (18): _BulkVariantDialog, _BulkVariantDialogState, _ColorGroupDialog, _ColorGroupDialogState, ProductEditorDialog, _ProductEditorDialogState, PromotionEditorDialog, _PromotionEditorDialogState (+10 more)

### Community 28 - "Wishlist Controller"
Cohesion: 0.10
Nodes (19): auth_controller.dart, bool get, catalog_controller.dart, ../core/utils/demo_data.dart, int get, count, fetchWishlist, isEmpty (+11 more)

### Community 29 - "Admin Navigation Scaffold"
Cohesion: 0.11
Nodes (18): IconData, _AccessDenied, actions, active, _adminNav, AdminNavItem, AdminScaffold, auth (+10 more)

### Community 30 - "Initial DB Schema Migration"
Cohesion: 0.17
Nodes (16): on_auth_user_created, public.addresses, public.order_items, public.orders, public.products, public.profiles, public.promotions, public.variant_groups (+8 more)

### Community 31 - "App Bar Navigation"
Cohesion: 0.11
Nodes (17): build, cart, _CartButton, _go, _goShop, _height, label, _NavLink (+9 more)

### Community 32 - "Cart Controller Tests"
Cohesion: 0.13
Nodes (14): VariantGroup, Object?, R, asStream, catchError, controller, main, _shouldThrow (+6 more)

### Community 33 - "Cart View & Order Summary"
Cohesion: 0.12
Nodes (17): ../../core/utils/env.dart, CartItem, build, cart, _CartLine, CartView, createState, dispose (+9 more)

### Community 34 - "App Routes"
Cohesion: 0.12
Nodes (15): account, adminDashboard, adminOrders, adminProducts, adminPromotions, AppRoutes, cart, checkout (+7 more)

### Community 35 - "Product Detail View"
Cohesion: 0.12
Nodes (15): _Accordion, _addToCart, _AssuranceRow, _Breadcrumb, build, catalog, createState, description (+7 more)

### Community 36 - "Admin Dashboard View"
Cohesion: 0.08
Nodes (24): admin_scaffold.dart, Color get, ../../controllers/admin_controller.dart, Order, OrderStatus, admin, AdminDashboardView, build (+16 more)

### Community 37 - "Responsive UI Widgets"
Cohesion: 0.13
Nodes (15): Fb5BreakpointBuilder, FB5Col, FB5Container, FB5Row, _HeaderRow, ProductManagerView, _ProductRow, EmptyState (+7 more)

### Community 38 - "App Bindings"
Cohesion: 0.12
Nodes (21): Bindings, ../../controllers/auth_controller.dart, ../../controllers/cart_controller.dart, ../../controllers/catalog_controller.dart, ../../controllers/orders_controller.dart, ../../controllers/wishlist_controller.dart, ../../core/utils/formatters.dart, GetxController (+13 more)

### Community 39 - "Login View"
Cohesion: 0.14
Nodes (13): FormState, auth, build, createState, _demoChip, dispose, _email, _formKey (+5 more)

### Community 40 - "App Bootstrap & Entry"
Cohesion: 0.15
Nodes (12): core/bindings/initial_binding.dart, core/routes/app_pages.dart, core/theme/app_theme.dart, core/utils/app_constants.dart, core/utils/store_settings.dart, core/utils/supabase_service.dart, core/utils/url_strategy/url_strategy.dart, build (+4 more)

### Community 41 - "Variant Selector"
Cohesion: 0.15
Nodes (12): ../../core/theme/app_typography.dart, VariantItem, build, controller, item, onTap, selected, _showSizeGuide (+4 more)

### Community 42 - "App Theme & Typography"
Cohesion: 0.17
Nodes (11): app_colors.dart, app_spacing.dart, app_typography.dart, AppTheme, AppTypography, eyebrow, scaleFor, textTheme (+3 more)

### Community 43 - "Product Grid & Order Confirmation"
Cohesion: 0.10
Nodes (22): ../../core/theme/app_colors.dart, ../../core/theme/app_spacing.dart, ../../core/utils/bootstrap5.dart, build, count, ProductGrid, ProductGridSkeleton, products (+14 more)

### Community 44 - "Formatters Utility"
Cohesion: 0.17
Nodes (11): _compact, _date, _dateTime, Formatters, price, priceTrim, stockLabel, _usd (+3 more)

### Community 45 - "DB Functions Migration"
Cohesion: 0.17
Nodes (8): public.current_app_role(), public.validate_promotion(), public.variant_unit_price(), public.products, public.profiles, public.promotions, public.variant_groups, public.variant_items

### Community 46 - "Storefront Scaffold"
Cohesion: 0.18
Nodes (10): custom_app_bar.dart, AppFooter, build, child, _links, scrollable, showFooter, _StickyCartBar (+2 more)

### Community 47 - "Orders Controller"
Cohesion: 0.18
Nodes (10): clear, error, fetch, isLoading, orders, record, _sessionOrders, RxBool (+2 more)

### Community 48 - "Demo Data"
Cohesion: 0.18
Nodes (10): DemoData, _img, products, promotions, _round2, validatePromo, ../models/product_model.dart, ../models/promotion_model.dart (+2 more)

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

### Community 56 - "SQL Assertions Tests"
Cohesion: 0.33
Nodes (5): pg_namespace, pg_proc, assert_eq(), public.order_items, public.variant_items

### Community 57 - "Browser Stub Storage"
Cohesion: 0.40
Nodes (4): readLocal, removeLocal, replaceUrl, writeLocal

### Community 58 - "Admin & Layout Tests"
Cohesion: 0.14
Nodes (11): AdminController, package:flutter_test/flutter_test.dart, package:vanguard_fashion/core/utils/bootstrap5.dart, package:vanguard_fashion/views/storefront/order_confirmation_view.dart, admin, main, main, main (+3 more)

### Community 59 - "Promo Edge Function"
Cohesion: 0.40
Nodes (3): corsHeaders, PromoLine, PromoRequest

### Community 60 - "SEO Service"
Cohesion: 0.50
Nodes (3): SeoService, update, seo_stub.dart

### Community 84 - "Product Card Widget"
Cohesion: 0.22
Nodes (9): core/routes/app_routes.dart, build, createState, _hover, product, ProductCard, _ProductCardState, _swatches (+1 more)

## Knowledge Gaps
- **787 isolated node(s):** `PromoLine`, `PromoRequest`, `AppPages`, `redirect`, `routes` (+782 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **19 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CartController` connect `Cart Persistence Tests` to `Cart Controller Tests`, `Cart View & Order Summary`, `Product Detail View`, `App Bindings`, `Cart Controller`, `Cart & Checkout Views`, `Storefront Scaffold`, `App Bar Navigation`?**
  _High betweenness centrality (0.034) - this node is a cross-community bridge._
- **Why does `AuthController` connect `App Bindings` to `Routing & Layout Guards`, `Login View`, `Cart & Checkout Views`, `Auth Controller`, `Auth Controller Tests`, `Catalog Variant Tests`, `Wishlist Controller`, `Admin Navigation Scaffold`, `App Bar Navigation`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **What connects `PromoLine`, `PromoRequest`, `AppPages` to the rest of the system?**
  _787 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Routing & Layout Guards` be split into smaller, more focused modules?**
  _Cohesion score 0.043478260869565216 - nodes in this community are weakly interconnected._
- **Should `Admin Controller` be split into smaller, more focused modules?**
  _Cohesion score 0.043478260869565216 - nodes in this community are weakly interconnected._
- **Should `Bootstrap5 Responsive Utils` be split into smaller, more focused modules?**
  _Cohesion score 0.045454545454545456 - nodes in this community are weakly interconnected._
- **Should `Browser JS Interop` be split into smaller, more focused modules?**
  _Cohesion score 0.05547652916073969 - nodes in this community are weakly interconnected._