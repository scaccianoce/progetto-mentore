-- ============================================================================
-- 21 - NOTIFICHE V2: VERIFICA POST MIGRAZIONE
-- Query read-only di controllo.
-- ============================================================================

-- 1) colonne nuove su notifiche_messaggi
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notifiche_messaggi'
  AND column_name IN (
    'invia_push',
    'invia_email',
    'tipo_messaggio',
    'tipo_evento_utente',
    'riferimento_data',
    'email_policy',
    'template_context'
  )
ORDER BY column_name;

-- 2) colonne nuove su notifiche_destinatari
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notifiche_destinatari'
  AND column_name IN (
    'push_stato',
    'push_tentativi',
    'push_inviata_at',
    'push_errore',
    'email_stato',
    'email_tentativi',
    'email_programmata_per',
    'email_inviata_at',
    'email_errore',
    'occorrenza_data'
  )
ORDER BY column_name;

-- 3) trigger duplicati updated_at rimossi
SELECT c.relname AS tabella, t.tgname AS trigger_name, pg_get_triggerdef(t.oid, true) AS definizione
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'notifiche_destinatari',
    'notifiche_dispositivi',
    'notifiche_messaggi',
    'notifiche_regole'
  )
  AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname;

-- 4) stato cron notifiche
SELECT jobid, jobname, schedule, active, command
FROM cron.job
WHERE jobname ILIKE 'notifiche%'
ORDER BY jobid;

-- 5) regole senza canali attivi (anomalia)
SELECT id, codice, attiva, invia_push, invia_email
FROM public.notifiche_regole
WHERE attiva IS TRUE
  AND COALESCE(invia_push, false) IS FALSE
  AND COALESCE(invia_email, false) IS FALSE;

-- 6) snapshot sintetico stati destinatari per canale
SELECT
  push_stato,
  email_stato,
  count(*) AS totale
FROM public.notifiche_destinatari
GROUP BY push_stato, email_stato
ORDER BY push_stato, email_stato;
