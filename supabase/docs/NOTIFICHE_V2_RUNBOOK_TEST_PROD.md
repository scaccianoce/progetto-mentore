# Runbook Operativa Notifiche V2 (TEST -> PROD)

Data: 2026-09-16

Obiettivo: portare in esercizio push + email (Resend) in modo controllato, con gate finale go/no-go.

Nota: questa runbook non applica modifiche DB automaticamente. Include script SQL di verifica e, dove indicato, script SQL di patch da eseguire solo dopo approvazione.

## 0) Prerequisiti

- Supabase CLI autenticata.
- Accesso a Supabase Studio su TEST e PROD.
- Secrets Edge gia configurati:
  - PROJECT_SECRET_KEY (o SUPABASE_SECRET_KEYS)
  - FIREBASE_SERVICE_ACCOUNT_JSON
  - NOTIFICHE_CRON_SECRET
- Vault DB gia configurato:
  - notifiche_project_url
  - notifiche_publishable_key
  - notifiche_cron_secret

## 1) Verifica cron e stato base (read-only)

Esegui in SQL Editor (TEST e poi PROD):

```sql
SELECT jobid, jobname, schedule, active
FROM cron.job
WHERE jobname IN ('notifiche-worker-giornaliero-v2', 'notifiche-worker-ogni-minuto')
ORDER BY jobname;
```

Atteso:
- presente notifiche-worker-giornaliero-v2
- assente notifiche-worker-ogni-minuto

Storico esecuzioni cron:

```sql
SELECT jobid, runid, status, start_time, end_time, return_message
FROM cron.job_run_details
WHERE jobid IN (
  SELECT jobid FROM cron.job WHERE jobname = 'notifiche-worker-giornaliero-v2'
)
ORDER BY start_time DESC
LIMIT 30;
```

## 2) Verifica RLS/RPC dispositivi (read-only)

### 2.1 Funzioni presenti

```sql
SELECT n.nspname AS schema, p.proname AS funzione
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'notifiche_registra_dispositivo',
    'notifiche_disattiva_dispositivo',
    'notifiche_genera_destinatari',
    'notifiche_materializza_regole_temporali',
    'notifiche_email_pianifica_messaggio'
  )
ORDER BY p.proname;
```

### 2.2 Grant EXECUTE per authenticated

```sql
SELECT
  routine_name,
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE specific_schema = 'public'
  AND routine_name IN ('notifiche_registra_dispositivo', 'notifiche_disattiva_dispositivo')
  AND grantee = 'authenticated'
ORDER BY routine_name, privilege_type;
```

### 2.3 RLS attiva su notifiche_dispositivi

```sql
SELECT
  n.nspname AS schemaname,
  c.relname AS tablename,
  c.relrowsecurity AS rowsecurity,
  c.relforcerowsecurity AS forcerowsecurity
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = 'notifiche_dispositivi'
  AND c.relkind = 'r';
```

### 2.4 Policy su notifiche_dispositivi

```sql
SELECT policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'notifiche_dispositivi'
ORDER BY policyname;
```

Atteso minimo:
- RLS attiva.
- policy per leggere propri token.
- policy/admin access coerente con backoffice.

## 3) Deploy Edge function

Gia fatto. Comandi di riferimento:

```bash
supabase functions deploy notifiche-invia --project-ref <TEST_REF>
supabase functions deploy notifiche-invia --project-ref <PROD_REF>
```

Verifica presenza funzione:

```bash
supabase functions list --project-ref <TEST_REF>
supabase functions list --project-ref <PROD_REF>
```

## 4) Email reale con Aruba (SMTP): cosa fare

Stato attuale:
- la funzione pianifica email (email_stato in_coda / email_programmata_per)
- non esegue ancora invio email verso provider

Per andare live con email reale servono questi passi.

### 4.1 Crea casella email su Aruba

- Crea casella: `noreply@<tuo-dominio>.eu`
- Scegli password dedicata forte (solo server-side)
- Usa come reply-to: `xx.xx@unipa.it`

### 4.2 Crea secret Edge per SMTP Aruba

Imposta in TEST e PROD:
- SMTP_HOST (es. `smtp.aruba.it`)
- SMTP_PORT (tipico `465` SSL oppure `587` STARTTLS)
- SMTP_SECURE (`true` con 465, `false` con 587)
- SMTP_USER (`noreply@<tuo-dominio>.eu`)
- SMTP_PASS (password casella)
- SMTP_FROM_EMAIL (`noreply@<tuo-dominio>.eu`)
- SMTP_REPLY_TO (`xx.xx@unipa.it`)

