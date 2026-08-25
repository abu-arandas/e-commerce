-- Behavioural tests for the hardened schema: promotions, stock, and ordering.
--
-- To run everything at once -- provisioning, schema/migration equivalence, the
-- client contract, and this suite -- use `supabase/tests/20_contract.sh`. To
-- run this file alone, read on.
--
-- Needs a database that already has 00_shim.sql, the schema, and seed.sql --
-- seed.sql is not optional, since the assertions below name promotion codes
-- and SKUs it creates. Either provisioning path works:
--
--   psql -v ON_ERROR_STOP=1 -d DB \
--     -f supabase/tests/00_shim.sql \
--     -f supabase/schema.sql \
--     -f supabase/seed.sql \
--     -f supabase/tests/10_tests.sql
--
-- ...or substitute migrations/0001..0006 in order for schema.sql; the two are
-- equivalent (see 20_contract.sh, which checks exactly that).
--
-- Safe to re-run against the same database: fixtures it creates are cleaned
-- up, and assertions are made relative to live counts rather than absolute
-- ones. Any failure raises, so a non-zero exit means a regression.
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

-- A customer may edit safe profile fields, but the public authenticated role
-- must not be able to alter the authorization-bearing role column.
insert into auth.users (id, email) values
  ('22222222-bbbb-4bbb-8bbb-222222222222', 'customer@vanguard.test')
  on conflict do nothing;
do $$
declare
  v_role public.app_role;
  v_rejected boolean := false;
begin
  set local role authenticated;
  perform set_config('request.jwt.claim.sub',
                     '22222222-bbbb-4bbb-8bbb-222222222222', true);
  begin
    update public.profiles set role = 'admin'
      where id = '22222222-bbbb-4bbb-8bbb-222222222222';
  exception when insufficient_privilege then
    v_rejected := true;
  end;
  reset role;
  select role into v_role from public.profiles
    where id = '22222222-bbbb-4bbb-8bbb-222222222222';
  perform assert_eq(v_rejected, true, 'customer role update rejected');
  perform assert_eq(v_role, 'customer'::public.app_role,
                    'customer role remains customer');
end $$;

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


-- ============================================================================
-- 8. The write paths 0007 closed stay closed, and the read exception it opened
--    is scoped to what the caller actually wishlisted.
--
--    These run as a real customer, not as the table owner: RLS is bypassed
--    entirely for a superuser, so a probe that forgets to drop privileges
--    reports "wide open" no matter what the policies say.
-- ============================================================================
do $$
declare
  v_customer uuid := '22222222-bbbb-4bbb-8bbb-222222222222';
  v_other    uuid := '33333333-cccc-4ccc-8ccc-333333333333';
  v_retired  uuid;
  v_unsaved  uuid;
  v_order    uuid;
  v_n        integer;
  v_err      text;
begin
  insert into auth.users (id, email) values
    (v_customer, 'shopper@vanguard.test'),
    (v_other,    'stranger@vanguard.test')
  on conflict do nothing;

  -- Two products taken off sale: one the shopper saved, one they did not.
  select id into v_retired from public.products order by created_at limit 1;
  select id into v_unsaved from public.products order by created_at offset 1 limit 1;
  update public.products set is_active = false where id in (v_retired, v_unsaved);
  insert into public.wishlists (user_id, product_id) values (v_customer, v_retired)
    on conflict do nothing;

  -- Become that customer for the rest of the block.
  perform set_config('request.jwt.claim.sub', v_customer::text, true);
  perform set_config('role', 'authenticated', true);
  set local role authenticated;

  -- --- the closed write paths -------------------------------------------
  begin
    insert into public.orders (user_id, subtotal, discount_total,
                               shipping_total, grand_total, status)
    values (v_customer, 0, 0, 0, 0, 'paid');
    raise exception 'FAIL direct order insert was accepted';
  exception when insufficient_privilege then
    perform assert_eq(true, true, 'customers cannot insert orders directly');
  when others then
    get stacked diagnostics v_err = message_text;
    if v_err like 'FAIL%' then raise; end if;
    perform assert_eq(v_err like '%row-level security%', true,
                      'customers cannot insert orders directly');
  end;

  begin
    insert into public.order_items (order_id, product_title, unit_price,
                                    quantity, line_total)
    values (gen_random_uuid(), 'forged', 1, 1, 1);
    raise exception 'FAIL direct order_items insert was accepted';
  exception when insufficient_privilege then
    perform assert_eq(true, true, 'customers cannot insert order lines directly');
  when others then
    get stacked diagnostics v_err = message_text;
    if v_err like 'FAIL%' then raise; end if;
    perform assert_eq(v_err like '%row-level security%', true,
                      'customers cannot insert order lines directly');
  end;

  -- --- the scoped read exception ----------------------------------------
  select count(*) into v_n from public.products where id = v_retired;
  perform assert_eq(v_n, 1, 'a retired product the shopper saved is readable');

  select count(*) into v_n from public.products where id = v_unsaved;
  perform assert_eq(v_n, 0, 'a retired product they did not save stays hidden');

  -- The variant tree resolves with it, otherwise the wishlist card is empty.
  select count(*) into v_n from public.variant_groups where product_id = v_retired;
  perform assert_eq(v_n > 0, true, 'its variant groups resolve too');

  select count(*) into v_n from public.variant_groups where product_id = v_unsaved;
  perform assert_eq(v_n, 0, 'variant groups of an unsaved retired product stay hidden');

  select count(*) into v_n from public.variant_items vi
    join public.variant_groups vg on vg.id = vi.group_id
   where vg.product_id = v_unsaved;
  perform assert_eq(v_n, 0, 'variant items of an unsaved retired product stay hidden');

  reset role;

  -- --- the accounting identity ------------------------------------------
  -- Written as the owner, so RLS is out of the way and the CHECK is what is
  -- actually under test.
  begin
    insert into public.orders (id, user_id, subtotal, discount_total,
                               shipping_total, grand_total)
    values (gen_random_uuid(), v_customer, 100, 10, 12, 999);
    raise exception 'FAIL inconsistent totals were accepted';
  exception when check_violation then
    perform assert_eq(true, true, 'grand_total must equal subtotal - discount + shipping');
  when others then
    get stacked diagnostics v_err = message_text;
    if v_err like 'FAIL%' then raise; end if;
    raise;
  end;

  -- The identity place_order actually produces is accepted.
  v_order := gen_random_uuid();
  insert into public.orders (id, user_id, subtotal, discount_total,
                             shipping_total, grand_total)
  values (v_order, v_customer, 100, 10, 12, 102);
  perform assert_eq(
    (select grand_total from public.orders where id = v_order), 102::numeric,
    'consistent totals are accepted');

  -- Put the fixtures back.
  delete from public.orders where id = v_order;
  delete from public.wishlists where user_id in (v_customer, v_other);
  update public.products set is_active = true where id in (v_retired, v_unsaved);
end $$;

select '=== ALL SQL TESTS PASSED ===' as result;
