import 'package:flutter/foundation.dart';

import '../app_exception.dart';
import 'repository_dinamico.dart';

typedef NormalizzaValoriDinamici = Map<String, dynamic> Function(
  Map<String, dynamic> valori,
  Map<String, dynamic>? esistente,
);

/// Controller CRUD generico per pagine elenco + dettaglio.
///
/// Una pagina standard deve dichiarare soltanto tabella, filtri, ordinamenti
/// ed eventuale normalizzazione/validazione dei valori prima del salvataggio.
class ControllerElencoCrudDinamico extends ChangeNotifier {
  ControllerElencoCrudDinamico({
    required this.tabella,
    this.campoId = 'id',
    this.colonne = '*',
    this.filtri = const <FiltroDinamico>[],
    this.ordinamenti = const <OrdinamentoDinamico>[],
    this.puoGestire = false,
    this.normalizzaValori,
    this.messaggioErroreCaricamento = 'Impossibile caricare i dati.',
    this.messaggioErroreSalvataggio = 'Impossibile salvare i dati.',
    this.messaggioErroreEliminazione = 'Impossibile eliminare il dato.',
    RepositoryDinamico? repository,
  }) : _repository = repository ?? RepositoryDinamico();

  final String tabella;
  final String campoId;
  final String colonne;
  final List<FiltroDinamico> filtri;
  final List<OrdinamentoDinamico> ordinamenti;
  final bool puoGestire;
  final NormalizzaValoriDinamici? normalizzaValori;
  final String messaggioErroreCaricamento;
  final String messaggioErroreSalvataggio;
  final String messaggioErroreEliminazione;
  final RepositoryDinamico _repository;

  List<Map<String, dynamic>> _record = const <Map<String, dynamic>>[];
  Map<String, dynamic>? _selezionato;
  bool _caricamento = false;
  bool _salvataggio = false;
  String? _errore;

  List<Map<String, dynamic>> get record => _record;
  Map<String, dynamic>? get selezionato => _selezionato;
  bool get caricamento => _caricamento;
  bool get salvataggio => _salvataggio;
  String? get errore => _errore;

