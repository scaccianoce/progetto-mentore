import 'package:flutter/foundation.dart';

import '../../app_exception.dart';
import '../../sessione_controller.dart';
import '../../supabase_config.dart';

class AmministrazioneController extends ChangeNotifier {
  AmministrazioneController(this.sessione);

  final SessioneController sessione;
  final partecipanti = <Map<String, dynamic>>[];
  final riservati = <String, Map<String, dynamic>>{};
  final ruoli = <String, String>{};
  final abilitazioni = <Map<String, dynamic>>[];
  final anni = <Map<String, dynamic>>[];
  final mentoraggi = <Map<String, dynamic>>[];
  final assegnazioni = <Map<String, dynamic>>[];

  bool caricamento = false;
  String? errore;
  bool get soloOwner => sessione.ruolo == AppRole.owner;

  String nomeUtente(Object? id) {
    final chiave = id?.toString();
    for (final persona in partecipanti) {
      if (persona['user_id']?.toString() == chiave) {
        return '${persona['cognome'] ?? ''} ${persona['nome'] ?? ''}'.trim();
      }
    }
    return chiave ?? '';
  }

  Future<void> carica() async {
    caricamento = true;
    errore = null;
    notifyListeners();
    try {
      final db = SupabaseConfig.client;
      final risultati = await Future.wait<dynamic>([
        db
            .from('anagrafica')
            .select(
              'user_id, email_unipa, cognome, nome, cod_ssd, dipartimento, ufficio, ruolo_accademico, cellulare, fascia_eta, pagina_personale_unipa, anno_prima_partecipazione',
            )
            .order('cognome'),
        db
            .from('anagrafica_riservata')
            .select('user_id, note_storiche, attivo'),
        db
            .from('abilitazioni_modifica')
            .select(
              'user_id, ambito, anno_accademico, richiesta_at, abilitata, abilitata_da, abilitata_at, scade_at, revocata_at',
            )
            .order('richiesta_at', ascending: false),
        db
            .from('anni_accademici')
            .select('codice, data_inizio, data_fine, corrente')
            .order('codice', ascending: false),
        db.from('mentoraggi').select('id, insegnamento_id, stato_mentoraggio'),
        db
            .from('mentoraggio_mentori')
            .select('mentoraggio_id, mentore_id, tipo, assegnato_il'),
      ]);
      partecipanti
        ..clear()
        ..addAll((risultati[0] as List).cast<Map<String, dynamic>>());
      riservati.clear();
      for (final r in (risultati[1] as List).cast<Map<String, dynamic>>()) {
        riservati[r['user_id'].toString()] = r;
      }
      abilitazioni
        ..clear()
        ..addAll((risultati[2] as List).cast<Map<String, dynamic>>());
      anni
        ..clear()
        ..addAll((risultati[3] as List).cast<Map<String, dynamic>>());
      mentoraggi
        ..clear()
        ..addAll((risultati[4] as List).cast<Map<String, dynamic>>());
      assegnazioni
        ..clear()
        ..addAll((risultati[5] as List).cast<Map<String, dynamic>>());
      ruoli.clear();
      if (soloOwner) {
        final righe = await db.from('user_roles').select('user_id, role');
        for (final r in righe) {
          ruoli[r['user_id'].toString()] = r['role'].toString();
        }
      }
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile caricare i dati amministrativi.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  Future<String?> salvaRiservati(String userId, bool attivo, String note) =>
      _esegui(() async {
        await SupabaseConfig.client.from('anagrafica_riservata').upsert({
          'user_id': userId,
          'attivo': attivo,
          'note_storiche': note.trim().isEmpty ? null : note.trim(),
        });
      });

  Future<String?> cambiaRuolo(String userId, String ruolo) => _esegui(() async {
    if (!soloOwner) {
      throw const AppException('Operazione riservata al proprietario.');
    }
    await SupabaseConfig.client
        .from('user_roles')
        .update({'role': ruolo})
        .eq('user_id', userId);
  });

  Future<String?> cambiaAbilitazione(Map<String, dynamic> riga, bool abilita) =>
      _esegui(() async {
        final adesso = DateTime.now().toIso8601String();
        await SupabaseConfig.client
            .from('abilitazioni_modifica')
            .update(
              abilita
                  ? {
                      'abilitata': true,
                      'abilitata_da': sessione.utente!.id,
                      'abilitata_at': adesso,
                      'revocata_at': null,
                    }
                  : {'abilitata': false, 'revocata_at': adesso},
            )
            .eq('user_id', riga['user_id'])
            .eq('ambito', riga['ambito'])
            .eq('anno_accademico', riga['anno_accademico']);
      });

  Future<String?> aggiungiAnno(String codice, String? inizio, String? fine) =>
      _esegui(() async {
        if (!soloOwner) {
          throw const AppException('Operazione riservata al proprietario.');
        }
        await SupabaseConfig.client.from('anni_accademici').insert({
          'codice': codice.trim(),
          'data_inizio': _vuotoNull(inizio),
          'data_fine': _vuotoNull(fine),
          'corrente': false,
        });
      });

  Future<String?> impostaAnnoCorrente(String codice) => _esegui(() async {
    if (!soloOwner) {
      throw const AppException('Operazione riservata al proprietario.');
    }
    await SupabaseConfig.client.rpc(
      'imposta_anno_accademico_corrente',
      params: {'p_codice': codice},
    );
  });

  Future<String?> aggiungiAssegnazione(
    String mentoraggioId,
    String mentoreId,
    String tipo,
  ) => _esegui(() async {
    await SupabaseConfig.client.from('mentoraggio_mentori').insert({
      'mentoraggio_id': mentoraggioId,
      'mentore_id': mentoreId,
      'tipo': tipo,
      'assegnato_il': DateTime.now().toIso8601String().split('T').first,
    });
  });

  Future<String?> eliminaAssegnazione(Map<String, dynamic> riga) =>
      _esegui(() async {
        await SupabaseConfig.client
            .from('mentoraggio_mentori')
            .delete()
            .eq('mentoraggio_id', riga['mentoraggio_id'])
            .eq('mentore_id', riga['mentore_id'])
            .eq('tipo', riga['tipo']);
      });

  Future<String?> _esegui(Future<void> Function() azione) async {
    try {
      await azione();
      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Operazione amministrativa non riuscita.',
      ).messaggio;
    }
  }
}

String? _vuotoNull(String? valore) =>
    valore == null || valore.trim().isEmpty ? null : valore.trim();
