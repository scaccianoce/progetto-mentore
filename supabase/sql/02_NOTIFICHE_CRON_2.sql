-- =====================================================================
-- NOTIFICHE - CONFIGURAZIONE SUPABASE CRON
-- =====================================================================
--
-- Il job viene eseguito ogni minuto e richiama:
--
--   Edge Function: notifiche-invia
--
-- La Edge Function si occuperà di:
--
--   1. notifiche manuali programmate scadute;
--   2. regole automatiche basate sulle date;
--   3. regole automatiche programmate;
--   4. generazione destinatari;
--   5. invio push tramite FCM.
--
-- I valori sensibili/configurabili vengono conservati nel Vault.
--
-- =====================================================================


-- =====================================================================
-- 1. ESTENSIONI NECESSARIE
-- =====================================================================

create extension if not exists pg_cron
with schema pg_catalog;

create extension if not exists pg_net
with schema extensions;


-- =====================================================================
-- 2. CONFIGURAZIONE VAULT
--
-- SOSTITUIRE SOLTANTO:
--
--   YOUR_PROJECT_URL
--   YOUR_PUBLISHABLE_KEY
--   YOUR_CRON_SECRET
--
-- NON modificare:
--
--   notifiche_project_url
--   notifiche_publishable_key
--   notifiche_cron_secret
--
-- =====================================================================


-- ---------------------------------------------------------------------
-- URL DEL PROGETTO SUPABASE
--
-- Esempio:
-- https://abcdefghijk.supabase.co
-- ---------------------------------------------------------------------

select vault.create_secret(
  'https://dwzmuxlwndsctkhrmuzt.supabase.co',
  'notifiche_project_url'
);


-- ---------------------------------------------------------------------
-- PUBLISHABLE KEY SUPABASE
--
-- Deve essere la chiave:
--
--   sb_publishable_...
--
-- NON usare la Secret Key.
-- ---------------------------------------------------------------------

select vault.create_secret(
  'sb_publishable_jgZAFuXc36RinuKub400zw_hFog6atv',
  'notifiche_publishable_key'
);


-- ---------------------------------------------------------------------
-- SECRET CONDIVISO TRA CRON ED EDGE FUNCTION
--
-- Deve essere ESATTAMENTE lo stesso valore salvato in:
--
-- Edge Functions -> Secrets
--
-- con nome:
--
--   NOTIFICHE_CRON_SECRET
--
-- Puoi generarlo con:
--
--   openssl rand -hex 32
--
-- ---------------------------------------------------------------------

select vault.create_secret(
  '64a508fd0adf35fd536230c2f9b3de248aa447071346145e6f85318ea356f775',
  'notifiche_cron_secret'
);


-- =====================================================================
-- 3. ELIMINA EVENTUALE JOB PRECEDENTE
-- =====================================================================

do $$
declare
  v_job_id bigint;
begin

  select jobid
  into v_job_id
  from cron.job
  where jobname = 'notifiche-worker-ogni-minuto'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

end;
$$;


-- =====================================================================
-- 4. CREA IL CRON JOB
--
-- Frequenza:
--
--   * * * * *
--
-- significa:
--
--   OGNI MINUTO
--
-- =====================================================================

select cron.schedule(
  'notifiche-worker-ogni-minuto',

  '* * * * *',

  $cron$

  select net.http_post(

    -- ---------------------------------------------------------------
    -- URL EDGE FUNCTION
    -- ---------------------------------------------------------------

    url := (
      select decrypted_secret
      from vault.decrypted_secrets
      where name = 'notifiche_project_url'
      limit 1
    )
    || '/functions/v1/notifiche-invia',


    -- ---------------------------------------------------------------
    -- HEADERS
    -- ---------------------------------------------------------------

    headers := jsonb_build_object(

      'Content-Type',
      'application/json',

      'apikey',
      (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'notifiche_publishable_key'
        limit 1
      ),

      'x-cron-secret',
      (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'notifiche_cron_secret'
        limit 1
      )

    ),


    -- ---------------------------------------------------------------
    -- BODY
    --
    -- Indica alla Edge Function che deve eseguire il worker.
    -- ---------------------------------------------------------------

    body := jsonb_build_object(
      'action',
      'worker'
    )

  );

  $cron$
);


-- =====================================================================
-- 5. VERIFICA CHE IL JOB ESISTA
-- =====================================================================

select
  jobid,
  jobname,
  schedule,
  active,
  command
from cron.job
where jobname = 'notifiche-worker-ogni-minuto';


-- =====================================================================
-- FINE CONFIGURAZIONE
-- =====================================================================
