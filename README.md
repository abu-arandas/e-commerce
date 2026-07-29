# Vanguard Fashion

A high-end, responsive **Flutter Web** e-commerce platform for premium apparel,
built to the Vanguard Fashion PRD. It pairs an editorial storefront with a
role-based back-office, multi-level nested product variants, a dynamic
promotions engine, and a Supabase (PostgreSQL) backend.

> **Runs with zero setup.** Without Supabase credentials the app boots against a
> built-in in-memory catalog so every screen — storefront and admin — is fully
> explorable. Add credentials to switch to the live backend.

---

## Highlights

- **Nested variants** — Product → Colour group → Size/SKU, with independent
  price overrides and stock at the deepest level. Selecting a colour instantly
  updates the available sizes, price, and stock, and rewrites the address bar so
  the exact colour is shareable.
- **Promotions engine** — percentage, fixed-amount, and free-shipping codes with
  minimum-order rules, usage limits, date windows, and category targeting. A
  category-targeted code discounts **only the lines it targets**. Validated
  server-side and re-validated live as the cart changes.
- **Atomic checkout** — a `place_order` Postgres function recomputes every unit
  price, the discount, and the shipping charge server-side, then decrements the
  exact nested SKU stock inside a transaction. The client sends SKUs and
  quantities; nothing it sends touches money.
- **Role-based admin** — dashboard analytics (aggregated in SQL), catalog CMS
  with bulk variant generation, a promotions rule-builder, and a fulfillment
  order grid that returns stock to the shelf on cancellation.
- **Responsive by design** — a faithful Bootstrap 5 grid (container/row/column,
  `col-{bp}-{n}`) at the PRD breakpoints, from single-column mobile to
  4-column desktop, with a split-screen product page and sticky mobile cart bar.
- **SEO & deep-linking** — clean path URLs (no `#`), per-route `<title>`/meta
  injection, and colour-specific product deep links
  (`/product/cashmere-turtleneck?color=midnight-blue`).
- **Survives a refresh** — the cart is persisted to `localStorage` and its promo
  code re-validated on restore.

## Tech stack

| Concern            | Choice                                             |
| ------------------ | -------------------------------------------------- |
| UI                 | Flutter Web (Material 3, CanvasKit + Wasm)         |
| State & routing    | GetX (`GetMaterialApp`, reactive `Rx`, middleware) |
| Responsiveness     | Bootstrap 5 grid (`lib/core/utils/bootstrap5.dart`)|
| Backend            | Supabase — Postgres, Auth, Storage, Edge Functions |
| Images             | `cached_network_image`, `.webp` from Storage CDN   |

### A note on `flutter_bootstrap5`

The PRD names the `flutter_bootstrap5` pub package. That package (v1.1.1) carries
an SDK constraint that stops below Dart 3, which is irreconcilable with
`supabase_flutter` 2.x and modern GetX (both require Dart 3) and with the PRD's
Wasm-compilation goal. Rather than ship a project that can't `pub get`, the grid
is re-implemented in
[`lib/core/utils/bootstrap5.dart`](lib/core/utils/bootstrap5.dart) with the same
public API (`FB5Container`, `FB5Row`, `FB5Col`), the same 12-column semantics and
`col-{bp}-{n}` grammar, and the exact PRD breakpoints — on a Dart-3, Wasm-ready
foundation.

---

## Getting started

Requires **Flutter 3.35+ (Dart 3.9+)**.

```bash
flutter pub get

# Demo mode (in-memory catalog, no backend):
flutter run -d chrome

# Live mode (Supabase):
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_ANON_KEY
```

Production build (Wasm, per PRD §6.1):

