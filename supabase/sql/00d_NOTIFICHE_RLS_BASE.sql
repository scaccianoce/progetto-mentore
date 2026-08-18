-- ============================================================================
-- RLS SISTEMA NOTIFICHE
-- ============================================================================
-- Obiettivi:
-- 1) ogni utente autenticato legge SOLO i propri notifiche_destinatari;
-- 2) un utente legge un notifiche_messaggi SOLO se ne e destinatario;
-- 3) la marcatura "letta" avviene tramite RPC controllata, non con UPDATE libero;
-- 4) owner/organizer possono amministrare regole e messaggi dal backoffice;
-- 5) ciascun utente puo gestire soltanto i propri device token.
--
-- La tabella user_roles usa la colonna: role
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Funzione helper: owner/organizer
-- ----------------------------------------------------------------------------
create or replace function public.notifiche_utente_amministratore()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role in ('owner', 'organizer')
  );
$$;

revoke all on function public.notifiche_utente_amministratore() from public;
grant execute on function public.notifiche_utente_amministratore() to authenticated;

-- ----------------------------------------------------------------------------
-- notifiche_destinatari
-- ----------------------------------------------------------------------------
alter table public.notifiche_destinatari enable row level security;

-- Elimina eventuali policy omonime per rendere lo script rieseguibile.
drop policy if exists notifiche_destinatari_leggi_propri on public.notifiche_destinatari;
drop policy if exists notifiche_destinatari_admin_tutto on public.notifiche_destinatari;

-- Partecipante/utente normale: legge esclusivamente le proprie righe.
create policy notifiche_destinatari_leggi_propri
on public.notifiche_destinatari
for select
to authenticated
using (user_id = auth.uid());

-- Owner/organizer: accesso amministrativo completo.
create policy notifiche_destinatari_admin_tutto
on public.notifiche_destinatari
for all
to authenticated
using (public.notifiche_utente_amministratore())
with check (public.notifiche_utente_amministratore());

-- ----------------------------------------------------------------------------
-- RPC sicura per segnare una notifica come letta.
-- L'utente NON riceve una policy UPDATE generica sulla propria riga.
-- ----------------------------------------------------------------------------
create or replace function public.notifiche_segna_letta(
  p_destinatario_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notifiche_destinatari
  set
    stato = 'letto',
    letto_at = coalesce(letto_at, now()),
    updated_at = now()
  where id = p_destinatario_id
    and user_id = auth.uid();

  if not found then
    raise exception 'Notifica non trovata o non appartenente all''utente corrente.';
  end if;
end;
$$;

revoke all on function public.notifiche_segna_letta(uuid) from public;
grant execute on function public.notifiche_segna_letta(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- notifiche_messaggi
-- Impedisce di leggere direttamente messaggi destinati ad altri utenti.
-- ----------------------------------------------------------------------------
alter table public.notifiche_messaggi enable row level security;

drop policy if exists notifiche_messaggi_leggi_se_destinatario on public.notifiche_messaggi;
drop policy if exists notifiche_messaggi_admin_tutto on public.notifiche_messaggi;

create policy notifiche_messaggi_leggi_se_destinatario
on public.notifiche_messaggi
for select
to authenticated
using (
  exists (
    select 1
    from public.notifiche_destinatari nd
    where nd.messaggio_id = notifiche_messaggi.id
      and nd.user_id = auth.uid()
  )
);

create policy notifiche_messaggi_admin_tutto
on public.notifiche_messaggi
for all
to authenticated
using (public.notifiche_utente_amministratore())
with check (public.notifiche_utente_amministratore());

-- ----------------------------------------------------------------------------
-- notifiche_regole
-- Solo owner/organizer possono vedere e fare CRUD sulle regole.
-- ----------------------------------------------------------------------------
alter table public.notifiche_regole enable row level security;

drop policy if exists notifiche_regole_admin_tutto on public.notifiche_regole;

create policy notifiche_regole_admin_tutto
on public.notifiche_regole
for all
to authenticated
using (public.notifiche_utente_amministratore())
with check (public.notifiche_utente_amministratore());

-- ----------------------------------------------------------------------------
-- notifiche_dispositivi
-- Ogni utente gestisce i propri token. Gli amministratori possono consultarli.
-- ----------------------------------------------------------------------------
alter table public.notifiche_dispositivi enable row level security;

drop policy if exists notifiche_dispositivi_propri on public.notifiche_dispositivi;
drop policy if exists notifiche_dispositivi_admin_leggi on public.notifiche_dispositivi;

create policy notifiche_dispositivi_propri
on public.notifiche_dispositivi
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy notifiche_dispositivi_admin_leggi
on public.notifiche_dispositivi
for select
to authenticated
using (public.notifiche_utente_amministratore());
