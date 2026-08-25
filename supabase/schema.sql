-- ============================================================================
-- Vanguard Fashion — consolidated schema
--
-- One file that provisions a database from empty to production-ready. This is
-- the FINAL state, not a replay of history: where a later migration replaced an
-- earlier definition, only the surviving one appears here, and the columns that
-- 0004 added with ALTER TABLE are folded into the CREATE TABLE that introduces
-- them. Nothing is defined twice.
--
--   psql -v ON_ERROR_STOP=1 -f supabase/schema.sql
--   -- or paste into the Supabase SQL editor
--
-- Idempotent: every statement is CREATE IF NOT EXISTS / CREATE OR REPLACE /
-- DROP POLICY IF EXISTS, so re-running is safe.
--
-- Provenance: 0001_init_schema, 0002_functions, 0003_rls, 0004_hardening,
-- 0005_integrity, 0006_rls_performance, 0007_write_paths,
-- 0008_profile_update_least_privilege, 0009_rpc_input_hardening.
-- The numbered migrations remain the upgrade path for databases already
-- deployed; this file is the source of truth for a fresh install.
--
-- Contents
--   1. Extensions and enums
--   2. Tables and indexes
--   3. Triggers
--   4. Role helpers
--   5. Pricing, promotions, checkout
--   6. Back-office RPCs
--   7. Row-Level Security
--   8. Execute grants
--   9. Public RPC input hardening and function search paths
-- ============================================================================

\set ON_ERROR_STOP on

-- ============================================================================
-- 1. Extensions and enums
-- ============================================================================

create extension if not exists "pgcrypto";     -- gen_random_uuid()
create extension if not exists "citext";       -- case-insensitive promo codes

do $$
begin
  if not exists (select 1 from pg_type where typname = 'discount_type') then
    create type discount_type as enum ('percentage', 'fixed_amount', 'free_shipping');
  end if;
  if not exists (select 1 from pg_type where typname = 'order_status') then
    create type order_status as enum
      ('pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded');
  end if;
  if not exists (select 1 from pg_type where typname = 'app_role') then
    create type app_role as enum
      ('customer', 'catalog_manager', 'marketing_manager', 'fulfillment', 'admin');
  end if;
end$$;

-- ============================================================================
-- 2. Tables and indexes
--
-- Product → Variant_Group (colour) → Variant_Item (size / final SKU). SKU,
-- price override and stock all live at the deepest level, so checkout can
-- decrement the exact unit that was sold (PRD §5).
-- ============================================================================

