import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_exception.dart';
import '../../sessione_controller.dart';
import '../../notifiche_automatiche_service.dart';
import '../../supabase_config.dart';

class EventiController extends ChangeNotifier {
  EventiController(this.sessione);

  static const String bucketLocandine = 'locandine';
  static const int dimensioneMassimaLocandina = 300 * 1024;

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

  /// evento_id -> questionario_id per i questionari interni di gradimento.
  final Map<String, String> questionarioPerEvento = <String, String>{};

  /// "questionario_id|user_id" -> data invio.
  final Map<String, DateTime> compilazioni = <String, DateTime>{};

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

    final userId =
        partecipanteId ?? SupabaseConfig.client.auth.currentUser?.id;
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
      if (userId == null) {
        throw const AppException('Sessione non valida.');
      }

      final risultati = await Future.wait<dynamic>(<Future<dynamic>>[
        _queryEventi(),
        SupabaseConfig.client
            .from('partecipazioni_eventi')
            .select(
              'evento_id, partecipante_id, data_iscrizione, presente',
            )
            .eq('partecipante_id', userId),
        SupabaseConfig.client
            .from('anni_accademici')
            .select('codice')
            .order('codice', ascending: false),
        SupabaseConfig.client
            .from('questionari')
            .select('id, evento_id')
            .eq('provider', 'interno')
            .eq('aperto', true),
        SupabaseConfig.client
            .from('questionari_compilazioni')
            .select('questionario_id, user_id, inviato_at')
            .eq('user_id', userId),
      ]);

      eventi
        ..clear()
        ..addAll((risultati[0] as List).cast<Map<String, dynamic>>());

      iscrizioni.clear();
      for (final riga
          in (risultati[1] as List).cast<Map<String, dynamic>>()) {
        iscrizioni[riga['evento_id'].toString()] = riga;
      }

      anniAccademici
        ..clear()
        ..addAll(
          (risultati[2] as List)
              .cast<Map<String, dynamic>>()
              .map((riga) => riga['codice'].toString()),
        );

      questionarioPerEvento.clear();
      for (final riga
          in (risultati[3] as List).cast<Map<String, dynamic>>()) {
        final eventoId = riga['evento_id']?.toString();
        final questionarioId = riga['id']?.toString();

        if (eventoId != null &&
            eventoId.isNotEmpty &&
            questionarioId != null &&
            questionarioId.isNotEmpty) {
          questionarioPerEvento[eventoId] = questionarioId;
        }
      }

      compilazioni.clear();
      _aggiungiCompilazioni(
        (risultati[4] as List).cast<Map<String, dynamic>>(),
      );

      iscrittiPerEvento.clear();
      anagraficaPerUserId.clear();

