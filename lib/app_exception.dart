import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

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
