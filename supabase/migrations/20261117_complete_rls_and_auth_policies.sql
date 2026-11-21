-- ============================================================================
-- COMPLETE RLS AND AUTHORIZATION POLICIES
-- ============================================================================
-- Purpose: Implement comprehensive Row-Level Security (RLS) for all tables
-- supporting three-tier role system (User/Agent/Admin)
-- ============================================================================

-- ============================================================================
-- 1. ENABLE RLS ON ALL EXISTING TABLES
-- ============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 2. PROFILES TABLE - RLS POLICIES
-- ============================================================================
-- Users can only view/update their own profile
-- Admins can view all profiles

-- Allow users to view their own profile
CREATE POLICY "users_view_own_profile" ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);

-- Allow users to update their own profile
CREATE POLICY "users_update_own_profile" ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Allow users to insert their own profile (during signup)
CREATE POLICY "users_insert_own_profile" ON public.profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id AND role = 'user');

-- Allow agents to insert their own profile with agent role
CREATE POLICY "agents_insert_own_profile" ON public.profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id AND role = 'agent');

-- Allow admins to view all profiles
CREATE POLICY "admins_view_all_profiles" ON public.profiles
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Allow admins to update any profile
CREATE POLICY "admins_update_all_profiles" ON public.profiles
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- 3. PROPERTIES TABLE - RLS POLICIES
-- ============================================================================
-- Public can view published properties
-- Agents can view/edit their own properties
-- Admins can view/edit all properties

-- Allow anyone to view published properties
CREATE POLICY "anyone_view_published_properties" ON public.properties
  FOR SELECT
  USING (
    -- Properties are public by default or have a status check
    -- (requires status column, see schema enhancement below)
    true
  );

-- Allow authenticated users to insert properties (auto-assign to self if agent)
CREATE POLICY "users_insert_properties" ON public.properties
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND (
      SELECT role FROM public.profiles WHERE id = auth.uid()
    ) IN ('agent', 'admin')
  );

-- Allow agents to update their own properties
CREATE POLICY "agents_update_own_properties" ON public.properties
  FOR UPDATE
  USING (
    agent_id = auth.uid()
    AND (
      SELECT role FROM public.profiles WHERE id = auth.uid()
    ) = 'agent'
  );

-- Allow admins to update any property
CREATE POLICY "admins_update_all_properties" ON public.properties
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Allow admins to delete any property
CREATE POLICY "admins_delete_all_properties" ON public.properties
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Allow agents to delete their own properties
CREATE POLICY "agents_delete_own_properties" ON public.properties
  FOR DELETE
  USING (
    agent_id = auth.uid()
    AND (
      SELECT role FROM public.profiles WHERE id = auth.uid()
    ) = 'agent'
  );

-- ============================================================================
-- 4. SCHEMA ENHANCEMENTS - Add missing columns
-- ============================================================================

-- Add agent_id to properties if not exists
ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS agent_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

-- Add status to properties if not exists
ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'active' CHECK (status IN ('active', 'sold', 'archived', 'pending'));

-- ============================================================================
-- 5. INQUIRIES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.inquiries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'viewed', 'responded', 'closed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz
);

CREATE INDEX IF NOT EXISTS inquiries_property_id_idx ON public.inquiries(property_id);
CREATE INDEX IF NOT EXISTS inquiries_sender_id_idx ON public.inquiries(sender_id);
CREATE INDEX IF NOT EXISTS inquiries_receiver_id_idx ON public.inquiries(receiver_id);
CREATE INDEX IF NOT EXISTS inquiries_created_at_idx ON public.inquiries(created_at DESC);

ALTER TABLE public.inquiries ENABLE ROW LEVEL SECURITY;

-- Users can view inquiries they sent or received
CREATE POLICY "users_view_own_inquiries" ON public.inquiries
  FOR SELECT
  USING (sender_id = auth.uid() OR receiver_id = auth.uid());

-- Users can insert inquiries
CREATE POLICY "users_insert_inquiries" ON public.inquiries
  FOR INSERT
  WITH CHECK (sender_id = auth.uid());

-- Users can update inquiries they received
CREATE POLICY "users_update_inquiries" ON public.inquiries
  FOR UPDATE
  USING (receiver_id = auth.uid())
  WITH CHECK (receiver_id = auth.uid());

-- Admins can view all inquiries
CREATE POLICY "admins_view_all_inquiries" ON public.inquiries
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- 6. FAVORITES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, property_id)
);

