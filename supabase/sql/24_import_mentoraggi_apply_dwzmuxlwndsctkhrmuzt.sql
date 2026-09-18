-- =============================================================================
-- 24 - IMPORT MENTORAGGI (APPLY)
-- Target: dwzmuxlwndsctkhrmuzt
--
-- Usa i dati in public.import_mentoraggi_csv_20260918 per:
-- - aggiornare public.mentoraggi
-- - inserire in public.mentoraggio_mentori (mentor, mentor, senior)
--
-- Regole principali:
-- - match docente: anagrafica.email_unipa == ID (case-insensitive, trim)
-- - match insegnamento: insegnamenti.docente_id = anagrafica.user_id
-- - match mentoraggio: mentoraggi.insegnamento_id = insegnamenti.id
-- - se il match mentoraggio e' ambiguo (piu righe), la riga NON viene applicata
-- - numero_studenti: intervallo -> media arrotondata, "meno di X" -> floor(X/2),
--   "X e oltre" -> X
-- - campi vuoti nel CSV NON sovrascrivono i valori esistenti in mentoraggi
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 0) Normalizzazione e parse
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_import_mentoraggi_norm;
CREATE TEMP TABLE tmp_import_mentoraggi_norm AS
SELECT
  row_number() OVER () AS riga,
  lower(trim(id_email)) AS docente_email,
  nullif(trim(data_inizio_corso), '') AS data_inizio_txt,
  nullif(trim(data_fine_corso), '') AS data_fine_txt,
  nullif(trim(giorni_orari), '') AS giorni_orari_lezioni,
  nullif(trim(numero_studenti_attesi), '') AS numero_studenti_txt,
  nullif(trim(tipologia_aula), '') AS sede,
  nullif(trim(note), '') AS note,
  nullif(trim(link_questionario), '') AS link_questionario,
  nullif(lower(trim(email_mentore_1)), '') AS email_mentore_1,
  nullif(lower(trim(email_mentore_2)), '') AS email_mentore_2,
  nullif(lower(trim(email_mentore_senior)), '') AS email_mentore_senior
FROM public.import_mentoraggi_csv_20260918
WHERE nullif(trim(id_email), '') IS NOT NULL;

DROP TABLE IF EXISTS tmp_import_mentoraggi_mappati;
CREATE TEMP TABLE tmp_import_mentoraggi_mappati AS
WITH parsed AS (
  SELECT
    n.*,
    CASE
      WHEN n.data_inizio_txt ~ '^\d{2}/\d{2}/\d{2}$' THEN to_date(n.data_inizio_txt, 'DD/MM/YY')
      ELSE NULL
    END AS data_inizio,
    CASE
      WHEN n.data_fine_txt ~ '^\d{2}/\d{2}/\d{2}$' THEN to_date(n.data_fine_txt, 'DD/MM/YY')
      ELSE NULL
    END AS data_fine,
    CASE
      WHEN n.numero_studenti_txt ~ '^\d+\s*-\s*\d+$' THEN round((
        (regexp_match(n.numero_studenti_txt, '^(\d+)\s*-\s*(\d+)$'))[1]::numeric +
        (regexp_match(n.numero_studenti_txt, '^(\d+)\s*-\s*(\d+)$'))[2]::numeric
      ) / 2.0)::int
      WHEN lower(n.numero_studenti_txt) ~ '^meno di\s+\d+$' THEN floor(
        (regexp_match(lower(n.numero_studenti_txt), '^meno di\s+(\d+)$'))[1]::numeric / 2.0
      )::int
      WHEN lower(n.numero_studenti_txt) ~ '^\d+\s*e\s*oltre$' THEN
        (regexp_match(lower(n.numero_studenti_txt), '^(\d+)\s*e\s*oltre$'))[1]::int
      ELSE NULL
    END AS numero_studenti
  FROM tmp_import_mentoraggi_norm n
),
docenti AS (
  SELECT p.*, a.user_id AS docente_user_id
  FROM parsed p
  LEFT JOIN public.anagrafica a
    ON lower(trim(a.email_unipa)) = p.docente_email
),
ins AS (
  SELECT d.*, i.id AS insegnamento_id
  FROM docenti d
  LEFT JOIN public.insegnamenti i
    ON i.docente_id = d.docente_user_id
),
ment AS (
  SELECT
    i.*,
    m.id AS mentoraggio_id,
    count(m.id) OVER (PARTITION BY i.riga) AS mentoraggi_candidati,
    row_number() OVER (PARTITION BY i.riga ORDER BY m.updated_at DESC NULLS LAST, m.created_at DESC NULLS LAST, m.id) AS rn
  FROM ins i
  LEFT JOIN public.mentoraggi m
    ON m.insegnamento_id = i.insegnamento_id
)
SELECT
  riga,
  docente_email,
  docente_user_id,
  insegnamento_id,
  mentoraggio_id,
  mentoraggi_candidati,
  data_inizio,
  data_fine,
  giorni_orari_lezioni,
  numero_studenti,
  sede,
  note,
  link_questionario,
  email_mentore_1,
  email_mentore_2,
  email_mentore_senior
FROM ment
WHERE rn = 1 OR mentoraggio_id IS NULL;

