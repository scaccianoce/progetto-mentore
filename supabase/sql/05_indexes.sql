-- ============================================================================
-- 05 - INDICI NON GIA CREATI DAI CONSTRAINT
-- Generato da inventario read-only del progetto Supabase esistente.
-- NON eseguire sul progetto di produzione attuale.
-- Destinato esclusivamente a un NUOVO progetto Supabase vuoto.
-- ============================================================================

-- abilitazioni_modifica_pkey: creato automaticamente dal relativo constraint.
CREATE UNIQUE INDEX IF NOT EXISTS anagrafica_email_unipa_unique ON public.anagrafica USING btree (lower((email_unipa)::text));
CREATE UNIQUE INDEX IF NOT EXISTS anagrafica_email_unipa_unique_ci ON public.anagrafica USING btree (lower(TRIM(BOTH FROM email_unipa))) WHERE ((email_unipa IS NOT NULL) AND (TRIM(BOTH FROM email_unipa) <> ''::text));
-- anagrafica_pkey: creato automaticamente dal relativo constraint.
CREATE INDEX IF NOT EXISTS anagrafica_riservata_attivo_idx ON public.anagrafica_riservata USING btree (attivo);
CREATE INDEX IF NOT EXISTS anagrafica_riservata_notifiche_attivo_idx ON public.anagrafica_riservata USING btree (user_id, attivo);
-- anagrafica_riservata_pkey: creato automaticamente dal relativo constraint.
CREATE INDEX IF NOT EXISTS anagrafica_riservata_user_attivo_idx ON public.anagrafica_riservata USING btree (user_id, attivo);
-- anni_accademici_pkey: creato automaticamente dal relativo constraint.
CREATE UNIQUE INDEX IF NOT EXISTS anni_accademici_unica_preparazione ON public.anni_accademici USING btree (stato) WHERE (stato = 'preparazione'::text);
CREATE UNIQUE INDEX IF NOT EXISTS anni_accademici_unico_attivo ON public.anni_accademici USING btree (stato) WHERE (stato = 'attivo'::text);
CREATE UNIQUE INDEX IF NOT EXISTS un_solo_anno_accademico_corrente ON public.anni_accademici USING btree (corrente) WHERE (corrente = true);
-- eventi_pkey: creato automaticamente dal relativo constraint.
CREATE INDEX IF NOT EXISTS house_of_mentore_anno_idx ON public.house_of_mentore USING btree (anno_accademico);
CREATE INDEX IF NOT EXISTS house_of_mentore_data_idx ON public.house_of_mentore USING btree (data_evento);
-- house_of_mentore_pkey: creato automaticamente dal relativo constraint.
-- house_of_mentore_opzioni_id_evento_unique: creato automaticamente dal relativo constraint.
CREATE INDEX IF NOT EXISTS house_of_mentore_opzioni_ordine_idx ON public.house_of_mentore_opzioni USING btree (evento_id, ordine_visualizzazione);
-- house_of_mentore_opzioni_pkey: creato automaticamente dal relativo constraint.
-- import_insegnamenti_pkey: creato automaticamente dal relativo constraint.
-- import_partecipanti_pkey: creato automaticamente dal relativo constraint.
CREATE INDEX IF NOT EXISTS insegnamenti_docente_idx ON public.insegnamenti USING btree (docente_id);
-- insegnamenti_pkey: creato automaticamente dal relativo constraint.
CREATE INDEX IF NOT EXISTS mentoraggi_anno_accademico_idx ON public.mentoraggi USING btree (anno_accademico);
CREATE INDEX IF NOT EXISTS mentoraggi_anno_idx ON public.mentoraggi USING btree (anno_accademico);
CREATE UNIQUE INDEX IF NOT EXISTS mentoraggi_insegnamento_anno_unique ON public.mentoraggi USING btree (insegnamento_id, anno_accademico) WHERE (anno_accademico IS NOT NULL);
CREATE INDEX IF NOT EXISTS mentoraggi_insegnamento_idx ON public.mentoraggi USING btree (insegnamento_id);
-- mentoraggi_pkey: creato automaticamente dal relativo constraint.
CREATE INDEX IF NOT EXISTS mentoraggio_mentori_mentoraggio_idx ON public.mentoraggio_mentori USING btree (mentoraggio_id);
CREATE INDEX IF NOT EXISTS mentoraggio_mentori_mentore_idx ON public.mentoraggio_mentori USING btree (mentore_id);
-- mentoraggio_mentori_pkey: creato automaticamente dal relativo constraint.
CREATE UNIQUE INDEX IF NOT EXISTS mentoraggio_mentori_univoco ON public.mentoraggio_mentori USING btree (mentoraggio_id, mentore_id, tipo);
CREATE UNIQUE INDEX IF NOT EXISTS un_solo_mentore_senior ON public.mentoraggio_mentori USING btree (mentoraggio_id) WHERE (tipo = 'senior'::tipo_mentore);
-- news_pkey: creato automaticamente dal relativo constraint.
CREATE INDEX IF NOT EXISTS notifiche_destinatari_messaggio_idx ON public.notifiche_destinatari USING btree (messaggio_id);
-- notifiche_destinatari_pkey: creato automaticamente dal relativo constraint.
CREATE INDEX IF NOT EXISTS notifiche_destinatari_stato_idx ON public.notifiche_destinatari USING btree (stato);
-- notifiche_destinatari_unique: creato automaticamente dal relativo constraint.
CREATE INDEX IF NOT EXISTS notifiche_destinatari_user_idx ON public.notifiche_destinatari USING btree (user_id);
CREATE INDEX IF NOT EXISTS notifiche_dispositivi_attivo_idx ON public.notifiche_dispositivi USING btree (attivo);
-- notifiche_dispositivi_pkey: creato automaticamente dal relativo constraint.
-- notifiche_dispositivi_token_unique: creato automaticamente dal relativo constraint.
CREATE INDEX IF NOT EXISTS notifiche_dispositivi_user_idx ON public.notifiche_dispositivi USING btree (user_id);
CREATE INDEX IF NOT EXISTS notifiche_messaggi_anno_idx ON public.notifiche_messaggi USING btree (anno_accademico);
CREATE UNIQUE INDEX IF NOT EXISTS notifiche_messaggi_chiave_univoca_idx ON public.notifiche_messaggi USING btree (chiave_univoca) WHERE (chiave_univoca IS NOT NULL);
-- notifiche_messaggi_pkey: creato automaticamente dal relativo constraint.
CREATE INDEX IF NOT EXISTS notifiche_messaggi_programmata_idx ON public.notifiche_messaggi USING btree (programmata_per);
CREATE INDEX IF NOT EXISTS notifiche_messaggi_stato_idx ON public.notifiche_messaggi USING btree (stato);
CREATE INDEX IF NOT EXISTS notifiche_regole_attive_idx ON public.notifiche_regole USING btree (attiva, tipo_attivazione);
-- notifiche_regole_codice_key: creato automaticamente dal relativo constraint.
-- notifiche_regole_pkey: creato automaticamente dal relativo constraint.
CREATE INDEX IF NOT EXISTS notifiche_regole_tabella_idx ON public.notifiche_regole USING btree (tabella) WHERE (tabella IS NOT NULL);
CREATE INDEX IF NOT EXISTS partecipazioni_annuali_anno_stato_idx ON public.partecipazioni_annuali USING btree (anno_accademico, stato);
-- partecipazioni_annuali_pkey: creato automaticamente dal relativo constraint.
-- partecipazioni_eventi_pkey: creato automaticamente dal relativo constraint.
-- partecipazioni_house_of_mentore_pkey: creato automaticamente dal relativo constraint.
CREATE INDEX IF NOT EXISTS partecipazioni_house_opzione_idx ON public.partecipazioni_house_of_mentore USING btree (opzione_id);
CREATE INDEX IF NOT EXISTS partecipazioni_house_partecipante_idx ON public.partecipazioni_house_of_mentore USING btree (partecipante_id);
CREATE UNIQUE INDEX IF NOT EXISTS questionari_evento_interno_unique ON public.questionari USING btree (evento_id) WHERE (provider = 'interno'::questionario_provider);
CREATE INDEX IF NOT EXISTS questionari_mentoraggio_idx ON public.questionari USING btree (mentoraggio_id);
CREATE UNIQUE INDEX IF NOT EXISTS questionari_mentoraggio_pubblico_unique ON public.questionari USING btree (mentoraggio_id) WHERE (provider = 'pubblico'::questionario_provider);
-- questionari_pkey: creato automaticamente dal relativo constraint.
CREATE UNIQUE INDEX IF NOT EXISTS questionari_pubblico_mentoraggio_unique ON public.questionari USING btree (mentoraggio_id) WHERE ((provider = 'pubblico'::questionario_provider) AND (mentoraggio_id IS NOT NULL));
CREATE UNIQUE INDEX IF NOT EXISTS questionari_pubblico_token_unique ON public.questionari USING btree (pubblico_token) WHERE (pubblico_token IS NOT NULL);
CREATE INDEX IF NOT EXISTS questionari_template_idx ON public.questionari USING btree (template_id);
CREATE UNIQUE INDEX IF NOT EXISTS questionari_token_pubblico_unique ON public.questionari USING btree (token_pubblico) WHERE (token_pubblico IS NOT NULL);
CREATE UNIQUE INDEX IF NOT EXISTS questionari_compilazione_interna_unique ON public.questionari_compilazioni USING btree (questionario_id, user_id) WHERE (user_id IS NOT NULL);
-- questionari_compilazioni_pkey: creato automaticamente dal relativo constraint.
-- questionari_compilazioni_questionario_id_user_id_key: creato automaticamente dal relativo constraint.
CREATE INDEX IF NOT EXISTS questionari_compilazioni_questionario_idx ON public.questionari_compilazioni USING btree (questionario_id);
-- questionari_domande_pkey: creato automaticamente dal relativo constraint.
-- questionari_domande_template_id_ordine_key: creato automaticamente dal relativo constraint.
CREATE INDEX IF NOT EXISTS questionari_domande_template_idx ON public.questionari_domande USING btree (template_id, ordine);
-- questionari_risposte_compilazione_id_domanda_id_key: creato automaticamente dal relativo constraint.
-- questionari_risposte_pkey: creato automaticamente dal relativo constraint.
CREATE UNIQUE INDEX IF NOT EXISTS questionari_template_default_unique ON public.questionari_template USING btree (destinatario) WHERE ((predefinito = true) AND (attivo = true));
CREATE INDEX IF NOT EXISTS questionari_template_destinatario_idx ON public.questionari_template USING btree (destinatario);
-- questionari_template_pkey: creato automaticamente dal relativo constraint.
-- risorse_mentoring_pkey: creato automaticamente dal relativo constraint.
-- risorse_mentoring_storage_path_key: creato automaticamente dal relativo constraint.
-- ssd_pkey: creato automaticamente dal relativo constraint.
-- user_roles_pkey: creato automaticamente dal relativo constraint.
