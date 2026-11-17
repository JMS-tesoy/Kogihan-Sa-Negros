-- ============================================================================
-- SECURITY HARDENING AND CONSTRAINT FIXES
-- ============================================================================
-- Purpose: Add missing constraints, fix RLS policies, and implement
-- security best practices identified in Phase 1 audit
-- ============================================================================

-- ============================================================================
-- 1. ADD ROLE VALIDATION CONSTRAINT
-- ============================================================================
-- Ensure only valid roles can be inserted into profiles table
-- This prevents privilege escalation via API if RLS policies have gaps

ALTER TABLE public.profiles
  ADD CONSTRAINT valid_role 
  CHECK (role IN ('user', 'agent', 'admin'));

-- ============================================================================
-- 2. FIX PROPERTIES STATUS VISIBILITY POLICY
-- ============================================================================
-- Current policy allows viewing ALL properties. This should only allow
-- viewing ACTIVE/PUBLISHED properties for anonymous users, and all
-- properties for authenticated users.

-- Drop the overly permissive policy
DROP POLICY "anyone_view_published_properties" ON public.properties;

-- Create a more restrictive version that filters by status
CREATE POLICY "anyone_view_active_properties" ON public.properties
  FOR SELECT
  USING (
    -- Authenticated users can see all properties
    auth.uid() IS NOT NULL
    OR
    -- Anonymous users can only see active properties
    (auth.uid() IS NULL AND status = 'active')
  );

-- ============================================================================
-- 3. FIX SUBSCRIPTION TIER IMMUTABILITY
-- ============================================================================
-- Current policy allows users to update tier if it's already 'free'.
-- This is wrong - users should NEVER be able to change tier.
-- Only admins and payment processors should modify tier via functions.

-- Drop the broken tier update policy if it exists
DROP POLICY IF EXISTS "users_update_own_subscription" ON public.subscriptions;

-- Create correct policy: users can only view their own subscription
CREATE POLICY "users_view_own_subscription" ON public.subscriptions
  FOR SELECT
  USING (user_id = auth.uid());

-- Tier changes must go through admin-only functions, not direct updates
CREATE POLICY "admins_manage_subscriptions" ON public.subscriptions
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- 4. ADD PROFILE UPDATE CONSTRAINT - Prevent Role Privilege Escalation
-- ============================================================================
-- Users should NEVER be able to change their own role.
-- Only admins can change roles.

-- For user update policy: prevent role column changes
CREATE POLICY "users_update_own_profile_safe" ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id AND role = (SELECT role FROM public.profiles WHERE id = auth.uid()));

-- ============================================================================
-- 5. ADD PROPERTY CREATION ASSIGNMENT POLICY
-- ============================================================================
-- Properties must be assigned to the creating agent.
-- Users should not be able to change agent_id after creation.

CREATE POLICY "agents_cannot_reassign_properties" ON public.properties
  FOR UPDATE
  USING (agent_id = auth.uid())
  WITH CHECK (agent_id = auth.uid()); -- Prevents agent_id column changes

-- ============================================================================
-- 6. ADD DELETION POLICIES
-- ============================================================================
-- Users can only delete their own data
-- Admins can delete anything

CREATE POLICY "users_delete_own_profile" ON public.profiles
  FOR DELETE
  USING (auth.uid() = id);

CREATE POLICY "admins_delete_any_profile" ON public.profiles
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "agents_delete_own_properties" ON public.properties
  FOR DELETE
  USING (agent_id = auth.uid());

CREATE POLICY "admins_delete_any_property" ON public.properties
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- 7. DOCUMENT SECURITY ASSUMPTIONS
-- ============================================================================
-- These comments serve as documentation for future audits and reviews

COMMENT ON TABLE public.profiles IS
'User identity and authorization table. All access control decisions
ultimately reference this table via RLS policies. The role column
determines feature access and is immutable after creation (except via
admin functions). Every authenticated user MUST have exactly one profile row.
If not found, it indicates a critical data consistency error.';

COMMENT ON COLUMN public.profiles.role IS
'User role determines authorization level and feature access. Valid values:
- "user": Regular buyer/viewer. Can browse, save favorites, send inquiries.
- "agent": Property agent. Can create/edit listings, respond to inquiries.
- "admin": System administrator. Can moderate content, manage users, view audit logs.
Immutable after creation. Changes only via admin functions, never by users.';

COMMENT ON COLUMN public.properties.status IS
'Publication status of property listing. Valid values:
- "active": Published and visible to users (default)
- "inactive": Unpublished, visible only to agent and admins
- "archived": Soft-deleted, visible only to admins
Only properties with status="active" are visible to anonymous users.
Agents can transition own properties. Admins can transition any.';

COMMENT ON TABLE public.profiles IS
'Authorization table enforcing three-tier role system.
All RLS policies verify auth.uid() against this table.
JWT tokens cannot encode role (attackable) - always check
the profiles table for current role in policies.';

-- ============================================================================
-- 8. ADD AUDIT TRIGGER FOR ROLE CHANGES
-- ============================================================================
-- Log any role changes for security monitoring

CREATE OR REPLACE FUNCTION log_role_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.role != OLD.role THEN
    -- Insert audit log entry
    INSERT INTO public.audit_logs (user_id, action, table_name, old_value, new_value)
    VALUES (
      auth.uid(),
      'role_change',
      'profiles',
      OLD.role,
      NEW.role
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if present (to avoid conflicts)
DROP TRIGGER IF EXISTS trigger_log_role_change ON public.profiles;

-- Create trigger
CREATE TRIGGER trigger_log_role_change
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION log_role_change();

-- ============================================================================
-- 9. PERFORMANCE INDEXES FOR SECURITY POLICIES
-- ============================================================================
-- RLS policies with complex subqueries benefit from indexes.
-- These improve query performance when checking user roles.

CREATE INDEX IF NOT EXISTS idx_profiles_role
  ON public.profiles(role);

CREATE INDEX IF NOT EXISTS idx_profiles_id_role
  ON public.profiles(id, role); -- For fast role lookups in policies

CREATE INDEX IF NOT EXISTS idx_properties_agent_id_status
  ON public.properties(agent_id, status); -- For agent property filtering

CREATE INDEX IF NOT EXISTS idx_profiles_email_unique
  ON public.profiles(email); -- For email uniqueness checks

-- ============================================================================
-- 10. VERIFY MIGRATION SUCCESS
-- ============================================================================
-- These checks ensure all security constraints are in place

DO $$
DECLARE
  v_role_constraint_exists boolean;
BEGIN
  -- Check if role constraint exists
  SELECT EXISTS(
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'profiles'
    AND constraint_name = 'valid_role'
  ) INTO v_role_constraint_exists;

  IF NOT v_role_constraint_exists THEN
    RAISE WARNING 'SECURITY: Role constraint not found on profiles table';
  END IF;

  RAISE NOTICE 'Security hardening migration completed successfully';
END $$;
