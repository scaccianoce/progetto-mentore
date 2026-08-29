import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../app/app_core.dart';
import '../../../app/app_session_controller.dart';
import '../../../dati/repository.dart';
import '../../../ui/dinamico_schema.dart';

/// Stato annuale relativo alla scelta/gestione dell'insegnamento.
class StatoInsegnamentoAnnuale {
  const StatoInsegnamentoAnnuale({
    required this.annoAccademico,
    required this.annoCorrente,
    required this.nonRichiesto,
    required this.puoSelezionare,
    required this.puoCreare,
    required this.puoModificare,
    this.partecipazioneStato,
    this.soloMentore = false,
    this.mentoraggioId,
    this.insegnamentoId,
  });

  factory StatoInsegnamentoAnnuale.daMap(Map<String, dynamic> map) {
    return StatoInsegnamentoAnnuale(
      annoAccademico: map['anno_accademico']?.toString() ?? '',
      annoCorrente: map['anno_corrente'] == true,
      nonRichiesto: map['non_richiesto'] == true,
      puoSelezionare: map['puo_selezionare'] == true,
      puoCreare: map['puo_creare'] == true,
      puoModificare: map['puo_modificare'] == true,
      partecipazioneStato: map['partecipazione_stato']?.toString(),
      soloMentore: map['solo_mentore'] == true,
      mentoraggioId: map['mentoraggio_id']?.toString(),
      insegnamentoId: map['insegnamento_id']?.toString(),
    );
  }

  final String annoAccademico;
  final bool annoCorrente;
  final bool nonRichiesto;
  final bool puoSelezionare;
  final bool puoCreare;
  final bool puoModificare;
  final String? partecipazioneStato;
  final bool soloMentore;
  final String? mentoraggioId;
  final String? insegnamentoId;

  bool get haMentoraggio => mentoraggioId != null;

  bool get partecipazioneConfermata =>
      partecipazioneStato == null ||
      partecipazioneStato == 'confermato' ||
      partecipazioneStato == 'nuovo';
}

