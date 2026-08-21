-- ============================================================================
-- Vanguard Fashion — 0005 referential and monetary integrity
--
-- Three problems, each reproduced against a live database before being fixed:
--
--   1. Three foreign keys had no supporting index, so every delete of a
--      product, variant or promotion sequentially scanned its child table.
--      EXPLAIN confirmed Seq Scan on wishlists, order_items and orders.
--
--   2. A percentage promotion had no upper bound and place_order clamped only
--      fixed-amount discounts. `least()` guarded fixed_amount but nothing
--      guarded percentage, and grand_total had no floor — so a 500% code on a
--      245.00 basket wrote an order with grand_total = -980.00. The Flutter
--      client clamps its display to zero, which hides it; the stored row, which
--      is the authoritative one, stayed negative.
--
--   3. A promotion could end before it started, and usage_count could go
--      negative. Neither was rejected.
--
-- Data is repaired before each constraint is added, so this applies cleanly to
-- a database that already contains bad rows.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Index every foreign key
--
-- Postgres indexes the referenced side automatically; the referencing side is
-- the caller's job, and it is the side a cascade or SET NULL has to search.
-- ---------------------------------------------------------------------------
create index if not exists order_items_variant_item_idx
  on public.order_items (variant_item_id);
create index if not exists orders_promotion_idx
  on public.orders (promotion_id);
create index if not exists wishlists_product_idx
  on public.wishlists (product_id);

-- ---------------------------------------------------------------------------
-- 2. Promotion sanity
-- ---------------------------------------------------------------------------

-- Repair first: clamp any percentage promotion already above 100%, straighten
-- inverted date windows, and floor negative usage counts.
update public.promotions
   set discount_value = 100
 where discount_type = 'percentage' and discount_value > 100;

update public.promotions
   set valid_until = null
 where valid_until is not null and valid_until <= valid_from;

update public.promotions
   set usage_count = 0
 where usage_count < 0;

alter table public.promotions drop constraint if exists promotions_percentage_range;
alter table public.promotions add constraint promotions_percentage_range
  check (discount_type <> 'percentage' or discount_value <= 100);

alter table public.promotions drop constraint if exists promotions_window_ordered;
alter table public.promotions add constraint promotions_window_ordered
  check (valid_until is null or valid_until > valid_from);

alter table public.promotions drop constraint if exists promotions_usage_count_non_negative;
alter table public.promotions add constraint promotions_usage_count_non_negative
  check (usage_count >= 0);

-- A promotion is only ever looked up by code, and only live ones matter to the
-- storefront. The existing (is_active, valid_from, valid_until) index leads on
-- a boolean and serves nothing; the back-office listing wants recency.
drop index if exists public.promotions_active_idx;
create index if not exists promotions_live_idx
  on public.promotions (valid_until)
  where is_active;

-- ---------------------------------------------------------------------------
-- 3. Order money can never be negative
-- ---------------------------------------------------------------------------

-- Repair any order already written with an over-large discount: cap the
-- discount at the subtotal and recompute the total from the repaired figures.
update public.orders
   set discount_total = least(discount_total, subtotal),
       grand_total    = round(subtotal - least(discount_total, subtotal) + shipping_total, 2)
 where discount_total > subtotal or grand_total < 0;

alter table public.orders drop constraint if exists orders_money_non_negative;
alter table public.orders add constraint orders_money_non_negative
  check (subtotal >= 0 and discount_total >= 0 and shipping_total >= 0 and grand_total >= 0);

alter table public.orders drop constraint if exists orders_discount_within_subtotal;
alter table public.orders add constraint orders_discount_within_subtotal
  check (discount_total <= subtotal);

-- ---------------------------------------------------------------------------
-- 4. Fix the two functions that let a negative total through
--
-- Redefined in full (they are SECURITY DEFINER and their bodies are the
-- authority), identical to 0004 apart from the clamping noted inline.
-- ---------------------------------------------------------------------------
drop function if exists public.validate_promotion(text, jsonb);
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
set search_path = public, extensions
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
drop function if exists public.place_order(jsonb, text, jsonb, text);
-- place_order(items, promo_code, shipping_address, contact_email)
--
-- Atomic checkout. `p_items` = jsonb array of { variant_item_id, quantity }.
-- Every price, the discount, and the shipping charge are recomputed here; the
-- client supplies quantities and nothing else that touches money.
-- ---------------------------------------------------------------------------
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
set search_path = public, extensions
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
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'Cannot place an empty order';
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
-- Grants are dropped with the function, so restore them.
grant execute on function public.validate_promotion(text, jsonb) to anon, authenticated;
grant execute on function public.place_order(jsonb, text, jsonb, text) to anon, authenticated;
