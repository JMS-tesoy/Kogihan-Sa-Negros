BEGIN;

ALTER TABLE public.subscriptions
  DROP CONSTRAINT IF EXISTS subscriptions_tier_check;

UPDATE public.subscriptions
SET tier = CASE tier
  WHEN 'premium' THEN 'monthly'
  WHEN 'professional' THEN 'yearly'
  ELSE tier
END
WHERE tier IN ('premium', 'professional');

UPDATE public.subscriptions
SET expires_at = renewal_at
WHERE expires_at IS NULL
  AND renewal_at IS NOT NULL;

ALTER TABLE public.subscriptions
  ADD CONSTRAINT subscriptions_tier_check
    CHECK (tier IN ('free', 'monthly', 'yearly')),
  ADD COLUMN IF NOT EXISTS store text,
  ADD COLUMN IF NOT EXISTS product_id text;

CREATE TABLE IF NOT EXISTS public.entitlement_products (
  store text NOT NULL CHECK (store IN ('google_play', 'app_store')),
  environment text NOT NULL CHECK (environment IN ('production', 'sandbox')),
  product_id text NOT NULL,
  tier text NOT NULL CHECK (tier IN ('monthly', 'yearly')),
  PRIMARY KEY (store, environment, product_id)
);

INSERT INTO public.entitlement_products (store, environment, product_id, tier)
VALUES
  ('google_play', 'production', 'com.landfinder.app.monthly', 'monthly'),
  ('google_play', 'sandbox', 'com.landfinder.app.monthly', 'monthly'),
  ('google_play', 'production', 'com.landfinder.app.yearly', 'yearly'),
  ('google_play', 'sandbox', 'com.landfinder.app.yearly', 'yearly'),
  ('app_store', 'production', 'landfinder_monthly', 'monthly'),
  ('app_store', 'sandbox', 'landfinder_monthly', 'monthly'),
  ('app_store', 'production', 'landfinder_yearly', 'yearly'),
  ('app_store', 'sandbox', 'landfinder_yearly', 'yearly')
ON CONFLICT (store, environment, product_id) DO UPDATE
SET tier = EXCLUDED.tier;

ALTER TABLE public.entitlement_products ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.purchase_history
  ADD COLUMN IF NOT EXISTS environment text
    CHECK (environment IN ('production', 'sandbox')),
  ADD COLUMN IF NOT EXISTS store_subscription_id text,
  ADD COLUMN IF NOT EXISTS event_id text,
  ADD COLUMN IF NOT EXISTS event_time timestamptz,
  ADD COLUMN IF NOT EXISTS auto_renew boolean,
  ADD COLUMN IF NOT EXISTS cancellation_reason text,
  ADD COLUMN IF NOT EXISTS revoked_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS purchase_history_store_transaction_unique
  ON public.purchase_history(store, store_transaction_id);

CREATE UNIQUE INDEX IF NOT EXISTS purchase_history_store_event_unique
  ON public.purchase_history(store, event_id)
  WHERE event_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS purchase_history_active_entitlement_idx
  ON public.purchase_history(
    user_id,
    store,
    store_subscription_id,
    expiry_date
  )
  WHERE verification_status = 'verified'
    AND status = 'verified';

CREATE TABLE IF NOT EXISTS public.store_event_inbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store text NOT NULL CHECK (store IN ('google_play', 'app_store')),
  event_id text NOT NULL,
  event_time timestamptz,
  payload_hash text,
  processed_at timestamptz,
  processing_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (store, event_id)
);

ALTER TABLE public.store_event_inbox ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_view_own_subscription"
  ON public.subscriptions;
DROP POLICY IF EXISTS "admins_manage_subscriptions"
  ON public.subscriptions;
DROP POLICY IF EXISTS "users_view_own_purchase_history"
  ON public.purchase_history;
DROP POLICY IF EXISTS "users_cannot_modify_purchases"
  ON public.purchase_history;
DROP POLICY IF EXISTS "service_role_insert_purchases"
  ON public.purchase_history;
DROP POLICY IF EXISTS "service_role_update_purchases"
  ON public.purchase_history;
DROP POLICY IF EXISTS "admins_view_all_purchases"
  ON public.purchase_history;

CREATE POLICY "users_view_own_subscription"
  ON public.subscriptions
  FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "users_view_own_purchase_history"
  ON public.purchase_history
  FOR SELECT
  USING (user_id = auth.uid());

