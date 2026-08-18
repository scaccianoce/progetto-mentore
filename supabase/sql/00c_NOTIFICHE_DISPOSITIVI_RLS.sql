-- =====================================================================
-- DISPOSITIVI PUSH: RLS + RPC SICURE
-- =====================================================================

alter table public.notifiche_dispositivi enable row level security;

-- Ogni utente autenticato puo vedere soltanto i propri dispositivi.
drop policy if exists notifiche_dispositivi_leggi_propri
on public.notifiche_dispositivi;

create policy notifiche_dispositivi_leggi_propri
on public.notifiche_dispositivi
for select
to authenticated
using (user_id = auth.uid());

-- Le scritture dirette dal client sono volutamente escluse: il Flutter usa le
-- due RPC SECURITY DEFINER sottostanti. In questo modo il token viene sempre
-- associato all'utente autenticato e non a un user_id fornito dal client.

create or replace function public.notifiche_registra_dispositivo(
  p_token text,
  p_piattaforma text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'Utente non autenticato';
  end if;

  if p_token is null or btrim(p_token) = '' then
    raise exception 'Token dispositivo mancante';
  end if;

  if p_piattaforma not in ('android', 'ios', 'web') then
    raise exception 'Piattaforma non valida: %', p_piattaforma;
  end if;

  insert into public.notifiche_dispositivi (
    user_id,
    token,
    piattaforma,
    attivo,
    ultimo_accesso
  )
  values (
    v_user_id,
    p_token,
    p_piattaforma::public.notifiche_piattaforma,
    true,
    now()
  )
  on conflict (token)
  do update set
    user_id = excluded.user_id,
    piattaforma = excluded.piattaforma,
    attivo = true,
    ultimo_accesso = now(),
    updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.notifiche_registra_dispositivo(text, text)
from public;
grant execute on function public.notifiche_registra_dispositivo(text, text)
to authenticated;


create or replace function public.notifiche_disattiva_dispositivo(
  p_token text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_count integer;
begin
  if v_user_id is null then
    raise exception 'Utente non autenticato';
  end if;

  update public.notifiche_dispositivi
  set
    attivo = false,
    updated_at = now()
  where token = p_token
    and user_id = v_user_id;

  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

revoke all on function public.notifiche_disattiva_dispositivo(text)
from public;
grant execute on function public.notifiche_disattiva_dispositivo(text)
to authenticated;
