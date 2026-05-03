-- Team Inbox realtime chat support
-- Safe additive migration: creates team_messages only.

create extension if not exists pgcrypto;

create table if not exists public.team_messages (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.agent_teams(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  sender_name text not null default 'Agent',
  body text not null check (char_length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

create index if not exists team_messages_team_created_at_idx
  on public.team_messages (team_id, created_at desc);

alter table public.team_messages enable row level security;

drop policy if exists "Team members can read team messages" on public.team_messages;

create policy "Team members can read team messages"
  on public.team_messages
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.team_members member
      where member.team_id = team_messages.team_id
        and member.user_id = auth.uid()
    )
  );

drop policy if exists "Team members can send team messages" on public.team_messages;

create policy "Team members can send team messages"
  on public.team_messages
  for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1
      from public.team_members member
      where member.team_id = team_messages.team_id
        and member.user_id = auth.uid()
    )
  );

drop policy if exists "Senders can delete own team messages" on public.team_messages;

create policy "Senders can delete own team messages"
  on public.team_messages
  for delete
  to authenticated
  using (sender_id = auth.uid());

do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  )
  and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'team_messages'
  ) then
    alter publication supabase_realtime add table public.team_messages;
  end if;
end $$;