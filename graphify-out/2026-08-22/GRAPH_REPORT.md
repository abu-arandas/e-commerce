# Graph Report - e-commerce  (2026-08-22)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1378 nodes · 1867 edges · 100 communities (73 shown, 27 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 49,480 input · 6,550 output

## Graph Freshness
- Built from commit: `7962ff55`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Routing & Layout Guards
- Admin Controller
- Bootstrap5 Responsive Layout
- Browser JS Interop
- Promotion Model
- UI Kit Widgets
- Cart Controller
- Product Manager View
- Catalog Controller
- Checkout Form View
- Promotion Builder View
- Order Model
- Database Schema
- Order Confirmation & Wishlist Views
- App Config & Settings
- User Model & Roles
- Product Model
- Variant Model
- App Color Theme
- Auth Controller
- Cart Item Model
- Admin & Model Tests
- App Constants & RPC Names
- Auth Controller Tests
- Cart Controller Tests
- Catalog & Promo Tests
- Home & Shop Views
- Product & Checkout Widgets
- Wishlist Controller
- Admin Scaffold Navigation
- Initial DB Schema Migration
- App Bar Navigation
- Cart Controller Fakes
- Cart View
- App Route Definitions
- Product Detail View
- Admin Dashboard View
- Product Manager UI Components
- GetX Controllers & Bindings
- Login View
- App Bootstrap & Init
- Variant Selector Widget
- App Theme Definitions
- Graphify Skill Docs
- Formatters Utility
- DB Functions Migration
- Storefront Scaffold
- Orders Controller
- Demo Data
- JSON Parsing Utility
- Cart Test Entry
- PWA Manifest
- Environment Config
- UUID Utility
- DB Hardening Migration
- Browser Storage Abstraction
- DB Test Assertions
- Browser Stub Storage
- Dev Notes & Learnings
- Promo Edge Function
- SEO Service
- DB Integrity Migration
- URL Strategy Config
- Web URL Strategy
- Auth Schema Shim
- SEO Stub
- URL Strategy Stub
- Product Editor Dialog
- Addresses Table
- Wishlists Table
- Order Items Table
- Orders Table
- Products Table
- Profiles Table
- Promotions Table
- Variant Groups Table
- Variant Items Table
- Order Items Reference
- Orders Reference
- Orders Reference Alt
- Promotions Reference
- Admin Orders View
- Utility & Model Tests
- Find Skills Docs
- Admin Delete Tests
- Project README
- Graphify Export Docs
- Graphify Query Docs
- Graphify Add & Watch Docs
- Graphify Hooks Docs
- Graphify Update Docs
- Graphify GitHub Merge Docs
- Graphify Transcription Docs
- Root Graphify Config
- Claude Dir Graphify Config
- Graphify Extraction Spec
- Bootstrap5 Tests

## God Nodes (most connected - your core abstractions)
1. `_` - 25 edges
2. `_` - 16 edges
3. `AuthController` - 12 edges
4. `What You Must Do When Invoked` - 12 edges
5. `CartController` - 11 edges
6. `CatalogController` - 11 edges
7. `/graphify` - 10 edges
8. `WishlistController` - 9 edges
9. `AdminController` - 8 edges
10. `graphify reference: extra exports and benchmark` - 8 edges

## Surprising Connections (you probably didn't know these)
- `_PromoCard` --inherits--> `StatelessWidget`  [EXTRACTED]
  lib/views/admin/promotion_builder_view.dart → None  _Bridges community 10 → community 37_
- `PromotionEditorDialog` --inherits--> `StatefulWidget`  [EXTRACTED]
  lib/views/admin/promotion_builder_view.dart → None  _Bridges community 10 → community 27_
- `OrderConfirmationView` --inherits--> `StatelessWidget`  [EXTRACTED]
  lib/views/storefront/order_confirmation_view.dart → None  _Bridges community 13 → community 37_
- `ProductGrid` --inherits--> `StatelessWidget`  [EXTRACTED]
  lib/views/shared/product_grid.dart → None  _Bridges community 17 → community 37_