Esempio:

```bash
supabase secrets set SMTP_HOST="smtp.aruba.it" --project-ref <TEST_REF>
supabase secrets set SMTP_PORT="465" --project-ref <TEST_REF>
supabase secrets set SMTP_SECURE="true" --project-ref <TEST_REF>
supabase secrets set SMTP_USER="noreply@<tuo-dominio>.eu" --project-ref <TEST_REF>
supabase secrets set SMTP_PASS="<PASSWORD_CASELLA>" --project-ref <TEST_REF>
supabase secrets set SMTP_FROM_EMAIL="noreply@<tuo-dominio>.eu" --project-ref <TEST_REF>
supabase secrets set SMTP_REPLY_TO="xx.xx@unipa.it" --project-ref <TEST_REF>

supabase secrets set SMTP_HOST="smtp.aruba.it" --project-ref <PROD_REF>
supabase secrets set SMTP_PORT="465" --project-ref <PROD_REF>
supabase secrets set SMTP_SECURE="true" --project-ref <PROD_REF>
supabase secrets set SMTP_USER="noreply@<tuo-dominio>.eu" --project-ref <PROD_REF>
supabase secrets set SMTP_PASS="<PASSWORD_CASELLA>" --project-ref <PROD_REF>
supabase secrets set SMTP_FROM_EMAIL="noreply@<tuo-dominio>.eu" --project-ref <PROD_REF>
supabase secrets set SMTP_REPLY_TO="xx.xx@unipa.it" --project-ref <PROD_REF>
```

### 4.3 Implementa invio email nella Edge function

In notifiche-invia:
- selezionare destinatari con email_stato = in_coda e email_programmata_per <= CURRENT_DATE
- recuperare email utente da anagrafica
- inviare con API Resend
- aggiornare notifiche_destinatari:
  - successo: email_stato = inviata, email_inviata_at = now(), email_errore = null, email_tentativi = email_tentativi + 1
  - errore: email_stato = fallita, email_errore = <messaggio>, email_tentativi = email_tentativi + 1
- aggiornare notifiche_messaggi.stato in base a push+email aggregate

Implementazione completata in [supabase/edge-functions/notifiche-invia/index.ts](../edge-functions/notifiche-invia/index.ts):
- invio email reale via SMTP (Aruba)
- aggiornamento stati `email_stato`, `email_inviata_at`, `email_errore`, `email_tentativi`
- fallback errore esplicito se secret SMTP mancanti
- il canale push resta operativo e indipendente dal canale email

### 4.4 Test tecnico SMTP Aruba

- invio email di prova a un indirizzo interno
- verifica dominio mittente e DNS SPF/DKIM del provider Aruba

Deploy funzione dopo patch:

```bash
supabase functions deploy notifiche-invia --project-ref <TEST_REF>
supabase functions deploy notifiche-invia --project-ref <PROD_REF>
```

Verifica rapida post-deploy (manual trigger worker):

```bash
curl -i "https://<PROJECT_REF>.supabase.co/functions/v1/notifiche-invia" \
  -H "Content-Type: application/json" \
  -H "apikey: <PUBLISHABLE_KEY>" \
  -H "x-cron-secret: <NOTIFICHE_CRON_SECRET>" \
  -d '{"azione":"processa_coda"}'
```

Query esito email (ultimi messaggi):

```sql
SELECT
  d.messaggio_id,
  d.email_stato,
  count(*) AS totale,
  max(d.email_inviata_at) AS ultima_email_inviata_at
FROM public.notifiche_destinatari d
GROUP BY d.messaggio_id, d.email_stato
ORDER BY d.messaggio_id DESC, d.email_stato;
```

## 5) FlutterFire non funziona: percorso alternativo

Se flutterfire configure non parte, non e bloccante se questi file sono gia presenti e coerenti:
- android/app/google-services.json
- ios/Runner/GoogleService-Info.plist
- lib/configurazione/firebase_options.dart
- web/firebase-messaging-sw.js

Checklist pratica:
1. Controlla che Android packageName in Firebase corrisponda a applicationId Android.
2. Controlla che iOS bundleId in Firebase corrisponda a PRODUCT_BUNDLE_IDENTIFIER iOS.
3. Verifica APNs key caricata su Firebase (iOS).
4. Esegui pulizia e rebuild locale:

