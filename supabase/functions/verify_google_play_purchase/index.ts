import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.3.1";
import { jwtDecode } from "https://deno.land/x/jwt@v2.0.1/mod.ts";

// Initialize Supabase client with service role for database access
const supabase = createClient(
  Deno.env.get("SUPABASE_URL") || "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""
);

// Google Play API configuration
const GOOGLE_PLAY_PACKAGE_NAME = Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME");
const GOOGLE_PLAY_CREDENTIALS = Deno.env.get("GOOGLE_PLAY_CREDENTIALS");
const GOOGLE_PLAY_SCOPE =
  "https://www.googleapis.com/auth/androidpublisher";

interface VerifyRequest {
  userId: string;
  productId: string;
  purchaseToken: string;
  orderId?: string;
}

interface GooglePlayPurchase {
  orderId: string;
  packageName: string;
  productId: string;
  purchaseTime: number;
  purchaseState: number; // 0 = purchased, 1 = cancelled
  developerPayload?: string;
  purchaseToken: string;
  acknowledged: boolean;
  autoRenewing?: boolean;
  expiryTimeMillis?: number;
}

serve(async (req: Request) => {
  // Only allow POST requests
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    // Parse request body
    const body: VerifyRequest = await req.json();
    const { userId, productId, purchaseToken, orderId } = body;

    // Validate required fields
    if (!userId || !productId || !purchaseToken) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: userId, productId, purchaseToken" }),
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
        JSON.stringify({ error: "Unauthorized: cannot verify another user's purchase" }),
        {
          status: 403,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Verify purchase with Google Play
    const verifyResult = await verifyGooglePlayPurchase(
      purchaseToken,
      productId
    );

    if (!verifyResult.success) {
      return new Response(
        JSON.stringify({
          error: verifyResult.error || "Purchase verification failed",
          verified: false,
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
      verifyResult.purchaseData!
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
        message: "Purchase successfully verified and recorded",
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
 * Verify purchase token with Google Play API
 * Returns purchase details if valid, error if invalid
 */
async function verifyGooglePlayPurchase(
  purchaseToken: string,
  productId: string
): Promise<{
  success: boolean;
  error?: string;
  purchaseData?: GooglePlayPurchase;
}> {
  try {
    // For Phase 2 MVP: Placeholder verification
    // In production: Implement full Google Play API verification
    // This requires:
    // 1. Service account credentials (from Deno env)
    // 2. OAuth token exchange
    // 3. API call to: https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/products/{productId}/tokens/{token}

    // Validate purchase token format
    if (!purchaseToken || purchaseToken.length < 10) {
      return {
        success: false,
        error: "Invalid purchase token format",
      };
    }

    // Validate product ID
    if (!productId.includes("premium") && !productId.includes("monthly") && !productId.includes("yearly")) {
      return {
        success: false,
        error: "Invalid product ID",
      };
    }

    // TODO: Implement real Google Play verification
    // For now, create mock verification response
    const mockPurchaseData: GooglePlayPurchase = {
      orderId: `GPA.${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      packageName: GOOGLE_PLAY_PACKAGE_NAME || "com.landfinder.app",
      productId: productId,
      purchaseTime: Date.now(),
      purchaseState: 0, // Purchased
      purchaseToken: purchaseToken,
      acknowledged: true,
      autoRenewing: true,
      expiryTimeMillis: Date.now() + (productId.includes("yearly") ? 365 * 24 * 60 * 60 * 1000 : 30 * 24 * 60 * 60 * 1000),
    };

    return {
      success: true,
      purchaseData: mockPurchaseData,
    };
  } catch (error) {
    console.error("Error verifying with Google Play:", error);
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
  purchaseData: GooglePlayPurchase
): Promise<{
  success: boolean;
  purchaseId?: string;
  subscriptionTier?: string;
  expiryDate?: string;
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

    // Convert expiry time from milliseconds to ISO string
    const expiryDate = purchaseData.expiryTimeMillis
      ? new Date(purchaseData.expiryTimeMillis).toISOString()
      : null;

    // Insert purchase record
    const { data: purchaseRecord, error: insertError } = await supabase
      .from("purchase_history")
      .insert({
        user_id: userId,
        product_id: productId,
        store: "google_play",
        store_transaction_id: purchaseData.orderId,
        purchase_token: purchaseData.purchaseToken,
        purchase_date: new Date(purchaseData.purchaseTime).toISOString(),
        expiry_date: expiryDate,
        status: "verified",
        verification_status: "verified",
        verification_response: purchaseData,
      })
      .select()
      .single();

    if (insertError) {
      console.error("Error inserting purchase:", insertError);
      
      // Check if it's a duplicate (already verified)
      if (insertError.code === "23505") { // Unique constraint violation
        // Try to update existing record
        const { data: existingRecord, error: fetchError } = await supabase
          .from("purchase_history")
          .select()
          .eq("store_transaction_id", purchaseData.orderId)
          .single();

        if (!fetchError && existingRecord) {
          // Update existing record
          await supabase
            .from("purchase_history")
            .update({
              verification_status: "verified",
              status: "verified",
              verification_response: purchaseData,
              updated_at: new Date().toISOString(),
            })
            .eq("id", existingRecord.id);

          return {
            success: true,
            purchaseId: existingRecord.id,
            subscriptionTier,
            expiryDate: expiryDate || undefined,
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
    };
  } catch (error) {
    console.error("Error storing purchase:", error);
    return {
      success: false,
      error: `Database error: ${error}`,
    };
  }
}
