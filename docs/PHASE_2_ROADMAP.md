# 📱 Phase 2: Real Billing Integration - Implementation Roadmap

**Status:** 🚀 Starting Now  
**Focus:** Android (Google Play) + iOS (App Store) support  
**Timeline:** 3-4 hours for complete implementation  
**Deployment:** After Phase 1 is stable (24-48 hours)

---

## 🎯 Phase 2 Objectives

Transform the subscription system from a mock/placeholder into a real, production-grade billing system with:

✅ Real payment processing (Google Play + App Store)  
✅ Secure backend receipt verification  
✅ Server-authoritative entitlement management  
✅ Subscription tier enforcement via RLS  
✅ Transaction history and audit trail  
✅ Refund/cancellation handling  
✅ Error recovery and retry logic  

---

## 📊 Current State vs Phase 2

| Component | Phase 1 | Phase 2 |
|-----------|---------|---------|
| **Data Model** | ✅ Exists (free/monthly/yearly) | 🔧 Enhance (add transaction fields) |
| **UI Screens** | ✅ PlansScreen exists | 🔧 Add PurchaseFlow, Success screen |
| **Local Datasource** | ✅ Mocked | 🔧 Real SharedPreferences |
| **Remote Datasource** | ❌ Stub (throws error) | 🔧 Real Supabase + verification |
| **Payment SDK** | ❌ Not integrated | 🔧 Google Play + StoreKit |
| **Backend Verification** | ❌ Not implemented | 🔧 Supabase Edge Functions |
| **Receipt Storage** | ❌ No transaction records | 🔧 purchase_history table |
| **Entitlement Enforcement** | ✅ RLS ready (from Phase 1) | 🔧 Activated + tested |

---

## 🔄 Implementation Flow

```
User Taps "Subscribe"
│
├─→ Load Store Products (Google Play/App Store)
│
├─→ Initiate Purchase Flow (IAP SDK)
│
├─→ User Completes Payment
│
├─→ Receive Purchase Token/Receipt
│
├─→ Call Supabase Edge Function for Verification
│
├─→ Edge Function Validates Receipt with Store
│
├─→ Update Database (subscription + purchase_history)
│
├─→ Return Verified Entitlement to App
│
├─→ Update Local Cache
│
└─→ Show Success Screen → Home Page

If anything fails at any step:
  → Retry with exponential backoff
  → Show specific error message
  → Provide actionable next steps
```

---

## 📋 Detailed Tasks (In Order)

### Phase 2.1: Packages & Configuration (30 min)

**Files to Create/Update:**

1. ✅ Update `pubspec.yaml`
   - Add: `in_app_purchase: ^0.8.0`
   - Add: `in_app_purchase_android: ^0.4.0`
   - Add: `in_app_purchase_storekit_2: ^0.2.0`

2. ✅ Create `.env` entries for product IDs
   ```
   GOOGLE_PLAY_MONTHLY_SKU=land_finder_monthly_premium
   GOOGLE_PLAY_YEARLY_SKU=land_finder_yearly_premium
   APPLE_MONTHLY_SKU=com.landfinder.monthly
   APPLE_YEARLY_SKU=com.landfinder.yearly
   ```

3. ✅ Update `lib/app/config/env_config.dart`
   ```dart
   static String get googlePlayMonthlySku => dotenv.env['GOOGLE_PLAY_MONTHLY_SKU'] ?? '';
   static String get googlePlayYearlySku => dotenv.env['GOOGLE_PLAY_YEARLY_SKU'] ?? '';
   static String get appleMonthlySku => dotenv.env['APPLE_MONTHLY_SKU'] ?? '';
   static String get appleYearlySku => dotenv.env['APPLE_YEARLY_SKU'] ?? '';
   ```

4. ✅ Update Android `build.gradle`
   ```gradle
   buildTypes {
     release {
       // Ensure app is signed for Google Play
     }
   }
   ```

5. ✅ Update iOS `Podfile` (if needed for StoreKit)
   ```ruby
   pod 'StoreKit'
   ```

---

### Phase 2.2: Database Schema Enhancement (20 min)

**New Migration: `20261119_payment_integration.sql` (280 lines)**

