enum TipoCampoDinamico {
  testoBreve,
  testoMultiriga,
  testoFormattato,
  numeroIntero,
  numeroDecimale,
  data,
  dataOra,
  booleano,
  scelta,
  relazione,
  json,
}

class RelazioneDatabase {
  const RelazioneDatabase({required this.tabella, required this.colonna});

  final String tabella;
  final String colonna;

  factory RelazioneDatabase.fromJson(Map<String, dynamic> json) =>
      RelazioneDatabase(
        tabella: json['table'].toString(),
        colonna: json['column'].toString(),
      );
}

class CampoDatabase {
  const CampoDatabase({
    required this.nome,
    required this.tipoDatabase,
    required this.tipo,
    required this.posizione,
    required this.nullable,
    this.valorePredefinito,
    this.commento,
    this.valoriScelta = const <String>[],
    this.relazione,
    this.identita = false,
    this.generato = false,
    this.chiavePrimaria = false,
    this.etichettaPersonalizzata,
    this.nascosto = false,
    this.solaLettura = false,
    this.visibilePartecipante = true,
    this.modificabilePartecipante = true,
  });

  final String nome;
  final String tipoDatabase;
  final TipoCampoDinamico tipo;
  final int posizione;
  final bool nullable;
  final String? valorePredefinito;
  final String? commento;
  final List<String> valoriScelta;
  final RelazioneDatabase? relazione;
  final bool identita;
  final bool generato;
  final bool chiavePrimaria;
  final String? etichettaPersonalizzata;
  final bool nascosto;
  final bool solaLettura;
  final bool visibilePartecipante;
  final bool modificabilePartecipante;

  String get etichetta => etichettaPersonalizzata ?? _titoloDaNome(nome);

  bool get modificabile => !nascosto && !solaLettura && !identita && !generato;

  bool visibilePer({required bool partecipante}) =>
      !nascosto && (!partecipante || visibilePartecipante);

  bool modificabilePer({required bool partecipante}) =>
      modificabile &&
      (!partecipante || (visibilePartecipante && modificabilePartecipante));

  CampoDatabase copyWith({
    TipoCampoDinamico? tipo,
    List<String>? valoriScelta,
    String? etichettaPersonalizzata,
    bool? nascosto,
    bool? solaLettura,
    bool? visibilePartecipante,
    bool? modificabilePartecipante,
  }) => CampoDatabase(
    nome: nome,
    tipoDatabase: tipoDatabase,
    tipo: tipo ?? this.tipo,
    posizione: posizione,
    nullable: nullable,
    valorePredefinito: valorePredefinito,
    commento: commento,
    valoriScelta: valoriScelta ?? this.valoriScelta,
    relazione: relazione,
    identita: identita,
    generato: generato,
    chiavePrimaria: chiavePrimaria,
    etichettaPersonalizzata:
        etichettaPersonalizzata ?? this.etichettaPersonalizzata,
    nascosto: nascosto ?? this.nascosto,
    solaLettura: solaLettura ?? this.solaLettura,
    visibilePartecipante: visibilePartecipante ?? this.visibilePartecipante,
    modificabilePartecipante:
        modificabilePartecipante ?? this.modificabilePartecipante,
  );

  factory CampoDatabase.fromJson(
    Map<String, dynamic> json, {
    required Set<String> chiaviPrimarie,
  }) {
    final commento = json['comment']?.toString();
    final valoriScelta = (json['enum_values'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false);
    final relazioneJson = json['foreign_key'];
    final relazione = relazioneJson is Map
        ? RelazioneDatabase.fromJson(Map<String, dynamic>.from(relazioneJson))
        : null;
    final nome = json['name'].toString();

    return CampoDatabase(
      nome: nome,
      tipoDatabase: json['data_type']?.toString() ?? '',
      tipo: tipoCampoDaDatabase(
        json['data_type']?.toString() ?? '',
        commento: commento,
        haScelte: valoriScelta.isNotEmpty,
        haRelazione: relazione != null,
      ),
      posizione: (json['position'] as num?)?.toInt() ?? 0,
      nullable: json['nullable'] == true,
      valorePredefinito: json['default']?.toString(),
      commento: commento,
      valoriScelta: valoriScelta,
      relazione: relazione,
      identita: json['identity'] == true,
      generato: json['generated'] == true,
      chiavePrimaria: chiaviPrimarie.contains(nome),
      etichettaPersonalizzata: _direttiva(commento, 'label'),
      nascosto: _haDirettiva(commento, 'hidden'),
      solaLettura: _haDirettiva(commento, 'readonly'),
    );
  }
}

class TabellaDatabase {
  const TabellaDatabase({
    required this.nome,
    required this.campi,
    this.commento,
    this.tipoOggetto,
  });

  final String nome;
  final String? commento;
  final String? tipoOggetto;
  final List<CampoDatabase> campi;

