-- ============================================================================
-- 02 - ENUM E TIPI CUSTOM
-- Generato da inventario read-only del progetto Supabase esistente.
-- NON eseguire sul progetto di produzione attuale.
-- Destinato esclusivamente a un NUOVO progetto Supabase vuoto.
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'ambito_modifica'
  ) THEN
    CREATE TYPE "public"."ambito_modifica" AS ENUM ('anagrafica', 'insegnamento', 'insegnamento_selezione', 'insegnamento_creazione', 'insegnamento_modifica', 'insegnamento_non_richiesto');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'anno_erogazione'
  ) THEN
    CREATE TYPE "public"."anno_erogazione" AS ENUM ('1° anno', '2° anno', '3° anno', '4° anno', '5° anno', '6° anno');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'app_role'
  ) THEN
    CREATE TYPE "public"."app_role" AS ENUM ('owner', 'organizer', 'participant');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'fascia_eta'
  ) THEN
    CREATE TYPE "public"."fascia_eta" AS ENUM ('<35', '35-40', '41-50', '51-60', '61-70', '>70');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'modalita_svolgimento'
  ) THEN
    CREATE TYPE "public"."modalita_svolgimento" AS ENUM ('In presenza', 'A distanza', 'Misto');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'notifiche_piattaforma'
  ) THEN
    CREATE TYPE "public"."notifiche_piattaforma" AS ENUM ('android', 'ios', 'web');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'notifiche_stato_destinatario'
  ) THEN
    CREATE TYPE "public"."notifiche_stato_destinatario" AS ENUM ('da_inviare', 'inviato', 'letto', 'errore', 'escluso_inattivo', 'senza_dispositivo');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'notifiche_stato_messaggio'
  ) THEN
    CREATE TYPE "public"."notifiche_stato_messaggio" AS ENUM ('bozza', 'programmato', 'da_inviare', 'in_invio', 'inviato', 'parziale', 'annullato', 'errore');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'notifiche_tipo_attivazione'
  ) THEN
    CREATE TYPE "public"."notifiche_tipo_attivazione" AS ENUM ('insert', 'update', 'data', 'programmata');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'notifiche_tipo_destinatari'
  ) THEN
    CREATE TYPE "public"."notifiche_tipo_destinatari" AS ENUM ('tutti', 'participant', 'mentor', 'senior', 'mentee', 'mentor_senior', 'mentor_senior_mentee', 'iscritti_evento', 'iscritti_house_of_mentore', 'anno_accademico', 'manuale', 'relazionale');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'numero_mentoraggi_precedenti'
  ) THEN
    CREATE TYPE "public"."numero_mentoraggi_precedenti" AS ENUM ('1 volta', '2 volte', '3 o più volte');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'preferenza_periodo_mentore_enum'
  ) THEN
    CREATE TYPE "public"."preferenza_periodo_mentore_enum" AS ENUM ('Soltanto nel primo semestre', 'Soltanto nel secondo semestre', 'Una volta per semestre', 'Soltanto in uno dei due semestri, non è importante quale', 'Indifferente');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'questionario_destinatario'
  ) THEN
    CREATE TYPE "public"."questionario_destinatario" AS ENUM ('partecipanti', 'studenti');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'questionario_provider'
  ) THEN
    CREATE TYPE "public"."questionario_provider" AS ENUM ('interno', 'pubblico');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'questionario_tipo_domanda'
  ) THEN
    CREATE TYPE "public"."questionario_tipo_domanda" AS ENUM ('testo_breve', 'testo_lungo', 'booleano', 'scelta_singola', 'scala');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'ruolo_accademico'
  ) THEN
    CREATE TYPE "public"."ruolo_accademico" AS ENUM ('PO', 'PA', 'RU', 'RTT', 'RTDb', 'RTDa', 'altro');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'semestre_erogazione'
  ) THEN
    CREATE TYPE "public"."semestre_erogazione" AS ENUM ('I semestre', 'Annuale', 'II semestre');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'stato_mentoraggio'
  ) THEN
    CREATE TYPE "public"."stato_mentoraggio" AS ENUM ('Non iniziato', 'In corso', 'Completato');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'tipo_mentore'
  ) THEN
    CREATE TYPE "public"."tipo_mentore" AS ENUM ('senior', 'mentor');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'tipologia_evento'
  ) THEN
    CREATE TYPE "public"."tipologia_evento" AS ENUM ('Incontro di approfondimento', 'Seminario', 'Workshop', 'Altro');
  END IF;
END
$$;

