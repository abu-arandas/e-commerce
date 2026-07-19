// Vanguard Fashion — Edge Function: validate-promo
// Thin, cache-friendly wrapper over the `validate_promotion` SQL function so the
// storefront can preview a promo code before checkout (PRD §4.1). Runs on Deno.
//
// Deploy:  supabase functions deploy validate-promo
// Invoke:  POST { code, subtotal, categories?: string[] }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface PromoRequest {
  code: string;
  subtotal: number;
  categories?: string[];
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ valid: false, reason: "Method not allowed" }, 405);
  }

  let body: PromoRequest;
  try {
    body = await req.json();
  } catch {
    return json({ valid: false, reason: "Invalid JSON body" }, 400);
  }

  const code = (body.code ?? "").trim();
  const subtotal = Number(body.subtotal ?? 0);
  const categories = Array.isArray(body.categories) ? body.categories : [];

  if (!code) {
    return json({ valid: false, reason: "Missing promo code" }, 400);
  }
  if (!Number.isFinite(subtotal) || subtotal < 0) {
    return json({ valid: false, reason: "Invalid subtotal" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    // Anon key is sufficient: validate_promotion is a stable, read-only function.
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );

  const { data, error } = await supabase.rpc("validate_promotion", {
    p_code: code,
    p_subtotal: subtotal,
    p_categories: categories,
  });

  if (error) {
    return json({ valid: false, reason: error.message }, 200);
  }

  return json(data, 200);
});

function json(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
