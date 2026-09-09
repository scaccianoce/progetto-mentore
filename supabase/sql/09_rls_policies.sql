-- ============================================================================
-- 09 - RLS E POLICIES
-- Generato da inventario read-only del progetto Supabase esistente.
-- NON eseguire sul progetto di produzione attuale.
-- Destinato esclusivamente a un NUOVO progetto Supabase vuoto.
-- ============================================================================

ALTER TABLE public."abilitazioni_modifica" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."abilitazioni_modifica" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."anagrafica" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."anagrafica" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."anagrafica_riservata" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."anagrafica_riservata" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."anni_accademici" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."anni_accademici" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."eventi" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."eventi" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."house_of_mentore" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."house_of_mentore" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."house_of_mentore_opzioni" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."house_of_mentore_opzioni" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."import_insegnamenti" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."import_insegnamenti" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."import_partecipanti" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."import_partecipanti" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."insegnamenti" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."insegnamenti" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."mentoraggi" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."mentoraggi" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."mentoraggio_mentori" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."mentoraggio_mentori" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."news" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."news" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."notifiche_destinatari" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."notifiche_destinatari" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."notifiche_dispositivi" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."notifiche_dispositivi" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."notifiche_messaggi" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."notifiche_messaggi" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."notifiche_regole" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."notifiche_regole" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."partecipazioni_annuali" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."partecipazioni_annuali" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."partecipazioni_eventi" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."partecipazioni_eventi" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."partecipazioni_house_of_mentore" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."partecipazioni_house_of_mentore" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."questionari" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."questionari" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."questionari_compilazioni" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."questionari_compilazioni" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."questionari_domande" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."questionari_domande" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."questionari_risposte" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."questionari_risposte" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."questionari_template" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."questionari_template" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."risorse_mentoring" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."risorse_mentoring" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."ssd" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."ssd" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."user_roles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."user_roles" NO FORCE ROW LEVEL SECURITY;

-- Policies public + storage

DROP POLICY IF EXISTS "Owner and organizer update authorizations" ON "public"."abilitazioni_modifica";
CREATE POLICY "Owner and organizer update authorizations" ON "public"."abilitazioni_modifica" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]))
  WITH CHECK (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]));

DROP POLICY IF EXISTS "Users read own authorizations" ON "public"."abilitazioni_modifica";
CREATE POLICY "Users read own authorizations" ON "public"."abilitazioni_modifica" AS PERMISSIVE FOR SELECT TO authenticated
  USING (((user_id = ( SELECT auth.uid() AS uid)) OR has_role(ARRAY['owner'::app_role, 'organizer'::app_role])));

DROP POLICY IF EXISTS "abilitazioni_modifica_backoffice_select" ON "public"."abilitazioni_modifica";
CREATE POLICY "abilitazioni_modifica_backoffice_select" ON "public"."abilitazioni_modifica" AS PERMISSIVE FOR SELECT TO authenticated
  USING (app_backoffice_admin());

DROP POLICY IF EXISTS "Owner and organizer create anagrafica" ON "public"."anagrafica";
CREATE POLICY "Owner and organizer create anagrafica" ON "public"."anagrafica" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]));

DROP POLICY IF EXISTS "Owner and organizer update all anagrafica" ON "public"."anagrafica";
CREATE POLICY "Owner and organizer update all anagrafica" ON "public"."anagrafica" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]))
  WITH CHECK (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]));

DROP POLICY IF EXISTS "Read active anagrafica or manage all" ON "public"."anagrafica";
CREATE POLICY "Read active anagrafica or manage all" ON "public"."anagrafica" AS PERMISSIVE FOR SELECT TO authenticated
  USING ((anagrafica_e_attiva(user_id) OR has_role(ARRAY['owner'::app_role, 'organizer'::app_role])));

DROP POLICY IF EXISTS "Users update own profile when authorized" ON "public"."anagrafica";
CREATE POLICY "Users update own profile when authorized" ON "public"."anagrafica" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((user_id = ( SELECT auth.uid() AS uid)) AND puo_modificare_corrente('anagrafica'::ambito_modifica)))
  WITH CHECK (((user_id = ( SELECT auth.uid() AS uid)) AND puo_modificare_corrente('anagrafica'::ambito_modifica)));

DROP POLICY IF EXISTS "anagrafica_backoffice_insert" ON "public"."anagrafica";
CREATE POLICY "anagrafica_backoffice_insert" ON "public"."anagrafica" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (app_backoffice_admin());

DROP POLICY IF EXISTS "anagrafica_backoffice_select" ON "public"."anagrafica";
CREATE POLICY "anagrafica_backoffice_select" ON "public"."anagrafica" AS PERMISSIVE FOR SELECT TO authenticated
  USING (app_backoffice_admin());

DROP POLICY IF EXISTS "anagrafica_backoffice_update" ON "public"."anagrafica";
CREATE POLICY "anagrafica_backoffice_update" ON "public"."anagrafica" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (app_backoffice_admin())
  WITH CHECK (app_backoffice_admin());

DROP POLICY IF EXISTS "Owner and organizer insert reserved data" ON "public"."anagrafica_riservata";
CREATE POLICY "Owner and organizer insert reserved data" ON "public"."anagrafica_riservata" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]));

DROP POLICY IF EXISTS "Owner and organizer read reserved data" ON "public"."anagrafica_riservata";
CREATE POLICY "Owner and organizer read reserved data" ON "public"."anagrafica_riservata" AS PERMISSIVE FOR SELECT TO authenticated
  USING (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]));

