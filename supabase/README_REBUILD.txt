SUPABASE REBUILD MASTER - PROG MENTORE
======================================

SCOPO
-----
Ricostruire la STRUTTURA applicativa in un NUOVO progetto Supabase vuoto,
senza copiare dati applicativi né utenti Authentication.

IMPORTANTE
----------
NON eseguire questi script sul progetto di produzione attuale.
Gli script sono destinati a un NUOVO progetto Supabase.

ORDINE DI ESECUZIONE SUL NUOVO PROGETTO
---------------------------------------
01_extensions.sql
02_enums.sql
03_tables.sql
04_constraints.sql
05_indexes.sql
06_functions.sql
07_views.sql
08_triggers.sql
09_rls_policies.sql
10_grants_tables.sql
11_grants_functions.sql
12_storage_buckets.sql

PRIMA DEL CRON
--------------
Creare nel Vault del NUOVO progetto i secrets indicati in:
docs/SECRETS_REQUIRED.txt

Poi:
13_cron.sql
13b_OTHER_correzioni.sql

Infine:
14_verify.sql

AUTH
----
La struttura standard auth.* NON va ricreata: viene generata da Supabase.
Vedi docs/AUTH_CHECKLIST.txt per le impostazioni Dashboard da replicare.

STORAGE
-------
Le tabelle standard storage.* NON vanno ricreate.
12_storage_buckets.sql ricrea solo i bucket applicativi.
09_rls_policies.sql contiene anche le policy custom su storage.objects.
Nessun file fisico viene copiato.

EDGE FUNCTIONS
--------------
NON possono essere ricostruite dai metadati PostgreSQL.
Vedi edge-functions/README.txt.
Serve ancora raccogliere dal Dashboard il sorgente ATTUALE di ciascuna funzione.

LIMITI / VERIFICHE
------------------
1. Il pacchetto è stato generato dai metadati forniti tramite CSV.
2. Le impostazioni Dashboard non rappresentate nel DB (Auth, URL, secrets,
   configurazioni Edge, eventuali Realtime settings) richiedono verifica manuale.
3. I GRANT sulle funzioni sono ricostruiti associando i grant esportati alle
   firme delle funzioni inventariate. È opportuno eseguire 14_verify.sql e
   confrontare con il progetto sorgente prima dell'uso reale.
4. I valori dei secrets non sono e non devono essere inclusi nel pacchetto.