  /// Indica se l'oggetto e una tabella fisica quando la RPC espone il tipo.
  bool? get eTabellaBase {
    final tipo = tipoOggetto?.trim().toUpperCase();
    if (tipo == null || tipo.isEmpty) return null;
    if (tipo == 'BASE TABLE' || tipo == 'TABLE' || tipo == 'R') return true;
    if (tipo.contains('VIEW') || tipo == 'V' || tipo == 'M') return false;
    return null;
  }

  CampoDatabase? campo(String nomeCampo) {
    for (final campo in campi) {
      if (campo.nome == nomeCampo) return campo;
    }
    return null;
  }

  /// Colonna da usare come etichetta nelle relazioni verso questa tabella.
  ///
  /// Non viene fatta alcuna ipotesi sui nomi dei campi. La scelta arriva
  /// esclusivamente dal COMMENT PostgreSQL della tabella, ad esempio:
  ///   COMMENT ON TABLE public.ssd IS '@app:display=codice';
  /// Se la direttiva manca o indica una colonna inesistente, il frontend usa
  /// la chiave della foreign key senza inventare un campo descrittivo.
  String? get nomeCampoDescrittivo {
    final nome = _direttiva(commento, 'display');
    if (nome == null || nome.isEmpty || campo(nome) == null) return null;
    return nome;
  }

