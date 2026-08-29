import '../app/app_core.dart';
import '../app/app_session_controller.dart';
import '../dati/repository.dart';
import 'questionario_csv_service.dart';

/// Carica, sintetizza ed esporta i risultati di qualsiasi questionario.
///
/// Il controller non distingue tra questionario privato e pubblico: entrambi
/// condividono le stesse tabelle di compilazioni, domande e risposte.
class QuestionarioRisultatiController {
  QuestionarioRisultatiController(
    this.sessione, {
    DatabaseRepository? database,
    QuestionarioCsvService? csvService,
  })  : db = database ?? DatabaseRepository(),
        csvService = csvService ?? const QuestionarioCsvService();

  final SessioneController sessione;
  final DatabaseRepository db;
  final QuestionarioCsvService csvService;

  bool get puoGestire => sessione.ruolo?.puoAmministrare ?? false;

  Future<Map<String, dynamic>> caricaRisultatiQuestionario(
    String questionarioId,
  ) async {
    if (!puoGestire) {
      throw const AppException('Operazione non autorizzata.');
    }

    final questionario = await db.tabella('questionari').singolo(
      colonne:
          'id, titolo, template_id, provider, evento_id, mentoraggio_id',
      filtri: <FiltroDb>[
        FiltroDb.uguale('id', questionarioId),
      ],
    );

    if (questionario == null) {
      throw const AppException('Questionario non trovato.');
    }

    final templateId = questionario['template_id']?.toString();
    if (templateId == null || templateId.isEmpty) {
      throw const AppException(
        'Template del questionario non disponibile.',
      );
    }

    final domande = await db.tabella('questionari_domande').elenco(
      colonne: 'id, ordine, testo, tipo, opzioni',
      filtri: <FiltroDb>[
        FiltroDb.uguale('template_id', templateId),
      ],
      ordinamenti: const <OrdineDb>[
        OrdineDb('ordine'),
      ],
    );

    final compilazioni = await db.tabella('questionari_compilazioni').elenco(
      colonne: 'id, user_id, inviato_at',
      filtri: <FiltroDb>[
        FiltroDb.uguale('questionario_id', questionarioId),
      ],
      ordinamenti: const <OrdineDb>[
        OrdineDb('inviato_at'),
      ],
    );

    final idsCompilazioni = compilazioni
        .map((riga) => riga['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    final risposte = idsCompilazioni.isEmpty
        ? const <Map<String, dynamic>>[]
        : await db.tabella('questionari_risposte').elenco(
            colonne: 'compilazione_id, domanda_id, valore',
            filtri: <FiltroDb>[
              FiltroDb.inLista(
                'compilazione_id',
                idsCompilazioni.cast<Object>(),
              ),
            ],
          );

    final dati = <String, dynamic>{
      'questionario': questionario,
      'numero_compilazioni': compilazioni.length,
      'domande': domande,
      'compilazioni': compilazioni,
      'risposte': risposte,
    };

    dati['sintesi'] = <Map<String, dynamic>>[
      for (final domanda in domande)
        _sintesiDomanda(
          domanda,
          risposte
              .where(
                (riga) =>
                    riga['domanda_id']?.toString() ==
                    domanda['id']?.toString(),
              )
              .map((riga) => riga['valore'])
              .where((valore) => valore != null)
              .toList(growable: false),
        ),
    ];

    return dati;
  }

  Future<String?> esportaCsvRisultati(String questionarioId) async {
    try {
      await csvService.esporta(
        await caricaRisultatiQuestionario(questionarioId),
      );
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile esportare i risultati CSV.',
      ).messaggio;
    }
  }

  Map<String, dynamic> _sintesiDomanda(
    Map<String, dynamic> domanda,
    List<dynamic> valori,
  ) {
    final tipo = domanda['tipo']?.toString() ?? '';

    if (tipo == 'scala') {
      final numeri = valori
          .map((valore) => double.tryParse(valore.toString()))
          .whereType<double>()
          .toList();

      return <String, dynamic>{
        ...domanda,
        'numero_risposte': numeri.length,
        'media': numeri.isEmpty
            ? null
            : numeri.reduce((a, b) => a + b) / numeri.length,
      };
    }

    if (tipo == 'booleano' || tipo == 'scelta_singola') {
      final frequenze = <String, int>{};

      for (final valore in valori) {
        final chiave = valore is bool
            ? (valore ? 'Si' : 'No')
            : valore.toString();
        frequenze[chiave] = (frequenze[chiave] ?? 0) + 1;
      }

      return <String, dynamic>{
        ...domanda,
        'numero_risposte': valori.length,
        'frequenze': frequenze,
      };
    }

    return <String, dynamic>{
      ...domanda,
      'numero_risposte': valori.length,
      'testi': valori
          .map((valore) => valore.toString())
          .toList(growable: false),
    };
  }
}
