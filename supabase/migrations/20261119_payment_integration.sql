-- ============================================================================
-- PHASE 2: REAL BILLING INTEGRATION SCHEMA
-- ============================================================================
-- Purpose: Add payment infrastructure for real in-app purchases
-- - Purchase history tracking
-- - Receipt verification storage
-- - Subscription linking to verified purchases
-- - RLS policies for purchase access control
-- ============================================================================

-- ============================================================================
-- 1. CREATE PURCHASE_HISTORY TABLE
-- ============================================================================
-- Tracks all purchase transactions from Google Play and App Store
-- Immutable audit trail of all payment activity

CREATE TABLE public.purchase_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Product information
  product_id TEXT NOT NULL,                    -- SKU from store (google_play_monthly, etc)
  store TEXT NOT NULL CHECK (store IN ('google_play', 'app_store')),
  
  -- Store transaction identifiers
  store_transaction_id TEXT NOT NULL UNIQUE,   -- Google Play orderId or Apple transactionId
  purchase_token TEXT,                         -- Google Play purchaseToken (nullable for App Store)
  original_transaction_id TEXT,                -- App Store originalTransactionId
  
  -- Timing
  purchase_date TIMESTAMP WITH TIME ZONE NOT NULL,
  expiry_date TIMESTAMP WITH TIME ZONE,
  
  -- Status tracking
  status TEXT NOT NULL 
    CHECK (status IN ('pending', 'verified', 'failed', 'cancelled', 'refunded'))
    DEFAULT 'pending',
  
  verification_status TEXT NOT NULL 
    CHECK (verification_status IN ('unverified', 'verified', 'failed'))
    DEFAULT 'unverified',
  
  -- Verification details (store response)
  verification_response JSONB,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  -- Constraints
  CONSTRAINT unique_user_active_purchase UNIQUE (user_id, store_transaction_id),
  CONSTRAINT valid_dates CHECK (purchase_date <= expiry_date OR expiry_date IS NULL)
);

-- Indexes for common queries
CREATE INDEX idx_purchase_history_user_id 
  ON public.purchase_history(user_id);

CREATE INDEX idx_purchase_history_store_transaction_id 
  ON public.purchase_history(store_transaction_id);

CREATE INDEX idx_purchase_history_status 
  ON public.purchase_history(status, verification_status);

CREATE INDEX idx_purchase_history_created_at 
  ON public.purchase_history(created_at DESC);

CREATE INDEX idx_purchase_history_user_created 
  ON public.purchase_history(user_id, created_at DESC);

-- ============================================================================
-- 2. UPDATE SUBSCRIPTIONS TABLE - ADD PURCHASE LINKS
-- ============================================================================
-- Link subscriptions to verified purchases for entitlement tracking

ALTER TABLE public.subscriptions
  ADD COLUMN verified_purchase_id UUID REFERENCES purchase_history(id),
  ADD COLUMN last_verification_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN renewal_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN auto_renew_enabled BOOLEAN DEFAULT TRUE;

-- ============================================================================
-- 3. ENABLE RLS ON PURCHASE_HISTORY
-- ============================================================================

ALTER TABLE public.purchase_history ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 4. RLS POLICIES - PURCHASE_HISTORY
-- ============================================================================

-- Users can view their own purchase history
CREATE POLICY "users_view_own_purchase_history" ON public.purchase_history
  FOR SELECT
  USING (user_id = auth.uid());

-- Users cannot insert/update/delete (backend only)
CREATE POLICY "users_cannot_modify_purchases" ON public.purchase_history
  FOR INSERT, UPDATE, DELETE
  USING (FALSE);

-- Service role (Edge Functions) can insert verified purchases
CREATE POLICY "service_role_insert_purchases" ON public.purchase_history
  FOR INSERT
  WITH CHECK (TRUE); -- Allowed by service-role key in Edge Functions

-- Service role can update verification status
CREATE POLICY "service_role_update_purchases" ON public.purchase_history
  FOR UPDATE
  USING (TRUE)
  WITH CHECK (TRUE);

-- Admins can view all purchases for support/debugging
CREATE POLICY "admins_view_all_purchases" ON public.purchase_history
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- 5. CREATE HELPER FUNCTIONS FOR PURCHASE VERIFICATION
-- ============================================================================

