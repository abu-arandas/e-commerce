-- ============================================================================
-- 0007 — close the direct write paths around checkout
--
-- 0006 preserved the access matrix from 0003 exactly, on purpose: it was a
-- performance rewrite and proving "nothing changed" was the point. That left a
-- hole 0003 had all along, which review caught.
--
-- `place_order` computes every figure server-side -- prices from the SKU rows,
-- the discount from validate_promotion, shipping from store_settings -- and
-- that was described as the trusted path. It was not the *only* path. RLS let
-- any signed-in customer INSERT straight into public.orders with whatever
-- subtotal, discount, shipping, grand_total, status, and promotion they liked,
-- so long as user_id was their own, and then append matching order_items.
-- admin_stats() aggregates those rows into revenue-by-category, so fabricated
-- lines land in the dashboard.
--
-- Nothing needs those policies. The Flutter client never writes to either
-- table -- checkout is `rpc('place_order')` and no other code path touches
-- them -- and place_order is SECURITY DEFINER, so it inserts with the
-- function owner's rights and is unaffected by RLS. Dropping the two INSERT
-- policies makes the trusted path the only path.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Orders are created by place_order() or not at all.
-- ----------------------------------------------------------------------------
drop policy if exists orders_insert      on public.orders;
drop policy if exists order_items_insert on public.order_items;

-- ----------------------------------------------------------------------------
-- 2. Totals must add up.
--
-- The existing constraints say each figure is non-negative and the discount
-- does not exceed the subtotal. Neither says the four agree with each other,
-- so a row could still claim a grand_total unrelated to its own parts. This
-- is the accounting identity itself.
--
-- Safe against place_order as written: line totals, the promotion discount and
-- the shipping fee are each already rounded to two decimals (or read from a
-- numeric(10,2) column), so the sum is exact at the column's scale and cannot
-- drift by a fraction of a cent.
-- ----------------------------------------------------------------------------
alter table public.orders drop constraint if exists orders_totals_consistent;
alter table public.orders add constraint orders_totals_consistent
  check (grand_total = subtotal - discount_total + shipping_total);

-- ----------------------------------------------------------------------------
-- 3. Let a shopper see a product they saved, even once it is retired.
--
-- products_read is `is_active or is_staff()`, which is right for the storefront
-- but silently defeats the wishlist: the client resolves saved ids that the
-- catalogue listing does not carry, precisely so a piece taken off sale still
-- appears, and that lookup returned nothing for ordinary customers. The
-- wishlist page fell back to counting it as unavailable.
--
-- Scoped to rows the caller has actually wishlisted, so it exposes no more of
-- the retired catalogue than the shopper already chose to save. The variant
-- tables get the matching exception, otherwise the product resolves with an
-- empty variant tree.
-- ----------------------------------------------------------------------------
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
