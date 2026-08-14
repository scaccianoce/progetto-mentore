-- ============================================================================
-- CONTRATTO DATABASE PER IL NUOVO BACKOFFICE
-- ============================================================================
-- Eseguire e adattare nel SQL Editor Supabase DOPO aver verificato i nomi
-- delle colonne del progetto. Il frontend non codifica elenchi di dominio:
-- enum, relazioni e metadati devono vivere nel database.
-- ============================================================================

-- 1) NOTIFICHE ----------------------------------------------------------------
-- I valori sono nel DB (ENUM), mai nel Dart.
do $$ begin
  create type public.tipo_notifica as enum ('manuale', 'programmata', 'automatica');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.stato_notifica as enum ('bozza', 'programmata', 'in_coda', 'inviata', 'annullata', 'errore');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.origine_notifica as enum ('manuale', 'news', 'evento', 'house_of_mentore', 'mentoraggio');
exception when duplicate_object then null; end $$;

create table if not exists public.notifiche (
  id uuid primary key default gen_random_uuid(),
  titolo text not null,
  messaggio text not null,
  tipo public.tipo_notifica not null default 'manuale',
  stato public.stato_notifica not null default 'bozza',
  origine public.origine_notifica not null default 'manuale',
  riferimento_id uuid,
  anno_accademico text references public.anni_accademici(codice),
  programmata_per timestamptz,
  inviata_at timestamptz,
  creata_da uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Token push registrati dall'app dopo il consenso dell'utente sul dispositivo.
create table if not exists public.dispositivi_notifiche (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  piattaforma text,
  autorizzato boolean not null default true,
  ultimo_aggiornamento timestamptz not null default now()
);

-- Coda di consegna: un worker/Edge Function legge le righe pendenti e invia
-- tramite FCM/APNs. La sola app Flutter non deve possedere credenziali server.
create table if not exists public.notifiche_consegne (
  notifica_id uuid not null references public.notifiche(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  stato public.stato_notifica not null default 'in_coda',
  tentativi integer not null default 0,
  ultimo_errore text,
  inviata_at timestamptz,
  primary key (notifica_id, user_id)
);

-- 2) HOUSE OF MENTORE: controllo presenza/questionario -------------------------
-- Il frontend attuale registra l'iscrizione. Per il controllo annuale servono
-- anche gli stessi indicatori gia presenti in partecipazioni_eventi.
alter table public.partecipazioni_house_of_mentore
  add column if not exists presente boolean not null default false,
  add column if not exists questionario_compilato boolean not null default false,
  add column if not exists data_compilazione timestamptz;

-- 3) VIEW CONTROLLO PARTECIPANTI -----------------------------------------------
-- Costruisce la popolazione annuale come unione di mentee (docenti con un
-- insegnamento nell'anno) e mentori assegnati a mentoraggi di quell'anno.
create or replace view public.backoffice_controllo_partecipanti as
with coinvolgimenti as (
  select i.anno_accademico, i.docente_id as user_id, true as mentee, false as mentore
  from public.insegnamenti i
  where i.docente_id is not null
  union all
  select i.anno_accademico, mm.mentore_id as user_id, false, true
  from public.mentoraggio_mentori mm
  join public.mentoraggi m on m.id = mm.mentoraggio_id
  join public.insegnamenti i on i.id = m.insegnamento_id
), popolazione as (
  select anno_accademico, user_id,
         bool_or(mentee) as ruolo_mentee,
         bool_or(mentore) as ruolo_mentore
  from coinvolgimenti
  group by anno_accademico, user_id
), mentoraggi_utente as (
  select x.anno_accademico, x.user_id,
         count(distinct x.mentoraggio_id) as mentoraggi,
         count(distinct x.mentoraggio_id) filter (where x.data_invio_scheda is not null) as mentoraggi_completati,
         jsonb_agg(distinct jsonb_build_object(
           'mentoraggio_id', x.mentoraggio_id,
           'ruolo', x.ruolo,
           'data_visita_1', x.data_visita_1,
           'data_visita_2', x.data_visita_2,
           'data_visita_3', x.data_visita_3,
           'data_visita_4', x.data_visita_4,
           'data_focus_group', x.data_focus_group,
           'data_incontro_finale', x.data_incontro_finale,
           'data_invio_scheda', x.data_invio_scheda
         )) as mentoraggi_dettaglio
  from (
    select i.anno_accademico, i.docente_id user_id, m.id mentoraggio_id,
           'mentee'::text ruolo, m.data_visita_1, m.data_visita_2,
           m.data_visita_3, m.data_visita_4, m.data_focus_group,
           m.data_incontro_finale, m.data_invio_scheda
    from public.mentoraggi m
    join public.insegnamenti i on i.id = m.insegnamento_id
    union all
    select i.anno_accademico, mm.mentore_id, m.id,
           'mentore'::text, m.data_visita_1, m.data_visita_2,
           m.data_visita_3, m.data_visita_4, m.data_focus_group,
           m.data_incontro_finale, m.data_invio_scheda
    from public.mentoraggio_mentori mm
    join public.mentoraggi m on m.id = mm.mentoraggio_id
    join public.insegnamenti i on i.id = m.insegnamento_id
  ) x
  group by x.anno_accademico, x.user_id
), eventi_utente as (
  select e.anno_accademico, pe.partecipante_id user_id,
         count(*) as eventi_iscritti,
         count(*) filter (where pe.presente) as eventi_presenti,
         count(*) filter (where pe.questionario_compilato) as questionari_eventi
  from public.partecipazioni_eventi pe
  join public.eventi e on e.id = pe.evento_id
  group by e.anno_accademico, pe.partecipante_id
), hom_utente as (
  select h.anno_accademico, ph.partecipante_id user_id,
         count(*) as hom_iscritti,
         count(*) filter (where ph.presente) as hom_presenti,
         count(*) filter (where ph.questionario_compilato) as questionari_hom
  from public.partecipazioni_house_of_mentore ph
  join public.house_of_mentore h on h.id = ph.evento_id
  group by h.anno_accademico, ph.partecipante_id
)
select p.anno_accademico, p.user_id, a.cognome, a.nome, a.email_unipa,
       p.ruolo_mentee, p.ruolo_mentore,
       coalesce(mu.mentoraggi, 0) mentoraggi,
       coalesce(mu.mentoraggi_completati, 0) mentoraggi_completati,
       mu.mentoraggi_dettaglio,
       coalesce(ev.eventi_iscritti, 0) eventi_iscritti,
       coalesce(ev.eventi_presenti, 0) eventi_presenti,
       coalesce(ev.questionari_eventi, 0) questionari_eventi,
       coalesce(ho.hom_iscritti, 0) hom_iscritti,
       coalesce(ho.hom_presenti, 0) hom_presenti,
       coalesce(ho.questionari_hom, 0) questionari_hom
from popolazione p
join public.anagrafica a on a.user_id = p.user_id
left join mentoraggi_utente mu using (anno_accademico, user_id)
left join eventi_utente ev using (anno_accademico, user_id)
left join hom_utente ho using (anno_accademico, user_id);

-- 4) SINTESI ED ESPORTAZIONE ANNUALE ------------------------------------------
-- Non vengono create view/RPC di riepilogo: la pagina Anni accademici legge
-- direttamente le tabelle reali (insegnamenti, mentoraggi, eventi,
-- partecipazioni_eventi, house_of_mentore, partecipazioni_house_of_mentore)
-- e calcola la sintesi nel client. Anche i CSV sono costruiti a partire dai
-- record grezzi delle tabelle coinvolte.

