create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  phone text,
  full_name text,
  role text not null default 'user',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  fcm_token text,
  constraint profiles_role_check check (role = any (array['user', 'agent', 'admin']))
);

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  location text not null,
  price text not null,
  price_value integer not null default 0,
  size text not null,
  size_value integer not null default 0,
  tag text not null default '',
  image_color integer not null default -6501275,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  image_url text,
  reference_code text not null default '',
  description text not null default '',
  title_status text not null default '',
  thumbnail_url text,
  boundary_coordinates text
);

create or replace function public.set_properties_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
