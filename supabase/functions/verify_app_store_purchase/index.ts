import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.3.1";
import { jwtDecode } from "https://deno.land/x/jwt@v2.0.1/mod.ts";

// Initialize Supabase client with service role for database access
const supabase = createClient(
  Deno.env.get("SUPABASE_URL") || "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""
);

// Apple StoreKit 2 configuration
const APPLE_BUNDLE_ID = Deno.env.get("APPLE_BUNDLE_ID");
const APPLE_APP_ID = Deno.env.get("APPLE_APP_ID");
const APPLE_SHARED_SECRET = Deno.env.get("APPLE_SHARED_SECRET");
const APP_STORE_SANDBOX_URL = "https://sandbox.itunes.apple.com/verifyReceipt";
const APP_STORE_PRODUCTION_URL = "https://buy.itunes.apple.com/verifyReceipt";

interface VerifyRequest {
  userId: string;
  productId: string;
  receiptData: string; // Base64 encoded receipt
  environment?: "sandbox" | "production";
}

interface AppStoreReceipt {
  bundle_id: string;
  application_version: string;
  original_purchase_date_pst: string;
  original_transaction_id: string;
  bvrs?: string;
  transaction_id: string;
  quantity: string;
  unique_identifier?: string;
  product_id: string;
  bvrs_mac?: string;
  bid?: string;
  purchase_date_ms: string;
  purchase_date: string;
  original_purchase_date_ms: string;
  original_purchase_date: string;
  unique_vendor_identifier?: string;
  item_id?: string;
  version_external_identifier?: string;
  web_order_line_item_id?: string;
  expires_date?: string;
  expires_date_ms?: string;
  expires_date_pst?: string;
  is_trial_period?: string;
  is_in_intro_offer_period?: string;
}

interface AppStoreVerifyResponse {
  receipt?: {
    in_app?: AppStoreReceipt[];
    bundle_id: string;
    application_version: string;
    version_external_identifier?: string;
    receipt_creation_date_ms: string;
    receipt_creation_date: string;
    receipt_type: string;
    adam_id?: number;
    app_item_id?: number;
    download_id?: number;
    request_date?: string;
    request_date_ms?: string;
    request_date_pst?: string;
  };
  latest_receipt?: string;
  latest_receipt_info?: AppStoreReceipt[];
  pending_renewal_info?: Array<{
    product_id: string;
    original_transaction_id: string;
    auto_renew_product_id?: string;
    auto_renew_status?: "1" | "0";
    renewal_date?: string;
    renewal_date_ms?: string;
    renewal_date_pst?: string;
    expiration_intent?: "1" | "2" | "3" | "4";
    is_in_billing_retry_period?: string;
    grace_period_expires_date?: string;
    grace_period_expires_date_ms?: string;
    grace_period_expires_date_pst?: string;
    price_consent_status?: string;
  }>;
  status: number; // 0 = valid, 21002+ = various errors
  environment?: "Production" | "Sandbox";
}