  Future<void> carica() async {
    _caricamento = true;
    _errore = null;
    notifyListeners();
    try {
      final idSelezionato = _selezionato?[campoId];
      _record = await _repository.elenco(
        tabella: tabella,
        colonne: colonne,
        filtri: filtri,
        ordinamenti: ordinamenti,
      );
      _selezionato = _trovaPerId(idSelezionato) ??
          (_record.isEmpty ? null : _record.first);
    } catch (errore) {
      _errore = AppErrorMapper.converti(
        errore,
        messaggioGenerico: messaggioErroreCaricamento,
      ).messaggio;
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  void seleziona(Map<String, dynamic> record) {
    if (_selezionato?[campoId] == record[campoId]) return;
    _selezionato = record;
    notifyListeners();
  }

  Future<Map<String, dynamic>> salva({
    Map<String, dynamic>? esistente,
    required Map<String, dynamic> valori,
  }) async {
    if (!puoGestire) {
      throw const AppException('Non hai i permessi per modificare questi dati.');
    }

    _salvataggio = true;
    _errore = null;
    notifyListeners();
    try {
      final payload = normalizzaValori?.call(valori, esistente) ?? valori;
      final Map<String, dynamic>? salvato = esistente == null
          ? await _repository.inserisci(
              tabella: tabella,
              valori: payload,
              colonne: colonne,
            )
          : await _repository.aggiorna(
              tabella: tabella,
              campoFiltro: campoId,
              valoreFiltro: esistente[campoId]!,
              valori: payload,
              colonne: colonne,
            );
      if (salvato == null) {
        throw AppException(messaggioErroreSalvataggio);
      }
      await carica();
      _selezionato = _trovaPerId(salvato[campoId]) ?? salvato;
      notifyListeners();
      return salvato;
    } catch (errore) {
      final eccezione = AppErrorMapper.converti(
        errore,
        messaggioGenerico: messaggioErroreSalvataggio,
      );
      _errore = eccezione.messaggio;
      throw eccezione;
    } finally {
      _salvataggio = false;
      notifyListeners();
    }
  }

  Future<void> elimina(Map<String, dynamic> recordDaEliminare) async {
    if (!puoGestire) {
      throw const AppException('Non hai i permessi per eliminare questi dati.');
    }
    final id = recordDaEliminare[campoId];
    if (id == null) throw const AppException('Identificativo del dato mancante.');

    _salvataggio = true;
    _errore = null;
    notifyListeners();
    try {
      await _repository.elimina(
        tabella: tabella,
        campoFiltro: campoId,
        valoreFiltro: id,
      );
      _record = _record
          .where((record) => record[campoId] != id)
          .toList(growable: false);
      _selezionato = _record.isEmpty ? null : _record.first;
    } catch (errore) {
      final eccezione = AppErrorMapper.converti(
        errore,
        messaggioGenerico: messaggioErroreEliminazione,
      );
      _errore = eccezione.messaggio;
      throw eccezione;
    } finally {
      _salvataggio = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? _trovaPerId(Object? id) {
    if (id == null) return null;
    for (final record in _record) {
      if (record[campoId] == id) return record;
    }
    return null;
  }
}

/// Controller CRUD generico per una scheda singola.
class ControllerSchedaCrudDinamico extends ChangeNotifier {
  ControllerSchedaCrudDinamico({
    required this.tabella,
    this.campoId = 'id',
    this.colonne = '*',
    this.puoGestire = true,
    this.normalizzaValori,
    this.includiFiltriInInserimento = true,
    this.messaggioErroreCaricamento = 'Impossibile caricare i dati.',
    this.messaggioErroreSalvataggio = 'Impossibile salvare i dati.',
    RepositoryDinamico? repository,
  }) : _repository = repository ?? RepositoryDinamico();

  final String tabella;
  final String campoId;
  final String colonne;
  final bool puoGestire;
  final NormalizzaValoriDinamici? normalizzaValori;
  final bool includiFiltriInInserimento;
  final String messaggioErroreCaricamento;
  final String messaggioErroreSalvataggio;
  final RepositoryDinamico _repository;

  Map<String, dynamic>? _record;
  List<FiltroDinamico> _filtri = const <FiltroDinamico>[];
  bool _caricamento = false;
  bool _salvataggio = false;
  String? _errore;

  Map<String, dynamic>? get record => _record;
  bool get caricamento => _caricamento;
  bool get salvataggio => _salvataggio;
  String? get errore => _errore;
  List<FiltroDinamico> get filtri => _filtri;

  Future<void> carica({required List<FiltroDinamico> filtri}) async {
    _filtri = filtri;
    _caricamento = true;
    _errore = null;
    notifyListeners();
    try {
      _record = await _repository.singolo(
        tabella: tabella,
        colonne: colonne,
        filtri: filtri,
      );
    } catch (errore) {
      _errore = AppErrorMapper.converti(
        errore,
        messaggioGenerico: messaggioErroreCaricamento,
      ).messaggio;
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> salva(Map<String, dynamic> valori) async {
    if (!puoGestire) {
      throw const AppException('Non hai i permessi per modificare questi dati.');
    }
    _salvataggio = true;
    _errore = null;
    notifyListeners();
    try {
      final payload = normalizzaValori?.call(valori, _record) ?? valori;
      final valoriInserimento = includiFiltriInInserimento
          ? <String, dynamic>{
              for (final filtro in _filtri) filtro.campo: filtro.valore,
              ...payload,
            }
          : payload;
      final Map<String, dynamic>? salvato = _record == null
          ? await _repository.inserisci(
              tabella: tabella,
              valori: valoriInserimento,
              colonne: colonne,
            )
          : await _repository.aggiorna(
              tabella: tabella,
              campoFiltro: campoId,
              valoreFiltro: _record![campoId]!,
              valori: payload,
              colonne: colonne,
            );
      if (salvato == null) throw AppException(messaggioErroreSalvataggio);
      _record = salvato;
      return salvato;
    } catch (errore) {
      final eccezione = AppErrorMapper.converti(
        errore,
        messaggioGenerico: messaggioErroreSalvataggio,
      );
      _errore = eccezione.messaggio;
      throw eccezione;
    } finally {
      _salvataggio = false;
      notifyListeners();
    }
  }
}
