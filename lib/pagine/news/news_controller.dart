import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_exception.dart';
import '../../sessione_controller.dart';
import '../../supabase_config.dart';

class News {
  const News({
    required this.id,
    required this.titolo,
    required this.testo,
    required this.dataPubblicazione,
    required this.attiva,
  });

  final int id;
  final String titolo;
  final String? testo;
  final DateTime? dataPubblicazione;
  final bool attiva;

  factory News.daDatabase(Map<String, dynamic> riga) {
    final Object? idDatabase = riga['id'];
    final int id = switch (idDatabase) {
      int valore => valore,
      num valore => valore.toInt(),
      String valore => int.parse(valore),
      _ => throw const FormatException('ID della news non valido.'),
    };

    final String titolo = riga['titolo']?.toString().trim() ?? '';
    if (titolo.isEmpty) {
      throw const FormatException('Titolo della news mancante.');
    }

    return News(
      id: id,
      titolo: titolo,
      testo: riga['testo']?.toString(),
      dataPubblicazione: DateTime.tryParse(
        riga['data_pubblicazione']?.toString() ?? '',
      ),
      attiva: riga['attiva'] as bool? ?? true,
    );
  }
}

class NewsController extends ChangeNotifier {
  NewsController({required this.ruolo, SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  static const String _colonne =
      'id, titolo, testo, data_pubblicazione, attiva';

  final AppRole ruolo;
  final SupabaseClient _client;

  List<News> _news = const <News>[];
  News? _selezionata;
  bool _caricamento = false;
  bool _salvataggio = false;
  String? _errore;

  List<News> get news => _news;
  News? get selezionata => _selezionata;
  bool get caricamento => _caricamento;
  bool get salvataggio => _salvataggio;
  String? get errore => _errore;
  bool get puoGestire => ruolo.puoAmministrare;

  Future<void> carica() async {
    _caricamento = true;
    _errore = null;
    notifyListeners();

    try {
      final query = _client.from('news').select(_colonne);
      final List<dynamic> righe =
          await (ruolo == AppRole.participant
                  ? query.eq('attiva', true)
                  : query)
              .order('data_pubblicazione', ascending: false, nullsFirst: false)
              .order('id', ascending: false);

      final int? idSelezionato = _selezionata?.id;
      _news = righe
          .cast<Map<String, dynamic>>()
          .map(News.daDatabase)
          .toList(growable: false);

      _selezionata =
          _trovaPerId(idSelezionato) ?? (_news.isEmpty ? null : _news.first);
    } catch (errore) {
      _errore = AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile caricare le news. Riprova.',
      ).messaggio;
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  void seleziona(News news) {
    if (_selezionata?.id == news.id) {
      return;
    }
    _selezionata = news;
    notifyListeners();
  }

  Future<void> salva({
    News? esistente,
    required String titolo,
    required String testo,
    required DateTime dataPubblicazione,
    required bool attiva,
  }) async {
    if (!puoGestire) {
      throw const AppException('Non hai i permessi per modificare le news.');
    }

    final String titoloPulito = titolo.trim();
    if (titoloPulito.isEmpty) {
      throw const AppException('Il titolo è obbligatorio.');
    }

    _salvataggio = true;
    _errore = null;
    notifyListeners();

    final DateTime soloData = DateTime(
      dataPubblicazione.year,
      dataPubblicazione.month,
      dataPubblicazione.day,
    );
    final Map<String, dynamic> valori = <String, dynamic>{
      'titolo': titoloPulito,
      'testo': testo.trim().isEmpty ? null : testo.trim(),
      'data_pubblicazione': soloData.toIso8601String(),
      'attiva': attiva,
    };

    try {
      final Map<String, dynamic>? riga = esistente == null
          ? await _client
                .from('news')
                .insert(valori)
                .select(_colonne)
                .maybeSingle()
          : await _client
                .from('news')
                .update(valori)
                .eq('id', esistente.id)
                .select(_colonne)
                .maybeSingle();

      if (riga == null) {
        throw const AppException('Salvataggio della news non riuscito.');
      }

      final News salvata = News.daDatabase(riga);
      await carica();
      _selezionata = _trovaPerId(salvata.id) ?? salvata;
    } catch (errore) {
      final AppException eccezione = AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile salvare la news. Riprova.',
      );
      _errore = eccezione.messaggio;
      throw eccezione;
    } finally {
      _salvataggio = false;
      notifyListeners();
    }
  }

  Future<void> elimina(News newsDaEliminare) async {
    if (!puoGestire) {
      throw const AppException('Non hai i permessi per eliminare le news.');
    }

    _salvataggio = true;
    _errore = null;
    notifyListeners();

    try {
      await _client.from('news').delete().eq('id', newsDaEliminare.id);
      _news = _news
          .where((News news) => news.id != newsDaEliminare.id)
          .toList(growable: false);
      _selezionata = _news.isEmpty ? null : _news.first;
    } catch (errore) {
      final AppException eccezione = AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile eliminare la news. Riprova.',
      );
      _errore = eccezione.messaggio;
      throw eccezione;
    } finally {
      _salvataggio = false;
      notifyListeners();
    }
  }

  News? _trovaPerId(int? id) {
    if (id == null) {
      return null;
    }
    for (final News elemento in _news) {
      if (elemento.id == id) {
        return elemento;
      }
    }
    return null;
  }
}
