import 'package:flutter/foundation.dart';

import '../../app/app_core.dart';
import '../../app/app_session_controller.dart';
import '../../dati/repository.dart';
import '../../supporto/notifiche_automatiche_service.dart';
import '../../ui/dinamico_schema.dart';

/// Controller della pagina Eventi.
///
/// Coordina caricamento, selezione, iscrizioni, presenze, questionari privati
/// associati agli eventi e gestione della locandina. Tutto l'accesso remoto
/// passa attraverso [DatabaseRepository]; la pagina contiene solo la UI.
class EventiController extends ChangeNotifier {
  EventiController(
    this.sessione, {
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  static const String bucketLocandine = 'locandine';
  static const int dimensioneMassimaLocandina = 300 * 1024;

  final SessioneController sessione;
  final DatabaseRepository db;

  final List<Map<String, dynamic>> eventi = <Map<String, dynamic>>[];
  final List<String> anniAccademici = <String>[];
  final List<Map<String, dynamic>> templateQuestionari =
      <Map<String, dynamic>>[];

  final Map<String, Map<String, dynamic>> iscrizioni =
      <String, Map<String, dynamic>>{};

  final Map<String, List<Map<String, dynamic>>> iscrittiPerEvento =
      <String, List<Map<String, dynamic>>>{};

  final Map<String, Map<String, dynamic>> anagraficaPerUserId =
      <String, Map<String, dynamic>>{};

  final Map<String, String> questionarioPerEvento = <String, String>{};
  final Map<String, Map<String, dynamic>> questionariPrivatiPerEvento =
      <String, Map<String, dynamic>>{};

  final Map<String, DateTime> compilazioni = <String, DateTime>{};

  bool caricamento = false;
  bool salvataggio = false;
  String? errore;
  String? eventoSelezionatoId;

  bool get puoGestire => sessione.ruolo?.puoAmministrare ?? false;
  bool get partecipante => sessione.ruolo == AppRole.participant;

  Map<String, dynamic>? get eventoSelezionato {
    for (final evento in eventi) {
      if (evento['id']?.toString() == eventoSelezionatoId) return evento;
    }
    return eventi.isEmpty ? null : eventi.first;
  }

  /// Carica lo schema DB e lo converte nel modello usato dalla UI dinamica.
  Future<SchemaDatabase> caricaSchemaDatabase() =>
      SchemaDatabase.carica(database: db);

  bool iscritto(String eventoId) => iscrizioni.containsKey(eventoId);

  bool presente(String eventoId) =>
      iscrizioni[eventoId]?['presente'] == true;

  bool haQuestionario(String eventoId) =>
      questionarioPerEvento.containsKey(eventoId);

  bool questionarioCompilato(
    String eventoId, {
    String? partecipanteId,
  }) {
    final questionarioId = questionarioPerEvento[eventoId];
    if (questionarioId == null) return false;

    final userId = partecipanteId ?? db.userIdCorrente;
    if (userId == null) return false;

    return compilazioni.containsKey('$questionarioId|$userId');
  }

  DateTime? dataCompilazione(
    String eventoId,
    String partecipanteId,
  ) {
    final questionarioId = questionarioPerEvento[eventoId];
    if (questionarioId == null) return null;
    return compilazioni['$questionarioId|$partecipanteId'];
  }

  List<Map<String, dynamic>> iscritti(String eventoId) =>
      iscrittiPerEvento[eventoId] ?? const <Map<String, dynamic>>[];

  List<Map<String, dynamic>> templatePer(String destinatario) =>
      templateQuestionari
          .where(
            (riga) =>
                riga['destinatario']?.toString() == destinatario &&
                riga['attivo'] != false,
          )
          .toList(growable: false);

  Map<String, dynamic>? questionarioEvento(String eventoId) =>
      questionariPrivatiPerEvento[eventoId];

  String nomePartecipante(String userId) {
    final persona = anagraficaPerUserId[userId];
    if (persona == null) return userId;

    final cognome = persona['cognome']?.toString().trim() ?? '';
    final nome = persona['nome']?.toString().trim() ?? '';
    final completo = '$cognome $nome'.trim();

    return completo.isEmpty ? userId : completo;
  }

  /// Carica tutti i dati necessari alla pagina.
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
        db.tabella('eventi').elenco(
          colonne:
              'id, titolo, anno_accademico, luogo, data_evento, tipologia, '
              'descrizione, modalita, relatori, moderatori, '
              'note_organizzative, locandina_url, '
              'data_apertura_iscrizioni, data_chiusura_iscrizioni, '
              'attiva, created_at',
          filtri: <FiltroDb>[
            if (!puoGestire) const FiltroDb.uguale('attiva', true),
          ],
          ordinamenti: const <OrdineDb>[
            OrdineDb('data_evento', crescente: false),
          ],
        ),
        db.tabella('partecipazioni_eventi').elenco(
          colonne:
              'evento_id, partecipante_id, data_iscrizione, presente',
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
        db.tabella('questionari').elenco(
          colonne: 'id, evento_id, template_id, titolo, aperto',
          filtri: const <FiltroDb>[
            FiltroDb.uguale('provider', 'interno'),
            FiltroDb.uguale('aperto', true),
          ],
        ),
        db.tabella('questionari_compilazioni').elenco(
          colonne: 'questionario_id, user_id, inviato_at',
          filtri: <FiltroDb>[
            FiltroDb.uguale('user_id', userId),
          ],
        ),
        db.tabella('questionari_template').elenco(
          ordinamenti: const <OrdineDb>[
            OrdineDb('destinatario'),
            OrdineDb('titolo'),
          ],
        ),
      ]);

      eventi
        ..clear()
        ..addAll(risultati[0]);

      iscrizioni.clear();
      for (final riga in risultati[1]) {
        final eventoId = riga['evento_id']?.toString() ?? '';
        if (eventoId.isNotEmpty) iscrizioni[eventoId] = riga;
      }

      anniAccademici
        ..clear()
        ..addAll(
          risultati[2]
              .map((riga) => riga['codice']?.toString() ?? '')
              .where((codice) => codice.isNotEmpty),
        );

      questionarioPerEvento.clear();
      questionariPrivatiPerEvento.clear();
      for (final riga in risultati[3]) {
        final eventoId = riga['evento_id']?.toString() ?? '';
        final questionarioId = riga['id']?.toString() ?? '';

        if (eventoId.isEmpty || questionarioId.isEmpty) continue;

        questionarioPerEvento[eventoId] = questionarioId;
        questionariPrivatiPerEvento[eventoId] = riga;
      }

      compilazioni.clear();
      _aggiungiCompilazioni(risultati[4]);

      templateQuestionari
        ..clear()
        ..addAll(risultati[5]);

      iscrittiPerEvento.clear();
      anagraficaPerUserId.clear();

      if (puoGestire) {
        final gestione = await Future.wait<List<Map<String, dynamic>>>([
          db.tabella('partecipazioni_eventi').elenco(
            colonne:
                'evento_id, partecipante_id, data_iscrizione, presente',
            ordinamenti: const <OrdineDb>[
              OrdineDb('data_iscrizione'),
            ],
          ),
          db.tabella('anagrafica').elenco(
            colonne: 'user_id, nome, cognome',
          ),
          db.tabella('questionari_compilazioni').elenco(
            colonne: 'questionario_id, user_id, inviato_at',
          ),
        ]);

        for (final riga in gestione[0]) {
          final eventoId = riga['evento_id']?.toString() ?? '';
          if (eventoId.isEmpty) continue;

          iscrittiPerEvento
              .putIfAbsent(
                eventoId,
                () => <Map<String, dynamic>>[],
              )
              .add(riga);
        }

        for (final persona in gestione[1]) {
          final id = persona['user_id']?.toString() ?? '';
          if (id.isNotEmpty) anagraficaPerUserId[id] = persona;
        }

        _aggiungiCompilazioni(gestione[2]);
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
        messaggioGenerico: 'Impossibile caricare gli eventi.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  void _aggiungiCompilazioni(List<Map<String, dynamic>> righe) {
    for (final riga in righe) {
      final questionarioId = riga['questionario_id']?.toString() ?? '';
      final userId = riga['user_id']?.toString() ?? '';

      if (questionarioId.isEmpty || userId.isEmpty) continue;

      final data = DateTime.tryParse(
        riga['inviato_at']?.toString() ?? '',
      );

      compilazioni['$questionarioId|$userId'] = data ?? DateTime.now();
    }
  }

  void seleziona(Map<String, dynamic> evento) {
    eventoSelezionatoId = evento['id']?.toString();
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
      final userId = db.userIdCorrente;
      if (userId == null) {
        throw const AppException('Sessione non valida.');
      }

      final eventoId = evento['id']?.toString() ?? '';
      if (eventoId.isEmpty) {
        throw const AppException('Evento non valido.');
      }

      final partecipazioni = db.tabella('partecipazioni_eventi');

      if (iscritto(eventoId)) {
        await partecipazioni.elimina(
          filtri: <FiltroDb>[
            FiltroDb.uguale('evento_id', eventoId),
            FiltroDb.uguale('partecipante_id', userId),
          ],
        );
      } else {
        await partecipazioni.inserisci(
          <String, dynamic>{
            'evento_id': eventoId,
            'partecipante_id': userId,
          },
          colonne: 'evento_id',
        );
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

  Future<String?> aggiornaPresenza({
    required String eventoId,
    required String partecipanteId,
    required bool presente,
  }) async {
    try {
      if (!puoGestire) {
        throw const AppException('Operazione non autorizzata.');
      }

      await db.tabella('partecipazioni_eventi').aggiorna(
        <String, dynamic>{'presente': presente},
        filtri: <FiltroDb>[
          FiltroDb.uguale('evento_id', eventoId),
          FiltroDb.uguale('partecipante_id', partecipanteId),
        ],
        colonne: 'evento_id',
      );

      if (presente && haQuestionario(eventoId)) {
        final evento = eventi.cast<Map<String, dynamic>?>().firstWhere(
              (riga) => riga?['id']?.toString() == eventoId,
              orElse: () => null,
            );
        final titoloEvento =
            evento?['titolo']?.toString().trim() ?? 'evento';

        try {
          await NotificheAutomaticheService.inviaUtenti(
            userIds: <String>[partecipanteId],
            titolo: 'Questionario di gradimento disponibile',
            messaggio:
                'La tua presenza a "$titoloEvento" è stata confermata. '
                'Puoi ora compilare il questionario di gradimento.',
          );
        } catch (e) {
          debugPrint('Notifica questionario evento non inviata: $e');
        }
      }

      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile aggiornare la presenza.',
      ).messaggio;
    }
  }

  /// Carica questionario e domande per il dialog di compilazione.
  Future<Map<String, dynamic>?> caricaQuestionarioEvento(
    String eventoId,
  ) async {
    final questionario = await db.tabella('questionari').singolo(
      filtri: <FiltroDb>[
        const FiltroDb.uguale('provider', 'interno'),
        FiltroDb.uguale('evento_id', eventoId),
        const FiltroDb.uguale('aperto', true),
      ],
    );

    if (questionario == null) return null;

    final templateId = questionario['template_id']?.toString() ?? '';
    if (templateId.isEmpty) {
      throw const AppException(
        'Template del questionario non disponibile.',
      );
    }

    final domande = await db.tabella('questionari_domande').elenco(
      filtri: <FiltroDb>[
        FiltroDb.uguale('template_id', templateId),
      ],
      ordinamenti: const <OrdineDb>[
        OrdineDb('ordine'),
      ],
    );

    return <String, dynamic>{
      'questionario': questionario,
      'domande': domande,
    };
  }

  /// Registra la compilazione del questionario privato dell'evento.
  Future<String?> inviaQuestionario({
    required String questionarioId,
    required Map<String, dynamic> risposte,
  }) async {
    try {
      final userId = db.userIdCorrente;
      if (userId == null) {
        throw const AppException('Sessione non valida.');
      }

      final esistente =
          await db.tabella('questionari_compilazioni').singolo(
        colonne: 'id',
        filtri: <FiltroDb>[
          FiltroDb.uguale('questionario_id', questionarioId),
          FiltroDb.uguale('user_id', userId),
        ],
      );

      if (esistente != null) {
        throw const AppException(
          'Hai già compilato questo questionario.',
        );
      }

      final compilazione =
          await db.tabella('questionari_compilazioni').inserisci(
        <String, dynamic>{
          'questionario_id': questionarioId,
          'user_id': userId,
        },
        colonne: 'id',
      );

      final compilazioneId = compilazione['id']?.toString() ?? '';
      if (compilazioneId.isEmpty) {
        throw const AppException(
          'Identificativo della compilazione non disponibile.',
        );
      }

      try {
        await db.tabella('questionari_risposte').inserisciMolti(
          <Map<String, dynamic>>[
            for (final risposta in risposte.entries)
              <String, dynamic>{
                'compilazione_id': compilazioneId,
                'domanda_id': risposta.key,
                'valore': risposta.value,
              },
          ],
          colonne: 'id',
        );
      } catch (_) {
        await db.tabella('questionari_compilazioni').elimina(
          filtri: <FiltroDb>[
            FiltroDb.uguale('id', compilazioneId),
          ],
        );
        rethrow;
      }

      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile inviare il questionario.',
      ).messaggio;
    }
  }

  Future<String?> salva({
    String? id,
    required Map<String, dynamic> dati,
    bool aggiornaQuestionario = false,
    String? templateQuestionarioId,
    Uint8List? locandinaBytes,
    String? locandinaNomeFile,
    bool rimuoviLocandina = false,
  }) async {
    String? eventoCreatoId;

    salvataggio = true;
    notifyListeners();

    try {
      if (!puoGestire) {
        throw const AppException('Operazione non autorizzata.');
      }

      final anno = dati['anno_accademico']?.toString().trim() ?? '';
      if (anno.isEmpty) {
        throw const AppException(
          'Devi selezionare l’anno accademico.',
        );
      }

      final titolo = dati['titolo']?.toString().trim() ?? '';
      if (titolo.isEmpty) {
        throw const AppException(
          'Il titolo dell’evento è obbligatorio.',
        );
      }

      if (locandinaBytes != null &&
          locandinaBytes.lengthInBytes > dimensioneMassimaLocandina) {
        throw const AppException(
          'La locandina supera il limite massimo di 300 KB.',
        );
      }

      final tabellaEventi = db.tabella('eventi');

      String? locandinaPrecedente;
      if (id != null && (locandinaBytes != null || rimuoviLocandina)) {
        final eventoEsistente = await tabellaEventi.singolo(
          colonne: 'locandina_url',
          filtri: <FiltroDb>[
            FiltroDb.uguale('id', id),
          ],
        );
        locandinaPrecedente =
            eventoEsistente?['locandina_url']?.toString();
      }

      late final String eventoId;

      if (id == null) {
        final creato = await tabellaEventi.inserisci(
          <String, dynamic>{
            ...dati,
            'attiva': dati['attiva'] ?? true,
          },
          colonne: 'id',
        );
        eventoId = creato['id']?.toString() ?? '';
        if (eventoId.isEmpty) {
          throw const AppException(
            'Identificativo dell’evento non disponibile.',
          );
        }
        eventoCreatoId = eventoId;
      } else {
        eventoId = id;
        await tabellaEventi.aggiorna(
          dati,
          filtri: <FiltroDb>[
            FiltroDb.uguale('id', id),
          ],
          colonne: 'id',
        );
      }

      if (rimuoviLocandina) {
        await _rimuoviLocandinaStorage(locandinaPrecedente);
        await tabellaEventi.aggiorna(
          <String, dynamic>{'locandina_url': null},
          filtri: <FiltroDb>[
            FiltroDb.uguale('id', eventoId),
          ],
          colonne: 'id',
        );
      } else if (locandinaBytes != null && locandinaNomeFile != null) {
        final nuovaUrl = await _caricaLocandina(
          eventoId: eventoId,
          bytes: locandinaBytes,
          nomeFile: locandinaNomeFile,
          urlPrecedente: locandinaPrecedente,
        );

        await tabellaEventi.aggiorna(
          <String, dynamic>{'locandina_url': nuovaUrl},
          filtri: <FiltroDb>[
            FiltroDb.uguale('id', eventoId),
          ],
          colonne: 'id',
        );
      }

      if (aggiornaQuestionario) {
        await _aggiornaQuestionarioEvento(
          eventoId: eventoId,
          titoloEvento: titolo,
          templateQuestionarioId: templateQuestionarioId,
        );
      }

      if (id == null) {
        try {
          await NotificheAutomaticheService.inviaAnnoAccademico(
            annoAccademico: anno,
            titolo: 'Nuovo evento',
            messaggio:
                'È stato pubblicato l’evento "$titolo". '
                'Apri la pagina Eventi per consultare i dettagli e iscriverti.',
          );
        } catch (e) {
          debugPrint('Notifica nuovo evento non inviata: $e');
        }
      }

      await carica();
      return null;
    } catch (e) {
      if (eventoCreatoId != null) {
        try {
          await db.tabella('eventi').elimina(
            filtri: <FiltroDb>[
              FiltroDb.uguale('id', eventoCreatoId),
            ],
          );
        } catch (_) {
          // Pulizia best effort.
        }
      }

      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile salvare l’evento.',
      ).messaggio;
    } finally {
      salvataggio = false;
      notifyListeners();
    }
  }