-- 5) NOTIFICHE AUTOMATICHE -----------------------------------------------------
-- Gli INSERT di news/eventi/House of Mentore possono creare una riga in
-- notifiche tramite trigger. Il testo definitivo e i destinatari possono poi
-- essere elaborati da Edge Function. Esempio generico per EVENTI:
create or replace function public.accoda_notifica_nuovo_evento()
returns trigger language plpgsql security definer as $$
begin
  insert into public.notifiche(titolo, messaggio, tipo, stato, origine, riferimento_id, anno_accademico)
  values ('Nuovo evento', new.titolo, 'automatica', 'in_coda', 'evento', new.id, new.anno_accademico);
  return new;
end $$;

drop trigger if exists trg_notifica_nuovo_evento on public.eventi;
create trigger trg_notifica_nuovo_evento
after insert on public.eventi
for each row execute function public.accoda_notifica_nuovo_evento();

-- Per news e house_of_mentore applicare lo stesso schema con origine rispettiva.
-- I solleciti temporali dei mentoraggi NON vanno implementati con trigger INSERT:
-- richiedono un job schedulato (Supabase Cron/pg_cron o Edge Function giornaliera)
-- che controlli date inizio/fine lezioni, almeno 2 visite e focus group prima
-- della fine. Se le date delle lezioni non esistono ancora in `insegnamenti`,
-- aggiungerle nel DB prima di implementare il job.

