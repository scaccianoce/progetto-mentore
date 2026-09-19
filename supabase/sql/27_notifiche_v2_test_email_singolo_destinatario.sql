-- ============================================================================
-- 27 - NOTIFICHE V2: TEST EMAIL SINGOLO DESTINATARIO VIA EDGE FUNCTION
--
-- Obiettivo:
-- - creare un messaggio manuale SOLO email per un user_id specifico
-- - richiamare la edge-function notifiche-invia con quel messaggio
-- - ottenere subito messaggio_id e request_id per diagnosi
--
-- Prima di eseguire:
-- 1) sostituisci il valore di v_user_id con l'utente target
-- 2) verifica che l'utente sia attivo e abbia email_unipa valorizzata
-- ============================================================================

DO $block$
DECLARE
  v_user_id uuid := '00000000-0000-0000-0000-000000000000'; -- TODO: sostituire
  v_titolo text := 'Test invio email da SQL';
  v_testo text := 'Questa e'' una email di test inviata tramite edge-function notifiche-invia.';
  v_anno text;
  v_messaggio_id uuid;
  v_request_id bigint;
BEGIN
  IF v_user_id = '00000000-0000-0000-0000-000000000000'::uuid THEN
    RAISE EXCEPTION 'Sostituisci v_user_id nello script 27 con lo user_id reale del destinatario.';
  END IF;

  -- Verifica utente attivo con email disponibile.
  PERFORM 1
  FROM public.anagrafica a
  JOIN public.anagrafica_riservata ar ON ar.user_id = a.user_id
  WHERE a.user_id = v_user_id
    AND ar.attivo IS TRUE
    AND NULLIF(trim(a.email_unipa), '') IS NOT NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Utente % non valido per test email: serve attivo=true ed email_unipa valorizzata.', v_user_id;
  END IF;

  v_anno := COALESCE(
    public.notifiche_anno_corrente(),
    public.anno_accademico_attivo()
  );

  INSERT INTO public.notifiche_messaggi (
    regola_id,
    anno_accademico,
    titolo,
    messaggio,
    destinatari,
    destinatari_configurazione,
    programmata_per,
    stato,
    invia_push,
    invia_email,
    tipo_messaggio,
    tipo_evento_utente,
    creata_da
  )
  VALUES (
    NULL,
    v_anno,
    v_titolo,
    v_testo,
    'manuale'::public.notifiche_tipo_destinatari,
    jsonb_build_object('user_ids', jsonb_build_array(v_user_id::text)),
    NULL,
    'da_inviare'::public.notifiche_stato_messaggio,
    FALSE,
    TRUE,
    'manuale',
    'manuale',
    NULL
  )
  RETURNING id INTO v_messaggio_id;

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
    body := jsonb_build_object('messaggio_id', v_messaggio_id)
  ) INTO v_request_id;

  RAISE NOTICE 'Messaggio test creato: %', v_messaggio_id;
  RAISE NOTICE 'Request id edge-function: %', v_request_id;
END;
$block$;

-- Controlla esito HTTP recente.
SELECT id, status_code, error_msg, content
FROM net._http_response
ORDER BY id DESC
LIMIT 10;

-- Controlla dettaglio stato destinatari del test (prende l'ultimo messaggio creato).
WITH ultimo_messaggio AS (
  SELECT id
  FROM public.notifiche_messaggi
  WHERE titolo = 'Test invio email da SQL'
  ORDER BY created_at DESC
  LIMIT 1
)
SELECT
  d.messaggio_id,
  d.user_id,
  d.stato,
  d.push_stato,
  d.email_stato,
  d.email_tentativi,
  d.email_inviata_at,
  d.email_errore,
  d.updated_at
FROM public.notifiche_destinatari d
JOIN ultimo_messaggio u ON u.id = d.messaggio_id;
