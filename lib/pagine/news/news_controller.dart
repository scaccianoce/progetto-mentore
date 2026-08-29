import 'package:flutter/foundation.dart';

import '../../app/app_core.dart';
import '../../dati/repository.dart';

/// Controller della pagina News.
///
/// Gestisce lo stato della pagina e tutte le operazioni sui dati. Il controller
/// sceglie esplicitamente la tabella `news`; il repository resta generico e non
/// contiene alcuna conoscenza del dominio News.
class NewsController extends ChangeNotifier {
  NewsController({
    required this.partecipante,
    required this.puoGestire,
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  final bool partecipante;
  final bool puoGestire;
  final DatabaseRepository db;

  List<Map<String, dynamic>> _news = const <Map<String, dynamic>>[];
  Map<String, dynamic>? _selezionata;
  bool _caricamento = false;
  bool _salvataggio = false;
  String? _errore;

  List<Map<String, dynamic>> get news => _news;
  Map<String, dynamic>? get selezionata => _selezionata;
  bool get caricamento => _caricamento;
  bool get salvataggio => _salvataggio;
  String? get errore => _errore;

  /// Carica le news visibili all'utente corrente.
  ///
  /// Per i partecipanti viene richiesto soltanto `attiva = true`; la sicurezza
  /// effettiva resta comunque affidata alle policy RLS del database.
  Future<void> carica() async {
    _caricamento = true;
    _errore = null;
    notifyListeners();

    final idSelezionato = _selezionata?['id']?.toString();

    try {
      final risultati = await db.tabella('news').elenco(
        filtri: <FiltroDb>[
          if (partecipante) const FiltroDb.uguale('attiva', true),
        ],
        ordinamenti: const <OrdineDb>[
          OrdineDb('data_pubblicazione', crescente: false),
          OrdineDb('id', crescente: false),
        ],
      );

      _news = risultati;
      _selezionata = _trovaSelezionata(
        risultati,
        idPreferito: idSelezionato,
      );
    } catch (e) {
      final errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile caricare le news.',
      );
      _errore = errore.messaggio;
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  /// Imposta la news selezionata nel pannello di dettaglio.
  void seleziona(Map<String, dynamic> news) {
    _selezionata = news;
    notifyListeners();
  }

  /// Inserisce o aggiorna una news e restituisce la riga salvata dal database.
  Future<Map<String, dynamic>> salva({
    Map<String, dynamic>? esistente,
    required Map<String, dynamic> valori,
  }) async {
    if (!puoGestire) {
      throw const AppException('Operazione non autorizzata.');
    }

    _salvataggio = true;
    _errore = null;
    notifyListeners();

    try {
      final valoriNormalizzati = normalizzaNews(valori, esistente);
      final tabella = db.tabella('news');

      final Map<String, dynamic> salvata;
      if (esistente == null) {
        salvata = await tabella.inserisci(valoriNormalizzati);
      } else {
        final id = esistente['id'];
        if (id == null || id.toString().trim().isEmpty) {
          throw const AppException('Identificativo della news non disponibile.');
        }

        final aggiornata = await tabella.aggiornaSingolo(
          valoriNormalizzati,
          filtri: <FiltroDb>[FiltroDb.uguale('id', id)],
        );
        if (aggiornata == null) {
          throw const AppException('News non trovata o non modificabile.');
        }
        salvata = aggiornata;
      }

      await _ricaricaDopoScrittura(salvata['id']?.toString());
      return salvata;
    } catch (e) {
      final errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile salvare la news.',
      );
      _errore = errore.messaggio;
      rethrow;
    } finally {
      _salvataggio = false;
      notifyListeners();
    }
  }

  /// Elimina la news indicata e aggiorna l'elenco locale.
  Future<void> elimina(Map<String, dynamic> news) async {
    if (!puoGestire) {
      throw const AppException('Operazione non autorizzata.');
    }

    final id = news['id'];
    if (id == null || id.toString().trim().isEmpty) {
      throw const AppException('Identificativo della news non disponibile.');
    }

    _salvataggio = true;
    _errore = null;
    notifyListeners();

    try {
      await db.tabella('news').elimina(
        filtri: <FiltroDb>[FiltroDb.uguale('id', id)],
      );
      await _ricaricaDopoScrittura(null);
    } catch (e) {
      final errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile eliminare la news.',
      );
      _errore = errore.messaggio;
      rethrow;
    } finally {
      _salvataggio = false;
      notifyListeners();
    }
  }

  /// Ricarica i dati dopo insert/update/delete preservando, quando possibile,
  /// il record appena salvato come selezione corrente.
  Future<void> _ricaricaDopoScrittura(String? idPreferito) async {
    final risultati = await db.tabella('news').elenco(
      filtri: <FiltroDb>[
        if (partecipante) const FiltroDb.uguale('attiva', true),
      ],
      ordinamenti: const <OrdineDb>[
        OrdineDb('data_pubblicazione', crescente: false),
        OrdineDb('id', crescente: false),
      ],
    );

    _news = risultati;
    _selezionata = _trovaSelezionata(
      risultati,
      idPreferito: idPreferito,
    );
  }

  /// Cerca il record preferito; se non esiste seleziona il primo disponibile.
  Map<String, dynamic>? _trovaSelezionata(
    List<Map<String, dynamic>> righe, {
    String? idPreferito,
  }) {
    if (righe.isEmpty) return null;

    if (idPreferito != null && idPreferito.isNotEmpty) {
      for (final riga in righe) {
        if (riga['id']?.toString() == idPreferito) return riga;
      }
    }

    return righe.first;
  }
}

/// Valida e normalizza i valori della news prima della scrittura sul database.
Map<String, dynamic> normalizzaNews(
  Map<String, dynamic> valori,
  Map<String, dynamic>? esistente,
) {
  final titolo = valori['titolo']?.toString().trim() ?? '';
  if (titolo.isEmpty) {
    throw const AppException('Il titolo e obbligatorio.');
  }

  final testo = valori['testo']?.toString().trim() ?? '';
  final data = DateTime.tryParse(
    valori['data_pubblicazione']?.toString() ?? '',
  );

  return <String, dynamic>{
    ...valori,
    'titolo': titolo,
    'testo': testo.isEmpty ? null : testo,
    if (data != null)
      'data_pubblicazione': data.toIso8601String().split('T').first,
    'attiva': valori['attiva'] ?? esistente?['attiva'] ?? true,
  };
}