- `FakePostgrestFilterBuilder` --implements--> `PostgrestFilterBuilder`  [EXTRACTED]
  test/controllers/cart_controller_test.dart → None  _Bridges community 23 → community 32_

## Import Cycles
- None detected.

## Communities (100 total, 27 thin omitted)

### Community 0 - "Routing & Layout Guards"
Cohesion: 0.04
Nodes (44): app_routes.dart, GetMiddleware, AppPages, redirect, routes, _StaffGuard, AppShadows, AppSpacing (+36 more)

### Community 1 - "Admin Controller"
Cohesion: 0.04
Nodes (45): activeProducts, activePromotions, _cachedRevenueByCategory, _cachedTotalSkus, colorName, deleteProduct, deletePromotion, _demoOrders (+37 more)

### Community 2 - "Bootstrap5 Responsive Layout"
Cohesion: 0.05
Nodes (43): AlignmentGeometry, BuildContext, EdgeInsetsGeometry, Fb5Breakpoint get, alignment, atLeast, _bpFromToken, breakpoint (+35 more)

### Community 3 - "Browser JS Interop"
Cohesion: 0.06
Nodes (38): dart:js_interop, external _Document get, external _Element? get, external _History get, external _Location get, external _Storage get, external String get, _ (+30 more)

### Community 4 - "Promotion Model"
Cohesion: 0.06
Nodes (35): int?, category, code, db, description, discountAmount, discountValue, eligibleSubtotal (+27 more)

### Community 5 - "UI Kit Widgets"
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

### Community 9 - "Checkout Form View"
Cohesion: 0.11
Nodes (18): cart_view.dart, build, cart, _city, _country, createState, dispose, _email (+10 more)

### Community 10 - "Promotion Builder View"
Cohesion: 0.06
Nodes (31): ../../core/utils/uuid.dart, DiscountType, Promotion, _active, admin, build, _code, createState (+23 more)

### Community 11 - "Order Model"
Cohesion: 0.06
Nodes (30): category, contactEmail, createdAt, discountTotal, fromDb, fromJson, grandTotal, id (+22 more)

### Community 12 - "Database Schema"
Cohesion: 0.11
Nodes (21): on_auth_user_created, public.addresses, public.current_app_role(), public.order_items, public.orders, public.place_order(), public.products, public.profiles (+13 more)

### Community 13 - "Order Confirmation & Wishlist Views"
Cohesion: 0.15
Nodes (13): ../../core/routes/app_routes.dart, OrderStatus, build, OrderConfirmationView, orderProgressStep, _OrderProgressTracker, status, _totalRow (+5 more)

### Community 14 - "App Config & Settings"
Cohesion: 0.07
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
Cohesion: 0.06
Nodes (32): double?, colorHex, copyWith, effectivePrice, fromJson, groupId, groupImages, hasStock (+24 more)

### Community 18 - "App Color Theme"
Cohesion: 0.08
Nodes (25): AppColors, charcoal, danger, gold, goldDeep, goldSoft, info, ink (+17 more)

### Community 19 - "Auth Controller"
Cohesion: 0.08
Nodes (23): AppRole get, _bindAuthState, error, isLoading, isLoggedIn, isStaff, _loadProfile, _lockoutDuration (+15 more)

### Community 20 - "Cart Item Model"
Cohesion: 0.08
Nodes (24): ../core/utils/json_parse.dart, double get, category, colorName, from, fromJson, imageUrl, key (+16 more)

### Community 21 - "Admin & Model Tests"
Cohesion: 0.12
Nodes (18): package:flutter_test/flutter_test.dart, package:vanguard_fashion/controllers/admin_controller.dart, package:vanguard_fashion/core/utils/bootstrap5.dart, package:vanguard_fashion/models/order_model.dart, package:vanguard_fashion/models/product_model.dart, package:vanguard_fashion/models/variant_model.dart, package:vanguard_fashion/views/storefront/order_confirmation_view.dart, main (+10 more)

### Community 22 - "App Constants & RPC Names"
Cohesion: 0.08
Nodes (24): all, AppConstants, appName, Categories, freeReturnsDays, lowStockThreshold, rpcAdminStats, rpcPlaceOrder (+16 more)