```sql
-- 1. Add purchase_history table
CREATE TABLE public.purchase_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  store TEXT NOT NULL, -- 'google_play' or 'app_store'
  store_transaction_id TEXT NOT NULL UNIQUE,
  purchase_token TEXT,
  original_transaction_id TEXT,
  purchase_date TIMESTAMP WITH TIME ZONE NOT NULL,
  expiry_date TIMESTAMP WITH TIME ZONE,
  status TEXT NOT NULL CHECK (status IN ('pending', 'verified', 'failed', 'cancelled', 'refunded')),
  verification_status TEXT NOT NULL CHECK (verification_status IN ('unverified', 'verified', 'failed')),
  verification_response JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  INDEX idx_user_id (user_id),
  INDEX idx_store_transaction_id (store_transaction_id),
  INDEX idx_status (status),
  INDEX idx_created_at (created_at)
);

-- 2. Update subscriptions table
ALTER TABLE public.subscriptions
  ADD COLUMN verified_purchase_id UUID REFERENCES purchase_history(id),
  ADD COLUMN last_verification_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN renewal_at TIMESTAMP WITH TIME ZONE;

-- 3. Enable RLS on purchase_history
ALTER TABLE public.purchase_history ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS policies
CREATE POLICY "users_view_own_purchases" ON purchase_history
  FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "admins_view_all_purchases" ON purchase_history
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 5. Create helper function for purchase verification
CREATE OR REPLACE FUNCTION verify_purchase(
  p_purchase_id UUID,
  p_verification_data JSONB
) RETURNS void AS $$
BEGIN
  UPDATE purchase_history
  SET 
    verification_status = 'verified',
    verification_response = p_verification_data,
    status = 'verified',
    updated_at = now()
  WHERE id = p_purchase_id
    AND verification_status = 'unverified';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

### Phase 2.3: Supabase Edge Functions (45 min)

**Create: `supabase/functions/verify_google_play_purchase/index.ts`**

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") || "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""
);

serve(async (req) => {
  const { purchaseToken, productId, userId } = await req.json();

  try {
    // 1. Validate request
    if (!purchaseToken || !productId || !userId) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400 }
      );
    }

    // 2. Call Google Play API to verify purchase
    const response = await verifyWithGooglePlay(
      purchaseToken,
      productId,
      Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME") || "",
      Deno.env.get("GOOGLE_PLAY_CREDENTIALS") || ""
    );

    if (!response.verified) {
      return new Response(
        JSON.stringify({ error: "Purchase verification failed", verified: false }),
        { status: 400 }
      );
    }

    // 3. Store verified purchase in database
    const { data, error } = await supabase
      .from("purchase_history")
      .insert({
        user_id: userId,
        product_id: productId,
        store: "google_play",
        store_transaction_id: response.transactionId,
        purchase_token: purchaseToken,
        purchase_date: new Date(response.purchaseTime * 1000),
        expiry_date: new Date(response.expiryTime * 1000),
        status: "verified",
        verification_status: "verified",
        verification_response: response,
      })
      .select()
      .single();

    if (error) {
      console.error("Error storing purchase:", error);
      return new Response(
        JSON.stringify({ error: "Failed to store purchase record" }),
        { status: 500 }
      );
    }

    // 4. Update user subscription
    await updateUserSubscription(userId, productId, data.id);

    return new Response(
      JSON.stringify({
        verified: true,
        purchaseId: data.id,
        expiryDate: data.expiry_date,
      }),
      { status: 200 }
    );
  } catch (error) {
    console.error("Verification error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500 }
    );
  }
});

async function verifyWithGooglePlay(
  purchaseToken: string,
  productId: string,
  packageName: string,
  credentials: string
): Promise<any> {
  // TODO: Implement Google Play API verification
  // This requires service-account credentials stored securely in Supabase
  // For now, return a placeholder
  return {
    verified: true,
    transactionId: "txn_" + Date.now(),
    purchaseTime: Math.floor(Date.now() / 1000),
    expiryTime: Math.floor((Date.now() + 30 * 24 * 60 * 60 * 1000) / 1000),
  };
}

async function updateUserSubscription(
  userId: string,
  productId: string,
  purchaseId: string
): Promise<void> {
  const tierMap = {
    land_finder_monthly_premium: "monthly",
    land_finder_yearly_premium: "yearly",
  };

  const tier = tierMap[productId as keyof typeof tierMap] || "free";

  await supabase
    .from("subscriptions")
    .update({
      tier: tier,
      status: "active",
      verified_purchase_id: purchaseId,
      last_verification_at: new Date().toISOString(),
    })
    .eq("user_id", userId);
}
```

**Create: `supabase/functions/verify_app_store_purchase/index.ts`**
- Similar structure but calls Apple receipt verification API
- Uses same purchase_history table structure

---

### Phase 2.4: Purchase Handler Service (60 min)

**Create: `lib/features/subscription/data/services/purchase_handler.dart`**

