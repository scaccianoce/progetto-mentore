-- ============================================================================
-- 12 - STORAGE BUCKETS
-- Generato da inventario read-only del progetto Supabase esistente.
-- NON eseguire sul progetto di produzione attuale.
-- Destinato esclusivamente a un NUOVO progetto Supabase vuoto.
-- ============================================================================

-- Le tabelle storage.* sono fornite da Supabase.
-- Questo script ricrea solo i bucket applicativi.
-- Le relative policies sono già comprese in 09_rls_policies.sql.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('locandine', 'locandine', true, 307200, ARRAY['image/jpeg', 'image/png']::text[])
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('risorse-mentoring', 'risorse-mentoring', false, 20971520, NULL)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('schede-sintesi', 'schede-sintesi', false, NULL, ARRAY['application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']::text[])
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

