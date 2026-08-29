-- ============================================================================
-- 10 - GRANT TABELLE E VIEWS
-- Generato da inventario read-only del progetto Supabase esistente.
-- NON eseguire sul progetto di produzione attuale.
-- Destinato esclusivamente a un NUOVO progetto Supabase vuoto.
-- ============================================================================

REVOKE ALL PRIVILEGES ON TABLE "public"."abilitazioni_modifica" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."abilitazioni_modifica" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."abilitazioni_modifica" FROM authenticated;
GRANT REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."abilitazioni_modifica" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."abilitazioni_modifica" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."abilitazioni_modifica" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."anagrafica" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."anagrafica" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."anagrafica" FROM authenticated;
GRANT INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."anagrafica" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."anagrafica" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."anagrafica" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."anagrafica_riservata" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."anagrafica_riservata" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."anagrafica_riservata" FROM authenticated;
GRANT INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."anagrafica_riservata" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."anagrafica_riservata" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."anagrafica_riservata" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."anni_accademici" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."anni_accademici" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."anni_accademici" FROM authenticated;
GRANT REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."anni_accademici" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."anni_accademici" FROM service_role;
GRANT REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."anni_accademici" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."eventi" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."eventi" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."eventi" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."eventi" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."eventi" FROM service_role;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."eventi" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."house_of_mentore" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."house_of_mentore" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."house_of_mentore" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."house_of_mentore" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."house_of_mentore" FROM service_role;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."house_of_mentore" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."house_of_mentore_opzioni" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."house_of_mentore_opzioni" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."house_of_mentore_opzioni" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."house_of_mentore_opzioni" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."house_of_mentore_opzioni" FROM service_role;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."house_of_mentore_opzioni" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."import_insegnamenti" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."import_insegnamenti" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."import_insegnamenti" FROM authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."import_insegnamenti" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."import_insegnamenti" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."import_insegnamenti" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."import_partecipanti" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."import_partecipanti" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."import_partecipanti" FROM authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."import_partecipanti" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."import_partecipanti" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."import_partecipanti" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."insegnamenti" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."insegnamenti" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."insegnamenti" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."insegnamenti" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."insegnamenti" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."insegnamenti" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."mentoraggi" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."mentoraggi" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."mentoraggi" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."mentoraggi" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."mentoraggi" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."mentoraggi" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."mentoraggio_mentori" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."mentoraggio_mentori" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."mentoraggio_mentori" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."mentoraggio_mentori" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."mentoraggio_mentori" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."mentoraggio_mentori" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."news" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."news" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."news" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."news" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."news" FROM service_role;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."news" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."notifiche_destinatari" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."notifiche_destinatari" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."notifiche_destinatari" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."notifiche_destinatari" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."notifiche_destinatari" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."notifiche_destinatari" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."notifiche_dispositivi" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."notifiche_dispositivi" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."notifiche_dispositivi" FROM authenticated;
GRANT REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."notifiche_dispositivi" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."notifiche_dispositivi" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."notifiche_dispositivi" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."notifiche_messaggi" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."notifiche_messaggi" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."notifiche_messaggi" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."notifiche_messaggi" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."notifiche_messaggi" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."notifiche_messaggi" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."notifiche_regole" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."notifiche_regole" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."notifiche_regole" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."notifiche_regole" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."notifiche_regole" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."notifiche_regole" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."notifiche_utenti_attivi" FROM service_role;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."notifiche_utenti_attivi" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."partecipazioni_annuali" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."partecipazioni_annuali" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."partecipazioni_annuali" FROM authenticated;
GRANT REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."partecipazioni_annuali" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."partecipazioni_annuali" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."partecipazioni_annuali" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."partecipazioni_eventi" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."partecipazioni_eventi" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."partecipazioni_eventi" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."partecipazioni_eventi" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."partecipazioni_eventi" FROM service_role;
GRANT REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."partecipazioni_eventi" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."partecipazioni_house_of_mentore" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."partecipazioni_house_of_mentore" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."partecipazioni_house_of_mentore" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."partecipazioni_house_of_mentore" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."partecipazioni_house_of_mentore" FROM service_role;
GRANT REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."partecipazioni_house_of_mentore" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."questionari" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."questionari" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."questionari" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."questionari" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."questionari" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."questionari" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."questionari_compilazioni" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."questionari_compilazioni" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."questionari_compilazioni" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."questionari_compilazioni" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."questionari_compilazioni" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."questionari_compilazioni" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."questionari_domande" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."questionari_domande" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."questionari_domande" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."questionari_domande" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."questionari_domande" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."questionari_domande" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."questionari_risposte" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."questionari_risposte" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."questionari_risposte" FROM authenticated;
GRANT INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."questionari_risposte" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."questionari_risposte" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."questionari_risposte" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."questionari_template" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."questionari_template" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."questionari_template" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."questionari_template" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."questionari_template" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."questionari_template" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."risorse_mentoring" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."risorse_mentoring" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."risorse_mentoring" FROM authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."risorse_mentoring" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."risorse_mentoring" FROM service_role;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."risorse_mentoring" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."ssd" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."ssd" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."ssd" FROM authenticated;
GRANT REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."ssd" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."ssd" FROM service_role;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."ssd" TO service_role;

REVOKE ALL PRIVILEGES ON TABLE "public"."user_roles" FROM anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."user_roles" TO anon;

REVOKE ALL PRIVILEGES ON TABLE "public"."user_roles" FROM authenticated;
GRANT REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."user_roles" TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE "public"."user_roles" FROM service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."user_roles" TO service_role;

