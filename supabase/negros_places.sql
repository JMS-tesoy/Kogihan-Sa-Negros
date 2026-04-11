create table if not exists public.negros_places (
  id bigserial primary key,
  place_name text not null,
  province text not null,
  location text not null unique
);

alter table public.negros_places enable row level security;

drop policy if exists "Authenticated users can view negros places" on public.negros_places;
create policy "Authenticated users can view negros places"
on public.negros_places
for select
to authenticated
using (true);

insert into public.negros_places (place_name, province, location)
values
  ('Bacolod City', 'Negros Occidental', '10.6676,122.9503'),
  ('Bago City', 'Negros Occidental', '10.5389,122.8366'),
  ('San Carlos City', 'Negros Occidental', '10.4824,123.4183'),
  ('La Carlota City', 'Negros Occidental', '10.4253,122.9224'),
  ('Cadiz City', 'Negros Occidental', '10.9545,123.3058'),
  ('Escalante City', 'Negros Occidental', '10.8412,123.4992'),
  ('Silay City', 'Negros Occidental', '10.7977,122.9730'),
  ('Victorias City', 'Negros Occidental', '10.8962,123.0726'),
  ('Sagay City', 'Negros Occidental', '10.9000,123.4167'),
  ('Talisay City', 'Negros Occidental', '10.7333,122.9667'),
  ('Himamaylan City', 'Negros Occidental', '10.1000,122.8667'),
  ('Kabankalan City', 'Negros Occidental', '9.9833,122.8167'),
  ('Sipalay City', 'Negros Occidental', '9.7500,122.4000'),
  ('Dumaguete City', 'Negros Oriental', '9.3054,123.3080'),
  ('Bayawan City', 'Negros Oriental', '9.3668,122.8055'),
  ('Bais City', 'Negros Oriental', '9.5914,123.1213'),
  ('Guihulngan City', 'Negros Oriental', '10.1199,123.2728'),
  ('Canlaon City', 'Negros Oriental', '10.3833,123.2167'),
  ('Tanjay City', 'Negros Oriental', '9.5121,123.1596'),
  ('Bacong', 'Negros Oriental', '9.2452,123.2951'),
  ('Dauin', 'Negros Oriental', '9.1911,123.2655'),
  ('Valencia', 'Negros Oriental', '9.2817,123.2446'),
  ('Sibulan', 'Negros Oriental', '9.3667,123.2833'),
  ('Amlan', 'Negros Oriental', '9.4636,123.2266'),
  ('Ayungon', 'Negros Oriental', '9.8587,123.1436'),
  ('San Jose', 'Negros Oriental', '9.4138,123.2417')
on conflict (location) do nothing;
