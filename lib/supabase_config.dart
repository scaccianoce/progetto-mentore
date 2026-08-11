import 'package:supabase_flutter/supabase_flutter.dart';

/// Configurazione unica della connessione a Supabase.
abstract final class SupabaseConfig {
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
}