/// Coordina la scelta annuale dell'insegnamento.
///
/// Non usa un repository specifico: indica direttamente tabelle e RPC al
/// [DatabaseRepository].
class SceltaInsegnamentoAnnualeController {
  SceltaInsegnamentoAnnualeController({
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  final DatabaseRepository db;

  String? _annoGestione;

  Future<String?> annoGestione() async {
    if (_annoGestione != null && _annoGestione!.isNotEmpty) {
      return _annoGestione;
    }

    final raw = await db.rpc('anno_accademico_gestione_insegnamenti');
    _annoGestione = raw?.toString();

    return _annoGestione;
  }

  Future<StatoInsegnamentoAnnuale> caricaStato() async {
    final anno = await annoGestione();

    final raw = await db.rpcMappa(
      'insegnamento_stato_annuale',
      parametri: <String, dynamic>{
        'p_anno_accademico': anno,
      },
    );

    if (raw == null) {
      throw const AppException(
        'Stato annuale dell’insegnamento non disponibile.',
      );
    }

    final mappa = Map<String, dynamic>.from(raw);

    if (anno != null && anno.isNotEmpty) {
      final userId = db.userIdCorrente;

      if (userId != null) {
        final partecipazione =
            await db.tabella('partecipazioni_annuali').singolo(
          colonne: 'stato, solo_mentore',
          filtri: <FiltroDb>[
            FiltroDb.uguale('user_id', userId),
            FiltroDb.uguale('anno_accademico', anno),
          ],
        );

        if (partecipazione != null) {
          mappa['partecipazione_stato'] =
              partecipazione['stato']?.toString();
          mappa['solo_mentore'] =
              partecipazione['solo_mentore'] == true;
        }
      }
    }

    return StatoInsegnamentoAnnuale.daMap(mappa);
  }

  Future<List<Map<String, dynamic>>> caricaInsegnamenti() =>
      db.rpcElenco('insegnamenti_miei');

  Future<void> seleziona(String insegnamentoId) async {
    await db.rpc(
      'insegnamento_seleziona_per_anno',
      parametri: <String, dynamic>{
        'p_insegnamento_id': insegnamentoId,
        'p_anno_accademico': await annoGestione(),
      },
    );
  }

  Future<void> crea(Map<String, dynamic> valori) async {
    await db.rpc(
      'insegnamento_crea_per_anno',
      parametri: <String, dynamic>{
        'p_valori': valori,
        'p_anno_accademico': await annoGestione(),
      },
    );
  }

  Future<void> modifica(
    String insegnamentoId,
    Map<String, dynamic> valori,
  ) async {
    await db.rpc(
      'insegnamento_modifica_autorizzata',
      parametri: <String, dynamic>{
        'p_insegnamento_id': insegnamentoId,
        'p_valori': valori,
        'p_anno_accademico': await annoGestione(),
      },
    );
  }

  void invalidaAnno() {
    _annoGestione = null;
  }
}

/// Controller della pagina Insegnamenti.
///
/// Coordina insegnamenti, storico dei mentoraggi, stato annuale e risultati
/// dei questionari. Tutto l'accesso remoto passa da [DatabaseRepository].
class InsegnamentoController extends ChangeNotifier {
  InsegnamentoController({
    required this.sessione,
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository() {
    _sceltaAnnualeController =
        SceltaInsegnamentoAnnualeController(database: db);
  }

  final SessioneController sessione;
  final DatabaseRepository db;

  late final SceltaInsegnamentoAnnualeController
      _sceltaAnnualeController;

  List<InsegnamentoStorico> _insegnamenti =
      const <InsegnamentoStorico>[];
  int _indiceSelezionato = 0;

  bool _caricamento = false;
  bool _salvataggio = false;
  String? _errore;

  final Map<String, Map<String, dynamic>?> _risultatiQuestionari =
      <String, Map<String, dynamic>?>{};

  List<InsegnamentoStorico> get insegnamenti => _insegnamenti;
  int get indiceSelezionato => _indiceSelezionato;
  bool get caricamento => _caricamento;
  bool get salvataggio => _salvataggio;
  String? get errore => _errore;

  InsegnamentoStorico? get selezionato {
    if (_insegnamenti.isEmpty) return null;

    if (_indiceSelezionato < 0 ||
        _indiceSelezionato >= _insegnamenti.length) {
      return _insegnamenti.first;
    }

    return _insegnamenti[_indiceSelezionato];
  }

  Future<SchemaDatabase> caricaSchemaDatabase() =>
      SchemaDatabase.carica(database: db);

  /// Restituisce un URL apribile per la scheda di sintesi.
  Future<String> urlSchedaSintesi(String valore) {
    if (valore.startsWith('http://') ||
        valore.startsWith('https://')) {
      return Future<String>.value(valore);
    }

    return db.creaUrlFirmato(
      bucket: 'schede-sintesi',
      percorso: valore,
      durata: const Duration(hours: 1),
    );
  }

  Future<void> carica() async {
    _caricamento = true;
    _errore = null;
    notifyListeners();

    try {
      if (db.userIdCorrente == null) {
        throw const AppException('Utente non autenticato.');
      }

      final risultati = await Future.wait<dynamic>([
        _sceltaAnnualeController.caricaInsegnamenti(),
        db.rpcElenco('mentoraggi_del_mentee'),
      ]);

      final insegnamentiRaw = (risultati[0] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

      final mentoraggiRaw = (risultati[1] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

      final elementi = <InsegnamentoStorico>[];

      for (final insegnamento in insegnamentiRaw) {
        final id = insegnamento['id']?.toString();

        final mentoraggi = mentoraggiRaw
            .where(
              (mentoraggio) =>
                  mentoraggio['insegnamento_id']?.toString() == id,
            )
            .toList(growable: true)
          ..sort((a, b) {
            final annoA =
                a['anno_accademico']?.toString() ?? '';
            final annoB =
                b['anno_accademico']?.toString() ?? '';
            return annoB.compareTo(annoA);
          });

        elementi.add(
          InsegnamentoStorico(
            insegnamento: insegnamento,
            mentoraggi: mentoraggi,
          ),
        );
      }

      _insegnamenti = elementi;

      if (_insegnamenti.isEmpty) {
        _indiceSelezionato = 0;
      } else if (_indiceSelezionato >= _insegnamenti.length) {
        _indiceSelezionato = _insegnamenti.length - 1;
      }
    } catch (e) {
      _errore = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile caricare gli insegnamenti.',
      ).messaggio;
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  void seleziona(int indice) {
    if (indice < 0 || indice >= _insegnamenti.length) return;
    if (_indiceSelezionato == indice) return;

    _indiceSelezionato = indice;
    notifyListeners();
  }

  Future<void> creaInsegnamento(
    Map<String, dynamic> valori,
  ) =>
      _eseguiSalvataggio(
        azione: () => _sceltaAnnualeController.crea(valori),
        messaggio: 'Impossibile creare l’insegnamento.',
      );

  Future<void> selezionaInsegnamento(
    String insegnamentoId,
  ) =>
      _eseguiSalvataggio(
        azione: () =>
            _sceltaAnnualeController.seleziona(insegnamentoId),
        messaggio:
            'Impossibile associare l’insegnamento all’anno accademico.',
      );

  Future<void> modificaInsegnamento(
    String insegnamentoId,
    Map<String, dynamic> valori,
  ) =>
      _eseguiSalvataggio(
        azione: () => _sceltaAnnualeController.modifica(
          insegnamentoId,
          valori,
        ),
        messaggio: 'Impossibile modificare l’insegnamento.',
      );

  Future<void> _eseguiSalvataggio({
    required Future<void> Function() azione,
    required String messaggio,
  }) async {
    _salvataggio = true;
    _errore = null;
    notifyListeners();

    try {
      await azione();
      await carica();
    } catch (e) {
      throw AppErrorMapper.converti(
        e,
        messaggioGenerico: messaggio,
      );
    } finally {
      _salvataggio = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> risultatiMentoraggio(
    String mentoraggioId, {
    bool forza = false,
  }) async {
    if (!forza &&
        _risultatiQuestionari.containsKey(mentoraggioId)) {
      return _risultatiQuestionari[mentoraggioId];
    }

    final risultato = await db.rpcMappa(
      'questionario_risultati_mentoraggio',
      parametri: <String, dynamic>{
        'p_mentoraggio_id': mentoraggioId,
      },
    );

    _risultatiQuestionari[mentoraggioId] = risultato;
    return risultato;
  }

  Future<String?> esportaCsvQuestionarioMentoraggio(
    String mentoraggioId,
  ) async {
    try {
      final dati = await risultatiMentoraggio(
        mentoraggioId,
        forza: true,
      );

      if (dati == null || dati['questionario_id'] == null) {
        throw const AppException(
          'Nessun questionario studenti disponibile.',
        );
      }

      final domande = (dati['domande'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

      final compilazioni =
          (dati['compilazioni'] as List? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(growable: false);

      final risposte = (dati['risposte'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

      String csv(Object? valore) {
        final testo = valore?.toString() ?? '';
        return '"${testo.replaceAll('"', '""')}"';
      }

      final buffer = StringBuffer('data_compilazione');

      for (final domanda in domande) {
        buffer.write(',${csv(domanda['testo'])}');
      }
      buffer.writeln();

      for (final compilazione in compilazioni) {
        buffer.write(csv(compilazione['inviato_at']));

        for (final domanda in domande) {
          Object? valore;

          for (final risposta in risposte) {
            if (risposta['compilazione_id']?.toString() ==
                    compilazione['id']?.toString() &&
                risposta['domanda_id']?.toString() ==
                    domanda['id']?.toString()) {
              valore = risposta['valore'];
              break;
            }
          }

          buffer.write(',${csv(valore)}');
        }

        buffer.writeln();
      }

      await FilePicker.saveFile(
        dialogTitle: 'Esporta risultati questionario',
        fileName:
            'questionario_${mentoraggioId}_risultati.csv',
        bytes: Uint8List.fromList(
          utf8.encode(buffer.toString()),
        ),
        mimeType: 'text/csv',
      );

      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile esportare i risultati.',
      ).messaggio;
    }
  }

  /// Compatibilita' con la chiamata unica di salvataggio della page.
  Future<void> salvaInsegnamento(
    Map<String, dynamic> valori, {
    String? insegnamentoId,
  }) {
    return insegnamentoId == null
        ? creaInsegnamento(valori)
        : modificaInsegnamento(insegnamentoId, valori);
  }
}

/// Raggruppa un insegnamento con i mentoraggi storici associati.
class InsegnamentoStorico {
  const InsegnamentoStorico({
    required this.insegnamento,
    required this.mentoraggi,
  });

  final Map<String, dynamic> insegnamento;
  final List<Map<String, dynamic>> mentoraggi;
}
