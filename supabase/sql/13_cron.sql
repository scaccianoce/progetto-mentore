-- ============================================================================
-- 13 - CRON
-- Generato da inventario read-only del progetto Supabase esistente.
-- NON eseguire sul progetto di produzione attuale.
-- Destinato esclusivamente a un NUOVO progetto Supabase vuoto.
-- ============================================================================

-- ATTENZIONE:
-- Il job sorgente dipende da secrets nel Vault.
-- Prima di eseguire questo file sul NUOVO progetto devi creare nel Vault:
--   notifiche_project_url
--   notifiche_publishable_key
--   notifiche_cron_secret
-- con i valori del NUOVO progetto / ambiente.
--
-- Il file NON contiene valori segreti.

-- Job sorgente: notifiche-worker-ogni-minuto | schedule: * * * * *
SELECT cron.schedule(
  'notifiche-worker-ogni-minuto',
  '* * * * *',
  $croncmd$
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
  $croncmd$
);