DROP POLICY IF EXISTS "Owner and organizer update reserved data" ON "public"."anagrafica_riservata";
CREATE POLICY "Owner and organizer update reserved data" ON "public"."anagrafica_riservata" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]))
  WITH CHECK (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]));

DROP POLICY IF EXISTS "anagrafica_riservata_backoffice_insert" ON "public"."anagrafica_riservata";
CREATE POLICY "anagrafica_riservata_backoffice_insert" ON "public"."anagrafica_riservata" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (app_backoffice_admin());

DROP POLICY IF EXISTS "anagrafica_riservata_backoffice_select" ON "public"."anagrafica_riservata";
CREATE POLICY "anagrafica_riservata_backoffice_select" ON "public"."anagrafica_riservata" AS PERMISSIVE FOR SELECT TO authenticated
  USING (app_backoffice_admin());

DROP POLICY IF EXISTS "anagrafica_riservata_backoffice_update" ON "public"."anagrafica_riservata";
CREATE POLICY "anagrafica_riservata_backoffice_update" ON "public"."anagrafica_riservata" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (app_backoffice_admin())
  WITH CHECK (app_backoffice_admin());

DROP POLICY IF EXISTS "Authenticated users read academic years" ON "public"."anni_accademici";
CREATE POLICY "Authenticated users read academic years" ON "public"."anni_accademici" AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Owner manages academic years" ON "public"."anni_accademici";
CREATE POLICY "Owner manages academic years" ON "public"."anni_accademici" AS PERMISSIVE FOR ALL TO authenticated
  USING (has_role(ARRAY['owner'::app_role]))
  WITH CHECK (has_role(ARRAY['owner'::app_role]));

DROP POLICY IF EXISTS "authenticated can read anni_accademici" ON "public"."anni_accademici";
CREATE POLICY "authenticated can read anni_accademici" ON "public"."anni_accademici" AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Authenticated users read events" ON "public"."eventi";
CREATE POLICY "Authenticated users read events" ON "public"."eventi" AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Owner and organizer manage events" ON "public"."eventi";
CREATE POLICY "Owner and organizer manage events" ON "public"."eventi" AS PERMISSIVE FOR ALL TO authenticated
  USING (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]))
  WITH CHECK (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]));

DROP POLICY IF EXISTS "eventi_backoffice_delete" ON "public"."eventi";
CREATE POLICY "eventi_backoffice_delete" ON "public"."eventi" AS PERMISSIVE FOR DELETE TO authenticated
  USING (app_backoffice_admin());

DROP POLICY IF EXISTS "Authenticated users read House of Mentore" ON "public"."house_of_mentore";
CREATE POLICY "Authenticated users read House of Mentore" ON "public"."house_of_mentore" AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Owner and organizer manage House of Mentore" ON "public"."house_of_mentore";
CREATE POLICY "Owner and organizer manage House of Mentore" ON "public"."house_of_mentore" AS PERMISSIVE FOR ALL TO authenticated
  USING (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]))
  WITH CHECK (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]));

DROP POLICY IF EXISTS "Authenticated users read House options" ON "public"."house_of_mentore_opzioni";
CREATE POLICY "Authenticated users read House options" ON "public"."house_of_mentore_opzioni" AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Owner and organizer manage House options" ON "public"."house_of_mentore_opzioni";
CREATE POLICY "Owner and organizer manage House options" ON "public"."house_of_mentore_opzioni" AS PERMISSIVE FOR ALL TO authenticated
  USING (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]))
  WITH CHECK (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]));

DROP POLICY IF EXISTS "Assigned mentors read teaching" ON "public"."insegnamenti";
CREATE POLICY "Assigned mentors read teaching" ON "public"."insegnamenti" AS PERMISSIVE FOR SELECT TO authenticated
  USING (is_mentore_di_insegnamento(id));

DROP POLICY IF EXISTS "Owner and organizer manage teachings" ON "public"."insegnamenti";
CREATE POLICY "Owner and organizer manage teachings" ON "public"."insegnamenti" AS PERMISSIVE FOR ALL TO authenticated
  USING (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]))
  WITH CHECK (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]));

DROP POLICY IF EXISTS "Users create own teaching" ON "public"."insegnamenti";
CREATE POLICY "Users create own teaching" ON "public"."insegnamenti" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((docente_id = auth.uid()));

DROP POLICY IF EXISTS "Users read own teaching" ON "public"."insegnamenti";
CREATE POLICY "Users read own teaching" ON "public"."insegnamenti" AS PERMISSIVE FOR SELECT TO authenticated
  USING (((docente_id = ( SELECT auth.uid() AS uid)) OR has_role(ARRAY['owner'::app_role, 'organizer'::app_role])));

DROP POLICY IF EXISTS "Users update own teaching" ON "public"."insegnamenti";
CREATE POLICY "Users update own teaching" ON "public"."insegnamenti" AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((docente_id = auth.uid()))
  WITH CHECK ((docente_id = auth.uid()));

DROP POLICY IF EXISTS "insegnamenti_backoffice_delete" ON "public"."insegnamenti";
CREATE POLICY "insegnamenti_backoffice_delete" ON "public"."insegnamenti" AS PERMISSIVE FOR DELETE TO authenticated
  USING (app_backoffice_admin());

DROP POLICY IF EXISTS "insegnamenti_backoffice_insert" ON "public"."insegnamenti";
CREATE POLICY "insegnamenti_backoffice_insert" ON "public"."insegnamenti" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (app_backoffice_admin());

DROP POLICY IF EXISTS "insegnamenti_backoffice_select" ON "public"."insegnamenti";
CREATE POLICY "insegnamenti_backoffice_select" ON "public"."insegnamenti" AS PERMISSIVE FOR SELECT TO authenticated
  USING (app_backoffice_admin());

