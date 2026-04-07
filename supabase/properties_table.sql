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
  updated_at timestamptz not null default now()
);

alter table public.properties
add column if not exists thumbnail_url text;

create or replace function public.set_properties_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists properties_set_updated_at on public.properties;

create trigger properties_set_updated_at
before update on public.properties
for each row
execute function public.set_properties_updated_at();

alter table public.properties enable row level security;

drop policy if exists "Authenticated users can view properties" on public.properties;
create policy "Authenticated users can view properties"
on public.properties
for select
to authenticated
using (true);

drop policy if exists "Admins can insert properties" on public.properties;
create policy "Admins can insert properties"
on public.properties
for insert
to authenticated
with check ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');

drop policy if exists "Admins can update properties" on public.properties;
create policy "Admins can update properties"
on public.properties
for update
to authenticated
using ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin')
with check ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');

drop policy if exists "Admins can delete properties" on public.properties;
create policy "Admins can delete properties"
on public.properties
for delete
to authenticated
using ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');

insert into public.properties (
  id,
  title,
  location,
  price,
  price_value,
  size,
  size_value,
  tag,
  image_color
)
values
  (
    '11111111-1111-1111-1111-111111111111',
    'Prime Residential Lot',
    '9.3077, 123.3054',
    '₱1,200,000',
    1200000,
    '500 sqm',
    500,
    'Featured',
    -6501275
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    'Mountain View Land',
    '9.2516, 123.2400',
    '₱2,450,000',
    2450000,
    '1,200 sqm',
    1200,
    'Hot Deal',
    -6190977
  ),
  (
    '33333333-3333-3333-3333-333333333333',
    'Farm Lot Investment',
    '10.3370, 123.8980',
    '₱3,100,000',
    3100000,
    '2,000 sqm',
    2000,
    'New',
    -10177034
  ),
  (
    '44444444-4444-4444-4444-444444444444',
    'Highway Frontage Lot',
    '9.3580, 123.2851',
    '₱4,800,000',
    4800000,
    '1,500 sqm',
    1500,
    'Premium',
    -4560696
  ),
  (
    '55555555-5555-5555-5555-555555555555',
    'Affordable Starter Lot',
    '9.3647, 122.8044',
    '₱900,000',
    900000,
    '300 sqm',
    300,
    'Budget',
    -18611
  )
on conflict (id) do nothing;
