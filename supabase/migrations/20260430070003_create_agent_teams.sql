create table if not exists public.agent_teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text default '',
  logo_url text,
  specialization text default '',
  created_at timestamptz default now()
);

create table if not exists public.team_members (
  id uuid primary key default gen_random_uuid(),
  team_id uuid references public.agent_teams(id) on delete cascade,
  name text not null,
  role text default '',
  avatar_url text,
  phone text,
  email text,
  created_at timestamptz default now()
);

alter table public.agent_teams enable row level security;
alter table public.team_members enable row level security;

drop policy if exists "Public read" on public.agent_teams;
create policy "Public read"
on public.agent_teams
for select
using (true);

drop policy if exists "Public read" on public.team_members;
create policy "Public read"
on public.team_members
for select
using (true);

create table if not exists public.team_join_requests (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.agent_teams(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  message text default '',
  created_at timestamptz default now(),
  unique (team_id, user_id)
);

alter table public.team_join_requests enable row level security;

drop policy if exists "Users can create own team join requests"
on public.team_join_requests;
create policy "Users can create own team join requests"
on public.team_join_requests
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can view own team join requests"
on public.team_join_requests;
create policy "Users can view own team join requests"
on public.team_join_requests
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Admins can view all team join requests"
on public.team_join_requests;
create policy "Admins can view all team join requests"
on public.team_join_requests
for select
to authenticated
using (
  lower(
    coalesce(
      auth.jwt() -> 'app_metadata' ->> 'role',
      auth.jwt() -> 'user_metadata' ->> 'role',
      ''
    )
  ) = 'admin'
);

drop policy if exists "Admins can update team join requests"
on public.team_join_requests;
create policy "Admins can update team join requests"
on public.team_join_requests
for update
to authenticated
using (
  lower(
    coalesce(
      auth.jwt() -> 'app_metadata' ->> 'role',
      auth.jwt() -> 'user_metadata' ->> 'role',
      ''
    )
  ) = 'admin'
)
with check (
  lower(
    coalesce(
      auth.jwt() -> 'app_metadata' ->> 'role',
      auth.jwt() -> 'user_metadata' ->> 'role',
      ''
    )
  ) = 'admin'
);

drop policy if exists "Admins can add team members"
on public.team_members;
create policy "Admins can add team members"
on public.team_members
for insert
to authenticated
with check (
  lower(
    coalesce(
      auth.jwt() -> 'app_metadata' ->> 'role',
      auth.jwt() -> 'user_metadata' ->> 'role',
      ''
    )
  ) = 'admin'
);
