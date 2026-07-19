-- ============================================================================
-- Vanguard Fashion — seed data
-- Demo catalog exercising the full Product → Color → Size hierarchy plus a set
-- of promotions covering every discount type. Safe to re-run (idempotent upserts).
-- Image URLs are illustrative Supabase Storage CDN paths (.webp per PRD §6.1).
-- ============================================================================

-- ---- Products ----
insert into public.products (id, slug, title, description, category, base_price, is_active, is_featured)
values
  ('11111111-1111-1111-1111-111111111111', 'cashmere-turtleneck',
   'Cashmere Turtleneck',
   'A whisper-soft grade-A Mongolian cashmere turtleneck with a relaxed, elongated silhouette. Fully fashioned seams and a ribbed funnel neck.',
   'Knitwear', 245.00, true, true),
  ('22222222-2222-2222-2222-222222222222', 'tailored-wool-trouser',
   'Tailored Wool Trouser',
   'Italian virgin-wool trousers with a mid-rise waist, pressed crease, and tapered ankle. Sartorial by day, effortless by night.',
   'Trousers', 189.00, true, true),
  ('33333333-3333-3333-3333-333333333333', 'silk-slip-dress',
   'Bias-Cut Silk Slip Dress',
   '100% mulberry silk cut on the bias to skim the body. Adjustable straps and a cowl neckline.',
   'Dresses', 320.00, true, true),
  ('44444444-4444-4444-4444-444444444444', 'structured-trench',
   'Structured Cotton Trench',
   'A water-resistant cotton-gabardine trench with storm flaps, a removable belt, and horn buttons.',
   'Outerwear', 410.00, true, false)
on conflict (id) do update set
  title = excluded.title, description = excluded.description,
  category = excluded.category, base_price = excluded.base_price;

-- ---- Variant groups (Level 1: Color) ----
insert into public.variant_groups (id, product_id, name, color_hex, group_images, sort_order)
values
  ('a1000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'Midnight Blue', '#1E2A44',
   array['https://YOUR_PROJECT.supabase.co/storage/v1/object/public/products/cashmere/midnight-1.webp',
         'https://YOUR_PROJECT.supabase.co/storage/v1/object/public/products/cashmere/midnight-2.webp'], 0),
  ('a1000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   'Crimson', '#8C1C2B',
   array['https://YOUR_PROJECT.supabase.co/storage/v1/object/public/products/cashmere/crimson-1.webp'], 1),
  ('a1000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
   'Oatmeal', '#D8CDB8',
   array['https://YOUR_PROJECT.supabase.co/storage/v1/object/public/products/cashmere/oatmeal-1.webp'], 2),

  ('a2000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222',
   'Charcoal', '#36373B',
   array['https://YOUR_PROJECT.supabase.co/storage/v1/object/public/products/trouser/charcoal-1.webp'], 0),
  ('a2000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222',
   'Camel', '#C19A6B',
   array['https://YOUR_PROJECT.supabase.co/storage/v1/object/public/products/trouser/camel-1.webp'], 1),

  ('a3000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333',
   'Champagne', '#E7D3B3',
   array['https://YOUR_PROJECT.supabase.co/storage/v1/object/public/products/slip/champagne-1.webp'], 0),
  ('a3000000-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333',
   'Onyx', '#14141A',
   array['https://YOUR_PROJECT.supabase.co/storage/v1/object/public/products/slip/onyx-1.webp'], 1),

  ('a4000000-0000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444',
   'Sand', '#C9B79C',
   array['https://YOUR_PROJECT.supabase.co/storage/v1/object/public/products/trench/sand-1.webp'], 0)
on conflict (id) do update set
  name = excluded.name, color_hex = excluded.color_hex, group_images = excluded.group_images;

