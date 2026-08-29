import 'package:flutter/foundation.dart';

import '../app/app_core.dart';
import '../app/app_session_controller.dart';
import '../dati/repository.dart';

/// Gestisce i questionari privati, accessibili agli utenti autenticati.
///
/// Attualmente il questionario privato e' usato dagli eventi, ma il controller
/// non e' vincolato alla pagina Evento: il tipo di accesso e' espresso dal
/// provider `interno` memorizzato nel database.
class QuestionarioPrivatoController extends ChangeNotifier {
  QuestionarioPrivatoController(
    this.sessione, {
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  final SessioneController sessione;
  final DatabaseRepository db;

  final List<Map<String, dynamic>> template = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> questionari = <Map<String, dynamic>>[];

  bool caricamento = false;
  String? errore;

  bool get puoGestire => sessione.ruolo?.puoAmministrare ?? false;

  /// Carica template e questionari privati.
  Future<void> carica() async {
    caricamento = true;
    errore = null;
    notifyListeners();

    try {
      final risultati = await Future.wait<List<Map<String, dynamic>>>([
        db.tabella('questionari_template').elenco(
          ordinamenti: const <OrdineDb>[
            OrdineDb('destinatario'),
            OrdineDb('titolo'),
          ],
        ),
        db.tabella('questionari').elenco(
          filtri: const <FiltroDb>[
            FiltroDb.uguale('provider', 'interno'),
          ],
          ordinamenti: const <OrdineDb>[
            OrdineDb('created_at', crescente: false),
          ],
        ),
      ]);

      template
        ..clear()
        ..addAll(risultati[0]);

      questionari
        ..clear()
        ..addAll(risultati[1]);
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile caricare i questionari privati.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  /// Restituisce i template attivi destinati al contesto richiesto.
  List<Map<String, dynamic>> templatePer(String destinatario) => template
      .where(
        (riga) =>
            riga['destinatario']?.toString() == destinatario &&
            riga['attivo'] != false,
      )
      .toList(growable: false);

  /// Cerca il questionario privato associato a un evento gia' caricato.
  Map<String, dynamic>? questionarioPerEvento(String eventoId) {
    for (final questionario in questionari) {
      if (questionario['evento_id']?.toString() == eventoId) {
        return questionario;
      }
    }
    return null;
  }

  /// Crea un questionario privato associato a un evento.
  Future<String?> creaPerEvento({
    required String eventoId,
    required String templateId,
    required String titolo,
  }) =>
      _esegui(() async {
        if (!puoGestire) {
          throw const AppException('Operazione non autorizzata.');
        }

        await db.tabella('questionari').inserisci(
          <String, dynamic>{
            'template_id': templateId,
            'titolo': titolo.trim(),
            'provider': 'interno',
            'evento_id': eventoId,
            'aperto': true,
            'created_by': db.userIdCorrente,
          },
          colonne: 'id',
        );
      });

  /// Carica questionario e domande per la compilazione privata.
  Future<Map<String, dynamic>?> caricaPerEvento(String eventoId) async {
    final questionario = await db.tabella('questionari').singolo(
      filtri: <FiltroDb>[
        const FiltroDb.uguale('provider', 'interno'),
        FiltroDb.uguale('evento_id', eventoId),
        const FiltroDb.uguale('aperto', true),
      ],
    );

    if (questionario == null) return null;

    final templateId = questionario['template_id']?.toString();
    if (templateId == null || templateId.isEmpty) {
      throw const AppException(
        'Template del questionario non disponibile.',
      );
    }

    final domande = await db.tabella('questionari_domande').elenco(
      filtri: <FiltroDb>[
        FiltroDb.uguale('template_id', templateId),
      ],
      ordinamenti: const <OrdineDb>[
        OrdineDb('ordine'),
      ],
    );

    return <String, dynamic>{
      'questionario': questionario,
      'domande': domande,
    };
  }

  /// Invia le risposte dell'utente autenticato.
  Future<String?> invia({
    required String questionarioId,
    required Map<String, dynamic> risposte,
  }) async {
    try {
      final userId = db.userIdCorrente;
      if (userId == null) {
        throw const AppException('Sessione non valida.');
      }

      final esistente = await db.tabella('questionari_compilazioni').singolo(
        colonne: 'id',
        filtri: <FiltroDb>[
          FiltroDb.uguale('questionario_id', questionarioId),
          FiltroDb.uguale('user_id', userId),
        ],
      );

      if (esistente != null) {
        throw const AppException(
          'Hai già compilato questo questionario.',
        );
      }

      final compilazione = await db.tabella('questionari_compilazioni').inserisci(
        <String, dynamic>{
          'questionario_id': questionarioId,
          'user_id': userId,
        },
        colonne: 'id',
      );

      final compilazioneId = compilazione['id']?.toString() ?? '';
      if (compilazioneId.isEmpty) {
        throw const AppException(
          'Identificativo della compilazione non disponibile.',
        );
      }

      try {
        final righe = <Map<String, dynamic>>[
          for (final risposta in risposte.entries)
            <String, dynamic>{
              'compilazione_id': compilazioneId,
              'domanda_id': risposta.key,
              'valore': risposta.value,
            },
        ];

        await db.tabella('questionari_risposte').inserisciMolti(
              righe,
              colonne: 'id',
            );
      } catch (_) {
        await db.tabella('questionari_compilazioni').elimina(
          filtri: <FiltroDb>[
            FiltroDb.uguale('id', compilazioneId),
          ],
        );
        rethrow;
      }

      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile inviare il questionario.',
      ).messaggio;
    }
  }

  Future<String?> _esegui(Future<void> Function() azione) async {
    try {
      await azione();
      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Operazione sul questionario privato non riuscita.',
      ).messaggio;
    }
  }
}
