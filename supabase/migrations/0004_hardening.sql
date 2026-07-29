-- ============================================================================
-- Vanguard Fashion — 0004 correctness & security hardening
--
-- Supersedes the `validate_promotion`, `place_order` and `restock_order`
-- definitions in 0002, and the promotions/orders policies in 0003. Written to
-- be safe whether or not those migrations have already been applied.
--
-- What changes and why:
--   1. Shipping is computed server-side from `store_settings`. It used to be a
--      client-supplied argument, so any caller could pass 0 and ship free.
--   2. A category-targeted promotion now discounts only the lines in those
--      categories. It used to apply its percentage to the whole subtotal, so
--      "25% off knitwear" also took 25% off the trousers in the same bag.
--   3. `usage_limit` is claimed atomically. Validate-then-increment let two
--      concurrent checkouts both pass a limit-1 code.
--   4. SKU row locks are taken in a deterministic order, and duplicate lines in
--      one payload are collapsed, removing a deadlock and a stock-check bypass.
--   5. `restock_order` is idempotent, so cancel → refund cannot double-credit.
--   6. Promo codes are no longer readable in bulk by anonymous clients.
--   7. New `save_product` RPC persists a product with its whole variant tree,
--      and `admin_stats` aggregates dashboard figures in the database.
--
-- SECURITY DEFINER functions pin `search_path = public, extensions` so they
-- resolve `citext` regardless of which schema the extension lives in.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Store settings — the authoritative source for shipping figures.
-- Single row, enforced by a boolean primary key that can only ever be true.
-- ---------------------------------------------------------------------------
create table if not exists public.store_settings (
  id                      boolean primary key default true check (id),
  flat_shipping_fee       numeric(10, 2) not null default 12.00
                            check (flat_shipping_fee >= 0),
  free_shipping_threshold numeric(10, 2) not null default 150.00
                            check (free_shipping_threshold >= 0),
  updated_at              timestamptz not null default now()
);

insert into public.store_settings (id) values (true) on conflict (id) do nothing;

drop trigger if exists trg_store_settings_updated on public.store_settings;
create trigger trg_store_settings_updated before update on public.store_settings
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Schema additions
-- ---------------------------------------------------------------------------

-- Category snapshot on the order line, so revenue reporting survives a product
-- being re-categorised, renamed, or deleted. Reporting used to join back to the
-- live catalog by product *title*.
alter table public.order_items add column if not exists category text;

update public.order_items oi
   set category = p.category
  from public.variant_items vi
  join public.variant_groups vg on vg.id = vi.group_id
  join public.products p on p.id = vg.product_id
 where oi.variant_item_id = vi.id
   and oi.category is null;

-- Restock bookkeeping, so returning stock to the shelf is idempotent.
alter table public.orders add column if not exists restocked_at timestamptz;

create index if not exists order_items_category_idx
  on public.order_items (category);

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
      v_discount := round(v_eligible * (promo.discount_value / 100.0), 2);
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

  v_grand := round(v_subtotal - v_discount + v_shipping, 2);

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
set search_path = public, extensions
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
set search_path = public, extensions
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
set search_path = public, extensions
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

-- ---------------------------------------------------------------------------
-- Row-Level Security corrections
-- ---------------------------------------------------------------------------

alter table public.store_settings enable row level security;

drop policy if exists store_settings_read on public.store_settings;
create policy store_settings_read on public.store_settings
  for select using (true);   -- shipping figures are shown on the storefront

drop policy if exists store_settings_write on public.store_settings;
create policy store_settings_write on public.store_settings
  for all using (public.is_staff()) with check (public.is_staff());

-- Promo codes are no longer bulk-readable. The previous policy exposed every
-- active row to anonymous clients, so the whole discount list could be dumped
-- with a single select. Redemption goes through validate_promotion(), which is
-- SECURITY DEFINER and answers only for a code the caller already knows.
drop policy if exists promotions_read on public.promotions;
create policy promotions_read on public.promotions
  for select using (public.is_staff());

-- Direct order inserts are for signed-in shoppers only. The old policy allowed
-- `user_id is null`, letting anyone write arbitrary order rows with any totals.
-- Guest checkout is unaffected: it goes through place_order().
drop policy if exists orders_insert on public.orders;
create policy orders_insert on public.orders
  for insert with check (auth.uid() is not null and user_id = auth.uid());

drop policy if exists order_items_insert on public.order_items;
create policy order_items_insert on public.order_items
  for insert with check (
    public.is_staff()
    or exists (
      select 1 from public.orders o
       where o.id = order_id
         and auth.uid() is not null
         and o.user_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- Execute grants — staff-only RPCs should not even be callable anonymously.
-- ---------------------------------------------------------------------------
revoke execute on function public.save_product(jsonb) from public, anon;
revoke execute on function public.admin_stats() from public, anon;
revoke execute on function public.restock_order(uuid) from public, anon;

grant execute on function public.save_product(jsonb) to authenticated;
grant execute on function public.admin_stats() to authenticated;
grant execute on function public.restock_order(uuid) to authenticated;

-- Storefront-facing: guests must be able to price a basket and check out.
grant execute on function public.validate_promotion(text, jsonb) to anon, authenticated;
grant execute on function public.place_order(jsonb, text, jsonb, text) to anon, authenticated;
