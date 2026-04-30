create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  phone text,
  full_name text,
  role text not null default 'user' check (role in ('user', 'agent', 'admin')),
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles (id) on delete cascade,
  agent_id uuid not null references public.profiles (id) on delete cascade,
  property_id uuid references public.properties (id) on delete set null,
  subject text not null default '',
  last_message_preview text not null default '',
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (buyer_id <> agent_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  body text not null,
  message_type text not null default 'text' check (message_type in ('text')),
  read_at timestamptz,
  created_at timestamptz not null default now(),
  check (length(btrim(body)) > 0)
);

create index if not exists conversations_buyer_id_idx
  on public.conversations (buyer_id);

create index if not exists conversations_agent_id_idx
  on public.conversations (agent_id);

create index if not exists conversations_property_id_idx
  on public.conversations (property_id);

create index if not exists conversations_last_message_at_idx
  on public.conversations (last_message_at desc nulls last);

create index if not exists messages_conversation_id_created_at_idx
  on public.messages (conversation_id, created_at desc);

create index if not exists messages_sender_id_idx
  on public.messages (sender_id);

create or replace function public.is_admin()
returns boolean
language sql
stable
set search_path = ''
as $$
  select lower(
    coalesce(
      auth.jwt() -> 'app_metadata' ->> 'role',
      auth.jwt() -> 'user_metadata' ->> 'role',
      ''
    )
  ) = 'admin';
$$;

create or replace function public.set_updated_at_timestamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.sync_profile_from_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    email,
    phone,
    full_name,
    role,
    avatar_url
  )
  values (
    new.id,
    new.email,
    new.phone,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name'
    ),
    case lower(
      coalesce(
        new.raw_app_meta_data ->> 'role',
        new.raw_user_meta_data ->> 'role',
        'user'
      )
    )
      when 'admin' then 'admin'
      when 'agent' then 'agent'
      else 'user'
    end,
    coalesce(
      new.raw_user_meta_data ->> 'avatar_url',
      new.raw_user_meta_data ->> 'picture'
    )
  )
  on conflict (id) do update
  set
    email = excluded.email,
    phone = excluded.phone,
    full_name = coalesce(excluded.full_name, public.profiles.full_name),
    role = excluded.role,
    avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url),
    updated_at = now();

  return new;
end;
$$;

create or replace function public.touch_conversation_from_message()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_conversation_id uuid;
  latest_message record;
begin
  target_conversation_id := coalesce(new.conversation_id, old.conversation_id);

  select body, created_at
  into latest_message
  from public.messages
  where conversation_id = target_conversation_id
  order by created_at desc, id desc
  limit 1;

  update public.conversations
  set
    last_message_preview = coalesce(left(latest_message.body, 120), ''),
    last_message_at = latest_message.created_at,
    updated_at = now()
  where id = target_conversation_id;

  return coalesce(new, old);
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at_timestamp();

drop trigger if exists conversations_set_updated_at on public.conversations;
create trigger conversations_set_updated_at
before update on public.conversations
for each row
execute function public.set_updated_at_timestamp();

drop trigger if exists on_auth_user_changed_sync_profile on auth.users;
create trigger on_auth_user_changed_sync_profile
after insert or update of email, phone, raw_user_meta_data, raw_app_meta_data
on auth.users
for each row
execute function public.sync_profile_from_auth_user();

drop trigger if exists messages_touch_conversation on public.messages;
create trigger messages_touch_conversation
after insert or update or delete on public.messages
for each row
execute function public.touch_conversation_from_message();

insert into public.profiles (
  id,
  email,
  phone,
  full_name,
  role,
  avatar_url
)
select
  users.id,
  users.email,
  users.phone,
  coalesce(
    users.raw_user_meta_data ->> 'full_name',
    users.raw_user_meta_data ->> 'name'
  ),
  case lower(
    coalesce(
      users.raw_app_meta_data ->> 'role',
      users.raw_user_meta_data ->> 'role',
      'user'
    )
  )
    when 'admin' then 'admin'
    when 'agent' then 'agent'
    else 'user'
  end,
  coalesce(
    users.raw_user_meta_data ->> 'avatar_url',
    users.raw_user_meta_data ->> 'picture'
  )
