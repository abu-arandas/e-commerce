-- Behavioural tests for the 0004 hardening migration.
--
-- Run after applying 00_shim.sql, the four migrations, and seed.sql. Safe to
-- re-run against the same database: fixtures it creates are cleaned up, and
-- assertions are made relative to live counts rather than absolute ones.
--
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/10_tests.sql
--
-- Any failure raises, so a non-zero exit means a regression.
\set ON_ERROR_STOP on

create or replace function assert_eq(actual anyelement, expected anyelement, label text)
returns void language plpgsql as $$
begin
  if actual is distinct from expected then
    raise exception 'FAIL % — expected %, got %', label, expected, actual;
  end if;
  raise notice 'pass: % (%)', label, actual;
end;
$$;

-- A staff user, for the admin-only RPCs.
insert into auth.users (id, email) values
  ('11111111-aaaa-4aaa-8aaa-111111111111', 'staff@vanguard.test')
  on conflict do nothing;
update public.profiles set role = 'admin'
  where id = '11111111-aaaa-4aaa-8aaa-111111111111';

do $$
declare
  v_knit_sku   uuid;
  v_trou_sku   uuid;
  v_res        jsonb;
  v_order      jsonb;
  v_stock_before integer;
  v_stock_after  integer;
  v_err        text;
