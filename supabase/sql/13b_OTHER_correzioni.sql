drop policy if exists
"Users update own profile when authorized"
on public.anagrafica;

drop policy if exists
"Users update own profile"
on public.anagrafica;

create policy
"Users update own profile"
on public.anagrafica
for update
to authenticated
using (
  user_id = auth.uid()
)
with check (
  user_id = auth.uid()
);

-- ============================================================================
-- 13b_OTHER_correzioni.sql
-- Correzioni applicabili anche a un database già esistente
-- ============================================================================

begin;

-- ============================================================================
-- 1. CONSERVAZIONE COMPILAZIONI QUESTIONARI
--
-- Eliminando auth.users:
-- - la compilazione viene conservata;
-- - user_id diventa NULL;
-- - le risposte collegate alla compilazione rimangono.
-- ============================================================================

alter table public.questionari_compilazioni
drop constraint if exists questionari_compilazioni_user_id_fkey;

alter table public.questionari_compilazioni
add constraint questionari_compilazioni_user_id_fkey
foreign key (user_id)
references auth.users(id)
on delete set null;


-- ============================================================================
-- 2. HARDENING GENERALE DELLE FUNZIONI
--
-- PostgreSQL può concedere EXECUTE a PUBLIC per impostazione predefinita.
-- Togliamo l’accesso implicito a tutte le funzioni già esistenti.
--
-- Le concessioni esplicite ad authenticated e service_role non vengono rimosse.
-- ============================================================================

revoke execute on all functions in schema public
from public, anon;

-- Impedisce la concessione implicita anche alle nuove funzioni create
-- successivamente dallo stesso ruolo che esegue questo script.
alter default privileges in schema public
revoke execute on functions
from public, anon;


-- ============================================================================
-- 3. RIPRISTINO DELLE SOLE FUNZIONI PUBBLICHE VOLUTE
-- ============================================================================

grant execute
on function public.questionario_pubblico_carica(uuid)
to anon;

grant execute
on function public.questionario_pubblico_invia(uuid, jsonb)
to anon;

grant execute
on function public.questionario_pubblico_leggi(uuid)
to anon;


-- ============================================================================
-- 4. STORICO PARTECIPAZIONI DEL PROFILO
--
-- Restituisce tutte e sole le righe dell'utente autenticato. La funzione
-- consente alla pagina Profilo di creare una tile per ogni anno accademico,
-- indipendentemente da eventuali disallineamenti delle policy RLS remote.
-- ============================================================================

create or replace function public.partecipazioni_annuali_proprie()
returns setof public.partecipazioni_annuali
language sql
stable
security definer
set search_path = 'public'
as $function$
  select pa.*
  from public.partecipazioni_annuali pa
  where pa.user_id = auth.uid()
  order by pa.anno_accademico desc;
$function$;

revoke all privileges
on function public.partecipazioni_annuali_proprie()
from public, anon, authenticated;

grant execute
on function public.partecipazioni_annuali_proprie()
to authenticated;


-- ============================================================================
-- 5. PROTEZIONE DEL CONTEGGIO DESTINATARI
--
-- La funzione rimane disponibile ad authenticated, ma soltanto owner e
-- organizer possono ottenere il risultato.
-- ============================================================================

create or replace function public.notifiche_conta_destinatari(
  p_messaggio_id uuid
)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null
     or not public.notifiche_puo_gestire() then
    raise exception 'Utente non autorizzato.'
      using errcode = '42501';
  end if;

  return (
    select count(*)::integer
    from public.notifiche_destinatari nd
    where nd.messaggio_id = p_messaggio_id
  );
end;
$function$;

revoke all privileges
on function public.notifiche_conta_destinatari(uuid)
from public, anon, authenticated;

grant execute
on function public.notifiche_conta_destinatari(uuid)
to authenticated;

commit;


revoke all on table public.questionari from anon;
revoke all on table public.questionari_template from anon;
revoke all on table public.questionari_domande from anon;
revoke all on table public.questionari_compilazioni from anon;
revoke all on table public.questionari_risposte from anon;


revoke execute
on function public.questionario_pubblico_carica(uuid)
from public;

revoke execute
on function public.questionario_pubblico_invia(uuid, jsonb)
from public;

grant execute
on function public.questionario_pubblico_carica(uuid)
to anon, authenticated;