-- 7) RPC LEGACY CREAZIONE PARTECIPANTE ----------------------------------------
-- La versione finale usa la Edge Function `backoffice-user-admin`, che crea
-- direttamente Auth + anagrafica + anagrafica_riservata + user_roles e non
-- dipende da questa RPC. La funzione seguente resta solo per compatibilita con
-- installazioni precedenti e puo essere omessa in una nuova installazione.
create or replace function public.backoffice_crea_partecipante(p_anagrafica jsonb)
returns void
language plpgsql
security invoker
as $$
declare
  v_user_id uuid := (p_anagrafica->>'user_id')::uuid;
begin
  if v_user_id is null then
    raise exception 'user_id obbligatorio';
  end if;

  insert into public.anagrafica
  select * from jsonb_populate_record(null::public.anagrafica, p_anagrafica);

  insert into public.anagrafica_riservata(user_id, attivo)
  values (v_user_id, true)
  on conflict (user_id) do nothing;

  insert into public.user_roles(user_id, role)
  values (v_user_id, 'participant')
  on conflict (user_id) do nothing;
end;
$$;

-- Trigger automatico NEWS. `news` non e legata obbligatoriamente a un anno.
create or replace function public.accoda_notifica_nuova_news()
returns trigger language plpgsql security definer as $$
begin
  insert into public.notifiche(titolo, messaggio, tipo, stato, origine, riferimento_id)
  values ('Nuova news', new.titolo, 'automatica', 'in_coda', 'news', new.id);
  return new;
end $$;

drop trigger if exists trg_notifica_nuova_news on public.news;
create trigger trg_notifica_nuova_news
after insert on public.news
for each row execute function public.accoda_notifica_nuova_news();

create or replace function public.accoda_notifica_nuovo_hom()
returns trigger language plpgsql security definer as $$
begin
  insert into public.notifiche(titolo, messaggio, tipo, stato, origine, riferimento_id, anno_accademico)
  values ('Nuovo House of Mentore', new.titolo, 'automatica', 'in_coda', 'house_of_mentore', new.id, new.anno_accademico);
  return new;
end $$;

drop trigger if exists trg_notifica_nuovo_hom on public.house_of_mentore;
create trigger trg_notifica_nuovo_hom
after insert on public.house_of_mentore
for each row execute function public.accoda_notifica_nuovo_hom();

-- 8) SOLLECITI AUTOMATICI DEL MENTORAGGIO -------------------------------------
-- Se queste date non sono gia presenti, diventano dati dell'insegnamento e
-- quindi verranno mostrate automaticamente nella maschera dinamica.
alter table public.insegnamenti
  add column if not exists data_inizio_lezioni date,
  add column if not exists data_fine_lezioni date;

alter table public.notifiche
  add column if not exists chiave_deduplica text unique;

-- Genera al massimo una notifica per fase/mentoraggio. Le soglie sono calcolate
-- sulla durata reale delle lezioni: prima visita entro circa 1/3, seconda entro
-- circa 2/3, focus group nelle ultime due settimane.
create or replace function public.genera_solleciti_mentoraggio(p_oggi date default current_date)
returns integer
language plpgsql
security definer
as $$
declare
  r record;
  v_visite integer;
  v_creati integer := 0;
  v_durata integer;
  v_chiave text;
