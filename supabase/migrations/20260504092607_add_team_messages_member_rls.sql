alter table public.team_messages enable row level security;

drop policy if exists "Team members can view team messages" on public.team_messages;
create policy "Team members can view team messages"
on public.team_messages
for select
to authenticated
using (
  exists (
    select 1
    from public.team_members tm
    where tm.team_id = team_messages.team_id
      and tm.user_id = auth.uid()
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
    from public.team_members tm
    where tm.team_id = team_messages.team_id
      and tm.user_id = auth.uid()
  )
);

drop policy if exists "Team members can update their own team messages" on public.team_messages;
create policy "Team members can update their own team messages"
on public.team_messages
for update
to authenticated
using (
  sender_id = auth.uid()
)
with check (
  sender_id = auth.uid()
);

drop policy if exists "Team members can delete their own team messages" on public.team_messages;
create policy "Team members can delete their own team messages"
on public.team_messages
for delete
to authenticated
using (
  sender_id = auth.uid()
);