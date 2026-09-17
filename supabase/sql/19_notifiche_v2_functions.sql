-- ============================================================================
-- 19 - NOTIFICHE V2: FUNZIONI
-- Migrazione per database ESISTENTE.
-- Include:
-- - render template con placeholder annidati {{a.b.c}}
-- - context relazionale base (mentoraggi -> insegnamento/docente)
-- - metadati messaggio per canali push/email
-- - scheduling email con quota giornaliera (max 90)
-- ============================================================================

BEGIN;

-- --------------------------------------------------------------------------
-- Utility: lettura valore da path jsonb "a.b.c"
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_jsonb_get_text(
  p_data jsonb,
  p_path text
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public'
AS $function$
DECLARE
  v_parts text[];
  v_curr jsonb := p_data;
  v_part text;
BEGIN
  IF p_data IS NULL OR p_path IS NULL OR btrim(p_path) = '' THEN
    RETURN NULL;
  END IF;

  v_parts := string_to_array(p_path, '.');

  FOREACH v_part IN ARRAY v_parts LOOP
    IF v_curr IS NULL THEN
      RETURN NULL;
    END IF;
    v_curr := v_curr -> v_part;
  END LOOP;

  IF v_curr IS NULL OR v_curr = 'null'::jsonb THEN
    RETURN NULL;
  END IF;

  IF jsonb_typeof(v_curr) = 'string' THEN
    RETURN trim(both '"' from v_curr::text);
  END IF;

  RETURN v_curr::text;
END;
$function$;

-- --------------------------------------------------------------------------
-- Template engine v2: supporta {{campo}} e {{relazione.campo}}
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_render_template_v2(
  p_template text,
  p_context jsonb
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public'
AS $function$
DECLARE
  v_result text := COALESCE(p_template, '');
  v_match text[];
  v_placeholder text;
  v_value text;
BEGIN
  IF v_result = '' OR p_context IS NULL THEN
    RETURN v_result;
  END IF;

  FOR v_match IN
    SELECT regexp_matches(v_result, '\\{\\{\\s*([A-Za-z0-9_\\.]+)\\s*\\}\\}', 'g')
  LOOP
    v_placeholder := v_match[1];
    v_value := public.notifiche_jsonb_get_text(p_context, v_placeholder);
    v_result := regexp_replace(
      v_result,
      '\\{\\{\\s*' || replace(v_placeholder, '.', '\\.') || '\\s*\\}\\}',
      COALESCE(v_value, ''),
      'g'
    );
  END LOOP;

  RETURN v_result;
END;
$function$;

-- --------------------------------------------------------------------------
-- Costruzione context con campi relazionali principali
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_costruisci_context(
  p_tabella text,
  p_record jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_context jsonb := COALESCE(p_record, '{}'::jsonb);
  v_id uuid;
  v_row RECORD;
BEGIN
  IF p_tabella IS NULL OR p_record IS NULL THEN
    RETURN v_context;
  END IF;

  IF p_tabella = 'mentoraggi' THEN
    BEGIN
      v_id := NULLIF(p_record->>'id', '')::uuid;
    EXCEPTION WHEN others THEN
      v_id := NULL;
    END;

    IF v_id IS NOT NULL THEN
      SELECT
        m.data_inizio,
        m.data_fine,
        i.insegnamento,
        i.cds,
        a.nome,
        a.cognome,
        a.email_unipa
      INTO v_row
      FROM public.mentoraggi m
      JOIN public.insegnamenti i ON i.id = m.insegnamento_id
      LEFT JOIN public.anagrafica a ON a.user_id = i.docente_id
      WHERE m.id = v_id;

      v_context := v_context || jsonb_build_object(
        'insegnamento', jsonb_build_object(
          'insegnamento', v_row.insegnamento,
          'cds', v_row.cds
        ),
        'docente', jsonb_build_object(
          'nome', v_row.nome,
          'cognome', v_row.cognome,
          'email_unipa', v_row.email_unipa
        ),
        'data_inizio_fmt', to_char(v_row.data_inizio, 'DD/MM/YYYY'),
        'data_fine_fmt', to_char(v_row.data_fine, 'DD/MM/YYYY')
      );
    END IF;
  ELSIF p_tabella = 'eventi' THEN
    v_context := v_context || jsonb_build_object(
      'data_fmt', to_char((p_record->>'data_evento')::date, 'DD/MM/YYYY')
    );
  END IF;

  RETURN v_context;
END;
$function$;

-- --------------------------------------------------------------------------
-- Applica metadati v2 al messaggio creato da regola
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_applica_v2_messaggio_da_regola(
  p_messaggio_id uuid,
  p_regola_id uuid,
  p_record jsonb,
  p_evento text,
  p_data_riferimento timestamptz DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_regola public.notifiche_regole%ROWTYPE;
  v_context jsonb;
  v_tipo_evento text;
  v_riferimento_data date;
  v_email_policy text := 'posticipa';
BEGIN
  SELECT *
  INTO v_regola
  FROM public.notifiche_regole
  WHERE id = p_regola_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_context := public.notifiche_costruisci_context(v_regola.tabella, p_record);

  IF v_regola.tipo_attivazione::text = 'insert' THEN
    v_tipo_evento := 'nuovo_inserimento';
  ELSIF v_regola.tipo_attivazione::text = 'update' THEN
    v_tipo_evento := 'aggiornamento';
  ELSIF v_regola.tipo_attivazione::text = 'programmata' THEN
    v_tipo_evento := 'programmata';
  ELSE
    IF COALESCE(v_regola.offset_giorni, 0) < 0 THEN
      v_tipo_evento := 'reminder_prima_data';
    ELSIF COALESCE(v_regola.offset_giorni, 0) = 0 THEN
      v_tipo_evento := 'reminder_giorno_data';
      v_email_policy := 'anticipa';
    ELSE
      v_tipo_evento := 'reminder_dopo_data';
    END IF;
  END IF;

  v_riferimento_data := COALESCE(
    p_data_riferimento::date,
    (p_record ->> v_regola.campo_data)::date,
    CURRENT_DATE
  );

  UPDATE public.notifiche_messaggi m
  SET
    tipo_messaggio = 'automatica',
    tipo_evento_utente = v_tipo_evento,
    invia_push = COALESCE(v_regola.invia_push, true),
    invia_email = COALESCE(v_regola.invia_email, false),
    email_policy = v_email_policy,
    riferimento_data = v_riferimento_data,
    template_context = v_context,
    titolo = public.notifiche_render_template_v2(v_regola.titolo_template, v_context),
    messaggio = public.notifiche_render_template_v2(v_regola.messaggio_template, v_context)
  WHERE m.id = p_messaggio_id;
END;
$function$;

-- --------------------------------------------------------------------------
-- Trigger sorgente v2: usa la pipeline esistente + metadati canali
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_trigger_sorgente_v2()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_regola public.notifiche_regole%rowtype;
  v_new jsonb := to_jsonb(new);
  v_old jsonb := CASE WHEN tg_op = 'UPDATE' THEN to_jsonb(old) ELSE '{}'::jsonb END;
  v_campo text;
  v_cambiato boolean;
  v_richiede_attiva boolean;
  v_msg_id uuid;
BEGIN
  FOR v_regola IN
    SELECT *
    FROM public.notifiche_regole
    WHERE attiva IS TRUE
      AND tabella = tg_table_name
      AND tipo_attivazione::text = lower(tg_op)
  LOOP
    v_richiede_attiva := COALESCE((v_regola.configurazione->>'richiede_attiva')::boolean, false);
    IF v_richiede_attiva
       AND lower(COALESCE(v_new->>'attiva', 'false')) NOT IN ('true', 't', '1', 'yes') THEN
      CONTINUE;
    END IF;

    IF NOT public.notifiche_condizioni_regola_ok(
      tg_table_name,
      v_new,
      v_regola.configurazione
    ) THEN
      CONTINUE;
    END IF;

    IF tg_op = 'UPDATE' THEN
      v_cambiato := false;
      IF jsonb_typeof(v_regola.configurazione->'campi_monitorati') = 'array'
         AND jsonb_array_length(v_regola.configurazione->'campi_monitorati') > 0 THEN
        FOR v_campo IN
          SELECT value FROM jsonb_array_elements_text(v_regola.configurazione->'campi_monitorati')
        LOOP
          IF (v_old->v_campo) IS DISTINCT FROM (v_new->v_campo) THEN
            v_cambiato := true;
            EXIT;
          END IF;
        END LOOP;
      ELSE
        v_cambiato := (v_old - 'updated_at') IS DISTINCT FROM (v_new - 'updated_at');
      END IF;

      IF NOT v_cambiato THEN
        CONTINUE;
      END IF;
    END IF;

    v_msg_id := public.notifiche_crea_messaggio_da_regola(
      v_regola.id,
      v_new,
      lower(tg_op),
      NULL
    );

    IF v_msg_id IS NOT NULL THEN
      PERFORM public.notifiche_applica_v2_messaggio_da_regola(
        v_msg_id,
        v_regola.id,
        v_new,
        lower(tg_op),
        NULL
      );
    END IF;
  END LOOP;

  RETURN new;
END;
$function$;

-- --------------------------------------------------------------------------
-- Materializzazione regole temporali v2 (riusa logica esistente)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_materializza_regole_temporali_v2()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_regola public.notifiche_regole%rowtype;
  v_record jsonb;
  v_data timestamptz;
  v_scadenza timestamptz;
  v_id uuid;
  v_count integer := 0;
BEGIN
  FOR v_regola IN
    SELECT * FROM public.notifiche_regole
    WHERE attiva IS TRUE
      AND tipo_attivazione::text = 'data'
      AND tabella IS NOT NULL
      AND campo_data IS NOT NULL
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns c
      WHERE c.table_schema = 'public'
        AND c.table_name = v_regola.tabella
        AND c.column_name = v_regola.campo_data
    ) THEN
      CONTINUE;
    END IF;

    FOR v_record IN
      EXECUTE format(
        'select to_jsonb(t) from public.%I t where %I is not null',
        v_regola.tabella,
        v_regola.campo_data
      )
    LOOP
      BEGIN
        v_data := (v_record->>v_regola.campo_data)::timestamptz;
      EXCEPTION WHEN others THEN
        CONTINUE;
      END;

      v_scadenza := v_data + make_interval(days => v_regola.offset_giorni);
      IF v_scadenza::date > now()::date THEN
        CONTINUE;
      END IF;

      v_id := public.notifiche_crea_messaggio_da_regola(
        v_regola.id,
        v_record,
        'data',
        v_scadenza
      );

      IF v_id IS NOT NULL THEN
        PERFORM public.notifiche_applica_v2_messaggio_da_regola(
          v_id,
          v_regola.id,
          v_record,
          'data',
          v_scadenza
        );
        v_count := v_count + 1;
      END IF;
    END LOOP;
  END LOOP;

  RETURN v_count;
END;
$function$;

-- --------------------------------------------------------------------------
-- Pianifica la coda email di un messaggio con limite giornaliero (90)
-- --------------------------------------------------------------------------
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
        WHEN v_policy = 'anticipa' THEN (v_base - ((c.rn - 1) / p_limite_giornaliero))
        ELSE (v_base + ((c.rn - 1) / p_limite_giornaliero))
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

-- --------------------------------------------------------------------------
-- Pianifica email per tutti i messaggi con invia_email attivo
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_email_pianifica_coda(
  p_limite_giornaliero integer DEFAULT 90
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_m record;
  v_count integer := 0;
BEGIN
  FOR v_m IN
    SELECT id
    FROM public.notifiche_messaggi
    WHERE invia_email IS TRUE
      AND stato IN ('da_inviare', 'programmato', 'parziale', 'errore', 'in_invio')
  LOOP
    PERFORM public.notifiche_email_pianifica_messaggio(v_m.id, p_limite_giornaliero);
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$function$;

COMMIT;