  Future<void> _aggiornaQuestionarioEvento({
    required String eventoId,
    required String titoloEvento,
    required String? templateQuestionarioId,
  }) async {
    final questionari = db.tabella('questionari');

    final esistente = await questionari.singolo(
      colonne: 'id, template_id',
      filtri: <FiltroDb>[
        const FiltroDb.uguale('provider', 'interno'),
        FiltroDb.uguale('evento_id', eventoId),
      ],
    );

    if (esistente == null) {
      if (templateQuestionarioId == null) return;

      await questionari.inserisci(
        <String, dynamic>{
          'template_id': templateQuestionarioId,
          'titolo': 'Gradimento - $titoloEvento',
          'provider': 'interno',
          'evento_id': eventoId,
          'aperto': true,
          'created_by': db.userIdCorrente,
        },
        colonne: 'id',
      );
      return;
    }

    final questionarioId = esistente['id']?.toString() ?? '';
    if (questionarioId.isEmpty) return;

    final compilazioni =
        await db.tabella('questionari_compilazioni').elenco(
      colonne: 'id',
      filtri: <FiltroDb>[
        FiltroDb.uguale('questionario_id', questionarioId),
      ],
      limite: 1,
    );
    final haCompilazioni = compilazioni.isNotEmpty;

    if (templateQuestionarioId == null) {
      if (haCompilazioni) {
        throw const AppException(
          'Il questionario non può essere rimosso perché esistono già compilazioni.',
        );
      }

      await questionari.elimina(
        filtri: <FiltroDb>[
          FiltroDb.uguale('id', questionarioId),
        ],
      );
      return;
    }

    final templateCorrente = esistente['template_id']?.toString();
    if (templateCorrente != templateQuestionarioId && haCompilazioni) {
      throw const AppException(
        'Il template non può essere cambiato perché esistono già compilazioni.',
      );
    }

    await questionari.aggiorna(
      <String, dynamic>{
        'template_id': templateQuestionarioId,
        'titolo': 'Gradimento - $titoloEvento',
      },
      filtri: <FiltroDb>[
        FiltroDb.uguale('id', questionarioId),
      ],
      colonne: 'id',
    );
  }