```bash
flutter build web --wasm \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

### Exploring the admin panel in demo mode

On the sign-in page, use the **"Explore back-office (demo)"** chips to preview
the Catalog, Marketing, Fulfillment, or Admin personas without a backend.

### Demo promo codes

`FALL20` (20% over $150) · `WELCOME15` ($15 over $75) · `FREESHIP` (free
shipping over $100) · `KNIT25` (25% off Knitwear — applied to the knitwear
lines only, not the rest of the bag).

---

## Tests

```bash
flutter test        # 74 unit/widget tests
flutter analyze     # clean
```

Covers the promotions engine (including category scoping), cart totals and
promo lifecycle, nested variant selection, the Bootstrap grid's breakpoints and
column maths, and model/JSON edge cases.

The SQL side has its own suite. Against any PostgreSQL 16 instance:

```bash
psql -f supabase/tests/00_shim.sql          # stands in for Supabase's auth schema
psql -f supabase/migrations/0001_init_schema.sql
psql -f supabase/migrations/0002_functions.sql
psql -f supabase/migrations/0003_rls.sql
psql -f supabase/migrations/0004_hardening.sql
psql -f supabase/seed.sql
psql -f supabase/tests/10_tests.sql          # 36 assertions
```

It exercises category-scoped discounts, server-side shipping, the usage-limit
race, duplicate-line stock bypass, restock idempotency, `save_product`'s
variant-tree round-trip, and the staff gates on every admin RPC.

---

## Backend setup (Supabase)

SQL lives in [`supabase/`](supabase/) as ordered migrations. Apply them with the
Supabase CLI (`supabase db push`) or paste them into the SQL editor in order:

1. `migrations/0001_init_schema.sql` — tables, enums, profile trigger.
2. `migrations/0002_functions.sql` — pricing, `validate_promotion`, atomic
   `place_order`, `restock_order`.
3. `migrations/0003_rls.sql` — Row-Level Security policies.
4. `migrations/0004_hardening.sql` — **required.** Corrects pricing, promotion
   and RLS defects in 0002/0003 and adds `store_settings`, `save_product` and
   `admin_stats`. See the header of that file for the full list.
5. `seed.sql` — demo catalog and promotions.

Deploy the promo-validation Edge Function:

```bash
supabase functions deploy validate-promo
supabase secrets set ALLOWED_ORIGINS=https://your-storefront.example
```

Grant a user staff access by setting their `profiles.role` (e.g.
`catalog_manager`, `marketing_manager`, `fulfillment`, `admin`).

Storage: create a public `products` bucket and upload `.webp` imagery; the seed
`group_images` URLs follow the `products/<slug>/<file>.webp` convention.

### Shipping configuration

Shipping is owned by the database, not the client. Edit the single row in
`store_settings`:

```sql
update public.store_settings
   set flat_shipping_fee = 12.00,
       free_shipping_threshold = 150.00;
```

The storefront reads those values for display and `place_order` charges from the
same row, so the two can never disagree.

---

## Project structure (GetX MVC)

```
lib/
├── main.dart                  # bootstraps Supabase + settings + GetMaterialApp
├── core/
│   ├── theme/                 # colours, typography, spacing, ThemeData
│   ├── utils/                 # bootstrap5 grid, supabase, seo, browser, uuid, env
│   ├── routes/                # AppRoutes + AppPages (+ staff guard)
│   └── bindings/              # InitialBinding (controller registration)
├── models/                    # product, variant, promotion, user, cart, order
├── controllers/               # auth, cart (promo engine), catalog, orders, admin
└── views/
    ├── storefront/            # home, shop, product detail, cart, checkout, …
    ├── admin/                 # dashboard, product manager, promotion builder, orders
    └── shared/                # app bar, variant selector, product card, ui kit
supabase/                      # migrations, seed, tests, edge function
test/                          # Dart unit + widget tests
web/                           # index.html (SEO meta + splash), manifest, icons
```

Platform-specific code (SEO meta injection, `localStorage`, `history`, the URL
strategy) sits behind conditional imports with non-web stubs, so nothing needs a
platform check at the call site and the whole app compiles to Wasm.

## Responsive breakpoints (PRD §6.2)

| Breakpoint | Width    | Product grid | Notable layout                     |
| ---------- | -------- | ------------ | ---------------------------------- |
| xs         | < 576    | 1 column     | Sticky bottom cart bar, hamburger  |
| sm         | ≥ 576    | 1 column     | Typography scales up               |
| md         | ≥ 768    | 2 columns    | Inline nav                         |
| lg         | ≥ 992    | 3 columns    | Split product page (7 / 5)         |
| xl / xxl   | ≥ 1200   | 4 columns    | Constrained max-width              |

---

_Demo checkout captures no payment. Wire a payment provider into the
`place_order` flow / an Edge Function before production use._