begin
  for r in
    select m.id mentoraggio_id, i.docente_id, i.anno_accademico,
           i.data_inizio_lezioni, i.data_fine_lezioni,
           m.data_visita_1, m.data_visita_2, m.data_visita_3, m.data_visita_4,
           m.data_focus_group
    from public.mentoraggi m
    join public.insegnamenti i on i.id = m.insegnamento_id
    where i.data_inizio_lezioni is not null
      and i.data_fine_lezioni is not null
      and p_oggi between i.data_inizio_lezioni and i.data_fine_lezioni
  loop
    v_durata := greatest(1, r.data_fine_lezioni - r.data_inizio_lezioni);
    v_visite :=
      (case when r.data_visita_1 is not null then 1 else 0 end) +
      (case when r.data_visita_2 is not null then 1 else 0 end) +
      (case when r.data_visita_3 is not null then 1 else 0 end) +
      (case when r.data_visita_4 is not null then 1 else 0 end);

    if p_oggi >= r.data_inizio_lezioni + greatest(1, v_durata / 3)
       and v_visite < 1 then
      v_chiave := 'mentoraggio:' || r.mentoraggio_id || ':visita1';
      insert into public.notifiche(
        titolo, messaggio, tipo, stato, origine, riferimento_id,
        anno_accademico, chiave_deduplica
      ) values (
        'Promemoria mentoraggio',
        'E necessario programmare la prima visita di mentoraggio.',
        'automatica', 'in_coda', 'mentoraggio', r.mentoraggio_id,
        r.anno_accademico, v_chiave
      ) on conflict (chiave_deduplica) do nothing;
      if found then v_creati := v_creati + 1; end if;
    end if;

    if p_oggi >= r.data_inizio_lezioni + greatest(1, (v_durata * 2) / 3)
       and v_visite < 2 then
      v_chiave := 'mentoraggio:' || r.mentoraggio_id || ':visita2';
      insert into public.notifiche(
        titolo, messaggio, tipo, stato, origine, riferimento_id,
        anno_accademico, chiave_deduplica
      ) values (
        'Seconda visita di mentoraggio',
        'Prima della fine delle lezioni devono essere svolte almeno due visite.',
        'automatica', 'in_coda', 'mentoraggio', r.mentoraggio_id,
        r.anno_accademico, v_chiave
      ) on conflict (chiave_deduplica) do nothing;
      if found then v_creati := v_creati + 1; end if;
    end if;

    if p_oggi >= r.data_fine_lezioni - 14 and r.data_focus_group is null then
      v_chiave := 'mentoraggio:' || r.mentoraggio_id || ':focus';
      insert into public.notifiche(
        titolo, messaggio, tipo, stato, origine, riferimento_id,
        anno_accademico, chiave_deduplica
      ) values (
        'Focus group da completare',
        'Il focus group deve essere svolto prima della fine delle lezioni.',
        'automatica', 'in_coda', 'mentoraggio', r.mentoraggio_id,
        r.anno_accademico, v_chiave
      ) on conflict (chiave_deduplica) do nothing;
      if found then v_creati := v_creati + 1; end if;
    end if;
  end loop;
  return v_creati;
end;
$$;

-- Pianificazione consigliata con Supabase Cron/pg_cron (se abilitato):
-- select cron.schedule(
--   'solleciti-mentoraggio-giornalieri',
--   '0 7 * * *',
--   $$select public.genera_solleciti_mentoraggio(current_date);$$
-- );
--
-- Un worker/Edge Function deve poi trasformare le notifiche `in_coda` in
-- `notifiche_consegne` per docente + mentori coinvolti e inviare via FCM/APNs.

-- 9) ELENCO DELLE SOLE TABELLE FISICHE PER IL DATABASE BACKOFFICE ------------
-- Evita che view/oggetti tecnici restituiti dall'introspezione vengano mostrati
-- come tab modificabili nella pagina Gestione -> Database.
create or replace function public.app_database_base_tables()
returns table(name text)
language sql
stable
security definer
set search_path = public, information_schema
as $$
  select table_name::text
  from information_schema.tables
  where table_schema = 'public'
    and table_type = 'BASE TABLE'
  order by table_name;
$$;

grant execute on function public.app_database_base_tables() to authenticated;
