-- FootTime — Lot 1 : schéma, contraintes, RLS, réservation atomique
-- Conventions : montants en FCFA (integer), horodatages en timestamptz (UTC),
-- fuseau d'affichage par ville (cities.timezone, défaut Africa/Dakar).

create extension if not exists btree_gist;
create extension if not exists pgcrypto;

-- ───────── Types ─────────
create type user_role as enum ('JOUEUR','PROPRIETAIRE','GESTIONNAIRE','ADMIN_FOOTTIME');
create type account_status as enum ('ACTIVE','SUSPENDED','PENDING');
create type booking_status as enum ('PENDING_PAYMENT','CONFIRMED','CANCELLED','EXPIRED','COMPLETED','NO_SHOW');
create type payment_status as enum ('PENDING','SUCCEEDED','FAILED','CANCELLED');
create type review_status as enum ('PENDING','APPROVED','REJECTED');
create type report_kind as enum ('CLOSURE','UNAVAILABLE','TECHNICAL','OTHER');
create type report_status as enum ('OPEN','IN_PROGRESS','RESOLVED');
create type manager_status as enum ('PENDING','ACTIVE','REVOKED');

-- ───────── Tables ─────────
create table cities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  timezone text not null default 'Africa/Dakar',
  is_active boolean not null default true
);

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null default '',
  last_name text not null default '',
  phone text,
  email text,
  role user_role not null default 'JOUEUR',
  status account_status not null default 'ACTIVE',
  created_at timestamptz not null default now()
);

create table owners (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references profiles(id) on delete restrict,
  business_name text,
  status account_status not null default 'PENDING',
  created_at timestamptz not null default now()
);

create table venues (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references cities(id),
  owner_id uuid references owners(id),
  name text not null,
  neighborhood text,
  address text,
  description text,
  latitude numeric(9,6),
  longitude numeric(9,6),
  price_per_hour integer not null check (price_per_hour > 0),
  has_lighting boolean not null default false,
  has_lockers boolean not null default false,
  has_showers boolean not null default false,
  has_parking boolean not null default false,
  amenities text[] not null default '{}',
  rules text,
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);
create index on venues (city_id, is_active);
create index on venues (owner_id);

create table venue_photos (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references venues(id) on delete cascade,
  storage_path text not null,
  position integer not null default 0
);
create index on venue_photos (venue_id);

create table venue_managers (
  venue_id uuid not null references venues(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  permissions jsonb not null default '{}'::jsonb,
  status manager_status not null default 'PENDING',
  primary key (venue_id, profile_id)
);

create table venue_opening_hours (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references venues(id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6), -- 0 = dimanche
  opens_at time not null,
  closes_at time not null,
  check (closes_at > opens_at),
  unique (venue_id, weekday)
);

create table venue_closures (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references venues(id) on delete cascade,
  during tstzrange not null,
  reason text,
  created_by uuid references profiles(id),
  exclude using gist (venue_id with =, during with &&)
);

create table platform_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);
insert into platform_settings (key, value) values
  ('deposit_percent',            '30'::jsonb),
  ('commission_bps',             '1000'::jsonb),   -- 10,00 % du total payé
  ('pending_payment_ttl_minutes','15'::jsonb),
  ('max_modifications',          '2'::jsonb),
  ('cancellation_rules',         '"À définir par FootTime avant la mise en production."'::jsonb),
  ('no_show_rules',              '"À définir par FootTime avant la mise en production."'::jsonb);

create table bookings (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  venue_id uuid not null references venues(id),
  player_id uuid not null references profiles(id),
  during tstzrange not null,
  duration_hours smallint not null check (duration_hours between 1 and 8),
  total_amount integer not null check (total_amount >= 0),
  deposit_amount integer not null check (deposit_amount >= 0),
  balance_amount integer not null check (balance_amount >= 0),
  commission_amount integer not null check (commission_amount >= 0),
  venue_amount integer not null check (venue_amount >= 0),
  status booking_status not null default 'PENDING_PAYMENT',
  modification_count smallint not null default 0 check (modification_count between 0 and 2),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  -- Anti double réservation : deux réservations actives ne peuvent pas se chevaucher.
  constraint no_overlap exclude using gist (venue_id with =, during with &&)
    where (status in ('PENDING_PAYMENT','CONFIRMED','COMPLETED','NO_SHOW'))
);
create index on bookings (player_id, created_at desc);
create index on bookings (venue_id, status);