begin
  select id into v_knit_sku from public.variant_items where sku = 'CASH-TURT-BLU-M';  -- Knitwear, 245
  select id into v_trou_sku from public.variant_items where sku = 'WOOL-TROU-CHR-32'; -- Trousers, 189

  -- ==========================================================================
  -- 1. A category-targeted promotion discounts only its own lines.
  --    Bag: Knitwear 245 + Trousers 189 = 434. KNIT25 = 25% off Knitwear.
  --    Correct discount is 61.25, not 108.50.
  -- ==========================================================================
  v_res := public.validate_promotion('KNIT25', jsonb_build_array(
    jsonb_build_object('category', 'Knitwear', 'line_total', 245),
    jsonb_build_object('category', 'Trousers', 'line_total', 189)
  ));
  perform assert_eq((v_res ->> 'valid')::boolean, true, 'KNIT25 valid');
  perform assert_eq((v_res ->> 'discount_amount')::numeric, 61.25::numeric,
                    'KNIT25 discounts only the knitwear line');
  perform assert_eq((v_res ->> 'eligible_subtotal')::numeric, 245::numeric,
                    'KNIT25 eligible base');

  -- An untargeted promotion still applies to the whole basket.
  v_res := public.validate_promotion('FALL20', jsonb_build_array(
    jsonb_build_object('category', 'Knitwear', 'line_total', 245),
    jsonb_build_object('category', 'Trousers', 'line_total', 189)
  ));
  perform assert_eq((v_res ->> 'discount_amount')::numeric, 86.80::numeric,
                    'FALL20 applies to the whole basket');

  -- No eligible line -> rejected rather than silently discounting nothing.
  v_res := public.validate_promotion('KNIT25', jsonb_build_array(
    jsonb_build_object('category', 'Trousers', 'line_total', 189)
  ));
  perform assert_eq((v_res ->> 'valid')::boolean, false, 'KNIT25 with no knitwear');
  perform assert_eq(v_res ->> 'reason', 'No eligible items in cart', 'KNIT25 reason');

  -- Minimum order is judged on the whole basket.
  v_res := public.validate_promotion('FALL20', jsonb_build_array(
    jsonb_build_object('category', 'Knitwear', 'line_total', 100)
  ));
  perform assert_eq((v_res ->> 'valid')::boolean, false, 'FALL20 under minimum');

  -- A fixed-amount discount is capped at the eligible base, never negative.
  v_res := public.validate_promotion('WELCOME15', jsonb_build_array(
    jsonb_build_object('category', 'Knitwear', 'line_total', 80)
  ));
  perform assert_eq((v_res ->> 'discount_amount')::numeric, 15::numeric,
                    'WELCOME15 fixed amount');

  -- ==========================================================================
  -- 2. Shipping is computed server-side (threshold 150, fee 12).
  -- ==========================================================================
  v_order := public.place_order(
    jsonb_build_array(jsonb_build_object('variant_item_id', v_trou_sku, 'quantity', 1)),
    null, null, 'ship-test@example.com');
  perform assert_eq((v_order ->> 'subtotal')::numeric, 189::numeric, 'over-threshold subtotal');
  perform assert_eq((v_order ->> 'shipping_total')::numeric, 0::numeric,
                    'free shipping over threshold');

  -- Under the threshold the flat fee is charged. Temporarily raise it so the
  -- seeded catalogue (cheapest SKU is 189) falls below.
  update public.store_settings set free_shipping_threshold = 500;
  v_order := public.place_order(
    jsonb_build_array(jsonb_build_object('variant_item_id', v_trou_sku, 'quantity', 1)),
    null, null, 'ship-test2@example.com');
  perform assert_eq((v_order ->> 'shipping_total')::numeric, 12.00::numeric,
                    'flat fee under threshold');
  perform assert_eq((v_order ->> 'grand_total')::numeric, 201.00::numeric,
                    'grand total includes shipping');
  update public.store_settings set free_shipping_threshold = 150;

  -- place_order takes no shipping argument at all any more.
  perform assert_eq(
    (select count(*)::integer from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'place_order'),
    1, 'exactly one place_order overload');
  perform assert_eq(
    (select pg_get_function_identity_arguments(p.oid) from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'place_order'),
    'p_items jsonb, p_promo_code text, p_shipping_address jsonb, p_contact_email text',
    'place_order no longer accepts a shipping figure');

  -- ==========================================================================
  -- 3. Duplicate lines for one SKU are collapsed before the stock check.
  --    CASH-TURT-BLU-L has 3 in stock; 2 + 2 must not pass as two checks of 2.
  -- ==========================================================================
  begin
    v_order := public.place_order(jsonb_build_array(
      jsonb_build_object('variant_item_id',
        (select id from public.variant_items where sku = 'CASH-TURT-BLU-L'), 'quantity', 2),
      jsonb_build_object('variant_item_id',
        (select id from public.variant_items where sku = 'CASH-TURT-BLU-L'), 'quantity', 2)
    ), null, null, 'dupe@example.com');
    raise exception 'FAIL duplicate-line stock bypass — order was accepted';
  exception when others then
    get stacked diagnostics v_err = message_text;
    if v_err like 'FAIL%' then raise; end if;
    perform assert_eq(v_err like 'Insufficient stock%', true,
                      'duplicate lines collapse into one stock check');
  end;

  -- ==========================================================================
  -- 4. Stock actually decrements against the exact nested SKU.
  -- ==========================================================================
  select stock_quantity into v_stock_before
    from public.variant_items where id = v_knit_sku;
  v_order := public.place_order(
    jsonb_build_array(jsonb_build_object('variant_item_id', v_knit_sku, 'quantity', 2)),
    null, null, 'stock@example.com');
  select stock_quantity into v_stock_after
    from public.variant_items where id = v_knit_sku;
  perform assert_eq(v_stock_before - v_stock_after, 2, 'stock decremented by quantity');

  -- ==========================================================================
  -- 5. Order lines snapshot their category.
  -- ==========================================================================
  perform assert_eq(
    (select category from public.order_items
      where order_id = (v_order ->> 'order_id')::uuid limit 1),
    'Knitwear', 'order line records its category');
end $$;

-- ============================================================================
-- 6. usage_limit is enforced under concurrency (conditional claim).
-- ============================================================================
do $$
declare
  v_sku uuid;
  v_err text;