DROP POLICY IF EXISTS "insegnamenti_backoffice_update" ON "public"."insegnamenti";
CREATE POLICY "insegnamenti_backoffice_update" ON "public"."insegnamenti" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (app_backoffice_admin())
  WITH CHECK (app_backoffice_admin());

DROP POLICY IF EXISTS "mentoraggi_backoffice_delete" ON "public"."mentoraggi";
CREATE POLICY "mentoraggi_backoffice_delete" ON "public"."mentoraggi" AS PERMISSIVE FOR DELETE TO authenticated
  USING (app_backoffice_admin());

DROP POLICY IF EXISTS "mentoraggi_backoffice_insert" ON "public"."mentoraggi";
CREATE POLICY "mentoraggi_backoffice_insert" ON "public"."mentoraggi" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (app_backoffice_admin());

DROP POLICY IF EXISTS "mentoraggi_backoffice_select" ON "public"."mentoraggi";
CREATE POLICY "mentoraggi_backoffice_select" ON "public"."mentoraggi" AS PERMISSIVE FOR SELECT TO authenticated
  USING (app_backoffice_admin());

DROP POLICY IF EXISTS "mentoraggi_backoffice_update" ON "public"."mentoraggi";
CREATE POLICY "mentoraggi_backoffice_update" ON "public"."mentoraggi" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (app_backoffice_admin())
  WITH CHECK (app_backoffice_admin());

DROP POLICY IF EXISTS "mentoraggi_delete_backoffice" ON "public"."mentoraggi";
CREATE POLICY "mentoraggi_delete_backoffice" ON "public"."mentoraggi" AS PERMISSIVE FOR DELETE TO authenticated
  USING (mentoraggio_backoffice());

DROP POLICY IF EXISTS "mentoraggi_insert_backoffice" ON "public"."mentoraggi";
CREATE POLICY "mentoraggi_insert_backoffice" ON "public"."mentoraggi" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (mentoraggio_backoffice());

DROP POLICY IF EXISTS "mentoraggi_select_team_backoffice" ON "public"."mentoraggi";
CREATE POLICY "mentoraggi_select_team_backoffice" ON "public"."mentoraggi" AS PERMISSIVE FOR SELECT TO authenticated
  USING ((mentoraggio_backoffice() OR mentoraggio_utente_associato(id, auth.uid())));

DROP POLICY IF EXISTS "mentoraggi_update_autorizzati" ON "public"."mentoraggi";
CREATE POLICY "mentoraggi_update_autorizzati" ON "public"."mentoraggi" AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((mentoraggio_backoffice() OR mentoraggio_utente_associato(id, auth.uid()) OR mentoraggio_utente_mentee(id, auth.uid())))
  WITH CHECK ((mentoraggio_backoffice() OR mentoraggio_utente_associato(id, auth.uid()) OR mentoraggio_utente_mentee(id, auth.uid())));

DROP POLICY IF EXISTS "Mentee and assigned mentors read assignments" ON "public"."mentoraggio_mentori";
CREATE POLICY "Mentee and assigned mentors read assignments" ON "public"."mentoraggio_mentori" AS PERMISSIVE FOR SELECT TO authenticated
  USING ((is_docente_del_mentoraggio(mentoraggio_id) OR is_mentore_assegnato(mentoraggio_id)));

DROP POLICY IF EXISTS "Owner and organizer manage mentor assignments" ON "public"."mentoraggio_mentori";
CREATE POLICY "Owner and organizer manage mentor assignments" ON "public"."mentoraggio_mentori" AS PERMISSIVE FOR ALL TO authenticated
  USING (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]))
  WITH CHECK (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]));

DROP POLICY IF EXISTS "mentoraggio_mentori_backoffice_delete" ON "public"."mentoraggio_mentori";
CREATE POLICY "mentoraggio_mentori_backoffice_delete" ON "public"."mentoraggio_mentori" AS PERMISSIVE FOR DELETE TO authenticated
  USING (app_backoffice_admin());

DROP POLICY IF EXISTS "mentoraggio_mentori_backoffice_insert" ON "public"."mentoraggio_mentori";
CREATE POLICY "mentoraggio_mentori_backoffice_insert" ON "public"."mentoraggio_mentori" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (app_backoffice_admin());

DROP POLICY IF EXISTS "mentoraggio_mentori_backoffice_select" ON "public"."mentoraggio_mentori";
CREATE POLICY "mentoraggio_mentori_backoffice_select" ON "public"."mentoraggio_mentori" AS PERMISSIVE FOR SELECT TO authenticated
  USING (app_backoffice_admin());

DROP POLICY IF EXISTS "mentoraggio_mentori_backoffice_update" ON "public"."mentoraggio_mentori";
CREATE POLICY "mentoraggio_mentori_backoffice_update" ON "public"."mentoraggio_mentori" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (app_backoffice_admin())
  WITH CHECK (app_backoffice_admin());

DROP POLICY IF EXISTS "Only owners can delete news" ON "public"."news";
CREATE POLICY "Only owners can delete news" ON "public"."news" AS PERMISSIVE FOR DELETE TO authenticated
  USING (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]));

DROP POLICY IF EXISTS "Owners and organizers can create news" ON "public"."news";
CREATE POLICY "Owners and organizers can create news" ON "public"."news" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]));

DROP POLICY IF EXISTS "Owners and organizers can update news" ON "public"."news";
CREATE POLICY "Owners and organizers can update news" ON "public"."news" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]))
  WITH CHECK (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]));