serve(async (req: Request) => {
  // Only allow POST requests
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    // Parse request body
    const body: VerifyRequest = await req.json();
    const { userId, productId, receiptData, environment = "production" } = body;

    // Validate required fields
    if (!userId || !productId || !receiptData) {
      return new Response(
        JSON.stringify({
          error: "Missing required fields: userId, productId, receiptData",
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Verify user is authenticated (extract from JWT)
    const authHeader = req.headers.get("authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const token = authHeader.substring(7);
    const decoded = jwtDecode(token);
    const authenticatedUserId = decoded.sub;

    // Security: Ensure user can only verify their own purchases
    if (authenticatedUserId !== userId) {
      return new Response(
        JSON.stringify({
          error: "Unauthorized: cannot verify another user's purchase",
        }),
        {
          status: 403,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Verify receipt with App Store
    const verifyResult = await verifyAppStoreReceipt(receiptData, environment);

    if (!verifyResult.success) {
      return new Response(
        JSON.stringify({
          error: verifyResult.error || "Receipt verification failed",
          verified: false,
          status: verifyResult.status,
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Store verified purchase in database
    const storeResult = await storePurchaseInDatabase(
      userId,
      productId,
      verifyResult.receiptData!,
      verifyResult.verifyResponse!
    );

    if (!storeResult.success) {
      return new Response(
        JSON.stringify({
          error: "Failed to store purchase record",
          verified: false,
        }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Success response
    return new Response(
      JSON.stringify({
        verified: true,
        purchaseId: storeResult.purchaseId,
        subscriptionTier: storeResult.subscriptionTier,
        expiryDate: storeResult.expiryDate,
        renewalStatus: storeResult.renewalStatus,
        message: "Receipt successfully verified and recorded",
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Verification error:", error);
    return new Response(
      JSON.stringify({
        error: "Internal server error",
        verified: false,
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});

/**
 * Verify receipt with Apple App Store
 */
async function verifyAppStoreReceipt(
  receiptData: string,
  environment: "sandbox" | "production"
): Promise<{
  success: boolean;
  error?: string;
  status?: number;
  receiptData?: AppStoreReceipt;
  verifyResponse?: AppStoreVerifyResponse;
}> {
  try {
    // Validate receipt data format
    if (!receiptData || receiptData.length < 100) {
      return {
        success: false,
        error: "Invalid receipt data format",
      };
    }

    // Determine which URL to use
    const verifyUrl =
      environment === "sandbox"
        ? APP_STORE_SANDBOX_URL
        : APP_STORE_PRODUCTION_URL;

    // Send receipt to Apple for verification
    const response = await fetch(verifyUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        "receipt-data": receiptData,
        password: APPLE_SHARED_SECRET,
      }),
    });

    if (!response.ok) {
      return {
        success: false,
        error: `App Store request failed: ${response.statusText}`,
        status: response.status,
      };
    }

    const verifyResponse: AppStoreVerifyResponse = await response.json();

    // Check App Store response status
    if (verifyResponse.status !== 0) {
      // Status codes: 0=valid, 21002=invalid data, 21005=receipt couldn't be authenticated, etc.
      let errorMessage = "Receipt verification failed";

      switch (verifyResponse.status) {
        case 21002:
          errorMessage = "Invalid receipt data";
          break;
        case 21005:
          errorMessage = "Receipt couldn't be authenticated";
          break;
        case 21007:
          errorMessage = "Receipt from sandbox environment (switch environments)";
          break;
        case 21008:
          errorMessage = "Receipt from production environment (switch environments)";
          break;
      }

      return {
        success: false,
        error: errorMessage,
        status: verifyResponse.status,
      };
    }

    // Extract the latest receipt info
    let latestReceipt: AppStoreReceipt | undefined;

    // For subscriptions, use latest_receipt_info
    if (
      verifyResponse.latest_receipt_info &&
      verifyResponse.latest_receipt_info.length > 0
    ) {
      // Sort by purchase date and get the most recent
      latestReceipt = verifyResponse.latest_receipt_info.sort(
        (a, b) =>
          parseInt(b.purchase_date_ms || "0") -
          parseInt(a.purchase_date_ms || "0")
      )[0];
    }

    // Fallback to in_app receipt
    if (!latestReceipt && verifyResponse.receipt?.in_app) {
      latestReceipt = verifyResponse.receipt.in_app.sort(
        (a, b) =>
          parseInt(b.purchase_date_ms || "0") -
          parseInt(a.purchase_date_ms || "0")
      )[0];
    }

    if (!latestReceipt) {
      return {
        success: false,
        error: "No valid receipt found in App Store response",
      };
    }

    // Validate bundle ID
    if (
      verifyResponse.receipt?.bundle_id !== APPLE_BUNDLE_ID &&
      APPLE_BUNDLE_ID
    ) {
      return {
        success: false,
        error: "Bundle ID mismatch",
      };
    }

    return {
      success: true,
      receiptData: latestReceipt,
      verifyResponse,
    };
  } catch (error) {
    console.error("Error verifying with App Store:", error);
    return {
      success: false,
      error: `Verification failed: ${error}`,
    };
  }
}

/**
 * Store verified purchase in Supabase database
 */
async function storePurchaseInDatabase(
  userId: string,
  productId: string,
  receiptData: AppStoreReceipt,
  verifyResponse: AppStoreVerifyResponse
): Promise<{
  success: boolean;
  purchaseId?: string;
  subscriptionTier?: string;
  expiryDate?: string;
  renewalStatus?: string;
  error?: string;
}> {
  try {
    // Determine subscription tier from product ID
    let subscriptionTier = "free";
    if (productId.includes("yearly")) {
      subscriptionTier = "yearly";
    } else if (productId.includes("monthly")) {
      subscriptionTier = "monthly";
    }

    // Extract expiry date from receipt
    const expiryDate = receiptData.expires_date_ms
      ? new Date(parseInt(receiptData.expires_date_ms)).toISOString()
      : null;

    // Check auto-renewal status from pending_renewal_info
    let renewalStatus = "unknown";
    if (verifyResponse.pending_renewal_info) {
      const renewalInfo = verifyResponse.pending_renewal_info.find(
        (info) => info.product_id === productId
      );
      if (renewalInfo) {
        renewalStatus = renewalInfo.auto_renew_status === "1" ? "active" : "cancelled";

        // Check expiration intent (reason for cancellation)
        if (renewalInfo.expiration_intent) {
          switch (renewalInfo.expiration_intent) {
            case "1":
              renewalStatus = "cancelled-by-user";
              break;
            case "2":
              renewalStatus = "cancelled-billing-issue";
              break;
            case "3":
              renewalStatus = "cancelled-price-increase";
              break;
            case "4":
              renewalStatus = "cancelled-product-unavailable";
              break;
          }
        }
      }
    }

    // Insert purchase record
    const { data: purchaseRecord, error: insertError } = await supabase
      .from("purchase_history")
      .insert({
        user_id: userId,
        product_id: productId,
        store: "app_store",
        store_transaction_id: receiptData.transaction_id,
        purchase_token: receiptData.transaction_id, // Use transaction ID as token for Apple
        purchase_date: new Date(
          parseInt(receiptData.purchase_date_ms || "0")
        ).toISOString(),
        expiry_date: expiryDate,
        status: "verified",
        verification_status: "verified",
        verification_response: verifyResponse,
      })
      .select()
      .single();

    if (insertError) {
      console.error("Error inserting purchase:", insertError);

      // Check if it's a duplicate (already verified)
      if (insertError.code === "23505") {
        // Unique constraint violation
        const { data: existingRecord, error: fetchError } = await supabase
          .from("purchase_history")
          .select()
          .eq("store_transaction_id", receiptData.transaction_id)
          .single();

        if (!fetchError && existingRecord) {
          // Update existing record
          await supabase
            .from("purchase_history")
            .update({
              verification_status: "verified",
              status: "verified",
              verification_response: verifyResponse,
              updated_at: new Date().toISOString(),
            })
            .eq("id", existingRecord.id);

          return {
            success: true,
            purchaseId: existingRecord.id,
            subscriptionTier,
            expiryDate: expiryDate || undefined,
            renewalStatus,
          };
        }
      }

      return {
        success: false,
        error: `Failed to store purchase: ${insertError.message}`,
      };
    }

    // Update user subscription
    const { error: updateError } = await supabase
      .from("subscriptions")
      .update({
        tier: subscriptionTier,
        status: "active",
        verified_purchase_id: purchaseRecord.id,
        last_verification_at: new Date().toISOString(),
        renewal_at: expiryDate,
      })
      .eq("user_id", userId);

    if (updateError) {
      console.error("Error updating subscription:", updateError);
      return {
        success: false,
        error: `Failed to update subscription: ${updateError.message}`,
      };
    }

    return {
      success: true,
      purchaseId: purchaseRecord.id,
      subscriptionTier,
      expiryDate: expiryDate || undefined,
      renewalStatus,
    };
  } catch (error) {
    console.error("Error storing purchase:", error);
    return {
      success: false,
      error: `Database error: ${error}`,
    };
  }
}
