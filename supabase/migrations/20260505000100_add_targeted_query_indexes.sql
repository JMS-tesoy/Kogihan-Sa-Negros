create index if not exists properties_created_at_idx
on public.properties (created_at desc);

create index if not exists negros_places_province_place_name_idx
on public.negros_places (province, place_name);

create index if not exists team_join_requests_status_created_at_idx
on public.team_join_requests (status, created_at desc);

create index if not exists profiles_role_created_at_idx
on public.profiles (role, created_at desc);
