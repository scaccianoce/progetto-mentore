# Elenchi gestiti dal database

Il frontend non deve contenere elenchi di dominio hard-coded.

## Campi che devono essere PostgreSQL ENUM

Verificare che nel database i seguenti campi usino un Database Enumerated Type,
cosi `app_database_schema` puo restituire automaticamente `enum_values`:

- `anagrafica.ruolo_accademico`
- `anagrafica.fascia_eta`
- `insegnamenti.semestre`
- `insegnamenti.anno_erogazione`
- `insegnamenti.svolgimento`
- `insegnamenti.gia_mentorato`
- `eventi.tipologia`
- `eventi.modalita`
- `mentoraggi.stato`
- `mentoraggi.stato_mentoraggio`
- `user_roles.role`
- `mentoraggio_mentori.tipo`

Se uno di questi elenchi non e presente nel DB, va creato nel database: il
frontend non fornisce piu valori sostitutivi.

## Elenchi letti da tabelle

Questi non devono diventare array Dart; sono gia caricati dal database:

- SSD: tabella `ssd`, colonna `cod_ssd`
- anni accademici: tabella `anni_accademici`, colonna `codice`

Gli altri elenchi relazionali sono costruiti dalle relative tabelle/foreign key.