```dart
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../../app/config/env_config.dart';
import '../models/subscription_model.dart';

enum PurchaseState {
  idle,
  loading,
  processing,
  success,
  error,
  cancelled,
}

enum PurchaseError {
  networkError,
  paymentFailed,
  userCancelled,
  verificationFailed,
  storeUnavailable,
  invalidProduct,
}

class PurchaseResult {
  final PurchaseState state;
  final SubscriptionModel? subscription;
  final PurchaseError? error;
  final String? errorMessage;

  PurchaseResult({
    required this.state,
    this.subscription,
    this.error,
    this.errorMessage,
  });
}

class PurchaseHandler {
  late final InAppPurchase _iap;
  late final Stream<List<PurchaseDetails>> _purchaseStream;

  PurchaseHandler() {
    _iap = InAppPurchase.instance;
    _purchaseStream = _iap.purchaseStream;
  }

  /// Load available products from store
  Future<List<ProductDetails>> loadProducts() async {
    try {
      final productIds = <String>{
        EnvConfig.googlePlayMonthlySku,
        EnvConfig.googlePlayYearlySku,
      };

      final response = await _iap.queryProductDetails(productIds);
      return response.productDetails;
    } catch (e) {
      throw PurchaseException(
        PurchaseError.storeUnavailable,
        'Failed to load products from store',
      );
    }
  }

  /// Initiate purchase flow
  Future<PurchaseResult> purchaseProduct({
    required ProductDetails product,
    required String userId,
  }) async {
    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );

      // Result will come through purchaseStream
      return PurchaseResult(
        state: PurchaseState.processing,
        subscription: null,
      );
    } catch (e) {
      return PurchaseResult(
        state: PurchaseState.error,
        error: PurchaseError.paymentFailed,
        errorMessage: 'Failed to initiate purchase: $e',
      );
    }
  }

  /// Listen to purchase updates
  Stream<PurchaseResult> get purchaseUpdates {
    return _purchaseStream.asyncMap((purchases) async {
      for (final purchase in purchases) {
        return await _handlePurchaseUpdate(purchase);
      }
      return PurchaseResult(state: PurchaseState.idle);
    });
  }

  /// Handle individual purchase update
  Future<PurchaseResult> _handlePurchaseUpdate(
    PurchaseDetails purchase,
  ) async {
    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      try {
        // Verify with backend
        final subscription = await _verifyPurchaseWithBackend(purchase);

        // Complete the purchase
        await _iap.completePurchase(purchase);

        return PurchaseResult(
          state: PurchaseState.success,
          subscription: subscription,
        );
      } catch (e) {
        return PurchaseResult(
          state: PurchaseState.error,
          error: PurchaseError.verificationFailed,
          errorMessage: 'Purchase verification failed: $e',
        );
      }
    } else if (purchase.status == PurchaseStatus.pending) {
      return PurchaseResult(state: PurchaseState.processing);
    } else if (purchase.status == PurchaseStatus.canceled) {
      return PurchaseResult(
        state: PurchaseState.cancelled,
        error: PurchaseError.userCancelled,
      );
    } else {
      return PurchaseResult(
        state: PurchaseState.error,
        error: PurchaseError.paymentFailed,
        errorMessage: 'Unknown purchase status: ${purchase.status}',
      );
    }
  }

  /// Verify purchase with Supabase backend
  Future<SubscriptionModel> _verifyPurchaseWithBackend(
    PurchaseDetails purchase,
  ) async {
    // TODO: Call Supabase Edge Function to verify receipt
    // Returns verified subscription from server
    throw UnimplementedError('Backend verification not yet implemented');
  }

  /// Restore previous purchases
  Future<List<PurchaseResult>> restorePurchases() async {
    try {
      await _iap.restorePurchases();
      // Results come through purchaseStream
      return [];
    } catch (e) {
      return [
        PurchaseResult(
          state: PurchaseState.error,
          error: PurchaseError.networkError,
          errorMessage: 'Failed to restore purchases: $e',
        )
      ];
    }
  }
}

class PurchaseException implements Exception {
  final PurchaseError error;
  final String message;

  PurchaseException(this.error, this.message);

  @override
  String toString() => message;
}
```

---

### Phase 2.5: Updated Subscription Datasource (40 min)

**Update: `lib/features/subscription/data/datasources/subscription_remote_datasource.dart`**

