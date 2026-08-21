-- ============================================================================
-- Vanguard Fashion — Combined Database Schema, Business Logic, RLS & Seed Data
-- Target Project: https://dtbrspgpnklwetkgzryf.supabase.co
--
-- Instructions:
-- 1. Open Supabase SQL Editor:
--    https://supabase.com/dashboard/project/dtbrspgpnklwetkgzryf/sql/new
-- 2. Paste the contents of this file into the editor.
-- 3. Click "Run".
-- ============================================================================

-- ============================================================================
-- STEP 1: 0001_init_schema.sql (Tables, Enums, Indexes, Triggers)
-- ============================================================================

create extension if not exists "pgcrypto";     -- gen_random_uuid()
create extension if not exists "citext";        -- case-insensitive promo codes

-- Enums
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
    create type app_role as enum ('customer', 'catalog_manager', 'marketing_manager', 'fulfillment', 'admin');
  end if;
end$$;

-- Products — parent container
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
create index if not exists products_active_idx   on public.products (is_active);
create index if not exists products_category_idx  on public.products (category);
create index if not exists products_featured_idx  on public.products (is_featured) where is_featured;

-- Variant groups — Level 1 (Color). Holds visuals for the color.
create table if not exists public.variant_groups (
  id            uuid primary key default gen_random_uuid(),
  product_id    uuid not null references public.products (id) on delete cascade,
  name          text not null,                    -- e.g. "Midnight Blue"
  color_hex     text check (color_hex ~* '^#[0-9a-f]{6}$'),
  group_images  text[] not null default '{}',     -- Supabase Storage .webp URLs
  sort_order    integer not null default 0,
  created_at    timestamptz not null default now()
);
create index if not exists variant_groups_product_idx on public.variant_groups (product_id);

-- Variant items — Level 2 (Size / final SKU). The purchasable unit.
create table if not exists public.variant_items (
  id              uuid primary key default gen_random_uuid(),
  group_id        uuid not null references public.variant_groups (id) on delete cascade,
  sku             text unique not null,
  size_label      text not null,                  -- e.g. "M", "L"
  price_override  numeric(10, 2) check (price_override >= 0),
  stock_quantity  integer not null default 0 check (stock_quantity >= 0),
  low_stock_threshold integer not null default 5,
  sort_order      integer not null default 0,
  created_at      timestamptz not null default now()
);
create index if not exists variant_items_group_idx on public.variant_items (group_id);
create index if not exists variant_items_low_stock_idx
  on public.variant_items (stock_quantity)
  where stock_quantity <= low_stock_threshold;

-- Promotions — discount rules engine
create table if not exists public.promotions (
  id                uuid primary key default gen_random_uuid(),
  code              citext unique not null,
  description       text,
  discount_type     discount_type not null,
  discount_value    numeric(10, 2) not null default 0 check (discount_value >= 0),
  min_order_value   numeric(10, 2) not null default 0 check (min_order_value >= 0),
  usage_limit       integer,                       -- null = unlimited
  usage_count       integer not null default 0,
  is_active         boolean not null default true,
  included_categories text[] not null default '{}',
  excluded_categories text[] not null default '{}',
  valid_from        timestamptz not null default now(),
  valid_until       timestamptz,
  created_at        timestamptz not null default now()
);
create index if not exists promotions_active_idx on public.promotions (is_active, valid_from, valid_until);

-- Profiles — mirrors auth.users
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

-- Orders + order_items
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
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index if not exists orders_user_idx   on public.orders (user_id);
create index if not exists orders_status_idx  on public.orders (status);
create index if not exists orders_created_idx on public.orders (created_at desc);

create table if not exists public.order_items (
  id              uuid primary key default gen_random_uuid(),
  order_id        uuid not null references public.orders (id) on delete cascade,
  variant_item_id uuid references public.variant_items (id) on delete set null,
  product_title   text not null,
  variant_name    text,
  size_label      text,
  sku             text not null,
  unit_price      numeric(10, 2) not null,
  quantity        integer not null check (quantity > 0),
  line_total      numeric(10, 2) not null
);
create index if not exists order_items_order_idx on public.order_items (order_id);