### Community 23 - "Auth Controller Tests"
Cohesion: 0.11
Nodes (22): dart:async, GoTrueClient, Mock, MockSupabaseClient, package:mocktail/mocktail.dart, package:vanguard_fashion/core/utils/supabase_service.dart, PostgrestFilterBuilder, PostgrestTransformBuilder (+14 more)

### Community 24 - "Cart Controller Tests"
Cohesion: 0.12
Nodes (15): dart:convert, CartController, Product, package:vanguard_fashion/controllers/cart_controller.dart, package:vanguard_fashion/core/utils/env.dart, package:vanguard_fashion/core/utils/store_settings.dart, cart, lineFor (+7 more)

### Community 25 - "Catalog & Promo Tests"
Cohesion: 0.09
Nodes (21): AuthController, CatalogController, package:vanguard_fashion/controllers/auth_controller.dart, package:vanguard_fashion/controllers/catalog_controller.dart, package:vanguard_fashion/controllers/wishlist_controller.dart, package:vanguard_fashion/core/utils/demo_data.dart, package:vanguard_fashion/models/promotion_model.dart, package:vanguard_fashion/views/shared/variant_selector.dart (+13 more)

### Community 26 - "Home & Shop Views"
Cohesion: 0.11
Nodes (18): ../../core/utils/bootstrap5.dart, ../../core/utils/seo/seo_service.dart, _AnnouncementBar, build, _CategoryStrip, _cats, _EditorialBand, _Hero (+10 more)

### Community 27 - "Product & Checkout Widgets"
Cohesion: 0.14
Nodes (20): _BulkVariantDialog, _BulkVariantDialogState, _ColorGroupDialog, _ColorGroupDialogState, ProductCard, _ProductCardState, _OrderHistoryList, _OrderHistoryListState (+12 more)

### Community 28 - "Wishlist Controller"
Cohesion: 0.10
Nodes (19): auth_controller.dart, bool get, catalog_controller.dart, ../core/utils/demo_data.dart, int get, count, fetchWishlist, isEmpty (+11 more)

### Community 29 - "Admin Scaffold Navigation"
Cohesion: 0.11
Nodes (18): IconData?, _AccessDenied, actions, active, _adminNav, AdminNavItem, AdminScaffold, auth (+10 more)

### Community 30 - "Initial DB Schema Migration"
Cohesion: 0.17
Nodes (16): on_auth_user_created, public.addresses, public.order_items, public.orders, public.products, public.profiles, public.promotions, public.variant_groups (+8 more)

### Community 31 - "App Bar Navigation"
Cohesion: 0.11
Nodes (17): build, cart, _CartButton, _go, _goShop, _height, label, _NavLink (+9 more)

### Community 32 - "Cart Controller Fakes"
Cohesion: 0.12
Nodes (16): Fake, VariantGroup, Object?, R, asStream, catchError, controller, FakePostgrestFilterBuilder (+8 more)

### Community 33 - "Cart View"
Cohesion: 0.12
Nodes (15): ../../core/utils/env.dart, CartItem, build, cart, _CartLine, CartView, createState, dispose (+7 more)

### Community 34 - "App Route Definitions"
Cohesion: 0.12
Nodes (15): account, adminDashboard, adminOrders, adminProducts, adminPromotions, AppRoutes, cart, checkout (+7 more)

### Community 35 - "Product Detail View"
Cohesion: 0.12
Nodes (15): _Accordion, _addToCart, _AssuranceRow, _Breadcrumb, build, catalog, createState, description (+7 more)

### Community 36 - "Admin Dashboard View"
Cohesion: 0.12
Nodes (15): admin_scaffold.dart, Color get, admin, AdminDashboardView, build, child, _color, _kpi (+7 more)

### Community 37 - "Product Manager UI Components"
Cohesion: 0.13
Nodes (15): Fb5BreakpointBuilder, FB5Col, FB5Container, FB5Row, _HeaderRow, ProductManagerView, _ProductRow, EmptyState (+7 more)