grant execute
on function public.questionario_pubblico_invia(uuid, jsonb)
to anon, authenticated;


alter function public.questionario_pubblico_carica(uuid)
set search_path = '';

alter function public.questionario_pubblico_invia(uuid, jsonb)
set search_path = '';


-- ============================================================
-- 1. PRIVILEGI SQL
-- ============================================================

grant select, insert, update, delete
on table public.import_insegnamenti
to authenticated;

grant select, insert, update, delete
on table public.import_partecipanti
to authenticated;


-- ============================================================
-- 2. ATTIVA RLS
-- ============================================================

alter table public.import_insegnamenti
enable row level security;

alter table public.import_partecipanti
enable row level security;


-- ============================================================
-- 3. FUNZIONE: UTENTE CORRENTE E' OWNER?
-- ============================================================

create or replace function public.app_is_owner()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role = 'owner'
  );
$$;

revoke execute
on function public.app_is_owner()
from public;

grant execute
on function public.app_is_owner()
to authenticated;


-- ============================================================
-- 4. POLICY import_insegnamenti
-- ============================================================

create policy import_insegnamenti_owner_all
on public.import_insegnamenti
for all
to authenticated
using (
  public.app_is_owner()
)
with check (
  public.app_is_owner()
);


-- ============================================================
-- 5. POLICY import_partecipanti
-- ============================================================

create policy import_partecipanti_owner_all
on public.import_partecipanti
for all
to authenticated
using (
  public.app_is_owner()
)
with check (
  public.app_is_owner()
);


grant select, insert, update, delete
on table public.import_insegnamenti
to authenticated;

grant select, insert, update, delete
on table public.import_partecipanti
to authenticated;


create or replace function public.app_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  r record;
begin
  for r in
    select t.table_name
    from information_schema.tables t
    where t.table_schema = 'public'
      and t.table_type = 'BASE TABLE'
      and not exists (
        select 1
        from information_schema.columns c
        where c.table_schema = t.table_schema
          and c.table_name = t.table_name
          and c.column_name = 'updated_at'
      )
  loop
    execute format(
      'alter table public.%I
       add column updated_at timestamptz not null default now()',
      r.table_name
    );
  end loop;
end
$$;

do $$
declare
  r record;
begin
  for r in
    select t.table_name
    from information_schema.tables t
    join information_schema.columns c
      on c.table_schema = t.table_schema
     and c.table_name = t.table_name
    where t.table_schema = 'public'
      and t.table_type = 'BASE TABLE'
      and c.column_name = 'updated_at'
      and c.data_type = 'timestamp with time zone'
  loop

    execute format(
      'drop trigger if exists trg_set_updated_at on public.%I',
      r.table_name
    );

    execute format(
      'create trigger trg_set_updated_at
       before update on public.%I
       for each row
       execute function public.app_set_updated_at()',
      r.table_name
    );

  end loop;
end
$$;

alter table public.news
alter column updated_at type timestamptz
using updated_at at time zone 'UTC';

alter table public.news
alter column updated_at set default now();

alter table public.news
alter column updated_at set not null;


BEGIN;

-- ============================================================
-- 1. CREA L'ENUM, SE NON ESISTE GIA'
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n
      ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'stato_partecipazione_annuale'
  ) THEN

    CREATE TYPE public.stato_partecipazione_annuale AS ENUM (
      'da_contattare',
      'confermato',
      'rinuncia',
      'nuovo',
      'sospeso'
    );

  END IF;
END
$$;


-- ============================================================
-- 2. ELIMINA IL CHECK VECCHIO
--
-- Non serve piu':
-- l'ENUM stesso impedira' l'inserimento di valori non validi.
-- ============================================================

ALTER TABLE public.partecipazioni_annuali
DROP CONSTRAINT IF EXISTS partecipazioni_annuali_stato_check;


-- ============================================================
-- 3. ELIMINA TEMPORANEAMENTE IL DEFAULT
-- ============================================================

ALTER TABLE public.partecipazioni_annuali
ALTER COLUMN stato DROP DEFAULT;


-- ============================================================
-- 4. CONVERTE TEXT -> ENUM
--
-- ::text intermedio rende la conversione robusta anche
-- nel caso in cui lo script venga rieseguito.
-- ============================================================

ALTER TABLE public.partecipazioni_annuali
ALTER COLUMN stato
TYPE public.stato_partecipazione_annuale
USING stato::text::public.stato_partecipazione_annuale;


