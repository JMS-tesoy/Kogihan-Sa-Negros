import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import {
  paymongoConfig,
  sha256,
  verifySignature,
} from "../_shared/paymongo.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  try {
    const rawBody = await request.text();
    const config = paymongoConfig();
    const signature = request.headers.get("Paymongo-Signature") ?? "";
    if (!await verifySignature(rawBody, signature, config.webhookSecret)) {
      return Response.json({ error: "Invalid signature" }, { status: 401 });
    }
    const payload = JSON.parse(rawBody);
    const event = payload.data;
    const attributes = event?.attributes ?? {};
    const providerResource = attributes.data;
    const resourceAttributes = providerResource?.attributes;
    const eventId = event?.id;
    const eventType = attributes.type ?? attributes.event_type ?? "";
    if (!eventId || !providerResource || !resourceAttributes) {
      return Response.json({ error: "Invalid event" }, { status: 400 });
    }

    const isCheckoutPaid =
      eventType === "checkout_session.payment.paid" &&
      providerResource.type === "checkout_session";
    const paymentIntent = resourceAttributes.payment_intent;
    const payment = isCheckoutPaid
      ? {
        id: paymentIntent?.id,
        amount: paymentIntent?.attributes?.amount,
        currency: paymentIntent?.attributes?.currency,
        metadata: resourceAttributes.metadata ??
          paymentIntent?.attributes?.metadata ?? {},
        status: "paid",
      }
      : {
        id: providerResource.id,
        amount: resourceAttributes.amount,
        currency: resourceAttributes.currency,
        metadata: resourceAttributes.metadata ?? {},
        status: resourceAttributes.status,
      };
    if (!payment.id || !payment.amount || !payment.currency) {
      return Response.json({ error: "Invalid payment resource" }, { status: 400 });
    }
    const orderId = payment.metadata.local_order_id ?? payment.metadata.order_id;
    if (!orderId) {
      return Response.json({ error: "Missing order reference" }, { status: 400 });
    }

    const paymentStatus = String(payment.status ?? "").toLowerCase();
    const status = paymentStatus === "paid"
      ? "paid"
      : paymentStatus === "refunded"
      ? "refunded"
      : paymentStatus === "cancelled" || paymentStatus === "canceled"
      ? "cancelled"
      : "failed";
    const normalized = {
      event_id: eventId,
      event_type: eventType,
      event_time: attributes.created_at
        ? new Date(attributes.created_at * 1000).toISOString()
        : new Date().toISOString(),
      order_id: orderId,
      payment_id: payment.id,
      amount_minor: payment.amount,
      currency: payment.currency,
      status,
      raw_body_hash: await sha256(rawBody),
    };
    const { error } = await supabase.rpc("apply_paymongo_event", {
      event: normalized,
    });
    if (error) {
      console.error("PayMongo event processing failed", error);
      return Response.json({ error: "Event processing failed" }, { status: 503 });
    }
    return Response.json({ received: true });
  } catch (error) {
    console.error("PayMongo webhook failed", error);
    return Response.json({ error: "Webhook failed" }, { status: 500 });
  }
});
