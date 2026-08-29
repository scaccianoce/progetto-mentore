-- ============================================================================
-- 03 - TABELLE PUBLIC
-- Generato da inventario read-only del progetto Supabase esistente.
-- NON eseguire sul progetto di produzione attuale.
-- Destinato esclusivamente a un NUOVO progetto Supabase vuoto.
-- ============================================================================

-- La struttura standard degli schemi auth e storage NON viene ricreata qui:
-- un nuovo progetto Supabase la fornisce automaticamente.
-- Le FK verso auth.users vengono aggiunte successivamente in 04_constraints.sql.

CREATE TABLE IF NOT EXISTS public."abilitazioni_modifica" (
  "user_id" uuid NOT NULL,
  "ambito" "public"."ambito_modifica" NOT NULL,
  "anno_accademico" varchar NOT NULL,
  "richiesta_at" timestamptz DEFAULT now() NOT NULL,
  "abilitata" boolean DEFAULT false NOT NULL,
  "abilitata_da" uuid,
  "abilitata_at" timestamptz,
  "scade_at" timestamptz,
  "revocata_at" timestamptz
);

CREATE TABLE IF NOT EXISTS public."anagrafica" (
  "user_id" uuid NOT NULL,
  "email_unipa" varchar NOT NULL,
  "cognome" varchar NOT NULL,
  "nome" varchar NOT NULL,
  "cod_ssd" varchar,
  "dipartimento" varchar,
  "ufficio" varchar,
  "ruolo_accademico" "public"."ruolo_accademico",
  "cellulare" varchar,
  "pagina_personale_unipa" varchar,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "fascia_eta" "public"."fascia_eta",
  "anno_prima_partecipazione" varchar
);

CREATE TABLE IF NOT EXISTS public."anagrafica_riservata" (
  "user_id" uuid NOT NULL,
  "note_storiche" text,
  "attivo" boolean DEFAULT true NOT NULL
);

CREATE TABLE IF NOT EXISTS public."anni_accademici" (
  "codice" varchar NOT NULL,
  "data_inizio" date,
  "data_fine" date,
  "corrente" boolean DEFAULT false NOT NULL,
  "stato" text DEFAULT 'chiuso'::text NOT NULL
);

CREATE TABLE IF NOT EXISTS public."eventi" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "titolo" varchar NOT NULL,
  "anno_accademico" varchar NOT NULL,
  "luogo" text,
  "data_evento" date NOT NULL,
  "tipologia" "public"."tipologia_evento" NOT NULL,
  "descrizione" text,
  "modalita" "public"."modalita_svolgimento" NOT NULL,
  "relatori" text,
  "moderatori" text,
  "note_organizzative" text,
  "locandina_url" text,
  "data_apertura_iscrizioni" date,
  "data_chiusura_iscrizioni" date,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "attiva" boolean DEFAULT true
);

CREATE TABLE IF NOT EXISTS public."house_of_mentore" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "titolo" text NOT NULL,
  "descrizione" text,
  "anno_accademico" varchar NOT NULL,
  "data_evento" date,
  "luogo" text,
  "locandina_url" text,
  "iscrizioni_aperte" boolean DEFAULT false NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."house_of_mentore_opzioni" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "evento_id" uuid NOT NULL,
  "descrizione" text NOT NULL,
  "ordine_visualizzazione" integer DEFAULT 0 NOT NULL
);

CREATE TABLE IF NOT EXISTS public."import_insegnamenti" (
  "id" bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
  "email_docente" text NOT NULL,
  "insegnamento" text NOT NULL,
  "cfu" integer,
  "cds" text,
  "importato" boolean DEFAULT false NOT NULL,
  "insegnamento_id" uuid,
  "errore" text,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "imported_at" timestamptz,
  "semestre" "public"."semestre_erogazione" NOT NULL,
  "anno_erogazione" "public"."anno_erogazione",
  "ore" integer,
  "mentoraggio_id" uuid
);

