// supabase/functions/send-push-notification/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { create } from "https://deno.land/x/djwt@v2.8/mod.ts";

const FIREBASE_SERVICE_ACCOUNT = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") || "{}");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: any;
  schema: string;
  old_record: any | null;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const pemClean = pem
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");

  const binary = atob(pemClean);
  const buffer = new ArrayBuffer(binary.length);
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return buffer;
}

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: FIREBASE_SERVICE_ACCOUNT.client_email,
    sub: FIREBASE_SERVICE_ACCOUNT.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  const header = { alg: "RS256", typ: "JWT" };

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(FIREBASE_SERVICE_ACCOUNT.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const jwt = await create(header, payload, privateKey);

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

async function sendFCMNotification(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<any> {
  const accessToken = await getAccessToken();
  const projectId = FIREBASE_SERVICE_ACCOUNT.project_id;

  const fcmPayload = {
    message: {
      token: fcmToken,
      notification: { title, body },
      data,
      android: {
        priority: "high",
        notification: { sound: "default" },
      },
      apns: {
        payload: {
          aps: { sound: "default" },
        },
      },
    },
  };

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${accessToken}`,
      },
      body: JSON.stringify(fcmPayload),
    }
  );

  return await response.json();
}

serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();
    console.log("Received webhook:", JSON.stringify(payload, null, 2));

    if (payload.table !== "messages" || payload.type !== "INSERT") {
      return new Response(
        JSON.stringify({ success: true, skipped: true }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    const { conversation_id, sender_id, body: messageBody, id: message_id } = payload.record;

    if (!conversation_id || !sender_id) {
      console.log("Missing conversation_id or sender_id");
      return new Response(
        JSON.stringify({ success: false, error: "Missing required fields" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const convRes = await fetch(
      `${SUPABASE_URL}/rest/v1/conversations?id=eq.${conversation_id}&select=buyer_id,agent_id,property_id`,
      {
        headers: {
          "apikey": SUPABASE_SERVICE_KEY,
          "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`,
        },
      }
    );

    const conversations = await convRes.json();
    if (!conversations || conversations.length === 0) {
      console.log("Conversation not found:", conversation_id);
      return new Response(
        JSON.stringify({ success: false, error: "Conversation not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    const conversation = conversations[0];

    const recipientUserId =
      sender_id === conversation.buyer_id
        ? conversation.agent_id
        : conversation.buyer_id;

    console.log("Sender:", sender_id, "| Recipient:", recipientUserId);

    const profileRes = await fetch(
      `${SUPABASE_URL}/rest/v1/profiles?id=eq.${recipientUserId}&select=fcm_token,full_name`,
      {
        headers: {
          "apikey": SUPABASE_SERVICE_KEY,
          "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`,
        },
      }
    );

    const profiles = await profileRes.json();
    if (!profiles || profiles.length === 0 || !profiles[0].fcm_token) {
      console.log("No FCM token found for recipient:", recipientUserId);
      return new Response(
        JSON.stringify({ success: false, error: "No FCM token for recipient" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    const senderRes = await fetch(
      `${SUPABASE_URL}/rest/v1/profiles?id=eq.${sender_id}&select=full_name`,
      {
        headers: {
          "apikey": SUPABASE_SERVICE_KEY,
          "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`,
        },
      }
    );

    const senders = await senderRes.json();
    const senderName = senders?.[0]?.full_name ?? "Someone";

    const fcmToken = profiles[0].fcm_token;
    console.log("Sending notification to token:", fcmToken.substring(0, 20) + "...");

    const result = await sendFCMNotification(
      fcmToken,
      `New message from ${senderName}`,
      messageBody || "You have a new message",
      {
        type: "message",
        message_id: message_id ?? "",
        conversation_id: conversation_id ?? "",
        sender_id: sender_id ?? "",
        property_id: conversation.property_id ?? "",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      }
    );

    console.log("FCM result:", JSON.stringify(result, null, 2));

    if (result.error) {
      throw new Error(`FCM error: ${result.error.message}`);
    }

    return new Response(
      JSON.stringify({ success: true, fcm_result: result }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});