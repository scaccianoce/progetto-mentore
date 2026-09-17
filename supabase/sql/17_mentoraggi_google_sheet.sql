-- ============================================================================
-- 17 - SINCRONIZZAZIONE MENTORAGGI GOOGLE SHEET
-- Estratto in sola lettura dal progetto Supabase sorgente il 2026-09-15.
-- Eseguire dopo 13b_OTHER_correzioni.sql e 16_menu_novita.sql.
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'stato_partecipazione_annuale'
  ) THEN
    CREATE TYPE public.stato_partecipazione_annuale AS ENUM (
      'da_contattare',
      'confermato',
      'rinuncia',
      'nuovo',
      'sospeso'
    );
  END IF;
END;
$$;

CREATE OR REPLACE VIEW public."mentoraggi_google_sheet" AS
 SELECT m.id AS mentoraggio_id,
    lower(TRIM(BOTH FROM a.email_unipa)) AS email_unipa,
    to_char(m.data_visita_1::timestamp with time zone, 'DD-MM-YY'::text) AS data_visita_1,
    to_char(m.data_visita_2::timestamp with time zone, 'DD-MM-YY'::text) AS data_visita_2,
    to_char(m.data_incontro_finale::timestamp with time zone, 'DD-MM-YY'::text) AS data_incontro_finale,
    to_char(m.data_invio_scheda::timestamp with time zone, 'DD-MM-YY'::text) AS data_invio_scheda,
    to_char(m.data_focus_group::timestamp with time zone, 'DD-MM-YY'::text) AS data_focus_group
   FROM mentoraggi m
     JOIN insegnamenti i ON i.id = m.insegnamento_id
     JOIN anagrafica a ON a.user_id = i.docente_id;

CREATE OR REPLACE FUNCTION public.sync_mentoraggio_google_sheet()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'vault', 'net'
AS $function$
declare
    v_project_url text;
    v_secret_key text;
begin
    if
        old.data_visita_1 is distinct from new.data_visita_1
        or old.data_visita_2 is distinct from new.data_visita_2
        or old.data_focus_group is distinct from new.data_focus_group
        or old.data_incontro_finale is distinct from new.data_incontro_finale
        or old.data_invio_scheda is distinct from new.data_invio_scheda
    then
        select decrypted_secret
        into v_project_url
        from vault.decrypted_secrets
        where name = 'mentoraggi_google_sheet_project_url';

        select decrypted_secret
        into v_secret_key
        from vault.decrypted_secrets
        where name = 'mentoraggi_google_sheet_secret_key';

        if v_project_url is null then
            raise exception
                'Secret mentoraggi_google_sheet_project_url non trovato';
        end if;

        if v_secret_key is null then
            raise exception
                'Secret mentoraggi_google_sheet_secret_key non trovato';
        end if;

        perform net.http_post(
            url := v_project_url || '/functions/v1/mentoraggi-google-sheet',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'apikey', v_secret_key
            ),
            body := jsonb_build_object(
                'type', 'UPDATE',
                'table', 'mentoraggi',
                'schema', 'public',
                'record', to_jsonb(new),
                'old_record', to_jsonb(old)
            )
        );
    end if;

    return new;
end;
$function$;

DROP TRIGGER IF EXISTS sync_mentoraggi_google_sheet ON public.mentoraggi;

CREATE TRIGGER sync_mentoraggi_google_sheet
AFTER UPDATE ON public.mentoraggi
FOR EACH ROW
EXECUTE FUNCTION public.sync_mentoraggio_google_sheet();