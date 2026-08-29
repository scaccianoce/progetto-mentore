-- ============================================================================
-- 14 - VERIFICA READ-ONLY DOPO RICOSTRUZIONE
-- Generato da inventario read-only del progetto Supabase esistente.
-- NON eseguire sul progetto di produzione attuale.
-- Destinato esclusivamente a un NUOVO progetto Supabase vuoto.
-- ============================================================================


-- Eseguire solo sul NUOVO progetto dopo gli script precedenti.

SELECT 'tables' AS oggetto, count(*)::text AS valore
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind='r'
UNION ALL
SELECT 'views', count(*)::text
FROM pg_views WHERE schemaname='public'
UNION ALL
SELECT 'functions', count(*)::text
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prokind='f'
UNION ALL
SELECT 'triggers', count(*)::text
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND NOT t.tgisinternal
UNION ALL
SELECT 'policies_public_storage', count(*)::text
FROM pg_policies WHERE schemaname IN ('public','storage')
UNION ALL
SELECT 'storage_buckets', count(*)::text
FROM storage.buckets;
