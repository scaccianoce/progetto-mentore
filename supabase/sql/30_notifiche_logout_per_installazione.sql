-- Disattiva al logout la riga dell'installazione corrente.
-- La funzione usa device_id e non il token FCM, che puo' essere ruotato.

drop function if exists public.notifiche_disattiva_dispositivo(text);

create function public.notifiche_disattiva_dispositivo(p_device_id text)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user_id uuid := auth.uid();
  v_count integer;
begin
  if v_user_id is null then
    raise exception 'Utente non autenticato';
  end if;

  p_device_id := btrim(p_device_id);
  if p_device_id is null or p_device_id = '' then
    raise exception 'Identificatore installazione mancante';
  end if;

  update public.notifiche_dispositivi
  set attivo = false,
      updated_at = now()
  where device_id = p_device_id
    and user_id = v_user_id;

  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$function$;

revoke all privileges on function public.notifiche_disattiva_dispositivo(text)
  from public, anon;
grant execute on function public.notifiche_disattiva_dispositivo(text)
  to authenticated, service_role;

notify pgrst, 'reload schema';