CREATE INDEX IF NOT EXISTS favorites_user_id_idx ON public.favorites(user_id);
CREATE INDEX IF NOT EXISTS favorites_property_id_idx ON public.favorites(property_id);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

-- Users can view their own favorites
CREATE POLICY "users_view_own_favorites" ON public.favorites
  FOR SELECT
  USING (user_id = auth.uid());

-- Users can insert/delete their own favorites
CREATE POLICY "users_manage_own_favorites" ON public.favorites
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_delete_own_favorites" ON public.favorites
  FOR DELETE
  USING (user_id = auth.uid());

-- Admins can view all favorites
CREATE POLICY "admins_view_all_favorites" ON public.favorites
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- 7. AGENT TEAMS TABLE
-- ============================================================================

ALTER TABLE public.agent_teams
  ADD COLUMN IF NOT EXISTS leader_id uuid
    REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.agent_teams
  ADD COLUMN IF NOT EXISTS updated_at timestamptz
    NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS agent_teams_leader_id_idx ON public.agent_teams(leader_id);

ALTER TABLE public.agent_teams ENABLE ROW LEVEL SECURITY;

-- Allow anyone to view teams (for discovery/joining)
CREATE POLICY "anyone_view_teams" ON public.agent_teams
  FOR SELECT
  USING (true);

-- Leaders can create/update their own teams
CREATE POLICY "leaders_manage_teams" ON public.agent_teams
  FOR UPDATE
  USING (leader_id = auth.uid())
  WITH CHECK (leader_id = auth.uid());

CREATE POLICY "agents_create_teams" ON public.agent_teams
  FOR INSERT
  WITH CHECK (
    leader_id = auth.uid()
    AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'agent'
  );

-- Admins can manage any team
CREATE POLICY "admins_manage_all_teams" ON public.agent_teams
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- 8. TEAM MEMBERS TABLE
-- ============================================================================

ALTER TABLE public.team_members
  ADD COLUMN IF NOT EXISTS member_id uuid
    REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.team_members
  ADD COLUMN IF NOT EXISTS joined_at timestamptz
    NOT NULL DEFAULT now();

UPDATE public.team_members
SET member_id = user_id
WHERE member_id IS NULL
  AND user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS team_members_team_id_idx ON public.team_members(team_id);
CREATE INDEX IF NOT EXISTS team_members_member_id_idx ON public.team_members(member_id);

ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_view_team_members" ON public.team_members
  FOR SELECT
  USING (
    member_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.team_members tm
      WHERE tm.team_id = public.team_members.team_id
      AND tm.member_id = auth.uid()
    )
  );

CREATE POLICY "leaders_manage_members" ON public.team_members
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.agent_teams
      WHERE id = team_id AND leader_id = auth.uid()
    )
  );

CREATE POLICY "admins_manage_team_members" ON public.team_members
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- 9. SUBSCRIPTIONS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  tier text NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'premium', 'professional')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'expired', 'paused')),
  started_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  auto_renew boolean DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS subscriptions_user_id_idx ON public.subscriptions(user_id);
CREATE INDEX IF NOT EXISTS subscriptions_tier_idx ON public.subscriptions(tier);
CREATE INDEX IF NOT EXISTS subscriptions_expires_at_idx ON public.subscriptions(expires_at);

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can view their own subscription
CREATE POLICY "users_view_own_subscription" ON public.subscriptions
  FOR SELECT
  USING (user_id = auth.uid());

-- Users can update their own subscription (auto-renew setting)
CREATE POLICY "users_update_own_subscription" ON public.subscriptions
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid() AND tier = 'free'); -- Users can't change tier directly

-- System/Admin can update subscriptions (via functions)
CREATE POLICY "admins_manage_subscriptions" ON public.subscriptions
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- 10. MESSAGES TABLE
-- ============================================================================

-- The existing messaging model is conversation-based. Its participant RLS
-- policies are defined by the messaging migration and remain authoritative.
CREATE INDEX IF NOT EXISTS messages_conversation_id_created_at_idx
  ON public.messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS messages_sender_id_idx ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS messages_created_at_idx ON public.messages(created_at DESC);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 11. MODERATION TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.moderation_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reported_user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  reported_property_id uuid REFERENCES public.properties(id) ON DELETE CASCADE,
  reason text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'resolved', 'dismissed')),
  resolved_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolution_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS moderation_reporter_id_idx ON public.moderation_reports(reporter_id);