      if (puoGestire) {
        final risultatiGestione =
            await Future.wait<dynamic>(<Future<dynamic>>[
          SupabaseConfig.client
              .from('partecipazioni_eventi')
              .select(
                'evento_id, partecipante_id, data_iscrizione, presente',
              )
              .order('data_iscrizione', ascending: true),
          SupabaseConfig.client
              .from('anagrafica')
              .select('user_id, nome, cognome'),
          SupabaseConfig.client
              .from('questionari_compilazioni')
              .select('questionario_id, user_id, inviato_at'),
        ]);

        for (final riga
            in (risultatiGestione[0] as List).cast<Map<String, dynamic>>()) {
          final eventoId = riga['evento_id']?.toString() ?? '';
          if (eventoId.isEmpty) continue;

          iscrittiPerEvento
              .putIfAbsent(
                eventoId,
                () => <Map<String, dynamic>>[],
              )
              .add(riga);
        }

        for (final persona
            in (risultatiGestione[1] as List).cast<Map<String, dynamic>>()) {
          final id = persona['user_id']?.toString() ?? '';
          if (id.isNotEmpty) {
            anagraficaPerUserId[id] = persona;
          }
        }

        _aggiungiCompilazioni(
          (risultatiGestione[2] as List).cast<Map<String, dynamic>>(),
        );
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

  void _aggiungiCompilazioni(
    List<Map<String, dynamic>> righe,
  ) {
    for (final riga in righe) {
      final questionarioId = riga['questionario_id']?.toString() ?? '';
      final userId = riga['user_id']?.toString() ?? '';

      if (questionarioId.isEmpty || userId.isEmpty) continue;

      final data = DateTime.tryParse(
        riga['inviato_at']?.toString() ?? '',
      );

      compilazioni['$questionarioId|$userId'] =
          data ?? DateTime.now();
    }
  }

  Future<List<Map<String, dynamic>>> _queryEventi() async {
    var query = SupabaseConfig.client.from('eventi').select(
      'id, titolo, anno_accademico, luogo, data_evento, tipologia, '
      'descrizione, modalita, relatori, moderatori, note_organizzative, '
      'locandina_url, data_apertura_iscrizioni, data_chiusura_iscrizioni, '
      'attiva, created_at',
    );

    if (!puoGestire) {
      query = query.eq('attiva', true);
    }

    final righe =
        await query.order('data_evento', ascending: false);

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

  Future<String?> cambiaIscrizione(
    Map<String, dynamic> evento,
  ) async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;

      if (userId == null) {
        throw const AppException('Sessione non valida.');
      }

      final eventoId = evento['id'].toString();

      if (iscritto(eventoId)) {
        await SupabaseConfig.client
            .from('partecipazioni_eventi')
            .delete()
            .eq('evento_id', eventoId)
            .eq('partecipante_id', userId);
      } else {
        await SupabaseConfig.client
            .from('partecipazioni_eventi')
            .insert({
          'evento_id': eventoId,
          'partecipante_id': userId,
        });
      }

      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile aggiornare l’iscrizione.',
      ).messaggio;
    }
  }

  /// Solo owner/organizer possono impostare la presenza.
  ///
  /// Lo stato di compilazione del questionario NON viene modificato:
  /// deriva automaticamente da questionari_compilazioni.
  Future<String?> aggiornaPresenza({
    required String eventoId,
    required String partecipanteId,
    required bool presente,
  }) async {
    try {
      if (!puoGestire) {
        throw const AppException(
          'Operazione non autorizzata.',
        );
      }

      await SupabaseConfig.client
          .from('partecipazioni_eventi')
          .update(<String, dynamic>{
            'presente': presente,
          })
          .eq('evento_id', eventoId)
          .eq('partecipante_id', partecipanteId);

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
        messaggioGenerico:
            'Impossibile aggiornare la presenza.',
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

    try {
      if (!puoGestire) {
        throw const AppException(
          'Operazione non autorizzata.',
        );
      }

      final anno =
          dati['anno_accademico']?.toString().trim() ?? '';

      if (anno.isEmpty) {
        throw const AppException(
          'Devi selezionare l’anno accademico.',
        );
      }

      final titolo =
          dati['titolo']?.toString().trim() ?? '';

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

      String? locandinaPrecedente;
      if (id != null && (locandinaBytes != null || rimuoviLocandina)) {
        final eventoEsistente = await SupabaseConfig.client
            .from('eventi')
            .select('locandina_url')
            .eq('id', id)
            .maybeSingle();

        locandinaPrecedente =
            eventoEsistente?['locandina_url']?.toString();
      }

      String eventoId;

      if (id == null) {
        final creato = await SupabaseConfig.client
            .from('eventi')
            .insert(<String, dynamic>{
              ...dati,
              'attiva': dati['attiva'] ?? true,
            })
            .select('id')
            .single();

        eventoId = creato['id'].toString();
        eventoCreatoId = eventoId;
      } else {
        eventoId = id;

        await SupabaseConfig.client
            .from('eventi')
            .update(dati)
            .eq('id', id);
      }

      if (rimuoviLocandina) {
        await _rimuoviLocandinaStorage(locandinaPrecedente);

        await SupabaseConfig.client
            .from('eventi')
            .update({'locandina_url': null})
            .eq('id', eventoId);
      } else if (locandinaBytes != null && locandinaNomeFile != null) {
        final nuovaUrl = await _caricaLocandina(
          eventoId: eventoId,
          bytes: locandinaBytes,
          nomeFile: locandinaNomeFile,
          urlPrecedente: locandinaPrecedente,
        );

        await SupabaseConfig.client
            .from('eventi')
            .update({'locandina_url': nuovaUrl})
            .eq('id', eventoId);
      }

      if (aggiornaQuestionario) {
        final esistente = await SupabaseConfig.client
            .from('questionari')
            .select('id, template_id')
            .eq('provider', 'interno')
            .eq('evento_id', eventoId)
            .maybeSingle();

        if (esistente == null && templateQuestionarioId != null) {
          await SupabaseConfig.client.from('questionari').insert({
            'template_id': templateQuestionarioId,
            'titolo': 'Gradimento - $titolo',
            'provider': 'interno',
            'evento_id': eventoId,
            'aperto': true,
            'created_by': SupabaseConfig.client.auth.currentUser?.id,
          });
        } else if (esistente != null) {
          final questionarioId = esistente['id'].toString();
          final templateCorrente =
              esistente['template_id']?.toString();

          final compilazioni = await SupabaseConfig.client
              .from('questionari_compilazioni')
              .select('id')
              .eq('questionario_id', questionarioId)
              .limit(1);

          final haCompilazioni = (compilazioni as List).isNotEmpty;

          if (templateQuestionarioId == null) {
            if (haCompilazioni) {
              throw const AppException(
                'Il questionario non può essere rimosso perché esistono già compilazioni.',
              );
            }

            await SupabaseConfig.client
                .from('questionari')
                .delete()
                .eq('id', questionarioId);
          } else if (templateCorrente != templateQuestionarioId) {
            if (haCompilazioni) {
              throw const AppException(
                'Il template non può essere cambiato perché esistono già compilazioni.',
              );
            }

            await SupabaseConfig.client
                .from('questionari')
                .update({
                  'template_id': templateQuestionarioId,
                  'titolo': 'Gradimento - $titolo',
                })
                .eq('id', questionarioId);
          } else {
            await SupabaseConfig.client
                .from('questionari')
                .update({
                  'titolo': 'Gradimento - $titolo',
                })
                .eq('id', questionarioId);
          }
        }
      }

      if (id == null) {
        try {
          await NotificheAutomaticheService.inviaAnnoAccademico(
            annoAccademico: anno,
            titolo: 'Nuovo evento',
            messaggio: 'È stato pubblicato l’evento "$titolo". '
                'Apri la pagina Eventi per consultare i dettagli e iscriverti.',
          );
        } catch (e) {
          debugPrint('Notifica nuovo evento non inviata: $e');
        }
      }

      await carica();
      return null;
    } catch (e) {
      // Se fallisce la creazione del questionario dopo aver creato un nuovo
      // evento, proviamo a rimuovere il nuovo evento per non lasciare dati
      // parziali.
      if (eventoCreatoId != null) {
        try {
          await SupabaseConfig.client
              .from('eventi')
              .delete()
              .eq('id', eventoCreatoId);
        } catch (_) {
          // best effort
        }
      }

      return AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile salvare l’evento.',
      ).messaggio;
    }
  }

  Future<String?> elimina(String id) async {
    try {
      if (!puoGestire) {
        throw const AppException(
          'Operazione non autorizzata.',
        );
      }

      final prima = await SupabaseConfig.client
          .from('eventi')
          .select('id, locandina_url')
          .eq('id', id)
          .maybeSingle();

      if (prima == null) {
        throw const AppException(
          'Evento non trovato.',
        );
      }

      final locandinaUrl =
          prima['locandina_url']?.toString();

      final eliminato = await SupabaseConfig.client
          .from('eventi')
          .delete()
          .eq('id', id)
          .select('id')
          .maybeSingle();

      if (eliminato == null) {
        throw const AppException(
          'L’evento non è stato eliminato. Verifica i permessi RLS di cancellazione sulla tabella eventi.',
        );
      }

      // Il file Storage non è una FK PostgreSQL: lo rimuoviamo separatamente.
      // Se la pulizia Storage fallisce, l'evento resta comunque eliminato.
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
        messaggioGenerico:
            'Impossibile eliminare l’evento.',
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

    final estensione =
        nomeFile.split('.').last.trim().toLowerCase();

    if (!<String>{'jpg', 'jpeg', 'png'}.contains(estensione)) {
      throw const AppException(
        'Formato locandina non valido. Sono ammessi JPG, JPEG e PNG.',
      );
    }

    final mimeType = estensione == 'png'
        ? 'image/png'
        : 'image/jpeg';

    final estensioneNormalizzata =
        estensione == 'jpeg' ? 'jpg' : estensione;

    final path =
        'eventi/$eventoId/locandina.$estensioneNormalizzata';

    final vecchioPath =
        _storagePathDaUrl(urlPrecedente);

    if (vecchioPath != null && vecchioPath != path) {
      try {
        await SupabaseConfig.client.storage
            .from(bucketLocandine)
            .remove([vecchioPath]);
      } catch (_) {
        // Non blocchiamo la sostituzione se il vecchio file non esiste più.
      }
    }

    await SupabaseConfig.client.storage
        .from(bucketLocandine)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: true,
            contentType: mimeType,
          ),
        );

    return SupabaseConfig.client.storage
        .from(bucketLocandine)
        .getPublicUrl(path);
  }

  Future<void> _rimuoviLocandinaStorage(
    String? url,
  ) async {
    final path = _storagePathDaUrl(url);
    if (path == null) return;

    await SupabaseConfig.client.storage
        .from(bucketLocandine)
        .remove([path]);
  }

  String? _storagePathDaUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;

    final marker =
        '/storage/v1/object/public/$bucketLocandine/';
    final indice = url.indexOf(marker);

    if (indice < 0) {
      // URL esterno/legacy (ad es. Google Drive): non è un oggetto
      // del bucket locandine e quindi non va rimosso da Storage.
      return null;
    }

    final path = url.substring(indice + marker.length);
    return Uri.decodeComponent(path);
  }

}