  Future<String?> elimina(String id) async {
    try {
      if (!puoGestire) {
        throw const AppException('Operazione non autorizzata.');
      }

      final tabellaEventi = db.tabella('eventi');
      final prima = await tabellaEventi.singolo(
        colonne: 'id, locandina_url',
        filtri: <FiltroDb>[
          FiltroDb.uguale('id', id),
        ],
      );

      if (prima == null) {
        throw const AppException('Evento non trovato.');
      }

      final locandinaUrl = prima['locandina_url']?.toString();

      await tabellaEventi.elimina(
        filtri: <FiltroDb>[
          FiltroDb.uguale('id', id),
        ],
      );

      try {
        await _rimuoviLocandinaStorage(locandinaUrl);
      } catch (e) {
        debugPrint('Pulizia locandina Storage non riuscita: $e');
      }

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

  Future<String> _caricaLocandina({
    required String eventoId,
    required Uint8List bytes,
    required String nomeFile,
    String? urlPrecedente,
  }) async {
    if (bytes.lengthInBytes > dimensioneMassimaLocandina) {
      throw const AppException(
        'La locandina supera il limite massimo di 300 KB.',
      );
    }

    final parti = nomeFile.split('.');
    final estensione =
        parti.length > 1 ? parti.last.trim().toLowerCase() : '';

    if (!<String>{'jpg', 'jpeg', 'png'}.contains(estensione)) {
      throw const AppException(
        'Formato locandina non valido. Sono ammessi JPG, JPEG e PNG.',
      );
    }

    final mimeType = estensione == 'png' ? 'image/png' : 'image/jpeg';
    final estensioneNormalizzata =
        estensione == 'jpeg' ? 'jpg' : estensione;
    final percorso =
        'eventi/$eventoId/locandina.$estensioneNormalizzata';

    final vecchioPath = _storagePathDaUrl(urlPrecedente);
    if (vecchioPath != null && vecchioPath != percorso) {
      try {
        await db.rimuoviFileStorage(
          bucket: bucketLocandine,
          percorsi: <String>[vecchioPath],
        );
      } catch (_) {
        // Non blocca la sostituzione se il file precedente non esiste.
      }
    }

    return db.caricaFilePubblico(
      bucket: bucketLocandine,
      percorso: percorso,
      bytes: bytes,
      contentType: mimeType,
    );
  }

  Future<void> _rimuoviLocandinaStorage(String? url) async {
    final percorso = _storagePathDaUrl(url);
    if (percorso == null) return;

    await db.rimuoviFileStorage(
      bucket: bucketLocandine,
      percorsi: <String>[percorso],
    );
  }

  String? _storagePathDaUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;

    final marker = '/storage/v1/object/public/$bucketLocandine/';
    final indice = url.indexOf(marker);

    if (indice < 0) return null;

    final percorso = url.substring(indice + marker.length);
    return Uri.decodeComponent(percorso);
  }
}