```dart
class SubscriptionRemoteDatasource {
  final SupabaseClient supabase;

  SubscriptionRemoteDatasource(this.supabase);

  /// Fetch current subscription from server (source of truth)
  Future<SubscriptionModel?> getCurrentSubscription(String userId) async {
    try {
      final response = await supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return SubscriptionModel.fromMap(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Verify purchase receipt with backend
  Future<SubscriptionModel> verifyPurchase({
    required String userId,
    required String purchaseToken,
    required String productId,
    required String platform, // 'google_play' or 'app_store'
  }) async {
    try {
      final response = await supabase.functions.invoke(
        'verify_${platform}_purchase',
        body: {
          'userId': userId,
          'purchaseToken': purchaseToken,
          'productId': productId,
        },
      );

      if (response.status != 200) {
        throw Exception('Purchase verification failed');
      }

      // Fetch updated subscription
      return (await getCurrentSubscription(userId))!;
    } catch (e) {
      throw Exception('Failed to verify purchase: $e');
    }
  }

  /// Subscribe to subscription changes (real-time)
  Stream<SubscriptionModel> subscriptionStream(String userId) {
    return supabase
        .from('subscriptions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) {
      if (data.isEmpty) return SubscriptionModel.empty();
      return SubscriptionModel.fromMap(data.first);
    });
  }
}
```

---

### Phase 2.6: UI Implementation (50 min)

**Create: `lib/features/subscription/presentation/screens/purchase_flow_screen.dart`**

**Create: `lib/features/subscription/presentation/screens/purchase_success_screen.dart`**

**Update: `lib/features/subscription/presentation/screens/subscription_screen.dart`**

---

### Phase 2.7: Testing & Validation (60 min)

**Create: `docs/PHASE_2_TESTING.md`**
- Google Play sandbox testing
- iOS StoreKit 2 testing
- Edge case scenarios
- Verification testing

---

## 🎯 Key Decisions Made

| Decision | Choice | Reason |
|----------|--------|--------|
| **Platforms** | Android (primary) + iOS support | Requires iOS StoreKit 2 integration |
| **Subscriptions** | Single active subscription per user | Simplifies entitlement model |
| **Trial** | Deferred to Phase 3 | Requires eligibility rules definition |
| **Refunds** | Store-managed, honoured through expiry date | Reduces fraud risk |
| **Verification** | Server-only via Edge Functions | Never trust client-side receipt alone |
| **Pricing** | ₱199/month, ₱1,999/year | From existing plan_model.dart |
| **Tier Naming** | free/monthly/yearly | Aligns with existing SubscriptionTier enum |

---

## 📊 Success Criteria

✅ **Phase 2 Complete When:**
- [ ] Packages added to pubspec.yaml
- [ ] Database migration deployed
- [ ] Google Play verification Edge Function implemented
- [ ] Apple verification Edge Function implemented
- [ ] Purchase handler service fully functional
- [ ] Updated subscription datasource deployed
- [ ] Purchase flow screens completed
- [ ] Success/error states properly handled
- [ ] RLS policies tested and working
- [ ] Full purchase flow tested end-to-end
- [ ] Documentation completed
- [ ] Deployment checklist signed off

---

## ⏱️ Timeline

| Component | Estimated | Status |
|-----------|-----------|--------|
| Packages & Config | 30 min | ⏳ Ready |
| Database Schema | 20 min | ⏳ Ready |
| Edge Functions | 45 min | ⏳ Ready |
| Purchase Handler | 60 min | ⏳ Ready |
| Subscription Datasource | 40 min | ⏳ Ready |
| UI Implementation | 50 min | ⏳ Ready |
| Testing & Validation | 60 min | ⏳ Ready |
| **TOTAL** | **~305 min (5 hours)** | ⏳ **STARTING NOW** |

---

## 🚀 Next Steps

**Immediate:**
1. ✅ Confirm Android/iOS focus (assume both)
2. ✅ Confirm pricing (₱199/month, ₱1,999/year)
3. 🔧 Begin Phase 2.1: Package configuration
4. 🔧 Deploy Phase 2.2: Database schema

**After Core Implementation:**
- 🔧 Test on Android device with Google Play Console
- 🔧 Test on iOS simulator with StoreKit 2
- 🔧 Deploy Edge Functions to Supabase
- 🔧 Conduct full end-to-end testing

**Before Production:**
- 🔧 Get Google Play and App Store app IDs approved
- 🔧 Configure store product SKUs
- 🔧 Test with real payment methods
- 🔧 Set up store server notifications
- 🔧 Prepare refund/cancellation procedures

---

**Status:** 🚀 Ready to Begin Phase 2  
**Confidence:** HIGH (all prerequisites met)  
**Risk Level:** MEDIUM (payment integration complexity)  
**Next:** Proceed with Phase 2.1 (Package Configuration)
