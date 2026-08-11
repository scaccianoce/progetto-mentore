import 'package:flutter/foundation.dart';

import '../../app_exception.dart';
import '../../sessione_controller.dart';
import '../../supabase_config.dart';

class HouseOfMentoreController extends ChangeNotifier {
  HouseOfMentoreController(this.sessione);

  final SessioneController sessione;
  final eventi = <Map<String, dynamic>>[];
  final opzioniPerEvento = <String, List<Map<String, dynamic>>>{};
  final iscrizioni = <String, Map<String, dynamic>>{};
  final anniAccademici = <String>[];

  bool caricamento = false;
  String? errore;
  String? eventoSelezionatoId;

  bool get puoGestire => sessione.ruolo?.puoAmministrare ?? false;

  Map<String, dynamic>? get eventoSelezionato {
    for (final evento in eventi) {
      if (evento['id']?.toString() == eventoSelezionatoId) {
        return evento;
      }
    }
    return eventi.isEmpty ? null : eventi.first;
  }

  List<Map<String, dynamic>> opzioni(String eventoId) =>
      opzioniPerEvento[eventoId] ?? const <Map<String, dynamic>>[];

  Map<String, dynamic>? iscrizione(String eventoId) => iscrizioni[eventoId];

  Future<void> carica() async {
    caricamento = true;
    errore = null;
    notifyListeners();

    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) {
        throw const AppException('Sessione non valida.');
      }

      final db = SupabaseConfig.client;
      final risultati = await Future.wait<dynamic>([
        db
            .from('house_of_mentore')
            .select(
              'id, titolo, descrizione, anno_accademico, data_evento, luogo, locandina_url, iscrizioni_aperte, created_at, updated_at',
            )
            .order('data_evento', ascending: false, nullsFirst: false),
        db
            .from('house_of_mentore_opzioni')
            .select('id, evento_id, descrizione, ordine_visualizzazione')
            .order('ordine_visualizzazione'),
        db
            .from('partecipazioni_house_of_mentore')
            .select('evento_id, partecipante_id, opzione_id, data_iscrizione')
            .eq('partecipante_id', userId),
        db
            .from('anni_accademici')
            .select('codice')
            .order('codice', ascending: false),
      ]);

      eventi
        ..clear()
        ..addAll((risultati[0] as List).cast<Map<String, dynamic>>());

      opzioniPerEvento.clear();
      for (final opzione
          in (risultati[1] as List).cast<Map<String, dynamic>>()) {
        final eventoId = opzione['evento_id'].toString();
        opzioniPerEvento.putIfAbsent(eventoId, () => []).add(opzione);
      }

      iscrizioni.clear();
      for (final partecipazione
          in (risultati[2] as List).cast<Map<String, dynamic>>()) {
        iscrizioni[partecipazione['evento_id'].toString()] = partecipazione;
      }

      anniAccademici
        ..clear()
        ..addAll(
          (risultati[3] as List).cast<Map<String, dynamic>>().map(
            (riga) => riga['codice'].toString(),
          ),
        );

      if (eventi.isNotEmpty &&
          !eventi.any(
            (evento) => evento['id'].toString() == eventoSelezionatoId,
          )) {
        eventoSelezionatoId = eventi.first['id'].toString();
      }
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile caricare House of Mentore.',
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

  Future<String?> salvaEvento({
    String? id,
    required Map<String, dynamic> dati,
  }) => _esegui(
    azione: () async {
      _verificaGestore();
      if (id == null) {
        await SupabaseConfig.client.from('house_of_mentore').insert(dati);
      } else {
        await SupabaseConfig.client
            .from('house_of_mentore')
            .update(dati)
            .eq('id', id);
      }
    },
    messaggio: 'Impossibile salvare House of Mentore.',
  );

  Future<String?> eliminaEvento(String id) => _esegui(
    azione: () async {
      _verificaGestore();
      await SupabaseConfig.client
          .from('house_of_mentore')
          .delete()
          .eq('id', id);
      eventoSelezionatoId = null;
    },
    messaggio: 'Impossibile eliminare House of Mentore.',
  );

  Future<String?> salvaOpzione({
    String? id,
    required String eventoId,
    required String descrizione,
    required int ordine,
  }) => _esegui(
    azione: () async {
      _verificaGestore();
      final dati = <String, dynamic>{
        'evento_id': eventoId,
        'descrizione': descrizione.trim(),
        'ordine_visualizzazione': ordine,
      };
      if (id == null) {
        await SupabaseConfig.client
            .from('house_of_mentore_opzioni')
            .insert(dati);
      } else {
        await SupabaseConfig.client
            .from('house_of_mentore_opzioni')
            .update(dati)
            .eq('id', id);
      }
    },
    messaggio: 'Impossibile salvare l’alternativa.',
  );

  Future<String?> eliminaOpzione(String id) => _esegui(
    azione: () async {
      _verificaGestore();
      await SupabaseConfig.client
          .from('house_of_mentore_opzioni')
          .delete()
          .eq('id', id);
    },
    messaggio:
        'Impossibile eliminare l’alternativa. Potrebbe essere già stata scelta.',
  );

  Future<String?> scegliOpzione({
    required String eventoId,
    required String opzioneId,
  }) => _esegui(
    azione: () async {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) {
        throw const AppException('Sessione non valida.');
      }
      if (iscrizioni.containsKey(eventoId)) {
        await SupabaseConfig.client
            .from('partecipazioni_house_of_mentore')
            .update({'opzione_id': opzioneId})
            .eq('evento_id', eventoId)
            .eq('partecipante_id', userId);
      } else {
        await SupabaseConfig.client
            .from('partecipazioni_house_of_mentore')
            .insert({
              'evento_id': eventoId,
              'partecipante_id': userId,
              'opzione_id': opzioneId,
            });
      }
    },
    messaggio: 'Impossibile registrare la scelta.',
  );

  Future<String?> cancellaIscrizione(String eventoId) => _esegui(
    azione: () async {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) {
        throw const AppException('Sessione non valida.');
      }
      await SupabaseConfig.client
          .from('partecipazioni_house_of_mentore')
          .delete()
          .eq('evento_id', eventoId)
          .eq('partecipante_id', userId);
    },
    messaggio: 'Impossibile cancellare l’iscrizione.',
  );

  Future<String?> _esegui({
    required Future<void> Function() azione,
    required String messaggio,
  }) async {
    try {
      await azione();
      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(e, messaggioGenerico: messaggio).messaggio;
    }
  }

  void _verificaGestore() {
    if (!puoGestire) {
      throw const AppException('Operazione non autorizzata.');
    }
  }
}
