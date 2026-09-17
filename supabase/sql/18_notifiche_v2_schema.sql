-- ============================================================================
-- 18 - NOTIFICHE V2: SCHEMA
-- Migrazione per database ESISTENTE (non per rebuild da zero).
-- Obiettivo: separare canali push/email, introdurre coda email e metadati
-- semplificati per regole/manuali, mantenendo retrocompatibilita'.
-- ============================================================================

BEGIN;

-- --------------------------------------------------------------------------
-- 1) ENUM STATO CANALE
-- --------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'notifiche_stato_canale'
  ) THEN
    CREATE TYPE public.notifiche_stato_canale AS ENUM (
      'non_richiesta',
      'da_inviare',
      'in_coda',
      'in_invio',
      'inviata',
      'fallita',
      'esclusa'
    );
  END IF;
END
$$;

-- --------------------------------------------------------------------------
-- 2) ESTENSIONE GRUPPI DESTINATARI (senza rimuovere valori legacy)
-- --------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'notifiche_tipo_destinatari'
      AND e.enumlabel = 'partecipanti'
  ) THEN
    ALTER TYPE public.notifiche_tipo_destinatari ADD VALUE 'partecipanti';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'notifiche_tipo_destinatari'
      AND e.enumlabel = 'coordinatori'
  ) THEN
    ALTER TYPE public.notifiche_tipo_destinatari ADD VALUE 'coordinatori';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'notifiche_tipo_destinatari'
      AND e.enumlabel = 'amministratori'
  ) THEN
    ALTER TYPE public.notifiche_tipo_destinatari ADD VALUE 'amministratori';
  END IF;
END
$$;

-- --------------------------------------------------------------------------
-- 3) TABELLA notifiche_messaggi: metadati canali e semplificazione UI
-- --------------------------------------------------------------------------
ALTER TABLE public.notifiche_messaggi
  ADD COLUMN IF NOT EXISTS invia_push boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS invia_email boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS tipo_messaggio text NOT NULL DEFAULT 'manuale',
  ADD COLUMN IF NOT EXISTS tipo_evento_utente text NOT NULL DEFAULT 'manuale',
  ADD COLUMN IF NOT EXISTS riferimento_data date,
  ADD COLUMN IF NOT EXISTS email_policy text NOT NULL DEFAULT 'posticipa',
  ADD COLUMN IF NOT EXISTS template_context jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.notifiche_messaggi
  DROP CONSTRAINT IF EXISTS notifiche_messaggi_tipo_messaggio_check;

ALTER TABLE public.notifiche_messaggi
  ADD CONSTRAINT notifiche_messaggi_tipo_messaggio_check
  CHECK (tipo_messaggio IN ('manuale', 'automatica'));

ALTER TABLE public.notifiche_messaggi
  DROP CONSTRAINT IF EXISTS notifiche_messaggi_tipo_evento_utente_check;

ALTER TABLE public.notifiche_messaggi
  ADD CONSTRAINT notifiche_messaggi_tipo_evento_utente_check
  CHECK (
    tipo_evento_utente IN (
      'manuale',
      'nuovo_inserimento',
      'aggiornamento',
      'reminder_prima_data',
      'reminder_giorno_data',
      'reminder_dopo_data',
      'programmata'
    )
  );

ALTER TABLE public.notifiche_messaggi
  DROP CONSTRAINT IF EXISTS notifiche_messaggi_email_policy_check;

ALTER TABLE public.notifiche_messaggi
  ADD CONSTRAINT notifiche_messaggi_email_policy_check
  CHECK (email_policy IN ('posticipa', 'anticipa'));

-- Retrocompatibilita': classifica il pregresso.
UPDATE public.notifiche_messaggi
SET tipo_messaggio = CASE WHEN regola_id IS NULL THEN 'manuale' ELSE 'automatica' END
WHERE tipo_messaggio IS DISTINCT FROM CASE WHEN regola_id IS NULL THEN 'manuale' ELSE 'automatica' END;

-- Vincolo NON VALID per non bloccare dati storici legacy.
ALTER TABLE public.notifiche_messaggi
  DROP CONSTRAINT IF EXISTS notifiche_messaggi_manuale_destinatari_simplified;

ALTER TABLE public.notifiche_messaggi
  ADD CONSTRAINT notifiche_messaggi_manuale_destinatari_simplified
  CHECK (
    tipo_messaggio <> 'manuale'
    OR destinatari::text NOT IN ('anno_accademico', 'relazionale')
  ) NOT VALID;

-- --------------------------------------------------------------------------
-- 4) TABELLA notifiche_regole: canali separati e semantica evento
-- --------------------------------------------------------------------------
ALTER TABLE public.notifiche_regole
  ADD COLUMN IF NOT EXISTS invia_push boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS invia_email boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS tipo_evento_utente text NOT NULL DEFAULT 'aggiornamento';

ALTER TABLE public.notifiche_regole
  DROP CONSTRAINT IF EXISTS notifiche_regole_tipo_evento_utente_check;

