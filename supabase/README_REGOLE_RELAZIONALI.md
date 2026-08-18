# Regole notifiche relazionali

Questa estensione non crea nuove tabelle. Usa `notifiche_regole.configurazione` (jsonb) per descrivere condizioni e destinatari su tabelle collegate.

## Installazione

1. Eseguire `03_NOTIFICHE_REGOLE_RELAZIONALI.sql` nel Supabase SQL Editor.
2. Sostituire `lib/pagine/backoffice/notifiche_regole_backoffice_page.dart` con il file incluso.
3. Fare un hot restart / riavvio dell'app. Non serve modificare `notifiche-invia`: la Edge Function continua a chiamare `notifiche_materializza_regole_temporali()` e `notifiche_genera_destinatari()`, che vengono aggiornate dallo script SQL.

## Esempio richiesto: prima visita

Nella maschera Regole impostare:

- Tipo attivazione: `data`
- Tabella principale: `insegnamenti`
- Campo data: il campo reale di inizio lezioni
- Offset giorni: `21`
- Condizione opzionale:
  - Tabella: `mentoraggi`
  - Campo: `data_visita_1`
  - Operatore: `is_null`
- Destinatari: `relazionale`
  - Tabella destinatari: `mentoraggio_mentori`
  - Campo user_id destinatario: `mentore_id`

La UI ricava dalle FK il percorso:

`insegnamenti.id = mentoraggi.insegnamento_id -> mentoraggi.id = mentoraggio_mentori.mentoraggio_id`

Il worker valuta ogni insegnamento separatamente. Se, trascorsi 21 giorni dalla data di inizio, esiste un mentoraggio collegato con `data_visita_1 IS NULL`, crea una notifica per quell'insegnamento e inserisce come destinatari i `mentore_id` collegati, filtrando sempre `anagrafica_riservata.attivo = true`.

## JSON salvato

La configurazione prodotta è concettualmente:

```json
{
  "tabella_principale": "insegnamenti",
  "campo_id_principale": "id",
  "solo_anno_corrente": true,
  "condizioni": [
    {
      "tabella": "mentoraggi",
      "campo": "data_visita_1",
      "operatore": "is_null",
      "percorso": [
        {
          "da_tabella": "insegnamenti",
          "da_campo": "id",
          "a_tabella": "mentoraggi",
          "a_campo": "insegnamento_id"
        }
      ]
    }
  ],
  "destinatari_relazionali": {
    "tabella": "mentoraggio_mentori",
    "campo_user_id": "mentore_id",
    "percorso": [
      {
        "da_tabella": "insegnamenti",
        "da_campo": "id",
        "a_tabella": "mentoraggi",
        "a_campo": "insegnamento_id"
      },
      {
        "da_tabella": "mentoraggi",
        "da_campo": "id",
        "a_tabella": "mentoraggio_mentori",
        "a_campo": "mentoraggio_id"
      }
    ]
  }
}
```

## Semantica delle condizioni

Le condizioni sono in AND. Per una condizione su una tabella collegata, la condizione è considerata vera se esiste almeno una riga collegata che la soddisfa.

Il sistema supporta: `is_null`, `not_null`, `eq`, `neq`, `true`, `false`.

## Nota sui percorsi multipli

La UI usa il percorso FK più corto tra tabella principale e tabella scelta. Nel database attuale questo rende automatico il percorso Insegnamenti -> Mentoraggi -> Mentoraggio Mentori. Se in futuro esistessero più percorsi FK alternativi tra le stesse tabelle, sarà opportuno aggiungere un selettore esplicito del percorso.