REVOKE INSERT, UPDATE, DELETE ON public.subscriptions FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.purchase_history FROM authenticated, anon;
REVOKE ALL ON public.store_event_inbox FROM PUBLIC, authenticated, anon;
REVOKE ALL ON public.entitlement_products FROM PUBLIC, anon;
GRANT SELECT ON public.entitlement_products TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_entitlement()
RETURNS TABLE (
  id uuid,
  tier text,
  status text,
  expires_at timestamptz,
  auto_renew boolean,
  product_id text,
  verified_purchase_id uuid,
  last_verification_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
  SELECT
    s.id,
    s.tier,
    s.status,
    s.expires_at,
    s.auto_renew,
    s.product_id,
    s.verified_purchase_id,
    s.last_verification_at
  FROM public.subscriptions s
  WHERE s.user_id = auth.uid()
$$;

REVOKE ALL ON FUNCTION public.get_my_entitlement() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_entitlement() TO authenticated;

CREATE SCHEMA IF NOT EXISTS app_private;
REVOKE ALL ON SCHEMA app_private FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION app_private.apply_verified_store_event(event jsonb)
RETURNS TABLE (
  subscription_id uuid,
  tier text,
  status text,
  expires_at timestamptz,
  verified_purchase_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_user_id uuid := (event ->> 'user_id')::uuid;
  v_store text := event ->> 'store';
  v_environment text := event ->> 'environment';
  v_product_id text := event ->> 'product_id';
  v_transaction_id text := event ->> 'transaction_id';
  v_subscription_id text := NULLIF(event ->> 'subscription_id', '');
  v_event_id text := NULLIF(event ->> 'event_id', '');
  v_event_time timestamptz := COALESCE(
    (event ->> 'event_time')::timestamptz,
    now()
  );
  v_purchase_date timestamptz := COALESCE(
    (event ->> 'purchase_date')::timestamptz,
    v_event_time
  );
  v_expiry_date timestamptz := (event ->> 'expires_at')::timestamptz;
  v_event_status text := COALESCE(event ->> 'status', 'verified');
  v_purchase_status text;
  v_verification_status text;
  v_tier text;
  v_subscription public.subscriptions%ROWTYPE;
  v_effective_purchase_id uuid;
  v_purchase_id uuid;
  v_owner uuid;
BEGIN
  IF v_user_id IS NULL
    OR v_store IS NULL
    OR v_environment IS NULL
    OR v_product_id IS NULL
    OR v_transaction_id IS NULL THEN
    RAISE EXCEPTION 'Missing verified store event fields';
  END IF;

  SELECT ep.tier
  INTO v_tier
  FROM public.entitlement_products ep
  WHERE ep.store = v_store
    AND ep.environment = v_environment
    AND ep.product_id = v_product_id;

  IF v_tier IS NULL THEN
    RAISE EXCEPTION 'Unregistered store product %', v_product_id;
  END IF;

  IF v_event_status NOT IN ('verified', 'cancelled', 'refunded', 'revoked', 'expired') THEN
    RAISE EXCEPTION 'Unsupported store event status %', v_event_status;
  END IF;

  IF v_event_status IN ('verified', 'cancelled')
    AND v_expiry_date IS NULL THEN
    RAISE EXCEPTION 'Active store event is missing expiry';
  END IF;

  IF v_event_status IN ('refunded', 'revoked') THEN
    v_purchase_status := 'refunded';
    v_verification_status := 'verified';
  ELSIF v_event_status = 'cancelled' THEN
    v_purchase_status := 'verified';
    v_verification_status := 'verified';
  ELSIF v_event_status = 'expired' THEN
    v_purchase_status := 'cancelled';
    v_verification_status := 'verified';
  ELSE
    v_purchase_status := 'verified';
    v_verification_status := 'verified';
  END IF;

  SELECT ph.user_id
  INTO v_owner
  FROM public.purchase_history ph
  WHERE ph.store = v_store
    AND ph.store_transaction_id = v_transaction_id;

  IF v_owner IS NOT NULL AND v_owner <> v_user_id THEN
    RAISE EXCEPTION 'Store transaction is already owned by another user';
  END IF;

  INSERT INTO public.purchase_history (
    user_id,
    product_id,
    store,
    store_transaction_id,
    original_transaction_id,
    store_subscription_id,
    purchase_token,
    purchase_date,
    expiry_date,
    status,
    verification_status,
    verification_response,
    environment,
    event_id,
    event_time,
    auto_renew,
    cancellation_reason,
    revoked_at
  )
  VALUES (
    v_user_id,
    v_product_id,
    v_store,
    v_transaction_id,
    v_subscription_id,
    v_subscription_id,
    NULLIF(event ->> 'purchase_token', ''),
    v_purchase_date,
    v_expiry_date,
    v_purchase_status,
    v_verification_status,
    event -> 'verification_response',
    v_environment,
    v_event_id,
    v_event_time,
    COALESCE((event ->> 'auto_renew')::boolean, true),
    NULLIF(event ->> 'cancellation_reason', ''),
    CASE
      WHEN v_event_status IN ('refunded', 'revoked') THEN v_event_time
      ELSE NULL
    END
  )
  ON CONFLICT (store, store_transaction_id)
  DO UPDATE
  SET
    expiry_date = EXCLUDED.expiry_date,
    status = EXCLUDED.status,
    verification_status = EXCLUDED.verification_status,
    verification_response = EXCLUDED.verification_response,
    store_subscription_id = EXCLUDED.store_subscription_id,
    event_id = EXCLUDED.event_id,
    event_time = EXCLUDED.event_time,
    auto_renew = EXCLUDED.auto_renew,
    cancellation_reason = EXCLUDED.cancellation_reason,
    revoked_at = EXCLUDED.revoked_at,
    updated_at = now()
  WHERE public.purchase_history.event_time IS NULL
    OR EXCLUDED.event_time >= public.purchase_history.event_time
  RETURNING id INTO v_purchase_id;

  IF v_purchase_id IS NULL THEN
    SELECT ph.id
    INTO v_purchase_id
    FROM public.purchase_history ph
    WHERE ph.store = v_store
      AND ph.store_transaction_id = v_transaction_id;
  END IF;

  IF v_event_id IS NOT NULL THEN
    INSERT INTO public.store_event_inbox (
      store,
      event_id,
      event_time,
      payload_hash,
      processed_at
    )
    VALUES (
      v_store,
      v_event_id,
      v_event_time,
      md5(event::text),
      now()
    )
    ON CONFLICT (store, event_id) DO UPDATE
    SET processed_at = EXCLUDED.processed_at;
  END IF;

  INSERT INTO public.subscriptions (user_id, tier, status)
  VALUES (v_user_id, 'free', 'active')
  ON CONFLICT (user_id) DO NOTHING;

  SELECT *
  INTO v_subscription
  FROM public.subscriptions
  WHERE user_id = v_user_id
  FOR UPDATE;

  SELECT ph.id
  INTO v_effective_purchase_id
  FROM public.purchase_history ph
  WHERE ph.user_id = v_user_id
    AND ph.verification_status = 'verified'
    AND ph.status = 'verified'
    AND ph.revoked_at IS NULL
    AND ph.expiry_date > now()
  ORDER BY ph.expiry_date DESC, ph.event_time DESC
  LIMIT 1;

  IF v_effective_purchase_id IS NULL THEN
    UPDATE public.subscriptions
    SET
      tier = 'free',
      status = 'active',
      expires_at = NULL,
      renewal_at = NULL,
      verified_purchase_id = NULL,
      product_id = NULL,
      last_verification_at = now(),
      updated_at = now()
    WHERE id = v_subscription.id;
  ELSE
    UPDATE public.subscriptions
    SET
      tier = p_product.tier,
      status = 'active',
      expires_at = p.expiry_date,
      renewal_at = p.expiry_date,
      verified_purchase_id = p.id,
      store = p.store,
      product_id = p.product_id,
      auto_renew = COALESCE(p.auto_renew, true),
      last_verification_at = now(),
      updated_at = now()
    FROM public.purchase_history p
    JOIN public.entitlement_products p_product
      ON p_product.store = p.store
      AND p_product.environment = p.environment
      AND p_product.product_id = p.product_id
    WHERE public.subscriptions.id = v_subscription.id
      AND p.id = v_effective_purchase_id;
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.tier,
    s.status,
    s.expires_at,
    s.verified_purchase_id
  FROM public.subscriptions s
  WHERE s.id = v_subscription.id;
END;
$$;

REVOKE ALL ON FUNCTION app_private.apply_verified_store_event(jsonb)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION app_private.apply_verified_store_event(jsonb)
  TO service_role;

CREATE OR REPLACE FUNCTION public.apply_verified_store_event(event jsonb)
RETURNS TABLE (
  subscription_id uuid,
  tier text,
  status text,
  expires_at timestamptz,
  verified_purchase_id uuid
)
LANGUAGE sql
SECURITY INVOKER
SET search_path = pg_catalog, app_private
AS $$
  SELECT *
  FROM app_private.apply_verified_store_event(event)
$$;

REVOKE ALL ON FUNCTION public.apply_verified_store_event(jsonb)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.apply_verified_store_event(jsonb)
  TO service_role;

REVOKE ALL ON FUNCTION public.get_active_entitlement(uuid)
  FROM PUBLIC, authenticated, anon;

REVOKE ALL ON FUNCTION public.verify_google_play_purchase(
  uuid,
  text,
  text,
  text,
  jsonb
) FROM authenticated, anon, PUBLIC;

REVOKE ALL ON FUNCTION public.verify_app_store_purchase(
  uuid,
  text,
  text,
  text,
  jsonb
) FROM authenticated, anon, PUBLIC;

COMMIT;