-- ============================================================================
-- 25 - NOTIFICHE V2: AVVIO MANUALE WORKER DAL DB + DIAGNOSTICA RAPIDA
-- Eseguire in SQL Editor Supabase oppure via CLI con --file.
-- ============================================================================

-- --------------------------------------------------------------------------
-- 0) Controllo prerequisiti (Vault + job cron)
-- --------------------------------------------------------------------------
SELECT name
FROM vault.decrypted_secrets
WHERE name IN (
  'notifiche_project_url',
  'notifiche_publishable_key',
  'notifiche_cron_secret'
)
ORDER BY name;

SELECT jobid, jobname, schedule, active
FROM cron.job
WHERE jobname = 'notifiche-worker-giornaliero-v2';

-- --------------------------------------------------------------------------
-- 1) Coda attuale prima del trigger manuale
-- --------------------------------------------------------------------------
SELECT
  id,
  titolo,
  stato,
  invia_push,
  invia_email,
  programmata_per,
  created_at
FROM public.notifiche_messaggi
WHERE stato IN ('da_inviare', 'programmato', 'errore', 'parziale', 'in_invio')
ORDER BY created_at DESC
LIMIT 30;

-- --------------------------------------------------------------------------
-- 2) Trigger manuale dal DB (equivalente al cron): azione = processa_coda
--    Versione stateless (senza temp table) compatibile con SQL Editor/CLI.
-- --------------------------------------------------------------------------
WITH richiesta AS (
  SELECT net.http_post(
    url := (
      SELECT decrypted_secret
      FROM vault.decrypted_secrets
      WHERE name = 'notifiche_project_url'
      LIMIT 1
    ) || '/functions/v1/notifiche-invia',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', (
        SELECT decrypted_secret
        FROM vault.decrypted_secrets
        WHERE name = 'notifiche_publishable_key'
        LIMIT 1
      ),
      'x-cron-secret', (
        SELECT decrypted_secret
        FROM vault.decrypted_secrets
        WHERE name = 'notifiche_cron_secret'
        LIMIT 1
      )
    ),
    body := jsonb_build_object('azione', 'processa_coda')
  ) AS request_id
)
SELECT request_id
FROM richiesta;

-- --------------------------------------------------------------------------
-- 3) Esito HTTP della chiamata net.http_post
--    Mostra le risposte HTTP piu recenti (la prima riga e' in genere l'ultima richiesta).
-- --------------------------------------------------------------------------
SELECT
  r.id AS request_id,
  r.status_code,
  r.error_msg,
  r.content
FROM net._http_response r
ORDER BY r.id DESC
LIMIT 20;

-- Opzionale: filtro puntuale per request_id (sostituisci 12345).
-- SELECT r.id AS request_id, r.status_code, r.error_msg, r.content
-- FROM net._http_response r
-- WHERE r.id = 12345;

-- --------------------------------------------------------------------------
-- 4) Stato dopo l'esecuzione (messaggi + destinatari)
-- --------------------------------------------------------------------------
SELECT
  stato,
  count(*) AS totale
FROM public.notifiche_messaggi
GROUP BY stato
ORDER BY stato;

SELECT
  push_stato,
  email_stato,
  count(*) AS totale
FROM public.notifiche_destinatari
GROUP BY push_stato, email_stato
ORDER BY push_stato, email_stato;

-- Ultimi destinatari in errore per diagnosi rapida.
SELECT
  d.messaggio_id,
  d.user_id,
  d.stato,
  d.push_stato,
  d.email_stato,
  d.push_errore,
  d.email_errore,
  d.updated_at
FROM public.notifiche_destinatari d
WHERE d.push_stato IN ('fallita')
   OR d.email_stato IN ('fallita')
ORDER BY d.updated_at DESC
LIMIT 50;

-- --------------------------------------------------------------------------
-- 5) (OPZIONALE) Trigger mirato di un solo messaggio
--    Sostituire <UUID_MESSAGGIO> e lanciare solo questo blocco.
-- --------------------------------------------------------------------------
-- WITH richiesta AS (
-- SELECT net.http_post(
--   url := (
--     SELECT decrypted_secret
--     FROM vault.decrypted_secrets
--     WHERE name = 'notifiche_project_url'
--     LIMIT 1
--   ) || '/functions/v1/notifiche-invia',
--   headers := jsonb_build_object(
--     'Content-Type', 'application/json',
--     'apikey', (
--       SELECT decrypted_secret
--       FROM vault.decrypted_secrets
--       WHERE name = 'notifiche_publishable_key'
--       LIMIT 1
--     ),
--     'x-cron-secret', (
--       SELECT decrypted_secret
--       FROM vault.decrypted_secrets
--       WHERE name = 'notifiche_cron_secret'
--       LIMIT 1
--     )
--   ),
--   body := jsonb_build_object('messaggio_id', '<UUID_MESSAGGIO>')
-- ) AS request_id
-- )
-- SELECT request_id FROM richiesta;