DROP POLICY IF EXISTS "Read active news or manage all" ON "public"."news";
CREATE POLICY "Read active news or manage all" ON "public"."news" AS PERMISSIVE FOR SELECT TO authenticated
  USING (((COALESCE(attiva, false) = true) OR has_role(ARRAY['owner'::app_role, 'organizer'::app_role])));

DROP POLICY IF EXISTS "notifiche_destinatari_admin_tutto" ON "public"."notifiche_destinatari";
CREATE POLICY "notifiche_destinatari_admin_tutto" ON "public"."notifiche_destinatari" AS PERMISSIVE FOR ALL TO authenticated
  USING (notifiche_utente_amministratore())
  WITH CHECK (notifiche_utente_amministratore());

DROP POLICY IF EXISTS "notifiche_destinatari_backoffice_delete" ON "public"."notifiche_destinatari";
CREATE POLICY "notifiche_destinatari_backoffice_delete" ON "public"."notifiche_destinatari" AS PERMISSIVE FOR DELETE TO authenticated
  USING (notifiche_amministratore());

DROP POLICY IF EXISTS "notifiche_destinatari_backoffice_insert" ON "public"."notifiche_destinatari";
CREATE POLICY "notifiche_destinatari_backoffice_insert" ON "public"."notifiche_destinatari" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (notifiche_amministratore());

DROP POLICY IF EXISTS "notifiche_destinatari_backoffice_select" ON "public"."notifiche_destinatari";
CREATE POLICY "notifiche_destinatari_backoffice_select" ON "public"."notifiche_destinatari" AS PERMISSIVE FOR SELECT TO authenticated
  USING (notifiche_amministratore());

DROP POLICY IF EXISTS "notifiche_destinatari_backoffice_update" ON "public"."notifiche_destinatari";
CREATE POLICY "notifiche_destinatari_backoffice_update" ON "public"."notifiche_destinatari" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (notifiche_amministratore())
  WITH CHECK (notifiche_amministratore());

DROP POLICY IF EXISTS "notifiche_destinatari_leggi_propri" ON "public"."notifiche_destinatari";
CREATE POLICY "notifiche_destinatari_leggi_propri" ON "public"."notifiche_destinatari" AS PERMISSIVE FOR SELECT TO authenticated
  USING ((user_id = auth.uid()));

DROP POLICY IF EXISTS "notifiche_dispositivi_admin_leggi" ON "public"."notifiche_dispositivi";
CREATE POLICY "notifiche_dispositivi_admin_leggi" ON "public"."notifiche_dispositivi" AS PERMISSIVE FOR SELECT TO authenticated
  USING (notifiche_utente_amministratore());

DROP POLICY IF EXISTS "notifiche_dispositivi_backoffice_select" ON "public"."notifiche_dispositivi";
CREATE POLICY "notifiche_dispositivi_backoffice_select" ON "public"."notifiche_dispositivi" AS PERMISSIVE FOR SELECT TO authenticated
  USING (notifiche_amministratore());

DROP POLICY IF EXISTS "notifiche_dispositivi_leggi_propri" ON "public"."notifiche_dispositivi";
CREATE POLICY "notifiche_dispositivi_leggi_propri" ON "public"."notifiche_dispositivi" AS PERMISSIVE FOR SELECT TO authenticated
  USING ((user_id = auth.uid()));

DROP POLICY IF EXISTS "notifiche_dispositivi_propri" ON "public"."notifiche_dispositivi";
CREATE POLICY "notifiche_dispositivi_propri" ON "public"."notifiche_dispositivi" AS PERMISSIVE FOR ALL TO authenticated
  USING ((user_id = auth.uid()))
  WITH CHECK ((user_id = auth.uid()));

DROP POLICY IF EXISTS "notifiche_messaggi_admin_tutto" ON "public"."notifiche_messaggi";
CREATE POLICY "notifiche_messaggi_admin_tutto" ON "public"."notifiche_messaggi" AS PERMISSIVE FOR ALL TO authenticated
  USING (notifiche_utente_amministratore())
  WITH CHECK (notifiche_utente_amministratore());

DROP POLICY IF EXISTS "notifiche_messaggi_backoffice_delete" ON "public"."notifiche_messaggi";
CREATE POLICY "notifiche_messaggi_backoffice_delete" ON "public"."notifiche_messaggi" AS PERMISSIVE FOR DELETE TO authenticated
  USING (notifiche_amministratore());

DROP POLICY IF EXISTS "notifiche_messaggi_backoffice_insert" ON "public"."notifiche_messaggi";
CREATE POLICY "notifiche_messaggi_backoffice_insert" ON "public"."notifiche_messaggi" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (notifiche_amministratore());

DROP POLICY IF EXISTS "notifiche_messaggi_backoffice_select" ON "public"."notifiche_messaggi";
CREATE POLICY "notifiche_messaggi_backoffice_select" ON "public"."notifiche_messaggi" AS PERMISSIVE FOR SELECT TO authenticated
  USING (notifiche_amministratore());

DROP POLICY IF EXISTS "notifiche_messaggi_backoffice_update" ON "public"."notifiche_messaggi";
CREATE POLICY "notifiche_messaggi_backoffice_update" ON "public"."notifiche_messaggi" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (notifiche_amministratore())
  WITH CHECK (notifiche_amministratore());

DROP POLICY IF EXISTS "notifiche_messaggi_leggi_se_destinatario" ON "public"."notifiche_messaggi";
CREATE POLICY "notifiche_messaggi_leggi_se_destinatario" ON "public"."notifiche_messaggi" AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM notifiche_destinatari nd
  WHERE ((nd.messaggio_id = notifiche_messaggi.id) AND (nd.user_id = auth.uid())))));

