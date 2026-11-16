drop policy if exists "Admins can create agent teams"
on public.agent_teams;
create policy "Admins can create agent teams"
on public.agent_teams
for insert
to authenticated
with check (
  lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')) = 'admin'
);

drop policy if exists "Admins can update agent teams"
on public.agent_teams;
create policy "Admins can update agent teams"
on public.agent_teams
for update
to authenticated
using (
  lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')) = 'admin'
)
with check (
  lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')) = 'admin'
);

drop policy if exists "Admins can delete agent teams"
on public.agent_teams;
create policy "Admins can delete agent teams"
on public.agent_teams
for delete
to authenticated
using (
  lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')) = 'admin'
);

drop policy if exists "Admins can view all team join requests"
on public.team_join_requests;
create policy "Admins can view all team join requests"
on public.team_join_requests
for select
to authenticated
using (
  lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')) = 'admin'
);

drop policy if exists "Admins can update team join requests"
on public.team_join_requests;
create policy "Admins can update team join requests"
on public.team_join_requests
for update
to authenticated
using (
  lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')) = 'admin'
)
with check (
  lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')) = 'admin'
);

drop policy if exists "Admins can add team members"
on public.team_members;
create policy "Admins can add team members"
on public.team_members
for insert
to authenticated
with check (
  lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')) = 'admin'
);

drop policy if exists "Admins can update team members"
on public.team_members;
create policy "Admins can update team members"
on public.team_members
for update
to authenticated
using (
  lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')) = 'admin'
)
with check (
  lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')) = 'admin'
);

drop policy if exists "Admins can delete team members"
on public.team_members;
create policy "Admins can delete team members"
on public.team_members
for delete
to authenticated
using (
  lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')) = 'admin'
);