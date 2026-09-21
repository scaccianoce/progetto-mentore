-- ============================================================================
-- 11 - GRANT FUNZIONI
-- Generato da inventario read-only del progetto Supabase esistente.
-- NON eseguire sul progetto di produzione attuale.
-- Destinato esclusivamente a un NUOVO progetto Supabase vuoto.
-- ============================================================================

revoke execute on all functions in schema public from public, anon;

REVOKE ALL PRIVILEGES ON FUNCTION public."abilitazione_modifica_imposta"(p_user_id uuid, p_ambito ambito_modifica, p_anno_accademico text, p_abilitata boolean, p_scade_at timestamp with time zone) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."abilitazione_modifica_imposta"(p_user_id uuid, p_ambito ambito_modifica, p_anno_accademico text, p_abilitata boolean, p_scade_at timestamp with time zone) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."abilitazione_modifica_imposta"(p_user_id uuid, p_ambito ambito_modifica, p_anno_accademico text, p_abilitata boolean, p_scade_at timestamp with time zone) FROM service_role;
GRANT EXECUTE ON FUNCTION public."abilitazione_modifica_imposta"(p_user_id uuid, p_ambito ambito_modifica, p_anno_accademico text, p_abilitata boolean, p_scade_at timestamp with time zone) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."anagrafica_e_attiva"(p_user_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."anagrafica_e_attiva"(p_user_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."anno_accademico_attivo"() FROM authenticated;
GRANT EXECUTE ON FUNCTION public."anno_accademico_attivo"() TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."anno_accademico_attivo"() FROM service_role;
GRANT EXECUTE ON FUNCTION public."anno_accademico_attivo"() TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."anno_accademico_corrente"() FROM authenticated;
GRANT EXECUTE ON FUNCTION public."anno_accademico_corrente"() TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."anno_accademico_corrente"() FROM service_role;
GRANT EXECUTE ON FUNCTION public."anno_accademico_corrente"() TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."anno_accademico_gestione_insegnamenti"() FROM authenticated;
GRANT EXECUTE ON FUNCTION public."anno_accademico_gestione_insegnamenti"() TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."anno_accademico_gestione_insegnamenti"() FROM service_role;
GRANT EXECUTE ON FUNCTION public."anno_accademico_gestione_insegnamenti"() TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."anno_accademico_preparazione"() FROM authenticated;
GRANT EXECUTE ON FUNCTION public."anno_accademico_preparazione"() TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."anno_accademico_preparazione"() FROM service_role;
GRANT EXECUTE ON FUNCTION public."anno_accademico_preparazione"() TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."app_backoffice_admin"(p_user_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."app_backoffice_admin"(p_user_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."app_backoffice_admin"(p_user_id uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public."app_backoffice_admin"(p_user_id uuid) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."app_database_schema"() FROM authenticated;
GRANT EXECUTE ON FUNCTION public."app_database_schema"() TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."app_owner"(p_user_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."app_owner"(p_user_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."app_owner"(p_user_id uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public."app_owner"(p_user_id uuid) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."has_role"(allowed_roles app_role[]) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."has_role"(allowed_roles app_role[]) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."imposta_anno_accademico_corrente"(p_codice character varying) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."imposta_anno_accademico_corrente"(p_codice character varying) TO authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public."imposta_anno_accademico_corrente"(p_codice text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."imposta_anno_accademico_corrente"(p_codice text) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."imposta_anno_accademico_corrente"(p_codice character varying) FROM service_role;
GRANT EXECUTE ON FUNCTION public."imposta_anno_accademico_corrente"(p_codice character varying) TO service_role;
REVOKE ALL PRIVILEGES ON FUNCTION public."imposta_anno_accademico_corrente"(p_codice text) FROM service_role;
GRANT EXECUTE ON FUNCTION public."imposta_anno_accademico_corrente"(p_codice text) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."imposta_stato_anno_accademico"(p_codice text, p_stato text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."imposta_stato_anno_accademico"(p_codice text, p_stato text) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."imposta_stato_anno_accademico"(p_codice text, p_stato text) FROM service_role;
GRANT EXECUTE ON FUNCTION public."imposta_stato_anno_accademico"(p_codice text, p_stato text) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."insegnamenti_miei"() FROM authenticated;
GRANT EXECUTE ON FUNCTION public."insegnamenti_miei"() TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."insegnamenti_miei"() FROM service_role;
GRANT EXECUTE ON FUNCTION public."insegnamenti_miei"() TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."insegnamento_crea_per_anno"(p_valori jsonb, p_anno_accademico text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."insegnamento_crea_per_anno"(p_valori jsonb, p_anno_accademico text) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."insegnamento_crea_per_anno"(p_valori jsonb, p_anno_accademico text) FROM service_role;
GRANT EXECUTE ON FUNCTION public."insegnamento_crea_per_anno"(p_valori jsonb, p_anno_accademico text) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."insegnamento_modifica_autorizzata"(p_insegnamento_id uuid, p_valori jsonb, p_anno_accademico text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."insegnamento_modifica_autorizzata"(p_insegnamento_id uuid, p_valori jsonb, p_anno_accademico text) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."insegnamento_modifica_autorizzata"(p_insegnamento_id uuid, p_valori jsonb, p_anno_accademico text) FROM service_role;
GRANT EXECUTE ON FUNCTION public."insegnamento_modifica_autorizzata"(p_insegnamento_id uuid, p_valori jsonb, p_anno_accademico text) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."insegnamento_seleziona_per_anno"(p_insegnamento_id uuid, p_anno_accademico text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."insegnamento_seleziona_per_anno"(p_insegnamento_id uuid, p_anno_accademico text) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."insegnamento_seleziona_per_anno"(p_insegnamento_id uuid, p_anno_accademico text) FROM service_role;
GRANT EXECUTE ON FUNCTION public."insegnamento_seleziona_per_anno"(p_insegnamento_id uuid, p_anno_accademico text) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."insegnamento_stato_annuale"(p_anno_accademico text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."insegnamento_stato_annuale"(p_anno_accademico text) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."insegnamento_stato_annuale"(p_anno_accademico text) FROM service_role;
GRANT EXECUTE ON FUNCTION public."insegnamento_stato_annuale"(p_anno_accademico text) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."is_docente_del_mentoraggio"(p_mentoraggio_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."is_docente_del_mentoraggio"(p_mentoraggio_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."is_mentore_assegnato"(p_mentoraggio_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."is_mentore_assegnato"(p_mentoraggio_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."is_mentore_di_insegnamento"(p_insegnamento_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."is_mentore_di_insegnamento"(p_insegnamento_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."mentoraggi_del_mentee"() FROM authenticated;
GRANT EXECUTE ON FUNCTION public."mentoraggi_del_mentee"() TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."mentoraggi_del_mentore"() FROM authenticated;
GRANT EXECUTE ON FUNCTION public."mentoraggi_del_mentore"() TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."mentoraggio_aggiorna_backoffice"(p_mentoraggio_id uuid, p_valori jsonb) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."mentoraggio_aggiorna_backoffice"(p_mentoraggio_id uuid, p_valori jsonb) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."mentoraggio_aggiorna_mentee"(p_mentoraggio_id uuid, p_valori jsonb) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."mentoraggio_aggiorna_mentee"(p_mentoraggio_id uuid, p_valori jsonb) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."mentoraggio_aggiorna_mentore"(p_mentoraggio_id uuid, p_valori jsonb) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."mentoraggio_aggiorna_mentore"(p_mentoraggio_id uuid, p_valori jsonb) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."mentoraggio_anno_corrente"(p_mentoraggio_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."mentoraggio_anno_corrente"(p_mentoraggio_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."mentoraggio_anno_corrente"(p_mentoraggio_id uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public."mentoraggio_anno_corrente"(p_mentoraggio_id uuid) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."mentoraggio_backoffice"() FROM authenticated;
GRANT EXECUTE ON FUNCTION public."mentoraggio_backoffice"() TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."mentoraggio_backoffice"() FROM service_role;
GRANT EXECUTE ON FUNCTION public."mentoraggio_backoffice"() TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."mentoraggio_scheda_sintesi_imposta"(p_mentoraggio_id uuid, p_storage_path text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."mentoraggio_scheda_sintesi_imposta"(p_mentoraggio_id uuid, p_storage_path text) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."mentoraggio_utente_associato"(p_mentoraggio_id uuid, p_user_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."mentoraggio_utente_associato"(p_mentoraggio_id uuid, p_user_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."mentoraggio_utente_associato"(p_mentoraggio_id uuid, p_user_id uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public."mentoraggio_utente_associato"(p_mentoraggio_id uuid, p_user_id uuid) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."mentoraggio_utente_mentee"(p_mentoraggio_id uuid, p_user_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."mentoraggio_utente_mentee"(p_mentoraggio_id uuid, p_user_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."mentoraggio_utente_mentee"(p_mentoraggio_id uuid, p_user_id uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public."mentoraggio_utente_mentee"(p_mentoraggio_id uuid, p_user_id uuid) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_amministratore"() FROM authenticated;
GRANT EXECUTE ON FUNCTION public."notifiche_amministratore"() TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_anno_corrente"() FROM authenticated;
GRANT EXECUTE ON FUNCTION public."notifiche_anno_corrente"() TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_anno_corrente"() FROM service_role;
GRANT EXECUTE ON FUNCTION public."notifiche_anno_corrente"() TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_condizione_relazionale_ok"(p_tabella_principale text, p_record jsonb, p_condizione jsonb, p_campo_id_principale text) FROM service_role;
GRANT EXECUTE ON FUNCTION public."notifiche_condizione_relazionale_ok"(p_tabella_principale text, p_record jsonb, p_condizione jsonb, p_campo_id_principale text) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_condizioni_regola_ok"(p_tabella_principale text, p_record jsonb, p_configurazione jsonb) FROM service_role;
GRANT EXECUTE ON FUNCTION public."notifiche_condizioni_regola_ok"(p_tabella_principale text, p_record jsonb, p_configurazione jsonb) TO service_role;

-- REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_conta_destinatari"(p_messaggio_id uuid) FROM authenticated;
-- GRANT EXECUTE ON FUNCTION public."notifiche_conta_destinatari"(p_messaggio_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_crea_messaggio_da_regola"(p_regola_id uuid, p_record jsonb, p_evento text, p_data_riferimento timestamp with time zone) FROM service_role;
GRANT EXECUTE ON FUNCTION public."notifiche_crea_messaggio_da_regola"(p_regola_id uuid, p_record jsonb, p_evento text, p_data_riferimento timestamp with time zone) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_dettaglio_destinatari"(p_messaggio_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."notifiche_dettaglio_destinatari"(p_messaggio_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_disattiva_dispositivo"(p_token text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."notifiche_disattiva_dispositivo"(p_token text) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_disattiva_dispositivo"(p_token text) FROM service_role;
GRANT EXECUTE ON FUNCTION public."notifiche_disattiva_dispositivo"(p_token text) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_elenco_utenti_attivi"() FROM authenticated;
GRANT EXECUTE ON FUNCTION public."notifiche_elenco_utenti_attivi"() TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_elenco_utenti_attivi"() FROM service_role;
GRANT EXECUTE ON FUNCTION public."notifiche_elenco_utenti_attivi"() TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_genera_destinatari"(p_messaggio_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."notifiche_genera_destinatari"(p_messaggio_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_genera_destinatari"(p_messaggio_id uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public."notifiche_genera_destinatari"(p_messaggio_id uuid) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_inserisci_destinatari_relazionali"(p_messaggio_id uuid, p_configurazione jsonb) FROM service_role;
GRANT EXECUTE ON FUNCTION public."notifiche_inserisci_destinatari_relazionali"(p_messaggio_id uuid, p_configurazione jsonb) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_materializza_regole_temporali"() FROM authenticated;
GRANT EXECUTE ON FUNCTION public."notifiche_materializza_regole_temporali"() TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_materializza_regole_temporali"() FROM service_role;
GRANT EXECUTE ON FUNCTION public."notifiche_materializza_regole_temporali"() TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_registra_dispositivo"(p_token text, p_piattaforma text, p_device_id text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."notifiche_registra_dispositivo"(p_token text, p_piattaforma text, p_device_id text) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_registra_dispositivo"(p_token text, p_piattaforma text, p_device_id text) FROM service_role;
GRANT EXECUTE ON FUNCTION public."notifiche_registra_dispositivo"(p_token text, p_piattaforma text, p_device_id text) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_segna_letta"(p_destinatario_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."notifiche_segna_letta"(p_destinatario_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_segna_letta"(p_destinatario_id uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public."notifiche_segna_letta"(p_destinatario_id uuid) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_utente_amministratore"() FROM authenticated;
GRANT EXECUTE ON FUNCTION public."notifiche_utente_amministratore"() TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_utente_attivo"(p_user_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."notifiche_utente_attivo"(p_user_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."notifiche_utente_attivo"(p_user_id uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public."notifiche_utente_attivo"(p_user_id uuid) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."partecipazione_annuale_imposta"(p_user_id uuid, p_anno_accademico text, p_stato text, p_note text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."partecipazione_annuale_imposta"(p_user_id uuid, p_anno_accademico text, p_stato text, p_note text) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."partecipazione_annuale_imposta"(p_user_id uuid, p_anno_accademico text, p_stato text, p_note text) FROM service_role;
GRANT EXECUTE ON FUNCTION public."partecipazione_annuale_imposta"(p_user_id uuid, p_anno_accademico text, p_stato text, p_note text) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."partecipazione_annuale_rispondi"(p_partecipa boolean, p_anno_accademico text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."partecipazione_annuale_rispondi"(p_partecipa boolean, p_anno_accademico text) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."partecipazione_annuale_rispondi"(p_partecipa boolean, p_anno_accademico text) FROM service_role;
GRANT EXECUTE ON FUNCTION public."partecipazione_annuale_rispondi"(p_partecipa boolean, p_anno_accademico text) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."partecipazione_annuale_stato"(p_anno_accademico text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."partecipazione_annuale_stato"(p_anno_accademico text) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."partecipazione_annuale_stato"(p_anno_accademico text) FROM service_role;
GRANT EXECUTE ON FUNCTION public."partecipazione_annuale_stato"(p_anno_accademico text) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."partecipazioni_annuali_genera"(p_anno_destinazione text, p_anno_sorgente text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."partecipazioni_annuali_genera"(p_anno_destinazione text, p_anno_sorgente text) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."partecipazioni_annuali_proprie"() FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public."partecipazioni_annuali_proprie"() TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."partecipazioni_annuali_genera"(p_anno_destinazione text, p_anno_sorgente text) FROM service_role;
GRANT EXECUTE ON FUNCTION public."partecipazioni_annuali_genera"(p_anno_destinazione text, p_anno_sorgente text) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."puo_modificare"(p_ambito ambito_modifica, p_anno_accademico character varying) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."puo_modificare"(p_ambito ambito_modifica, p_anno_accademico character varying) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."puo_modificare_corrente"(p_ambito ambito_modifica) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."puo_modificare_corrente"(p_ambito ambito_modifica) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."questionario_mentoraggio_link_imposta"(p_mentoraggio_id uuid, p_url text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."questionario_mentoraggio_link_imposta"(p_mentoraggio_id uuid, p_url text) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."questionario_pubblico_carica"(p_token uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public."questionario_pubblico_carica"(p_token uuid) TO anon;

REVOKE ALL PRIVILEGES ON FUNCTION public."questionario_pubblico_carica"(p_token uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."questionario_pubblico_carica"(p_token uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."questionario_pubblico_invia"(p_token uuid, p_risposte jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."questionario_pubblico_invia"(p_token uuid, p_risposte jsonb) TO anon;

REVOKE ALL PRIVILEGES ON FUNCTION public."questionario_pubblico_invia"(p_token uuid, p_risposte jsonb) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."questionario_pubblico_invia"(p_token uuid, p_risposte jsonb) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."questionario_pubblico_leggi"(p_token uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public."questionario_pubblico_leggi"(p_token uuid) TO anon;

REVOKE ALL PRIVILEGES ON FUNCTION public."questionario_pubblico_leggi"(p_token uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."questionario_pubblico_leggi"(p_token uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."questionario_pubblico_leggi"(p_token uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public."questionario_pubblico_leggi"(p_token uuid) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."questionario_risultati_mentoraggio"(p_mentoraggio_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."questionario_risultati_mentoraggio"(p_mentoraggio_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."questionario_sintesi_mentoraggio"(p_mentoraggio_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."questionario_sintesi_mentoraggio"(p_mentoraggio_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."richiedi_abilitazione"(p_ambito ambito_modifica) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."richiedi_abilitazione"(p_ambito ambito_modifica) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."utente_ha_abilitazione"(p_ambito ambito_modifica, p_anno_accademico text, p_user_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."utente_ha_abilitazione"(p_ambito ambito_modifica, p_anno_accademico text, p_user_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."utente_ha_abilitazione"(p_ambito ambito_modifica, p_anno_accademico text, p_user_id uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public."utente_ha_abilitazione"(p_ambito ambito_modifica, p_anno_accademico text, p_user_id uuid) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public."utente_owner_organizer"(p_user_id uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public."utente_owner_organizer"(p_user_id uuid) TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public."utente_owner_organizer"(p_user_id uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public."utente_owner_organizer"(p_user_id uuid) TO service_role;
