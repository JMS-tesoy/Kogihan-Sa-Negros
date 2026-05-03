-- Chat attachment support for buyer/agent messages and admin team inbox messages.

alter table public.messages
add column if not exists attachment_url text,
add column if not exists attachment_path text,
add column if not exists attachment_name text,
add column if not exists attachment_mime_type text,
add column if not exists attachment_size_bytes bigint;

alter table public.team_messages
add column if not exists attachment_url text,
add column if not exists attachment_path text,
add column if not exists attachment_name text,
add column if not exists attachment_mime_type text,
add column if not exists attachment_size_bytes bigint;

insert into storage.buckets (id, name, public)
values ('chat-attachments', 'chat-attachments', true)
on conflict (id) do update
set public = true;

drop policy if exists "Authenticated users can upload chat attachments" on storage.objects;
drop policy if exists "Authenticated users can read chat attachments" on storage.objects;
drop policy if exists "Users can update own chat attachments" on storage.objects;
drop policy if exists "Users can delete own chat attachments" on storage.objects;

create policy "Authenticated users can upload chat attachments"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'chat-attachments'
);

create policy "Authenticated users can read chat attachments"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'chat-attachments'
);

create policy "Users can update own chat attachments"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'chat-attachments'
  and owner = auth.uid()
)
with check (
  bucket_id = 'chat-attachments'
  and owner = auth.uid()
);

create policy "Users can delete own chat attachments"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'chat-attachments'
  and owner = auth.uid()
);