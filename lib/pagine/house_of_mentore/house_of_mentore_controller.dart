import 'package:flutter/foundation.dart';

import '../../app/app_core.dart';
import '../../app/app_session_controller.dart';
import '../../dati/repository.dart';
import '../../ui/dinamico_schema.dart';

/// Controller della pagina House of Mentore.
///
/// Coordina il processo dati della pagina e indica esplicitamente le tabelle
/// utilizzate. Non esiste un repository specifico House of Mentore.
class HouseOfMentoreController extends ChangeNotifier {
  HouseOfMentoreController(
    this.sessione, {
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  final SessioneController sessione;
  final DatabaseRepository db;

  final List<Map<String, dynamic>> eventi = <Map<String, dynamic>>[];
  final Map<String, List<Map<String, dynamic>>> opzioniPerEvento =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, Map<String, dynamic>> iscrizioni =
      <String, Map<String, dynamic>>{};
  final List<String> anniAccademici = <String>[];

  /// Dati amministrativi, caricati soltanto per owner/organizer.
  final Map<String, List<Map<String, dynamic>>> iscrittiPerEvento =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, Map<String, dynamic>> anagraficaPerUserId =
      <String, Map<String, dynamic>>{};

  bool caricamento = false;
  bool salvataggio = false;
  String? errore;
  String? eventoSelezionatoId;

  bool get puoGestire => sessione.ruolo?.puoAmministrare ?? false;

  Map<String, dynamic>? get eventoSelezionato {
    for (final evento in eventi) {
      if (evento['id']?.toString() == eventoSelezionatoId) return evento;
    }
    return eventi.isEmpty ? null : eventi.first;
  }

  Future<SchemaDatabase> caricaSchemaDatabase() =>
      SchemaDatabase.carica(database: db);

  List<Map<String, dynamic>> opzioni(String eventoId) =>
      opzioniPerEvento[eventoId] ?? const <Map<String, dynamic>>[];

  Map<String, dynamic>? iscrizione(String eventoId) =>
      iscrizioni[eventoId];

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

  String descrizioneOpzione(String eventoId, Object? opzioneId) {
    final id = opzioneId?.toString() ?? '';
    if (id.isEmpty) return '—';

    for (final opzione in opzioni(eventoId)) {
      if (opzione['id']?.toString() == id) {
        return opzione['descrizione']?.toString().trim() ?? '—';
      }
    }

    return id;
  }

  /// Carica iniziative, opzioni, iscrizione corrente e lookup.
  Future<void> carica() async {
    caricamento = true;
    errore = null;
    notifyListeners();

    try {
      final userId = db.userIdCorrente;
      if (userId == null) {
        throw const AppException('Sessione non valida.');
      }

      final risultati = await Future.wait<List<Map<String, dynamic>>>([
        db.tabella('house_of_mentore').elenco(
          filtri: <FiltroDb>[
            if (!puoGestire) const FiltroDb.uguale('attiva', true),
          ],
          ordinamenti: const <OrdineDb>[
            OrdineDb('data_evento', crescente: false),
          ],
        ),
        db.tabella('house_of_mentore_opzioni').elenco(
          ordinamenti: const <OrdineDb>[
            OrdineDb('evento_id'),
            OrdineDb('ordine_visualizzazione'),
          ],
        ),
        db.tabella('partecipazioni_house_of_mentore').elenco(
          filtri: <FiltroDb>[
            FiltroDb.uguale('partecipante_id', userId),
          ],
        ),
        db.tabella('anni_accademici').elenco(
          colonne: 'codice',
          ordinamenti: const <OrdineDb>[
            OrdineDb('codice', crescente: false),
          ],
        ),
      ]);

      eventi
        ..clear()
        ..addAll(risultati[0]);

      opzioniPerEvento.clear();
      for (final opzione in risultati[1]) {
        final eventoId = opzione['evento_id']?.toString() ?? '';
        if (eventoId.isEmpty) continue;

        opzioniPerEvento
            .putIfAbsent(eventoId, () => <Map<String, dynamic>>[])
            .add(opzione);
      }

      iscrizioni.clear();
      for (final partecipazione in risultati[2]) {
        final eventoId = partecipazione['evento_id']?.toString() ?? '';
        if (eventoId.isNotEmpty) {
          iscrizioni[eventoId] = partecipazione;
        }
      }

      anniAccademici
        ..clear()
        ..addAll(
          risultati[3]
              .map((riga) => riga['codice']?.toString() ?? '')
              .where((codice) => codice.isNotEmpty),
        );

      iscrittiPerEvento.clear();
      anagraficaPerUserId.clear();

      if (puoGestire) {
        final gestione = await Future.wait<List<Map<String, dynamic>>>([
          db.tabella('partecipazioni_house_of_mentore').elenco(),
          db.tabella('anagrafica').elenco(
            colonne: 'user_id, nome, cognome',
            ordinamenti: const <OrdineDb>[
              OrdineDb('cognome'),
              OrdineDb('nome'),
            ],
          ),
        ]);

        for (final riga in gestione[0]) {
          final eventoId = riga['evento_id']?.toString() ?? '';
          if (eventoId.isEmpty) continue;

          iscrittiPerEvento
              .putIfAbsent(eventoId, () => <Map<String, dynamic>>[])
              .add(riga);
        }

        for (final persona in gestione[1]) {
          final id = persona['user_id']?.toString() ?? '';
          if (id.isNotEmpty) anagraficaPerUserId[id] = persona;
        }
      }

      if (eventi.isEmpty) {
        eventoSelezionatoId = null;
      } else if (!eventi.any(
        (evento) => evento['id']?.toString() == eventoSelezionatoId,
      )) {
        eventoSelezionatoId = eventi.first['id']?.toString();
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
    eventoSelezionatoId = evento['id']?.toString();
    notifyListeners();
  }

  Future<String?> aggiornaPresenza({
    required String eventoId,
    required String partecipanteId,
    required bool presente,
  }) =>
      _esegui(
        richiedeGestore: true,
        messaggio: 'Impossibile aggiornare la presenza.',
        azione: () => db.tabella('partecipazioni_house_of_mentore').aggiorna(
          <String, dynamic>{'presente': presente},
          filtri: <FiltroDb>[
            FiltroDb.uguale('evento_id', eventoId),
            FiltroDb.uguale('partecipante_id', partecipanteId),
          ],
          colonne: 'evento_id',
        ),
      );

  Future<String?> salvaEvento({
    String? id,
    required Map<String, dynamic> dati,
  }) =>
      _esegui(
        richiedeGestore: true,
        messaggio: 'Impossibile salvare House of Mentore.',
        azione: () async {
          final tabella = db.tabella('house_of_mentore');

          if (id == null) {
            await tabella.inserisci(dati, colonne: 'id');
          } else {
            await tabella.aggiorna(
              dati,
              filtri: <FiltroDb>[
                FiltroDb.uguale('id', id),
              ],
              colonne: 'id',
            );
          }
        },
      );

  Future<String?> eliminaEvento(String id) =>
      _esegui(
        richiedeGestore: true,
        messaggio: 'Impossibile eliminare House of Mentore.',
        azione: () async {
          await db.tabella('house_of_mentore').elimina(
            filtri: <FiltroDb>[
              FiltroDb.uguale('id', id),
            ],
          );
          eventoSelezionatoId = null;
        },
      );

  Future<String?> salvaOpzione({
    String? id,
    required String eventoId,
    required String descrizione,
    required int ordine,
  }) =>
      _esegui(
        richiedeGestore: true,
        messaggio: 'Impossibile salvare l’alternativa.',
        azione: () async {
          final dati = <String, dynamic>{
            'evento_id': eventoId,
            'descrizione': descrizione.trim(),
            'ordine_visualizzazione': ordine,
          };

          final tabella = db.tabella('house_of_mentore_opzioni');

          if (id == null) {
            await tabella.inserisci(dati, colonne: 'id');
          } else {
            await tabella.aggiorna(
              dati,
              filtri: <FiltroDb>[
                FiltroDb.uguale('id', id),
              ],
              colonne: 'id',
            );
          }
        },
      );

  Future<String?> eliminaOpzione(String id) =>
      _esegui(
        richiedeGestore: true,
        messaggio:
            'Impossibile eliminare l’alternativa. '
            'Potrebbe essere già stata scelta.',
        azione: () => db.tabella('house_of_mentore_opzioni').elimina(
          filtri: <FiltroDb>[
            FiltroDb.uguale('id', id),
          ],
        ),
      );

  Future<String?> scegliOpzione({
    required String eventoId,
    required String opzioneId,
  }) =>
      _esegui(
        messaggio: 'Impossibile registrare la scelta.',
        azione: () async {
          final userId = db.userIdCorrente;
          if (userId == null) {
            throw const AppException('Sessione non valida.');
          }

          final tabella = db.tabella('partecipazioni_house_of_mentore');
          final esistente = await tabella.singolo(
            colonne: 'evento_id',
            filtri: <FiltroDb>[
              FiltroDb.uguale('evento_id', eventoId),
              FiltroDb.uguale('partecipante_id', userId),
            ],
          );

          final valori = <String, dynamic>{
            'evento_id': eventoId,
            'partecipante_id': userId,
            'opzione_id': opzioneId,
          };

          if (esistente == null) {
            await tabella.inserisci(valori, colonne: 'evento_id');
          } else {
            await tabella.aggiorna(
              <String, dynamic>{'opzione_id': opzioneId},
              filtri: <FiltroDb>[
                FiltroDb.uguale('evento_id', eventoId),
                FiltroDb.uguale('partecipante_id', userId),
              ],
              colonne: 'evento_id',
            );
          }
        },
      );

  Future<String?> cancellaIscrizione(String eventoId) =>
      _esegui(
        messaggio: 'Impossibile cancellare l’iscrizione.',
        azione: () async {
          final userId = db.userIdCorrente;
          if (userId == null) {
            throw const AppException('Sessione non valida.');
          }

          await db.tabella('partecipazioni_house_of_mentore').elimina(
            filtri: <FiltroDb>[
              FiltroDb.uguale('evento_id', eventoId),
              FiltroDb.uguale('partecipante_id', userId),
            ],
          );
        },
      );

  Future<String?> _esegui({
    required Future<void> Function() azione,
    required String messaggio,
    bool richiedeGestore = false,
  }) async {
    salvataggio = true;
    notifyListeners();

    try {
      if (richiedeGestore && !puoGestire) {
        throw const AppException('Operazione non autorizzata.');
      }

      await azione();
      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: messaggio,
      ).messaggio;
    } finally {
      salvataggio = false;
      notifyListeners();
    }
  }
}
