-- ============================================================================
-- 01 - EXTENSIONS
-- Generato da inventario read-only del progetto Supabase esistente.
-- NON eseguire sul progetto di produzione attuale.
-- Destinato esclusivamente a un NUOVO progetto Supabase vuoto.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";
CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";
-- plpgsql è normalmente già presente in PostgreSQL/Supabase.
CREATE EXTENSION IF NOT EXISTS plpgsql;

CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";
