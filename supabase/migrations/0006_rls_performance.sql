-- ============================================================================
-- Vanguard Fashion — 0006 Row-Level Security performance
--
-- Same access, measured 200x faster. Two changes, neither of which alters who
-- can see or do what:
--
--   1. Policy expressions called auth.uid() and public.is_staff() directly, so
--      Postgres evaluated them once PER ROW. is_staff() is SECURITY DEFINER and
--      reads public.profiles, so a catalogue scan ran one profile lookup per
--      product. Wrapping the call in a scalar subquery — `(select is_staff())`
--      — makes it an InitPlan, evaluated once per statement.
--
--   2. Catalogue writes were granted with `for all`, which includes SELECT, so
--      every read evaluated the write policy too. The plan for a plain product
--      listing read:
--
--          Filter: (is_staff() OR is_active OR is_staff())
--
--      — two SECURITY DEFINER calls per row, one of them entirely redundant
--      because the read policy already admits staff. Splitting the write grant
--      into insert/update/delete removes it from the read path.
--
-- Measured on 20,000 products, selecting as a signed-in customer:
--
--      before   Filter: (is_staff() OR is_active OR is_staff())    599 ms
--      after    Filter: (is_active OR $0)  + InitPlan                2.9 ms
--
-- Equivalence: for every table below, the SELECT expression is unchanged once
-- the redundant disjunct is folded out --
--   products        is_active OR staff OR staff  ==  is_active OR staff
--   promotions      staff OR staff               ==  staff
--   store_settings  true OR staff                ==  true
--   variant_groups  (staff OR live) OR staff     ==  staff OR live
--   variant_items   (staff OR live) OR staff     ==  staff OR live
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Catalogue: read policy keeps admitting staff; the write grant is narrowed to
-- the commands that actually write.
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Promotions and store settings
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Owner-scoped tables. These carry a single `for all` policy that is also the
-- read policy, so the grant stays as-is; only the per-row auth.uid() call is
-- hoisted into an InitPlan.
-- ---------------------------------------------------------------------------
drop policy if exists addresses_owner on public.addresses;
create policy addresses_owner on public.addresses
  for all using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists wishlists_owner on public.wishlists;
create policy wishlists_owner on public.wishlists
  for all using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Profiles and orders
-- ---------------------------------------------------------------------------
drop policy if exists profiles_self_read on public.profiles;
create policy profiles_self_read on public.profiles
  for select using (id = (select auth.uid()) or (select public.is_staff()));

drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles
  for update using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

drop policy if exists orders_read on public.orders;
create policy orders_read on public.orders
  for select using (user_id = (select auth.uid()) or (select public.is_staff()));

drop policy if exists orders_insert on public.orders;
create policy orders_insert on public.orders
  for insert with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

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

drop policy if exists order_items_insert on public.order_items;
create policy order_items_insert on public.order_items
  for insert with check (
    (select public.is_staff())
    or exists (
      select 1 from public.orders o
       where o.id = order_id
         and (select auth.uid()) is not null
         and o.user_id = (select auth.uid())
    )
  );
