import 'package:flutter/foundation.dart';

import '../app/app_core.dart';
import '../app/app_session_controller.dart';
import '../dati/repository.dart';

/// Gestisce i questionari pubblici accessibili tramite token.
///
/// Il controller amministrativo usa il database con la sessione corrente;
/// caricamento e invio tramite link pubblico usano invece un accesso anonimo
/// confinato nel livello dati.
class QuestionarioPubblicoController extends ChangeNotifier {
  QuestionarioPubblicoController(
    this.sessione, {
    DatabaseRepository? database,
    DatabaseRepository? databasePubblico,
  })  : db = database ?? DatabaseRepository(),
        dbPubblico = databasePubblico ?? DatabaseRepository.pubblico();

  final SessioneController sessione;
  final DatabaseRepository db;
  final DatabaseRepository dbPubblico;

  final List<Map<String, dynamic>> template = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> domande = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> questionari = <Map<String, dynamic>>[];

  bool caricamento = false;
  String? errore;

  bool get puoGestire => sessione.ruolo?.puoAmministrare ?? false;

  /// Carica catalogo e questionari pubblici per l'area amministrativa.
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
        db.tabella('questionari_domande').elenco(
          ordinamenti: const <OrdineDb>[
            OrdineDb('template_id'),
            OrdineDb('ordine'),
          ],
        ),
        db.tabella('questionari').elenco(
          filtri: const <FiltroDb>[
            FiltroDb.uguale('provider', 'pubblico'),
          ],
          ordinamenti: const <OrdineDb>[
            OrdineDb('created_at', crescente: false),
          ],
        ),
      ]);

      template
        ..clear()
        ..addAll(risultati[0]);

      domande
        ..clear()
        ..addAll(risultati[1]);

      questionari
        ..clear()
        ..addAll(risultati[2]);
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile caricare i questionari pubblici.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> templatePer(String destinatario) => template
      .where(
        (riga) =>
            riga['destinatario']?.toString() == destinatario &&
            riga['attivo'] != false,
      )
      .toList(growable: false);

  List<Map<String, dynamic>> domandeTemplate(String templateId) => domande
      .where((riga) => riga['template_id']?.toString() == templateId)
      .toList(growable: false);

  /// Cerca il questionario pubblico associato a un mentoraggio.
  Map<String, dynamic>? questionarioPerMentoraggio(String mentoraggioId) {
    for (final questionario in questionari) {
      if (questionario['mentoraggio_id']?.toString() == mentoraggioId) {
        return questionario;
      }
    }
    return null;
  }

  /// Crea il questionario pubblico associato a un mentoraggio e ne registra
  /// il link sul mentoraggio.
  Future<String?> creaPerMentoraggio({
    required String mentoraggioId,
    required String templateId,
    required String titolo,
  }) =>
      _esegui(() async {
        if (!puoGestire) {
          throw const AppException('Operazione non autorizzata.');
        }

        final esistente = await db.tabella('questionari').singolo(
          colonne: 'id',
          filtri: <FiltroDb>[
            const FiltroDb.uguale('provider', 'pubblico'),
            FiltroDb.uguale('mentoraggio_id', mentoraggioId),
          ],
        );

        if (esistente != null) {
          throw const AppException(
            'Il questionario per questo mentoraggio è già stato generato.',
          );
        }

        final creato = await db.tabella('questionari').inserisci(
          <String, dynamic>{
            'template_id': templateId,
            'titolo': titolo.trim(),
            'provider': 'pubblico',
            'mentoraggio_id': mentoraggioId,
            'aperto': true,
            'created_by': db.userIdCorrente,
          },
          colonne: 'id, token_pubblico',
        );

        final token = creato['token_pubblico']?.toString().trim();
        if (token == null || token.isEmpty) {
          throw const AppException(
            'Token pubblico del questionario non restituito.',
          );
        }

        await db.rpc(
          'questionario_mentoraggio_link_imposta',
          parametri: <String, dynamic>{
            'p_mentoraggio_id': mentoraggioId,
            'p_url': _urlDaToken(token),
          },
        );
      });

  /// Costruisce l'URL pubblico a partire dal token restituito dal database.
  String? urlQuestionario(Map<String, dynamic> questionario) {
    final token = questionario['token_pubblico']?.toString().trim();
    return token == null || token.isEmpty ? null : _urlDaToken(token);
  }

  /// Conta le compilazioni associate a un questionario.
  Future<int> contaCompilazioni(String questionarioId) async {
    final righe = await db.tabella('questionari_compilazioni').elenco(
      colonne: 'id',
      filtri: <FiltroDb>[
        FiltroDb.uguale('questionario_id', questionarioId),
      ],
    );
    return righe.length;
  }

  /// Elimina un questionario pubblico privo di compilazioni.
  Future<String?> elimina(String questionarioId) =>
      _esegui(() async {
        if (!puoGestire) {
          throw const AppException('Operazione non autorizzata.');
        }

        if (await contaCompilazioni(questionarioId) > 0) {
          throw const AppException(
            'Il questionario non può essere cancellato perché '
            'sono già presenti risposte.',
          );
        }

        final questionario = await db.tabella('questionari').singolo(
          colonne: 'mentoraggio_id',
          filtri: <FiltroDb>[
            FiltroDb.uguale('id', questionarioId),
          ],
        );

        final mentoraggioId = questionario?['mentoraggio_id']?.toString();

        await db.tabella('questionari').elimina(
          filtri: <FiltroDb>[
            FiltroDb.uguale('id', questionarioId),
          ],
        );

        if (mentoraggioId != null && mentoraggioId.isNotEmpty) {
          await db.rpc(
            'questionario_mentoraggio_link_imposta',
            parametri: <String, dynamic>{
              'p_mentoraggio_id': mentoraggioId,
              'p_url': '',
            },
          );
        }
      });

  /// Carica un questionario pubblico tramite token, senza sessione utente.
  Future<Map<String, dynamic>?> caricaDaToken(String token) =>
      dbPubblico.rpcMappa(
        'questionario_pubblico_carica',
        parametri: <String, dynamic>{
          'p_token': token,
        },
      );

  /// Invia le risposte di un questionario pubblico tramite token.
  Future<void> inviaDaToken(
    String token,
    Map<String, dynamic> risposte,
  ) =>
      dbPubblico.rpc(
        'questionario_pubblico_invia',
        parametri: <String, dynamic>{
          'p_token': token,
          'p_risposte': risposte,
        },
      );

  String _urlDaToken(String token) {
    final configurato = AppConfig.publicAppUrl.trim();
    final base = configurato.isNotEmpty
        ? configurato.replaceFirst(RegExp(r'/$'), '')
        : Uri.base.origin;
    return '$base/q/$token';
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
            'Operazione sul questionario pubblico non riuscita.',
      ).messaggio;
    }
  }
}
