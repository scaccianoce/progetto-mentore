import 'package:flutter/foundation.dart';

import 'supabase_config.dart';

/// Crea una notifica nel database, genera i destinatari e avvia subito
/// l'Edge Function `notifiche-invia`.
///
/// Le notifiche automatiche non vengono lasciate volutamente nello stato
/// `da_inviare`: dopo la creazione viene richiesto immediatamente l'invio.
abstract final class NotificheAutomaticheService {
  static Future<void> inviaAnnoAccademico({
    required String annoAccademico,
    required String titolo,
    required String messaggio,
  }) async {
    final anno = annoAccademico.trim();
    if (anno.isEmpty) return;

    await _creaEInvia(
      titolo: titolo,
      messaggio: messaggio,
      destinatari: 'anno_accademico',
      configurazione: <String, dynamic>{
        'anno_accademico': anno,
      },
    );
  }

  static Future<void> inviaUtenti({
    required Iterable<String> userIds,
    required String titolo,
    required String messaggio,
  }) async {
    final ids = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (ids.isEmpty) return;

    await _creaEInvia(
      titolo: titolo,
      messaggio: messaggio,
      destinatari: 'manuale',
      configurazione: <String, dynamic>{
        'user_ids': ids,
      },
    );
  }

  static Future<void> _creaEInvia({
    required String titolo,
    required String messaggio,
    required String destinatari,
    required Map<String, dynamic> configurazione,
  }) async {
    final client = SupabaseConfig.client;
    final userId = client.auth.currentUser?.id;

    final record = await client
        .from('notifiche_messaggi')
        .insert(<String, dynamic>{
          'regola_id': null,
          'titolo': titolo.trim(),
          'messaggio': messaggio.trim(),
          'destinatari': destinatari,
          'destinatari_configurazione': configurazione,
          'programmata_per': null,
          'stato': 'da_inviare',
          'creata_da': userId,
        })
        .select('id')
        .single();

    final messaggioId = record['id']?.toString() ?? '';
    if (messaggioId.isEmpty) {
      throw StateError('ID della notifica non restituito dal database.');
    }

    await client.rpc(
      'notifiche_genera_destinatari',
      params: <String, dynamic>{
        'p_messaggio_id': messaggioId,
      },
    );

    final risposta = await client.functions.invoke(
      'notifiche-invia',
      body: <String, dynamic>{
        'messaggio_id': messaggioId,
      },
    );

    if (risposta.status < 200 || risposta.status >= 300) {
      debugPrint(
        'Notifica automatica $messaggioId non inviata: '
        'HTTP ${risposta.status} ${risposta.data}',
      );
      throw StateError(
        'Invio push non riuscito (HTTP ${risposta.status}).',
      );
    }
  }
}
