// Vanguard Fashion — Edge Function: validate-promo
// Thin, cache-friendly wrapper over the `validate_promotion` SQL function so the
// storefront can preview a promo code before checkout (PRD §4.1). Runs on Deno.
//
// Deploy:  supabase functions deploy validate-promo
// Invoke:  POST { code, lines: [{ category, line_total }] }
//
// The endpoint is deliberately unauthenticated (guests price baskets too), so it
// is a promo-code oracle by design. Two things keep that acceptable:
//   * `validate_promotion` answers only for a code the caller already supplied —
//     since 0004 the promotions table is not readable in bulk, so codes cannot
//     be listed, only guessed.
//   * Guessing is rate-limited per client below.
//
// Configure `ALLOWED_ORIGINS` (comma-separated) to lock CORS to your storefront;
// it falls back to `*` for local development only.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface PromoLine {
  category?: string | null;
  line_total: number;
}

interface PromoRequest {
  code: string;
  lines?: PromoLine[];
}

const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);

function corsHeaders(origin: string | null): Record<string, string> {
  const allow = ALLOWED_ORIGINS.length === 0
    ? "*"
    : (origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0]);
  return {
    "Access-Control-Allow-Origin": allow,
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    ...(ALLOWED_ORIGINS.length > 0 ? { Vary: "Origin" } : {}),
  };
}

// ---------------------------------------------------------------------------
// Best-effort per-client rate limit.
//
// State is per-isolate, so this is a speed bump against code guessing rather
// than a hard guarantee — an edge deployment may run several isolates. Put a
// WAF or gateway limit in front of this for a stronger bound.
// ---------------------------------------------------------------------------
const WINDOW_MS = 60_000;
const MAX_PER_WINDOW = 20;
const hits = new Map<string, number[]>();

function rateLimited(key: string): boolean {
  const now = Date.now();
  const recent = (hits.get(key) ?? []).filter((t) => now - t < WINDOW_MS);
  recent.push(now);
  hits.set(key, recent);

  // Opportunistic cleanup so the map cannot grow without bound.
  if (hits.size > 10_000) {
    for (const [k, v] of hits) {
      if (v.every((t) => now - t >= WINDOW_MS)) hits.delete(k);
    }
  }
  return recent.length > MAX_PER_WINDOW;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const cors = corsHeaders(req.headers.get("Origin"));

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  if (req.method !== "POST") {
    return json({ valid: false, reason: "Method not allowed" }, 405, cors);
  }

  const client = req.headers.get("x-forwarded-for")?.split(",")[0].trim() ??
    "unknown";
  if (rateLimited(client)) {
    return json(
      { valid: false, reason: "Too many attempts. Please try again shortly." },
      429,
      { ...cors, "Retry-After": String(WINDOW_MS / 1000) },
    );
  }

  let body: PromoRequest;
  try {
    body = await req.json();
  } catch {
    return json({ valid: false, reason: "Invalid JSON body" }, 400, cors);
  }

  const code = (body.code ?? "").trim();
  if (!code) {
    return json({ valid: false, reason: "Missing promo code" }, 400, cors);
  }

  // Per-line totals, because a category-targeted promotion discounts only the
  // lines it targets — a single cart subtotal cannot express that.
  const rawLines = Array.isArray(body.lines) ? body.lines : [];
  const lines: PromoLine[] = [];
  for (const line of rawLines) {
    const total = Number(line?.line_total ?? 0);
    if (!Number.isFinite(total) || total < 0) {
      return json({ valid: false, reason: "Invalid line total" }, 400, cors);
    }
    const category = line?.category;
    lines.push({
      category: typeof category === "string" ? category : null,
      line_total: total,
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    // The publishable key is enough: validate_promotion is SECURITY DEFINER and
    // read-only, and returns nothing about a code beyond whether it applies.
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
      Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: {
        headers: { Authorization: req.headers.get("Authorization") ?? "" },
      },
    },
  );

  const { data, error } = await supabase.rpc("validate_promotion", {
    p_code: code,
    p_lines: lines,
  });

  if (error) {
    console.error("validate_promotion failed", error.message);
    // Don't echo the database error back to the caller.
    return json(
      { valid: false, reason: "Could not validate that code right now" },
      200,
      cors,
    );
  }

  return json(data, 200, cors);
});

function json(
  payload: unknown,
  status: number,
  cors: Record<string, string>,
): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
