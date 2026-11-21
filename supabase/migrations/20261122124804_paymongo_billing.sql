BEGIN;

CREATE TABLE public.billing_settings (
  id boolean PRIMARY KEY DEFAULT true CHECK (id),
  external_checkout_enabled boolean NOT NULL DEFAULT false,
  gcash_enabled boolean NOT NULL DEFAULT true,
  qrph_enabled boolean NOT NULL DEFAULT true,
  card_fixed_term_enabled boolean NOT NULL DEFAULT true,
  card_recurring_enabled boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.billing_settings DEFAULT VALUES
ON CONFLICT (id) DO NOTHING;

CREATE TABLE public.billing_plans (
  id text PRIMARY KEY,
  tier text NOT NULL CHECK (tier IN ('monthly', 'yearly')),
  title text NOT NULL,
  currency text NOT NULL DEFAULT 'PHP',
  amount_minor integer NOT NULL CHECK (amount_minor > 0),
  duration_days integer NOT NULL CHECK (duration_days > 0),
  features text[] NOT NULL DEFAULT '{}',
  active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.billing_plans
  (id, tier, title, amount_minor, duration_days, features)
VALUES
  (
    'monthly_plan',
    'monthly',
    'Monthly Premium',
    19900,
    30,
    ARRAY['Unlimited saved lots', 'Premium-only feature gates', 'Premium analytics']
  ),
  (
    'yearly_plan',
    'yearly',
    'Yearly Premium',
    199900,
    365,
    ARRAY['Everything in Monthly Premium', 'Premium analytics', 'Best value']
  )
ON CONFLICT (id) DO NOTHING;

CREATE TABLE public.billing_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id text NOT NULL REFERENCES public.billing_plans(id),
  provider text NOT NULL DEFAULT 'paymongo'
    CHECK (provider IN ('paymongo', 'google_play', 'app_store')),
  payment_method text NOT NULL
    CHECK (payment_method IN ('gcash', 'qrph_gotyme', 'card')),
  renewal_mode text NOT NULL
    CHECK (renewal_mode IN ('fixed_term', 'paymongo_recurring')),
  idempotency_key text NOT NULL,
  reference_number text NOT NULL UNIQUE,
  provider_checkout_id text UNIQUE,
  provider_resource_id text,
  checkout_url text,
  currency text NOT NULL,
  amount_minor integer NOT NULL CHECK (amount_minor > 0),
  duration_days integer NOT NULL CHECK (duration_days > 0),
  status text NOT NULL DEFAULT 'pending'
    CHECK (
      status IN ('pending', 'awaiting_payment', 'paid', 'failed',
                 'cancelled', 'expired', 'refunded')
    ),
  paid_at timestamptz,
  entitlement_from timestamptz,
  entitlement_until timestamptz,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, idempotency_key)
);

CREATE TABLE public.billing_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.billing_orders(id)
    ON DELETE CASCADE,
  provider_payment_id text NOT NULL UNIQUE,
  amount_minor integer NOT NULL,
  currency text NOT NULL,
  status text NOT NULL
    CHECK (status IN ('paid', 'failed', 'refunded', 'disputed')),
  paid_at timestamptz,
  refunded_at timestamptz,
  provider_data jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.billing_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  order_id uuid NOT NULL REFERENCES public.billing_orders(id),
  provider_subscription_id text NOT NULL UNIQUE,
  status text NOT NULL,
  current_period_end timestamptz,
  cancel_at_period_end boolean NOT NULL DEFAULT false,
  cancelled_at timestamptz,
  next_charge_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.paymongo_entitlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  order_id uuid NOT NULL REFERENCES public.billing_orders(id),
  tier text NOT NULL CHECK (tier IN ('monthly', 'yearly')),
  source_type text NOT NULL
    CHECK (source_type IN ('fixed_term', 'paymongo_recurring')),
  valid_from timestamptz NOT NULL,
  valid_until timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (order_id)
);

CREATE TABLE public.provider_event_inbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL,
  event_id text NOT NULL,
  raw_body_hash text NOT NULL,
  event_type text,
  event_time timestamptz,
  processing_state text NOT NULL DEFAULT 'pending'
    CHECK (processing_state IN ('pending', 'processed', 'failed')),
  error text,
  received_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  UNIQUE (provider, event_id)
);

CREATE INDEX billing_orders_user_status_idx
  ON public.billing_orders(user_id, status, created_at DESC);
