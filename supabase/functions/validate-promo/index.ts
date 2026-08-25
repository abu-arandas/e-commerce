// Vanguard Fashion — Edge Function: validate-promo
// Thin, cache-friendly wrapper over the `validate_promotion` SQL function so the
// storefront can preview a promo code before checkout (PRD §4.1). Runs on Deno.
//
// Deploy:  supabase functions deploy validate-promo
// Invoke:  POST { code, lines: [{ category, line_total }] }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const allowedOrigin = Deno.env.get("ALLOWED_ORIGIN") ?? "https://vanguard.fashion";
const corsHeaders = {
  "Access-Control-Allow-Origin": allowedOrigin,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
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
  const origin = req.headers.get("origin");
  if (origin !== null && origin !== allowedOrigin) {
    return json({ valid: false, reason: "Origin not allowed" }, 403);
  }

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ valid: false, reason: "Method not allowed" }, 405);
  }

  const contentLength = Number(req.headers.get("content-length") ?? 0);
  if (contentLength > 64 * 1024) {
    return json({ valid: false, reason: "Request is too large" }, 413);
  }

  let body: unknown;
  try {
    const raw = await req.text();
    if (new TextEncoder().encode(raw).byteLength > 64 * 1024) {
      return json({ valid: false, reason: "Request is too large" }, 413);
    }
    body = JSON.parse(raw);
  } catch {
    return json({ valid: false, reason: "Invalid JSON body" }, 400);
  }

  if (!isRecord(body)) {
    return json({ valid: false, reason: "Invalid request body" }, 400);
  }

  const code = typeof body.code === "string" ? body.code.trim() : "";
  const lines = Array.isArray(body.lines) ? body.lines : [];

  if (!code) {
    return json({ valid: false, reason: "Missing promo code" }, 400);
  }
  if (code.length > 100) {
    return json({ valid: false, reason: "Promo code is too long" }, 400);
  }
  if (lines.length > 100) {
    return json({ valid: false, reason: "Promotion basket is too large" }, 400);
  }
  if (lines.some((line) => !isPromoLine(line))) {
    return json({ valid: false, reason: "Invalid line total" }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) {
    console.error("validate-promo is missing Supabase runtime configuration");
    return json({ valid: false, reason: "Promotion validation unavailable" }, 503);
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });

  const { data, error } = await supabase.rpc("validate_promotion", {
    p_code: code,
    p_lines: lines.map((line) => ({
      category: line.category,
      line_total: line.line_total,
    })),
  });

  if (error) {
    console.error("validate-promo RPC failed", error);
    return json({ valid: false, reason: "Promotion validation failed" }, 503);
  }

  return json(data, 200);
});

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isPromoLine(value: unknown): value is PromoLine {
  if (!isRecord(value)) return false;
  const category = value.category;
  const lineTotal = value.line_total;
  return (
    (category === null || typeof category === "string") &&
    (category === null || category.length <= 100) &&
    typeof lineTotal === "number" &&
    Number.isFinite(lineTotal) &&
    lineTotal >= 0 &&
    lineTotal <= 99999999.99 &&
    Math.abs(lineTotal * 100 - Math.round(lineTotal * 100)) < 1e-7
  );
}

function json(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
