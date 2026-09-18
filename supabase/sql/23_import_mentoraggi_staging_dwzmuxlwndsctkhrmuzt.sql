-- ==========================================================================
-- 23 - IMPORT MENTORAGGI (STAGING)
-- Target: dwzmuxlwndsctkhrmuzt
--
-- 1) Esegui questo script sul DB target.
-- 2) Carica il CSV locale in questa tabella staging (vedi comando psql sotto).
-- 3) Esegui poi 24_import_mentoraggi_apply_dwzmuxlwndsctkhrmuzt.sql.
-- ==========================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.import_mentoraggi_csv_20260918 (
  id_email text,
  data_inizio_corso text,
  data_fine_corso text,
  giorni_orari text,
  numero_studenti_attesi text,
  tipologia_aula text,
  note text,
  link_questionario text,
  email_mentore_1 text,
  email_mentore_2 text,
  email_mentore_senior text,
  created_at timestamptz NOT NULL DEFAULT now()
);

TRUNCATE TABLE public.import_mentoraggi_csv_20260918;

COMMIT;

-- --------------------------------------------------------------------------
-- Caricamento CSV da terminale (esempio)
-- --------------------------------------------------------------------------
-- 1) Assicurati di puntare al DB corretto (dwzmuxlwndsctkhrmuzt).
-- 2) Usa un DB URL con password, ad esempio:
--
--    export DB_URL='postgresql://postgres.<PROJECT_REF>:<PASSWORD>@aws-1-eu-west-1.pooler.supabase.com:5432/postgres'
--
-- 3) Carica il file:
--
-- psql "$DB_URL" -c "\copy public.import_mentoraggi_csv_20260918(
--   id_email,
--   data_inizio_corso,
--   data_fine_corso,
--   giorni_orari,
--   numero_studenti_attesi,
--   tipologia_aula,
--   note,
--   link_questionario,
--   email_mentore_1,
--   email_mentore_2,
--   email_mentore_senior
-- ) FROM '/Users/gianluca/Downloads/importare.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');"
--
-- Verifica rapida:
-- SELECT count(*) AS righe_staging FROM public.import_mentoraggi_csv_20260918;
