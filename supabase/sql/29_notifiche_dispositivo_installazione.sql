-- Una sola registrazione push per installazione dell'app/PWA.
-- Il token FCM puo' cambiare; device_id resta stabile e identifica la riga.

alter table public.notifiche_dispositivi
  add column if not exists device_id text;

create unique index if not exists notifiche_dispositivi_device_id_unique
  on public.notifiche_dispositivi (device_id)
  where device_id is not null;

create or replace function public.notifiche_registra_dispositivo(
  p_token text,
  p_piattaforma text,
  p_device_id text
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user_id uuid := auth.uid();
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'Utente non autenticato';
  end if;

  p_token := btrim(p_token);
  if p_token is null or p_token = '' then
    raise exception 'Token dispositivo mancante';
  end if;

  if p_piattaforma not in ('android', 'ios', 'web') then
    raise exception 'Piattaforma non valida: %', p_piattaforma;
  end if;

  p_device_id := btrim(p_device_id);
  if p_device_id is null or p_device_id = '' or length(p_device_id) > 200 then
    raise exception 'Identificatore installazione non valido';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_device_id, 0));

  select id into v_id
  from public.notifiche_dispositivi
  where device_id = p_device_id;

  if v_id is null then
    select id into v_id
    from public.notifiche_dispositivi
    where token = p_token;
  end if;

  if v_id is null then
    insert into public.notifiche_dispositivi (
      user_id, token, device_id, piattaforma, attivo, ultimo_accesso
    ) values (
      v_user_id, p_token, p_device_id,
      p_piattaforma::public.notifiche_piattaforma, true, now()
    )
    returning id into v_id;
  else
    delete from public.notifiche_dispositivi
    where token = p_token and id <> v_id;

    update public.notifiche_dispositivi
    set user_id = v_user_id,
        token = p_token,
        device_id = p_device_id,
        piattaforma = p_piattaforma::public.notifiche_piattaforma,
        attivo = true,
        ultimo_accesso = now(),
        updated_at = now()
    where id = v_id;
  end if;

  return v_id;
end;
$function$;

revoke all privileges on function public.notifiche_registra_dispositivo(text, text, text)
  from public, anon;
grant execute on function public.notifiche_registra_dispositivo(text, text, text)
  to authenticated, service_role;

-- La vecchia firma viene rimossa: tutti i client devono fornire device_id.
drop function if exists public.notifiche_registra_dispositivo(text, text);
