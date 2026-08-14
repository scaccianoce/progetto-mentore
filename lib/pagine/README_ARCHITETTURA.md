# Architettura delle pagine dinamiche

## Obiettivo

Una nuova pagina standard deve richiedere quasi soltanto:

1. titolo;
2. tabella Supabase;
3. eventuali eccezioni dei campi;
4. per elenco+dettaglio, il campo da usare come titolo dell'elenco.

La regola pratica e:

**default automatici -> configurazione delle sole eccezioni -> CRUD generico -> controller specifico solo per vera logica di dominio.**

## I livelli

### 1. Template di layout

- `template_scheda_page.dart`: layout di una scheda singola.
- `template_elenco_dettaglio_page.dart`: layout responsivo elenco + dettaglio.
- Il terzo template futuro deve seguire lo stesso principio: solo layout.

I template NON devono conoscere News, Profilo, Eventi, Mentee, ecc.

### 2. Pagine dinamiche standard

- `pagina_scheda_dinamica.dart`: visualizzazione dinamica di una Map.
- `pagina_scheda_crud_dinamica.dart`: scheda singola con CRUD standard completo.
- `pagina_elenco_dettaglio_crud_dinamica.dart`: elenco+dettaglio con CRUD standard completo.
- `componenti_pagina_dinamica.dart`: componenti riusabili di intestazione, elenco e dettaglio.

Questi file contengono il boilerplate che NON va duplicato nelle nuove pagine.

### 3. Configurazione dinamica

`ConfigurazionePaginaDinamica` indica la tabella e soltanto i campi speciali.

Un campo normale NON va elencato.

Le etichette sono automatiche:

`anno_accademico` -> `Anno accademico`

`id`, `created_at`, `updated_at` sono nascosti globalmente.

Le personalizzazioni condivise da una tabella stanno in
`ConfigurazioneMaschere.tabelle`.

### 4. Accesso dati e CRUD

- `repository_dinamico.dart`: accesso Supabase comune.
- `controller_crud_dinamico.dart`: stato e operazioni CRUD standard per:
  - elenco+dettaglio;
  - scheda singola.

Non creare un nuovo controller se deve soltanto duplicare `select`, `insert`,
`update`, `delete`, caricamento, salvataggio e gestione errori.

## Esempio minimo: nuova scheda standard

```dart
return PaginaSchedaCrudDinamica(
  titolo: 'Pubblicazione',
  configurazione: const ConfigurazionePaginaDinamica(
    tabella: 'pubblicazioni',
  ),
  filtri: <FiltroDinamico>[
    FiltroDinamico('user_id', sessione.utente!.id),
  ],
);
```

Se `pubblicazioni` contiene nuovi campi, questi vengono mostrati automaticamente.

Se serve una sola eccezione:

```dart
const configurazione = ConfigurazionePaginaDinamica(
  tabella: 'pubblicazioni',
  campi: <String, PersonalizzazioneCampo>{
    'abstract': PersonalizzazioneCampo(
      tipo: TipoCampoDinamico.testoMultiriga,
    ),
  },
);
```

## Esempio minimo: nuovo elenco + dettaglio standard

```dart
return const PaginaElencoDettaglioCrudDinamica(
  titolo: 'Pubblicazioni',
  configurazione: ConfigurazionePaginaDinamica(
    tabella: 'pubblicazioni',
  ),
  campoTitolo: 'titolo',
);
```

Filtri, ordinamenti, valori iniziali e poche eccezioni possono essere aggiunti
senza creare un controller dedicato.

## Pagine attuali

### CRUD standard completo

**News** usa ora `PaginaElencoDettaglioCrudDinamica` e non possiede piu un
`news_controller.dart` specifico. Restano nella pagina soltanto configurazione,
filtro per i partecipanti, ordinamento e validazione minima del payload.

### CRUD generico + logica specifica

**Insegnamento** mantiene `insegnamento_controller.dart`, ma il controller non
esegue piu direttamente il CRUD. Usa `ControllerSchedaCrudDinamico` e conserva
soltanto la vera logica di dominio:

