# Rollout Notifiche V2 (DB esistente)

Questa procedura applica la migrazione al sistema notifiche su un database gia esistente.

## Script da eseguire (in ordine)

1. supabase/sql/18_notifiche_v2_schema.sql
2. supabase/sql/19_notifiche_v2_functions.sql
3. supabase/sql/20_notifiche_v2_triggers_cron.sql
4. supabase/sql/22_notifiche_v2_fix_tipo_evento.sql
5. supabase/sql/21_notifiche_v2_verify.sql (solo verifica read-only)

## Operazioni da fare su DB TEST

1. Apri SQL Editor su progetto TEST.
2. Esegui, uno alla volta, i file 18, 19, 20 e 22.
3. Esegui il file 21 e salva l'output.
4. Verifica in Dashboard Cron che non esista piu `notifiche-worker-ogni-minuto` e che esista `notifiche-worker-giornaliero-v2`.
5. Verifica che i secret Vault esistano:
   - notifiche_project_url
   - notifiche_publishable_key
   - notifiche_cron_secret
6. Deploy edge function aggiornata:
   - funzione: notifiche-invia
7. Crea almeno una regola test con `invia_push=true` e una con `invia_email=true`.
8. Esegui un test manuale creando un messaggio da backoffice.

## Operazioni da fare su ALTRO AMBIENTE (produzione)

1. Ripeti gli stessi step del TEST nello stesso ordine.
2. Esegui 21_notifiche_v2_verify.sql e confronta output con TEST.
3. Conferma che il job ogni minuto sia assente.
4. Conferma il deploy della edge function notifiche-invia.

## Comandi CLI utili (facoltativi)

Da root progetto:

```bash
# deploy edge function
supabase functions deploy notifiche-invia --project-ref <PROJECT_REF>

# elenco funzioni
supabase functions list --project-ref <PROJECT_REF>
```

## Note importanti

- Gli script 18/19/20 sono di modifica schema/funzioni/trigger/cron: eseguirli solo quando approvati.
- Lo script 21 e solo diagnostico (read-only).
- La logica email quota 90/giorno viene predisposta a livello schema/funzioni.
- Nessuno script cancella storico notifiche esistente.
