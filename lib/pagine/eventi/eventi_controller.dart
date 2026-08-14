import 'package:flutter/foundation.dart';

import '../../app_exception.dart';
import '../../sessione_controller.dart';
import '../../supabase_config.dart';

class EventiController extends ChangeNotifier {
  EventiController(this.sessione);

  final SessioneController sessione;
  final List<Map<String, dynamic>> eventi = <Map<String, dynamic>>[];
  final List<String> anniAccademici = <String>[];
  final Map<String, Map<String, dynamic>> iscrizioni =
      <String, Map<String, dynamic>>{};

  /// Iscritti visibili solo a owner/organizer, raggruppati per evento.
  final Map<String, List<Map<String, dynamic>>> iscrittiPerEvento =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, Map<String, dynamic>> anagraficaPerUserId =
      <String, Map<String, dynamic>>{};

  bool caricamento = false;
  String? errore;
  String? eventoSelezionatoId;

  bool get puoGestire => sessione.ruolo?.puoAmministrare ?? false;
  Map<String, dynamic>? get eventoSelezionato {
    for (final evento in eventi) {
      if (evento['id']?.toString() == eventoSelezionatoId) return evento;
    }
    return eventi.isEmpty ? null : eventi.first;
  }

  bool iscritto(String eventoId) => iscrizioni.containsKey(eventoId);

  List<Map<String, dynamic>> iscritti(String eventoId) =>
      iscrittiPerEvento[eventoId] ?? const <Map<String, dynamic>>[];

  String nomePartecipante(String userId) {
    final persona = anagraficaPerUserId[userId];
    if (persona == null) return userId;
    final cognome = persona['cognome']?.toString().trim() ?? '';
    final nome = persona['nome']?.toString().trim() ?? '';
    final completo = '$cognome $nome'.trim();
    return completo.isEmpty ? userId : completo;
  }

  Future<void> carica() async {
    caricamento = true;
    errore = null;
    notifyListeners();
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) throw const AppException('Sessione non valida.');
      final risultati = await Future.wait<dynamic>(<Future<dynamic>>[
        _queryEventi(),
        SupabaseConfig.client
            .from('partecipazioni_eventi')
            .select(
              'evento_id, partecipante_id, data_iscrizione, presente, questionario_compilato, data_compilazione',
            )
            .eq('partecipante_id', userId),
        SupabaseConfig.client
            .from('anni_accademici')
            .select('codice')
            .order('codice', ascending: false),
      ]);
      eventi
        ..clear()
        ..addAll((risultati[0] as List).cast<Map<String, dynamic>>());
      iscrizioni.clear();
      for (final riga in (risultati[1] as List).cast<Map<String, dynamic>>()) {
        iscrizioni[riga['evento_id'].toString()] = riga;
      }
      anniAccademici
        ..clear()
        ..addAll(
          (risultati[2] as List).cast<Map<String, dynamic>>().map(
            (riga) => riga['codice'].toString(),
          ),
        );

      iscrittiPerEvento.clear();
      anagraficaPerUserId.clear();
      if (puoGestire) {
        final risultatiGestione = await Future.wait<dynamic>(<Future<dynamic>>[
          SupabaseConfig.client
              .from('partecipazioni_eventi')
              .select(
                'evento_id, partecipante_id, data_iscrizione, presente, questionario_compilato, data_compilazione',
              )
              .order('data_iscrizione', ascending: true),
          SupabaseConfig.client
              .from('anagrafica')
              .select('user_id, nome, cognome'),
        ]);

        for (final riga
            in (risultatiGestione[0] as List).cast<Map<String, dynamic>>()) {
          final eventoId = riga['evento_id']?.toString() ?? '';
          if (eventoId.isEmpty) continue;
          iscrittiPerEvento.putIfAbsent(eventoId, () => <Map<String, dynamic>>[]).add(riga);
        }
        for (final persona
            in (risultatiGestione[1] as List).cast<Map<String, dynamic>>()) {
          final id = persona['user_id']?.toString() ?? '';
          if (id.isNotEmpty) anagraficaPerUserId[id] = persona;
        }
      }

