# Vanguard Fashion — Enhancement Plan

**A route from working demo to shippable store.**

Audit date: 2026-08-22 · Against `claude/vercel-labs-find-skills-uuh7vb` @ `d41216e`

---

## How to read this

Every claim here was checked against the code or a running database — not inferred
from names or comments. Findings carry a `file:line` so you can disagree with the
evidence rather than the summary.

The document is in four parts, ordered by what would hurt most:

1. **[Defects](#part-1--defects)** — things that are wrong now, in code that ships.
2. **[The gap to complete](#part-2--the-gap-to-complete)** — what a store needs that
   this does not have.
3. **[Scale ceilings](#part-3--scale-ceilings)** — what breaks as the catalogue grows.
4. **[Engineering practice](#part-4--engineering-practice)** — what lets the above
   stay fixed.

Then a **[sequenced plan](#the-plan)** that puts them in a build order.

A note on the framing: this is a genuinely well-built demo. The variant model is
three levels deep and correct, the promotions engine agrees between client and
server to the cent, the checkout RPC is properly hardened, and the SQL has a real
behavioural suite. The gaps below are the gaps between *that* and a store that
takes money — not a critique of what is there.

---

## Current state — the honest baseline

Verified by running the toolchain, not by reading:

| | |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | 258 passing |
| SQL behavioural suite | 45 assertions |
| `schema.sql` ≡ `migrations/0001..0007` | 699 objects, zero drift |
| Dart → SQL RPC contract | 5/5 match `pg_proc` |
| Line coverage, files under test | **52.9%** (948/1792) |
| Line coverage, whole of `lib/` | **~10.5%** (948/9040) |
| `lib/` files never loaded by any test | **28 of 58** |
| Widget tests | 2 of 20 view files |
| CI | none — there is no `.github/` |

Those last five rows are the ones to sit with. The 52.9% figure is the one a
coverage badge would show, and it is measured only over the 30 files some test
happens to import. Against the whole of `lib/`, roughly one line in ten is
covered. Every storefront view, every admin view, `main.dart`, and the admin
route guard are never loaded by a test at all.

---

## Part 1 — Defects

Seven, ordered by blast radius. None are hypothetical; each names the line.

### 1.1 A failed catalogue fetch serves fake products to real customers

`lib/controllers/catalog_controller.dart:75` and `:153`

```dart
} catch (e) {
  error.value = 'Could not load products: $e';
  if (products.isEmpty) products.assignAll(DemoData.products());   // :75
}
...
product ??= DemoData.products().firstWhereOrNull((p) => p.slug == slug);  // :153
```

Demo mode exists so the UI is explorable without a backend. That is a good idea.
But the fallback is not gated on *being* in demo mode — it is gated on the fetch
having failed. In production, a transient Supabase outage silently replaces the
real catalogue with fixtures.

The shopper sees products that do not exist, at prices that are not real, and can
add them to a cart. Checkout then fails against SKUs the database has never heard
of. Line 153 is worse than 75: it has no `isEmpty` guard, so a single failed
product lookup substitutes a fixture unconditionally.

**Fix.** Gate every `DemoData` fallback on `!SupabaseService.isReady`, never on
failure. When a fetch fails against a configured backend, show the error state —
the `error` field is already set and already has UI. A store that is down should
look down.

### 1.2 A network blip silently demotes an admin to a customer

`lib/controllers/auth_controller.dart:60-62`

```dart
} catch (_) {
  user.value = AppUser(id: id, email: email ?? '');   // role defaults to customer
}
```

`_loadProfile` reads the row that carries `role`. If that read throws, it
constructs a user with the default role — `AppRole.customer`. Staff lose the admin
panel mid-session with no message, and `_StaffGuard` redirects them to the login
page they are already signed in to. The failure is invisible and looks like a
permissions bug.

**Fix.** Distinguish "profile says customer" from "could not read profile". On
failure, retry, or surface a session error, or preserve the last known role — but
do not manufacture an authoritative-looking downgrade from a caught exception.

### 1.3 Boot has no error boundary

`lib/main.dart:21`

```dart
await SupabaseService.init();   // no try/catch, before runApp()
```

`Supabase.initialize` can throw on a malformed URL or a network failure at start.
It is awaited before `runApp`, so the throw escapes `main` and the user gets a
blank page with nothing rendered and nothing logged.

There is also no `FlutterError.onError`, no `runZonedGuarded`, and no
`ErrorWidget.builder` anywhere in the project. No crash is reported, in
development or production.

**Fix.** Wrap `init()` so a failure degrades to a visible "cannot reach the store"
state rather than a white screen. Add a global error handler, and wire it to
something — Sentry, or at minimum a logged event.

### 1.4 Login rate limiting is decorative

`lib/controllers/auth_controller.dart:18-19, 66-90`

```dart
final Map<String, int> _loginAttempts = {};
final Map<String, DateTime> _lockouts = {};
```

Both maps are instance state on a controller in the browser tab. A page refresh
constructs a new `AuthController` and both are empty. An attacker refreshes, or
opens a new tab, or calls the Supabase endpoint directly without the app at all.

This is not a small weakness in a real control — there is no control. Worse, its
presence invites the belief that brute force is handled.

**Fix.** Either enforce it where it can be enforced — Supabase Auth rate limits,
or a `SECURITY DEFINER` function tracking attempts server-side — or remove it and
document that brute-force protection is delegated to Supabase. Keeping a
client-side counter is the one option that is worse than both.

### 1.5 The free-shipping bar measures against a different number than the total

`lib/views/storefront/cart_view.dart:176`

```dart
value: (cart.subtotal / Env.freeShippingThreshold).clamp(0, 1).toDouble(),
```

`Env.freeShippingThreshold` is the **compile-time** default. Every other consumer
reads the live value from `store_settings`:

```dart
subtotal >= StoreSettings.freeShippingThreshold.value       // cart_controller.dart:206
final remaining = StoreSettings.freeShippingThreshold.value - subtotal;   // :223
```

Change the threshold in the database and the progress bar contradicts the sentence
printed directly beneath it: the bar sits at 80% while the text says free shipping
is already unlocked.

This is the same defect that was fixed in `cart_controller` — the view was missed.
It is a good argument for the constant not being reachable from view code at all.

**Fix.** Read `StoreSettings.freeShippingThreshold.value`. Then consider making
`Env`'s commerce values private to `StoreSettings`, so this cannot recur.

### 1.6 The order-result parser can turn a successful order into "Checkout failed"

`lib/controllers/cart_controller.dart:343-346`

```dart
subtotal: (map['subtotal'] as num?)?.toDouble() ?? subtotal,
```

Every other model in the project parses defensively through `J.toDouble`,
specifically because `as num?` throws on a string-encoded numeric — that is why
`CartItem.fromJson` was changed. This site still casts.

Today it is latent: `place_order` returns `jsonb`, whose numerics decode as JSON
numbers, so the cast succeeds. But the failure mode if it ever does not is severe.
`_orderFromResult` is called inside `placeOrder`'s `try`, and the `catch` returns
`null`, which the checkout view renders as **"Checkout failed"** — *after the
server has already committed the order, decremented stock, and claimed the
promotion*. The shopper is told it failed and orders again.

**Fix.** Use `J.toDouble` for consistency with every other parser. Separately,
consider whether "the order committed but the client could not parse the receipt"
should ever present as failure — an order id is enough to show a confirmation.

### 1.7 Deprecation warnings are switched off

`analysis_options.yaml:9`

```yaml
deprecated_member_use: ignore
```

This is how the `pubspec` floor bug survived: the code used APIs whose predecessors
were deprecated, and the analyzer was told not to mention it. It hides exactly the
signal that tells you a dependency bump is coming.

**Fix.** Set it to `warning` and clear whatever it reports.

---

## Part 2 — The gap to complete

Ordered by what a merchant would notice first.

### 2.1 There is no payment

`lib/views/storefront/checkout_view.dart:136` — *"Demo checkout — no payment is captured."*

`place_order` writes an order at status `pending` and the flow ends. No
authorisation, no capture, no payment record. The schema has no `payments` table.

This is the single largest gap and everything else in this section is smaller than
it. A recommended shape, given the existing architecture:

- **Stripe Payment Intents** via a Supabase Edge Function — the project already has
  one (`supabase/functions/validate-promo`), so the pattern is established.
- `place_order` gains a `payment_intent_id` and stays at `pending`; a Stripe
  webhook (a second Edge Function) moves it to `paid`. The client never decides
  that an order was paid, exactly as it never decides what an order costs.
- A `payments` table recording intent id, amount, currency, status, and raw event
  — so a refund or a dispute has somewhere to live.
- Idempotency on the webhook. Stripe retries; the handler must be safe to run
  twice, in the same way `restock_order` already claims before crediting.

The existing hardening makes this tractable: totals are already computed
server-side, so the amount handed to Stripe can be read from the order row rather
than sent by the browser.

### 2.2 A merchant cannot put a photograph on a product

The admin CMS has no image input anywhere.

- `Product` has no image field at all (`lib/models/product_model.dart:7-18`).
- Images live on `VariantGroup.groupImages` (`lib/models/variant_model.dart:86`).
- The colour dialog that creates groups captures a name and a hex value, and
  nothing else (`lib/views/admin/product_manager_view.dart`, `_ColorGroupDialog`).
- `SupabaseService.storageUrl()` — the helper for serving from the products bucket
  — **has zero call sites.**

So a product created through the admin panel is permanently imageless. Every
product that does have imagery got it from seed data or demo fixtures.

**Fix.** An upload control in the colour-group editor, writing to the `products`
Storage bucket, with `storageUrl()` finally used to read them back. Storage RLS
needs the matching policy — staff write, public read — which does not currently
exist in the schema.

### 2.3 The `addresses` table is fully built and completely unused

`supabase/schema.sql` creates `public.addresses`, indexes it, and gives it RLS
policies. `AppConstants.tblAddresses` names it. **No Dart code reads or writes
it** — the constant is the only reference in the entire client.

Checkout makes every returning customer retype their full shipping address
(`checkout_view.dart:24-32`). The table to prevent that already exists.

**Fix.** Address book on the account page; a picker at checkout defaulting to the
last-used address. This is close to free — the schema and policies are done.

### 2.4 Account management is missing its middle

Present: sign in, sign up, sign out.

Absent:

- **Password reset.** No `resetPasswordForEmail` call anywhere. A customer who
  forgets their password has no route back into their account.
- **Email verification.** `signUp` treats a returned user as success
  (`auth_controller.dart:133`), but Supabase returns a user object with an
  unconfirmed email. The app signs them straight in, so the verification setting
  is effectively bypassed.
- **Profile editing.** `profiles_self_update` exists as an RLS policy and no
  client code uses it. A customer cannot change their own name or phone.
- **OAuth.** No social sign-in.
- **Account deletion.** No route, which is a GDPR/CCPA problem the moment there
  are EU or California customers.

### 2.5 Nothing records how an order got where it is

There is no `order_status_history` table and no audit log. `orders.status` is
overwritten in place (`admin_controller.dart:396-398`).

Nobody can answer who cancelled an order, when, or why. For a system that moves
money and inventory this is the record you most want during a dispute, and it is
the one thing that cannot be reconstructed after the fact.

**Fix.** An append-only `order_status_history (order_id, from_status, to_status,
actor, reason, created_at)` written by a trigger, so it cannot be bypassed by
whoever writes the update.

### 2.6 Stock is never reserved, only decremented

`place_order` decrements stock at the moment of purchase and does so correctly —
it locks rows, collapses duplicate lines, and refuses to oversell.

But nothing holds stock before that. Two shoppers can both have the last item in
their carts, both see "Only 1 left", and the second discovers at checkout that it
is gone. With a payment step added this gets worse: a shopper can complete payment
and *then* fail the stock check.

**Fix.** Once payment exists, reserve on payment-intent creation with a TTL, and
release on expiry. Before then, at minimum make the cart re-check availability at
the point of entering checkout, not only at submit.

### 2.7 Commerce features with no representation at all

No schema, no code, no UI:

| | Why it matters |
|---|---|
| **Tax** | Totals are `subtotal − discount + shipping`. No jurisdiction can be billed correctly. |
| **Shipping methods** | One flat fee. No express option, no carrier, no rate by weight or destination. |
| **Returns / RMA** | `refunded` is a status with no process behind it. |
| **Reviews & ratings** | Standard for apparel; absent. |
| **Transactional email** | No order confirmation, no shipping notice. The confirmation page is the only receipt, and it is gone on refresh. |
| **Search beyond substring** | See [3.2](#32-search-is-a-substring-scan-over-memory). |
| **Multi-currency** | `Formatters` hardcodes `en_US` and `$` (`formatters.dart:5-6`). |

### 2.8 Two sources of truth for categories

`Categories.all` is a hardcoded list of five (`app_constants.dart:32-43`), used
only by the promotion builder (`promotion_builder_view.dart:380`). The catalogue
derives categories dynamically from live products
(`catalog_controller.dart:38-48`).

So a promotion can target `Accessories` when no product has that category, and
*cannot* target a category a merchant invents. The promo silently discounts
nothing.

**Fix.** Feed the builder from `CatalogController.availableCategories`, or
promote categories to a table with a foreign key.

---

## Part 3 — Scale ceilings

### 3.1 The whole catalogue loads into memory on every visit

`lib/controllers/catalog_controller.dart:59-63`

```dart
.from(AppConstants.tblProducts)
.select('*, variant_groups(*, variant_items(*))')
.eq('is_active', true)
.order('created_at');
```

No `limit`, no `range`, no pagination. Every product, every colour group, and
every SKU, on every page load, held in a single `RxList`.

At the demo's ~6 products this is invisible. At 500 products with 4 colours and 6
sizes each it is 12,000 nested rows over the wire before the homepage paints.

**Fix.** Server-side pagination with `.range()`, and a summary projection for the
grid — the listing needs a title, a price range, and one image, not the full
variant tree. Fetch the tree on the product page only.

### 3.2 Search is a substring scan over memory

`lib/controllers/catalog_controller.dart:84-105` — `visibleProducts` filters with
`String.contains` over the in-memory list, re-running on every keystroke.

It cannot match a misspelling, cannot rank by relevance, and cannot search
anything that was not already downloaded. Combined with 3.1, search quality is
capped by however much of the catalogue fits in a browser tab.

**Fix.** Postgres full-text search — a `tsvector` column, a GIN index, an RPC that
takes the query. `pg_trgm` for typo tolerance. Both are already available in
Supabase.

### 3.3 Known and bounded

Worth stating so they are not rediscovered as bugs: admin orders are paged at the
most recent 100, which `admin_stats()` deliberately compensates for by aggregating
server-side. That one is handled correctly.

---

## Part 4 — Engineering practice

### 4.1 There is no CI

No `.github/` directory exists. Nothing runs on push. Every check in the baseline
table at the top of this document was run by hand.

This is the highest-leverage item in the document, because it is what keeps
everything else from regressing. The commands already exist and already exit
non-zero:

```yaml
- flutter analyze
- flutter test --coverage
- supabase/tests/20_contract.sh     # needs a postgres service container
```

That third one is worth the setup. It verifies what no compiler can: that
`schema.sql` and the migrations still agree, and that every RPC the Dart calls
exists with the parameter names the Dart sends. The client/database boundary is a
bare string (`rpcPlaceOrder = 'place_order'`), invisible to every static tool
including this repo's own knowledge graph — a renamed parameter compiles cleanly
and fails in production checkout. That is precisely the bug this branch was opened
to fix.

Also missing: a PR template, issue templates, and Dependabot.

### 4.2 The view layer is effectively untested

18 of 20 view files have no widget test. Untested: checkout, cart, product detail,
login, account, wishlist, and the entire admin panel.

`app_pages.dart` is never loaded by a test, which means **`_StaffGuard` — the
authorisation boundary on every admin route — has no test at all.** A refactor
that inverted its condition would pass the whole suite.

**Priority order for widget tests:** `_StaffGuard` first (it is a security
control), then checkout (it is the money path), then the product-detail variant
flow (it is the most intricate UI in the project).

### 4.3 Two parallel test trees

`test/admin_controller_test.dart` and `test/controllers/admin_controller_test.dart`
both exist. So do `test/cart_controller_test.dart` and
`test/controllers/cart_controller_test.dart`. Four files, two names.

The nested layout mirrors `lib/`; the flat one does not. Pick the nested one and
merge. Until then, "is it tested?" has no reliable answer, because the answer is
in whichever of the two files you did not open.

### 4.4 No accessibility work has been done

Zero `Semantics` widgets. Zero `semanticLabel` attributes. Nine tooltips across
9,040 lines.

Product images have no alternative text. The variant selector — colour swatches
distinguished only by hex value — is unusable with a screen reader and
indistinguishable to a colour-blind shopper without the name being read out.

For a retail site this is both an exclusion and, in many jurisdictions, a legal
exposure.

**Fix.** `semanticLabel` on every product image; `Semantics` around the swatches
naming the colour; a focus-order pass over checkout; contrast audit of
`AppColors`.

### 4.5 No internationalisation

`GetMaterialApp` declares no `translations`, `locale`, or `localizationsDelegates`
(`main.dart:37-50`). Every string is inline English. `Formatters` hardcodes
`en_US` and `$`.

The app is single-locale by construction. If that is intentional, say so in the
README; if not, retrofitting after another 9,000 lines will cost several times
what it costs now.

### 4.6 Dependencies are drifting

| Package | Current | Latest |
|---|---|---|
| `google_fonts` | 6.3.3 | **8.2.1** |
| `flutter_lints` | 4.0.0 | **6.0.0** |
| `intl` | 0.19.0 | 0.20.3 |
| `supabase_flutter` | 2.16.0 | 2.17.2 |

Two major versions behind on two packages. `flutter_lints` 6 would bring new rules
worth having — and with `deprecated_member_use` re-enabled ([1.7](#17-deprecation-warnings-are-switched-off))
the upgrade path becomes visible rather than silent.

### 4.7 Declared assets are empty

`pubspec.yaml` declares `assets/images/` and `assets/icons/`; both contain only a
`.gitkeep`. Harmless today, but it means there is no local placeholder, no brand
mark, and no offline fallback for a failed image load — the app depends entirely
on remote imagery that, per [2.2](#22-a-merchant-cannot-put-a-photograph-on-a-product),
a merchant cannot even set.

---

## The plan

Sequenced so each phase makes the next one safe, rather than by size.

### Phase 0 — Make regressions visible *(days)*

CI first, before any feature work. Everything after this is safer because of it.

1. GitHub Actions: `analyze`, `test --coverage`, `20_contract.sh` against a
   postgres service container.
2. Re-enable `deprecated_member_use`; clear the fallout.
3. Merge the duplicate test trees.
4. Coverage reporting, with a floor that ratchets rather than a target that is
   declared.

### Phase 1 — Fix what is wrong *(1 week)*

All of [Part 1](#part-1--defects). Each is small; several are one line. Take them
in this order — user-visible incorrectness first, then invisible fragility:

1.1 demo fallback → 1.2 role demotion → 1.5 shipping bar → 1.6 order parser →
1.3 error boundary → 1.4 rate limiting → 1.7 lints.

Add a widget test for `_StaffGuard` here rather than in Phase 4 — it is a security
control and it is currently untested.

### Phase 2 — Take money *(3–4 weeks)*

[2.1](#21-there-is-no-payment), and what it drags in:

1. `payments` table, `orders.payment_intent_id`, RLS.
2. Edge Function creating the intent from the **server-computed** order total.
3. Webhook function, idempotent, moving `pending → paid`.
4. Checkout UI: payment element, pending state, failure handling.
5. `order_status_history` ([2.5](#25-nothing-records-how-an-order-got-where-it-is)) —
   land it with payment, while the transitions are being written anyway.
6. Stock reservation ([2.6](#26-stock-is-never-reserved-only-decremented)) — a
   payment step makes this urgent rather than theoretical.

Extend `10_tests.sql` alongside, so the payment path gets the same behavioural
coverage the checkout path already has.

### Phase 3 — Make it operable by a merchant *(2–3 weeks)*

1. Image upload ([2.2](#22-a-merchant-cannot-put-a-photograph-on-a-product)) —
   without this the admin cannot publish a sellable product.
2. Address book ([2.3](#23-the-addresses-table-is-fully-built-and-completely-unused)) —
   the schema is already there.
3. Password reset, email verification, profile editing
   ([2.4](#24-account-management-is-missing-its-middle)).
4. Transactional email: order confirmation and shipping notice.
5. Categories from one source ([2.8](#28-two-sources-of-truth-for-categories)).

### Phase 4 — Earn the confidence *(2 weeks, overlappable)*

1. Widget tests: checkout, cart, product detail, admin CRUD
   ([4.2](#42-the-view-layer-is-effectively-untested)).
2. Accessibility pass ([4.4](#44-no-accessibility-work-has-been-done)).
3. Dependency upgrades ([4.6](#46-dependencies-are-drifting)).
4. An end-to-end test through the real browser — Playwright is available in this
   environment — covering browse → variant → cart → checkout.

### Phase 5 — Scale *(when the catalogue justifies it)*

Do not do this early. At the current catalogue size it is unnecessary work, and
the shape of the right answer depends on how the catalogue actually grows.

1. Pagination and a listing projection
   ([3.1](#31-the-whole-catalogue-loads-into-memory-on-every-visit)).
2. Postgres FTS with `pg_trgm`
   ([3.2](#32-search-is-a-substring-scan-over-memory)).
3. i18n and multi-currency ([4.5](#45-no-internationalisation)), if the market
   calls for it.

---

## Two things to decide before Phase 2

Both are product decisions, not engineering ones, and both change what gets built:

**Is demo mode a shipping feature or a development convenience?** It currently
reaches production code paths ([1.1](#11-a-failed-catalogue-fetch-serves-fake-products-to-real-customers)).
If it is a dev convenience, it should be compiled out of release builds entirely,
which makes that defect structurally impossible rather than fixed. If it is a
shipping feature — a public sandbox — it needs to be labelled as such in the UI.

**Which jurisdictions?** Tax, and to a large extent i18n and account deletion,
depend entirely on the answer. Building tax generically before knowing is how that
work gets done twice.

---

## Verifying any of this

```bash
# Dart
flutter analyze
flutter test --coverage

# Database: provisioning, schema/migration equivalence,
# the Dart↔SQL RPC contract, and the behavioural suite — one command
./supabase/tests/20_contract.sh

# Coverage by area
python3 - <<'PY'
import collections
area = collections.defaultdict(lambda: [0, 0])
cur = None
for line in open('coverage/lcov.info'):
    line = line.strip()
    if line.startswith('SF:'):
        cur = line[3:]
    elif line[:3] in ('LF:', 'LH:'):
        a = next((x for x in ('views', 'controllers', 'models', 'core') if x in cur), 'other')
        area[a][line[:3] == 'LF:'] += int(line[3:])
for a, (hit, found) in sorted(area.items()):
    print(f'{a:<14} {hit:>5}/{found:<5} {100*hit/found if found else 0:5.1f}%')
PY
```

The contract script is the one worth knowing about. It checks the things reading
the code cannot tell you — and both of its diffing arms were negative-tested, so a
green result means something.
