import '../../../dati/repository.dart';
import '../../../ui/dinamico_schema.dart';

/// Controller della pagina Database del backoffice.
///
/// E' volutamente generico: il nome della tabella arriva dalla UI costruita
/// dallo schema DB. Tutte le operazioni passano dal [DatabaseRepository].
class DatabaseBackofficeController {
  DatabaseBackofficeController({
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  static const String _funzioneAdmin = 'backoffice-user-admin';

  final DatabaseRepository db;

  /// Ricarica lo schema ignorando la cache.
  Future<SchemaDatabase> caricaSchema() =>
      SchemaDatabase.carica(
        database: db,
        forzaAggiornamento: true,
      );

  /// Restituisce i nomi delle sole tabelle base.
  Future<Set<String>?> caricaTabelleBase() async {
    try {
      final risposta = await db.rpc(
        'app_database_base_tables',
      );

      if (risposta is! List) return null;

      return risposta
          .map((e) => e is Map ? e['name'] : e)
          .where((e) => e != null)
          .map((e) => e.toString())
          .toSet();
    } catch (_) {
      return null;
    }
  }

  /// Carica al massimo 500 record dalla tabella indicata.
  Future<List<Map<String, dynamic>>> caricaTabella(
    String tabella,
  ) =>
      db.tabella(tabella).elenco(limite: 500);

  /// Inserisce un record nella tabella indicata.
  Future<void> inserisci(
    String tabella,
    Map<String, dynamic> valori,
  ) async {
    await db.tabella(tabella).inserisci(
      valori,
      colonne: '*',
    );
  }

  /// Aggiorna il record identificato dalla chiave primaria.
  Future<void> aggiorna(
    String tabella,
    Map<String, dynamic> valori,
    Map<String, dynamic> chiave,
  ) async {
    await db.tabella(tabella).aggiorna(
      valori,
      filtri: <FiltroDb>[
        for (final voce in chiave.entries)
          FiltroDb.uguale(voce.key, voce.value),
      ],
      colonne: '*',
    );
  }

  /// Elimina il record identificato dalla chiave primaria.
  Future<void> elimina(
    String tabella,
    Map<String, dynamic> chiave,
  ) =>
      db.tabella(tabella).elimina(
        filtri: <FiltroDb>[
          for (final voce in chiave.entries)
            FiltroDb.uguale(voce.key, voce.value),
        ],
      );

  /// Invoca la Edge Function amministrativa per `auth.users`.
  Future<Map<String, dynamic>> invocaUserAdmin(
    Map<String, dynamic> corpo,
  ) async {
    final raw = await db.invocaFunzione(
      _funzioneAdmin,
      corpo: corpo,
    );

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return <String, dynamic>{};
  }
}