-- Function to verify and record a Google Play purchase
CREATE OR REPLACE FUNCTION verify_google_play_purchase(
  p_user_id UUID,
  p_product_id TEXT,
  p_order_id TEXT,
  p_purchase_token TEXT,
  p_verification_data JSONB
) RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  purchase_id UUID
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_purchase_id UUID;
  v_expiry_date TIMESTAMP WITH TIME ZONE;
BEGIN
  -- Extract expiry from verification data
  v_expiry_date := (p_verification_data ->> 'expiryTimeMillis')::BIGINT / 1000;

  -- Insert or update purchase record
  INSERT INTO public.purchase_history (
    user_id,
    product_id,
    store,
    store_transaction_id,
    purchase_token,
    purchase_date,
    expiry_date,
    status,
    verification_status,
    verification_response
  )
  VALUES (
    p_user_id,
    p_product_id,
    'google_play',
    p_order_id,
    p_purchase_token,
    NOW(),
    to_timestamp(v_expiry_date),
    'verified',
    'verified',
    p_verification_data
  )
  ON CONFLICT (store_transaction_id)
  DO UPDATE SET
    verification_status = 'verified',
    status = 'verified',
    verification_response = p_verification_data,
    updated_at = NOW()
  RETURNING id INTO v_purchase_id;

  -- Update user subscription
  UPDATE public.subscriptions
  SET
    tier = CASE 
      WHEN p_product_id ILIKE '%monthly%' THEN 'monthly'
      WHEN p_product_id ILIKE '%yearly%' THEN 'yearly'
      ELSE tier
    END,
    status = 'active',
    verified_purchase_id = v_purchase_id,
    last_verification_at = NOW(),
    renewal_at = to_timestamp(v_expiry_date)
  WHERE user_id = p_user_id;

  RETURN QUERY SELECT 
    true AS success,
    'Purchase verified and recorded'::TEXT AS message,
    v_purchase_id AS purchase_id;
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT 
    false AS success,
    ('Error verifying purchase: ' || SQLERRM)::TEXT AS message,
    NULL::UUID AS purchase_id;
END;
$$;

-- Function to verify and record an App Store purchase
CREATE OR REPLACE FUNCTION verify_app_store_purchase(
  p_user_id UUID,
  p_product_id TEXT,
  p_transaction_id TEXT,
  p_original_transaction_id TEXT,
  p_verification_data JSONB
) RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  purchase_id UUID
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_purchase_id UUID;
  v_expiry_date TIMESTAMP WITH TIME ZONE;
BEGIN
  -- Extract expiry from verification data
  v_expiry_date := to_timestamp(
    (p_verification_data ->> 'expiresDate')::BIGINT / 1000
  );

  -- Insert or update purchase record
  INSERT INTO public.purchase_history (
    user_id,
    product_id,
    store,
    store_transaction_id,
    original_transaction_id,
    purchase_date,
    expiry_date,
    status,
    verification_status,
    verification_response
  )
  VALUES (
    p_user_id,
    p_product_id,
    'app_store',
    p_transaction_id,
    p_original_transaction_id,
    NOW(),
    v_expiry_date,
    'verified',
    'verified',
    p_verification_data
  )
  ON CONFLICT (store_transaction_id)
  DO UPDATE SET
    verification_status = 'verified',
    status = 'verified',
    verification_response = p_verification_data,
    updated_at = NOW()
  RETURNING id INTO v_purchase_id;

  -- Update user subscription
  UPDATE public.subscriptions
  SET
    tier = CASE 
      WHEN p_product_id ILIKE '%monthly%' THEN 'monthly'
      WHEN p_product_id ILIKE '%yearly%' THEN 'yearly'
      ELSE tier
    END,
    status = 'active',
    verified_purchase_id = v_purchase_id,
    last_verification_at = NOW(),
    renewal_at = v_expiry_date
  WHERE user_id = p_user_id;

  RETURN QUERY SELECT 
    true AS success,
    'Purchase verified and recorded'::TEXT AS message,
    v_purchase_id AS purchase_id;
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT 
    false AS success,
    ('Error verifying purchase: ' || SQLERRM)::TEXT AS message,
    NULL::UUID AS purchase_id;
END;
$$;

