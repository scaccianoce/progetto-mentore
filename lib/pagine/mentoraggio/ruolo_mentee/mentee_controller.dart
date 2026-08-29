import 'package:flutter/foundation.dart';

import '../../../app/app_core.dart';
import '../../../dati/repository.dart';
import '../../../ui/dinamico_schema.dart';

/// Raggruppa i dati necessari alla visualizzazione di un percorso da mentee.
class PercorsoMentee {
  const PercorsoMentee({
    required this.insegnamento,
    required this.mentoraggio,
    required this.mentori,
    required this.annoCorrente,
    required this.sintesiQuestionario,
  });

  final Map<String, dynamic> insegnamento;
  final Map<String, dynamic> mentoraggio;
  final List<Map<String, dynamic>> mentori;
  final bool annoCorrente;
  final Map<String, dynamic>? sintesiQuestionario;
}

/// Controller della pagina Ruolo Mentee.
///
/// Coordina direttamente le tabelle e le RPC necessarie alla pagina attraverso
/// [DatabaseRepository]. Non esiste piu' un repository specifico Mentoraggi.
class MenteeController extends ChangeNotifier {
  MenteeController({
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  final DatabaseRepository db;

  List<PercorsoMentee> percorsi = const <PercorsoMentee>[];
  PercorsoMentee? selezionato;

  String? annoCorrente;
  bool caricamento = false;
  bool salvataggio = false;
  String? errore;

  /// Carica lo schema DB usato dalla visualizzazione e dalla maschera dinamica.
  Future<SchemaDatabase> caricaSchemaDatabase() =>
      SchemaDatabase.carica(database: db);

  /// Carica tutti i dati necessari alla pagina Mentee.
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
        db.tabella('insegnamenti').elenco(
          filtri: <FiltroDb>[
            FiltroDb.uguale('docente_id', userId),
          ],
        ),
        db.rpcElenco('mentoraggi_del_mentee'),
      ]);

      annoCorrente =
          (risultatiBase[0] as Map<String, dynamic>?)?['codice']?.toString();

      final insegnamenti =
          (risultatiBase[1] as List<Map<String, dynamic>>);
      final mentoraggi =
          (risultatiBase[2] as List<Map<String, dynamic>>);

      final insegnamentiPerId = <String, Map<String, dynamic>>{
        for (final insegnamento in insegnamenti)
          if (insegnamento['id'] != null)
            insegnamento['id'].toString(): insegnamento,
      };

      final mentoraggioIds = mentoraggi
          .map((mentoraggio) => mentoraggio['id']?.toString())
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

      final mentoreIds = assegnazioni
          .map((assegnazione) => assegnazione['mentore_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);

      final persone = mentoreIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : await db.tabella('anagrafica').elenco(
              colonne: 'user_id, nome, cognome, email_unipa, cellulare',
              filtri: <FiltroDb>[
                FiltroDb.inLista(
                  'user_id',
                  mentoreIds.cast<Object>(),
                ),
              ],
            );

      final personePerId = <String, Map<String, dynamic>>{
        for (final persona in persone)
          if (persona['user_id'] != null)
            persona['user_id'].toString(): persona,
      };

      final nuoviPercorsi = <PercorsoMentee>[];

      for (final mentoraggio in mentoraggi) {
        final insegnamentoId =
            mentoraggio['insegnamento_id']?.toString() ?? '';
        final insegnamento = insegnamentiPerId[insegnamentoId];

        if (insegnamento == null) continue;

        final mentoraggioId = mentoraggio['id']?.toString() ?? '';

        final team = assegnazioni
            .where(
              (assegnazione) =>
                  assegnazione['mentoraggio_id']?.toString() ==
                  mentoraggioId,
            )
            .map((assegnazione) {
              final mentoreId =
                  assegnazione['mentore_id']?.toString() ?? '';
              final persona =
                  personePerId[mentoreId] ?? <String, dynamic>{};

              return <String, dynamic>{
                ...persona,
                'tipo': assegnazione['tipo'],
              };
            })
            .toList(growable: true)
          ..sort(_confrontaTeam);

        Map<String, dynamic>? sintesiQuestionario;

        if (mentoraggioId.isNotEmpty) {
          try {
            sintesiQuestionario = await db.rpcMappa(
              'questionario_sintesi_mentoraggio',
              parametri: <String, dynamic>{
                'p_mentoraggio_id': mentoraggioId,
              },
            );
          } catch (_) {
            // La pagina resta disponibile anche senza la sintesi questionario.
          }
        }

        nuoviPercorsi.add(
          PercorsoMentee(
            insegnamento: insegnamento,
            mentoraggio: mentoraggio,
            mentori: team,
            annoCorrente:
                mentoraggio['anno_accademico']?.toString() == annoCorrente,
            sintesiQuestionario: sintesiQuestionario,
          ),
        );
      }

      nuoviPercorsi.sort(_confrontaPercorsi);
      percorsi = nuoviPercorsi;
      _ripristinaSelezione();
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile caricare i mentoraggi da mentee.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  /// Seleziona il percorso da mostrare nella pagina.
  void seleziona(PercorsoMentee percorso) {
    selezionato = percorso;
    notifyListeners();
  }

  /// Salva i soli campi che il mentee puo' modificare.
  Future<void> salva(Map<String, dynamic> valori) async {
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
      const consentiti = <String>{
        'data_inizio',
        'data_fine',
        'numero_studenti',
        'sede',
        'note',
        'svolgimento',
        'giorni_orari_lezioni',
      };

      final patch = <String, dynamic>{
        for (final entry in valori.entries)
          if (consentiti.contains(entry.key))
            entry.key: entry.value,
      };

      await db.rpc(
        'mentoraggio_aggiorna_mentee',
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
            'Impossibile aggiornare il mentoraggio.',
      );
      errore = eccezione.messaggio;
      throw eccezione;
    } finally {
      salvataggio = false;
      notifyListeners();
    }
  }

  /// Restituisce un URL temporaneo apribile per la scheda di sintesi.
  Future<String> urlSchedaSintesi(String valore) {
    final percorso = valore.trim();

    if (percorso.startsWith('http://') ||
        percorso.startsWith('https://')) {
      return Future<String>.value(percorso);
    }

    return db.creaUrlFirmato(
      bucket: 'schede-sintesi',
      percorso: percorso,
      durata: const Duration(hours: 1),
    );
  }

  void _ripristinaSelezione() {
    final idSelezionato =
        selezionato?.mentoraggio['id']?.toString();

    if (idSelezionato == null ||
        !percorsi.any(
          (percorso) =>
              percorso.mentoraggio['id']?.toString() ==
              idSelezionato,
        )) {
      selezionato = percorsi.isEmpty ? null : percorsi.first;
      return;
    }

    selezionato = percorsi.firstWhere(
      (percorso) =>
          percorso.mentoraggio['id']?.toString() ==
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
    PercorsoMentee a,
    PercorsoMentee b,
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
