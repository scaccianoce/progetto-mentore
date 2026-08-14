import 'package:flutter/foundation.dart';

import '../../app_exception.dart';
import '../../sessione_controller.dart';
import '../../supabase_config.dart';

class BackofficeController extends ChangeNotifier {
  BackofficeController(this.sessione);

  final SessioneController sessione;
  final partecipanti = <Map<String, dynamic>>[];
  final riservati = <String, Map<String, dynamic>>{};
  final ruoli = <String, String>{};
  final abilitazioni = <Map<String, dynamic>>[];
  final anni = <Map<String, dynamic>>[];
  final mentoraggi = <Map<String, dynamic>>[];
  final assegnazioni = <Map<String, dynamic>>[];
  List<String> ruoliDisponibili = const <String>[];
  List<String> tipiMentoreDisponibili = const <String>[];

  bool caricamento = false;
  String? errore;
  bool get soloOwner => sessione.ruolo == AppRole.owner;
  bool get puoAmministrare => sessione.ruolo?.puoAmministrare ?? false;

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
        db.from('anagrafica').select().order('cognome'),
        db.from('anagrafica_riservata').select(),
        db.from('abilitazioni_modifica').select().order('richiesta_at', ascending: false),
        db.from('anni_accademici').select().order('codice', ascending: false),
        db.from('mentoraggi').select(),
        db.from('mentoraggio_mentori').select(),
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
      // Tutte le opzioni dei menu amministrativi arrivano dal DB.
      // `user_roles.role` e `mentoraggio_mentori.tipo` devono essere
      // PostgreSQL ENUM esposti da app_database_schema.
      final schema = await SupabaseConfig.caricaSchemaDatabase();
      ruoliDisponibili =
          schema.tabella('user_roles')?.campo('role')?.valoriScelta ??
          const <String>[];
      tipiMentoreDisponibili =
          schema.tabella('mentoraggio_mentori')?.campo('tipo')?.valoriScelta ??
          const <String>[];

      ruoli.clear();
      if (puoAmministrare) {
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


  Future<String?> salvaAnagrafica(
    String userId,
    Map<String, dynamic> valori, {
    Map<String, dynamic>? originali,
  }) => _esegui(() async {
    if (!puoAmministrare) {
      throw const AppException('Operazione non autorizzata.');
    }

    // Inviamo al DB solo colonne realmente scrivibili e modificate.
    // Evita di reinviare PK, identity/generated, campi readonly e valori
    // tecnici che la maschera ha ricevuto soltanto per la visualizzazione.
    final schema = await SupabaseConfig.caricaSchemaDatabase();
    final tabella = schema.tabella('anagrafica');
    final dati = <String, dynamic>{};
    for (final voce in valori.entries) {
      if (voce.key == 'user_id') continue;
      final campo = tabella?.campo(voce.key);
      if (campo != null &&
          (campo.chiavePrimaria ||
              campo.identita ||
              campo.generato ||
              campo.solaLettura)) {
        continue;
      }
      if (originali != null && originali[voce.key] == voce.value) continue;
      dati[voce.key] = voce.value;
    }
    if (dati.isEmpty) return;

    // L'email di anagrafica coincide con l'email Auth: se cambia, la
    // sincronizzazione viene eseguita server-side dalla Edge Function.
    final nuovaEmail = dati.remove('email_unipa')?.toString().trim();
    if (nuovaEmail != null && nuovaEmail.isNotEmpty) {
      await _invocaUserAdmin(<String, dynamic>{
        'action': 'update_participant_email',
        'user_id': userId,
        'email': nuovaEmail,
      });
    }
    if (dati.isNotEmpty) {
      await SupabaseConfig.client
          .from('anagrafica')
          .update(dati)
          .eq('user_id', userId);
    }
  });

  Future<Map<String, dynamic>> _invocaUserAdmin(
    Map<String, dynamic> body,
  ) async {
    final risposta = await SupabaseConfig.client.functions.invoke(
      'backoffice-user-admin',
      body: body,
    );
    final data = risposta.data;
    if (data is String &&
        data.trimLeft().toLowerCase().startsWith('<!doctype html')) {
      throw const AppException(
        'La chiamata a backoffice-user-admin ha ricevuto la pagina HTML di Flutter. '
        'Deploya la Edge Function su Supabase e verifica SUPABASE_URL.',
      );
    }
    if (risposta.status < 200 || risposta.status >= 300) {
      throw AppException('Edge Function (${risposta.status}): $data');
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    throw AppException('Risposta non JSON dalla Edge Function: $data');
  }

  Future<String?> creaPartecipante(
    Map<String, dynamic> valori,
    String passwordTemporanea,
  ) => _esegui(() async {
    if (!puoAmministrare) {
      throw const AppException('Operazione non autorizzata.');
    }
    final email = valori['email_unipa']?.toString().trim() ?? '';
    if (email.isEmpty) {
      throw const AppException('Email UNIPA obbligatoria per creare l’utente.');
    }
    if (passwordTemporanea.length < 8) {
      throw const AppException('La password temporanea deve avere almeno 8 caratteri.');
    }
    await _invocaUserAdmin(<String, dynamic>{
      'action': 'create',
      'email': email,
      'password': passwordTemporanea,
      'anagrafica': valori,
    });
  });

  Future<String?> reimpostaPassword(
    String userId,
    String nuovaPassword,
  ) => _esegui(() async {
    if (!puoAmministrare) {
      throw const AppException('Operazione non autorizzata.');
    }
    if (nuovaPassword.length < 8) {
      throw const AppException('La nuova password deve avere almeno 8 caratteri.');
    }
    await _invocaUserAdmin(<String, dynamic>{
      'action': 'reset_password',
      'user_id': userId,
      'password': nuovaPassword,
    });
  });

  Future<String?> eliminaPartecipante(String userId) => _esegui(() async {
    if (!puoAmministrare) {
      throw const AppException('Operazione non autorizzata.');
    }
    // La cancellazione passa dal server per rimuovere coerentemente anche
    // auth.users. Eventuali FK storiche possono comunque bloccare l'operazione.
    await _invocaUserAdmin(<String, dynamic>{
      'action': 'delete_participant',
      'user_id': userId,
    });
  });
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
        if (!puoAmministrare) {
          throw const AppException('Operazione riservata al backoffice.');
        }
        await SupabaseConfig.client.from('anni_accademici').insert({
          'codice': codice.trim(),
          'data_inizio': _vuotoNull(inizio),
          'data_fine': _vuotoNull(fine),
          'corrente': false,
        });
      });

  Future<String?> impostaAnnoCorrente(String codice) => _esegui(() async {
    if (!puoAmministrare) {
      throw const AppException('Operazione riservata al backoffice.');
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