CREATE TABLE IF NOT EXISTS public."import_partecipanti" (
  "id" bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
  "email_unipa" text NOT NULL,
  "cognome" text,
  "nome" text,
  "password_temporanea" text NOT NULL,
  "importato" boolean DEFAULT false NOT NULL,
  "user_id" uuid,
  "errore" text,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "imported_at" timestamptz,
  "dipartimento" text,
  "cellulare" text,
  "ufficio" text,
  "ruolo_accademico" "public"."ruolo_accademico",
  "fascia_eta" "public"."fascia_eta"
);

CREATE TABLE IF NOT EXISTS public."insegnamenti" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "docente_id" uuid NOT NULL,
  "insegnamento" varchar NOT NULL,
  "semestre" "public"."semestre_erogazione" NOT NULL,
  "cfu" numeric,
  "ore" integer,
  "cds" varchar,
  "anno_erogazione" "public"."anno_erogazione",
  "created_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."mentoraggi" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "insegnamento_id" uuid NOT NULL,
  "data_visita_1" date,
  "data_visita_2" date,
  "data_visita_3" date,
  "data_visita_4" date,
  "osservazioni_aula" text,
  "data_focus_group" date,
  "osservazioni_focus_group" text,
  "link_questionario" varchar,
  "data_incontro_finale" date,
  "scheda_sintesi" text,
  "data_invio_scheda" date,
  "stato" "public"."stato_mentoraggio" DEFAULT 'Non iniziato'::stato_mentoraggio NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "data_inizio" date,
  "data_fine" date,
  "anno_accademico" varchar NOT NULL,
  "numero_studenti" integer,
  "sede" text,
  "note" text,
  "svolgimento" "public"."modalita_svolgimento",
  "giorni_orari_lezioni" text,
  "scheda_sintesi_pdf_url" text,
  "azioni_miglioramento" text
);

CREATE TABLE IF NOT EXISTS public."mentoraggio_mentori" (
  "mentoraggio_id" uuid NOT NULL,
  "mentore_id" uuid NOT NULL,
  "tipo" "public"."tipo_mentore" DEFAULT 'mentor'::tipo_mentore NOT NULL,
  "assegnato_il" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."news" (
  "id" bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
  "titolo" text NOT NULL,
  "testo" text,
  "data_pubblicazione" timestamp DEFAULT now(),
  "attiva" boolean DEFAULT true,
  "created_at" timestamp DEFAULT now(),
  "updated_at" timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."notifiche_destinatari" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "messaggio_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "stato" "public"."notifiche_stato_destinatario" DEFAULT 'da_inviare'::notifiche_stato_destinatario NOT NULL,
  "inviato_at" timestamptz,
  "letto_at" timestamptz,
  "errore" text,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."notifiche_dispositivi" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "token" text NOT NULL,
  "piattaforma" "public"."notifiche_piattaforma" NOT NULL,
  "attivo" boolean DEFAULT true NOT NULL,
  "ultimo_accesso" timestamptz,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."notifiche_messaggi" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "regola_id" uuid,
  "anno_accademico" text NOT NULL,
  "titolo" text NOT NULL,
  "messaggio" text NOT NULL,
  "destinatari" "public"."notifiche_tipo_destinatari" NOT NULL,
  "destinatari_configurazione" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "origine_tabella" text,
  "origine_id" uuid,
  "chiave_univoca" text,
  "programmata_per" timestamptz,
  "inviata_at" timestamptz,
  "stato" "public"."notifiche_stato_messaggio" DEFAULT 'bozza'::notifiche_stato_messaggio NOT NULL,
  "creata_da" uuid,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."notifiche_regole" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "codice" text NOT NULL,
  "descrizione" text NOT NULL,
  "attiva" boolean DEFAULT true NOT NULL,
  "tipo_attivazione" "public"."notifiche_tipo_attivazione" NOT NULL,
  "tabella" text NOT NULL,
  "campo_data" text,
  "offset_giorni" integer DEFAULT 0 NOT NULL,
  "destinatari" "public"."notifiche_tipo_destinatari" NOT NULL,
  "configurazione" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "titolo_template" text NOT NULL,
  "messaggio_template" text NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL,
  "data_programmata" timestamptz
);

CREATE TABLE IF NOT EXISTS public."partecipazioni_annuali" (
  "user_id" uuid NOT NULL,
  "anno_accademico" varchar NOT NULL,
  "stato" text DEFAULT 'da_contattare'::text NOT NULL,
  "richiesta_at" timestamptz DEFAULT now() NOT NULL,
  "risposta_at" timestamptz,
  "aggiornato_da" uuid,
  "note" text,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL,
  "confermato_at" timestamptz,
  "confermato_da" uuid,
  "preferenza_periodo_mentore" "public"."preferenza_periodo_mentore_enum",
  "note_attivita_mentore" text,
  "solo_mentore" boolean DEFAULT false NOT NULL,
  "valutazione_mentori_precedenti" smallint,
  "cambiare_mentore" boolean,
  "cambiare_mentee_seguiti" text,
  "disponibile_mentoring_esami" boolean,
  "segnalazioni_suggerimenti" text,
  "note_sui_mentori" text
);

CREATE TABLE IF NOT EXISTS public."partecipazioni_eventi" (
  "evento_id" uuid NOT NULL,
  "partecipante_id" uuid NOT NULL,
  "data_iscrizione" timestamptz DEFAULT now() NOT NULL,
  "presente" boolean DEFAULT false NOT NULL,
  "presente_impostato_da" uuid,
  "presente_impostato_at" timestamptz
);

CREATE TABLE IF NOT EXISTS public."partecipazioni_house_of_mentore" (
  "evento_id" uuid NOT NULL,
  "partecipante_id" uuid NOT NULL,
  "opzione_id" uuid NOT NULL,
  "data_iscrizione" timestamptz DEFAULT now() NOT NULL,
  "presente" boolean
);

CREATE TABLE IF NOT EXISTS public."questionari" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "template_id" uuid NOT NULL,
  "titolo" varchar NOT NULL,
  "provider" "public"."questionario_provider" NOT NULL,
  "evento_id" uuid,
  "mentoraggio_id" uuid,
  "url_esterno" text,
  "aperto" boolean DEFAULT true NOT NULL,
  "data_apertura" timestamptz,
  "data_chiusura" timestamptz,
  "created_by" uuid,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "pubblico_token" uuid DEFAULT gen_random_uuid(),
  "token_pubblico" uuid DEFAULT gen_random_uuid()
);

