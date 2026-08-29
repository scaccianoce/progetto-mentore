import 'package:flutter/foundation.dart';

import '../../../app/app_core.dart';
import '../../../app/app_session_controller.dart';
import '../../../dati/repository.dart';
import '../../../ui/dinamico_schema.dart';

/// Controller del backoffice Insegnamenti.
///
/// Coordina insegnamenti, mentoraggi, team, importazione e schede di sintesi.
/// Tutti gli accessi remoti passano da [DatabaseRepository]; non esistono
/// repository specifici per Insegnamenti o Mentoraggi.
class InsegnamentiBackofficeController extends ChangeNotifier {
  InsegnamentiBackofficeController(
    this.sessione, {
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  static const String _funzioneAdmin = 'backoffice-user-admin';
  static const String bucketSchedeSintesi = 'schede-sintesi';

  final SessioneController sessione;
  final DatabaseRepository db;

  final List<Map<String, dynamic>> partecipanti = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> anni = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> insegnamenti = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> mentoraggi = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> assegnazioni = <Map<String, dynamic>>[];

  List<String> tipiMentoreDisponibili = const <String>[];

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

  String? get annoCorrente => annoAttivo;

  /// Carica i dati necessari alla pagina.
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
        db.tabella('anni_accademici').elenco(
          ordinamenti: const <OrdineDb>[
            OrdineDb('codice', crescente: false),
          ],
        ),
        db.tabella('insegnamenti').elenco(),
        db.tabella('mentoraggi').elenco(),
        db.tabella('mentoraggio_mentori').elenco(),
      ]);

      partecipanti
        ..clear()
        ..addAll(risultati[0]);

      anni
        ..clear()
        ..addAll(risultati[1]);

      insegnamenti
        ..clear()
        ..addAll(risultati[2]);

      mentoraggi
        ..clear()
        ..addAll(risultati[3]);

      assegnazioni
        ..clear()
        ..addAll(risultati[4]);

      final schema = await caricaSchemaDatabase();
      tipiMentoreDisponibili = schema
              .tabella('mentoraggio_mentori')
              ?.campo('tipo')
              ?.valoriScelta ??
          const <String>[];
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile caricare insegnamenti e mentoraggi.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  Future<SchemaDatabase> caricaSchemaDatabase() =>
      SchemaDatabase.carica(database: db);

  Map<String, dynamic>? personaPerId(String? userId) {
    if (userId == null) return null;

    for (final persona in partecipanti) {
      if (persona['user_id']?.toString() == userId) {
        return persona;
      }
    }

    return null;
  }

  String etichettaPersona(String? userId) {
    final persona = personaPerId(userId);
    if (persona == null) return userId ?? '—';

    final nome =
        '${persona['cognome'] ?? ''} ${persona['nome'] ?? ''}'.trim();
    final email = persona['email_unipa']?.toString().trim() ?? '';

    if (nome.isEmpty) {
      return email.isEmpty ? userId ?? '—' : email;
    }

    return email.isEmpty ? nome : '$nome — $email';
  }

  /// Inserisce o modifica un insegnamento.
  Future<String?> salvaInsegnamentoBackoffice(
    Map<String, dynamic> valori, {
    String? insegnamentoId,
    String? docenteIdForzato,
  }) =>
      _esegui(
        messaggio: 'Impossibile salvare l’insegnamento.',
        azione: () async {
          _verificaAmministratore();

          final dati = Map<String, dynamic>.from(valori)
            ..remove('id')
            ..remove('created_at')
            ..remove('updated_at');

          if (docenteIdForzato != null) {
            dati['docente_id'] = docenteIdForzato;
          }

          final docenteId =
              dati['docente_id']?.toString().trim() ?? '';
          final nome =
              dati['insegnamento']?.toString().trim() ?? '';

          if (docenteId.isEmpty) {
            throw const AppException(
              'Devi selezionare il docente.',
            );
          }

          if (nome.isEmpty) {
            throw const AppException(
              'Il nome dell’insegnamento è obbligatorio.',
            );
          }

          final tabella = db.tabella('insegnamenti');

          if (insegnamentoId == null) {
            await tabella.inserisci(dati, colonne: 'id');
          } else {
            await tabella.aggiorna(
              dati,
              filtri: <FiltroDb>[
                FiltroDb.uguale('id', insegnamentoId),
              ],
              colonne: 'id',
            );
          }
        },
      );

