# Configurazione push FCM

Questa versione aggiunge il canale push senza sostituire le notifiche interne nel DB.
Le notifiche interne restano sempre consultabili nella pagina `Notifiche` anche quando
l'utente non concede il permesso push.

## 1. Dipendenze Flutter

Il `pubspec.yaml` incluso aggiunge:

- `firebase_core: ^4.12.1`
- `firebase_messaging: ^16.4.3`

Eseguire:

```bash
flutter pub get
```

## 2. Configurare Firebase

Metodo raccomandato:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Configurare almeno Android e iOS; se si usa anche Flutter Web, configurare Web.

### Android

FlutterFire/Firebase deve generare/configurare `android/app/google-services.json`.

### iOS

Occorre `GoogleService-Info.plist`; in Xcode abilitare `Push Notifications` e
`Background Modes -> Remote notifications`, quindi caricare in Firebase la chiave APNs.

### Web

Il servizio incluso usa `--dart-define`. Passare almeno:

```text
FIREBASE_WEB_API_KEY
FIREBASE_WEB_APP_ID
FIREBASE_WEB_MESSAGING_SENDER_ID
FIREBASE_WEB_PROJECT_ID
FIREBASE_WEB_VAPID_KEY
```

Opzionali:

```text
FIREBASE_WEB_AUTH_DOMAIN
FIREBASE_WEB_STORAGE_BUCKET
FIREBASE_WEB_MEASUREMENT_ID
```

FCM Web richiede inoltre il service worker Firebase previsto dalla configurazione Web.

## 3. SQL dispositivi

Eseguire `NOTIFICHE_DISPOSITIVI_RLS.sql` nel SQL Editor di Supabase.
Il Flutter non scrive direttamente `notifiche_dispositivi`: usa RPC SECURITY DEFINER che
associano il token esclusivamente a `auth.uid()`.

## 4. Edge Function `notifiche-invia`

Creare/deployare la funzione con il file:

`supabase/functions/notifiche-invia/index.ts`

La funzione deve avere nei Secrets:

### PROJECT_SECRET_KEY

La nuova Secret key `sb_secret_...` del progetto Supabase. Rimane esclusivamente lato server.

### FIREBASE_SERVICE_ACCOUNT_JSON

JSON completo del service account Firebase con permesso di inviare messaggi FCM HTTP v1.
Non inserire mai questo JSON nel Flutter.

### NOTIFICHE_CRON_SECRET

Stringa casuale lunga. Servira al job schedulato che invochera la stessa Edge Function per
le notifiche con `programmata_per` scaduta e, in seguito, per il motore delle regole temporali.

## 5. Invio immediato

Quando owner/organizer crea una notifica manuale senza `programmata_per`, il Flutter:

1. crea `notifiche_messaggi`;
2. chiama `notifiche_genera_destinatari`;
3. invoca `notifiche-invia`;
4. la Edge Function ricontrolla `anagrafica_riservata.attivo = true`;
5. invia a tutti i token attivi dell'utente;
6. aggiorna `notifiche_destinatari` e `notifiche_messaggi`.

## 6. Invio programmato

Il codice della Edge Function supporta gia l'elaborazione dei messaggi programmati scaduti
quando viene invocata senza `messaggio_id`. Il prossimo passaggio e collegarla a Supabase Cron
(ad esempio ogni 5 minuti) usando `NOTIFICHE_CRON_SECRET`.
