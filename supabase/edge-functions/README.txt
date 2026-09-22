EDGE FUNCTIONS - INVENTARIO DA COMPLETARE
==========================================

Le Edge Functions NON sono incluse nel dump SQL PostgreSQL.

Sorgenti presenti localmente:
- notifiche-invia
- notifiche-push-test
- backoffice-user-admin
- smart-task
- mentoraggi-google-sheet

La funzione mentoraggi-google-sheet viene invocata dal trigger PostgreSQL
sync_mentoraggi_google_sheet. Dopo l'esecuzione di
sql/31_google_sheet_configurabile.sql legge URL, secret cifrato e mappature
dalla configurazione attiva. Le variabili GOOGLE_SCRIPT_URL e
GOOGLE_SCRIPT_SECRET restano come fallback compatibile se non esiste ancora
una configurazione attiva.

Richiede inoltre:
- secret:google_sheet_sync (gestito dalla configurazione withSupabase)

Il modello di Web App da distribuire in Google Apps Script e' disponibile in:
- ../google-apps-script/google_sheet_sync.gs

Per una ricostruzione realmente completa servono i sorgenti ATTUALI di tutte le
Edge Functions presenti nel Dashboard Supabase.

Operazione consigliata, solo dal Dashboard:
1. Edge Functions -> annotare l'elenco completo.
2. Aprire ciascuna funzione e salvare localmente il sorgente attuale.
3. Collocarlo in questa cartella, una sottocartella per funzione.

Non inserire qui valori segreti.


TEST PUSH SINGOLO
=================

La funzione notifiche-push-test non usa tabelle del database. Richiede i secret
FIREBASE_SERVICE_ACCOUNT_JSON e NOTIFICHE_CRON_SECRET e accetta via POST:

{
  "token": "TOKEN_FCM_DEL_DISPOSITIVO",
  "titolo": "Test push",
  "messaggio": "Notifica di prova"
}

Il campo token e' obbligatorio; titolo e messaggio sono facoltativi.
La verifica JWT e' disattivata per consentire la chiamata da pg_net; la funzione
verifica internamente l'header x-cron-secret.