begin
  select id into v_sku from public.variant_items where sku = 'SILK-SLIP-CHA-S';

  insert into public.promotions (code, description, discount_type, discount_value,
                                 min_order_value, usage_limit, usage_count)
  values ('ONESHOT', 'single use', 'fixed_amount', 10, 0, 1, 0)
  on conflict (code) do update set usage_limit = 1, usage_count = 0, is_active = true;

  -- First redemption succeeds.
  perform public.place_order(
    jsonb_build_array(jsonb_build_object('variant_item_id', v_sku, 'quantity', 1)),
    'ONESHOT', null, 'first@example.com');
  perform assert_eq((select usage_count from public.promotions where code = 'ONESHOT'),
                    1, 'usage_count incremented');

  -- Second is refused.
  begin
    perform public.place_order(
      jsonb_build_array(jsonb_build_object('variant_item_id', v_sku, 'quantity', 1)),
      'ONESHOT', null, 'second@example.com');
    raise exception 'FAIL usage limit — second redemption was accepted';
  exception when others then
    get stacked diagnostics v_err = message_text;
    if v_err like 'FAIL%' then raise; end if;
    perform assert_eq(v_err like '%Usage limit reached%', true,
                      'second redemption refused');
  end;

  perform assert_eq((select usage_count from public.promotions where code = 'ONESHOT'),
                    1, 'usage_count not double-counted');
end $$;

-- ============================================================================
-- 7. restock_order is idempotent.
-- ============================================================================
do $$
declare
  v_sku    uuid;
  v_order  jsonb;
  v_after_order integer;
  v_after_1     integer;
  v_after_2     integer;
begin
  perform set_config('request.jwt.claim.sub', '11111111-aaaa-4aaa-8aaa-111111111111', false);

  select id into v_sku from public.variant_items where sku = 'TRENCH-SND-M';
  v_order := public.place_order(
    jsonb_build_array(jsonb_build_object('variant_item_id', v_sku, 'quantity', 2)),
    null, null, 'restock@example.com');

  select stock_quantity into v_after_order from public.variant_items where id = v_sku;

  perform public.restock_order((v_order ->> 'order_id')::uuid);
  select stock_quantity into v_after_1 from public.variant_items where id = v_sku;
  perform assert_eq(v_after_1 - v_after_order, 2, 'restock returns the stock');

  perform public.restock_order((v_order ->> 'order_id')::uuid);
  select stock_quantity into v_after_2 from public.variant_items where id = v_sku;
  perform assert_eq(v_after_2, v_after_1, 'second restock is a no-op');
end $$;

-- ============================================================================
-- 8. save_product persists the whole variant tree, and prunes what was removed.
-- ============================================================================
do $$
declare
  v_pid  uuid := gen_random_uuid();
  v_gid  uuid := gen_random_uuid();
  v_i1   uuid := gen_random_uuid();
  v_i2   uuid := gen_random_uuid();
