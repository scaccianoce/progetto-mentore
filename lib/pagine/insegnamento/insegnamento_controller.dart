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