-- ============================================================
-- 5. RIPRISTINA IL DEFAULT
-- ============================================================

ALTER TABLE public.partecipazioni_annuali
ALTER COLUMN stato
SET DEFAULT
  'da_contattare'::public.stato_partecipazione_annuale;


-- ============================================================
-- 6. RPC:
-- partecipazione_annuale_imposta
--
-- Manteniamo p_stato TEXT per non cambiare la chiamata Flutter.
-- Facciamo il cast soltanto quando scriviamo nel DB.
-- ============================================================

CREATE OR REPLACE FUNCTION public.partecipazione_annuale_imposta(
  p_user_id uuid,
  p_anno_accademico text,
  p_stato text,
  p_note text DEFAULT NULL::text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN

  IF NOT public.app_backoffice_admin() THEN
    RAISE EXCEPTION
      'Operazione riservata a owner/organizer.'
      USING errcode = '42501';
  END IF;

  IF p_stato NOT IN (
    'da_contattare',
    'confermato',
    'rinuncia',
    'nuovo',
    'sospeso'
  ) THEN
    RAISE EXCEPTION 'Stato partecipazione non valido.';
  END IF;

  INSERT INTO public.partecipazioni_annuali (
    user_id,
    anno_accademico,
    stato,
    richiesta_at,
    risposta_at,
    aggiornato_da,
    note
  )
  VALUES (
    p_user_id,
    p_anno_accademico,

    -- TEXT -> ENUM
    p_stato::public.stato_partecipazione_annuale,

    now(),

    CASE
      WHEN p_stato IN (
        'confermato',
        'rinuncia',
        'nuovo'
      )
      THEN now()
      ELSE NULL
    END,

    auth.uid(),
    p_note
  )

  ON CONFLICT (user_id, anno_accademico)

  DO UPDATE SET
    stato = EXCLUDED.stato,
    risposta_at = EXCLUDED.risposta_at,
    aggiornato_da = auth.uid(),
    note = EXCLUDED.note,
    updated_at = now();

END;
$function$;


-- ============================================================
-- 7. RPC:
-- partecipazione_annuale_rispondi
--
-- v_stato resta TEXT.
-- Cast esplicito quando viene scritto nella colonna ENUM.
-- ============================================================

CREATE OR REPLACE FUNCTION public.partecipazione_annuale_rispondi(
  p_partecipa boolean,
  p_anno_accademico text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_anno text;
  v_stato text;
BEGIN

  IF v_user IS NULL THEN
    RAISE EXCEPTION
      'Utente non autenticato.'
      USING errcode = '42501';
  END IF;

  v_anno := COALESCE(
    p_anno_accademico,
    public.anno_accademico_preparazione()
  );

  IF v_anno IS NULL THEN
    RAISE EXCEPTION
      'Nessun anno accademico in preparazione.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.partecipazioni_annuali
    WHERE user_id = v_user
      AND anno_accademico = v_anno
  ) THEN

    RAISE EXCEPTION
      'Nessuna richiesta di partecipazione disponibile.';

  END IF;

  v_stato :=
    CASE
      WHEN p_partecipa THEN 'confermato'
      ELSE 'rinuncia'
    END;

  UPDATE public.partecipazioni_annuali
  SET
    stato =
      v_stato::public.stato_partecipazione_annuale,
    risposta_at = now(),
    aggiornato_da = v_user,
    updated_at = now()
  WHERE user_id = v_user
    AND anno_accademico = v_anno;

  RETURN public.partecipazione_annuale_stato(v_anno);

END;
$function$;


-- ============================================================
-- 8. RPC:
-- partecipazioni_annuali_genera
--
-- Qui il literal potrebbe essere risolto automaticamente,
-- ma usiamo il cast esplicito per chiarezza.
-- ============================================================

CREATE OR REPLACE FUNCTION public.partecipazioni_annuali_genera(
  p_anno_destinazione text,
  p_anno_sorgente text DEFAULT NULL::text
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_sorgente text;
  v_numero integer;
BEGIN

  IF NOT public.app_backoffice_admin() THEN
    RAISE EXCEPTION
      'Operazione riservata a owner/organizer.'
      USING errcode = '42501';
  END IF;

  v_sorgente :=
    COALESCE(
      p_anno_sorgente,
      public.anno_accademico_attivo()
    );

  IF v_sorgente IS NULL THEN
    RAISE EXCEPTION
      'Nessun anno sorgente disponibile.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.anni_accademici
    WHERE codice = p_anno_destinazione
  ) THEN

    RAISE EXCEPTION
      'Anno destinazione inesistente.';

  END IF;

  WITH utenti AS (

    -- Mentee dell'anno sorgente
    SELECT DISTINCT
      i.docente_id AS user_id
    FROM public.mentoraggi m
    JOIN public.insegnamenti i
      ON i.id = m.insegnamento_id
    WHERE m.anno_accademico = v_sorgente
      AND i.docente_id IS NOT NULL

    UNION

    -- Mentor/senior dell'anno sorgente
    SELECT DISTINCT
      mm.mentore_id AS user_id
    FROM public.mentoraggio_mentori mm
    JOIN public.mentoraggi m
      ON m.id = mm.mentoraggio_id
    WHERE m.anno_accademico = v_sorgente
      AND mm.mentore_id IS NOT NULL

  ),

  inserite AS (

    INSERT INTO public.partecipazioni_annuali (
      user_id,
      anno_accademico,
      stato,
      richiesta_at,
      aggiornato_da
    )

    SELECT
      u.user_id,
      p_anno_destinazione,
      'da_contattare'
        ::public.stato_partecipazione_annuale,
      now(),
      auth.uid()

    FROM utenti u

    JOIN public.anagrafica a
      ON a.user_id = u.user_id

    ON CONFLICT (user_id, anno_accademico)
    DO NOTHING

    RETURNING 1
  )

  SELECT count(*)
  INTO v_numero
  FROM inserite;

  RETURN v_numero;

END;
$function$;


-- ============================================================
-- 9. ADEGUA LE FUNZIONI CHE LEGGONO stato IN VARIABILI TEXT
--
-- Non e' indispensabile cambiare tutta la funzione:
-- PostgreSQL gestisce molte conversioni in assegnazione.
--
-- Le funzioni esistenti insegnamento_* possono continuare
-- a lavorare con v_partecipazione TEXT.
--
-- Pero' nelle query e' piu' robusto confrontare come TEXT.
-- ============================================================

-- Non dobbiamo modificare qui partecipazione_annuale_stato():
-- v_riga.stato viene serializzato correttamente in JSONB.


-- ============================================================
-- 10. RLS anni_accademici
--
-- PROBLEMA ATTUALE:
-- solo owner puo fare INSERT/UPDATE/DELETE.
--
-- app_backoffice_admin(), invece, considera correttamente
-- owner + organizer.
--
-- Rendiamo quindi coerente anche la policy RLS.
-- ============================================================

DROP POLICY IF EXISTS
  "Owner manages academic years"
ON public.anni_accademici;


DROP POLICY IF EXISTS
  "Owner and organizer manage academic years"
ON public.anni_accademici;


CREATE POLICY
  "Owner and organizer manage academic years"
ON public.anni_accademici
AS PERMISSIVE
FOR ALL
TO authenticated

USING (
  public.app_backoffice_admin()
)

WITH CHECK (
  public.app_backoffice_admin()
);


COMMIT;

DROP POLICY IF EXISTS
  "authenticated can read anni_accademici"
ON public.anni_accademici;

GRANT SELECT, INSERT, UPDATE, DELETE
ON TABLE public.anni_accademici
TO authenticated;


GRANT EXECUTE
ON FUNCTION public.partecipazioni_annuali_genera(text, text)
TO authenticated;

-- ============================================================
-- CONSENTE AL PARTECIPANTE DI AGGIORNARE SOLO LA PROPRIA RIGA
-- ============================================================

DROP POLICY IF EXISTS
    "partecipazioni_annuali_own_update"
ON public.partecipazioni_annuali;

CREATE POLICY
    "partecipazioni_annuali_own_update"
ON public.partecipazioni_annuali
AS PERMISSIVE
FOR UPDATE
TO authenticated
USING (
    user_id = auth.uid()
)
WITH CHECK (
    user_id = auth.uid()
);


-- ============================================================
-- PRIVILEGIO UPDATE
-- ============================================================

GRANT UPDATE
ON public.partecipazioni_annuali
TO authenticated;


CREATE OR REPLACE FUNCTION public.partecipazioni_annuali_genera(
    p_anno_destinazione text,
    p_anno_sorgente text DEFAULT NULL::text
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_sorgente text;
    v_numero integer;
BEGIN

    -- --------------------------------------------------------
    -- AUTORIZZAZIONE
    -- --------------------------------------------------------

    IF NOT public.app_backoffice_admin() THEN
        RAISE EXCEPTION
            'Operazione riservata a owner/organizer.'
            USING errcode = '42501';
    END IF;


    -- --------------------------------------------------------
    -- ANNO SORGENTE
    -- --------------------------------------------------------

    v_sorgente := COALESCE(
        p_anno_sorgente,
        public.anno_accademico_attivo()
    );

    IF v_sorgente IS NULL THEN
        RAISE EXCEPTION
            'Nessun anno sorgente disponibile.';
    END IF;


    -- --------------------------------------------------------
    -- CONTROLLA CHE SORGENTE E DESTINAZIONE SIANO DIVERSI
    -- --------------------------------------------------------

    IF v_sorgente = p_anno_destinazione THEN
        RAISE EXCEPTION
            'Anno sorgente e destinazione devono essere diversi.';
    END IF;


    -- --------------------------------------------------------
    -- VERIFICA ANNO DESTINAZIONE
    -- --------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM public.anni_accademici
        WHERE codice = p_anno_destinazione
    ) THEN
        RAISE EXCEPTION
            'Anno destinazione inesistente.';
    END IF;


    -- --------------------------------------------------------
    -- GENERA LE NUOVE RICHIESTE
    --
    -- Vengono ricontattati esclusivamente gli utenti che
    -- nell'anno sorgente risultano:
    --
    --   confermato
    --   nuovo
    --
    -- Gli altri stati vengono esclusi:
    --
    --   da_contattare
    --   rinuncia
    --   sospeso
    -- --------------------------------------------------------

    WITH inserite AS (

        INSERT INTO public.partecipazioni_annuali (
            user_id,
            anno_accademico,
            stato,
            richiesta_at,
            aggiornato_da
        )

        SELECT
            pa.user_id,
            p_anno_destinazione,
            'da_contattare'
                ::public.stato_partecipazione_annuale,
            now(),
            auth.uid()

        FROM public.partecipazioni_annuali pa

        WHERE pa.anno_accademico = v_sorgente

          AND pa.stato IN (
              'confermato'
                  ::public.stato_partecipazione_annuale,
              'nuovo'
                  ::public.stato_partecipazione_annuale
          )

        ON CONFLICT (
            user_id,
            anno_accademico
        )
        DO NOTHING

        RETURNING 1
    )

    SELECT count(*)::integer
    INTO v_numero
    FROM inserite;


    RETURN v_numero;

END;
$function$;


GRANT EXECUTE
ON FUNCTION public.menu_stato_novita()
TO service_role;


ALTER TABLE public.house_of_mentore
ADD COLUMN attiva boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.house_of_mentore.attiva IS
'Indica se la House of Mentore è attiva/visibile nell''applicazione.';


begin;

drop policy if exists "questionari_evento_partecipante_select"
on public.questionari;

create policy "questionari_evento_partecipante_select"
on public.questionari
as permissive
for select
to authenticated
using (
  provider = 'interno'::questionario_provider
  and aperto = true
  and (data_apertura is null or data_apertura <= now())
  and (data_chiusura is null or data_chiusura >= now())
  and exists (
    select 1
    from public.partecipazioni_eventi pe
    where pe.evento_id = questionari.evento_id
      and pe.partecipante_id = auth.uid()
      and pe.presente = true
  )
);

drop policy if exists "questionari_domande_select"
on public.questionari_domande;

create policy "questionari_domande_select"
on public.questionari_domande
as permissive
for select
to authenticated
using (
  app_backoffice_admin()
  or exists (
    select 1
    from public.questionari q
    join public.partecipazioni_eventi pe
      on pe.evento_id = q.evento_id
    where q.template_id = questionari_domande.template_id
      and q.provider = 'interno'::questionario_provider
      and q.aperto = true
      and (q.data_apertura is null or q.data_apertura <= now())
      and (q.data_chiusura is null or q.data_chiusura >= now())
      and pe.partecipante_id = auth.uid()
      and pe.presente = true
  )
);

commit;