-- updated_at maintenance
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

-- Auto-provision profile on auth sign-up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
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


-- ============================================================================
-- STEP 2: 0002_functions.sql (Business Logic & Functions)
-- ============================================================================

create or replace function public.current_app_role()
returns app_role
language sql
stable
security definer set search_path = public
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
security definer set search_path = public
as $$
  select public.current_app_role() in
    ('catalog_manager', 'marketing_manager', 'fulfillment', 'admin');
$$;

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

create or replace function public.validate_promotion(
  p_code       text,
  p_subtotal   numeric,
  p_categories text[] default '{}'
)
returns jsonb
language plpgsql
stable
as $$
declare
  promo public.promotions%rowtype;
  v_discount numeric := 0;
  v_free_shipping boolean := false;
begin
  select * into promo from public.promotions
  where code = p_code::citext and is_active = true;

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

  if p_subtotal < promo.min_order_value then
    return jsonb_build_object(
      'valid', false,
      'reason', format('Requires a minimum order of %s', promo.min_order_value)
    );
  end if;

  if array_length(promo.included_categories, 1) is not null
     and not (p_categories && promo.included_categories) then
    return jsonb_build_object('valid', false, 'reason', 'No eligible items in cart');
  end if;

  if array_length(promo.excluded_categories, 1) is not null
     and (p_categories && promo.excluded_categories) then
    return jsonb_build_object('valid', false, 'reason', 'Cart contains excluded items');
  end if;

  case promo.discount_type
    when 'percentage'    then v_discount := round(p_subtotal * (promo.discount_value / 100.0), 2);
    when 'fixed_amount'  then v_discount := least(promo.discount_value, p_subtotal);
    when 'free_shipping' then v_free_shipping := true;
  end case;

  return jsonb_build_object(
    'valid', true,
    'promotion_id', promo.id,
    'code', promo.code,
    'discount_type', promo.discount_type,
    'discount_amount', v_discount,
    'free_shipping', v_free_shipping,
    'description', promo.description
  );
end;
$$;

create or replace function public.place_order(
  p_items           jsonb,
  p_promo_code      text default null,
  p_shipping_address jsonb default null,
  p_contact_email   text default null,
  p_flat_shipping   numeric default 0
)
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  v_order_id      uuid := gen_random_uuid();
  v_item          jsonb;
  v_variant_id    uuid;
  v_qty           integer;
  v_unit          numeric;
  v_line          numeric;
  v_subtotal      numeric := 0;
  v_categories    text[] := '{}';
  v_promo         jsonb;
  v_promo_id      uuid := null;
  v_discount      numeric := 0;
  v_shipping      numeric := coalesce(p_flat_shipping, 0);
  v_grand         numeric;
  vi              public.variant_items%rowtype;
  v_prod_title    text;
  v_group_name    text;
  v_category      text;
