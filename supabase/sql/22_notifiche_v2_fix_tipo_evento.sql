-- ============================================================================
-- 22 - NOTIFICHE V2 FIX: RICALCOLO tipo_evento_utente
-- Migrazione correttiva idempotente per database ESISTENTE.
--
-- Motivo:
-- alcune regole legacy possono restare con tipo_evento_utente='aggiornamento'
-- anche quando tipo_attivazione e' 'insert', 'data' o 'programmata'.
-- ============================================================================

BEGIN;

UPDATE public.notifiche_regole r
SET tipo_evento_utente = m.nuovo_tipo
FROM (
  SELECT
    id,
    CASE tipo_attivazione::text
      WHEN 'insert' THEN 'nuovo_inserimento'
      WHEN 'update' THEN 'aggiornamento'
      WHEN 'data' THEN CASE
        WHEN COALESCE(offset_giorni, 0) < 0 THEN 'reminder_prima_data'
        WHEN COALESCE(offset_giorni, 0) = 0 THEN 'reminder_giorno_data'
        ELSE 'reminder_dopo_data'
      END
      WHEN 'programmata' THEN 'programmata'
      ELSE 'aggiornamento'
    END AS nuovo_tipo
  FROM public.notifiche_regole
) m
WHERE r.id = m.id
  AND r.tipo_evento_utente IS DISTINCT FROM m.nuovo_tipo;

COMMIT;

-- Verifica rapida suggerita:
-- select id, codice, tipo_attivazione::text, offset_giorni, tipo_evento_utente
-- from public.notifiche_regole
-- order by codice;
