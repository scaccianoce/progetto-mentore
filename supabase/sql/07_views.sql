-- ============================================================================
-- 07 - VIEWS
-- Generato da inventario read-only del progetto Supabase esistente.
-- NON eseguire sul progetto di produzione attuale.
-- Destinato esclusivamente a un NUOVO progetto Supabase vuoto.
-- ============================================================================

CREATE OR REPLACE VIEW public."notifiche_utenti_attivi" AS
 SELECT a.user_id,
    a.nome,
    a.cognome,
    a.email_unipa,
    ur.role
   FROM ((anagrafica a
     JOIN anagrafica_riservata ar ON ((ar.user_id = a.user_id)))
     LEFT JOIN user_roles ur ON ((ur.user_id = a.user_id)))
  WHERE (ar.attivo IS TRUE);

