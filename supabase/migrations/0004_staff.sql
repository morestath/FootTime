-- FootTime — Espaces propriétaire / gestionnaire

-- Le personnel peut retirer ses propres fermetures.
create policy closures_staff_delete on venue_closures for delete
  using (can_access_venue(venue_id) and created_by = auth.uid());

-- Proposition d'un gestionnaire par le propriétaire (sans permettre de deviner quels emails existent).
-- Le compte est créé en PENDING : FootTime doit l'activer.
create or replace function propose_manager(p_venue uuid, p_email text) returns void
language plpgsql security definer set search_path = public as $$
declare pid uuid;
begin
  if not exists (select 1 from venues ve join owners o on o.id = ve.owner_id
                 where ve.id = p_venue and o.profile_id = auth.uid() and o.status = 'ACTIVE') then
    raise exception 'Réservé au propriétaire du terrain';
  end if;
  select id into pid from profiles where lower(email) = lower(trim(p_email)) and status = 'ACTIVE';
  if pid is not null then
    insert into venue_managers (venue_id, profile_id, status) values (p_venue, pid, 'PENDING')
    on conflict do nothing;
  end if;
end $$;

-- Liste des gestionnaires d'un terrain (noms visibles du seul personnel autorisé).
create or replace function list_venue_managers(p_venue uuid)
returns table (profile_id uuid, first_name text, last_name text, status manager_status, permissions jsonb)
language sql stable security definer set search_path = public as $$
  select m.profile_id, p.first_name, p.last_name, m.status, m.permissions
    from venue_managers m join profiles p on p.id = m.profile_id
   where m.venue_id = p_venue and can_access_venue(p_venue);
$$;

revoke all on function propose_manager(uuid, text) from public, anon;
revoke all on function list_venue_managers(uuid) from public, anon;
grant execute on function propose_manager(uuid, text) to authenticated;
grant execute on function list_venue_managers(uuid) to authenticated;