DROP POLICY IF EXISTS "notifiche_regole_admin_tutto" ON "public"."notifiche_regole";
CREATE POLICY "notifiche_regole_admin_tutto" ON "public"."notifiche_regole" AS PERMISSIVE FOR ALL TO authenticated
  USING (notifiche_utente_amministratore())
  WITH CHECK (notifiche_utente_amministratore());

DROP POLICY IF EXISTS "notifiche_regole_backoffice_delete" ON "public"."notifiche_regole";
CREATE POLICY "notifiche_regole_backoffice_delete" ON "public"."notifiche_regole" AS PERMISSIVE FOR DELETE TO authenticated
  USING (notifiche_amministratore());

DROP POLICY IF EXISTS "notifiche_regole_backoffice_insert" ON "public"."notifiche_regole";
CREATE POLICY "notifiche_regole_backoffice_insert" ON "public"."notifiche_regole" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (notifiche_amministratore());

DROP POLICY IF EXISTS "notifiche_regole_backoffice_select" ON "public"."notifiche_regole";
CREATE POLICY "notifiche_regole_backoffice_select" ON "public"."notifiche_regole" AS PERMISSIVE FOR SELECT TO authenticated
  USING (notifiche_amministratore());

DROP POLICY IF EXISTS "notifiche_regole_backoffice_update" ON "public"."notifiche_regole";
CREATE POLICY "notifiche_regole_backoffice_update" ON "public"."notifiche_regole" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (notifiche_amministratore())
  WITH CHECK (notifiche_amministratore());

DROP POLICY IF EXISTS "partecipazioni_annuali_backoffice_select" ON "public"."partecipazioni_annuali";
CREATE POLICY "partecipazioni_annuali_backoffice_select" ON "public"."partecipazioni_annuali" AS PERMISSIVE FOR SELECT TO authenticated
  USING (app_backoffice_admin());

DROP POLICY IF EXISTS "partecipazioni_annuali_own_select" ON "public"."partecipazioni_annuali";
CREATE POLICY "partecipazioni_annuali_own_select" ON "public"."partecipazioni_annuali" AS PERMISSIVE FOR SELECT TO authenticated
  USING ((user_id = auth.uid()));

DROP POLICY IF EXISTS "Owner and organizer manage event registrations" ON "public"."partecipazioni_eventi";
CREATE POLICY "Owner and organizer manage event registrations" ON "public"."partecipazioni_eventi" AS PERMISSIVE FOR ALL TO authenticated
  USING (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]))
  WITH CHECK (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]));

DROP POLICY IF EXISTS "Participants cancel own registrations" ON "public"."partecipazioni_eventi";
CREATE POLICY "Participants cancel own registrations" ON "public"."partecipazioni_eventi" AS PERMISSIVE FOR DELETE TO authenticated
  USING (((partecipante_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM eventi e
  WHERE ((e.id = partecipazioni_eventi.evento_id) AND ((e.data_chiusura_iscrizioni IS NULL) OR (CURRENT_DATE <= e.data_chiusura_iscrizioni)))))));

DROP POLICY IF EXISTS "Participants read own registrations" ON "public"."partecipazioni_eventi";
CREATE POLICY "Participants read own registrations" ON "public"."partecipazioni_eventi" AS PERMISSIVE FOR SELECT TO authenticated
  USING ((partecipante_id = ( SELECT auth.uid() AS uid)));

DROP POLICY IF EXISTS "Participants register themselves" ON "public"."partecipazioni_eventi";
CREATE POLICY "Participants register themselves" ON "public"."partecipazioni_eventi" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((partecipante_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM eventi e
  WHERE ((e.id = partecipazioni_eventi.evento_id) AND ((e.data_apertura_iscrizioni IS NULL) OR (CURRENT_DATE >= e.data_apertura_iscrizioni)) AND ((e.data_chiusura_iscrizioni IS NULL) OR (CURRENT_DATE <= e.data_chiusura_iscrizioni)))))));

DROP POLICY IF EXISTS "Owner and organizer manage House registrations" ON "public"."partecipazioni_house_of_mentore";
CREATE POLICY "Owner and organizer manage House registrations" ON "public"."partecipazioni_house_of_mentore" AS PERMISSIVE FOR ALL TO authenticated
  USING (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]))
  WITH CHECK (has_role(ARRAY['owner'::app_role, 'organizer'::app_role]));

DROP POLICY IF EXISTS "Participants create own House registrations" ON "public"."partecipazioni_house_of_mentore";
CREATE POLICY "Participants create own House registrations" ON "public"."partecipazioni_house_of_mentore" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((partecipante_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM house_of_mentore h
  WHERE ((h.id = partecipazioni_house_of_mentore.evento_id) AND (h.iscrizioni_aperte = true))))));

DROP POLICY IF EXISTS "Participants delete own House registrations" ON "public"."partecipazioni_house_of_mentore";
CREATE POLICY "Participants delete own House registrations" ON "public"."partecipazioni_house_of_mentore" AS PERMISSIVE FOR DELETE TO authenticated
  USING (((partecipante_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM house_of_mentore h
  WHERE ((h.id = partecipazioni_house_of_mentore.evento_id) AND (h.iscrizioni_aperte = true))))));

DROP POLICY IF EXISTS "Participants read own House registrations" ON "public"."partecipazioni_house_of_mentore";
CREATE POLICY "Participants read own House registrations" ON "public"."partecipazioni_house_of_mentore" AS PERMISSIVE FOR SELECT TO authenticated
  USING ((partecipante_id = auth.uid()));