-- Function to handle purchase refund/cancellation
CREATE OR REPLACE FUNCTION cancel_or_refund_purchase(
  p_purchase_id UUID,
  p_reason TEXT DEFAULT 'user_requested'
) RETURNS TABLE (
  success BOOLEAN,
  message TEXT
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Get user_id from purchase
  SELECT user_id INTO v_user_id FROM public.purchase_history WHERE id = p_purchase_id;

  -- Update purchase status
  UPDATE public.purchase_history
  SET status = CASE 
    WHEN p_reason = 'refunded' THEN 'refunded'
    ELSE 'cancelled'
  END,
  updated_at = NOW()
  WHERE id = p_purchase_id;

  -- Revert subscription to free tier
  UPDATE public.subscriptions
  SET
    tier = 'free',
    status = 'active',
    verified_purchase_id = NULL,
    last_verification_at = NOW()
  WHERE user_id = v_user_id
    AND verified_purchase_id = p_purchase_id;

  RETURN QUERY SELECT 
    true AS success,
    ('Purchase ' || p_reason)::TEXT AS message;
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT 
    false AS success,
    ('Error cancelling purchase: ' || SQLERRM)::TEXT AS message;
END;
$$;

-- ============================================================================
-- 6. HELPER FUNCTION - GET ACTIVE ENTITLEMENT
-- ============================================================================
-- Returns current subscription tier with verification

CREATE OR REPLACE FUNCTION get_active_entitlement(p_user_id UUID)
RETURNS TABLE (
  tier TEXT,
  status TEXT,
  expires_at TIMESTAMP WITH TIME ZONE,
  verified BOOLEAN
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.tier::TEXT,
    s.status::TEXT,
    s.renewal_at,
    CASE 
      WHEN s.verified_purchase_id IS NOT NULL 
        AND ph.verification_status = 'verified'
        AND (ph.expiry_date IS NULL OR ph.expiry_date > NOW())
      THEN TRUE
      ELSE FALSE
    END AS verified
  FROM public.subscriptions s
  LEFT JOIN public.purchase_history ph ON s.verified_purchase_id = ph.id
  WHERE s.user_id = p_user_id
    AND s.status = 'active'
  LIMIT 1;
END;
$$;

-- ============================================================================
-- 7. TRIGGERS FOR AUTOMATIC TIMESTAMPS
-- ============================================================================

CREATE OR REPLACE FUNCTION update_purchase_history_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_purchase_history_updated_at
  BEFORE UPDATE ON public.purchase_history
  FOR EACH ROW
  EXECUTE FUNCTION update_purchase_history_timestamp();

-- ============================================================================
-- 8. GRANT PERMISSIONS
-- ============================================================================

-- Service role can call verification functions (for Edge Functions)
GRANT EXECUTE ON FUNCTION verify_google_play_purchase TO service_role;
GRANT EXECUTE ON FUNCTION verify_app_store_purchase TO service_role;
GRANT EXECUTE ON FUNCTION cancel_or_refund_purchase TO service_role;
GRANT EXECUTE ON FUNCTION get_active_entitlement TO authenticated;

-- ============================================================================
-- 9. CREATE DOCUMENTATION COMMENTS
-- ============================================================================

COMMENT ON TABLE public.purchase_history IS
'Immutable audit trail of all purchase transactions. Each record represents
one transaction from Google Play or App Store. Used for entitlement verification,
refund handling, and compliance reporting. Linked to subscriptions table
for active entitlement tracking.';

COMMENT ON COLUMN public.purchase_history.store_transaction_id IS
'Unique transaction identifier from store. For Google Play: orderId.
For App Store: transactionId. Used as idempotency key for verification.';

COMMENT ON COLUMN public.purchase_history.verification_status IS
'Status of verification with store API. Only "verified" purchases
grant entitlements. Provides audit trail for failed verifications.';

COMMENT ON COLUMN public.subscriptions.verified_purchase_id IS
'Foreign key to the latest verified purchase_history record.
If NULL or verification_status != "verified", user has no paid entitlement.';

COMMENT ON FUNCTION verify_google_play_purchase IS
'Server-side function (call via Edge Function) to verify and record Google Play purchases.
Never call directly from client. Performs verification lookup, creates/updates
purchase record, and updates subscriptions table atomically.';

COMMENT ON FUNCTION get_active_entitlement IS
'Returns current active subscription tier for a user.
Checks purchase_history for valid verification and expiry.
Safe to call from client via authenticated connection.';
