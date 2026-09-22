# Web App Google Apps Script

Il file `google_sheet_sync.gs` è il destinatario delle richieste inviate dalla
Edge Function `mentoraggi-google-sheet`.

## Configurazione

1. Creare un progetto Google Apps Script e incollare il contenuto di
   `google_sheet_sync.gs`.
2. In **Impostazioni progetto > Proprietà script** aggiungere la proprietà
   `GOOGLE_SCRIPT_SECRET`.
3. Scegliere personalmente un valore lungo e casuale per la proprietà. Non è
   una chiave fornita da Google: è una password condivisa fra Apps Script e
   l'app. Inserire lo stesso valore nel campo **Google Script secret** della
   pagina di configurazione.
4. Distribuire lo script come **App web**, eseguita dall'account proprietario e
   accessibile a chiunque possa raggiungere l'URL. La richiesta rimane protetta
   dal secret condiviso.
5. Copiare nell'app l'URL della distribuzione che termina con `/exec` e il link
   del foglio Google. Se il link contiene `gid`, viene aggiornata quella
   specifica scheda; altrimenti viene usata la prima.

L'account che esegue la Web App deve avere accesso in modifica al foglio. Le
intestazioni devono coincidere con i nomi di colonna configurati nell'app. La
riga viene individuata tramite email e la stessa email deve comparire una sola
volta nel foglio.
