-- ============================================================================
-- Vanguard Fashion — 0003 Row-Level Security
-- Storefront reads are public; writes are staff-only; customers see only their
-- own profile, addresses, wishlist, and orders.
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

-- ---------------------------------------------------------------------------
-- Catalog: public read of active rows; staff full control.
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Promotions: read active promos (needed for code validation UX); staff manage.
-- Note: validate_promotion() runs as a stable function and is the primary path;
-- direct reads are limited to active rows so codes aren't enumerable wholesale.
-- ---------------------------------------------------------------------------
drop policy if exists promotions_read on public.promotions;
create policy promotions_read on public.promotions
  for select using (public.is_staff() or is_active);

drop policy if exists promotions_write on public.promotions;
create policy promotions_write on public.promotions
  for all using (public.is_staff()) with check (public.is_staff());

-- ---------------------------------------------------------------------------
-- Profiles: a user reads/updates their own; staff can read all.
-- ---------------------------------------------------------------------------
drop policy if exists profiles_self_read on public.profiles;
create policy profiles_self_read on public.profiles
  for select using (id = auth.uid() or public.is_staff());

drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- Addresses & wishlists: owner-scoped.
-- ---------------------------------------------------------------------------
drop policy if exists addresses_owner on public.addresses;
create policy addresses_owner on public.addresses
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists wishlists_owner on public.wishlists;
create policy wishlists_owner on public.wishlists
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Orders: a customer sees/creates their own; staff (fulfillment) see & update all.
-- Inserts primarily flow through place_order() (SECURITY DEFINER), but a direct
-- insert of one's own order is permitted for flexibility.
-- ---------------------------------------------------------------------------
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
