import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// CONFIGURAZIONE APPLICAZIONE
// ============================================================================

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
      // AppEnvironment.produzione;
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

// ============================================================================
// BRANDING
// ============================================================================

/// Branding grafico centralizzato dell'applicazione.
abstract final class AppBranding {
  /// Logo usato nella schermata di login e nella barra laterale.
  ///
  /// Il file deve essere presente nel progetto in:
  ///   assets/icon/menu_logo.png
  /// e dichiarato nel pubspec.yaml tra gli assets Flutter.
  static const String logoAsset = 'assets/icon/menu_logo.png';
  static const String logoAssetWOtext = 'assets/icon/app_icon.png';
}

// ============================================================================
// ERRORI APPLICATIVI
// ============================================================================

/// Errore dell'app con un messaggio sicuro da mostrare all'utente.
class AppException implements Exception {
  const AppException(this.messaggio, {this.dettaglioTecnico});

  final String messaggio;
  final String? dettaglioTecnico;

  @override
  String toString() => messaggio;
}

/// Traduce gli errori tecnici più comuni in messaggi comprensibili.
abstract final class AppErrorMapper {
  static AppException converti(
    Object errore, {
    required String messaggioGenerico,
  }) {
    if (errore is AppException) {
      return errore;
    }

    if (errore is PostgrestException) {
      final String messaggio = switch (errore.code) {
        '42501' => 'Non hai i permessi per eseguire questa operazione.',
        '23505' => 'Esiste già un record con questi dati.',
        '23503' =>
          'L’operazione non è possibile perché il dato è collegato '
              'ad altre informazioni.',
        '23502' => 'Manca un dato obbligatorio.',
        'PGRST116' => 'Il dato richiesto non è stato trovato.',
        _ => messaggioGenerico,
      };

      return AppException(
        messaggio,
        dettaglioTecnico: '${errore.code}: ${errore.message}',
      );
    }

    if (errore is AuthException) {
      return AppException(
        'Operazione di autenticazione non riuscita.',
        dettaglioTecnico: errore.message,
      );
    }

    if (errore is TimeoutException) {
      return AppException(
        'Il collegamento sta impiegando troppo tempo. Riprova.',
        dettaglioTecnico: errore.toString(),
      );
    }

    return AppException(messaggioGenerico, dettaglioTecnico: errore.toString());
  }
}