```bash
flutter clean
flutter pub get
flutter run -d <device>
```

Se vuoi riparare il comando flutterfire:

```bash
dart pub global activate flutterfire_cli
export PATH="$PATH:$HOME/.pub-cache/bin"
flutterfire --version
```

Se continua a fallire, usa:

```bash
dart pub global run flutterfire_cli:flutterfire configure
```

## 6) Messaggio programmato: quando parte

Regola corrente:
- il messaggio parte quando notifiche-invia viene invocata senza messaggio_id
- e programmata_per <= now()

Quindi, con cron giornaliero, parte alla prima esecuzione utile dopo l'orario programmato.

Test rapido senza aspettare cron:
- crea un messaggio programmato con orario passato di pochi minuti
- invoca manualmente la funzione come cron (x-cron-secret)

Esempio HTTP:

```bash
curl -i "https://<PROJECT_REF>.supabase.co/functions/v1/notifiche-invia" \
  -H "Content-Type: application/json" \
  -H "apikey: <PUBLISHABLE_KEY>" \
  -H "x-cron-secret: <NOTIFICHE_CRON_SECRET>" \
  -d '{"azione":"processa_coda"}'
```

## 7) Collaudo funzionale minimo (TEST)

### Caso A - Solo push
- Crea messaggio manuale con invia_push=true, invia_email=false.
- Atteso: destinatari con push_stato valorizzato; email_stato non_richiesta.

### Caso B - Solo email
- Crea messaggio manuale con invia_push=false, invia_email=true.
- Atteso: email_stato in_coda (o inviata se worker email attivo), push_stato non_richiesta.

### Caso C - Push + email
- Crea messaggio con entrambi true.
- Atteso: push inviato e email in coda/inviata secondo worker.

### Caso D - Programmato
- Imposta programmata_per futuro breve.
- Invoca processa_coda manuale (oppure attendi cron).
- Atteso: invio al primo run utile.

Query verifica:

```sql
SELECT
  d.messaggio_id,
  d.push_stato,
  d.email_stato,
  count(*) AS totale
FROM public.notifiche_destinatari d
GROUP BY d.messaggio_id, d.push_stato, d.email_stato
ORDER BY d.messaggio_id DESC, d.push_stato, d.email_stato;
```

## 8) Osservabilita operativa minima

### 8.1 SQL dashboard giornaliera

```sql
SELECT
  CURRENT_DATE AS giorno,
  push_stato,
  email_stato,
  count(*) AS totale
FROM public.notifiche_destinatari
WHERE created_at::date >= CURRENT_DATE - 7
GROUP BY push_stato, email_stato
ORDER BY push_stato, email_stato;
```

```sql
SELECT
  email_programmata_per,
  count(*) AS in_coda
FROM public.notifiche_destinatari
WHERE email_stato = 'in_coda'
GROUP BY email_programmata_per
ORDER BY email_programmata_per;
```

### 8.2 Log Edge function

```bash
supabase functions logs notifiche-invia --project-ref <TEST_REF>
supabase functions logs notifiche-invia --project-ref <PROD_REF>
```

### 8.3 Alert minimi consigliati

- fallita push > soglia giornaliera
- email in_coda con email_programmata_per < CURRENT_DATE - 1
- cron job failed nelle ultime 24h

## 9) Gate finale go/no-go

Go solo se TUTTI i punti sotto sono verdi:

- [ ] Cron corretto (v2 presente, ogni-minuto assente)
- [ ] RLS e policy notifiche_dispositivi verificate
- [ ] RPC dispositivi presenti e grant authenticated ok
- [ ] Push end-to-end verificato su Android/iOS/Web target
- [ ] Email reale Resend implementata e testata (oppure canale email disabilitato esplicitamente)
- [ ] Collaudo casi A/B/C/D completato in TEST
- [ ] Nessun errore bloccante in log Edge nelle ultime 24h
- [ ] Evidenze condivise e approvazione al rollout PROD

No-go se uno qualsiasi dei punti sopra e rosso.

## 10) Sequenza secca TEST -> PROD

1. Esegui verifiche SQL sezione 1 e 2 su TEST.
2. Esegui collaudo sezione 7 su TEST.
3. Verifica osservabilita sezione 8 su TEST.
4. Gate go/no-go su TEST.
5. Ripeti sezione 1 e 2 su PROD.
6. Deploy (gia fatto) + sanity check logs su PROD.
7. Esegui collaudo ridotto su PROD (almeno A e D).
8. Gate finale go-live.
