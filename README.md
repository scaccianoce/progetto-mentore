# Progetto Mentore

Applicazione Flutter multipiattaforma collegata a Supabase.

## Maschere dinamiche

L'app può leggere la struttura delle tabelle dello schema `public` e generare
campi di modifica coerenti per testo, numeri, date, booleani, enum PostgreSQL e
chiavi esterne.

1. Eseguire una volta
   [`supabase/schema_dinamico.sql`](supabase/schema_dinamico.sql) nel SQL Editor
   del progetto Supabase.
2. La funzione è accessibile solo agli utenti `authenticated` e restituisce
   esclusivamente metadati, non righe delle tabelle.
3. `SupabaseConfig.caricaSchemaDatabase()` carica e mantiene in cache la
   struttura completa.
4. `mostraMascheraDinamica(...)` costruisce la maschera richiesta dalla pagina.

La pagina Mentore usa già il sistema per modificare `mentoraggi`. Se la RPC non
è stata ancora installata, la maschera usa una definizione provvisoria ricavata
dalla riga caricata e continua a funzionare.

### Tipi grafici definiti nei commenti Supabase

PostgreSQL non può distinguere da solo un testo breve da uno multiriga. Si può
aggiungere questa informazione con commenti sulle colonne:

```sql
comment on column public.news.testo is
  '@app:label=Contenuto @app:formatted';
comment on column public.eventi.note_organizzative is
  '@app:multiline';
comment on column public.eventi.created_at is
  '@app:readonly';
```

Direttive disponibili:

- `@app:multiline`: testo multiriga;
- `@app:formatted`: usa `EditorTestoFormattato`;
- `@app:hidden`: non mostra il campo;
- `@app:readonly`: non consente la modifica;
- `@app:label=...`: etichetta personalizzata.

Le definizioni, il caricamento dello schema e le eccezioni lato applicazione
sono raccolti in `lib/dinamico/maschera_dinamica_controller.dart`; tutti i
componenti Flutter sono in `lib/dinamico/maschera_dinamica_widget.dart`. Le
scelte definite come enum e quelle collegate ad altre tabelle tramite foreign
key vengono rilevate automaticamente.

I layout riutilizzabili delle pagine sono separati in `lib/pagine/template/`:

- `template_elenco_dettaglio_page.dart` per elenchi con record selezionato;
- `template_scheda_page.dart` per profili e record singoli.