### Community 38 - "GetX Controllers & Bindings"
Cohesion: 0.09
Nodes (26): Bindings, ../../controllers/admin_controller.dart, ../../controllers/auth_controller.dart, ../../controllers/cart_controller.dart, ../../controllers/catalog_controller.dart, ../../controllers/orders_controller.dart, ../../controllers/wishlist_controller.dart, ../../core/theme/app_spacing.dart (+18 more)

### Community 39 - "Login View"
Cohesion: 0.14
Nodes (13): FormState, auth, build, createState, _demoChip, dispose, _email, _formKey (+5 more)

### Community 40 - "App Bootstrap & Init"
Cohesion: 0.15
Nodes (12): core/bindings/initial_binding.dart, core/routes/app_pages.dart, ../../core/theme/app_theme.dart, ../../core/utils/app_constants.dart, core/utils/store_settings.dart, ../../core/utils/supabase_service.dart, core/utils/url_strategy/url_strategy.dart, build (+4 more)

### Community 41 - "Variant Selector Widget"
Cohesion: 0.15
Nodes (12): ../../core/theme/app_typography.dart, VariantItem, build, controller, item, onTap, selected, _showSizeGuide (+4 more)

### Community 42 - "App Theme Definitions"
Cohesion: 0.17
Nodes (10): app_colors.dart, app_spacing.dart, app_typography.dart, AppTheme, AppTypography, eyebrow, scaleFor, textTheme (+2 more)

### Community 43 - "Graphify Skill Docs"
Cohesion: 0.08
Nodes (24): For /graphify add and --watch, For /graphify query, For the commit hook and native CLAUDE.md integration, For --update and --cluster-only, /graphify, Honesty Rules, Interpreter guard for subcommands, Part A - Structural extraction for code files (+16 more)

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
Cohesion: 0.17
Nodes (11): clear, error, fetch, isLoading, orders, record, _sessionOrders, ../../models/order_model.dart (+3 more)

### Community 48 - "Demo Data"
Cohesion: 0.18
Nodes (10): DemoData, _img, products, promotions, _round2, validatePromo, ../../models/product_model.dart, ../../models/promotion_model.dart (+2 more)

### Community 49 - "JSON Parsing Utility"
Cohesion: 0.18
Nodes (10): date, dateOrNull, J, str, strList, strOrNull, toBool, toDouble (+2 more)

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

### Community 56 - "DB Test Assertions"
Cohesion: 0.33
Nodes (5): pg_namespace, pg_proc, assert_eq(), public.order_items, public.variant_items

### Community 57 - "Browser Stub Storage"
Cohesion: 0.40
Nodes (4): readLocal, removeLocal, replaceUrl, writeLocal

### Community 58 - "Dev Notes & Learnings"
Cohesion: 0.11
Nodes (18): 2023-11-20 - [Performance Optimization], 2024-05-18 - Avoid dart format ., 2024-05-18 - Use GetUtils for validation, 2024-05-19 - Dart Environment Variable Parsing, 2024-05-19 - Dart Type Promotion Convention, 2024-05-24 - Testing Strategy for Data Models \n **Learning:** Data models in Dart/Flutter, specifically those parsing JSON, require exhaustive testing of both valid data and missing/null optional fields (edge cases) to prevent runtime parsing errors. Computations derived from these models (like formatting IDs or calculating totals) should also have dedicated unit tests. \n **Action:** When creating tests for data models, always include JSON fixture-based parsing tests covering all fields (happy path), null/missing optional fields, and unit tests for any getters or calculated properties., 2024-07-28 - Avoid chained map/where/toList in Dart, 2024-08-02 - Caching String Regex Execution (+10 more)

### Community 59 - "Promo Edge Function"
Cohesion: 0.40
Nodes (3): corsHeaders, PromoLine, PromoRequest

### Community 60 - "SEO Service"
Cohesion: 0.50
Nodes (3): SeoService, update, seo_stub.dart

### Community 84 - "Admin Orders View"
Cohesion: 0.22
Nodes (8): ../../core/theme/app_colors.dart, Order, admin, AdminOrdersView, build, order, _OrderTile, _StatusDropdown