-- 5.1 products — parent container
create table if not exists public.products (
  id           uuid primary key default gen_random_uuid(),
  slug         text unique not null,
  title        text not null,
  description  text,
  category     text,
  base_price   numeric(10, 2) not null default 0 check (base_price >= 0),
  is_active    boolean not null default true,
  is_featured  boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists products_active_idx    on public.products (is_active);
create index if not exists products_category_idx  on public.products (category);
create index if not exists products_featured_idx  on public.products (is_featured) where is_featured;

-- 5.2 variant_groups — Level 1 (colour). Holds the colour's imagery.
create table if not exists public.variant_groups (
  id            uuid primary key default gen_random_uuid(),
  product_id    uuid not null references public.products (id) on delete cascade,
  name          text not null,                 -- e.g. "Midnight Blue"
  color_hex     text check (color_hex ~* '^#[0-9a-f]{6}$'),
  group_images  text[] not null default '{}',  -- Supabase Storage .webp URLs
  sort_order    integer not null default 0,
  created_at    timestamptz not null default now()
);
create index if not exists variant_groups_product_idx on public.variant_groups (product_id);

-- 5.3 variant_items — Level 2 (size / final SKU). The purchasable unit.
create table if not exists public.variant_items (
  id                  uuid primary key default gen_random_uuid(),
  group_id            uuid not null references public.variant_groups (id) on delete cascade,
  sku                 text unique not null,
  size_label          text not null,
  price_override      numeric(10, 2) check (price_override >= 0),
  stock_quantity      integer not null default 0 check (stock_quantity >= 0),
  low_stock_threshold integer not null default 5,
  sort_order          integer not null default 0,
  created_at          timestamptz not null default now(),
  constraint variant_items_low_stock_threshold_check
    check (low_stock_threshold >= 0)
);
create index if not exists variant_items_group_idx on public.variant_items (group_id);
create index if not exists variant_items_low_stock_idx
  on public.variant_items (stock_quantity)
  where stock_quantity <= low_stock_threshold;

-- 5.4 promotions — the discount rules engine
create table if not exists public.promotions (
  id                  uuid primary key default gen_random_uuid(),
  code                citext unique not null,
  description         text,
  discount_type       discount_type not null,
  discount_value      numeric(10, 2) not null default 0 check (discount_value >= 0),
  min_order_value     numeric(10, 2) not null default 0 check (min_order_value >= 0),
  usage_limit         integer,                     -- null = unlimited
  usage_count         integer not null default 0,
  is_active           boolean not null default true,
  included_categories text[] not null default '{}',
  excluded_categories text[] not null default '{}',
  valid_from          timestamptz not null default now(),
  valid_until         timestamptz,
  created_at          timestamptz not null default now(),
  -- A mis-keyed percentage must not be able to discount more than the basket.
  constraint promotions_percentage_range
    check (discount_type <> 'percentage' or discount_value <= 100),
  constraint promotions_window_ordered
    check (valid_until is null or valid_until > valid_from),
  constraint promotions_usage_count_non_negative
    check (usage_count >= 0)
);
-- Codes are looked up through the unique constraint on `code`; this partial
-- index serves the back-office listing of what is currently live.
create index if not exists promotions_live_idx
  on public.promotions (valid_until) where is_active;

-- store_settings — the authoritative source for shipping figures. A single row,
-- enforced by a boolean primary key that can only ever be true. place_order
-- reads its shipping charge from here; the client never supplies one.
create table if not exists public.store_settings (
  id                      boolean primary key default true check (id),
  flat_shipping_fee       numeric(10, 2) not null default 12.00
                            check (flat_shipping_fee >= 0),
  free_shipping_threshold numeric(10, 2) not null default 150.00
                            check (free_shipping_threshold >= 0),
  updated_at              timestamptz not null default now()
);
insert into public.store_settings (id) values (true) on conflict (id) do nothing;

-- profiles — mirrors auth.users, carries role + storefront profile data
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  email        text,
  full_name    text,
  role         app_role not null default 'customer',
  phone        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table if not exists public.addresses (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles (id) on delete cascade,
  label        text,
  line1        text not null,
  line2        text,
  city         text not null,
  region       text,
  postal_code  text,
  country      text not null default 'US',
  is_default   boolean not null default false,
  created_at   timestamptz not null default now()
);
create index if not exists addresses_user_idx on public.addresses (user_id);

create table if not exists public.wishlists (
  user_id      uuid not null references public.profiles (id) on delete cascade,
  product_id   uuid not null references public.products (id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (user_id, product_id)
);
create index if not exists wishlists_product_idx on public.wishlists (product_id);

-- orders + order_items. `restocked_at` makes returning stock idempotent;
-- `order_items.category` snapshots the category so revenue reporting survives a
-- product being re-categorised, renamed, or deleted.
create table if not exists public.orders (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid references public.profiles (id) on delete set null,
  status           order_status not null default 'pending',
  subtotal         numeric(10, 2) not null default 0,
  discount_total   numeric(10, 2) not null default 0,
  shipping_total   numeric(10, 2) not null default 0,
  grand_total      numeric(10, 2) not null default 0,
  promotion_id     uuid references public.promotions (id) on delete set null,
  promo_code       text,
  shipping_address jsonb,
  contact_email    text,
  tracking_number  text,
  restocked_at     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint orders_money_non_negative
    check (subtotal >= 0 and discount_total >= 0
           and shipping_total >= 0 and grand_total >= 0),
  constraint orders_discount_within_subtotal
    check (discount_total <= subtotal),
  -- The accounting identity itself. Without it the three parts and the total
  -- can each be individually plausible and still disagree with one another.
  constraint orders_totals_consistent
    check (grand_total = subtotal - discount_total + shipping_total)
);
create index if not exists orders_user_idx    on public.orders (user_id);
create index if not exists orders_status_idx  on public.orders (status);
create index if not exists orders_created_idx on public.orders (created_at desc);
create index if not exists orders_promotion_idx on public.orders (promotion_id);

create table if not exists public.order_items (
  id              uuid primary key default gen_random_uuid(),
  order_id        uuid not null references public.orders (id) on delete cascade,
  variant_item_id uuid references public.variant_items (id) on delete set null,
  -- Denormalised snapshot so historical orders survive catalog edits/deletes.
  product_title   text not null,
  variant_name    text,
  size_label      text,
  sku             text not null,
  category        text,
  unit_price      numeric(10, 2) not null,
  quantity        integer not null check (quantity > 0),
  line_total      numeric(10, 2) not null
);
create index if not exists order_items_order_idx    on public.order_items (order_id);
-- Postgres indexes the referenced side of a foreign key automatically; the
-- referencing side is ours, and it is the side a cascade or SET NULL searches.
create index if not exists order_items_variant_item_idx on public.order_items (variant_item_id);
create index if not exists order_items_category_idx on public.order_items (category);

-- Upgrade path: these are no-ops on a fresh install, and add the columns when
-- this file is run against a database created before 0004.
alter table public.orders      add column if not exists restocked_at timestamptz;
alter table public.order_items add column if not exists category text;

-- ============================================================================
-- 3. Triggers
-- ============================================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_products_updated  on public.products;
create trigger trg_products_updated  before update on public.products
  for each row execute function public.set_updated_at();

drop trigger if exists trg_profiles_updated  on public.profiles;
create trigger trg_profiles_updated  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_orders_updated  on public.orders;
create trigger trg_orders_updated  before update on public.orders
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Auto-provision a profile row whenever a new auth user signs up.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = pg_catalog, public, extensions, pg_temp
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- store_settings keeps its own updated_at current too.
drop trigger if exists trg_store_settings_updated on public.store_settings;
create trigger trg_store_settings_updated before update on public.store_settings
  for each row execute function public.set_updated_at();

-- ============================================================================
-- 4. Role helpers
--
-- SECURITY DEFINER so RLS can call them without recursing into the policies
-- that guard public.profiles.
-- ============================================================================
-- Role helper used by RLS policies (0003). SECURITY DEFINER so it can read the
-- caller's profile row without recursive RLS evaluation.
create or replace function public.current_app_role()
returns app_role
language sql
stable
security definer set search_path = pg_catalog, public, extensions, pg_temp
as $$
  select coalesce(
    (select role from public.profiles where id = auth.uid()),
    'customer'::app_role
  );
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer set search_path = pg_catalog, public, extensions, pg_temp
as $$
  select public.current_app_role() in
    ('catalog_manager', 'marketing_manager', 'fulfillment', 'admin');
$$;

-- Effective unit price for a variant item: price_override, else parent base_price.
create or replace function public.variant_unit_price(p_variant_item_id uuid)
returns numeric
language sql
stable
as $$
  select coalesce(vi.price_override, p.base_price)
  from public.variant_items vi
  join public.variant_groups vg on vg.id = vi.group_id
  join public.products p        on p.id  = vg.product_id
  where vi.id = p_variant_item_id;
$$;

-- ============================================================================
-- 5. Pricing, promotions, checkout
-- ============================================================================
-- ---------------------------------------------------------------------------
-- validate_promotion(code, lines)
--
-- `p_lines` is a jsonb array of { category, line_total } — one entry per cart
-- line. Per-line data is required because the discount base is the *eligible*
-- lines, not the whole cart.
--
-- SECURITY DEFINER so it can still resolve codes now that direct reads of
-- `promotions` are staff-only; it deliberately returns nothing about a code
-- beyond whether it applies to the supplied basket.
-- ---------------------------------------------------------------------------
-- Both prior signatures are dropped first: `create function` would otherwise add
-- an overload alongside an older definition rather than replace it, leaving two
-- callable versions of the same RPC. Harmless on a fresh database.
drop function if exists public.validate_promotion(text, numeric, text[]);
drop function if exists public.validate_promotion(text, jsonb);

create function public.validate_promotion(
  p_code  text,
  p_lines jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, extensions, pg_temp
as $$
declare
  promo           public.promotions%rowtype;
  v_lines         jsonb := coalesce(p_lines, '[]'::jsonb);
  v_subtotal      numeric := 0;
  v_eligible      numeric := 0;
  v_discount      numeric := 0;
  v_free_shipping boolean := false;
  v_excluded_hit  boolean := false;
begin
  if p_code is null or btrim(p_code) = '' then
    return jsonb_build_object('valid', false, 'reason', 'Enter a promo code');
  end if;

  if length(btrim(p_code)) > 100 then
    return jsonb_build_object('valid', false, 'reason', 'Promo code is too long');
  end if;

  if p_lines is null or jsonb_typeof(v_lines) <> 'array' then
    return jsonb_build_object('valid', false, 'reason', 'Invalid promotion basket');
  end if;

  if jsonb_array_length(v_lines) > 100 then
    return jsonb_build_object('valid', false, 'reason', 'Promotion basket is too large');
  end if;

  if exists (
    select 1
      from jsonb_array_elements(v_lines) l
     where jsonb_typeof(l) <> 'object'
        or not (l ? 'line_total')
        or (l ->> 'line_total') !~ '^(0|[1-9][0-9]{0,7})(\.[0-9]{1,2})?$'
  ) then
    return jsonb_build_object('valid', false, 'reason', 'Invalid promotion basket');
  end if;

  select * into promo
    from public.promotions
   where code = btrim(p_code)::citext
     and is_active = true;

  if not found then
    return jsonb_build_object('valid', false, 'reason', 'Code not found');
  end if;

  if now() < promo.valid_from then
    return jsonb_build_object('valid', false, 'reason', 'Promotion not yet active');
  end if;

  if promo.valid_until is not null and now() > promo.valid_until then
    return jsonb_build_object('valid', false, 'reason', 'Promotion expired');
  end if;

  if promo.usage_limit is not null and promo.usage_count >= promo.usage_limit then
    return jsonb_build_object('valid', false, 'reason', 'Usage limit reached');
  end if;

  select coalesce(sum((l ->> 'line_total')::numeric), 0)
    into v_subtotal
    from jsonb_array_elements(v_lines) l;

  -- The minimum-order rule is judged on the whole basket, as shoppers expect.
  if v_subtotal < promo.min_order_value then
    return jsonb_build_object(
      'valid', false,
      'reason', format('Requires a minimum order of $%s',
                       trim(to_char(promo.min_order_value, 'FM999999990.00')))
    );
  end if;

  -- Excluded categories disqualify the promotion outright.
  if array_length(promo.excluded_categories, 1) is not null then
    select exists (
      select 1 from jsonb_array_elements(v_lines) l
       where l ->> 'category' = any (promo.excluded_categories)
    ) into v_excluded_hit;

    if v_excluded_hit then
      return jsonb_build_object('valid', false, 'reason', 'Cart contains excluded items');
    end if;
  end if;

  -- Discount base: the targeted lines only when the promotion is restricted.
  if array_length(promo.included_categories, 1) is null then
    v_eligible := v_subtotal;
  else
    select coalesce(sum((l ->> 'line_total')::numeric), 0)
      into v_eligible
      from jsonb_array_elements(v_lines) l
     where l ->> 'category' = any (promo.included_categories);

    if v_eligible <= 0 then
      return jsonb_build_object('valid', false, 'reason', 'No eligible items in cart');
    end if;
  end if;

  case promo.discount_type
    when 'percentage' then
      -- Clamped: a mis-keyed percentage above 100 must never discount more
      -- than the lines it applies to.
      v_discount := least(round(v_eligible * (promo.discount_value / 100.0), 2),
                          v_eligible);
    when 'fixed_amount' then
      v_discount := round(least(promo.discount_value, v_eligible), 2);
    when 'free_shipping' then
      v_free_shipping := true;
  end case;

  return jsonb_build_object(
    'valid', true,
    'promotion_id', promo.id,
    'code', promo.code,
    'discount_type', promo.discount_type,
    'discount_amount', v_discount,
    'eligible_subtotal', v_eligible,
    'free_shipping', v_free_shipping,
    'description', promo.description
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- place_order(items, promo_code, shipping_address, contact_email)
--
-- Atomic checkout. `p_items` = jsonb array of { variant_item_id, quantity }.
-- Every price, the discount, and the shipping charge are recomputed here; the
-- client supplies quantities and nothing else that touches money.
-- ---------------------------------------------------------------------------
-- As above: drop the pre-0004 five-argument form (which took a client-supplied
-- shipping figure) so it cannot linger as a callable overload.
drop function if exists public.place_order(jsonb, text, jsonb, text, numeric);
drop function if exists public.place_order(jsonb, text, jsonb, text);

create function public.place_order(
  p_items            jsonb,
  p_promo_code       text default null,
  p_shipping_address jsonb default null,
  p_contact_email    text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions, pg_temp
as $$
declare
  v_order_id  uuid := gen_random_uuid();
  v_row       record;
  vi          public.variant_items%rowtype;
  v_settings  public.store_settings%rowtype;
  v_title     text;
  v_category  text;
  v_group     text;
  v_unit      numeric;
  v_line      numeric;
  v_subtotal  numeric := 0;
  v_lines     jsonb := '[]'::jsonb;
  v_promo     jsonb;
  v_promo_id  uuid;
  v_discount  numeric := 0;
  v_shipping  numeric := 0;
  v_free_ship boolean := false;
  v_grand     numeric;
  v_claimed   integer;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Order items must be a JSON array';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'Cannot place an empty order';
  end if;

  if jsonb_array_length(p_items) > 100 then
    raise exception 'Order contains too many line items';
  end if;

  if exists (
    select 1
      from jsonb_array_elements(p_items) item
     where jsonb_typeof(item) <> 'object'
        or not (item ? 'variant_item_id')
        or (item ->> 'variant_item_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
        or not (item ? 'quantity')
        or (item ->> 'quantity') !~ '^([1-9][0-9]{0,2}|1000)$'
  ) then
    raise exception 'Invalid order items';
  end if;

  if p_contact_email is not null and length(p_contact_email) > 320 then
    raise exception 'Contact email is too long';
  end if;

  if p_shipping_address is not null
     and (jsonb_typeof(p_shipping_address) <> 'object'
          or pg_column_size(p_shipping_address) > 16384) then
    raise exception 'Invalid shipping address';
  end if;

  select * into v_settings from public.store_settings limit 1;

  insert into public.orders (id, user_id, status, contact_email, shipping_address)
  values (v_order_id, auth.uid(), 'pending', p_contact_email, p_shipping_address);

  -- Duplicate lines for one SKU are collapsed (two lines of 5 against 6 in
  -- stock would otherwise pass two independent checks), and rows are locked in
  -- id order so concurrent checkouts queue rather than deadlock.
  for v_row in
    select (l ->> 'variant_item_id')::uuid as variant_item_id,
           sum((l ->> 'quantity')::integer) as quantity
      from jsonb_array_elements(p_items) l
     group by 1
     order by 1
  loop
    if v_row.variant_item_id is null then
      raise exception 'Order line is missing a variant';
    end if;
    if v_row.quantity is null or v_row.quantity <= 0 then
      raise exception 'Invalid quantity for variant %', v_row.variant_item_id;
    end if;

    select * into vi
      from public.variant_items
     where id = v_row.variant_item_id
     for update;

    if not found then
      raise exception 'Variant % no longer exists', v_row.variant_item_id;
    end if;

    if vi.stock_quantity < v_row.quantity then
      raise exception 'Insufficient stock for SKU % (have %, need %)',
        vi.sku, vi.stock_quantity, v_row.quantity;
    end if;

    select p.title, p.category, vg.name, coalesce(vi.price_override, p.base_price)
      into v_title, v_category, v_group, v_unit
      from public.variant_groups vg
      join public.products p on p.id = vg.product_id
     where vg.id = vi.group_id;

    v_line := round(v_unit * v_row.quantity, 2);
    v_subtotal := v_subtotal + v_line;
    v_lines := v_lines || jsonb_build_object('category', v_category, 'line_total', v_line);

    update public.variant_items
       set stock_quantity = stock_quantity - v_row.quantity
     where id = vi.id;

    insert into public.order_items
      (order_id, variant_item_id, product_title, variant_name, size_label,
       sku, unit_price, quantity, line_total, category)
    values
      (v_order_id, vi.id, v_title, v_group, vi.size_label,
       vi.sku, v_unit, v_row.quantity, v_line, v_category);
  end loop;

  -- Apply the promotion against server-computed line totals.
  if p_promo_code is not null and length(btrim(p_promo_code)) > 0 then
    v_promo := public.validate_promotion(p_promo_code, v_lines);

    if coalesce((v_promo ->> 'valid')::boolean, false) then
      v_promo_id  := (v_promo ->> 'promotion_id')::uuid;
      v_discount  := coalesce((v_promo ->> 'discount_amount')::numeric, 0);
      v_free_ship := coalesce((v_promo ->> 'free_shipping')::boolean, false);

      -- Claim a use conditionally: the WHERE guard is what actually enforces
      -- the limit under concurrency, since validation above only observed it.
      update public.promotions
         set usage_count = usage_count + 1
       where id = v_promo_id
         and (usage_limit is null or usage_count < usage_limit);

      get diagnostics v_claimed = row_count;
      if v_claimed = 0 then
        raise exception 'Promotion rejected: Usage limit reached';
      end if;
    else
      raise exception 'Promotion rejected: %', (v_promo ->> 'reason');
    end if;
  end if;

  -- Shipping is ours to decide, never the caller's.
  if v_free_ship
     or v_subtotal >= coalesce(v_settings.free_shipping_threshold, 150) then
    v_shipping := 0;
  else
    v_shipping := coalesce(v_settings.flat_shipping_fee, 12);
  end if;

  -- The discount can never exceed what was actually bought, so the total can
  -- never fall below the shipping charge. The CHECK constraints on orders are
  -- the backstop; this is the first line of defence.
  v_discount := least(v_discount, v_subtotal);
  v_grand    := round(v_subtotal - v_discount + v_shipping, 2);

  update public.orders set
    subtotal       = v_subtotal,
    discount_total = v_discount,
    shipping_total = v_shipping,
    grand_total    = v_grand,
    promotion_id   = v_promo_id,
    promo_code     = case when v_promo_id is null then null else p_promo_code end,
    status         = 'pending'
  where id = v_order_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'status', 'pending',
    'subtotal', v_subtotal,
    'discount_total', v_discount,
    'shipping_total', v_shipping,
    'grand_total', v_grand
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- restock_order — return an order's stock to the shelf, at most once.
-- ---------------------------------------------------------------------------
create or replace function public.restock_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, extensions, pg_temp
as $$
declare
  v_claimed integer;
begin
  if not public.is_staff() then
    raise exception 'Not authorised';
  end if;

  -- Claim the restock first. A second call (cancelled → refunded, a double
  -- click, a retry) finds nothing to claim and returns without crediting again.
  update public.orders
     set restocked_at = now()
   where id = p_order_id
     and restocked_at is null;

  get diagnostics v_claimed = row_count;
  if v_claimed = 0 then
    return;
  end if;

  -- Aggregated so an order carrying two lines for the same SKU (possible for
  -- rows written before 0004) credits both, not just one.
  update public.variant_items vi
     set stock_quantity = vi.stock_quantity + agg.qty
    from (
      select variant_item_id, sum(quantity) as qty
        from public.order_items
       where order_id = p_order_id
         and variant_item_id is not null
       group by variant_item_id
    ) agg
   where agg.variant_item_id = vi.id;
end;
$$;

-- ============================================================================
-- 6. Back-office RPCs
-- ============================================================================
-- ---------------------------------------------------------------------------
-- save_product — upsert a product together with its colour groups and SKUs.
--
-- A plain table upsert from the back-office silently dropped the whole variant
-- tree, because the product row carries none of it.
-- ---------------------------------------------------------------------------
create or replace function public.save_product(p_product jsonb)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions, pg_temp
as $$
declare
  v_product_id uuid;
  v_group      jsonb;
  v_item       jsonb;
  v_group_id   uuid;
  v_item_id    uuid;
  v_group_ids  uuid[] := '{}';
  v_item_ids   uuid[] := '{}';
begin
  if not public.is_staff() then
    raise exception 'Not authorised';
  end if;

  if coalesce(btrim(p_product ->> 'slug'), '') = '' then
    raise exception 'A product needs a slug';
  end if;

  v_product_id := coalesce(nullif(p_product ->> 'id', '')::uuid, gen_random_uuid());

  insert into public.products
    (id, slug, title, description, category, base_price, is_active, is_featured)
  values (
    v_product_id,
    p_product ->> 'slug',
    coalesce(p_product ->> 'title', ''),
    nullif(p_product ->> 'description', ''),
    nullif(p_product ->> 'category', ''),
    coalesce((p_product ->> 'base_price')::numeric, 0),
    coalesce((p_product ->> 'is_active')::boolean, true),
    coalesce((p_product ->> 'is_featured')::boolean, false)
  )
  on conflict (id) do update set
    slug        = excluded.slug,
    title       = excluded.title,
    description = excluded.description,
    category    = excluded.category,
    base_price  = excluded.base_price,
    is_active   = excluded.is_active,
    is_featured = excluded.is_featured;

  for v_group in
    select * from jsonb_array_elements(coalesce(p_product -> 'groups', '[]'::jsonb))
  loop
    v_group_id  := coalesce(nullif(v_group ->> 'id', '')::uuid, gen_random_uuid());
    v_group_ids := array_append(v_group_ids, v_group_id);

    insert into public.variant_groups
      (id, product_id, name, color_hex, group_images, sort_order)
    values (
      v_group_id,
      v_product_id,
      coalesce(v_group ->> 'name', ''),
      nullif(v_group ->> 'color_hex', ''),
      coalesce(
        (select array_agg(value #>> '{}')
           from jsonb_array_elements(coalesce(v_group -> 'group_images', '[]'::jsonb))),
        '{}'::text[]
      ),
      coalesce((v_group ->> 'sort_order')::integer, 0)
    )
    on conflict (id) do update set
      product_id   = excluded.product_id,
      name         = excluded.name,
      color_hex    = excluded.color_hex,
      group_images = excluded.group_images,
      sort_order   = excluded.sort_order;

    for v_item in
      select * from jsonb_array_elements(coalesce(v_group -> 'items', '[]'::jsonb))
    loop
      v_item_id  := coalesce(nullif(v_item ->> 'id', '')::uuid, gen_random_uuid());
      v_item_ids := array_append(v_item_ids, v_item_id);

      insert into public.variant_items
        (id, group_id, sku, size_label, price_override, stock_quantity,
         low_stock_threshold, sort_order)
      values (
        v_item_id,
        v_group_id,
        coalesce(v_item ->> 'sku', ''),
        coalesce(v_item ->> 'size_label', ''),
        (v_item ->> 'price_override')::numeric,
        coalesce((v_item ->> 'stock_quantity')::integer, 0),
        coalesce((v_item ->> 'low_stock_threshold')::integer, 5),
        coalesce((v_item ->> 'sort_order')::integer, 0)
      )
      on conflict (id) do update set
        group_id            = excluded.group_id,
        sku                 = excluded.sku,
        size_label          = excluded.size_label,
        price_override      = excluded.price_override,
        stock_quantity      = excluded.stock_quantity,
        low_stock_threshold = excluded.low_stock_threshold,
        sort_order          = excluded.sort_order;
    end loop;
  end loop;

  -- Anything the editor removed. `= any('{}')` is false, so a product saved
  -- with no groups correctly clears the tree.
  delete from public.variant_items vi
   using public.variant_groups vg
   where vi.group_id = vg.id
     and vg.product_id = v_product_id
     and not (vi.id = any (v_item_ids));

  delete from public.variant_groups
   where product_id = v_product_id
     and not (id = any (v_group_ids));

  return jsonb_build_object('product_id', v_product_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- admin_stats — dashboard figures, aggregated over every order.
--
-- The back-office only pages in the most recent orders, so folding totals over
-- that list under-reported revenue as soon as the store passed one page.
-- ---------------------------------------------------------------------------
create or replace function public.admin_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, extensions, pg_temp
as $$
declare
  v_total          integer := 0;
  v_pending        integer := 0;
  v_revenue_orders integer := 0;
  v_gross          numeric := 0;
  v_by_cat         jsonb   := '{}'::jsonb;
begin
  if not public.is_staff() then
    raise exception 'Not authorised';
  end if;

  select count(*),
         count(*) filter (where status in ('pending', 'paid')),
         count(*) filter (where status not in ('cancelled', 'refunded')),
         coalesce(sum(grand_total)
                  filter (where status not in ('cancelled', 'refunded')), 0)
    into v_total, v_pending, v_revenue_orders, v_gross
    from public.orders;

  select coalesce(jsonb_object_agg(cat, total), '{}'::jsonb)
    into v_by_cat
    from (
      select coalesce(oi.category, 'Other') as cat,
             sum(oi.line_total)             as total
        from public.order_items oi
        join public.orders o on o.id = oi.order_id
       where o.status not in ('cancelled', 'refunded')
       group by 1
    ) s;

  return jsonb_build_object(
    'gross_revenue', v_gross,
    'total_orders', v_total,
    'pending_orders', v_pending,
    'revenue_orders', v_revenue_orders,
    'revenue_by_category', v_by_cat
  );
end;
$$;

-- ============================================================================
-- 7. Row-Level Security
--
-- Storefront reads the live catalogue; writes are staff-only; a customer sees
-- only their own profile, addresses, wishlist and orders.
--
-- Two policies here are deliberately tighter than the original 0003 pair:
--   * promotions are NOT bulk-readable — the old policy exposed every active
--     row to anonymous clients, so the whole discount list could be dumped with
--     one select. Redemption goes through validate_promotion(), which is
--     SECURITY DEFINER and answers only for a code the caller already knows.
--   * direct order inserts require a signed-in owner. The old policy allowed
--     `user_id is null`, letting anyone write order rows with any totals. Guest
--     checkout is unaffected: it goes through place_order().
-- ============================================================================

alter table public.products        enable row level security;
alter table public.variant_groups  enable row level security;
alter table public.variant_items   enable row level security;
alter table public.promotions      enable row level security;
alter table public.store_settings  enable row level security;
alter table public.profiles        enable row level security;
alter table public.addresses       enable row level security;
alter table public.wishlists       enable row level security;
alter table public.orders          enable row level security;
alter table public.order_items     enable row level security;

-- Every auth.uid() and is_staff() call below is wrapped in a scalar subquery.
-- Called directly, Postgres evaluates them once PER ROW, and is_staff() is
-- SECURITY DEFINER over public.profiles — so a catalogue scan ran one profile
-- lookup per product. As a subquery it becomes an InitPlan, evaluated once per
-- statement. Measured on 20,000 products: 946 ms -> 2.8 ms.
--
-- Write grants are scoped to insert/update/delete rather than `for all`, so a
-- plain SELECT no longer evaluates the write policy on top of the read one.

-- ---- Catalogue: public read of live rows; staff full control ----
drop policy if exists products_read      on public.products;
drop policy if exists products_write     on public.products;
drop policy if exists products_write_ins on public.products;
drop policy if exists products_write_upd on public.products;
drop policy if exists products_write_del on public.products;
create policy products_read on public.products
  for select using (is_active or (select public.is_staff()));
create policy products_write_ins on public.products
  for insert with check ((select public.is_staff()));
create policy products_write_upd on public.products
  for update using ((select public.is_staff())) with check ((select public.is_staff()));
create policy products_write_del on public.products
  for delete using ((select public.is_staff()));

drop policy if exists vgroups_read      on public.variant_groups;
drop policy if exists vgroups_write     on public.variant_groups;
drop policy if exists vgroups_write_ins on public.variant_groups;
drop policy if exists vgroups_write_upd on public.variant_groups;
drop policy if exists vgroups_write_del on public.variant_groups;
create policy vgroups_read on public.variant_groups
  for select using (
    (select public.is_staff())
    or exists (select 1 from public.products p where p.id = product_id and p.is_active)
  );
create policy vgroups_write_ins on public.variant_groups
  for insert with check ((select public.is_staff()));
create policy vgroups_write_upd on public.variant_groups
  for update using ((select public.is_staff())) with check ((select public.is_staff()));
create policy vgroups_write_del on public.variant_groups
  for delete using ((select public.is_staff()));

drop policy if exists vitems_read      on public.variant_items;
drop policy if exists vitems_write     on public.variant_items;
drop policy if exists vitems_write_ins on public.variant_items;
drop policy if exists vitems_write_upd on public.variant_items;
drop policy if exists vitems_write_del on public.variant_items;
create policy vitems_read on public.variant_items
  for select using (
    (select public.is_staff())
    or exists (
      select 1 from public.variant_groups vg
      join public.products p on p.id = vg.product_id
      where vg.id = group_id and p.is_active
    )
  );
create policy vitems_write_ins on public.variant_items
  for insert with check ((select public.is_staff()));
create policy vitems_write_upd on public.variant_items
  for update using ((select public.is_staff())) with check ((select public.is_staff()));
create policy vitems_write_del on public.variant_items
  for delete using ((select public.is_staff()));

-- A shopper can read a product they have wishlisted even once it is retired.
-- products_read is `is_active or is_staff()`, which is right for the storefront
-- but defeats the wishlist: the client resolves saved ids the catalogue listing
-- does not carry, precisely so a piece taken off sale still appears.
--
-- Every reference to the row under test is table-qualified. `wishlists` has a
-- `product_id` of its own, so an unqualified `product_id` inside these
-- subqueries binds to the wishlist row, not the row being checked -- which
-- reads as `w.product_id = w.product_id` and grants everything.
drop policy if exists products_read_wishlisted on public.products;
create policy products_read_wishlisted on public.products
  for select using (
    exists (
      select 1 from public.wishlists w
       where w.product_id = public.products.id
         and w.user_id = (select auth.uid())
    )
  );

drop policy if exists vgroups_read_wishlisted on public.variant_groups;
create policy vgroups_read_wishlisted on public.variant_groups
  for select using (
    exists (
      select 1 from public.wishlists w
       where w.product_id = public.variant_groups.product_id
         and w.user_id = (select auth.uid())
    )
  );

drop policy if exists vitems_read_wishlisted on public.variant_items;
create policy vitems_read_wishlisted on public.variant_items
  for select using (
    exists (
      select 1
        from public.variant_groups vg
        join public.wishlists w on w.product_id = vg.product_id
       where vg.id = public.variant_items.group_id
         and w.user_id = (select auth.uid())
    )
  );

-- ---- Promotions: codes are never bulk-readable; redemption goes through
--      validate_promotion(), which is SECURITY DEFINER and answers only for a
--      code the caller already knows. ----
drop policy if exists promotions_read      on public.promotions;
drop policy if exists promotions_write     on public.promotions;
drop policy if exists promotions_write_ins on public.promotions;
drop policy if exists promotions_write_upd on public.promotions;
drop policy if exists promotions_write_del on public.promotions;
create policy promotions_read on public.promotions
  for select using ((select public.is_staff()));
create policy promotions_write_ins on public.promotions
  for insert with check ((select public.is_staff()));
create policy promotions_write_upd on public.promotions
  for update using ((select public.is_staff())) with check ((select public.is_staff()));
create policy promotions_write_del on public.promotions
  for delete using ((select public.is_staff()));

-- ---- Store settings: shipping figures are shown on the storefront ----
drop policy if exists store_settings_read      on public.store_settings;
drop policy if exists store_settings_write     on public.store_settings;
drop policy if exists store_settings_write_ins on public.store_settings;
drop policy if exists store_settings_write_upd on public.store_settings;
drop policy if exists store_settings_write_del on public.store_settings;
create policy store_settings_read on public.store_settings
  for select using (true);
create policy store_settings_write_ins on public.store_settings
  for insert with check ((select public.is_staff()));
create policy store_settings_write_upd on public.store_settings
  for update using ((select public.is_staff())) with check ((select public.is_staff()));
create policy store_settings_write_del on public.store_settings
  for delete using ((select public.is_staff()));

-- ---- Profiles ----
drop policy if exists profiles_self_read on public.profiles;
create policy profiles_self_read on public.profiles
  for select using (id = (select auth.uid()) or (select public.is_staff()));

drop policy if exists profiles_self_update on public.profiles;
-- Customers may edit only safe profile fields. In particular, role is not
-- updateable through the public API because current_app_role()/is_staff() use it
-- as an authorization attribute. Role changes belong to an owner/service-role
-- or dedicated admin path.
revoke update on table public.profiles from anon, authenticated;
grant update (email, full_name, phone) on table public.profiles to authenticated;

create policy profiles_self_update on public.profiles
  for update using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- ---- Addresses & wishlists: owner-scoped. A single policy covers every
--      command here, so it stays `for all`. ----
drop policy if exists addresses_owner on public.addresses;
create policy addresses_owner on public.addresses
  for all using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists wishlists_owner on public.wishlists;
create policy wishlists_owner on public.wishlists
  for all using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- ---- Orders: a customer sees their own; staff see and update all. Direct
--      inserts require a signed-in owner; guest checkout goes through
--      place_order(), which is SECURITY DEFINER. ----
drop policy if exists orders_read on public.orders;
create policy orders_read on public.orders
  for select using (user_id = (select auth.uid()) or (select public.is_staff()));


drop policy if exists orders_staff_update on public.orders;
create policy orders_staff_update on public.orders
  for update using ((select public.is_staff()))
  with check ((select public.is_staff()));

drop policy if exists order_items_read on public.order_items;
create policy order_items_read on public.order_items
  for select using (
    (select public.is_staff())
    or exists (
      select 1 from public.orders o
       where o.id = order_id and o.user_id = (select auth.uid())
    )
  );


-- ============================================================================
-- 8. Execute grants
--
-- Staff-only RPCs should not even be callable anonymously.
-- ============================================================================
revoke execute on function public.save_product(jsonb) from public, anon;
revoke execute on function public.admin_stats() from public, anon;
revoke execute on function public.restock_order(uuid) from public, anon;

grant execute on function public.save_product(jsonb) to authenticated;
grant execute on function public.admin_stats() to authenticated;
grant execute on function public.restock_order(uuid) to authenticated;

-- Storefront-facing: guests must be able to price a basket and check out.
revoke execute on function public.validate_promotion(text, jsonb) from public;
grant execute on function public.validate_promotion(text, jsonb) to anon, authenticated;
revoke execute on function public.place_order(jsonb, text, jsonb, text) from public;
grant execute on function public.place_order(jsonb, text, jsonb, text) to anon, authenticated;