CREATE INDEX paymongo_entitlements_user_valid_idx
  ON public.paymongo_entitlements(user_id, valid_until DESC);

ALTER TABLE public.billing_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.paymongo_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_event_inbox ENABLE ROW LEVEL SECURITY;

CREATE POLICY billing_plans_public_read ON public.billing_plans
  FOR SELECT USING (active);
CREATE POLICY billing_settings_authenticated_read ON public.billing_settings
  FOR SELECT TO authenticated USING (true);
CREATE POLICY billing_orders_own_read ON public.billing_orders
  FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY billing_subscriptions_own_read ON public.billing_subscriptions
  FOR SELECT TO authenticated USING (user_id = auth.uid());

REVOKE ALL ON public.billing_settings FROM anon;
REVOKE ALL ON public.billing_orders FROM anon, PUBLIC;
REVOKE ALL ON public.billing_payments FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.billing_subscriptions FROM anon, PUBLIC;
REVOKE ALL ON public.paymongo_entitlements FROM anon, authenticated, PUBLIC;
REVOKE ALL ON public.provider_event_inbox FROM anon, authenticated, PUBLIC;

CREATE OR REPLACE FUNCTION public.get_billing_availability()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
  SELECT jsonb_build_object(
    'external_checkout_enabled', s.external_checkout_enabled,
    'methods', jsonb_build_array(
      jsonb_build_object('id', 'gcash', 'enabled', s.gcash_enabled,
        'renewal_mode', 'fixed_term'),
      jsonb_build_object('id', 'qrph_gotyme', 'enabled', s.qrph_enabled,
        'renewal_mode', 'fixed_term'),
      jsonb_build_object('id', 'card', 'enabled',
        s.card_fixed_term_enabled OR s.card_recurring_enabled,
        'renewal_mode', CASE WHEN s.card_recurring_enabled
          THEN 'paymongo_recurring' ELSE 'fixed_term' END)
    ),
    'test_mode', true
  )
  FROM public.billing_settings s
  WHERE s.id = true
$$;

REVOKE ALL ON FUNCTION public.get_billing_availability() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_billing_availability()
  TO authenticated;

