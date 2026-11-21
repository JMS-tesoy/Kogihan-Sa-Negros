import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const authClient = createClient(supabaseUrl, anonKey);
const serviceClient = createClient(
  supabaseUrl,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const bearer = request.headers.get("Authorization");
  if (!bearer?.startsWith("Bearer ")) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }
  const { data: auth, error } = await authClient.auth.getUser(bearer.slice(7));
  if (error || !auth.user) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }
  const body = await request.json();
  const { data, error: queryError } = await serviceClient
    .from("billing_orders")
    .select(
      "id,status,payment_method,renewal_mode,currency,amount_minor,entitlement_until,paid_at,expires_at,created_at",
    )
    .eq("id", body.orderId)
    .eq("user_id", auth.user.id)
    .single();
  if (queryError || !data) {
    return Response.json({ error: "Order not found" }, { status: 404 });
  }
  return Response.json({ order: data });
});
