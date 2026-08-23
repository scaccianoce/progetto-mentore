// ============================================================================
// CONFIGURAZIONE AMBIENTE APPLICAZIONE
//
// Per scegliere il database:
//   AppEnvironment.produzione
//   AppEnvironment.test
//
// ATTENZIONE:
// utilizzare esclusivamente Publishable Key.
// Non inserire mai Service Role Key o Secret Key.
// ============================================================================

enum AppEnvironment {
  produzione,
  test,
}

abstract final class AppConfig {
  // ==========================================================================
  // AMBIENTE UTILIZZATO
  //
  // Cambia SOLO questa riga per passare da produzione a test.
  // ==========================================================================

  static const AppEnvironment ambiente =
      //AppEnvironment.produzione;
      AppEnvironment.test;

  // ==========================================================================
  // SUPABASE - PRODUZIONE
  // ==========================================================================

  static const String _supabaseUrlProduzione =
      'https://dwzmuxlwndsctkhrmuzt.supabase.co';

  static const String _supabasePublishableKeyProduzione =
      'sb_publishable_jgZAFuXc36RinuKub400zw_hFog6atv';

  // ==========================================================================
  // SUPABASE - TEST
  //
  // Inserisci qui URL e Publishable Key del progetto Supabase di prova.
  // ==========================================================================

  static const String _supabaseUrlTest =
      'https://yjcoldhertzaaypkyjlj.supabase.co';

  static const String _supabasePublishableKeyTest =
      'sb_publishable_AHMH2kgXjLlyp2_f46H1cA_SKNnfbfp';

  // ==========================================================================
  // CONFIGURAZIONE SUPABASE EFFETTIVAMENTE UTILIZZATA
  // ==========================================================================

  static const String supabaseUrl =
      ambiente == AppEnvironment.produzione
          ? _supabaseUrlProduzione
          : _supabaseUrlTest;

  static const String supabasePublishableKey =
      ambiente == AppEnvironment.produzione
          ? _supabasePublishableKeyProduzione
          : _supabasePublishableKeyTest;

  // ==========================================================================
  // URL PUBBLICO DELL'APPLICAZIONE WEB
  //
  // Utilizzato, ad esempio, per i link pubblici dei questionari.
  // Se vuoto, sul Web viene utilizzata automaticamente l'origine corrente.
  // ==========================================================================

  static const String publicAppUrl = String.fromEnvironment(
    'PUBLIC_APP_URL',
    defaultValue: '',
  );

  // ==========================================================================
  // INFORMAZIONI AMBIENTE
  // ==========================================================================

  static const bool isProduzione =
      ambiente == AppEnvironment.produzione;

  static const bool isTest =
      ambiente == AppEnvironment.test;

  static const String nomeAmbiente =
      ambiente == AppEnvironment.produzione
          ? 'Produzione'
          : 'Test';
}