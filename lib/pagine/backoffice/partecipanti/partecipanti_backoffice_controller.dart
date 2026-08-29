import 'package:flutter/foundation.dart';

import '../../../app/app_core.dart';
import '../../../app/app_session_controller.dart';
import '../../../dati/repository.dart';
import '../../../ui/dinamico_schema.dart';

/// Controller del backoffice Partecipanti.
///
/// Sostituisce la parte del vecchio `BackofficeRepository` necessaria a questa
/// sola pagina. Il controller mantiene il proprio stato e indica esplicitamente
/// le tabelle/RPC utilizzate.
class PartecipantiBackofficeController extends ChangeNotifier {
  PartecipantiBackofficeController(
    this.sessione, {
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  static const String _funzioneAdmin = 'backoffice-user-admin';

  static const List<String> _ambitiInsegnamento = <String>[
    'insegnamento_selezione',
    'insegnamento_creazione',
    'insegnamento_modifica',
    'insegnamento_non_richiesto',
  ];

  final SessioneController sessione;
  final DatabaseRepository db;

  final List<Map<String, dynamic>> partecipanti = <Map<String, dynamic>>[];
  final Map<String, Map<String, dynamic>> riservati =
      <String, Map<String, dynamic>>{};
  final Map<String, String> ruoli = <String, String>{};
  final List<Map<String, dynamic>> abilitazioni =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> partecipazioniAnnuali =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> anni = <Map<String, dynamic>>[];

  List<String> ruoliDisponibili = const <String>[];

  bool caricamento = false;
  bool salvataggio = false;
  String? errore;

  bool get soloOwner => sessione.ruolo == AppRole.owner;
  bool get puoAmministrare => sessione.ruolo?.puoAmministrare ?? false;

  String? get annoAttivo {
    for (final anno in anni) {
      if (anno['stato']?.toString() == 'attivo' ||
          anno['corrente'] == true) {
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

  String? get annoGestioneInsegnamenti =>
      annoPreparazione ?? annoAttivo;

  /// Carica i dati necessari esclusivamente al backoffice Partecipanti.
  Future<void> carica() async {
    caricamento = true;
    errore = null;
    notifyListeners();

    try {
      final risultati = await Future.wait<List<Map<String, dynamic>>>([
        db.tabella('anagrafica').elenco(
          ordinamenti: const <OrdineDb>[
            OrdineDb('cognome'),
            OrdineDb('nome'),
          ],
        ),
        db.tabella('anagrafica_riservata').elenco(),
        db.tabella('abilitazioni_modifica').elenco(
          ordinamenti: const <OrdineDb>[
            OrdineDb('richiesta_at', crescente: false),
          ],
        ),
        db.tabella('partecipazioni_annuali').elenco(),
        db.tabella('anni_accademici').elenco(
          ordinamenti: const <OrdineDb>[
            OrdineDb('codice', crescente: false),
          ],
        ),
        db.tabella('user_roles').elenco(
          colonne: 'user_id, role',
        ),
      ]);

      partecipanti
        ..clear()
        ..addAll(risultati[0]);

      riservati.clear();
      for (final riga in risultati[1]) {
        final id = riga['user_id']?.toString() ?? '';
        if (id.isNotEmpty) riservati[id] = riga;
      }

      abilitazioni
        ..clear()
        ..addAll(risultati[2]);

      partecipazioniAnnuali
        ..clear()
        ..addAll(risultati[3]);

      anni
        ..clear()
        ..addAll(risultati[4]);

      ruoli.clear();
      for (final riga in risultati[5]) {
        final id = riga['user_id']?.toString() ?? '';
        final ruolo = riga['role']?.toString() ?? '';
        if (id.isNotEmpty && ruolo.isNotEmpty) ruoli[id] = ruolo;
      }

      final schema = await SchemaDatabase.carica(database: db);
      ruoliDisponibili = schema
              .tabella('user_roles')
              ?.campo('role')
              ?.valoriScelta ??
          const <String>[];
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile caricare i partecipanti del backoffice.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  /// Restituisce la partecipazione annuale di un utente per l'anno indicato.
  Map<String, dynamic>? partecipazioneAnnuale(
    String userId,
    String? anno,
  ) {
    if (anno == null || anno.isEmpty) return null;

    for (final riga in partecipazioniAnnuali) {
      if (riga['user_id']?.toString() == userId &&
          riga['anno_accademico']?.toString() == anno) {
        return riga;
      }
    }
    return null;
  }

  String? statoPartecipazione(
    String userId, [
    String? anno,
  ]) =>
      partecipazioneAnnuale(
        userId,
        anno ?? annoPreparazione ?? annoAttivo,
      )?['stato']
          ?.toString();

  /// Verifica una specifica abilitazione temporanea.
  bool abilitazioneAttiva(
    String userId,
    String ambito,
    String? anno,
  ) {
    if (anno == null || anno.isEmpty) return false;

    for (final riga in abilitazioni) {
      if (riga['user_id']?.toString() != userId ||
          riga['ambito']?.toString() != ambito ||
          riga['anno_accademico']?.toString() != anno) {
        continue;
      }

      if (riga['abilitata'] != true || riga['revocata_at'] != null) {
        return false;
      }

      final scadenza =
          DateTime.tryParse(riga['scade_at']?.toString() ?? '');
      if (scadenza != null && !scadenza.isAfter(DateTime.now())) {
        return false;
      }

      return true;
    }

    return false;
  }

  bool gestioneInsegnamentiAttiva(String userId) {
    final anno = annoGestioneInsegnamenti;
    if (anno == null) return false;

    return abilitazioneAttiva(
          userId,
          'insegnamento_creazione',
          anno,
        ) &&
        abilitazioneAttiva(
          userId,
          'insegnamento_modifica',
          anno,
        );
  }

  /// Salva l'anagrafica. La sincronizzazione email con Auth passa dalla
  /// Edge Function amministrativa.
  Future<String?> salvaAnagrafica(
    String userId,
    Map<String, dynamic> valori, {
    Map<String, dynamic>? originali,
  }) =>
      _esegui(
        messaggio: 'Impossibile aggiornare l’anagrafica.',
        azione: () async {
          _verificaAmministratore();

          final schema = await SchemaDatabase.carica(database: db);
          final tabellaSchema = schema.tabella('anagrafica');
          final patch = <String, dynamic>{};

          for (final voce in valori.entries) {
            if (voce.key == 'user_id') continue;
            if (originali != null && originali[voce.key] == voce.value) {
              continue;
            }

            final campo = tabellaSchema?.campo(voce.key);
            if (campo != null &&
                (campo.chiavePrimaria ||
                    campo.identita ||
                    campo.generato ||
                    campo.solaLettura)) {
              continue;
            }

            patch[voce.key] = voce.value;
          }

          if (patch.isEmpty) return;

          final emailNuova = patch['email_unipa']?.toString().trim();
          final emailVecchia =
              originali?['email_unipa']?.toString().trim();

          if (emailNuova != null &&
              emailNuova.isNotEmpty &&
              emailNuova != emailVecchia) {
            await db.invocaFunzione(
              _funzioneAdmin,
              corpo: <String, dynamic>{
                'action': 'update_email',
                'user_id': userId,
                'email': emailNuova,
              },
            );

            // La Edge Function sincronizza gia' `email_unipa`.
            patch.remove('email_unipa');
          }

          if (patch.isNotEmpty) {
            await db.tabella('anagrafica').aggiorna(
              patch,
              filtri: <FiltroDb>[
                FiltroDb.uguale('user_id', userId),
              ],
              colonne: 'user_id',
            );
          }
        },
      );

  /// Crea Authentication + anagrafica + riservata + ruolo participant.
  Future<String?> creaPartecipante(
    Map<String, dynamic> valori,
    String password,
  ) =>
      _esegui(
        messaggio: 'Impossibile creare il partecipante.',
        azione: () async {
          _verificaAmministratore();

          final email = valori['email_unipa']?.toString().trim() ?? '';
          if (email.isEmpty) {
            throw const AppException('Email obbligatoria.');
          }
          if (password.length < 8) {
            throw const AppException(
              'La password temporanea deve avere almeno 8 caratteri.',
            );
          }

          await db.invocaFunzione(
            _funzioneAdmin,
            corpo: <String, dynamic>{
              'action': 'create_participant',
              'email': email,
              'password': password,
              'anagrafica': valori,
              'anagrafica_riservata': <String, dynamic>{
                'attivo': true,
              },
            },
          );
        },
      );

  /// Aggiorna dati riservati e stato attivo.
  Future<String?> salvaRiservati(
    String userId,
    Map<String, dynamic> valori,
  ) =>
      _esegui(
        messaggio: 'Impossibile aggiornare i dati riservati.',
        azione: () async {
          _verificaAmministratore();

          final attivo = valori['attivo'] == true;
          final precedente = riservati[userId]?['attivo'] == true;

          if (attivo != precedente) {
            await db.invocaFunzione(
              _funzioneAdmin,
              corpo: <String, dynamic>{
                'action': 'set_active',
                'user_id': userId,
                'active': attivo,
              },
            );
          }

          await db.tabella('anagrafica_riservata').upsert(
            <String, dynamic>{
              'user_id': userId,
              'attivo': attivo,
              'note_storiche': valori['note_storiche'],
            },
            onConflict: 'user_id',
            colonne: 'user_id',
          );
        },
      );

  Future<String?> cambiaRuolo(
    String userId,
    String ruolo,
  ) =>
      _esegui(
        messaggio: 'Impossibile modificare il ruolo.',
        azione: () async {
          _verificaOwner();

          await db.tabella('user_roles').aggiorna(
            <String, dynamic>{'role': ruolo},
            filtri: <FiltroDb>[
              FiltroDb.uguale('user_id', userId),
            ],
            colonne: 'user_id',
          );
        },
      );

  Future<String?> reimpostaPassword(
    String userId,
    String nuovaPassword,
  ) =>
      _esegui(
        messaggio: 'Impossibile reimpostare la password.',
        azione: () async {
          _verificaAmministratore();

          if (nuovaPassword.length < 8) {
            throw const AppException(
              'La nuova password deve avere almeno 8 caratteri.',
            );
          }

          await db.invocaFunzione(
            _funzioneAdmin,
            corpo: <String, dynamic>{
              'action': 'reset_password',
              'user_id': userId,
              'password': nuovaPassword,
            },
          );
        },
      );

  Future<String?> eliminaPartecipante(String userId) =>
      _esegui(
        messaggio: 'Impossibile eliminare il partecipante.',
        azione: () async {
          _verificaOwner();

          await db.invocaFunzione(
            _funzioneAdmin,
            corpo: <String, dynamic>{
              'action': 'delete_participant',
              'user_id': userId,
            },
          );
        },
      );

  /// Importa i partecipanti tramite il workflow server-side gia' esistente.
  Future<String?> importaPartecipanti(String annoAccademico) =>
      _esegui(
        messaggio: 'Importazione dei partecipanti non riuscita.',
        azione: () async {
          _verificaOwner();

          await db.invocaFunzione(
            _funzioneAdmin,
            corpo: <String, dynamic>{
              'action': 'import_participants',
              'anno_accademico': annoAccademico,
            },
          );
        },
      );

  Future<String?> impostaPartecipazioneAnnuale({
    required String userId,
    required String annoAccademico,
    required String stato,
  }) =>
      _esegui(
        messaggio:
            'Impossibile aggiornare la partecipazione annuale.',
        azione: () async {
          _verificaAmministratore();

          await db.rpc(
            'partecipazione_annuale_imposta',
            parametri: <String, dynamic>{
              'p_user_id': userId,
              'p_anno_accademico': annoAccademico,
              'p_stato': stato,
              'p_note': null,
            },
          );
        },
      );

  Future<String?> impostaGestioneInsegnamentiCorrente(
    String userId,
    bool abilitata,
  ) async {
    final anno = annoGestioneInsegnamenti;
    if (anno == null) {
      return 'Nessun anno accademico disponibile.';
    }

    if (abilitata && anno == annoPreparazione) {
      final stato = statoPartecipazione(userId, anno);
      if (stato != 'confermato' && stato != 'nuovo') {
        return 'Per abilitare gli insegnamenti il partecipante deve essere '
            'confermato o nuovo per $anno.';
      }
    }

    return _esegui(
      messaggio:
          'Impossibile aggiornare la gestione degli insegnamenti.',
      azione: () async {
        _verificaAmministratore();

        if (abilitata) {
          await _impostaAbilitazione(
            userId: userId,
            anno: anno,
            ambito: 'insegnamento_non_richiesto',
            abilitata: false,
          );
        }

        for (final ambito in const <String>[
          'insegnamento_selezione',
          'insegnamento_creazione',
          'insegnamento_modifica',
        ]) {
          await _impostaAbilitazione(
            userId: userId,
            anno: anno,
            ambito: ambito,
            abilitata: abilitata,
          );
        }
      },
    );
  }

  Future<String?> impostaAbilitazioniInsegnamento(
    String userId,
    Map<String, bool> valori,
  ) async {
    final anno = annoGestioneInsegnamenti;
    if (anno == null) {
      return 'Nessun anno accademico disponibile.';
    }

    final normalizzati = <String, bool>{
      for (final ambito in _ambitiInsegnamento)
        ambito: valori[ambito] == true,
    };

    if (normalizzati['insegnamento_non_richiesto'] == true) {
      normalizzati['insegnamento_selezione'] = false;
      normalizzati['insegnamento_creazione'] = false;
      normalizzati['insegnamento_modifica'] = false;
    }

    return _esegui(
      messaggio:
          'Impossibile aggiornare le abilitazioni insegnamento.',
      azione: () async {
        _verificaAmministratore();

        for (final voce in normalizzati.entries) {
          await _impostaAbilitazione(
            userId: userId,
            anno: anno,
            ambito: voce.key,
            abilitata: voce.value,
          );
        }
      },
    );
  }

  Future<void> _impostaAbilitazione({
    required String userId,
    required String anno,
    required String ambito,
    required bool abilitata,
  }) {
    return db.rpc(
      'abilitazione_modifica_imposta',
      parametri: <String, dynamic>{
        'p_user_id': userId,
        'p_ambito': ambito,
        'p_anno_accademico': anno,
        'p_abilitata': abilitata,
        'p_scade_at': null,
      },
    );
  }

  Future<String?> _esegui({
    required Future<void> Function() azione,
    required String messaggio,
  }) async {
    salvataggio = true;
    errore = null;
    notifyListeners();

    try {
      await azione();
      await carica();
      return null;
    } catch (e) {
      final convertito = AppErrorMapper.converti(
        e,
        messaggioGenerico: messaggio,
      );
      errore = convertito.messaggio;
      return convertito.messaggio;
    } finally {
      salvataggio = false;
      notifyListeners();
    }
  }

  void _verificaAmministratore() {
    if (!puoAmministrare) {
      throw const AppException('Operazione non autorizzata.');
    }
  }

  void _verificaOwner() {
    if (!soloOwner) {
      throw const AppException(
        'Questa operazione è riservata all’owner.',
      );
    }
  }
}
