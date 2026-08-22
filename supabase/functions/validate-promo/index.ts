// Vanguard Fashion — Edge Function: validate-promo
// Thin, cache-friendly wrapper over the `validate_promotion` SQL function so the
// storefront can preview a promo code before checkout (PRD §4.1). Runs on Deno.
//
// Deploy:  supabase functions deploy validate-promo
// Invoke:  POST { code, lines: [{ category, line_total }] }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": Deno.env.get("ALLOWED_ORIGIN") ?? "",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface PromoLine {
  category: string | null;
  line_total: number;
}

interface PromoRequest {
  code: string;
  lines?: PromoLine[];
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
  const lines = Array.isArray(body.lines) ? body.lines : [];

  if (!code) {
    return json({ valid: false, reason: "Missing promo code" }, 400);
  }
  // A category-targeted promotion discounts only the lines it covers, so the
  // basket is sent line by line rather than as a single subtotal.
  if (lines.some((l) => !Number.isFinite(Number(l?.line_total)) || Number(l.line_total) < 0)) {
    return json({ valid: false, reason: "Invalid line total" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    // Anon key is sufficient: validate_promotion is a stable, read-only function.
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );

  const { data, error } = await supabase.rpc("validate_promotion", {
    p_code: code,
    p_lines: lines.map((l) => ({
      category: l.category ?? null,
      line_total: Number(l.line_total),
    })),
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
