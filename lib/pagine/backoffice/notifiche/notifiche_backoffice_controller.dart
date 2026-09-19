import 'dart:async';

import '../../../ui/dinamico_schema.dart';
import '../../../dati/repository.dart';

/// Controller della pagina di backoffice delle notifiche.
///
/// Coordina la logica applicativa del sottosistema notifiche.
///
/// A differenza delle altre pagine, le operazioni remote restano volutamente
/// delegate a [NotificheRepository]: notifiche, destinatari, retry e regole
/// automatiche costituiscono un sottosistema autonomo rispetto al CRUD
/// generico dell'applicazione.
class NotificheBackofficeController {
  NotificheBackofficeController({NotificheRepository? repository})
      : repository = repository ?? NotificheRepository();

  final NotificheRepository repository;

  /// Carica lo schema usato dai dialog di configurazione.
  Future<SchemaDatabase> caricaSchemaDatabase() => SchemaDatabase.carica(database: DatabaseRepository());

  /// Carica i messaggi mostrati nella scheda "Messaggi".
  Future<List<Map<String, dynamic>>> caricaMessaggi() => repository.messaggi();

  /// Indica se un invio non concluso può essere ritentato manualmente.
  bool messaggioRitentabile(Map<String, dynamic> messaggio) {
    final stato = messaggio['stato']?.toString();
    return stato == 'da_inviare' || stato == 'errore' || stato == 'parziale';
  }

  /// Ritenta l'invio di un messaggio già creato.
  Future<void> ritentaInvio(String messaggioId) =>
      repository.inviaMessaggio(messaggioId);

  /// Elimina l’operazione `eliminaMessaggio` mantenendo separata la logica dalla UI.
  Future<void> eliminaMessaggio(String messaggioId) =>
      repository.eliminaMessaggio(messaggioId);

  Future<List<Map<String, dynamic>>> caricaDestinatari(String messaggioId) =>
      repository.destinatariMessaggio(messaggioId);

  Future<List<Map<String, dynamic>>> caricaOpzioniDestinatari(String tipo) =>
      repository.opzioniDestinatari(tipo);

  /// Crea o aggiorna una notifica, rigenera i destinatari e, se non è
  /// programmata, avvia l'invio in background senza bloccare la UI.
  Future<int> salvaMessaggio({
    String? messaggioId,
    required Map<String, dynamic> payload,
    required bool programmato,
  }) async {
    final String id;
    if (messaggioId == null) {
      id = await repository.creaMessaggio(<String, dynamic>{
        'regola_id': null,
        ...payload,
        'creata_da': repository.userIdCorrente,
      });
    } else {
      id = messaggioId;
      await repository.aggiornaMessaggio(id, payload);
      await repository.eliminaDestinatari(id);
    }

    try {
      final numeroDestinatari = await repository.generaDestinatari(id);
      if (!programmato) {
        // L'invio può richiedere tempo: non bloccare il dialog di creazione.
        unawaited(repository.inviaMessaggio(id).catchError((_) {}));
      }
      return numeroDestinatari;
    } catch (_) {
      // Qualunque errore successivo alla creazione non deve lasciare il record
      // apparentemente sospeso nello stato `da_inviare`.
      try {
        await repository.aggiornaMessaggio(
          id,
          <String, dynamic>{'stato': 'errore'},
        );
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> caricaRegole() => repository.regole();

  /// Imposta l’operazione `impostaRegolaAttiva` mantenendo separata la logica dalla UI.
  Future<void> impostaRegolaAttiva(String id, bool attiva) =>
      repository.impostaRegolaAttiva(id, attiva);

  /// Elimina l’operazione `eliminaRegola` mantenendo separata la logica dalla UI.
  Future<void> eliminaRegola(Object id) => repository.eliminaRegola(id);

  /// Salva l’operazione `salvaRegola` mantenendo separata la logica dalla UI.
  Future<void> salvaRegola({
    Object? id,
    required Map<String, dynamic> valori,
  }) => repository.salvaRegola(id: id, valori: valori);
}
