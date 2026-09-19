-- ============================================================================
-- 26 - NOTIFICHE V2: FIX DATE - BIGINT IN PIANIFICAZIONE EMAIL
--
-- Errore risolto:
--   operator does not exist: date - bigint
--
-- Causa:
--   row_number() restituisce bigint; in PostgreSQL date +/- integer e' valido,
--   date +/- bigint no.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.notifiche_email_pianifica_messaggio(
  p_messaggio_id uuid,
  p_limite_giornaliero integer DEFAULT 90
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_m public.notifiche_messaggi%rowtype;
  v_base date;
  v_policy text;
BEGIN
  SELECT * INTO v_m
  FROM public.notifiche_messaggi
  WHERE id = p_messaggio_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Messaggio % non trovato', p_messaggio_id;
  END IF;

  IF NOT v_m.invia_email THEN
    UPDATE public.notifiche_destinatari d
    SET email_stato = 'non_richiesta',
        email_programmata_per = NULL
    WHERE d.messaggio_id = p_messaggio_id;
    RETURN 0;
  END IF;

  v_base := COALESCE(v_m.riferimento_data, (v_m.programmata_per AT TIME ZONE 'UTC')::date, CURRENT_DATE);
  v_policy := COALESCE(v_m.email_policy, 'posticipa');

  WITH candidati AS (
    SELECT d.id,
           row_number() OVER (ORDER BY d.created_at, d.user_id, d.id) AS rn
    FROM public.notifiche_destinatari d
    WHERE d.messaggio_id = p_messaggio_id
      AND d.email_stato IN ('da_inviare', 'fallita', 'in_coda')
  ),
  slot AS (
    SELECT
      c.id,
      CASE
        WHEN v_policy = 'anticipa' THEN (
          v_base - (((c.rn - 1) / p_limite_giornaliero)::integer)
        )
        ELSE (
          v_base + (((c.rn - 1) / p_limite_giornaliero)::integer)
        )
      END AS giorno_target
    FROM candidati c
  )
  UPDATE public.notifiche_destinatari d
  SET
    email_stato = 'in_coda',
    email_programmata_per = s.giorno_target,
    occorrenza_data = COALESCE(d.occorrenza_data, v_base)
  FROM slot s
  WHERE d.id = s.id;

  RETURN (
    SELECT count(*)::int
    FROM public.notifiche_destinatari d
    WHERE d.messaggio_id = p_messaggio_id
      AND d.email_stato = 'in_coda'
  );
END;
$function$;

COMMIT;

-- Verifica rapida post-fix (read-only):
-- SELECT public.notifiche_email_pianifica_messaggio('<UUID_MESSAGGIO>'::uuid, 90);