-- ---- Variant items (Level 2: Size / final SKU) ----
insert into public.variant_items (group_id, sku, size_label, price_override, stock_quantity, sort_order)
values
  -- Cashmere / Midnight Blue
  ('a1000000-0000-0000-0000-000000000001', 'CASH-TURT-BLU-S',  'S',  null, 12, 0),
  ('a1000000-0000-0000-0000-000000000001', 'CASH-TURT-BLU-M',  'M',  null, 8,  1),
  ('a1000000-0000-0000-0000-000000000001', 'CASH-TURT-BLU-L',  'L',  null, 3,  2),
  ('a1000000-0000-0000-0000-000000000001', 'CASH-TURT-BLU-XL', 'XL', 255.00, 0, 3),
  -- Cashmere / Crimson
  ('a1000000-0000-0000-0000-000000000002', 'CASH-TURT-CRM-S',  'S',  null, 5,  0),
  ('a1000000-0000-0000-0000-000000000002', 'CASH-TURT-CRM-M',  'M',  null, 9,  1),
  ('a1000000-0000-0000-0000-000000000002', 'CASH-TURT-CRM-L',  'L',  null, 6,  2),
  -- Cashmere / Oatmeal
  ('a1000000-0000-0000-0000-000000000003', 'CASH-TURT-OAT-M',  'M',  null, 14, 0),
  ('a1000000-0000-0000-0000-000000000003', 'CASH-TURT-OAT-L',  'L',  null, 11, 1),

  -- Trouser / Charcoal
  ('a2000000-0000-0000-0000-000000000001', 'WOOL-TROU-CHR-30', '30', null, 10, 0),
  ('a2000000-0000-0000-0000-000000000001', 'WOOL-TROU-CHR-32', '32', null, 7,  1),
  ('a2000000-0000-0000-0000-000000000001', 'WOOL-TROU-CHR-34', '34', null, 4,  2),
  -- Trouser / Camel
  ('a2000000-0000-0000-0000-000000000002', 'WOOL-TROU-CAM-32', '32', null, 6,  0),
  ('a2000000-0000-0000-0000-000000000002', 'WOOL-TROU-CAM-34', '34', null, 2,  1),

  -- Slip dress / Champagne
  ('a3000000-0000-0000-0000-000000000001', 'SILK-SLIP-CHA-XS', 'XS', null, 6, 0),
  ('a3000000-0000-0000-0000-000000000001', 'SILK-SLIP-CHA-S',  'S',  null, 9, 1),
  ('a3000000-0000-0000-0000-000000000001', 'SILK-SLIP-CHA-M',  'M',  null, 5, 2),
  -- Slip dress / Onyx
  ('a3000000-0000-0000-0000-000000000002', 'SILK-SLIP-ONX-S',  'S',  null, 8, 0),
  ('a3000000-0000-0000-0000-000000000002', 'SILK-SLIP-ONX-M',  'M',  null, 7, 1),

  -- Trench / Sand
  ('a4000000-0000-0000-0000-000000000001', 'TRENCH-SND-S', 'S', null, 4, 0),
  ('a4000000-0000-0000-0000-000000000001', 'TRENCH-SND-M', 'M', null, 5, 1),
  ('a4000000-0000-0000-0000-000000000001', 'TRENCH-SND-L', 'L', null, 3, 2)
on conflict (sku) do update set
  stock_quantity = excluded.stock_quantity, price_override = excluded.price_override;

-- ---- Promotions (every discount type) ----
insert into public.promotions
  (code, description, discount_type, discount_value, min_order_value, usage_limit,
   included_categories, valid_from, valid_until)
values
  ('FALL20',   '20% off orders over $150',        'percentage',    20, 150, null, '{}',          now() - interval '1 day', now() + interval '60 days'),
  ('WELCOME15','$15 off your first order',        'fixed_amount',  15, 75,  1000, '{}',          now() - interval '1 day', now() + interval '365 days'),
  ('FREESHIP', 'Free shipping over $100',         'free_shipping', 0,  100, null, '{}',          now() - interval '1 day', now() + interval '30 days'),
  ('KNIT25',   '25% off all knitwear',            'percentage',    25, 0,   null, '{Knitwear}',  now() - interval '1 day', now() + interval '14 days')
on conflict (code) do update set
  description = excluded.description, discount_type = excluded.discount_type,
  discount_value = excluded.discount_value, min_order_value = excluded.min_order_value,
  valid_until = excluded.valid_until, is_active = true;