  factory TabellaDatabase.fromJson(Map<String, dynamic> json) {
    final chiavi = (json['primary_key'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toSet();
    final campi =
        (json['columns'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (value) => CampoDatabase.fromJson(
                Map<String, dynamic>.from(value),
                chiaviPrimarie: chiavi,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.posizione.compareTo(b.posizione));
    return TabellaDatabase(
      nome: json['name'].toString(),
      commento: json['comment']?.toString(),
      tipoOggetto: (json['table_type'] ?? json['type'] ?? json['kind'])?.toString(),
      campi: campi,
    );
  }

  factory TabellaDatabase.daRiga(String nome, Map<String, dynamic> riga) =>
      TabellaDatabase(
        nome: nome,
        campi: riga.entries.indexed
            .map((elemento) {
              final (posizione, voce) = elemento;
              final valore = voce.value;
              final tipo = switch (valore) {
                bool _ => TipoCampoDinamico.booleano,
                int _ => TipoCampoDinamico.numeroIntero,
                double _ || num _ => TipoCampoDinamico.numeroDecimale,
                Map _ || List _ => TipoCampoDinamico.json,
                _ when voce.key.startsWith('data_') => TipoCampoDinamico.data,
                _ => TipoCampoDinamico.testoBreve,
              };
              return CampoDatabase(
                nome: voce.key,
                tipoDatabase: valore.runtimeType.toString(),
                tipo: tipo,
                posizione: posizione + 1,
                nullable: true,
                chiavePrimaria: voce.key == 'id',
              );
            })
            .toList(growable: false),
      );
}

class SchemaDatabase {
  const SchemaDatabase({required this.tabelle});

  final List<TabellaDatabase> tabelle;

  TabellaDatabase? tabella(String nome) {
    for (final tabella in tabelle) {
      if (tabella.nome == nome) return tabella;
    }
    return null;
  }

  factory SchemaDatabase.fromJson(Map<String, dynamic> json) => SchemaDatabase(
    tabelle: (json['tables'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (value) => TabellaDatabase.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(growable: false),
  );
}

TipoCampoDinamico tipoCampoDaDatabase(
  String tipoDatabase, {
  String? commento,
  bool haScelte = false,
  bool haRelazione = false,
}) {
  if (haRelazione) return TipoCampoDinamico.relazione;
  if (haScelte) return TipoCampoDinamico.scelta;
  if (_haDirettiva(commento, 'formatted')) {
    return TipoCampoDinamico.testoFormattato;
  }
  if (_haDirettiva(commento, 'multiline')) {
    return TipoCampoDinamico.testoMultiriga;
  }

  final tipo = tipoDatabase.toLowerCase();
  if (tipo == 'boolean') return TipoCampoDinamico.booleano;
  // Convenzione globale: PostgreSQL TEXT rappresenta contenuto libero e
  // viene quindi visualizzato/modificato automaticamente come multiriga.
  // VARCHAR / CHARACTER VARYING restano invece campi di testo breve.
  if (tipo == 'text') return TipoCampoDinamico.testoMultiriga;
  if (tipo == 'date') return TipoCampoDinamico.data;
  if (tipo.contains('timestamp')) return TipoCampoDinamico.dataOra;
  if (<String>{'smallint', 'integer', 'bigint'}.contains(tipo)) {
    return TipoCampoDinamico.numeroIntero;
  }
  if (<String>{
    'numeric',
    'decimal',
    'real',
    'double precision',
  }.contains(tipo)) {
    return TipoCampoDinamico.numeroDecimale;
  }
  if (tipo == 'json' || tipo == 'jsonb' || tipo.endsWith('[]')) {
    return TipoCampoDinamico.json;
  }
  return TipoCampoDinamico.testoBreve;
}

bool _haDirettiva(String? commento, String nome) => RegExp(
  '(?:^|\\s)@app:$nome(?:\\s|\$)',
  caseSensitive: false,
).hasMatch(commento ?? '');

String? _direttiva(String? commento, String nome) => RegExp(
  '@app:$nome=([^@\\n]+)',
  caseSensitive: false,
).firstMatch(commento ?? '')?.group(1)?.trim();

String _titoloDaNome(String nome) {
  if (nome.isEmpty) return nome;
  final testo = nome.replaceAll('_', ' ');
  return '${testo[0].toUpperCase()}${testo.substring(1)}';
}

class PersonalizzazioneCampo {
  const PersonalizzazioneCampo({
    this.tipo,
    this.etichetta,
    this.valoriScelta,
    this.nascosto,
    this.solaLettura,
    this.visibilePartecipante,
    this.modificabilePartecipante,
  });

  final TipoCampoDinamico? tipo;
  final String? etichetta;
  final List<String>? valoriScelta;
  final bool? nascosto;
  final bool? solaLettura;
  final bool? visibilePartecipante;
  final bool? modificabilePartecipante;
}

class ConfigurazionePaginaDinamica {
  const ConfigurazionePaginaDinamica({
    required this.tabella,
    this.campi = const <String, PersonalizzazioneCampo>{},
  });

  final String tabella;
  final Map<String, PersonalizzazioneCampo> campi;
}

/// Eccezioni puramente grafiche che non appartengono allo schema PostgreSQL.
///
/// Per nuove tabelle è preferibile usare i commenti descritti in
/// `supabase/schema_dinamico.sql`; questo registro serve per compatibilità e
/// per scelte specifiche dell'applicazione.
abstract final class ConfigurazioneMaschere {
  /// MODIFICA ARCHITETTURALE: convenzioni valide per tutte le tabelle.
  /// Una singola pagina puo comunque sovrascriverle nella propria configurazione.
  static const Map<String, PersonalizzazioneCampo> campiSistema = {
    'id': PersonalizzazioneCampo(nascosto: true),
    'created_at': PersonalizzazioneCampo(nascosto: true),
    'updated_at': PersonalizzazioneCampo(nascosto: true),
  };

  /// Personalizzazioni condivise da tutte le pagine che usano una tabella.
  /// Qui va solo cio che appartiene al dominio, non al layout della singola pagina.
  static const Map<String, Map<String, PersonalizzazioneCampo>> tabelle = {
    'mentoraggi': {
      'insegnamento_id': PersonalizzazioneCampo(nascosto: true),
      'scheda_sintesi': PersonalizzazioneCampo(
        tipo: TipoCampoDinamico.testoFormattato,
      ),
      // `stato` e `stato_mentoraggio` non dichiarano valori in Dart:
      // se sono campi a scelta devono essere PostgreSQL ENUM e le opzioni
      // vengono lette automaticamente da app_database_schema.
      'stato_mentoraggio': PersonalizzazioneCampo(
        etichetta: 'Stato mentoraggio',
      ),
    },
  };

  static TabellaDatabase applica(
    TabellaDatabase tabella, {
    ConfigurazionePaginaDinamica? pagina,
  }) {
    final configurazioneTabella = tabelle[tabella.nome] ??
        const <String, PersonalizzazioneCampo>{};
    final configurazionePagina = pagina?.tabella == tabella.nome
        ? pagina!.campi
        : const <String, PersonalizzazioneCampo>{};

    CampoDatabase applicaUna(
      CampoDatabase campo,
      PersonalizzazioneCampo? modifica,
    ) {
      if (modifica == null) return campo;
      final enumDaDatabase = campo.valoriScelta.isNotEmpty;
      return campo.copyWith(
        tipo: enumDaDatabase ? TipoCampoDinamico.scelta : modifica.tipo,
        etichettaPersonalizzata: modifica.etichetta,
        valoriScelta: enumDaDatabase
            ? campo.valoriScelta
            : modifica.valoriScelta,
        nascosto: modifica.nascosto,
        solaLettura: modifica.solaLettura,
        visibilePartecipante: modifica.visibilePartecipante,
        modificabilePartecipante: modifica.modificabilePartecipante,
      );
    }

    return TabellaDatabase(
      nome: tabella.nome,
      commento: tabella.commento,
      tipoOggetto: tabella.tipoOggetto,
      campi: tabella.campi.map((originale) {
        // Le personalizzazioni vengono applicate a strati invece di essere
        // sostituite come interi oggetti. Cosi una regola di pagina (es.
        // readonly per il mentee) non perde il tipo semantico condiviso
        // (es. scheda_sintesi = HTML).
        var campo = originale;
        campo = applicaUna(campo, campiSistema[campo.nome]);
        campo = applicaUna(campo, configurazioneTabella[campo.nome]);
        campo = applicaUna(campo, configurazionePagina[campo.nome]);
        return campo;
      }).toList(growable: false),
    );
  }
}