-- -----------------------------------------------------------------------------
-- 1) Report pre-apply (diagnostico)
-- -----------------------------------------------------------------------------
SELECT
  count(*) AS righe_csv,
  count(*) FILTER (WHERE docente_user_id IS NULL) AS docente_non_trovato,
  count(*) FILTER (WHERE docente_user_id IS NOT NULL AND insegnamento_id IS NULL) AS insegnamento_non_trovato,
  count(*) FILTER (WHERE docente_user_id IS NOT NULL AND insegnamento_id IS NOT NULL AND mentoraggio_id IS NULL) AS mentoraggio_non_trovato,
  count(*) FILTER (WHERE mentoraggi_candidati > 1) AS mentoraggio_ambiguo,
  count(*) FILTER (WHERE mentoraggio_id IS NOT NULL AND mentoraggi_candidati = 1) AS righe_pronte
FROM tmp_import_mentoraggi_mappati;

-- Elenco righe bloccate
SELECT
  riga,
  docente_email,
  docente_user_id,
  insegnamento_id,
  mentoraggio_id,
  mentoraggi_candidati,
  CASE
    WHEN docente_user_id IS NULL THEN 'docente_non_trovato'
    WHEN insegnamento_id IS NULL THEN 'insegnamento_non_trovato'
    WHEN mentoraggio_id IS NULL THEN 'mentoraggio_non_trovato'
    WHEN mentoraggi_candidati > 1 THEN 'mentoraggio_ambiguo'
    ELSE 'ok'
  END AS stato_match
FROM tmp_import_mentoraggi_mappati
WHERE docente_user_id IS NULL
   OR insegnamento_id IS NULL
   OR mentoraggio_id IS NULL
   OR mentoraggi_candidati > 1
ORDER BY riga;

-- -----------------------------------------------------------------------------
-- 2) APPLY mentoraggi
-- -----------------------------------------------------------------------------
WITH src AS (
  SELECT *
  FROM tmp_import_mentoraggi_mappati
  WHERE mentoraggio_id IS NOT NULL
    AND mentoraggi_candidati = 1
)
UPDATE public.mentoraggi m
SET
  data_inizio = COALESCE(src.data_inizio, m.data_inizio),
  data_fine = COALESCE(src.data_fine, m.data_fine),
  numero_studenti = COALESCE(src.numero_studenti, m.numero_studenti),
  sede = COALESCE(src.sede, m.sede),
  note = COALESCE(src.note, m.note),
  giorni_orari_lezioni = COALESCE(src.giorni_orari_lezioni, m.giorni_orari_lezioni),
  link_questionario = COALESCE(src.link_questionario, m.link_questionario),
  updated_at = now()
FROM src
WHERE m.id = src.mentoraggio_id;

-- -----------------------------------------------------------------------------
-- 3) APPLY mentoraggio_mentori
-- -----------------------------------------------------------------------------
WITH src AS (
  SELECT *
  FROM tmp_import_mentoraggi_mappati
  WHERE mentoraggio_id IS NOT NULL
    AND mentoraggi_candidati = 1
),
mentori_csv AS (
  SELECT riga, mentoraggio_id, email_mentore_1 AS email_mentore, 'mentor'::text AS tipo FROM src
  UNION ALL
  SELECT riga, mentoraggio_id, email_mentore_2 AS email_mentore, 'mentor'::text AS tipo FROM src
  UNION ALL
  SELECT riga, mentoraggio_id, email_mentore_senior AS email_mentore, 'senior'::text AS tipo FROM src
),
mentori_valorizzati AS (
  SELECT *
  FROM mentori_csv
  WHERE email_mentore IS NOT NULL
),
mentori_risolti AS (
  SELECT
    m.riga,
    m.mentoraggio_id,
    a.user_id AS mentore_id,
    m.tipo
  FROM mentori_valorizzati m
  LEFT JOIN public.anagrafica a
    ON lower(trim(a.email_unipa)) = m.email_mentore
)
INSERT INTO public.mentoraggio_mentori (
  mentoraggio_id,
  mentore_id,
  tipo
)
SELECT DISTINCT
  mentoraggio_id,
  mentore_id,
  tipo::public.tipo_mentore
FROM mentori_risolti
WHERE mentore_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- Report mentori non risolti
WITH src AS (
  SELECT *
  FROM tmp_import_mentoraggi_mappati
  WHERE mentoraggio_id IS NOT NULL
    AND mentoraggi_candidati = 1
),
mentori_csv AS (
  SELECT riga, mentoraggio_id, email_mentore_1 AS email_mentore, 'mentor_1'::text AS sorgente FROM src
  UNION ALL
  SELECT riga, mentoraggio_id, email_mentore_2 AS email_mentore, 'mentor_2'::text AS sorgente FROM src
  UNION ALL
  SELECT riga, mentoraggio_id, email_mentore_senior AS email_mentore, 'mentor_senior'::text AS sorgente FROM src
)
SELECT
  m.riga,
  m.mentoraggio_id,
  m.sorgente,
  m.email_mentore
FROM mentori_csv m
LEFT JOIN public.anagrafica a
  ON lower(trim(a.email_unipa)) = m.email_mentore
WHERE m.email_mentore IS NOT NULL
  AND a.user_id IS NULL
ORDER BY m.riga, m.sorgente;

COMMIT;
