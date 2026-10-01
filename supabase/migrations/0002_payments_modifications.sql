-- FootTime — Lot 2 : règlement atomique des paiements, modification de réservation, maintenance

alter table payments add column if not exists needs_refund boolean not null default false;

insert into platform_settings (key, value) values
  ('modification_cutoff_hours', '24'::jsonb)   -- provisoire : à valider par FootTime
on conflict (key) do nothing;

-- Validation d'un créneau (horaires d'ouverture, fermetures, passé) — réutilisable
create or replace function assert_slot_valid(p_venue uuid, p_start timestamptz, p_hours integer)
returns void language plpgsql stable security definer set search_path = public as $$
declare
  v venues; tz text; oh venue_opening_hours; s_local timestamp; e_local timestamp;
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
  select * into oh from venue_opening_hours
   where venue_id = p_venue and weekday = extract(dow from s_local)::smallint;
  if not found or s_local::date <> e_local::date
     or s_local::time < oh.opens_at or e_local::time > oh.closes_at then
    raise exception 'Hors horaires d''ouverture';
  end if;
  if exists (select 1 from venue_closures where venue_id = p_venue
             and during && tstzrange(p_start, p_start + make_interval(hours => p_hours))) then
    raise exception 'Terrain fermé sur ce créneau';
  end if;
end $$;

-- Règlement d'un paiement : idempotent, atomique, vérifie le montant.
-- Retourne : CONFIRMED | ALREADY_PROCESSED | FAILED | AMOUNT_MISMATCH | NEEDS_REFUND | UNKNOWN_PAYMENT
create or replace function settle_payment(
  p_provider text, p_reference text, p_status payment_status, p_amount integer, p_raw jsonb)
returns text language plpgsql security definer set search_path = public as $$
declare
  pay payments; bk bookings; confirmed boolean := false;
begin
  select * into pay from payments
   where provider = p_provider and provider_reference = p_reference for update;
  if not found then return 'UNKNOWN_PAYMENT'; end if;
  if pay.status = 'SUCCEEDED' then return 'ALREADY_PROCESSED'; end if;

  select * into bk from bookings where id = pay.booking_id for update;

  if p_status in ('FAILED','CANCELLED') then
    update payments set status = p_status, raw_event = p_raw where id = pay.id;
    if bk.status = 'PENDING_PAYMENT' then
      update bookings set status = 'CANCELLED' where id = bk.id;
    end if;
    return 'FAILED';
  end if;

  if p_status <> 'SUCCEEDED' then return 'ALREADY_PROCESSED'; end if;   -- PENDING : rien à faire

  if p_amount is distinct from pay.amount then
    update payments set raw_event = p_raw where id = pay.id;            -- reste PENDING, à investiguer
    return 'AMOUNT_MISMATCH';
  end if;

  if bk.status = 'PENDING_PAYMENT' then
    update bookings set status = 'CONFIRMED', expires_at = null where id = bk.id;
    confirmed := true;
  elsif bk.status = 'EXPIRED' then
    begin   -- le créneau est-il encore libre ?
      update bookings set status = 'CONFIRMED', expires_at = null where id = bk.id;
      confirmed := true;
    exception when exclusion_violation then
      confirmed := false;
    end;
  end if;

  update payments set status = 'SUCCEEDED', paid_at = now(), raw_event = p_raw,
                      needs_refund = not confirmed
   where id = pay.id;

  if confirmed then
    insert into notifications (user_id, kind, title, body) values
      (bk.player_id, 'PAYMENT_CONFIRMED', 'Paiement confirmé',
       'Nous avons bien reçu votre avance de ' || pay.amount || ' FCFA.'),
      (bk.player_id, 'BOOKING_CONFIRMED', 'Réservation confirmée',
       'Votre réservation ' || bk.code || ' est confirmée.');
    return 'CONFIRMED';
  end if;

  insert into notifications (user_id, kind, title, body) values
    (bk.player_id, 'PAYMENT_NEEDS_REVIEW', 'Paiement reçu, créneau indisponible',
     'Votre paiement a été reçu mais le créneau n''est plus disponible. Contactez FootTime (réf. ' || bk.code || ').');
  return 'NEEDS_REFUND';
end $$;

-- Modification : même durée, nouveau début ; 2 modifications maximum.
create or replace function modify_booking(p_player uuid, p_booking uuid, p_new_start timestamptz)
returns bookings language plpgsql security definer set search_path = public as $$
declare
  b bookings; max_mod integer; cutoff integer;
begin
  select * into b from bookings where id = p_booking and player_id = p_player for update;
  if not found then raise exception 'Réservation introuvable'; end if;
  if b.status <> 'CONFIRMED' then raise exception 'Seules les réservations confirmées sont modifiables'; end if;

  max_mod := (select (value)::text::integer from platform_settings where key = 'max_modifications');
  cutoff  := (select (value)::text::integer from platform_settings where key = 'modification_cutoff_hours');
  if b.modification_count >= max_mod then raise exception 'Limite de modifications atteinte'; end if;
  if lower(b.during) < now() + make_interval(hours => cutoff) then
    raise exception 'Modification impossible à moins de % h du début', cutoff; end if;

  perform expire_pending_bookings();
  perform assert_slot_valid(b.venue_id, p_new_start, b.duration_hours);

  begin
    update bookings
       set during = tstzrange(p_new_start, p_new_start + make_interval(hours => b.duration_hours)),
           modification_count = modification_count + 1
     where id = b.id returning * into b;
  exception when exclusion_violation then
    raise exception 'Créneau déjà réservé';
  end;

  insert into notifications (user_id, kind, title, body) values
    (b.player_id, 'BOOKING_MODIFIED', 'Réservation modifiée',
     'Réservation ' || b.code || ' modifiée. Modifications restantes : ' || (max_mod - b.modification_count) || '.');
  return b;
end $$;

-- Maintenance : réservations terminées (débloque les avis)
create or replace function complete_past_bookings() returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  update bookings set status = 'COMPLETED' where status = 'CONFIRMED' and upper(during) < now();
  get diagnostics n = row_count;
  return n;
end $$;

revoke all on function assert_slot_valid(uuid, timestamptz, integer) from public, anon, authenticated;
revoke all on function settle_payment(text, text, payment_status, integer, jsonb) from public, anon, authenticated;
revoke all on function modify_booking(uuid, uuid, timestamptz) from public, anon, authenticated;
revoke all on function complete_past_bookings() from public, anon, authenticated;
grant execute on function assert_slot_valid(uuid, timestamptz, integer) to service_role;
grant execute on function settle_payment(text, text, payment_status, integer, jsonb) to service_role;
grant execute on function modify_booking(uuid, uuid, timestamptz) to service_role;
grant execute on function complete_past_bookings() to service_role;
