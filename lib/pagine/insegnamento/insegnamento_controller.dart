import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../app_exception.dart';
import '../../sessione_controller.dart';
import '../../supabase_config.dart';
import 'scelta_insegnamento_annuale_controller.dart';

class InsegnamentoController extends ChangeNotifier {
  InsegnamentoController({
    required SessioneController sessione,
  });

  final SceltaInsegnamentoAnnualeController
      _sceltaAnnualeController =
      SceltaInsegnamentoAnnualeController();

  List<InsegnamentoStorico> _insegnamenti = const [];
  int _indiceSelezionato = 0;

  bool _caricamento = false;
  bool _salvataggio = false;

  String? _errore;

  final Map<String, Map<String, dynamic>?> _risultatiQuestionari =
      <String, Map<String, dynamic>?>{};

  List<InsegnamentoStorico> get insegnamenti =>
      _insegnamenti;

  int get indiceSelezionato =>
      _indiceSelezionato;

  InsegnamentoStorico? get selezionato {
    if (_insegnamenti.isEmpty) {
      return null;
    }

    if (_indiceSelezionato < 0 ||
        _indiceSelezionato >= _insegnamenti.length) {
      return _insegnamenti.first;
    }

    return _insegnamenti[_indiceSelezionato];
  }

  bool get caricamento => _caricamento;

  bool get salvataggio => _salvataggio;

  String? get errore => _errore;

  // ============================================================
  // CARICAMENTO
  // ============================================================

  Future<void> carica() async {
    _caricamento = true;
    _errore = null;
    notifyListeners();

    try {
      final userId =
          SupabaseConfig.client.auth.currentUser?.id;

      if (userId == null) {
        throw const AppException(
          'Utente non autenticato.',
        );
      }

      final risultati =
          await Future.wait<dynamic>([
        _sceltaAnnualeController
            .caricaInsegnamenti(),

        SupabaseConfig.client.rpc(
          'mentoraggi_del_mentee',
        ),
      ]);

      final insegnamentiRaw =
          (risultati[0] as List)
              .map(
                (e) =>
                    Map<String, dynamic>.from(
                  e as Map,
                ),
              )
              .toList();

      final mentoraggiRaw =
          (risultati[1] as List)
              .map(
                (e) =>
                    Map<String, dynamic>.from(
                  e as Map,
                ),
              )
              .toList();

      final elementi =
          <InsegnamentoStorico>[];

      for (final insegnamento
          in insegnamentiRaw) {
        final id =
            insegnamento['id']
                ?.toString();

        final mentoraggi =
            mentoraggiRaw
                .where(
                  (mentoraggio) =>
                      mentoraggio[
                                  'insegnamento_id']
                              ?.toString() ==
                          id,
                )
                .toList();

        mentoraggi.sort(
          (a, b) {
            final annoA =
                a['anno_accademico']
                        ?.toString() ??
                    '';

            final annoB =
                b['anno_accademico']
                        ?.toString() ??
                    '';

            return annoB.compareTo(annoA);
          },
        );

        elementi.add(
          InsegnamentoStorico(
            insegnamento:
                insegnamento,
            mentoraggi:
                mentoraggi,
          ),
        );
      }

      _insegnamenti =
          elementi;

      if (_insegnamenti.isEmpty) {
        _indiceSelezionato = 0;
      } else if (_indiceSelezionato >=
          _insegnamenti.length) {
        _indiceSelezionato =
            _insegnamenti.length - 1;
      }
    } on AppException catch (e) {
      _errore = e.messaggio;
    } catch (e) {
      _errore =
          AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile caricare gli insegnamenti.',
      ).messaggio;
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  // ============================================================
  // SELEZIONE TAB
  // ============================================================

  void seleziona(int indice) {
    if (indice < 0 ||
        indice >= _insegnamenti.length) {
      return;
    }

    if (_indiceSelezionato == indice) {
      return;
    }

    _indiceSelezionato = indice;
    notifyListeners();
  }

  // ============================================================
  // CREAZIONE
  // ============================================================

  Future<void> creaInsegnamento(
    Map<String, dynamic> valori,
  ) async {
    _salvataggio = true;
    _errore = null;
    notifyListeners();

    try {
      await _sceltaAnnualeController
          .crea(
        valori,
      );

      await carica();
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile creare l’insegnamento.',
      );
    } finally {
      _salvataggio = false;
      notifyListeners();
    }
  }

  // ============================================================
  // SELEZIONE INSEGNAMENTO PRECEDENTE
  // ============================================================

  Future<void> selezionaInsegnamento(
    String insegnamentoId,
  ) async {
    _salvataggio = true;
    _errore = null;
    notifyListeners();

    try {
      await _sceltaAnnualeController
          .seleziona(
        insegnamentoId,
      );

      await carica();
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile associare l’insegnamento all’anno accademico.',
      );
    } finally {
      _salvataggio = false;
      notifyListeners();
    }
  }

  // ============================================================
  // MODIFICA AUTORIZZATA
  // ============================================================

  Future<void> modificaInsegnamento(
    String insegnamentoId,
    Map<String, dynamic> valori,
  ) async {
    _salvataggio = true;
    _errore = null;
    notifyListeners();

    try {
      await _sceltaAnnualeController
          .modifica(
        insegnamentoId,
        valori,
      );

      await carica();
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile modificare l’insegnamento.',
      );
    } finally {
      _salvataggio = false;
      notifyListeners();
    }
  }

  // ============================================================
  // RISULTATI QUESTIONARIO STUDENTI / STORICO
  // ============================================================

  Future<Map<String, dynamic>?> risultatiMentoraggio(
    String mentoraggioId, {
    bool forza = false,
  }) async {
    if (!forza && _risultatiQuestionari.containsKey(mentoraggioId)) {
      return _risultatiQuestionari[mentoraggioId];
    }

    final raw = await SupabaseConfig.client.rpc(
      'questionario_risultati_mentoraggio',
      params: {'p_mentoraggio_id': mentoraggioId},
    );

    final risultato = raw == null
        ? null
        : Map<String, dynamic>.from(raw as Map);
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
      final compilazioni = (dati['compilazioni'] as List? ?? const [])
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
        fileName: 'questionario_${mentoraggioId}_risultati.csv',
        bytes: Uint8List.fromList(utf8.encode(buffer.toString())),
        mimeType: 'text/csv',
      );
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile esportare i risultati.',
      ).messaggio;
    }
  }

  // ============================================================
  // COMPATIBILITÀ CON EVENTUALE CODICE PRECEDENTE
  // ============================================================

  Future<void> salvaInsegnamento(
    Map<String, dynamic> valori, {
    String? insegnamentoId,
  }) async {
    if (insegnamentoId == null) {
      await creaInsegnamento(
        valori,
      );
    } else {
      await modificaInsegnamento(
        insegnamentoId,
        valori,
      );
    }
  }
}

class InsegnamentoStorico {
  const InsegnamentoStorico({
    required this.insegnamento,
    required this.mentoraggi,
  });

  final Map<String, dynamic> insegnamento;

  final List<Map<String, dynamic>> mentoraggi;
}