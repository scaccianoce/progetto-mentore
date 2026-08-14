VERSIONE FINALE - Progetto Mentore (lib + supporto Supabase)

1) Copiare la cartella lib/ nel progetto Flutter.

2) Logo:
   il file deve esistere in:
     assets/icon/menu_logo.png
   e pubspec.yaml deve includere, ad esempio:
     flutter:
       assets:
         - assets/icon/

3) Supabase SQL:
   verificare/eseguire le parti necessarie di:
     supabase/sql/BACKOFFICE_DATABASE.sql
   In particolare app_database_schema/app_database_base_tables e gli oggetti
   effettivamente usati dal proprio database.

4) Edge Function OBBLIGATORIA per Users/creazione partecipante/reset password:
   sorgente pronto in:
     supabase/functions/backoffice-user-admin/index.ts
   Il nome della funzione deve essere ESATTAMENTE:
     backoffice-user-admin

   Esempio con Supabase CLI (dal root del progetto Supabase):
     supabase functions deploy backoffice-user-admin

   Non inserire mai SUPABASE_SERVICE_ROLE_KEY nel client Flutter.

5) Dopo aver copiato i file:
     flutter pub get
     flutter analyze
     flutter run -d chrome

NOTE IMPORTANTI
- Nuovo partecipante: viene creato in Auth, anagrafica,
  anagrafica_riservata e user_roles (participant).
- Anno prima partecipazione salva il codice completo, es. 2014-15.
- Users in Gestione > Database e accessibile solo a owner e usa la Edge Function.
- Database e visibile solo a owner; le altre pagine Gestione previste sono
  visibili solo a owner/organizer.
