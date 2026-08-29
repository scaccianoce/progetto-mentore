import 'package:flutter/foundation.dart';

import '../../../app/app_core.dart';
import '../../../dati/repository.dart';
import '../../../ui/dinamico_schema.dart';

/// Raggruppa i dati necessari alla visualizzazione di un percorso da mentore.
class PercorsoMentore {
  const PercorsoMentore({
    required this.mentoraggio,
    required this.insegnamento,
    required this.docente,
    required this.team,
    required this.annoCorrente,
    required this.mioRuolo,
  });

  final Map<String, dynamic> mentoraggio;
  final Map<String, dynamic> insegnamento;
  final Map<String, dynamic> docente;
  final List<Map<String, dynamic>> team;
  final bool annoCorrente;
  final String mioRuolo;
}

/// Controller della pagina Ruolo Mentore.
///
/// Coordina direttamente tabelle, RPC e Storage necessari alla pagina tramite
/// [DatabaseRepository]. Non utilizza repository specifici di mentoraggio.
class MentoreController extends ChangeNotifier {
  MentoreController({
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  static const String bucketSchedeSintesi = 'schede-sintesi';

  final DatabaseRepository db;

  List<PercorsoMentore> percorsi = const <PercorsoMentore>[];
  PercorsoMentore? selezionato;

  String? annoCorrente;
  bool caricamento = false;
  bool salvataggio = false;
  String? errore;

  /// Carica lo schema DB usato dalla visualizzazione e dall'editor dinamico.
  Future<SchemaDatabase> caricaSchemaDatabase() =>
      SchemaDatabase.carica(database: db);

  /// Carica mentoraggi, insegnamenti, docente e team del mentore corrente.
  Future<void> carica() async {
    final userId = db.userIdCorrente;
    if (userId == null) {
      errore = 'Sessione non valida.';
      notifyListeners();
      return;
    }

    caricamento = true;
    errore = null;
    notifyListeners();

    try {
      final risultatiBase = await Future.wait<dynamic>([
        db.tabella('anni_accademici').singolo(
          colonne: 'codice',
          filtri: const <FiltroDb>[
            FiltroDb.uguale('corrente', true),
          ],
        ),
        db.tabella('mentoraggio_mentori').elenco(
          colonne: 'mentoraggio_id, mentore_id, tipo',
          filtri: <FiltroDb>[
            FiltroDb.uguale('mentore_id', userId),
          ],
        ),
        db.rpcElenco('mentoraggi_del_mentore'),
      ]);

      annoCorrente =
          (risultatiBase[0] as Map<String, dynamic>?)?['codice']?.toString();

      final mieAssegnazioni =
          risultatiBase[1] as List<Map<String, dynamic>>;

      if (mieAssegnazioni.isEmpty) {
        percorsi = const <PercorsoMentore>[];
        selezionato = null;
        return;
      }

      final mentoraggi =
          risultatiBase[2] as List<Map<String, dynamic>>;

      final insegnamentoIds = mentoraggi
          .map((m) => m['insegnamento_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);

      final insegnamenti = insegnamentoIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : await db.tabella('insegnamenti').elenco(
              filtri: <FiltroDb>[
                FiltroDb.inLista(
                  'id',
                  insegnamentoIds.cast<Object>(),
                ),
              ],
            );

      final insegnamentiPerId = <String, Map<String, dynamic>>{
        for (final insegnamento in insegnamenti)
          if (insegnamento['id'] != null)
            insegnamento['id'].toString(): insegnamento,
      };

      final docenteIds = insegnamenti
          .map((i) => i['docente_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);

      final docenti = docenteIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : await db.tabella('anagrafica').elenco(
              colonne: 'user_id, nome, cognome, email_unipa, cellulare',
              filtri: <FiltroDb>[
                FiltroDb.inLista(
                  'user_id',
                  docenteIds.cast<Object>(),
                ),
              ],
            );

      final docentiPerId = <String, Map<String, dynamic>>{
        for (final docente in docenti)
          if (docente['user_id'] != null)
            docente['user_id'].toString(): docente,
      };

      final mentoraggioIds = mentoraggi
          .map((m) => m['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList(growable: false);

      final assegnazioni = mentoraggioIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : await db.tabella('mentoraggio_mentori').elenco(
              colonne: 'mentoraggio_id, mentore_id, tipo',
              filtri: <FiltroDb>[
                FiltroDb.inLista(
                  'mentoraggio_id',
                  mentoraggioIds.cast<Object>(),
                ),
              ],
            );

      final teamIds = assegnazioni
          .map((a) => a['mentore_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);

      final persone = teamIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : await db.tabella('anagrafica').elenco(
              colonne: 'user_id, nome, cognome, email_unipa',
              filtri: <FiltroDb>[
                FiltroDb.inLista(
                  'user_id',
                  teamIds.cast<Object>(),
                ),
              ],
            );

      final personePerId = <String, Map<String, dynamic>>{
        for (final persona in persone)
          if (persona['user_id'] != null)
            persona['user_id'].toString(): persona,
      };

      final risultato = <PercorsoMentore>[];

      for (final mentoraggio in mentoraggi) {
        final insegnamentoId =
            mentoraggio['insegnamento_id']?.toString() ?? '';
        final insegnamento = insegnamentiPerId[insegnamentoId];
        if (insegnamento == null) continue;

        final mentoraggioId =
            mentoraggio['id']?.toString() ?? '';

        final assegnati = assegnazioni
            .where(
              (a) =>
                  a['mentoraggio_id']?.toString() ==
                  mentoraggioId,
            )
            .toList(growable: false);

        final miaAssegnazione = assegnati.firstWhere(
          (a) => a['mentore_id']?.toString() == userId,
          orElse: () => <String, dynamic>{},
        );

        final team = assegnati.map((a) {
          final mentoreId = a['mentore_id']?.toString() ?? '';
          final persona =
              personePerId[mentoreId] ?? <String, dynamic>{};

          return <String, dynamic>{
            ...persona,
            'tipo': a['tipo'],
          };
        }).toList(growable: true)
          ..sort(_confrontaTeam);

        risultato.add(
          PercorsoMentore(
            mentoraggio: mentoraggio,
            insegnamento: insegnamento,
            docente: docentiPerId[
                  insegnamento['docente_id']?.toString()
                ] ??
                <String, dynamic>{},
            team: team,
            annoCorrente:
                mentoraggio['anno_accademico']?.toString() ==
                annoCorrente,
            mioRuolo:
                miaAssegnazione['tipo']?.toString() ?? '',
          ),
        );
      }

      risultato.sort(_confrontaPercorsi);
      percorsi = risultato;
      _ripristinaSelezione();
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile caricare i mentoraggi assegnati.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  /// Seleziona il percorso mostrato nel dettaglio.
  void seleziona(PercorsoMentore valore) {
    selezionato = valore;
    notifyListeners();
  }

  /// Salva esclusivamente i campi modificabili dal mentore.
  Future<void> salvaMentoraggio(
    Map<String, dynamic> valori,
  ) async {
    final percorso = selezionato;

    if (percorso == null || !percorso.annoCorrente) {
      throw const AppException(
        'Questo mentoraggio e\' in sola lettura.',
      );
    }

    salvataggio = true;
    errore = null;
    notifyListeners();

    try {
      const esclusi = <String>{
        'id',
        'insegnamento_id',
        'anno_accademico',
        'data_inizio',
        'data_fine',
        'numero_studenti',
        'sede',
        'note',
        'svolgimento',
        'giorni_orari_lezioni',
        'scheda_sintesi_pdf_url',
        'created_at',
        'updated_at',
      };

      final patch = <String, dynamic>{
        for (final entry in valori.entries)
          if (!esclusi.contains(entry.key))
            entry.key: entry.value,
      };

      await db.rpc(
        'mentoraggio_aggiorna_mentore',
        parametri: <String, dynamic>{
          'p_mentoraggio_id':
              percorso.mentoraggio['id'].toString(),
          'p_valori': patch,
        },
      );

      await carica();
    } catch (e) {
      final eccezione = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile salvare il mentoraggio.',
      );
      errore = eccezione.messaggio;
      throw eccezione;
    } finally {
      salvataggio = false;
      notifyListeners();
    }
  }

  /// Carica o sostituisce la scheda di sintesi del mentoraggio.
  ///
  /// Storage e aggiornamento DB vengono coordinati qui; le primitive di
  /// accesso remoto restano generiche nel [DatabaseRepository].
  Future<String> salvaSchedaSintesi({
    required String mentoraggioId,
    required String annoAccademico,
    required String estensione,
    required Uint8List bytes,
    required String contentType,
    String? percorsoPrecedente,
  }) async {
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
      } catch (_) {
        // Pulizia best effort.
      }
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
        // Il nuovo documento e' gia' valido.
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

  void _ripristinaSelezione() {
    final idSelezionato =
        selezionato?.mentoraggio['id']?.toString();

    if (idSelezionato == null ||
        !percorsi.any(
          (p) =>
              p.mentoraggio['id']?.toString() ==
              idSelezionato,
        )) {
      selezionato =
          percorsi.isEmpty ? null : percorsi.first;
      return;
    }

    selezionato = percorsi.firstWhere(
      (p) =>
          p.mentoraggio['id']?.toString() ==
          idSelezionato,
    );
  }

  static int _confrontaTeam(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final seniorA =
        a['tipo']?.toString().toLowerCase() == 'senior';
    final seniorB =
        b['tipo']?.toString().toLowerCase() == 'senior';

    if (seniorA != seniorB) return seniorA ? 1 : -1;

    return '${a['cognome'] ?? ''} ${a['nome'] ?? ''}'
        .compareTo(
          '${b['cognome'] ?? ''} ${b['nome'] ?? ''}',
        );
  }

  static int _confrontaPercorsi(
    PercorsoMentore a,
    PercorsoMentore b,
  ) {
    final confrontoAnno =
        (b.mentoraggio['anno_accademico']?.toString() ?? '')
            .compareTo(
              a.mentoraggio['anno_accademico']?.toString() ?? '',
            );

    if (confrontoAnno != 0) return confrontoAnno;

    return (a.insegnamento['insegnamento']?.toString() ?? '')
        .compareTo(
          b.insegnamento['insegnamento']?.toString() ?? '',
        );
  }
}