from auth.users as users
on conflict (id) do update
set
  email = excluded.email,
  phone = excluded.phone,
  full_name = coalesce(excluded.full_name, public.profiles.full_name),
  role = excluded.role,
  avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url),
  updated_at = now();

alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

drop policy if exists "Users can view related profiles" on public.profiles;
create policy "Users can view related profiles"
on public.profiles
for select
to authenticated
using (
  public.is_admin()
  or auth.uid() = id
  or exists (
    select 1
    from public.conversations
    where (buyer_id = auth.uid() or agent_id = auth.uid())
      and (public.profiles.id = buyer_id or public.profiles.id = agent_id)
  )
);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
on public.profiles
for update
to authenticated
using (
  public.is_admin()
  or auth.uid() = id
)
with check (
  public.is_admin()
  or auth.uid() = id
);

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
on public.profiles
for insert
to authenticated
with check (
  public.is_admin()
  or auth.uid() = id
);

drop policy if exists "Participants can view conversations" on public.conversations;
create policy "Participants can view conversations"
on public.conversations
for select
to authenticated
using (
  public.is_admin()
  or auth.uid() = buyer_id
  or auth.uid() = agent_id
);

drop policy if exists "Participants can create conversations" on public.conversations;
create policy "Participants can create conversations"
on public.conversations
for insert
to authenticated
with check (
  public.is_admin()
  or auth.uid() = buyer_id
  or auth.uid() = agent_id
);

drop policy if exists "Participants can update conversations" on public.conversations;
create policy "Participants can update conversations"
on public.conversations
for update
to authenticated
using (
  public.is_admin()
  or auth.uid() = buyer_id
  or auth.uid() = agent_id
)
with check (
  public.is_admin()
  or auth.uid() = buyer_id
  or auth.uid() = agent_id
);

drop policy if exists "Participants can delete conversations" on public.conversations;
create policy "Participants can delete conversations"
on public.conversations
for delete
to authenticated
using (
  public.is_admin()
  or auth.uid() = buyer_id
  or auth.uid() = agent_id
);

drop policy if exists "Participants can view messages" on public.messages;
create policy "Participants can view messages"
on public.messages
for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.conversations
    where public.conversations.id = public.messages.conversation_id
      and (
        public.conversations.buyer_id = auth.uid()
        or public.conversations.agent_id = auth.uid()
      )
  )
);

drop policy if exists "Participants can send messages" on public.messages;
create policy "Participants can send messages"
on public.messages
for insert
to authenticated
with check (
  public.is_admin()
  or (
    auth.uid() = sender_id
    and exists (
      select 1
      from public.conversations
      where public.conversations.id = public.messages.conversation_id
        and (
          public.conversations.buyer_id = auth.uid()
          or public.conversations.agent_id = auth.uid()
        )
    )
  )
);

drop policy if exists "Participants can update messages" on public.messages;
create policy "Senders can update own messages"
on public.messages
for update
to authenticated
using (
  public.is_admin()
  or (
    auth.uid() = sender_id
    and exists (
      select 1
      from public.conversations
      where public.conversations.id = public.messages.conversation_id
        and (
          public.conversations.buyer_id = auth.uid()
          or public.conversations.agent_id = auth.uid()
        )
    )
  )
)
with check (
  public.is_admin()
  or (
    auth.uid() = sender_id
    and exists (
      select 1
      from public.conversations
      where public.conversations.id = public.messages.conversation_id
        and (
          public.conversations.buyer_id = auth.uid()
          or public.conversations.agent_id = auth.uid()
        )
    )
  )
);

drop policy if exists "Senders can delete own messages" on public.messages;
create policy "Senders can delete own messages"
on public.messages
for delete
to authenticated
using (
  public.is_admin()
  or (
    auth.uid() = sender_id
    and exists (
      select 1
      from public.conversations
      where public.conversations.id = public.messages.conversation_id
        and (
          public.conversations.buyer_id = auth.uid()
          or public.conversations.agent_id = auth.uid()
        )
    )
  )
);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'conversations'
  ) then
    alter publication supabase_realtime add table public.conversations;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;
