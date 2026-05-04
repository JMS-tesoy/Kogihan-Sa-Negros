alter table public.team_messages enable row level security;

alter table public.team_messages
drop constraint if exists team_messages_body_not_empty;

alter table public.team_messages
add constraint team_messages_body_not_empty
check (length(trim(body)) > 0);

alter table public.team_messages
drop constraint if exists team_messages_body_max_length;

alter table public.team_messages
add constraint team_messages_body_max_length
check (char_length(body) <= 1000);

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
  and length(trim(body)) > 0
  and char_length(body) <= 1000
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
  and length(trim(body)) > 0
  and char_length(body) <= 1000
);

drop policy if exists "Team members can delete their own team messages" on public.team_messages;
create policy "Team members can delete their own team messages"
on public.team_messages
for delete
to authenticated
using (
  sender_id = auth.uid()
);