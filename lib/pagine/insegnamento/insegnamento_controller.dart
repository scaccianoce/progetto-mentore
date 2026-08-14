import 'package:flutter/foundation.dart';

import '../../app_exception.dart';
import '../../dinamico/controller_crud_dinamico.dart';
import '../../dinamico/repository_dinamico.dart';
import '../../sessione_controller.dart';

/// Controller specifico SOLO per il contesto dell'insegnamento.
///
/// Il CRUD e lo stato di caricamento/salvataggio del record sono delegati a
/// ControllerSchedaCrudDinamico. Qui resta la sola logica di dominio:
/// utente corrente + anno accademico corrente.
class InsegnamentoController extends ChangeNotifier {
  InsegnamentoController({
    required this.sessione,
    RepositoryDinamico? repository,
  }) : _repository = repository ?? RepositoryDinamico(),
       _crud = ControllerSchedaCrudDinamico(
         tabella: 'insegnamenti',
         messaggioErroreCaricamento: 'Impossibile caricare l’insegnamento.',
         messaggioErroreSalvataggio: 'Impossibile salvare l’insegnamento.',
       ) {
    _crud.addListener(_propaga);
  }

  final SessioneController sessione;
  final RepositoryDinamico _repository;
  final ControllerSchedaCrudDinamico _crud;

  String? _annoCorrente;
  bool _caricamentoContesto = false;
  String? _erroreContesto;

  Map<String, dynamic>? get insegnamento => _crud.record;
  String? get annoCorrente => _annoCorrente;
  bool get puoModificare => _annoCorrente != null && sessione.utente != null;
  bool get caricamento => _caricamentoContesto || _crud.caricamento;
  bool get salvataggio => _crud.salvataggio;
  String? get errore => _erroreContesto ?? _crud.errore;

  Future<void> carica() async {
    final userId = sessione.utente?.id;
    if (userId == null) {
      _erroreContesto = 'Sessione assente.';
      notifyListeners();
      return;
    }

    _caricamentoContesto = true;
    _erroreContesto = null;
    notifyListeners();
    try {
      final anno = await _repository.singolo(
        tabella: 'anni_accademici',
        colonne: 'codice',
        filtri: const <FiltroDinamico>[FiltroDinamico('corrente', true)],
      );
      _annoCorrente = anno?['codice']?.toString();
      if (_annoCorrente == null) {
        throw const AppException('Nessun anno accademico corrente impostato.');
      }

      await _crud.carica(
        filtri: <FiltroDinamico>[
          FiltroDinamico('docente_id', userId),
          FiltroDinamico('anno_accademico', _annoCorrente!),
        ],
      );
    } catch (errore) {
      _erroreContesto = AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile determinare l’anno accademico corrente.',
      ).messaggio;
    } finally {
      _caricamentoContesto = false;
      notifyListeners();
    }
  }

  Future<void> salva(Map<String, dynamic> valori) async {
    final userId = sessione.utente?.id;
    if (userId == null || _annoCorrente == null) {
      throw const AppException('Modifica dell’insegnamento non autorizzata.');
    }
    await _crud.salva(<String, dynamic>{
      ...valori,
      'docente_id': userId,
      'anno_accademico': _annoCorrente,
    });
  }

  void _propaga() => notifyListeners();

  @override
  void dispose() {
    _crud.removeListener(_propaga);
    _crud.dispose();
    super.dispose();
  }
}