create table payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references bookings(id) on delete restrict,
  provider text not null,                       -- 'WAVE', 'ORANGE_MONEY', ...
  amount integer not null check (amount > 0),
  status payment_status not null default 'PENDING',
  provider_reference text,
  raw_event jsonb,
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  unique (provider, provider_reference)
);
create index on payments (booking_id);

create table reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references bookings(id),
  venue_id uuid not null references venues(id),
  player_id uuid not null references profiles(id),
  rating smallint not null check (rating between 1 and 5),
  comment text,
  status review_status not null default 'PENDING',
  created_at timestamptz not null default now()
);
create index on reviews (venue_id, status);

create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  kind text not null,
  title text not null,
  body text,
  channel text not null default 'IN_APP',
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index on notifications (user_id, created_at desc);

create table reports (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references venues(id) on delete cascade,
  reporter_id uuid not null references profiles(id),
  kind report_kind not null,
  message text not null,
  status report_status not null default 'OPEN',
  created_at timestamptz not null default now()
);

-- ───────── Fonctions d'autorisation ─────────
create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles
                 where id = auth.uid() and role = 'ADMIN_FOOTTIME' and status = 'ACTIVE');
$$;

create or replace function can_access_venue(v uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_admin()
  or exists (select 1 from venues ve join owners o on o.id = ve.owner_id
             where ve.id = v and o.profile_id = auth.uid() and o.status = 'ACTIVE')
  or exists (select 1 from venue_managers m
             where m.venue_id = v and m.profile_id = auth.uid() and m.status = 'ACTIVE');
$$;

-- ───────── Profil auto + anti-escalade de rôle ─────────
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, first_name, last_name, phone, email)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'first_name',''),
          coalesce(new.raw_user_meta_data->>'last_name',''),
          new.raw_user_meta_data->>'phone',
          new.email);                       -- rôle toujours JOUEUR par défaut
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

create or replace function protect_profile_columns() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() and auth.role() <> 'service_role'
     and (new.role <> old.role or new.status <> old.status or new.id <> old.id) then
    raise exception 'Modification du rôle ou du statut interdite';
  end if;
  return new;
end $$;
create trigger profiles_protect before update on profiles
  for each row execute function protect_profile_columns();

-- ───────── RLS ─────────
alter table cities               enable row level security;
alter table profiles             enable row level security;
alter table owners               enable row level security;
alter table venues               enable row level security;
alter table venue_photos         enable row level security;
alter table venue_managers       enable row level security;
alter table venue_opening_hours  enable row level security;
alter table venue_closures       enable row level security;
alter table platform_settings    enable row level security;
alter table bookings             enable row level security;
alter table payments             enable row level security;
alter table reviews              enable row level security;
alter table notifications        enable row level security;
alter table reports              enable row level security;

-- cities
create policy cities_read  on cities for select using (is_active or is_admin());
create policy cities_admin on cities for all using (is_admin()) with check (is_admin());

-- profiles
create policy profiles_self_read   on profiles for select using (id = auth.uid() or is_admin());
create policy profiles_self_update on profiles for update using (id = auth.uid() or is_admin())
  with check (id = auth.uid() or is_admin());
create policy profiles_admin_all   on profiles for all using (is_admin()) with check (is_admin());

