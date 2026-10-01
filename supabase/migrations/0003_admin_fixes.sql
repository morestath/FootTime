-- FootTime — Lot 4 : lecture publique des paramètres, garde-fou de rôle robuste

-- Les règles (avance, annulation, absence) doivent être visibles avant connexion.
drop policy if exists settings_read on platform_settings;
create policy settings_read on platform_settings for select using (true);

-- Une connexion directe à la base (SQL Editor, sans JWT) est considérée comme service de confiance.
create or replace function protect_profile_columns() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() and coalesce(auth.role(), 'service_role') <> 'service_role'
     and (new.role <> old.role or new.status <> old.status or new.id <> old.id) then
    raise exception 'Modification du rôle ou du statut interdite';
  end if;
  return new;
end $$;