ALTER TABLE public.notifiche_regole
  ADD CONSTRAINT notifiche_regole_tipo_evento_utente_check
  CHECK (
    tipo_evento_utente IN (
      'nuovo_inserimento',
      'aggiornamento',
      'reminder_prima_data',
      'reminder_giorno_data',
      'reminder_dopo_data',
      'programmata'
    )
  );

UPDATE public.notifiche_regole
SET tipo_evento_utente = CASE tipo_attivazione::text
  WHEN 'insert' THEN 'nuovo_inserimento'
  WHEN 'update' THEN 'aggiornamento'
  WHEN 'data' THEN CASE
    WHEN coalesce(offset_giorni, 0) < 0 THEN 'reminder_prima_data'
    WHEN coalesce(offset_giorni, 0) = 0 THEN 'reminder_giorno_data'
    ELSE 'reminder_dopo_data'
  END
  WHEN 'programmata' THEN 'programmata'
  ELSE 'aggiornamento'
END
WHERE tipo_evento_utente IS NULL OR tipo_evento_utente = 'manuale';

-- --------------------------------------------------------------------------
-- 5) TABELLA notifiche_destinatari: stato separato push/email
-- --------------------------------------------------------------------------
ALTER TABLE public.notifiche_destinatari
  ADD COLUMN IF NOT EXISTS push_stato public.notifiche_stato_canale NOT NULL DEFAULT 'da_inviare',
  ADD COLUMN IF NOT EXISTS push_tentativi integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS push_inviata_at timestamptz,
  ADD COLUMN IF NOT EXISTS push_errore text,
  ADD COLUMN IF NOT EXISTS email_stato public.notifiche_stato_canale NOT NULL DEFAULT 'non_richiesta',
  ADD COLUMN IF NOT EXISTS email_tentativi integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS email_programmata_per date,
  ADD COLUMN IF NOT EXISTS email_inviata_at timestamptz,
  ADD COLUMN IF NOT EXISTS email_errore text,
  ADD COLUMN IF NOT EXISTS occorrenza_data date;

ALTER TABLE public.notifiche_destinatari
  DROP CONSTRAINT IF EXISTS notifiche_destinatari_push_tentativi_check;

ALTER TABLE public.notifiche_destinatari
  ADD CONSTRAINT notifiche_destinatari_push_tentativi_check
  CHECK (push_tentativi >= 0);

ALTER TABLE public.notifiche_destinatari
  DROP CONSTRAINT IF EXISTS notifiche_destinatari_email_tentativi_check;

ALTER TABLE public.notifiche_destinatari
  ADD CONSTRAINT notifiche_destinatari_email_tentativi_check
  CHECK (email_tentativi >= 0);

-- Backfill stati push dal campo legacy stato.
UPDATE public.notifiche_destinatari
SET
  push_stato = CASE stato::text
    WHEN 'inviato' THEN 'inviata'::public.notifiche_stato_canale
    WHEN 'letto' THEN 'inviata'::public.notifiche_stato_canale
    WHEN 'errore' THEN 'fallita'::public.notifiche_stato_canale
    WHEN 'escluso_inattivo' THEN 'esclusa'::public.notifiche_stato_canale
    WHEN 'senza_dispositivo' THEN 'esclusa'::public.notifiche_stato_canale
    ELSE 'da_inviare'::public.notifiche_stato_canale
  END,
  push_inviata_at = COALESCE(push_inviata_at, inviato_at),
  push_errore = COALESCE(push_errore, errore),
  push_tentativi = CASE
    WHEN stato::text IN ('inviato', 'letto', 'errore', 'senza_dispositivo')
      THEN GREATEST(push_tentativi, 1)
    ELSE push_tentativi
  END;

-- Backfill stato email in base ai flag messaggio.
UPDATE public.notifiche_destinatari d
SET
  email_stato = CASE
    WHEN m.invia_email THEN 'da_inviare'::public.notifiche_stato_canale
    ELSE 'non_richiesta'::public.notifiche_stato_canale
  END,
  occorrenza_data = COALESCE(
    d.occorrenza_data,
    m.riferimento_data,
    (m.programmata_per AT TIME ZONE 'UTC')::date,
    CURRENT_DATE
  )
FROM public.notifiche_messaggi m
WHERE m.id = d.messaggio_id
  AND d.email_stato = 'non_richiesta';

-- --------------------------------------------------------------------------
-- 6) INDICI PER CODE PUSH/EMAIL E RICERCA STORICO
-- --------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS notifiche_destinatari_push_queue_idx
  ON public.notifiche_destinatari (push_stato, messaggio_id, created_at);

CREATE INDEX IF NOT EXISTS notifiche_destinatari_email_queue_idx
  ON public.notifiche_destinatari (email_stato, email_programmata_per, messaggio_id, created_at);

CREATE INDEX IF NOT EXISTS notifiche_messaggi_canali_idx
  ON public.notifiche_messaggi (stato, invia_push, invia_email, programmata_per, created_at);

CREATE INDEX IF NOT EXISTS notifiche_messaggi_tipo_evento_idx
  ON public.notifiche_messaggi (tipo_messaggio, tipo_evento_utente, created_at);

COMMIT;