CREATE INDEX IF NOT EXISTS moderation_status_idx ON public.moderation_reports(status);
CREATE INDEX IF NOT EXISTS moderation_created_at_idx ON public.moderation_reports(created_at DESC);

ALTER TABLE public.moderation_reports ENABLE ROW LEVEL SECURITY;

-- Users can view their own reports
CREATE POLICY "users_view_own_reports" ON public.moderation_reports
  FOR SELECT
  USING (reporter_id = auth.uid());

-- Users can submit reports
CREATE POLICY "users_submit_reports" ON public.moderation_reports
  FOR INSERT
  WITH CHECK (reporter_id = auth.uid());

-- Admins can view and manage all reports
CREATE POLICY "admins_manage_reports" ON public.moderation_reports
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- 12. REVIEW TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  reviewer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS reviews_property_id_idx ON public.reviews(property_id);
CREATE INDEX IF NOT EXISTS reviews_reviewer_id_idx ON public.reviews(reviewer_id);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Anyone can view published reviews
CREATE POLICY "anyone_view_reviews" ON public.reviews
  FOR SELECT
  USING (true);

-- Users can submit reviews
CREATE POLICY "users_submit_reviews" ON public.reviews
  FOR INSERT
  WITH CHECK (reviewer_id = auth.uid());

-- Users can update their own reviews
CREATE POLICY "users_update_own_reviews" ON public.reviews
  FOR UPDATE
  USING (reviewer_id = auth.uid())
  WITH CHECK (reviewer_id = auth.uid());

-- Users can delete their own reviews
CREATE POLICY "users_delete_own_reviews" ON public.reviews
  FOR DELETE
  USING (reviewer_id = auth.uid());

-- Admins can delete any review
CREATE POLICY "admins_delete_reviews" ON public.reviews
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- 13. NOTIFICATIONS TABLE (if not exists)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type text NOT NULL,
  title text NOT NULL,
  message text,
  related_id uuid,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notifications_user_id_idx ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS notifications_created_at_idx ON public.notifications(created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Users can view their own notifications
CREATE POLICY "users_view_own_notifications" ON public.notifications
  FOR SELECT
  USING (user_id = auth.uid());

-- System can insert notifications
CREATE POLICY "system_insert_notifications" ON public.notifications
  FOR INSERT
  WITH CHECK (true);

-- Users can update their notifications (mark read)
CREATE POLICY "users_update_notifications" ON public.notifications
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- 14. GRANT NECESSARY PERMISSIONS
-- ============================================================================

-- Grant authenticated users access to execute their own operations
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.properties TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.inquiries TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.favorites TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.subscriptions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.messages TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.agent_teams TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.team_members TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.moderation_reports TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.reviews TO authenticated;

-- Grant public read access to published content
GRANT SELECT ON public.properties TO anon;
GRANT SELECT ON public.reviews TO anon;
GRANT SELECT ON public.agent_teams TO anon;

-- ============================================================================
-- 15. AUDIT FUNCTION (Optional - tracks changes)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name text NOT NULL,
  operation text NOT NULL,
  user_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS audit_logs_table_name_idx ON public.audit_logs(table_name);
CREATE INDEX IF NOT EXISTS audit_logs_user_id_idx ON public.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS audit_logs_created_at_idx ON public.audit_logs(created_at DESC);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Only admins can view audit logs
CREATE POLICY "admins_view_audit_logs" ON public.audit_logs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- 16. HELPER FUNCTIONS
-- ============================================================================

-- Function to get user role
CREATE OR REPLACE FUNCTION public.get_user_role(user_id uuid)
RETURNS text AS $$
BEGIN
  RETURN COALESCE(
    (SELECT role FROM public.profiles WHERE id = user_id),
    'guest'
  );
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin(user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN (SELECT role FROM public.profiles WHERE id = user_id) = 'admin';
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to check if user is agent
CREATE OR REPLACE FUNCTION public.is_agent(user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN (SELECT role FROM public.profiles WHERE id = user_id) IN ('agent', 'admin');
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to auto-create subscription on profile creation
CREATE OR REPLACE FUNCTION public.create_default_subscription()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.subscriptions (user_id, tier, status)
  VALUES (NEW.id, 'free', 'active')
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to create default subscription
DROP TRIGGER IF EXISTS trigger_create_default_subscription ON public.profiles;
CREATE TRIGGER trigger_create_default_subscription
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.create_default_subscription();

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