CREATE OR REPLACE FUNCTION app_private.apply_paymongo_event(event jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_order public.billing_orders%ROWTYPE;
  v_payment_id text := event ->> 'payment_id';
  v_event_id text := event ->> 'event_id';
  v_event_time timestamptz := (event ->> 'event_time')::timestamptz;
  v_status text := event ->> 'status';
  v_valid_from timestamptz;
  v_valid_until timestamptz;
  v_existing_until timestamptz;
  v_inserted boolean;
BEGIN
  SELECT * INTO v_order
  FROM public.billing_orders
  WHERE id = (event ->> 'order_id')::uuid
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown billing order';
  END IF;

  IF v_order.amount_minor <> (event ->> 'amount_minor')::integer
    OR v_order.currency <> event ->> 'currency' THEN
    RAISE EXCEPTION 'Provider amount or currency mismatch';
  END IF;

  INSERT INTO public.provider_event_inbox
    (provider, event_id, raw_body_hash, event_type, event_time)
  VALUES
    ('paymongo', v_event_id, event ->> 'raw_body_hash',
     event ->> 'event_type', v_event_time)
  ON CONFLICT (provider, event_id) DO NOTHING
  RETURNING true INTO v_inserted;

  IF v_inserted IS NOT TRUE THEN
    IF EXISTS (
      SELECT 1
      FROM public.provider_event_inbox
      WHERE provider = 'paymongo'
        AND event_id = v_event_id
        AND processing_state = 'processed'
    ) THEN
      RETURN v_order.id;
    END IF;
    RAISE EXCEPTION 'PayMongo event is already processing';
  END IF;

  IF v_status = 'paid' THEN
    INSERT INTO public.billing_payments
      (order_id, provider_payment_id, amount_minor, currency, status,
       paid_at, provider_data)
    VALUES
      (v_order.id, v_payment_id, v_order.amount_minor, v_order.currency,
       'paid', v_event_time, event)
    ON CONFLICT (provider_payment_id) DO NOTHING;

    SELECT max(e.valid_until)
    INTO v_existing_until
    FROM public.paymongo_entitlements e
    WHERE e.user_id = v_order.user_id
      AND e.revoked_at IS NULL
      AND e.valid_until > now();

    v_valid_from := CASE
      WHEN v_existing_until > v_event_time THEN v_existing_until
      ELSE v_event_time
    END;
    v_valid_until := v_valid_from
      + make_interval(days => v_order.duration_days);

    INSERT INTO public.paymongo_entitlements
      (user_id, order_id, tier, source_type, valid_from, valid_until)
    VALUES
      (v_order.user_id, v_order.id, (
        SELECT bp.tier FROM public.billing_plans bp
        WHERE bp.id = v_order.plan_id
      ), v_order.renewal_mode, v_valid_from, v_valid_until)
    ON CONFLICT (order_id) DO UPDATE
    SET valid_from = EXCLUDED.valid_from,
        valid_until = EXCLUDED.valid_until;

    UPDATE public.billing_orders
    SET status = 'paid',
        paid_at = COALESCE(paid_at, v_event_time),
        entitlement_from = v_valid_from,
        entitlement_until = v_valid_until,
        updated_at = now()
    WHERE id = v_order.id;

    UPDATE public.subscriptions s
    SET tier = e.tier,
        status = 'active',
        store = 'paymongo',
        expires_at = e.valid_until,
        renewal_at = e.valid_until,
        last_verification_at = now(),
        updated_at = now()
    FROM public.paymongo_entitlements e
    WHERE s.user_id = v_order.user_id
      AND e.user_id = v_order.user_id
      AND e.valid_until > now()
      AND e.revoked_at IS NULL
      AND e.id = (
        SELECT e2.id FROM public.paymongo_entitlements e2
        WHERE e2.user_id = v_order.user_id
          AND e2.valid_until > now()
          AND e2.revoked_at IS NULL
        ORDER BY e2.valid_until DESC
        LIMIT 1
      );
  ELSIF v_status = 'refunded' THEN
    UPDATE public.paymongo_entitlements
    SET revoked_at = v_event_time
    WHERE order_id = v_order.id;
    UPDATE public.billing_orders
    SET status = 'refunded', updated_at = now()
    WHERE id = v_order.id;
    UPDATE public.subscriptions s
    SET tier = COALESCE(next_entitlement.tier, 'free'),
        status = 'active',
        store = CASE
          WHEN next_entitlement.id IS NULL THEN NULL ELSE 'paymongo' END,
        expires_at = next_entitlement.valid_until,
        renewal_at = next_entitlement.valid_until,
        last_verification_at = now(),
        updated_at = now()
    FROM LATERAL (
      SELECT e.id, e.tier, e.valid_until
      FROM public.paymongo_entitlements e
      WHERE e.user_id = v_order.user_id
        AND e.revoked_at IS NULL
        AND e.valid_until > now()
      ORDER BY e.valid_until DESC
      LIMIT 1
    ) next_entitlement
    WHERE s.user_id = v_order.user_id
      AND s.store = 'paymongo';

    UPDATE public.subscriptions
    SET tier = 'free',
        status = 'active',
        store = NULL,
        expires_at = NULL,
        renewal_at = NULL,
        last_verification_at = now(),
        updated_at = now()
    WHERE user_id = v_order.user_id
      AND store = 'paymongo'
      AND NOT EXISTS (
        SELECT 1
        FROM public.paymongo_entitlements e
        WHERE e.user_id = v_order.user_id
          AND e.revoked_at IS NULL
          AND e.valid_until > now()
      );
  ELSE
    UPDATE public.billing_orders
    SET status = v_status, updated_at = now()
    WHERE id = v_order.id;
  END IF;

  UPDATE public.provider_event_inbox
  SET processing_state = 'processed', processed_at = now()
  WHERE provider = 'paymongo' AND event_id = v_event_id;

  RETURN v_order.id;
EXCEPTION WHEN OTHERS THEN
  UPDATE public.provider_event_inbox
  SET processing_state = 'failed', error = SQLERRM
  WHERE provider = 'paymongo' AND event_id = v_event_id;
  RAISE;
END;
$$;

REVOKE ALL ON FUNCTION app_private.apply_paymongo_event(jsonb)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION app_private.apply_paymongo_event(jsonb)
  TO service_role;

CREATE OR REPLACE FUNCTION public.apply_paymongo_event(event jsonb)
RETURNS uuid
LANGUAGE sql
SECURITY INVOKER
SET search_path = pg_catalog, app_private
AS $$
  SELECT app_private.apply_paymongo_event(event)
$$;

REVOKE ALL ON FUNCTION public.apply_paymongo_event(jsonb)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.apply_paymongo_event(jsonb)
  TO service_role;

COMMIT;