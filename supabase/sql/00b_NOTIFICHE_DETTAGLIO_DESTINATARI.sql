-- =====================================================================
-- DETTAGLIO DESTINATARI DI UNA NOTIFICA PER IL BACKOFFICE
-- Accessibile soltanto a owner e organizer.
-- =====================================================================

create or replace function public.notifiche_dettaglio_destinatari(
  p_messaggio_id uuid
)
returns table (
  user_id uuid,
  nome text,
  cognome text,
  email_unipa text,
  stato text,
  inviato_at timestamptz,
  letto_at timestamptz,
  errore text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role::text in ('owner', 'organizer')
  ) then
    raise exception 'Utente non autorizzato.'
      using errcode = '42501';
  end if;

  return query
  select
    nd.user_id,
    a.nome::text,
    a.cognome::text,
    a.email_unipa::text,
    nd.stato::text,
    nd.inviato_at,
    nd.letto_at,
    nd.errore::text
  from public.notifiche_destinatari nd
  left join public.anagrafica a
    on a.user_id = nd.user_id
  where nd.messaggio_id = p_messaggio_id
  order by
    a.cognome nulls last,
    a.nome nulls last,
    nd.created_at;
end;
$$;

revoke all
on function public.notifiche_dettaglio_destinatari(uuid)
from public;

grant execute
on function public.notifiche_dettaglio_destinatari(uuid)
to authenticated;