      if (eventoSelezionatoId == null && eventi.isNotEmpty) {
        eventoSelezionatoId = eventi.first['id'].toString();
      }
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile caricare gli eventi.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }


  Future<List<Map<String, dynamic>>> _queryEventi() async {
    var query = SupabaseConfig.client.from('eventi').select(
      'id, titolo, anno_accademico, luogo, data_evento, tipologia, descrizione, modalita, relatori, moderatori, note_organizzative, locandina_path, modulo_partecipazione_url, data_apertura_iscrizioni, data_chiusura_iscrizioni, questionario_gradimento_attivo, link_questionario_gradimento, attiva, created_at',
    );
    if (!puoGestire) {
      query = query.eq('attiva', true);
    }
    final righe = await query.order('data_evento', ascending: false);
    return righe.cast<Map<String, dynamic>>();
  }

  void seleziona(Map<String, dynamic> evento) {
    eventoSelezionatoId = evento['id'].toString();
    notifyListeners();
  }

  bool iscrizioniAperte(Map<String, dynamic> evento) {
    final oggi = DateTime.now();
    final data = DateTime(oggi.year, oggi.month, oggi.day);
    final apertura = DateTime.tryParse(
      evento['data_apertura_iscrizioni']?.toString() ?? '',
    );
    final chiusura = DateTime.tryParse(
      evento['data_chiusura_iscrizioni']?.toString() ?? '',
    );
    return (apertura == null || !data.isBefore(apertura)) &&
        (chiusura == null || !data.isAfter(chiusura));
  }

  Future<String?> cambiaIscrizione(Map<String, dynamic> evento) async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) throw const AppException('Sessione non valida.');
      final eventoId = evento['id'].toString();
      if (iscritto(eventoId)) {
        await SupabaseConfig.client
            .from('partecipazioni_eventi')
            .delete()
            .eq('evento_id', eventoId)
            .eq('partecipante_id', userId);
      } else {
        await SupabaseConfig.client.from('partecipazioni_eventi').insert({
          'evento_id': eventoId,
          'partecipante_id': userId,
        });
      }
      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile aggiornare l’iscrizione.',
      ).messaggio;
    }
  }


  Future<String?> aggiornaPartecipazione({
    required String eventoId,
    required String partecipanteId,
    required bool presente,
    required bool questionarioCompilato,
    DateTime? dataCompilazione,
  }) async {
    try {
      if (!puoGestire) throw const AppException('Operazione non autorizzata.');
      await SupabaseConfig.client
          .from('partecipazioni_eventi')
          .update(<String, dynamic>{
            'presente': presente,
            'questionario_compilato': questionarioCompilato,
            'data_compilazione': dataCompilazione == null
                ? null
                : '${dataCompilazione.year.toString().padLeft(4, '0')}-${dataCompilazione.month.toString().padLeft(2, '0')}-${dataCompilazione.day.toString().padLeft(2, '0')}',
          })
          .eq('evento_id', eventoId)
          .eq('partecipante_id', partecipanteId);
      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile aggiornare la partecipazione.',
      ).messaggio;
    }
  }

  Future<String?> salva({
    String? id,
    required Map<String, dynamic> dati,
  }) async {
    try {
      if (!puoGestire) throw const AppException('Operazione non autorizzata.');
      if (id == null) {
        await SupabaseConfig.client.from('eventi').insert(<String, dynamic>{
          ...dati,
          'attiva': dati['attiva'] ?? true,
        });
      } else {
        await SupabaseConfig.client.from('eventi').update(dati).eq('id', id);
      }
      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile salvare l’evento.',
      ).messaggio;
    }
  }

  Future<String?> elimina(String id) async {
    try {
      if (!puoGestire) throw const AppException('Operazione non autorizzata.');
      await SupabaseConfig.client.from('eventi').delete().eq('id', id);
      eventoSelezionatoId = null;
      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile eliminare l’evento.',
      ).messaggio;
    }
  }
}
