import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { paymongoConfig, paymongoRequest } from "../_shared/paymongo.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const authClient = createClient(supabaseUrl, anonKey);
const supabase = createClient(supabaseUrl, serviceRoleKey);

interface CheckoutRequest {
  planId: string;
  paymentMethod: "gcash" | "qrph_gotyme" | "card";
  idempotencyKey: string;
}

function response(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (request) => {
  if (request.method !== "POST") return response({ error: "Method not allowed" }, 405);
  try {
    const bearer = request.headers.get("Authorization");
    if (!bearer?.startsWith("Bearer ")) return response({ error: "Unauthorized" }, 401);
    const { data: auth, error: authError } = await authClient.auth.getUser(
      bearer.slice(7),
    );
    if (authError || !auth.user) return response({ error: "Unauthorized" }, 401);

    const body = await request.json() as CheckoutRequest;
    if (!body.planId || !body.paymentMethod || !body.idempotencyKey) {
      return response({ error: "Invalid checkout request" }, 400);
    }

    const [{ data: settings }, { data: plan }] = await Promise.all([
      supabase.from("billing_settings").select("*").eq("id", true).single(),
      supabase.from("billing_plans").select("*").eq("id", body.planId).eq(
        "active",
        true,
      ).single(),
    ]);
    if (!settings?.external_checkout_enabled) {
      return response({ error: "External checkout is unavailable", code: "checkout_unavailable" }, 403);
    }
    if (!plan) return response({ error: "Plan unavailable" }, 404);

    const renewalMode = body.paymentMethod === "card" &&
        settings.card_recurring_enabled
      ? "paymongo_recurring"
      : "fixed_term";
    const methodEnabled = body.paymentMethod === "gcash"
      ? settings.gcash_enabled
      : body.paymentMethod === "qrph_gotyme"
      ? settings.qrph_enabled
      : settings.card_fixed_term_enabled || settings.card_recurring_enabled;
    if (!methodEnabled) return response({ error: "Payment method unavailable" }, 409);
    if (
      renewalMode === "paymongo_recurring"
    ) {
      return response({
        error: "Recurring PayMongo checkout requires account-specific setup",
        code: "recurring_not_configured",
      }, 501);
    }

    const referenceNumber = crypto.randomUUID();
    const { data: order, error: orderError } = await supabase
      .from("billing_orders")
      .insert({
        user_id: auth.user.id,
        plan_id: plan.id,
        provider: "paymongo",
        payment_method: body.paymentMethod,
        renewal_mode: renewalMode,
        idempotency_key: body.idempotencyKey,
        reference_number: referenceNumber,
        currency: plan.currency,
        amount_minor: plan.amount_minor,
        duration_days: plan.duration_days,
        expires_at: new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString(),
        status: "pending",
      })
      .select()
      .single();
    if (orderError) {
      const { data: existing } = await supabase.from("billing_orders")
        .select()
        .eq("user_id", auth.user.id)
        .eq("idempotency_key", body.idempotencyKey)
        .single();
      if (existing && existing.plan_id === plan.id &&
        existing.payment_method === body.paymentMethod) {
        return response({
          orderId: existing.id,
          checkoutUrl: existing.checkout_url,
          status: existing.status,
          reused: true,
        });
      }
      throw orderError;
    }

    const config = paymongoConfig();
    if (!config.checkoutSuccessUrl || !config.checkoutCancelUrl) {
      throw new Error("Checkout return URLs are not configured");
    }
    const paymongoMethod = body.paymentMethod === "qrph_gotyme"
      ? "qrph"
      : body.paymentMethod;
    const providerResponse = await paymongoRequest("/checkout_sessions", {
      data: {
        attributes: {
          send_email_receipt: true,
          billing: {},
          description: `${plan.title} subscription`,
          line_items: [{
            name: plan.title,
            quantity: 1,
            amount: plan.amount_minor,
            currency: plan.currency,
          }],
          payment_method_types: [paymongoMethod],
          reference_number: referenceNumber,
          metadata: {
            local_order_id: order.id,
            user_id: auth.user.id,
            plan_id: plan.id,
          },
          success_url: `${config.checkoutSuccessUrl}?order=${order.id}`,
          cancel_url: `${config.checkoutCancelUrl}?order=${order.id}`,
        },
      },
    });
    const providerData = await providerResponse.json();
    if (!providerResponse.ok) {
      await supabase.from("billing_orders").update({ status: "failed" })
        .eq("id", order.id);
      console.error("PayMongo checkout creation failed", providerData);
      return response({ error: "Unable to create checkout" }, 502);
    }
    const attributes = providerData.data?.attributes;
    const checkoutUrl = attributes?.checkout_url;
    if (!checkoutUrl) throw new Error("PayMongo returned no checkout URL");
    await supabase.from("billing_orders").update({
      provider_checkout_id: providerData.data.id,
      checkout_url: checkoutUrl,
      status: "awaiting_payment",
    }).eq("id", order.id);
    return response({
      orderId: order.id,
      checkoutUrl,
      status: "awaiting_payment",
      reuseAllowed: true,
    });
  } catch (error) {
    console.error("Checkout creation failed", error);
    return response({ error: "Checkout creation failed" }, 500);
  }
});