begin
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'Cannot place an empty order';
  end if;

  insert into public.orders (id, user_id, status, contact_email, shipping_address)
  values (v_order_id, auth.uid(), 'pending', p_contact_email, p_shipping_address);

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_variant_id := (v_item ->> 'variant_item_id')::uuid;
    v_qty        := (v_item ->> 'quantity')::integer;

    if v_qty is null or v_qty <= 0 then
      raise exception 'Invalid quantity for variant %', v_variant_id;
    end if;

    select * into vi from public.variant_items
      where id = v_variant_id for update;

    if not found then
      raise exception 'Variant % no longer exists', v_variant_id;
    end if;

    if vi.stock_quantity < v_qty then
      raise exception 'Insufficient stock for SKU % (have %, need %)',
        vi.sku, vi.stock_quantity, v_qty;
    end if;

    select p.title, p.category, vg.name
      into v_prod_title, v_category, v_group_name
      from public.variant_groups vg
      join public.products p on p.id = vg.product_id
      where vg.id = vi.group_id;

    v_unit := coalesce(vi.price_override,
                       (select base_price from public.products p2
                        join public.variant_groups vg2 on vg2.product_id = p2.id
                        where vg2.id = vi.group_id));
    v_line := round(v_unit * v_qty, 2);
    v_subtotal := v_subtotal + v_line;
    if v_category is not null then
      v_categories := array_append(v_categories, v_category);
    end if;

    update public.variant_items
      set stock_quantity = stock_quantity - v_qty
      where id = v_variant_id;

    insert into public.order_items
      (order_id, variant_item_id, product_title, variant_name, size_label,
       sku, unit_price, quantity, line_total)
    values
      (v_order_id, v_variant_id, v_prod_title, v_group_name, vi.size_label,
       vi.sku, v_unit, v_qty, v_line);
  end loop;

  if p_promo_code is not null and length(trim(p_promo_code)) > 0 then
    v_promo := public.validate_promotion(p_promo_code, v_subtotal, v_categories);
    if (v_promo ->> 'valid')::boolean then
      v_promo_id := (v_promo ->> 'promotion_id')::uuid;
      v_discount := coalesce((v_promo ->> 'discount_amount')::numeric, 0);
      if (v_promo ->> 'free_shipping')::boolean then
        v_shipping := 0;
      end if;
      update public.promotions
        set usage_count = usage_count + 1
        where id = v_promo_id;
    else
      raise exception 'Promotion rejected: %', (v_promo ->> 'reason');
    end if;
  end if;

  v_grand := round(v_subtotal - v_discount + v_shipping, 2);

  update public.orders set
    subtotal       = v_subtotal,
    discount_total = v_discount,
    shipping_total = v_shipping,
    grand_total    = v_grand,
    promotion_id   = v_promo_id,
    promo_code     = p_promo_code,
    status         = 'pending'
  where id = v_order_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'subtotal', v_subtotal,
    'discount_total', v_discount,
    'shipping_total', v_shipping,
    'grand_total', v_grand
  );
end;
$$;