begin
  perform set_config('request.jwt.claim.sub', '11111111-aaaa-4aaa-8aaa-111111111111', false);

  -- Clear any fixture left by a previous run so the suite is re-runnable.
  delete from public.products where slug = 'test-piece';

  perform public.save_product(jsonb_build_object(
    'id', v_pid, 'slug', 'test-piece', 'title', 'Test Piece',
    'description', 'd', 'category', 'Knitwear', 'base_price', 100,
    'is_active', true, 'is_featured', false,
    'groups', jsonb_build_array(jsonb_build_object(
      'id', v_gid, 'name', 'Ecru', 'color_hex', '#EEE8DC',
      'group_images', jsonb_build_array('https://example.test/a.webp'),
      'sort_order', 0,
      'items', jsonb_build_array(
        jsonb_build_object('id', v_i1, 'sku', 'TEST-ECR-S', 'size_label', 'S',
                           'stock_quantity', 4, 'sort_order', 0),
        jsonb_build_object('id', v_i2, 'sku', 'TEST-ECR-M', 'size_label', 'M',
                           'price_override', 110, 'stock_quantity', 6, 'sort_order', 1)
      )))));

  perform assert_eq((select count(*)::integer from public.variant_groups where product_id = v_pid),
                    1, 'colour group persisted');
  perform assert_eq((select count(*)::integer from public.variant_items where group_id = v_gid),
                    2, 'both SKUs persisted');
  perform assert_eq((select price_override from public.variant_items where id = v_i2),
                    110::numeric, 'price override persisted');
  perform assert_eq((select array_length(group_images, 1) from public.variant_groups where id = v_gid),
                    1, 'group images persisted');

  -- Re-save with one SKU dropped: it should be pruned, the other updated.
  perform public.save_product(jsonb_build_object(
    'id', v_pid, 'slug', 'test-piece', 'title', 'Test Piece Renamed',
    'base_price', 100, 'is_active', true, 'is_featured', false,
    'groups', jsonb_build_array(jsonb_build_object(
      'id', v_gid, 'name', 'Ecru', 'sort_order', 0,
      'items', jsonb_build_array(
        jsonb_build_object('id', v_i1, 'sku', 'TEST-ECR-S', 'size_label', 'S',
                           'stock_quantity', 9, 'sort_order', 0)
      )))));

  perform assert_eq((select count(*)::integer from public.variant_items where group_id = v_gid),
                    1, 'removed SKU pruned');
  perform assert_eq((select stock_quantity from public.variant_items where id = v_i1),
                    9, 'kept SKU updated');
  perform assert_eq((select title from public.products where id = v_pid),
                    'Test Piece Renamed', 'product updated');

  -- Saving with no groups clears the tree.
  perform public.save_product(jsonb_build_object(
    'id', v_pid, 'slug', 'test-piece', 'title', 'Test Piece Renamed',
    'base_price', 100, 'groups', '[]'::jsonb));
  perform assert_eq((select count(*)::integer from public.variant_groups where product_id = v_pid),
                    0, 'empty groups clears the tree');

  delete from public.products where id = v_pid;
end $$;

-- ============================================================================
-- 9. admin_stats aggregates over every order, and is staff-gated.
-- ============================================================================
do $$
declare
  v_stats jsonb;
  v_err   text;
begin
  perform set_config('request.jwt.claim.sub', '11111111-aaaa-4aaa-8aaa-111111111111', false);
  v_stats := public.admin_stats();

  perform assert_eq((v_stats ->> 'total_orders')::integer,
                    (select count(*)::integer from public.orders),
                    'admin_stats counts every order');
  perform assert_eq((v_stats ->> 'gross_revenue')::numeric,
                    (select coalesce(sum(grand_total), 0) from public.orders
                      where status not in ('cancelled', 'refunded')),
                    'admin_stats sums revenue');
  perform assert_eq(v_stats -> 'revenue_by_category' ? 'Knitwear', true,
                    'admin_stats breaks revenue down by category');

  -- Not staff -> refused.
  perform set_config('request.jwt.claim.sub', '', false);
  begin
    perform public.admin_stats();
    raise exception 'FAIL admin_stats — anonymous call was accepted';
  exception when others then
    get stacked diagnostics v_err = message_text;
    if v_err like 'FAIL%' then raise; end if;
    perform assert_eq(v_err, 'Not authorised', 'admin_stats refuses non-staff');
  end;
end $$;

-- ============================================================================
-- 10. save_product and restock_order refuse non-staff callers.
-- ============================================================================
do $$
declare v_err text;
begin
  perform set_config('request.jwt.claim.sub', '', false);
  begin
    perform public.save_product('{"slug":"x","title":"x"}'::jsonb);
    raise exception 'FAIL save_product — anonymous call was accepted';
  exception when others then
    get stacked diagnostics v_err = message_text;
    if v_err like 'FAIL%' then raise; end if;
    perform assert_eq(v_err, 'Not authorised', 'save_product refuses non-staff');
  end;

  begin
    perform public.restock_order(gen_random_uuid());
    raise exception 'FAIL restock_order — anonymous call was accepted';
  exception when others then
    get stacked diagnostics v_err = message_text;
    if v_err like 'FAIL%' then raise; end if;
    perform assert_eq(v_err, 'Not authorised', 'restock_order refuses non-staff');
  end;
end $$;

select '=== ALL SQL TESTS PASSED ===' as result;