  /// Elimina un insegnamento se non contiene mentoraggi completati.
  Future<String?> eliminaInsegnamentoBackoffice(
    String insegnamentoId,
  ) =>
      _esegui(
        messaggio: 'Impossibile eliminare l’insegnamento.',
        azione: () async {
          _verificaAmministratore();

          final collegati = await db.tabella('mentoraggi').elenco(
            colonne: 'id, anno_accademico, stato',
            filtri: <FiltroDb>[
              FiltroDb.uguale('insegnamento_id', insegnamentoId),
            ],
          );

          final completati = collegati.where(
            (riga) =>
                riga['stato']?.toString().trim().toLowerCase() ==
                'completato',
          );

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

          await db.tabella('insegnamenti').elimina(
            filtri: <FiltroDb>[
              FiltroDb.uguale('id', insegnamentoId),
            ],
          );
        },
      );

  /// Crea un mentoraggio per un insegnamento e anno.
  Future<String?> creaMentoraggioBackoffice(
    String insegnamentoId,
    String annoAccademico,
  ) =>
      _esegui(
        messaggio: 'Impossibile creare il mentoraggio.',
        azione: () async {
          _verificaAmministratore();

          final anno = annoAccademico.trim();
          if (anno.isEmpty) {
            throw const AppException(
              'Anno accademico obbligatorio.',
            );
          }

          final tabella = db.tabella('mentoraggi');

          final esistente = await tabella.singolo(
            colonne: 'id',
            filtri: <FiltroDb>[
              FiltroDb.uguale('insegnamento_id', insegnamentoId),
              FiltroDb.uguale('anno_accademico', anno),
            ],
          );

          if (esistente != null) {
            throw AppException(
              'Esiste già un mentoraggio per questo insegnamento '
              'nell’anno accademico $anno.',
            );
          }

          await tabella.inserisci(
            <String, dynamic>{
              'insegnamento_id': insegnamentoId,
              'anno_accademico': anno,
            },
            colonne: 'id',
          );
        },
      );

  /// Aggiorna un mentoraggio dal backoffice.
  Future<String?> salvaMentoraggioBackoffice(
    String mentoraggioId,
    Map<String, dynamic> valori,
  ) =>
      _esegui(
        messaggio: 'Impossibile salvare il mentoraggio.',
        azione: () async {
          _verificaAmministratore();

          final dati = Map<String, dynamic>.from(valori)
            ..remove('id')
            ..remove('created_at')
            ..remove('updated_at');

          await db.rpc(
            'mentoraggio_aggiorna_backoffice',
            parametri: <String, dynamic>{
              'p_mentoraggio_id': mentoraggioId,
              'p_valori': dati,
            },
          );
        },
      );

  /// Elimina un mentoraggio non ancora completato.
  Future<String?> eliminaMentoraggioBackoffice(
    String mentoraggioId,
  ) =>
      _esegui(
        messaggio: 'Impossibile eliminare il mentoraggio.',
        azione: () async {
          _verificaAmministratore();

          final riga = await db.tabella('mentoraggi').singolo(
            colonne: 'id, stato, anno_accademico',
            filtri: <FiltroDb>[
              FiltroDb.uguale('id', mentoraggioId),
            ],
          );

          if (riga == null) {
            throw const AppException('Mentoraggio non trovato.');
          }

          final stato =
              riga['stato']?.toString().trim().toLowerCase() ?? '';

          if (stato == 'completato') {
            throw const AppException(
              'Un mentoraggio completato non può essere eliminato.',
            );
          }

          await db.tabella('mentoraggi').elimina(
            filtri: <FiltroDb>[
              FiltroDb.uguale('id', mentoraggioId),
            ],
          );
        },
      );

