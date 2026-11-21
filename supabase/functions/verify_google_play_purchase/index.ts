import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const packageName = Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME") ?? "";
const credentialsJson = Deno.env.get("GOOGLE_PLAY_CREDENTIALS") ?? "";
const supabase = createClient(supabaseUrl, serviceRoleKey);
const authClient = createClient(supabaseUrl, anonKey);

interface VerifyRequest {
  productId: string;
  purchaseToken: string;
}

interface GoogleCredentials {
  client_email: string;
  private_key: string;
  token_uri?: string;
}

interface GoogleLineItem {
  productId?: string;
  expiryTime?: string;
  autoRenewingPlan?: { autoRenewEnabled?: boolean };
}

interface GoogleSubscriptionPurchase {
  latestOrderId?: string;
  startTime?: string;
  subscriptionState?: string;
  lineItems?: GoogleLineItem[];
  testPurchase?: unknown;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function base64Url(value: Uint8Array | string): string {
  const bytes = typeof value === "string"
    ? new TextEncoder().encode(value)
    : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
}

async function googleAccessToken(credentials: GoogleCredentials) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(
    JSON.stringify({ alg: "RS256", typ: "JWT" }),
  );
  const payload = base64Url(
    JSON.stringify({
      iss: credentials.client_email,
      scope: "https://www.googleapis.com/auth/androidpublisher",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );
  const signingInput = `${header}.${payload}`;
  const pem = credentials.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const keyBytes = Uint8Array.from(atob(pem), (char) => char.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );
  const assertion = `${signingInput}.${base64Url(new Uint8Array(signature))}`;
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const data = await response.json();
  if (!response.ok || !data.access_token) {
    throw new Error(`Google OAuth failed: ${response.status}`);
  }
  return data.access_token as string;
}

async function verifySubscription(
  productId: string,
  purchaseToken: string,
): Promise<{ purchase: GoogleSubscriptionPurchase; environment: string }> {
  if (!packageName || !credentialsJson) {
    throw new Error("Google Play verification is not configured");
  }
  const credentials = JSON.parse(credentialsJson) as GoogleCredentials;
  const token = await googleAccessToken(credentials);
  const encodedToken = encodeURIComponent(purchaseToken);
  const response = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/subscriptionsv2/tokens/${encodedToken}`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  if (!response.ok) {
    return Promise.reject(
      new Error(`Google Play verification failed: ${response.status}`),
    );
  }
  const purchase = await response.json() as GoogleSubscriptionPurchase;
  const lineItem = purchase.lineItems?.find((item) =>
    item.productId === productId
  );
  if (!lineItem) {
    throw new Error("Product does not match the verified purchase");
  }
  if (
    purchase.subscriptionState !== "SUBSCRIPTION_STATE_ACTIVE" &&
    purchase.subscriptionState !== "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"
  ) {
    throw new Error("Subscription is not active");
  }
  return {
    purchase,
    environment: purchase.testPurchase ? "sandbox" : "production",
  };
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
    if (!body.productId || !body.purchaseToken) {
      return jsonResponse(
        { error: "Missing productId or purchaseToken", verified: false },
        400,
      );
    }

    const { purchase, environment } = await verifySubscription(
      body.productId,
      body.purchaseToken,
    );
    const lineItem = purchase.lineItems?.find((item) =>
      item.productId === body.productId
    );
    if (!lineItem?.expiryTime || !purchase.latestOrderId) {
      return jsonResponse(
        { error: "Incomplete Google Play purchase", verified: false },
        502,
      );
    }

    const { data, error } = await supabase.rpc(
      "apply_verified_store_event",
      {
        event: {
          user_id: authData.user.id,
          store: "google_play",
          environment,
          product_id: body.productId,
          transaction_id: purchase.latestOrderId,
          subscription_id: purchaseTokenIdentity(body.purchaseToken),
          event_id: purchase.latestOrderId,
          purchase_date: purchase.startTime,
          event_time: new Date().toISOString(),
          expires_at: lineItem.expiryTime,
          status: "verified",
          auto_renew: lineItem.autoRenewingPlan?.autoRenewEnabled ?? false,
          purchase_token: body.purchaseToken,
          verification_response: purchase,
        },
      },
    );
    if (error) {
      console.error("Failed to persist verified Google purchase", error);
      return jsonResponse(
        { error: "Failed to persist verified purchase", verified: false },
        500,
      );
    }

    return jsonResponse({
      verified: true,
      expiryDate: lineItem.expiryTime,
      subscription: data?.[0] ?? null,
    });
  } catch (error) {
    console.error("Google Play verification failed", error);
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Verification failed", verified: false },
      502,
    );
  }
});

function purchaseTokenIdentity(token: string): string {
  return token.length > 96
    ? `gp_${token.slice(0, 48)}_${token.slice(-48)}`
    : `gp_${token}`;
}