DROP POLICY IF EXISTS "Participants update own House registrations" ON "public"."partecipazioni_house_of_mentore";
CREATE POLICY "Participants update own House registrations" ON "public"."partecipazioni_house_of_mentore" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((partecipante_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM house_of_mentore h
  WHERE ((h.id = partecipazioni_house_of_mentore.evento_id) AND (h.iscrizioni_aperte = true))))))
  WITH CHECK (((partecipante_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM house_of_mentore h
  WHERE ((h.id = partecipazioni_house_of_mentore.evento_id) AND (h.iscrizioni_aperte = true))))));

DROP POLICY IF EXISTS "questionari_admin_all" ON "public"."questionari";
CREATE POLICY "questionari_admin_all" ON "public"."questionari" AS PERMISSIVE FOR ALL TO authenticated
  USING (app_backoffice_admin())
  WITH CHECK (app_backoffice_admin());

DROP POLICY IF EXISTS "questionari_evento_partecipante_select" ON "public"."questionari";
CREATE POLICY "questionari_evento_partecipante_select" ON "public"."questionari" AS PERMISSIVE FOR SELECT TO authenticated
  USING (((provider = 'interno'::questionario_provider) AND (aperto = true) AND ((data_apertura IS NULL) OR (data_apertura <= now())) AND ((data_chiusura IS NULL) OR (data_chiusura >= now())) AND (EXISTS ( SELECT 1
   FROM partecipazioni_eventi pe
  WHERE ((pe.evento_id = questionari.evento_id) AND (pe.partecipante_id = auth.uid()) AND (pe.presente = true)))));

DROP POLICY IF EXISTS "questionari_mentoraggio_mentore_insert" ON "public"."questionari";
CREATE POLICY "questionari_mentoraggio_mentore_insert" ON "public"."questionari" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((provider = 'pubblico'::questionario_provider) AND (created_by = auth.uid()) AND (EXISTS ( SELECT 1
   FROM mentoraggio_mentori mm
  WHERE ((mm.mentoraggio_id = questionari.mentoraggio_id) AND (mm.mentore_id = auth.uid()))))));

DROP POLICY IF EXISTS "questionari_mentoraggio_mentore_select" ON "public"."questionari";
CREATE POLICY "questionari_mentoraggio_mentore_select" ON "public"."questionari" AS PERMISSIVE FOR SELECT TO authenticated
  USING (((provider = 'pubblico'::questionario_provider) AND (EXISTS ( SELECT 1
   FROM mentoraggio_mentori mm
  WHERE ((mm.mentoraggio_id = questionari.mentoraggio_id) AND (mm.mentore_id = auth.uid()))))));

DROP POLICY IF EXISTS "questionari_compilazioni_delete_own" ON "public"."questionari_compilazioni";
CREATE POLICY "questionari_compilazioni_delete_own" ON "public"."questionari_compilazioni" AS PERMISSIVE FOR DELETE TO authenticated
  USING ((user_id = auth.uid()));

DROP POLICY IF EXISTS "questionari_compilazioni_insert_own" ON "public"."questionari_compilazioni";
CREATE POLICY "questionari_compilazioni_insert_own" ON "public"."questionari_compilazioni" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM (questionari q
     JOIN partecipazioni_eventi pe ON ((pe.evento_id = q.evento_id)))
  WHERE ((q.id = questionari_compilazioni.questionario_id) AND (q.provider = 'interno'::questionario_provider) AND (q.aperto = true) AND ((q.data_apertura IS NULL) OR (q.data_apertura <= now())) AND ((q.data_chiusura IS NULL) OR (q.data_chiusura >= now())) AND (pe.partecipante_id = auth.uid()) AND (pe.presente = true))))));

DROP POLICY IF EXISTS "questionari_compilazioni_select_own" ON "public"."questionari_compilazioni";
CREATE POLICY "questionari_compilazioni_select_own" ON "public"."questionari_compilazioni" AS PERMISSIVE FOR SELECT TO authenticated
  USING (((user_id = auth.uid()) OR app_backoffice_admin()));

DROP POLICY IF EXISTS "questionari_domande_admin_all" ON "public"."questionari_domande";
CREATE POLICY "questionari_domande_admin_all" ON "public"."questionari_domande" AS PERMISSIVE FOR ALL TO authenticated
  USING (app_backoffice_admin())
  WITH CHECK (app_backoffice_admin());

DROP POLICY IF EXISTS "questionari_domande_select" ON "public"."questionari_domande";
CREATE POLICY "questionari_domande_select" ON "public"."questionari_domande" AS PERMISSIVE FOR SELECT TO authenticated
  USING ((app_backoffice_admin() OR (EXISTS ( SELECT 1
   FROM (questionari q
     JOIN partecipazioni_eventi pe ON ((pe.evento_id = q.evento_id)))
  WHERE ((q.template_id = questionari_domande.template_id) AND (q.provider = 'interno'::questionario_provider) AND (q.aperto = true) AND ((q.data_apertura IS NULL) OR (q.data_apertura <= now())) AND ((q.data_chiusura IS NULL) OR (q.data_chiusura >= now())) AND (pe.partecipante_id = auth.uid()) AND (pe.presente = true)))));

DROP POLICY IF EXISTS "questionari_risposte_insert" ON "public"."questionari_risposte";
CREATE POLICY "questionari_risposte_insert" ON "public"."questionari_risposte" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM questionari_compilazioni c
  WHERE ((c.id = questionari_risposte.compilazione_id) AND (c.user_id = auth.uid())))));

