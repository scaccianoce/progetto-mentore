import 'package:flutter/foundation.dart';

import '../../app_exception.dart';
import '../../sessione_controller.dart';
import '../../supabase_config.dart';

class EventiController extends ChangeNotifier {
  EventiController(this.sessione);

  final SessioneController sessione;
  final List<Map<String, dynamic>> eventi = <Map<String, dynamic>>[];
  final Map<String, Map<String, dynamic>> iscrizioni =
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

  Future<void> carica() async {
    caricamento = true;
    errore = null;
    notifyListeners();
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) throw const AppException('Sessione non valida.');
      final risultati = await Future.wait<dynamic>(<Future<dynamic>>[
        SupabaseConfig.client
            .from('eventi')
            .select(
              'id, titolo, anno_accademico, luogo, data_evento, tipologia, descrizione, modalita, relatori, moderatori, note_organizzative, locandina_path, modulo_partecipazione_url, data_apertura_iscrizioni, data_chiusura_iscrizioni, questionario_gradimento_attivo, link_questionario_gradimento, created_at',
            )
            .order('data_evento', ascending: false),
        SupabaseConfig.client
            .from('partecipazioni_eventi')
            .select(
              'evento_id, partecipante_id, data_iscrizione, presente, questionario_compilato, data_compilazione',
            )
            .eq('partecipante_id', userId),
      ]);
      eventi
        ..clear()
        ..addAll((risultati[0] as List).cast<Map<String, dynamic>>());
      iscrizioni.clear();
      for (final riga in (risultati[1] as List).cast<Map<String, dynamic>>()) {
        iscrizioni[riga['evento_id'].toString()] = riga;
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

  Future<String?> salva({
    String? id,
    required Map<String, dynamic> dati,
  }) async {
    try {
      if (!puoGestire) throw const AppException('Operazione non autorizzata.');
      if (id == null) {
        await SupabaseConfig.client.from('eventi').insert(dati);
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
