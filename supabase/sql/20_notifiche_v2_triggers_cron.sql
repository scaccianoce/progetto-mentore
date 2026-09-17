-- ============================================================================
-- 20 - NOTIFICHE V2: TRIGGER E CRON
-- Migrazione per database ESISTENTE.
-- Obiettivi:
-- - eliminare duplicazione trigger updated_at sulle tabelle notifiche
-- - usare trigger sorgente v2
-- - push event-driven per messaggi automatici immediati
-- - cron leggero (giornaliero), non ogni minuto
-- ============================================================================

BEGIN;

-- --------------------------------------------------------------------------
-- 1) Rimozione trigger updated_at duplicati notifiche_*
-- Manteniamo lo standard generale trg_set_updated_at (app_set_updated_at).
-- --------------------------------------------------------------------------
DROP TRIGGER IF EXISTS notifiche_destinatari_updated_at ON public.notifiche_destinatari;
DROP TRIGGER IF EXISTS notifiche_dispositivi_updated_at ON public.notifiche_dispositivi;
DROP TRIGGER IF EXISTS notifiche_messaggi_updated_at ON public.notifiche_messaggi;
DROP TRIGGER IF EXISTS notifiche_regole_updated_at ON public.notifiche_regole;

-- --------------------------------------------------------------------------
-- 2) Trigger sorgente v2 su tabelle evento gia' monitorate
-- --------------------------------------------------------------------------
DROP TRIGGER IF EXISTS notifiche_regole_aiu ON public.eventi;
CREATE TRIGGER notifiche_regole_aiu
AFTER INSERT OR UPDATE ON public.eventi
FOR EACH ROW
EXECUTE FUNCTION public.notifiche_trigger_sorgente_v2();

DROP TRIGGER IF EXISTS notifiche_regole_aiu ON public.news;
CREATE TRIGGER notifiche_regole_aiu
AFTER INSERT OR UPDATE ON public.news
FOR EACH ROW
EXECUTE FUNCTION public.notifiche_trigger_sorgente_v2();

DROP TRIGGER IF EXISTS notifiche_regole_aiu ON public.house_of_mentore;
CREATE TRIGGER notifiche_regole_aiu
AFTER INSERT OR UPDATE ON public.house_of_mentore
FOR EACH ROW
EXECUTE FUNCTION public.notifiche_trigger_sorgente_v2();

DROP TRIGGER IF EXISTS notifiche_regole_aiu ON public.partecipazioni_eventi;
CREATE TRIGGER notifiche_regole_aiu
AFTER INSERT OR UPDATE ON public.partecipazioni_eventi
FOR EACH ROW
EXECUTE FUNCTION public.notifiche_trigger_sorgente_v2();

-- --------------------------------------------------------------------------
-- 3) Push event-driven: dispatch immediato per messaggi automatici
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_dispatch_push_evento()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'vault', 'net'
AS $function$
DECLARE
  v_project_url text;
  v_publishable_key text;
  v_cron_secret text;
BEGIN
  -- Solo messaggi automatici e immediati.
  IF NEW.regola_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NOT COALESCE(NEW.invia_push, true) THEN
    RETURN NEW;
  END IF;

  IF NEW.programmata_per IS NOT NULL AND NEW.programmata_per > now() THEN
    RETURN NEW;
  END IF;

  SELECT decrypted_secret
  INTO v_project_url
  FROM vault.decrypted_secrets
  WHERE name = 'notifiche_project_url'
  LIMIT 1;

  SELECT decrypted_secret
  INTO v_publishable_key
  FROM vault.decrypted_secrets
  WHERE name = 'notifiche_publishable_key'
  LIMIT 1;

  SELECT decrypted_secret
  INTO v_cron_secret
  FROM vault.decrypted_secrets
  WHERE name = 'notifiche_cron_secret'
  LIMIT 1;

  IF v_project_url IS NULL OR v_publishable_key IS NULL OR v_cron_secret IS NULL THEN
    -- Non blocca l'inserimento del messaggio: il cron giornaliero recupera.
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url := v_project_url || '/functions/v1/notifiche-invia',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', v_publishable_key,
      'x-cron-secret', v_cron_secret
    ),
    body := jsonb_build_object(
      'messaggio_id', NEW.id,
      'azione', 'invio_push_evento'
    )
  );

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS notifiche_dispatch_push_evento ON public.notifiche_messaggi;
CREATE TRIGGER notifiche_dispatch_push_evento
AFTER INSERT ON public.notifiche_messaggi
FOR EACH ROW
EXECUTE FUNCTION public.notifiche_dispatch_push_evento();

COMMIT;

-- --------------------------------------------------------------------------
-- 4) CRON LIGHT: rimozione worker ogni minuto + job giornaliero
-- Fuori transazione per compatibilita' pg_cron.
-- --------------------------------------------------------------------------

-- Disattiva i vecchi job se presenti.
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname IN (
  'notifiche-worker-giornaliero-v2'
);

-- Job giornaliero: materializza regole temporali + processa coda programmata.
SELECT cron.schedule(
  'notifiche-worker-giornaliero-v2',
  '0 6,11 * * *',
  $croncmd$
  select net.http_post(
    url := (
      select decrypted_secret
      from vault.decrypted_secrets
      where name = 'notifiche_project_url'
      limit 1
    ) || '/functions/v1/notifiche-invia',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'notifiche_publishable_key'
        limit 1
      ),
      'x-cron-secret', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'notifiche_cron_secret'
        limit 1
      )
    ),
    body := jsonb_build_object(
      'azione', 'processa_coda'
    )
  );
  $croncmd$
);
