import 'package:supabase_flutter/supabase_flutter.dart';

import 'dinamico/maschera_dinamica_controller.dart';

/// Configurazione unica della connessione a Supabase.
abstract final class SupabaseConfig {
  static SchemaDatabase? _schemaDatabase;
  static Future<SchemaDatabase>? _caricamentoSchema;
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dwzmuxlwndsctkhrmuzt.supabase.co',
  );
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_jgZAFuXc36RinuKub400zw_hFog6atv',
  );

  /// Inizializza Supabase prima dell'avvio dell'app.
  static Future<void> inizializza() async {
    if (url.trim().isEmpty || publishableKey.trim().isEmpty) {
      throw StateError(
        'Configurazione Supabase mancante. Avvia l’app passando '
        'SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY con --dart-define.',
      );
    }

    final Uri? indirizzo = Uri.tryParse(url);
    if (indirizzo == null || !indirizzo.hasScheme || !indirizzo.hasAuthority) {
      throw StateError('SUPABASE_URL non contiene un indirizzo valido.');
    }

    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  /// Client condiviso usato dai controller delle singole pagine.
  static SupabaseClient get client => Supabase.instance.client;

  /// Ultima struttura del database caricata tramite la RPC Supabase.
  static SchemaDatabase? get schemaDatabase => _schemaDatabase;

  /// Legge tabelle, colonne, tipi, enum e chiavi esterne dello schema `public`.
  ///
  /// La funzione `app_database_schema` va installata una sola volta eseguendo
  /// `supabase/schema_dinamico.sql` nel SQL Editor del progetto Supabase.
  static Future<SchemaDatabase> caricaSchemaDatabase({
    bool forzaAggiornamento = false,
  }) {
    if (!forzaAggiornamento && _schemaDatabase != null) {
      return Future<SchemaDatabase>.value(_schemaDatabase);
    }
    if (!forzaAggiornamento && _caricamentoSchema != null) {
      return _caricamentoSchema!;
    }

    final caricamento = _leggiSchemaDatabase();
    _caricamentoSchema = caricamento;
    return caricamento.whenComplete(() {
      if (identical(_caricamentoSchema, caricamento)) {
        _caricamentoSchema = null;
      }
    });
  }

  static Future<SchemaDatabase> _leggiSchemaDatabase() async {
    final dynamic risposta = await client.rpc('app_database_schema');
    if (risposta is! Map) {
      throw const FormatException(
        'La funzione app_database_schema ha restituito dati non validi.',
      );
    }
    final schema = SchemaDatabase.fromJson(Map<String, dynamic>.from(risposta));
    _schemaDatabase = schema;
    return schema;
  }
}
