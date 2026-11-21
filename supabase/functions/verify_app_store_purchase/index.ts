import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const bundleId = Deno.env.get("APPLE_BUNDLE_ID") ?? "";
const sharedSecret = Deno.env.get("APPLE_SHARED_SECRET") ?? "";
const supabase = createClient(supabaseUrl, serviceRoleKey);
const authClient = createClient(supabaseUrl, anonKey);

interface VerifyRequest {
  productId: string;
  receiptData: string;
}

interface ReceiptItem {
  product_id: string;
  transaction_id: string;
  original_transaction_id: string;
  purchase_date_ms: string;
  expires_date_ms?: string;
  cancellation_date_ms?: string;
}

interface ReceiptResponse {
  status: number;
  environment?: string;
  receipt?: { bundle_id?: string };
  latest_receipt_info?: ReceiptItem[];
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function verifyAt(
  receiptData: string,
  sandbox: boolean,
): Promise<ReceiptResponse> {
  const host = sandbox
    ? "https://sandbox.itunes.apple.com/verifyReceipt"
    : "https://buy.itunes.apple.com/verifyReceipt";
  const response = await fetch(host, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      "receipt-data": receiptData,
      password: sharedSecret,
      "exclude-old-transactions": true,
    }),
  });
  if (!response.ok) {
    throw new Error(`Apple verification request failed: ${response.status}`);
  }
  return await response.json() as ReceiptResponse;
}

async function verifyReceipt(
  receiptData: string,
): Promise<{ response: ReceiptResponse; environment: "production" | "sandbox" }> {
  let response = await verifyAt(receiptData, false);
  let environment: "production" | "sandbox" = "production";
  if (response.status === 21007) {
    response = await verifyAt(receiptData, true);
    environment = "sandbox";
  }
  if (response.status === 21008) {
    response = await verifyAt(receiptData, false);
    environment = "production";
  }
  if (response.status !== 0) {
    throw new Error(`Apple receipt verification failed: ${response.status}`);
  }
  if (
    bundleId &&
    response.receipt?.bundle_id &&
    response.receipt.bundle_id !== bundleId
  ) {
    throw new Error("Bundle ID does not match the verified receipt");
  }
  return { response, environment };
}

serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }
  try {
    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) {
      return jsonResponse({ error: "Unauthorized", verified: false }, 401);
    }
    const token = authorization.slice(7);
    const { data: authData, error: authError } = await authClient.auth.getUser(
      token,
    );
    if (authError || !authData.user) {
      return jsonResponse({ error: "Unauthorized", verified: false }, 401);
    }

    const body = await request.json() as VerifyRequest;
    if (!body.productId || !body.receiptData) {
      return jsonResponse(
        { error: "Missing productId or receiptData", verified: false },
        400,
      );
    }
    if (!sharedSecret) {
      return jsonResponse(
        { error: "App Store verification is not configured", verified: false },
        503,
      );
    }

    const { response, environment } = await verifyReceipt(body.receiptData);
    const receipt = response.latest_receipt_info
      ?.filter((item) =>
        item.product_id === body.productId &&
        !item.cancellation_date_ms
      )
      .sort((left, right) =>
        Number(right.purchase_date_ms) - Number(left.purchase_date_ms)
      )[0];
    if (!receipt?.expires_date_ms || !receipt.transaction_id) {
      return jsonResponse(
        { error: "No active matching App Store subscription", verified: false },
        400,
      );
    }
    const expiresAt = new Date(Number(receipt.expires_date_ms)).toISOString();
    if (new Date(expiresAt).getTime() <= Date.now()) {
      return jsonResponse(
        { error: "Subscription is expired", verified: false },
        400,
      );
    }

    const { data, error } = await supabase.rpc(
      "apply_verified_store_event",
      {
        event: {
          user_id: authData.user.id,
          store: "app_store",
          environment,
          product_id: body.productId,
          transaction_id: receipt.transaction_id,
          subscription_id: receipt.original_transaction_id,
          event_id: receipt.transaction_id,
          purchase_date: new Date(
            Number(receipt.purchase_date_ms),
          ).toISOString(),
          event_time: new Date().toISOString(),
          expires_at: expiresAt,
          status: "verified",
          auto_renew: true,
          verification_response: response,
        },
      },
    );
    if (error) {
      console.error("Failed to persist verified Apple purchase", error);
      return jsonResponse(
        { error: "Failed to persist verified purchase", verified: false },
        500,
      );
    }

    return jsonResponse({
      verified: true,
      expiryDate: expiresAt,
      subscription: data?.[0] ?? null,
    });
  } catch (error) {
    console.error("App Store verification failed", error);
    return jsonResponse(
      {
        error: error instanceof Error ? error.message : "Verification failed",
        verified: false,
      },
      502,
    );
  }
});
