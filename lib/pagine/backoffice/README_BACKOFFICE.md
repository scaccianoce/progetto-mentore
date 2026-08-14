# Backoffice

Il backoffice e separato dal frontend ordinario e segue due livelli di permesso.

## Owner

L'owner vede anche **Database**. Le tab vengono generate automaticamente da
`app_database_schema`: una tab per ogni tabella disponibile. Il frontend non
contiene l'elenco `Partecipanti / Abilitazioni / Anni / Mentori` e non deve
essere aggiornato quando viene aggiunta una nuova tabella.

## Owner + organizer

Entrambi vedono:

- **Partecipanti**: coordinamento di `anagrafica`, `anagrafica_riservata` e
  `user_roles`. L'elevazione del ruolo applicativo resta owner-only per evitare
  escalation di privilegi; le RLS del database restano comunque il controllo
di sicurezza definitivo.
- **Anni accademici**: creazione anno, anno corrente, riepilogo KPI ed
  esportazione strutturata dei dati dell'anno.
- **Controllo**: stato per partecipante di mentoraggi, eventi e House of Mentore.
- **Notifiche**: CRUD delle notifiche manuali/programmate/automatiche.

La sintesi degli anni accademici e il controllo partecipanti vengono costruiti interrogando direttamente le tabelle reali del database; il frontend non dipende da `backoffice_riepilogo_anni`.

## Push sullo smartphone

La cartella `/lib` da sola non contiene `pubspec.yaml`, configurazioni Android/
iOS e credenziali FCM/APNs. Per questo la v7 prepara il modello dati e il centro
notifiche, ma la richiesta di autorizzazione sul dispositivo e l'invio push
vanno collegati nel progetto Flutter completo (tipicamente Firebase Messaging +
APNs/FCM + Edge Function server). Le credenziali server non devono stare nel
client Flutter.

## Solleciti mentoraggio

`BACKOFFICE_DATABASE.sql` include una funzione schedulabile
`genera_solleciti_mentoraggio`: usa `data_inizio_lezioni` e
`data_fine_lezioni`, verifica almeno due visite e il focus group prima della
fine. La funzione crea notifiche deduplicate; l'invio push resta responsabilita
del worker server/Edge Function.


## Navigazione v7.2

Le funzioni di gestione non sono piu raccolte in una singola pagina Amministrazione.
Sono voci autonome nella barra laterale sotto GESTIONE:

- Database: solo owner.
- Partecipanti: owner + organizer.
- Anni accademici: owner + organizer.
- Controllo partecipanti: owner + organizer.
- Notifiche: owner + organizer.

La pagina Anni accademici non usa `backoffice_riepilogo_anni`: le statistiche
sono calcolate direttamente dalle tabelle del database. L'esportazione prepara
un CSV separato per ciascuna tabella coinvolta, usando i valori grezzi del DB.

## Gestione utenti Authentication

La creazione e il reset password NON devono usare la service role nel client Flutter.
La pagina Partecipanti invoca la Edge Function `backoffice-user-admin`.
Il sorgente di riferimento e in `EDGE_FUNCTION_USER_ADMIN.ts`.

Permessi server-side:
- owner e organizer possono creare un nuovo utente participant;
- organizer puo reimpostare la password solo di utenti participant;
- owner puo reimpostare la password di qualunque utente applicativo.

La funzione crea l'utente in Supabase Authentication e inserisce direttamente `anagrafica`, `anagrafica_riservata` e `user_roles` con ruolo `participant`, senza dipendere da una RPC di creazione.


## Tab Users (auth.users)

La pagina `Gestione -> Database`, solo owner, include una tab virtuale `Users`.
Non usa PostgREST su `auth.users`: chiama la Edge Function `backoffice-user-admin`,
che usa `auth.admin.listUsers()` lato server. La stessa funzione gestisce modifica email,
conferma email, reset password, disabilitazione/riabilitazione ed eliminazione Auth.

Dopo modifiche a `EDGE_FUNCTION_USER_ADMIN.ts`, deployare la funzione su Supabase.
Se il browser mostra il contenuto di `web/index.html`, la richiesta non sta raggiungendo
la Edge Function corretta: verificare il deploy della funzione e `SUPABASE_URL`.

## Consolidamento finale - utenti

La creazione di un nuovo partecipante non dipende piu dalla RPC
`backoffice_crea_partecipante`. La Edge Function crea direttamente, con service
role lato server:

1. `auth.users` con email e password temporanea;
2. `anagrafica` con lo stesso `user_id` Auth;
3. `anagrafica_riservata` con `attivo = true`;
4. `user_roles` con ruolo `participant`.

Se una delle scritture applicative fallisce, la funzione esegue una pulizia
compensativa delle righe gia create e dell'utente Auth. I valori nulli non
necessari vengono omessi per non annullare i DEFAULT PostgreSQL.

La modifica di `email_unipa` dal backoffice sincronizza anche l'email di
Supabase Authentication tramite l'azione `update_participant_email`.
La cancellazione dalla pagina Partecipanti passa dalla Edge Function e rimuove
anche l'utente Auth, salvo vincoli FK/storici che bloccano correttamente la
cancellazione.

### Deploy obbligatorio

Il file `EDGE_FUNCTION_USER_ADMIN.ts` e solo il sorgente di riferimento. Per
rendere operative creazione utente, tab Users, reset password e sincronizzazione
email deve essere copiato/deployato come Edge Function Supabase con nome esatto:

`backoffice-user-admin`

La `SUPABASE_SERVICE_ROLE_KEY` deve restare esclusivamente nell'ambiente server
della Edge Function e non deve mai essere inserita nel codice Flutter.
