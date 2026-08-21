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
  final partecipazioniAnnuali = <Map<String, dynamic>>[];
  final anni = <Map<String, dynamic>>[];
  final insegnamenti = <Map<String, dynamic>>[];
  final mentoraggi = <Map<String, dynamic>>[];
  final assegnazioni = <Map<String, dynamic>>[];

  List<String> ruoliDisponibili = const <String>[];
  List<String> tipiMentoreDisponibili = const <String>[];

  bool caricamento = false;
  String? errore;

  bool get soloOwner => sessione.ruolo == AppRole.owner;
  bool get puoAmministrare => sessione.ruolo?.puoAmministrare ?? false;

  static const List<String> ambitiInsegnamento = <String>[
    'insegnamento_selezione',
    'insegnamento_creazione',
    'insegnamento_modifica',
    'insegnamento_non_richiesto',
  ];

  String? get annoAttivo {
    for (final anno in anni) {
      if (anno['stato']?.toString() == 'attivo' || _vero(anno['corrente'])) {
        final codice = anno['codice']?.toString();
        if (codice != null && codice.isNotEmpty) return codice;
      }
    }
    return null;
  }

  String? get annoPreparazione {
    for (final anno in anni) {
      if (anno['stato']?.toString() == 'preparazione') {
        final codice = anno['codice']?.toString();
        if (codice != null && codice.isNotEmpty) return codice;
      }
    }
    return null;
  }

  /// Anno usato per conferma/creazione/modifica dell'insegnamento.
  /// Se esiste un anno in preparazione viene usato quello; altrimenti
  /// l'anno operativo attivo.
  String? get annoGestioneInsegnamenti => annoPreparazione ?? annoAttivo;

  /// Compatibilità con il codice precedente: "corrente" = anno operativo.
  String? get annoCorrente => annoAttivo;

  bool abilitazioneAttiva(
    String userId,
    String ambito,
    String annoAccademico,
  ) {
    final adesso = DateTime.now();
    for (final riga in abilitazioni) {
      if (riga['user_id']?.toString() != userId ||
          riga['ambito']?.toString() != ambito ||
          riga['anno_accademico']?.toString() != annoAccademico) {
        continue;
      }
      if (riga['abilitata'] != true || riga['revocata_at'] != null) {
        return false;
      }
      final scadenza = DateTime.tryParse(riga['scade_at']?.toString() ?? '');
      return scadenza == null || scadenza.isAfter(adesso);
    }
    return false;
  }

  Map<String, dynamic>? partecipazioneAnnuale(
    String userId,
    String annoAccademico,
  ) {
    for (final riga in partecipazioniAnnuali) {
      if (riga['user_id']?.toString() == userId &&
          riga['anno_accademico']?.toString() == annoAccademico) {
        return riga;
      }
    }
    return null;
  }

  String statoPartecipazione(String userId, String annoAccademico) =>
      partecipazioneAnnuale(userId, annoAccademico)?['stato']?.toString() ??
      'non_presente';

  bool gestioneInsegnamentiAttiva(String userId) {
    final anno = annoGestioneInsegnamenti;
    if (anno == null) return false;
    return abilitazioneAttiva(userId, 'insegnamento_creazione', anno) &&
        abilitazioneAttiva(userId, 'insegnamento_modifica', anno);
  }

  Future<String?> impostaGestioneInsegnamentiCorrente(
    String userId,
    bool abilita,
  ) =>
      _esegui(() async {
        if (!puoAmministrare) {
          throw const AppException('Operazione non autorizzata.');
        }

        final anno = annoGestioneInsegnamenti;
        if (anno == null) {
          throw const AppException(
            'Nessun anno accademico attivo o in preparazione configurato.',
          );
        }

        if (abilita) {
          final stato = statoPartecipazione(userId, anno);
          if (annoPreparazione == anno &&
              stato != 'confermato' &&
              stato != 'nuovo') {
            throw const AppException(
              'Per l’anno in preparazione il partecipante deve prima '
              'confermare la partecipazione.',
            );
          }

          await SupabaseConfig.client.rpc(
            'abilitazione_modifica_imposta',
            params: <String, dynamic>{
              'p_user_id': userId,
              'p_ambito': 'insegnamento_non_richiesto',
              'p_anno_accademico': anno,
              'p_abilitata': false,
              'p_scade_at': null,
            },
          );
        }

        for (final ambito in const <String>[
          'insegnamento_creazione',
          'insegnamento_modifica',
          'insegnamento_selezione',
        ]) {
          await SupabaseConfig.client.rpc(
            'abilitazione_modifica_imposta',
            params: <String, dynamic>{
              'p_user_id': userId,
              'p_ambito': ambito,
              'p_anno_accademico': anno,
              'p_abilitata': abilita,
              'p_scade_at': null,
            },
          );
        }
      });

  String nomeUtente(Object? id) {
    final persona = personaPerId(id?.toString());
    if (persona == null) return id?.toString() ?? '';
    final nome = '${persona['cognome'] ?? ''} ${persona['nome'] ?? ''}'.trim();
    return nome.isEmpty ? persona['email_unipa']?.toString() ?? '' : nome;
  }

  Map<String, dynamic>? personaPerId(String? userId) {
    if (userId == null) return null;
    for (final persona in partecipanti) {
      if (persona['user_id']?.toString() == userId) return persona;
    }
    return null;
  }

  String etichettaPersona(String? userId) {
    final persona = personaPerId(userId);
    if (persona == null) return userId ?? '—';
    final nome = '${persona['cognome'] ?? ''} ${persona['nome'] ?? ''}'.trim();
    final email = persona['email_unipa']?.toString().trim() ?? '';
    if (nome.isEmpty) return email.isEmpty ? userId ?? '—' : email;
    return email.isEmpty ? nome : '$nome — $email';
  }

  Map<String, dynamic>? insegnamentoPerId(String? id) {
    if (id == null) return null;
    for (final riga in insegnamenti) {
      if (riga['id']?.toString() == id) return riga;
    }
    return null;
  }

  Future<void> carica() async {
    caricamento = true;
    errore = null;
    notifyListeners();

    try {
      final db = SupabaseConfig.client;
      final risultati = await Future.wait<dynamic>([
        db.from('anagrafica').select(),
        db.from('anagrafica_riservata').select(),
        db
            .from('abilitazioni_modifica')
            .select()
            .order('richiesta_at', ascending: false),
        db.from('partecipazioni_annuali').select(),
        db.from('anni_accademici').select().order('codice', ascending: false),
        db.from('insegnamenti').select(),
        db.from('mentoraggi').select(),
        db.from('mentoraggio_mentori').select(),
      ]);

      final elencoPartecipanti = (risultati[0] as List)
          .cast<Map<String, dynamic>>()
          .toList(growable: true)
        ..sort((a, b) {
          final cognomeA = a['cognome']?.toString().trim().toLowerCase() ?? '';
          final cognomeB = b['cognome']?.toString().trim().toLowerCase() ?? '';
          final c = cognomeA.compareTo(cognomeB);
          if (c != 0) return c;
          final nomeA = a['nome']?.toString().trim().toLowerCase() ?? '';
          final nomeB = b['nome']?.toString().trim().toLowerCase() ?? '';
          return nomeA.compareTo(nomeB);
        });

      partecipanti
        ..clear()
        ..addAll(elencoPartecipanti);

      riservati.clear();
      for (final r in (risultati[1] as List).cast<Map<String, dynamic>>()) {
        riservati[r['user_id'].toString()] = r;
      }

      abilitazioni
        ..clear()
        ..addAll((risultati[2] as List).cast<Map<String, dynamic>>());
      partecipazioniAnnuali
        ..clear()
        ..addAll((risultati[3] as List).cast<Map<String, dynamic>>());
      anni
        ..clear()
        ..addAll((risultati[4] as List).cast<Map<String, dynamic>>());
      insegnamenti
        ..clear()
        ..addAll((risultati[5] as List).cast<Map<String, dynamic>>());
      mentoraggi
        ..clear()
        ..addAll((risultati[6] as List).cast<Map<String, dynamic>>());
      assegnazioni
        ..clear()
        ..addAll((risultati[7] as List).cast<Map<String, dynamic>>());

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
  }) =>
      _esegui(() async {
        if (!puoAmministrare) {
          throw const AppException('Operazione non autorizzata.');
        }

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

        final nuovaEmail = dati.remove('email_unipa')?.toString().trim();
        if (nuovaEmail != null && nuovaEmail.isNotEmpty) {
          await _invocaUserAdmin(<String, dynamic>{
            'action': 'update_email',
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
  ) async {
    try {
      if (!puoAmministrare) {
        throw const AppException(
          'Operazione non autorizzata.',
        );
      }

      final email =
          valori['email_unipa']?.toString().trim() ?? '';

      if (email.isEmpty) {
        throw const AppException(
          'Email UNIPA obbligatoria per creare l’utente.',
        );
      }

      if (passwordTemporanea.length < 8) {
        throw const AppException(
          'La password temporanea deve avere almeno 8 caratteri.',
        );
      }

      final risposta =
          await SupabaseConfig.client.functions.invoke(
        'backoffice-user-admin',
        body: <String, dynamic>{
          'action': 'create_user',
          'email': email,
          'password': passwordTemporanea,
          'anagrafica': valori,
          'anagrafica_riservata': <String, dynamic>{
            'attivo': true,
          },
        },
      );

      final data = risposta.data;

      if (risposta.status < 200 ||
          risposta.status >= 300) {
        return 'Edge Function ${risposta.status}: $data';
      }

      await carica();

      return null;
    } catch (e) {
      return 'Creazione partecipante non riuscita: $e';
    }
  }
  
    Future<String?> reimpostaPassword(
    String userId,
    String nuovaPassword,
  ) =>
      _esegui(() async {
        if (!puoAmministrare) {
          throw const AppException('Operazione non autorizzata.');
        }
        if (nuovaPassword.length < 8) {
          throw const AppException(
            'La nuova password deve avere almeno 8 caratteri.',
          );
        }
        await _invocaUserAdmin(<String, dynamic>{
          'action': 'reset_password',
          'user_id': userId,
          'password': nuovaPassword,
        });
      });

  Future<String?> eliminaPartecipante(String userId) =>
      _esegui(() async {
        if (!soloOwner) {
          throw const AppException('Operazione riservata al proprietario.');
        }
        await _invocaUserAdmin(<String, dynamic>{
          'action': 'delete_user',
          'user_id': userId,
        });
      });

  Future<String?> salvaRiservati(
    String userId,
    bool attivo,
    String note, {
    bool? attivoOriginale,
  }) =>
      _esegui(() async {
        if (!puoAmministrare) {
          throw const AppException('Operazione non autorizzata.');
        }

        if (attivoOriginale == null || attivoOriginale != attivo) {
          await _invocaUserAdmin(<String, dynamic>{
            'action': 'set_banned',
            'user_id': userId,
            'banned': !attivo,
          });
        }

        await SupabaseConfig.client.from('anagrafica_riservata').upsert({
          'user_id': userId,
          'attivo': attivo,
          'note_storiche': note.trim().isEmpty ? null : note.trim(),
        });
      });

  Future<String?> cambiaRuolo(String userId, String ruolo) =>
      _esegui(() async {
        if (!soloOwner) {
          throw const AppException('Operazione riservata al proprietario.');
        }
        await SupabaseConfig.client
            .from('user_roles')
            .update({'role': ruolo})
            .eq('user_id', userId);
      });

  Future<String?> cambiaAbilitazione(
    Map<String, dynamic> riga,
    bool abilita,
  ) =>
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

  Future<String?> impostaAbilitazioniInsegnamento(
    String userId,
    String annoAccademico,
    Map<String, bool> valori,
  ) =>
      _esegui(() async {
        if (!puoAmministrare) {
          throw const AppException('Operazione non autorizzata.');
        }

        final normalizzati = <String, bool>{
          for (final ambito in ambitiInsegnamento)
            ambito: valori[ambito] == true,
        };
        if (normalizzati['insegnamento_non_richiesto'] == true) {
          normalizzati['insegnamento_selezione'] = false;
          normalizzati['insegnamento_creazione'] = false;
        }

        for (final entry in normalizzati.entries) {
          await SupabaseConfig.client.rpc(
            'abilitazione_modifica_imposta',
            params: <String, dynamic>{
              'p_user_id': userId,
              'p_ambito': entry.key,
              'p_anno_accademico': annoAccademico,
              'p_abilitata': entry.value,
              'p_scade_at': null,
            },
          );
        }
      });

  Future<String?> impostaPartecipazioneAnnuale(
    String userId,
    String annoAccademico,
    String stato,
  ) =>
      _esegui(() async {
        if (!puoAmministrare) {
          throw const AppException('Operazione non autorizzata.');
        }
        await SupabaseConfig.client.rpc(
          'partecipazione_annuale_imposta',
          params: <String, dynamic>{
            'p_user_id': userId,
            'p_anno_accademico': annoAccademico,
            'p_stato': stato,
            'p_note': null,
          },
        );
      });

  Future<String?> generaRichiestePartecipazione(
    String annoDestinazione, {
    String? annoSorgente,
  }) =>
      _esegui(() async {
        if (!puoAmministrare) {
          throw const AppException('Operazione non autorizzata.');
        }
        await SupabaseConfig.client.rpc(
          'partecipazioni_annuali_genera',
          params: <String, dynamic>{
            'p_anno_destinazione': annoDestinazione,
            'p_anno_sorgente': annoSorgente,
          },
        );
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
          'stato': 'chiuso',
        });
      });

  Future<String?> impostaStatoAnno(String codice, String stato) =>
      _esegui(() async {
        if (!puoAmministrare) {
          throw const AppException('Operazione riservata al backoffice.');
        }
        await SupabaseConfig.client.rpc(
          'imposta_stato_anno_accademico',
          params: <String, dynamic>{'p_codice': codice, 'p_stato': stato},
        );
      });

  Future<String?> impostaAnnoCorrente(String codice) =>
      impostaStatoAnno(codice, 'attivo');


Future<String?> salvaInsegnamentoBackoffice(
  Map<String, dynamic> valori, {
  String? insegnamentoId,
  String? docenteIdForzato,
}) =>
    _esegui(() async {
      if (!puoAmministrare) {
        throw const AppException(
          'Operazione non autorizzata.',
        );
      }

      final dati =
          Map<String, dynamic>.from(valori)
            ..remove('id')
            ..remove('created_at')
            ..remove('updated_at');

      if (docenteIdForzato != null) {
        dati['docente_id'] = docenteIdForzato;
      }

      final docenteId =
          dati['docente_id']?.toString().trim() ?? '';

      final nomeInsegnamento =
          dati['insegnamento']?.toString().trim() ?? '';

      if (docenteId.isEmpty) {
        throw const AppException(
          'Devi selezionare il docente.',
        );
      }

      if (nomeInsegnamento.isEmpty) {
        throw const AppException(
          'Il nome dell’insegnamento è obbligatorio.',
        );
      }

      if (insegnamentoId == null) {
        await SupabaseConfig.client
            .from('insegnamenti')
            .insert(dati);

        return;
      }

      await SupabaseConfig.client
          .from('insegnamenti')
          .update(dati)
          .eq(
            'id',
            insegnamentoId,
          );
    });


Future<String?> eliminaInsegnamentoBackoffice(
  String insegnamentoId,
) =>
    _esegui(() async {
      if (!puoAmministrare) {
        throw const AppException('Operazione non autorizzata.');
      }

      final righe = await SupabaseConfig.client
          .from('mentoraggi')
          .select('id, anno_accademico, stato')
          .eq('insegnamento_id', insegnamentoId);

      final completati = (righe as List)
          .map((riga) => Map<String, dynamic>.from(riga as Map))
          .where(
            (riga) =>
                riga['stato']?.toString().trim().toLowerCase() ==
                'completato',
          )
          .toList(growable: false);

      if (completati.isNotEmpty) {
        final anni = completati
            .map((riga) => riga['anno_accademico']?.toString())
            .whereType<String>()
            .where((anno) => anno.isNotEmpty)
            .toSet()
            .join(', ');

        throw AppException(
          'Impossibile eliminare l’insegnamento: '
          'esistono mentoraggi completati'
          '${anni.isEmpty ? '.' : ' negli anni $anni.'}',
        );
      }

      await SupabaseConfig.client
          .from('insegnamenti')
          .delete()
          .eq('id', insegnamentoId);
    });


Future<String?> creaMentoraggioBackoffice(
  String insegnamentoId,
  String annoAccademico,
) =>
    _esegui(() async {
      if (!puoAmministrare) {
        throw const AppException(
          'Operazione non autorizzata.',
        );
      }

      final anno = annoAccademico.trim();

      if (anno.isEmpty) {
        throw const AppException(
          'Anno accademico obbligatorio.',
        );
      }

      // Verifica direttamente sul database.
      final esistenti =
          await SupabaseConfig.client
              .from('mentoraggi')
              .select('id')
              .eq(
                'insegnamento_id',
                insegnamentoId,
              )
              .eq(
                'anno_accademico',
                anno,
              )
              .limit(1);

      if (esistenti.isNotEmpty) {
        throw AppException(
          'Esiste già un mentoraggio per questo '
          'insegnamento nell’anno accademico $anno.',
        );
      }

      await SupabaseConfig.client
          .from('mentoraggi')
          .insert({
        'insegnamento_id':
            insegnamentoId,
        'anno_accademico':
            anno,
      });
    });

  Future<String?> salvaMentoraggioBackoffice(
    String mentoraggioId,
    Map<String, dynamic> valori,
  ) =>
      _esegui(() async {
        if (!puoAmministrare) {
          throw const AppException('Operazione non autorizzata.');
        }
        final dati = Map<String, dynamic>.from(valori)
          ..remove('id')
          ..remove('created_at')
          ..remove('updated_at');
        await SupabaseConfig.client
            .from('mentoraggi')
            .update(dati)
            .eq('id', mentoraggioId);
      });

  Future<String?> aggiungiAssegnazione(
    String mentoraggioId,
    String mentoreId,
    String tipo,
  ) =>
      _esegui(() async {
        if (!puoAmministrare) {
          throw const AppException('Operazione non autorizzata.');
        }
        final duplicato = assegnazioni.any(
          (riga) =>
              riga['mentoraggio_id']?.toString() == mentoraggioId &&
              riga['mentore_id']?.toString() == mentoreId &&
              riga['tipo']?.toString() == tipo,
        );
        if (duplicato) {
          throw const AppException(
            'Questa persona è già assegnata al mentoraggio con lo stesso ruolo.',
          );
        }
        await SupabaseConfig.client.from('mentoraggio_mentori').insert({
          'mentoraggio_id': mentoraggioId,
          'mentore_id': mentoreId,
          'tipo': tipo,
          'assegnato_il': DateTime.now().toIso8601String().split('T').first,
        });
      });

  Future<String?> eliminaAssegnazione(Map<String, dynamic> riga) =>
      _esegui(() async {
        if (!puoAmministrare) {
          throw const AppException('Operazione non autorizzata.');
        }
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

  Future<String?> importaPartecipanti(
    String annoAccademico,
  ) async {
    try {
      if (!soloOwner) {
        throw const AppException(
          'Operazione riservata al proprietario.',
        );
      }

      final risposta =
          await SupabaseConfig.client.functions.invoke(
        'backoffice-user-admin',
        body: <String, dynamic>{
          'action': 'import_participants',
          'anno_accademico': annoAccademico,
        },
      );

      final data = risposta.data;

      if (risposta.status < 200 ||
          risposta.status >= 300) {
        return 'Edge Function ${risposta.status}: $data';
      }

      return null;
    } catch (e) {
      return 'Importazione non riuscita: $e';
    }
  }

  Future<String?> importaInsegnamenti(
    String annoAccademico,
  ) async {
    try {
      if (!soloOwner) {
        throw const AppException(
          'Operazione riservata al proprietario.',
        );
      }

      final risposta =
          await SupabaseConfig.client.functions.invoke(
        'backoffice-user-admin',
        body: <String, dynamic>{
          'action': 'import_insegnamenti',
          'anno_accademico': annoAccademico,
        },
      );

      final data = risposta.data;

      if (risposta.status < 200 ||
          risposta.status >= 300) {
        return 'Edge Function ${risposta.status}: $data';
      }

      if (data is Map) {
        final risultato =
            Map<String, dynamic>.from(data);

        final totale = risultato['totale'] ?? 0;
        final creati = risultato['creati'] ?? 0;
        final errori = risultato['errori'] ?? 0;

        await carica();

        if (errori != 0) {
          return 'Importazione completata: '
              '$creati di $totale creati, '
              '$errori errori. '
              'Controlla import_insegnamenti.errore.';
        }
      }

      return null;
    } catch (e) {
      return 'Importazione insegnamenti non riuscita: $e';
    }
  }

}

bool _vero(Object? valore) {
  if (valore == true) return true;
  if (valore == false || valore == null) return false;
  final testo = valore.toString().trim().toLowerCase();
  return testo == 'true' || testo == 't' || testo == '1' || testo == 'yes';
}

String? _vuotoNull(String? valore) =>
    valore == null || valore.trim().isEmpty ? null : valore.trim();

