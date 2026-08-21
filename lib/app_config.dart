/// Configurazione applicativa centralizzata.
///
/// Per usare un progetto Supabase diverso non serve modificare i controller:
/// cambia soltanto i valori qui sotto oppure passali con --dart-define.
abstract final class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dwzmuxlwndsctkhrmuzt.supabase.co',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_jgZAFuXc36RinuKub400zw_hFog6atv',
  );

  /// URL pubblico dell'app web, usato per i link /q/ token .
  /// Se vuoto, sul Web viene usata automaticamente l'origine corrente.
  static const String publicAppUrl = String.fromEnvironment(
    'PUBLIC_APP_URL',
    defaultValue: '',
  );
}