-- owners (lecture par le propriétaire lui-même ; gestion par l'admin)
create policy owners_read  on owners for select using (profile_id = auth.uid() or is_admin());
create policy owners_admin on owners for all using (is_admin()) with check (is_admin());

-- venues : publiques si actives ; staff sur son périmètre ; écriture admin uniquement
create policy venues_public_read on venues for select using (is_active or can_access_venue(id));
create policy venues_admin_write on venues for all using (is_admin()) with check (is_admin());

create policy photos_read  on venue_photos for select
  using (exists (select 1 from venues v where v.id = venue_id and (v.is_active or can_access_venue(v.id))));
create policy photos_admin on venue_photos for all using (is_admin()) with check (is_admin());

create policy hours_read  on venue_opening_hours for select
  using (exists (select 1 from venues v where v.id = venue_id and (v.is_active or can_access_venue(v.id))));
create policy hours_admin on venue_opening_hours for all using (is_admin()) with check (is_admin());

-- gestionnaires : vus par le personnel du terrain ; le propriétaire propose (PENDING), l'admin active
create policy managers_read on venue_managers for select
  using (can_access_venue(venue_id) or profile_id = auth.uid());
create policy managers_owner_propose on venue_managers for insert
  with check (status = 'PENDING' and exists (
    select 1 from venues ve join owners o on o.id = ve.owner_id
    where ve.id = venue_id and o.profile_id = auth.uid() and o.status = 'ACTIVE'));
create policy managers_admin on venue_managers for all using (is_admin()) with check (is_admin());

-- fermetures : le staff les voit et peut en créer ; l'admin gère tout
create policy closures_staff_read   on venue_closures for select using (can_access_venue(venue_id));
create policy closures_staff_insert on venue_closures for insert
  with check (can_access_venue(venue_id) and created_by = auth.uid());
create policy closures_admin        on venue_closures for all using (is_admin()) with check (is_admin());

-- paramètres : lecture authentifiée, écriture admin
create policy settings_read  on platform_settings for select using (auth.role() = 'authenticated');
create policy settings_admin on platform_settings for all using (is_admin()) with check (is_admin());

-- bookings : lecture seule côté client (écritures via Edge Functions / service_role)
create policy bookings_player_read on bookings for select using (player_id = auth.uid());
create policy bookings_staff_read  on bookings for select using (can_access_venue(venue_id));

-- payments : lecture seule, jamais d'écriture client
create policy payments_read on payments for select using (
  exists (select 1 from bookings b where b.id = booking_id
          and (b.player_id = auth.uid() or can_access_venue(b.venue_id))));

-- reviews : publics si approuvés ; dépôt seulement après réservation terminée
create policy reviews_public_read on reviews for select
  using (status = 'APPROVED' or player_id = auth.uid() or is_admin());
create policy reviews_insert on reviews for insert with check (
  player_id = auth.uid() and status = 'PENDING' and exists (
    select 1 from bookings b where b.id = booking_id and b.player_id = auth.uid()
      and b.venue_id = reviews.venue_id and b.status = 'COMPLETED'));
create policy reviews_admin on reviews for all using (is_admin()) with check (is_admin());

-- notifications
create policy notif_read   on notifications for select using (user_id = auth.uid());
create policy notif_update on notifications for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- reports
create policy reports_read   on reports for select using (can_access_venue(venue_id));
create policy reports_insert on reports for insert
  with check (can_access_venue(venue_id) and reporter_id = auth.uid());
create policy reports_admin  on reports for all using (is_admin()) with check (is_admin());

-- ───────── Disponibilités (plages occupées uniquement, sans données personnelles) ─────────
create or replace function get_busy_ranges(p_venue uuid, p_from timestamptz, p_to timestamptz)
returns table (starts_at timestamptz, ends_at timestamptz)
language sql stable security definer set search_path = public as $$
  select lower(during), upper(during) from bookings
   where venue_id = p_venue and during && tstzrange(p_from, p_to)
     and (status in ('CONFIRMED','COMPLETED','NO_SHOW')
          or (status = 'PENDING_PAYMENT' and expires_at > now()))
  union all
  select lower(during), upper(during) from venue_closures
   where venue_id = p_venue and during && tstzrange(p_from, p_to);
$$;
grant execute on function get_busy_ranges(uuid, timestamptz, timestamptz) to anon, authenticated;

-- ───────── Réservation atomique (appelée uniquement par l'Edge Function) ─────────
create or replace function expire_pending_bookings() returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  update bookings set status = 'EXPIRED'
   where status = 'PENDING_PAYMENT' and expires_at <= now();
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function create_pending_booking(
  p_player uuid, p_venue uuid, p_start timestamptz, p_hours integer)
returns bookings
language plpgsql security definer set search_path = public as $$
declare
  v venues; tz text; wd smallint; oh venue_opening_hours;
  s_local timestamp; e_local timestamp;
  price integer; total integer; dep integer; comm integer;
  dep_pct integer; comm_bps integer; ttl integer;
  b bookings;
begin
  if p_hours < 1 or p_hours > 8 then raise exception 'Durée invalide'; end if;
  if p_start <= now() then raise exception 'Créneau dans le passé'; end if;
  if extract(minute from p_start) <> 0 or extract(second from p_start) <> 0 then
    raise exception 'Le début doit tomber sur une heure pile'; end if;

  select * into v from venues where id = p_venue and is_active;
  if not found then raise exception 'Terrain indisponible'; end if;
  select timezone into tz from cities where id = v.city_id;

  s_local := p_start at time zone tz;
  e_local := (p_start + make_interval(hours => p_hours)) at time zone tz;
  wd := extract(dow from s_local)::smallint;
  select * into oh from venue_opening_hours where venue_id = p_venue and weekday = wd;
  if not found or s_local::date <> e_local::date
     or s_local::time < oh.opens_at or e_local::time > oh.closes_at then
    raise exception 'Hors horaires d''ouverture';
  end if;

  if exists (select 1 from venue_closures
             where venue_id = p_venue
               and during && tstzrange(p_start, p_start + make_interval(hours => p_hours))) then
    raise exception 'Terrain fermé sur ce créneau';
  end if;

  perform expire_pending_bookings();

  dep_pct  := (select (value)::text::integer from platform_settings where key = 'deposit_percent');
  comm_bps := (select (value)::text::integer from platform_settings where key = 'commission_bps');
  ttl      := (select (value)::text::integer from platform_settings where key = 'pending_payment_ttl_minutes');

  price := v.price_per_hour;
  total := price * p_hours;
  dep   := (total * dep_pct + 99) / 100;          -- arrondi à l'entier supérieur, sans flottants
  comm  := (total * comm_bps) / 10000;

  begin
    insert into bookings (code, venue_id, player_id, during, duration_hours,
                          total_amount, deposit_amount, balance_amount,
                          commission_amount, venue_amount, expires_at)
    values ('FT-' || upper(substr(encode(gen_random_bytes(5), 'hex'), 1, 8)),
            p_venue, p_player,
            tstzrange(p_start, p_start + make_interval(hours => p_hours)), p_hours,
            total, dep, total - dep, comm, total - comm,
            now() + make_interval(mins => ttl))
    returning * into b;
  exception when exclusion_violation then
    raise exception 'Créneau déjà réservé' using errcode = 'P0001';
  end;
  return b;
end $$;

revoke all on function create_pending_booking(uuid, uuid, timestamptz, integer) from public, anon, authenticated;
revoke all on function expire_pending_bookings() from public, anon, authenticated;
grant execute on function create_pending_booking(uuid, uuid, timestamptz, integer) to service_role;
grant execute on function expire_pending_bookings() to service_role;

-- ───────── Storage : bucket photos (lecture publique, écriture admin) ─────────
insert into storage.buckets (id, name, public) values ('venue-photos', 'venue-photos', true)
on conflict (id) do nothing;
create policy venue_photos_admin_write on storage.objects for all
  using (bucket_id = 'venue-photos' and is_admin())
  with check (bucket_id = 'venue-photos' and is_admin());

-- Ville de lancement (donnée de référence, pas de donnée métier fictive)
insert into cities (name, slug) values ('Kaolack', 'kaolack') on conflict (slug) do nothing;