  /// Assegna una persona al team del mentoraggio.
  Future<String?> aggiungiAssegnazione(
    String mentoraggioId,
    String mentoreId,
    String tipo,
  ) =>
      _esegui(
        messaggio: 'Impossibile aggiungere il membro al team.',
        azione: () async {
          _verificaAmministratore();

          final duplicato = assegnazioni.any(
            (riga) =>
                riga['mentoraggio_id']?.toString() == mentoraggioId &&
                riga['mentore_id']?.toString() == mentoreId &&
                riga['tipo']?.toString() == tipo,
          );

          if (duplicato) {
            throw const AppException(
              'Questa persona è già assegnata al mentoraggio '
              'con lo stesso ruolo.',
            );
          }

          await db.tabella('mentoraggio_mentori').inserisci(
            <String, dynamic>{
              'mentoraggio_id': mentoraggioId,
              'mentore_id': mentoreId,
              'tipo': tipo,
              'assegnato_il':
                  DateTime.now().toIso8601String().split('T').first,
            },
            colonne: 'mentoraggio_id',
          );
        },
      );

  /// Rimuove una persona dal team.
  Future<String?> eliminaAssegnazione(
    Map<String, dynamic> riga,
  ) =>
      _esegui(
        messaggio: 'Impossibile rimuovere il membro dal team.',
        azione: () async {
          _verificaAmministratore();

          await db.tabella('mentoraggio_mentori').elimina(
            filtri: <FiltroDb>[
              FiltroDb.uguale(
                'mentoraggio_id',
                riga['mentoraggio_id'],
              ),
              FiltroDb.uguale(
                'mentore_id',
                riga['mentore_id'],
              ),
              FiltroDb.uguale('tipo', riga['tipo']),
            ],
          );
        },
      );

  /// Importa gli insegnamenti tramite la Edge Function amministrativa.
  Future<String?> importaInsegnamenti(
    String annoAccademico,
  ) async {
    try {
      if (!soloOwner) {
        throw const AppException(
          'Operazione riservata all’owner.',
        );
      }

      final raw = await db.invocaFunzione(
        _funzioneAdmin,
        corpo: <String, dynamic>{
          'action': 'import_insegnamenti',
          'anno_accademico': annoAccademico,
        },
      );

      await carica();

      if (raw is Map) {
        final data = Map<String, dynamic>.from(raw);
        final totale = data['totale'] ?? 0;
        final creati = data['creati'] ?? 0;
        final errori = data['errori'] ?? 0;

        if (errori != 0) {
          return 'Importazione completata: $creati di $totale creati, '
              '$errori errori. Controlla import_insegnamenti.errore.';
        }
      }

      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Importazione insegnamenti non riuscita.',
      ).messaggio;
    }
  }

  /// Carica o sostituisce la scheda di sintesi.
  Future<String> salvaSchedaSintesi({
    required String mentoraggioId,
    required String annoAccademico,
    required String estensione,
    required Uint8List bytes,
    required String contentType,
    String? percorsoPrecedente,
  }) async {
    _verificaAmministratore();

    final path =
        '$annoAccademico/$mentoraggioId/scheda_sintesi.$estensione';

    await db.caricaFileStorage(
      bucket: bucketSchedeSintesi,
      percorso: path,
      bytes: bytes,
      contentType: contentType,
    );

    try {
      await db.rpc(
        'mentoraggio_scheda_sintesi_imposta',
        parametri: <String, dynamic>{
          'p_mentoraggio_id': mentoraggioId,
          'p_storage_path': path,
        },
      );
    } catch (_) {
      try {
        await db.rimuoviFileStorage(
          bucket: bucketSchedeSintesi,
          percorsi: <String>[path],
        );
      } catch (_) {}
      rethrow;
    }

    final precedente = percorsoPrecedente?.trim() ?? '';

    if (precedente.isNotEmpty &&
        precedente != path &&
        !precedente.startsWith('http://') &&
        !precedente.startsWith('https://')) {
      try {
        await db.rimuoviFileStorage(
          bucket: bucketSchedeSintesi,
          percorsi: <String>[precedente],
        );
      } catch (_) {
        // Il nuovo file e' valido; la pulizia del precedente e' best effort.
      }
    }

    return path;
  }

  /// Restituisce l'URL temporaneo della scheda di sintesi.
  Future<String> urlSchedaSintesi(String valore) {
    final percorso = valore.trim();

    if (percorso.startsWith('http://') ||
        percorso.startsWith('https://')) {
      return Future<String>.value(percorso);
    }

    return db.creaUrlFirmato(
      bucket: bucketSchedeSintesi,
      percorso: percorso,
      durata: const Duration(hours: 1),
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
}
