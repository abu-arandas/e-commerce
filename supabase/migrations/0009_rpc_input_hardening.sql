-- ============================================================================
-- 0009_rpc_input_hardening.sql
--
-- Bound public JSON inputs before expanding them, reject invalid money/quantity
-- encodings, and make SECURITY DEFINER functions use an explicit trusted path.
-- ============================================================================

alter table public.variant_items
  drop constraint if exists variant_items_low_stock_threshold_non_negative;
alter table public.variant_items
  drop constraint if exists variant_items_low_stock_threshold_check;
alter table public.variant_items
  add constraint variant_items_low_stock_threshold_check
  check (low_stock_threshold >= 0);

alter function public.handle_new_user()
  set search_path = pg_catalog, public, extensions, pg_temp;
alter function public.current_app_role()
  set search_path = pg_catalog, public, extensions, pg_temp;
alter function public.is_staff()
  set search_path = pg_catalog, public, extensions, pg_temp;
alter function public.variant_unit_price(uuid)
  set search_path = pg_catalog, public, extensions, pg_temp;
alter function public.restock_order(uuid)
  set search_path = pg_catalog, public, extensions, pg_temp;
alter function public.save_product(jsonb)
  set search_path = pg_catalog, public, extensions, pg_temp;
alter function public.admin_stats()
  set search_path = pg_catalog, public, extensions, pg_temp;

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

revoke execute on function public.validate_promotion(text, jsonb) from public;
grant execute on function public.validate_promotion(text, jsonb) to anon, authenticated;
revoke execute on function public.place_order(jsonb, text, jsonb, text) from public;
grant execute on function public.place_order(jsonb, text, jsonb, text) to anon, authenticated;
