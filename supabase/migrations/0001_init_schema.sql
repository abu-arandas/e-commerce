-- ============================================================================
-- Vanguard Fashion — 0001 initial schema
-- Hierarchical, multi-level product variants: Product → Variant_Group (Color)
-- → Variant_Item (Size / final SKU). Independent SKU, price, and stock at the
-- most granular level, per PRD §5.
-- ============================================================================

create extension if not exists "pgcrypto";     -- gen_random_uuid()
create extension if not exists "citext";        -- case-insensitive promo codes

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 5.1 products — parent container
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 5.2 variant_groups — Level 1 (Color). Holds visuals for the color.
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 5.3 variant_items — Level 2 (Size / final SKU). The purchasable unit.
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 5.4 promotions — the discount rules engine
-- ---------------------------------------------------------------------------
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
  -- Optional targeting: apply only to / exclude specific categories (PRD §3.2).
  included_categories text[] not null default '{}',
  excluded_categories text[] not null default '{}',
  valid_from        timestamptz not null default now(),
  valid_until       timestamptz,
  created_at        timestamptz not null default now()
);
create index if not exists promotions_active_idx on public.promotions (is_active, valid_from, valid_until);

-- ---------------------------------------------------------------------------
-- profiles — mirrors auth.users, carries role + storefront profile data
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- orders + order_items — nested SKU is captured at the line level so stock can
-- decrement against the exact variant_item (PRD §3.2 "Order & Inventory Sync").
-- ---------------------------------------------------------------------------
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
  -- Denormalised snapshot so historical orders survive catalog edits/deletes.
  product_title   text not null,
  variant_name    text,
  size_label      text,
  sku             text not null,
  unit_price      numeric(10, 2) not null,
  quantity        integer not null check (quantity > 0),
  line_total      numeric(10, 2) not null
);
create index if not exists order_items_order_idx on public.order_items (order_id);

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------------
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
