export interface PayMongoConfig {
  secretKey: string;
  apiBaseUrl: string;
  webhookSecret: string;
  checkoutSuccessUrl: string;
  checkoutCancelUrl: string;
}

export function paymongoConfig(): PayMongoConfig {
  return {
    secretKey: Deno.env.get("PAYMONGO_SECRET_KEY") ?? "",
    apiBaseUrl: Deno.env.get("PAYMONGO_API_BASE_URL") ??
      "https://api.paymongo.com/v2",
    webhookSecret: Deno.env.get("PAYMONGO_WEBHOOK_SECRET") ?? "",
    checkoutSuccessUrl: Deno.env.get("PAYMONGO_SUCCESS_URL") ?? "",
    checkoutCancelUrl: Deno.env.get("PAYMONGO_CANCEL_URL") ?? "",
  };
}

export function basicAuth(secretKey: string): string {
  return `Basic ${btoa(`${secretKey}:`)}`;
}

export async function paymongoRequest(
  path: string,
  body: unknown,
): Promise<Response> {
  const config = paymongoConfig();
  if (!config.secretKey) throw new Error("PayMongo is not configured");
  return await fetch(`${config.apiBaseUrl}${path}`, {
    method: "POST",
    headers: {
      Authorization: basicAuth(config.secretKey),
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

export async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function verifySignature(
  rawBody: string,
  signatureHeader: string,
  secret: string,
): Promise<boolean> {
  if (!secret || !signatureHeader) return false;
  const parts = signatureHeader.split(",");
  const timestamp = parts.find((part) => part.trim().startsWith("t="))
    ?.split("=")[1]?.trim();
  const signatures = parts.flatMap((part) => {
    const normalized = part.trim();
    if (
      normalized.startsWith("te=") ||
      normalized.startsWith("li=") ||
      normalized.startsWith("v1=")
    ) {
      return [normalized.slice(normalized.indexOf("=") + 1)];
    }
    return [];
  });
  if (!timestamp || signatures.length === 0) return false;
  const age = Math.abs(Date.now() / 1000 - Number(timestamp));
  if (!Number.isFinite(age) || age > 300) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${timestamp}.${rawBody}`),
  );
  const computed = Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return signatures.some((signature) =>
    signature.length === computed.length && signature === computed
  );
}
