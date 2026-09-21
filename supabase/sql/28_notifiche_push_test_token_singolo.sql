-- ============================================================================
-- 28 - TEST PUSH FCM SU UN SINGOLO TOKEN
--
-- Modificare token_fcm, titolo e messaggio, quindi eseguire l'intera query.
-- Funziona sia su TEST_db_mentore sia su dB_mentore.
-- ============================================================================

WITH parametri AS (
  SELECT
    'INCOLLA_QUI_IL_TOKEN_FCM'::text AS token_fcm,
    'Test push'::text AS titolo,
    'Notifica di prova dal Progetto Mentore'::text AS messaggio
),
segreti AS (
  SELECT
    max(decrypted_secret) FILTER (
      WHERE name = 'notifiche_project_url'
    ) AS project_url,
    max(decrypted_secret) FILTER (
      WHERE name = 'notifiche_publishable_key'
    ) AS publishable_key,
    max(decrypted_secret) FILTER (
      WHERE name = 'notifiche_cron_secret'
    ) AS cron_secret
  FROM vault.decrypted_secrets
  WHERE name IN (
    'notifiche_project_url',
    'notifiche_publishable_key',
    'notifiche_cron_secret'
  )
)
SELECT net.http_post(
  url => rtrim(s.project_url, '/') || '/functions/v1/notifiche-push-test',
  headers => jsonb_build_object(
    'Content-Type', 'application/json',
    'apikey', s.publishable_key,
    'x-cron-secret', s.cron_secret
  ),
  body => jsonb_build_object(
    'token', p.token_fcm,
    'titolo', p.titolo,
    'messaggio', p.messaggio
  )
) AS request_id
FROM parametri p
CROSS JOIN segreti s;

-- pg_net esegue la chiamata dopo la conclusione della query.
-- Attendere qualche secondo, poi eseguire separatamente:
--
-- SELECT
--   id AS request_id,
--   status_code,
--   error_msg,
--   content AS risposta
-- FROM net._http_response
-- ORDER BY id DESC
-- LIMIT 10;
