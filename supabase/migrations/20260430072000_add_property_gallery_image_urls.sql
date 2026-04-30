alter table if exists public.properties
add column if not exists image_urls text[] not null default '{}';
