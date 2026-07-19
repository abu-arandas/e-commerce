-- ============================================================================
-- Vanguard Fashion — 0002 business-logic functions
-- Server-authoritative pricing, promo validation, and atomic checkout so the
-- exact nested SKU stock decrements when an order is placed (PRD §3.2).
-- ============================================================================

-- Role helper used by RLS policies (0003). SECURITY DEFINER so it can read the
-- caller's profile row without recursive RLS evaluation.
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

-- ---------------------------------------------------------------------------
-- validate_promotion(code, subtotal, categories[])
-- Pure validation used for cart preview AND inside place_order. Returns a jsonb
-- describing whether the promo applies and the resulting discount amount.
-- ---------------------------------------------------------------------------
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

  -- Category targeting: if included list is non-empty, at least one cart
  -- category must be included; excluded categories always disqualify.
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

-- ---------------------------------------------------------------------------
-- place_order(items, promo_code, shipping_address, contact_email, flat_shipping)
-- Atomic checkout. `p_items` = jsonb array of { variant_item_id, quantity }.
-- Prices are recomputed server-side; the client price is never trusted.
-- ---------------------------------------------------------------------------
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

  -- Header first so line items can FK to it.
  insert into public.orders (id, user_id, status, contact_email, shipping_address)
  values (v_order_id, auth.uid(), 'pending', p_contact_email, p_shipping_address);

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_variant_id := (v_item ->> 'variant_item_id')::uuid;
    v_qty        := (v_item ->> 'quantity')::integer;

    if v_qty is null or v_qty <= 0 then
      raise exception 'Invalid quantity for variant %', v_variant_id;
    end if;

    -- Lock the exact SKU row to serialise concurrent checkouts.
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

    -- Decrement the exact nested SKU stock.
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

  -- Apply promotion, if any.
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

-- Restock helper for cancellations/refunds (fulfillment tooling).
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