### Community 85 - "Utility & Model Tests"
Cohesion: 0.18
Nodes (8): package:vanguard_fashion/core/utils/formatters.dart, package:vanguard_fashion/core/utils/json_parse.dart, package:vanguard_fashion/core/utils/uuid.dart, package:vanguard_fashion/models/cart_item_model.dart, package:vanguard_fashion/models/user_model.dart, main, main, main

### Community 86 - "Find Skills Docs"
Cohesion: 0.14
Nodes (13): Common Skill Categories, Find Skills, How to Help Users Find Skills, Step 1: Understand What They Need, Step 2: Check the Leaderboard First, Step 3: Search for Skills, Step 4: Verify Quality Before Recommending, Step 5: Present Options to the User (+5 more)

### Community 87 - "Admin Delete Tests"
Cohesion: 0.50
Nodes (3): AdminController, admin, main

### Community 88 - "Project README"
Cohesion: 0.18
Nodes (10): A note on `flutter_bootstrap5`, Backend setup (Supabase), Demo promo codes, Exploring the admin panel in demo mode, Getting started, Highlights, Project structure (GetX MVC), Responsive breakpoints (PRD §6.2) (+2 more)

### Community 89 - "Graphify Export Docs"
Cohesion: 0.22
Nodes (8): graphify reference: extra exports and benchmark, Step 6b - Wiki (only if --wiki flag), Step 7 - Neo4j export (only if --neo4j or --neo4j-push flag), Step 7a - FalkorDB export (only if --falkordb or --falkordb-push flag), Step 7b - SVG export (only if --svg flag), Step 7c - GraphML export (only if --graphml flag), Step 7d - MCP server (only if --mcp flag), Step 8 - Token reduction benchmark (only if total_words > 5000)

### Community 90 - "Graphify Query Docs"
Cohesion: 0.33
Nodes (5): For /graphify explain, For /graphify path, graphify reference: query, path, explain, Step 0 — Constrained query expansion (REQUIRED before traversal), Step 1 — Traversal

### Community 91 - "Graphify Add & Watch Docs"
Cohesion: 0.50
Nodes (3): For /graphify add, For --watch, graphify reference: add a URL and watch a folder

### Community 92 - "Graphify Hooks Docs"
Cohesion: 0.50
Nodes (3): For git commit hook, For native CLAUDE.md integration, graphify reference: commit hook and native CLAUDE.md integration

### Community 93 - "Graphify Update Docs"
Cohesion: 0.50
Nodes (3): For --cluster-only, For --update (incremental re-extraction), graphify reference: incremental update and cluster-only

## Knowledge Gaps
- **862 isolated node(s):** `PromoLine`, `PromoRequest`, `AppPages`, `redirect`, `routes` (+857 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **27 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CartController` connect `Cart Controller Tests` to `Cart Controller Fakes`, `Cart View`, `Product Detail View`, `GetX Controllers & Bindings`, `Cart Controller`, `Checkout Form View`, `Storefront Scaffold`, `App Bar Navigation`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **Why does `AuthController` connect `Catalog & Promo Tests` to `Routing & Layout Guards`, `GetX Controllers & Bindings`, `Login View`, `Checkout Form View`, `Auth Controller`, `Auth Controller Tests`, `Wishlist Controller`, `Admin Scaffold Navigation`, `App Bar Navigation`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **What connects `PromoLine`, `PromoRequest`, `AppPages` to the rest of the system?**
  _862 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Routing & Layout Guards` be split into smaller, more focused modules?**
  _Cohesion score 0.043478260869565216 - nodes in this community are weakly interconnected._
- **Should `Admin Controller` be split into smaller, more focused modules?**
  _Cohesion score 0.043478260869565216 - nodes in this community are weakly interconnected._
- **Should `Bootstrap5 Responsive Layout` be split into smaller, more focused modules?**
  _Cohesion score 0.045454545454545456 - nodes in this community are weakly interconnected._
- **Should `Browser JS Interop` be split into smaller, more focused modules?**
  _Cohesion score 0.05547652916073969 - nodes in this community are weakly interconnected._