CREATE TABLE IF NOT EXISTS public."questionari_compilazioni" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "questionario_id" uuid NOT NULL,
  "user_id" uuid,
  "inviato_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."questionari_domande" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "template_id" uuid NOT NULL,
  "ordine" integer NOT NULL,
  "testo" text NOT NULL,
  "tipo" "public"."questionario_tipo_domanda" NOT NULL,
  "obbligatoria" boolean DEFAULT false NOT NULL,
  "opzioni" jsonb,
  "created_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."questionari_risposte" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "compilazione_id" uuid NOT NULL,
  "domanda_id" uuid NOT NULL,
  "valore" jsonb
);

CREATE TABLE IF NOT EXISTS public."questionari_template" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "titolo" varchar NOT NULL,
  "descrizione" text,
  "destinatario" "public"."questionario_destinatario" NOT NULL,
  "versione" smallint DEFAULT 1 NOT NULL,
  "attivo" boolean DEFAULT true NOT NULL,
  "created_by" uuid,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL,
  "predefinito" boolean DEFAULT false NOT NULL
);

CREATE TABLE IF NOT EXISTS public."risorse_mentoring" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "titolo" varchar NOT NULL,
  "descrizione" text,
  "categoria" varchar NOT NULL,
  "anno_accademico" varchar,
  "storage_path" text NOT NULL,
  "nome_file" text NOT NULL,
  "dimensione_bytes" bigint,
  "ordine" integer DEFAULT 100 NOT NULL,
  "attivo" boolean DEFAULT true NOT NULL,
  "uploaded_by" uuid,
  "created_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."ssd" (
  "cod_ssd" varchar NOT NULL,
  "gsd" varchar NOT NULL,
  "area" varchar NOT NULL
);

CREATE TABLE IF NOT EXISTS public."user_roles" (
  "user_id" uuid NOT NULL,
  "role" "public"."app_role" DEFAULT 'participant'::app_role NOT NULL
);

