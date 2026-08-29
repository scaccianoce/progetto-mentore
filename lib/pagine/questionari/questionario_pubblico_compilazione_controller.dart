import 'package:flutter/foundation.dart';

import '../../app/app_core.dart';
import '../../dati/repository.dart';

/// Controller della sola compilazione anonima di un questionario pubblico.
///
/// Viene usato dalla route pubblica `/q/<token>` e non deve essere confuso con
/// il controller amministrativo dei questionari pubblici usato dai mentori.
class QuestionarioPubblicoCompilazioneController extends ChangeNotifier {
  QuestionarioPubblicoCompilazioneController({
    DatabaseRepository? databasePubblico,
  }) : db = databasePubblico ?? DatabaseRepository.pubblico();

  final DatabaseRepository db;

  Map<String, dynamic>? dati;
  bool caricamento = true;
  bool invio = false;
  bool completato = false;
  String? errore;

  /// Carica questionario e domande tramite la RPC pubblica.
  Future<void> carica(String token) async {
    caricamento = true;
    errore = null;
    notifyListeners();

    try {
      dati = await db.rpcMappa(
        'questionario_pubblico_carica',
        parametri: <String, dynamic>{
          'p_token': token,
        },
      );
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Questionario non disponibile.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  /// Invia le risposte tramite la RPC pubblica.
  Future<String?> invia(
    String token,
    Map<String, dynamic> risposte,
  ) async {
    invio = true;
    notifyListeners();

    try {
      await db.rpc(
        'questionario_pubblico_invia',
        parametri: <String, dynamic>{
          'p_token': token,
          'p_risposte': risposte,
        },
      );

      completato = true;
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Invio del questionario non riuscito.',
      ).messaggio;
    } finally {
      invio = false;
      notifyListeners();
    }
  }
}