DROP POLICY IF EXISTS "questionari_risposte_select" ON "public"."questionari_risposte";
CREATE POLICY "questionari_risposte_select" ON "public"."questionari_risposte" AS PERMISSIVE FOR SELECT TO authenticated
  USING ((app_backoffice_admin() OR (EXISTS ( SELECT 1
   FROM questionari_compilazioni c
  WHERE ((c.id = questionari_risposte.compilazione_id) AND (c.user_id = auth.uid()))))));

DROP POLICY IF EXISTS "questionari_template_admin_all" ON "public"."questionari_template";
CREATE POLICY "questionari_template_admin_all" ON "public"."questionari_template" AS PERMISSIVE FOR ALL TO authenticated
  USING (app_backoffice_admin())
  WITH CHECK (app_backoffice_admin());

DROP POLICY IF EXISTS "questionari_template_select" ON "public"."questionari_template";
CREATE POLICY "questionari_template_select" ON "public"."questionari_template" AS PERMISSIVE FOR SELECT TO authenticated
  USING ((app_backoffice_admin() OR ((attivo = true) AND (predefinito = true))));

DROP POLICY IF EXISTS "risorse_mentoring_admin" ON "public"."risorse_mentoring";
CREATE POLICY "risorse_mentoring_admin" ON "public"."risorse_mentoring" AS PERMISSIVE FOR ALL TO authenticated
  USING (app_backoffice_admin())
  WITH CHECK (app_backoffice_admin());

DROP POLICY IF EXISTS "risorse_mentoring_select" ON "public"."risorse_mentoring";
CREATE POLICY "risorse_mentoring_select" ON "public"."risorse_mentoring" AS PERMISSIVE FOR SELECT TO authenticated
  USING (((attivo = true) OR app_backoffice_admin()));

DROP POLICY IF EXISTS "Owner can delete SSD" ON "public"."ssd";
CREATE POLICY "Owner can delete SSD" ON "public"."ssd" AS PERMISSIVE FOR DELETE TO authenticated
  USING (has_role(ARRAY['owner'::app_role]));

DROP POLICY IF EXISTS "Owner can insert SSD" ON "public"."ssd";
CREATE POLICY "Owner can insert SSD" ON "public"."ssd" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (has_role(ARRAY['owner'::app_role]));

DROP POLICY IF EXISTS "Owner can update SSD" ON "public"."ssd";
CREATE POLICY "Owner can update SSD" ON "public"."ssd" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (has_role(ARRAY['owner'::app_role]))
  WITH CHECK (has_role(ARRAY['owner'::app_role]));

DROP POLICY IF EXISTS "authenticated can read ssd" ON "public"."ssd";
CREATE POLICY "authenticated can read ssd" ON "public"."ssd" AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Owner manages application roles" ON "public"."user_roles";
CREATE POLICY "Owner manages application roles" ON "public"."user_roles" AS PERMISSIVE FOR ALL TO authenticated
  USING (has_role(ARRAY['owner'::app_role]))
  WITH CHECK (has_role(ARRAY['owner'::app_role]));

DROP POLICY IF EXISTS "Users read own role and owner reads all" ON "public"."user_roles";
CREATE POLICY "Users read own role and owner reads all" ON "public"."user_roles" AS PERMISSIVE FOR SELECT TO authenticated
  USING (((user_id = auth.uid()) OR has_role(ARRAY['owner'::app_role])));

DROP POLICY IF EXISTS "user_roles_backoffice_select" ON "public"."user_roles";
CREATE POLICY "user_roles_backoffice_select" ON "public"."user_roles" AS PERMISSIVE FOR SELECT TO authenticated
  USING (app_backoffice_admin());

DROP POLICY IF EXISTS "user_roles_owner_update" ON "public"."user_roles";
CREATE POLICY "user_roles_owner_update" ON "public"."user_roles" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (app_owner())
  WITH CHECK (app_owner());

DROP POLICY IF EXISTS "users can read own role" ON "public"."user_roles";
CREATE POLICY "users can read own role" ON "public"."user_roles" AS PERMISSIVE FOR SELECT TO authenticated
  USING ((auth.uid() = user_id));

DROP POLICY IF EXISTS "locandine_admin_delete" ON "storage"."objects";
CREATE POLICY "locandine_admin_delete" ON "storage"."objects" AS PERMISSIVE FOR DELETE TO authenticated
  USING (((bucket_id = 'locandine'::text) AND app_backoffice_admin()));

DROP POLICY IF EXISTS "locandine_admin_insert" ON "storage"."objects";
CREATE POLICY "locandine_admin_insert" ON "storage"."objects" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((bucket_id = 'locandine'::text) AND app_backoffice_admin() AND (storage.extension(name) = ANY (ARRAY['jpg'::text, 'jpeg'::text, 'png'::text]))));

DROP POLICY IF EXISTS "locandine_admin_select" ON "storage"."objects";
CREATE POLICY "locandine_admin_select" ON "storage"."objects" AS PERMISSIVE FOR SELECT TO authenticated
  USING (((bucket_id = 'locandine'::text) AND app_backoffice_admin()));

DROP POLICY IF EXISTS "locandine_admin_update" ON "storage"."objects";
CREATE POLICY "locandine_admin_update" ON "storage"."objects" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((bucket_id = 'locandine'::text) AND app_backoffice_admin()))
  WITH CHECK (((bucket_id = 'locandine'::text) AND app_backoffice_admin() AND (storage.extension(name) = ANY (ARRAY['jpg'::text, 'jpeg'::text, 'png'::text]))));

