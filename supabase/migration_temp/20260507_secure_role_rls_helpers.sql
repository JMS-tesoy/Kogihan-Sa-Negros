-- =========================================================
-- Secure role helpers for RLS
-- Removes the need to trust user_metadata.role in policies.
-- Uses database-backed profiles.role instead.
-- =========================================================

-- 1) Admin role check
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and lower(coalesce(profiles.role, '')) = 'admin'
  );
$$;

-- 2) Agent role check
create or replace function public.is_agent()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and lower(coalesce(profiles.role, '')) in ('agent', 'admin')
  );
$$;

-- 3) Buyer/user role check
create or replace function public.is_buyer()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and lower(coalesce(profiles.role, '')) in ('buyer', 'user')
  );
$$;

-- 4) Team admin check
create or replace function public.is_team_admin(target_team_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.team_members
    where team_members.team_id = target_team_id
      and team_members.user_id = auth.uid()
      and lower(coalesce(team_members.role, '')) in ('admin', 'owner', 'team_admin')
      and lower(coalesce(team_members.status, '')) = 'approved'
  );
$$;

-- 5) Team member check
create or replace function public.is_team_member(target_team_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.team_members
    where team_members.team_id = target_team_id
      and team_members.user_id = auth.uid()
      and lower(coalesce(team_members.status, '')) = 'approved'
  );
$$;

-- 6) Optional: allow authenticated users to execute helper functions.
-- These functions only return true/false and are intended for RLS.
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_agent() to authenticated;
grant execute on function public.is_buyer() to authenticated;
grant execute on function public.is_team_admin(uuid) to authenticated;
grant execute on function public.is_team_member(uuid) to authenticated;