create or replace function public.restock_order(p_order_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'Not authorised';
  end if;
  update public.variant_items vi
    set stock_quantity = vi.stock_quantity + oi.quantity
    from public.order_items oi
    where oi.order_id = p_order_id
      and oi.variant_item_id = vi.id;
end;
$$;


-- ============================================================================
-- STEP 3: 0003_rls.sql (Row-Level Security Policies)
-- ============================================================================

alter table public.products        enable row level security;
alter table public.variant_groups  enable row level security;
alter table public.variant_items   enable row level security;
alter table public.promotions      enable row level security;
alter table public.profiles        enable row level security;
alter table public.addresses       enable row level security;
alter table public.wishlists       enable row level security;
alter table public.orders          enable row level security;
alter table public.order_items     enable row level security;

drop policy if exists products_read on public.products;
create policy products_read on public.products
  for select using (is_active or public.is_staff());

drop policy if exists products_write on public.products;
create policy products_write on public.products
  for all using (public.is_staff()) with check (public.is_staff());

drop policy if exists vgroups_read on public.variant_groups;
create policy vgroups_read on public.variant_groups
  for select using (
    public.is_staff()
    or exists (select 1 from public.products p where p.id = product_id and p.is_active)
  );

drop policy if exists vgroups_write on public.variant_groups;
create policy vgroups_write on public.variant_groups
  for all using (public.is_staff()) with check (public.is_staff());

drop policy if exists vitems_read on public.variant_items;
create policy vitems_read on public.variant_items
  for select using (
    public.is_staff()
    or exists (
      select 1 from public.variant_groups vg
      join public.products p on p.id = vg.product_id
      where vg.id = group_id and p.is_active
    )
  );

drop policy if exists vitems_write on public.variant_items;
create policy vitems_write on public.variant_items
  for all using (public.is_staff()) with check (public.is_staff());

drop policy if exists promotions_read on public.promotions;
create policy promotions_read on public.promotions
  for select using (public.is_staff() or is_active);

drop policy if exists promotions_write on public.promotions;
create policy promotions_write on public.promotions
  for all using (public.is_staff()) with check (public.is_staff());

drop policy if exists profiles_self_read on public.profiles;
create policy profiles_self_read on public.profiles
  for select using (id = auth.uid() or public.is_staff());

drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists addresses_owner on public.addresses;
create policy addresses_owner on public.addresses
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists wishlists_owner on public.wishlists;
create policy wishlists_owner on public.wishlists
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists orders_read on public.orders;
create policy orders_read on public.orders
  for select using (user_id = auth.uid() or public.is_staff());

drop policy if exists orders_insert on public.orders;
create policy orders_insert on public.orders
  for insert with check (user_id = auth.uid() or user_id is null);

drop policy if exists orders_staff_update on public.orders;
create policy orders_staff_update on public.orders
  for update using (public.is_staff()) with check (public.is_staff());

drop policy if exists order_items_read on public.order_items;
create policy order_items_read on public.order_items
  for select using (
    public.is_staff()
    or exists (select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid())
  );

drop policy if exists order_items_insert on public.order_items;
create policy order_items_insert on public.order_items
  for insert with check (
    public.is_staff()
    or exists (select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid())
  );


-- ============================================================================
-- STEP 4: seed.sql (Initial Demo Catalog & Promotions)
-- ============================================================================

insert into public.products (id, slug, title, description, category, base_price, is_active, is_featured)
values
  ('11111111-1111-1111-1111-111111111111', 'cashmere-turtleneck',
   'Cashmere Turtleneck',
   'A whisper-soft grade-A Mongolian cashmere turtleneck with a relaxed, elongated silhouette. Fully fashioned seams and a ribbed funnel neck.',
   'Knitwear', 245.00, true, true),
  ('22222222-2222-2222-2222-222222222222', 'tailored-wool-trouser',
   'Tailored Wool Trouser',
   'Italian virgin-wool trousers with a mid-rise waist, pressed crease, and tapered ankle. Sartorial by day, effortless by night.',
   'Trousers', 189.00, true, true),
  ('33333333-3333-3333-3333-333333333333', 'silk-slip-dress',
   'Bias-Cut Silk Slip Dress',
   '100% mulberry silk cut on the bias to skim the body. Adjustable straps and a cowl neckline.',
   'Dresses', 320.00, true, true),
  ('44444444-4444-4444-4444-444444444444', 'structured-trench',
   'Structured Cotton Trench',
   'A water-resistant cotton-gabardine trench with storm flaps, a removable belt, and horn buttons.',
   'Outerwear', 410.00, true, false)
on conflict (id) do update set
  title = excluded.title, description = excluded.description,
  category = excluded.category, base_price = excluded.base_price;

insert into public.variant_groups (id, product_id, name, color_hex, group_images, sort_order)
values
  ('a1000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'Midnight Blue', '#1E2A44',
   array['https://picsum.photos/seed/vf-cash-midnight-1/900/1200',
         'https://picsum.photos/seed/vf-cash-midnight-2/900/1200'], 0),
  ('a1000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   'Crimson', '#8C1C2B',
   array['https://picsum.photos/seed/vf-cash-crimson-1/900/1200'], 1),
  ('a1000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
   'Oatmeal', '#D8CDB8',
   array['https://picsum.photos/seed/vf-cash-oatmeal-1/900/1200'], 2),

  ('a2000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222',
   'Charcoal', '#36373B',
   array['https://picsum.photos/seed/vf-trou-charcoal-1/900/1200'], 0),
  ('a2000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222',
   'Camel', '#C19A6B',
   array['https://picsum.photos/seed/vf-trou-camel-1/900/1200'], 1),

  ('a3000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333',
   'Champagne', '#E7D3B3',
   array['https://picsum.photos/seed/vf-slip-champagne-1/900/1200'], 0),
  ('a3000000-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333',
   'Onyx', '#14141A',
   array['https://picsum.photos/seed/vf-slip-onyx-1/900/1200'], 1),

  ('a4000000-0000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444',
   'Sand', '#C9B79C',
   array['https://picsum.photos/seed/vf-trench-sand-1/900/1200'], 0)
on conflict (id) do update set
  name = excluded.name, color_hex = excluded.color_hex, group_images = excluded.group_images;

insert into public.variant_items (group_id, sku, size_label, price_override, stock_quantity, sort_order)
values
  ('a1000000-0000-0000-0000-000000000001', 'CASH-TURT-BLU-S',  'S',  null, 12, 0),
  ('a1000000-0000-0000-0000-000000000001', 'CASH-TURT-BLU-M',  'M',  null, 8,  1),
  ('a1000000-0000-0000-0000-000000000001', 'CASH-TURT-BLU-L',  'L',  null, 3,  2),
  ('a1000000-0000-0000-0000-000000000001', 'CASH-TURT-BLU-XL', 'XL', 255.00, 0, 3),
  ('a1000000-0000-0000-0000-000000000002', 'CASH-TURT-CRM-S',  'S',  null, 5,  0),
  ('a1000000-0000-0000-0000-000000000002', 'CASH-TURT-CRM-M',  'M',  null, 9,  1),
  ('a1000000-0000-0000-0000-000000000002', 'CASH-TURT-CRM-L',  'L',  null, 6,  2),
  ('a1000000-0000-0000-0000-000000000003', 'CASH-TURT-OAT-M',  'M',  null, 14, 0),
  ('a1000000-0000-0000-0000-000000000003', 'CASH-TURT-OAT-L',  'L',  null, 11, 1),

  ('a2000000-0000-0000-0000-000000000001', 'WOOL-TROU-CHR-30', '30', null, 10, 0),
  ('a2000000-0000-0000-0000-000000000001', 'WOOL-TROU-CHR-32', '32', null, 7,  1),
  ('a2000000-0000-0000-0000-000000000001', 'WOOL-TROU-CHR-34', '34', null, 4,  2),
  ('a2000000-0000-0000-0000-000000000002', 'WOOL-TROU-CAM-32', '32', null, 6,  0),
  ('a2000000-0000-0000-0000-000000000002', 'WOOL-TROU-CAM-34', '34', null, 2,  1),

  ('a3000000-0000-0000-0000-000000000001', 'SILK-SLIP-CHA-XS', 'XS', null, 6, 0),
  ('a3000000-0000-0000-0000-000000000001', 'SILK-SLIP-CHA-S',  'S',  null, 9, 1),
  ('a3000000-0000-0000-0000-000000000001', 'SILK-SLIP-CHA-M',  'M',  null, 5, 2),
  ('a3000000-0000-0000-0000-000000000002', 'SILK-SLIP-ONX-S',  'S',  null, 8, 0),
  ('a3000000-0000-0000-0000-000000000002', 'SILK-SLIP-ONX-M',  'M',  null, 7, 1),

  ('a4000000-0000-0000-0000-000000000001', 'TRENCH-SND-S', 'S', null, 4, 0),
  ('a4000000-0000-0000-0000-000000000001', 'TRENCH-SND-M', 'M', null, 5, 1),
  ('a4000000-0000-0000-0000-000000000001', 'TRENCH-SND-L', 'L', null, 3, 2)
on conflict (sku) do update set
  stock_quantity = excluded.stock_quantity, price_override = excluded.price_override;

insert into public.promotions
  (code, description, discount_type, discount_value, min_order_value, usage_limit,
   included_categories, valid_from, valid_until)
values
  ('FALL20',   '20% off orders over $150',        'percentage',    20, 150, null, '{}',          now() - interval '1 day', now() + interval '60 days'),
  ('WELCOME15','$15 off your first order',        'fixed_amount',  15, 75,  1000, '{}',          now() - interval '1 day', now() + interval '365 days'),
  ('FREESHIP', 'Free shipping over $100',         'free_shipping', 0,  100, null, '{}',          now() - interval '1 day', now() + interval '30 days'),
  ('KNIT25',   '25% off all knitwear',            'percentage',    25, 0,   null, '{Knitwear}',  now() - interval '1 day', now() + interval '14 days')
on conflict (code) do update set
  description = excluded.description, discount_type = excluded.discount_type,
  discount_value = excluded.discount_value, min_order_value = excluded.min_order_value,
  valid_until = excluded.valid_until, is_active = true;