DROP POLICY IF EXISTS "risorse_mentoring_delete" ON "storage"."objects";
CREATE POLICY "risorse_mentoring_delete" ON "storage"."objects" AS PERMISSIVE FOR DELETE TO authenticated
  USING (((bucket_id = 'risorse-mentoring'::text) AND app_backoffice_admin()));

DROP POLICY IF EXISTS "risorse_mentoring_insert" ON "storage"."objects";
CREATE POLICY "risorse_mentoring_insert" ON "storage"."objects" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((bucket_id = 'risorse-mentoring'::text) AND app_backoffice_admin()));

DROP POLICY IF EXISTS "risorse_mentoring_select" ON "storage"."objects";
CREATE POLICY "risorse_mentoring_select" ON "storage"."objects" AS PERMISSIVE FOR SELECT TO authenticated
  USING ((bucket_id = 'risorse-mentoring'::text));

DROP POLICY IF EXISTS "risorse_mentoring_update" ON "storage"."objects";
CREATE POLICY "risorse_mentoring_update" ON "storage"."objects" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((bucket_id = 'risorse-mentoring'::text) AND app_backoffice_admin()))
  WITH CHECK (((bucket_id = 'risorse-mentoring'::text) AND app_backoffice_admin()));

DROP POLICY IF EXISTS "risorse_storage_delete" ON "storage"."objects";
CREATE POLICY "risorse_storage_delete" ON "storage"."objects" AS PERMISSIVE FOR DELETE TO authenticated
  USING (((bucket_id = 'risorse-mentoring'::text) AND app_backoffice_admin()));

DROP POLICY IF EXISTS "risorse_storage_insert" ON "storage"."objects";
CREATE POLICY "risorse_storage_insert" ON "storage"."objects" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((bucket_id = 'risorse-mentoring'::text) AND app_backoffice_admin()));

DROP POLICY IF EXISTS "risorse_storage_select" ON "storage"."objects";
CREATE POLICY "risorse_storage_select" ON "storage"."objects" AS PERMISSIVE FOR SELECT TO authenticated
  USING ((bucket_id = 'risorse-mentoring'::text));

DROP POLICY IF EXISTS "risorse_storage_update" ON "storage"."objects";
CREATE POLICY "risorse_storage_update" ON "storage"."objects" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((bucket_id = 'risorse-mentoring'::text) AND app_backoffice_admin()))
  WITH CHECK (((bucket_id = 'risorse-mentoring'::text) AND app_backoffice_admin()));

DROP POLICY IF EXISTS "schede_sintesi_delete" ON "storage"."objects";
CREATE POLICY "schede_sintesi_delete" ON "storage"."objects" AS PERMISSIVE FOR DELETE TO authenticated
  USING (((bucket_id = 'schede-sintesi'::text) AND (app_backoffice_admin() OR (EXISTS ( SELECT 1
   FROM (mentoraggio_mentori mm
     JOIN mentoraggi m ON ((m.id = mm.mentoraggio_id)))
  WHERE (((mm.mentoraggio_id)::text = split_part(objects.name, '/'::text, 2)) AND (mm.mentore_id = auth.uid()) AND ((m.stato)::text = 'Completato'::text)))))));

DROP POLICY IF EXISTS "schede_sintesi_insert" ON "storage"."objects";
CREATE POLICY "schede_sintesi_insert" ON "storage"."objects" AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((bucket_id = 'schede-sintesi'::text) AND (app_backoffice_admin() OR (EXISTS ( SELECT 1
   FROM (mentoraggio_mentori mm
     JOIN mentoraggi m ON ((m.id = mm.mentoraggio_id)))
  WHERE (((mm.mentoraggio_id)::text = split_part(objects.name, '/'::text, 2)) AND (mm.mentore_id = auth.uid()) AND ((m.stato)::text = 'Completato'::text)))))));

DROP POLICY IF EXISTS "schede_sintesi_select" ON "storage"."objects";
CREATE POLICY "schede_sintesi_select" ON "storage"."objects" AS PERMISSIVE FOR SELECT TO authenticated
  USING (((bucket_id = 'schede-sintesi'::text) AND (app_backoffice_admin() OR (EXISTS ( SELECT 1
   FROM mentoraggio_mentori mm
  WHERE (((mm.mentoraggio_id)::text = split_part(objects.name, '/'::text, 2)) AND (mm.mentore_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM (mentoraggi m
     JOIN insegnamenti i ON ((i.id = m.insegnamento_id)))
  WHERE (((m.id)::text = split_part(objects.name, '/'::text, 2)) AND (i.docente_id = auth.uid())))))));

DROP POLICY IF EXISTS "schede_sintesi_update" ON "storage"."objects";
CREATE POLICY "schede_sintesi_update" ON "storage"."objects" AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((bucket_id = 'schede-sintesi'::text) AND (app_backoffice_admin() OR (EXISTS ( SELECT 1
   FROM (mentoraggio_mentori mm
     JOIN mentoraggi m ON ((m.id = mm.mentoraggio_id)))
  WHERE (((mm.mentoraggio_id)::text = split_part(objects.name, '/'::text, 2)) AND (mm.mentore_id = auth.uid()) AND ((m.stato)::text = 'Completato'::text)))))))
  WITH CHECK (((bucket_id = 'schede-sintesi'::text) AND (app_backoffice_admin() OR (EXISTS ( SELECT 1
   FROM (mentoraggio_mentori mm
     JOIN mentoraggi m ON ((m.id = mm.mentoraggio_id)))
  WHERE (((mm.mentoraggio_id)::text = split_part(objects.name, '/'::text, 2)) AND (mm.mentore_id = auth.uid()) AND ((m.stato)::text = 'Completato'::text)))))));

