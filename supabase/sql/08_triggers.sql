-- ============================================================================
-- 08 - TRIGGER
-- Generato da inventario read-only del progetto Supabase esistente.
-- NON eseguire sul progetto di produzione attuale.
-- Destinato esclusivamente a un NUOVO progetto Supabase vuoto.
-- ============================================================================

DROP TRIGGER IF EXISTS "crea_anagrafica_riservata_trigger" ON public."anagrafica";
CREATE TRIGGER crea_anagrafica_riservata_trigger AFTER INSERT ON anagrafica FOR EACH ROW EXECUTE FUNCTION crea_anagrafica_riservata();

DROP TRIGGER IF EXISTS "notifiche_regole_aiu" ON public."eventi";
CREATE TRIGGER notifiche_regole_aiu AFTER INSERT OR UPDATE ON eventi FOR EACH ROW EXECUTE FUNCTION notifiche_trigger_sorgente();

DROP TRIGGER IF EXISTS "aggiorna_updated_at_house_of_mentore_trigger" ON public."house_of_mentore";
CREATE TRIGGER aggiorna_updated_at_house_of_mentore_trigger BEFORE UPDATE ON house_of_mentore FOR EACH ROW EXECUTE FUNCTION aggiorna_updated_at_house_of_mentore();

DROP TRIGGER IF EXISTS "notifiche_regole_aiu" ON public."house_of_mentore";
CREATE TRIGGER notifiche_regole_aiu AFTER INSERT OR UPDATE ON house_of_mentore FOR EACH ROW EXECUTE FUNCTION notifiche_trigger_sorgente();

DROP TRIGGER IF EXISTS "proteggi_identificativi_insegnamento_trigger" ON public."insegnamenti";
CREATE TRIGGER proteggi_identificativi_insegnamento_trigger BEFORE UPDATE ON insegnamenti FOR EACH ROW EXECUTE FUNCTION proteggi_identificativi_insegnamento();

DROP TRIGGER IF EXISTS "notifiche_regole_aiu" ON public."news";
CREATE TRIGGER notifiche_regole_aiu AFTER INSERT OR UPDATE ON news FOR EACH ROW EXECUTE FUNCTION notifiche_trigger_sorgente();

DROP TRIGGER IF EXISTS "notifiche_destinatari_updated_at" ON public."notifiche_destinatari";
CREATE TRIGGER notifiche_destinatari_updated_at BEFORE UPDATE ON notifiche_destinatari FOR EACH ROW EXECUTE FUNCTION notifiche_set_updated_at();

DROP TRIGGER IF EXISTS "notifiche_dispositivi_updated_at" ON public."notifiche_dispositivi";
CREATE TRIGGER notifiche_dispositivi_updated_at BEFORE UPDATE ON notifiche_dispositivi FOR EACH ROW EXECUTE FUNCTION notifiche_set_updated_at();

DROP TRIGGER IF EXISTS "notifiche_messaggi_updated_at" ON public."notifiche_messaggi";
CREATE TRIGGER notifiche_messaggi_updated_at BEFORE UPDATE ON notifiche_messaggi FOR EACH ROW EXECUTE FUNCTION notifiche_set_updated_at();

DROP TRIGGER IF EXISTS "notifiche_regole_config_changed" ON public."notifiche_regole";
CREATE TRIGGER notifiche_regole_config_changed AFTER INSERT OR DELETE OR UPDATE ON notifiche_regole FOR EACH STATEMENT EXECUTE FUNCTION notifiche_trigger_regole_config();

DROP TRIGGER IF EXISTS "notifiche_regole_updated_at" ON public."notifiche_regole";
CREATE TRIGGER notifiche_regole_updated_at BEFORE UPDATE ON notifiche_regole FOR EACH ROW EXECUTE FUNCTION notifiche_set_updated_at();

DROP TRIGGER IF EXISTS "notifiche_regole_aiu" ON public."partecipazioni_eventi";
CREATE TRIGGER notifiche_regole_aiu AFTER INSERT OR UPDATE ON partecipazioni_eventi FOR EACH ROW EXECUTE FUNCTION notifiche_trigger_sorgente();

DROP TRIGGER IF EXISTS "proteggi_presenza_evento_trg" ON public."partecipazioni_eventi";
CREATE TRIGGER proteggi_presenza_evento_trg BEFORE INSERT OR UPDATE ON partecipazioni_eventi FOR EACH ROW EXECUTE FUNCTION proteggi_presenza_evento();

