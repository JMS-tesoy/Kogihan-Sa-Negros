create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  message text not null,
  type text not null default 'system_notice',
  related_property_id uuid null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.notifications enable row level security;

drop policy if exists "Users can view their own notifications" on public.notifications;
create policy "Users can view their own notifications"
on public.notifications
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can update their own notifications" on public.notifications;
create policy "Users can update their own notifications"
on public.notifications
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can insert their own notifications" on public.notifications;
create policy "Users can insert their own notifications"
on public.notifications
for insert
to authenticated
with check (auth.uid() = user_id);

create index if not exists notifications_user_id_created_at_idx
on public.notifications (user_id, created_at desc);

create index if not exists notifications_user_id_is_read_idx
on public.notifications (user_id, is_read);