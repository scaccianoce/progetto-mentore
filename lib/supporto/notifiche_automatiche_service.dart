import '../dati/repository.dart';

/// Coordina la creazione di notifiche automatiche generate dall'app.
///
/// Il servizio contiene soltanto regole applicative relative ai destinatari.
/// Tutte le operazioni remote sono delegate a [NotificheRepository].
abstract final class NotificheAutomaticheService {
  static final NotificheRepository _repository = NotificheRepository();

  /// Invia una notifica a tutti gli utenti dell'anno accademico indicato.
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

  /// Invia una notifica a un insieme esplicito di utenti.
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

  /// Esegue il workflow applicativo:
  /// crea messaggio -> genera destinatari -> invia push.
  ///
  /// La gestione degli errori remoti e dello stato `errore` resta nel
  /// repository notifiche.
  static Future<void> _creaEInvia({
    required String titolo,
    required String messaggio,
    required String destinatari,
    required Map<String, dynamic> configurazione,
  }) async {
    final titoloPulito = titolo.trim();
    final messaggioPulito = messaggio.trim();

    if (titoloPulito.isEmpty || messaggioPulito.isEmpty) return;

    final messaggioId = await _repository.creaMessaggio(
      <String, dynamic>{
        'regola_id': null,
        'titolo': titoloPulito,
        'messaggio': messaggioPulito,
        'destinatari': destinatari,
        'destinatari_configurazione': configurazione,
        'programmata_per': null,
        'stato': 'da_inviare',
        'creata_da': _repository.userIdCorrente,
      },
    );

    try {
      await _repository.generaDestinatari(messaggioId);
      await _repository.inviaMessaggio(messaggioId);
    } catch (_) {
      // Il repository prova gia' a portare il messaggio in stato `errore`
      // quando fallisce l'invio. L'eccezione viene comunque propagata.
      rethrow;
    }
  }
}