- individuare l'anno accademico corrente;
- legarlo all'utente corrente.

### Controller specifici da mantenere

Restano specifici perche coordinano logica applicativa reale:

- Eventi: iscrizione/cancellazione e workflow evento;
- House of Mentore: opzioni e iscrizioni;
- Mentee: team, assegnazioni e piu tabelle;
- Mentore: mentoraggi e relazioni fra tabelle;
- Profilo: liste di scelta collegate e permessi/richiesta di modifica.

## Contatti: eccezione di sicurezza

`ContattiPage` usa `anagrafica`, ma NON deve fare `select()` automatico di tutte
le colonne. Il controller mantiene `colonnePubbliche`, cioe la whitelist dei soli
dati che e lecito mostrare nella rubrica.

Questa e una scelta intenzionale: l'automatismo non deve provocare esposizione
accidentale di dati personali.

## Quando personalizzare un campo

Aggiungere un campo alla configurazione soltanto se serve almeno una di queste
caratteristiche:

- nascosto / sola lettura;
- visibilita o modifica diversa per partecipante;
- tipo UI diverso da quello dedotto dal database;
- valori di scelta;
- etichetta non deducibile, ad esempio `cfu` -> `CFU`.

## Regola per le future pagine

Prima di creare `qualcosa_controller.dart`, verificare se la pagina puo essere
espressa usando uno dei due controller CRUD generici. Un controller specifico e
giustificato soltanto se contiene una regola di dominio che non appartiene al
CRUD standard.


## Regola: nessun elenco di dominio nel codice Dart

I valori dei campi a scelta non devono essere scritti nel frontend. Se una
colonna ha un insieme chiuso di valori, definirla come PostgreSQL ENUM nel DB:
`app_database_schema` espone `enum_values` e il motore genera automaticamente
il menu. Liste provenienti da entita relazionali (per esempio SSD o anni
accademici) devono essere lette dalle relative tabelle del DB. Se un elenco non
esiste nel database, va creato nel database prima di usarlo nell'interfaccia.


## Convenzioni automatiche dai tipi PostgreSQL

Il widget del campo viene scelto dal tipo reale restituito da `app_database_schema`:

- `text` -> testo multiriga;
- `varchar` / `character varying` -> testo breve;
- `boolean` -> switch;
- `date` -> selettore data;
- `timestamp` -> selettore data/ora;
- tipi interi -> numero intero;
- `numeric`, `decimal`, `real`, `double precision` -> numero decimale;
- `json`, `jsonb`, array -> editor JSON;
- PostgreSQL ENUM -> menu di scelta con valori letti dal DB;
- foreign key riconosciuta -> relazione.

Le pagine non devono dichiarare manualmente un `TipoCampoDinamico` quando il tipo e gia deducibile dallo schema. Restano ammesse solo eccezioni semantiche reali, per esempio `testoFormattato`.

## Relazioni: nessun campo descrittivo hard-coded

Per le foreign key il frontend non prova piu in sequenza campi come `titolo`,
`nome`, `codice` o `email`. La tabella referenziata deve dichiarare nel proprio
COMMENT PostgreSQL la colonna da usare come etichetta:

```sql
COMMENT ON TABLE public.nome_tabella IS '@app:display=nome_colonna';
```

`app_database_schema` deve continuare a restituire il commento della tabella.
Se la direttiva manca, viene mostrato il valore della chiave referenziata.

## Backoffice

La vecchia pagina monolitica `amministrazione_page.dart` e ora solo un wrapper
compatibile con il router. Le sezioni amministrative sono in
`lib/pagine/backoffice/` e devono restare moduli separati. Il prossimo
refactoring puo quindi trasformare progressivamente ciascuna sezione standard
in configurazione CRUD dinamica, lasciando specifici soltanto i workflow
(ammissioni, assegnazioni, cambio anno corrente, ecc.).
