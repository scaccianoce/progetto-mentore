import 'package:flutter/foundation.dart';

import '../../../app/app_core.dart';
import '../../../app/app_session_controller.dart';
import '../../../dati/repository.dart';

/// Sintesi numerica di un anno accademico pronta per la UI.
class RiepilogoAnnoAccademico {
  const RiepilogoAnnoAccademico({
    required this.anno,
    required this.partecipanti,
    required this.daConfermare,
    required this.confermati,
    required this.rinunce,
    required this.insegnamenti,
    required this.insegnamentiMentorati,
    required this.mentoraggiConclusi,
    required this.eventi,
    required this.iscrizioniEventi,
    required this.presenzeEventi,
    required this.mediaPresenzeEventi,
    required this.houseOfMentore,
    required this.iscrizioniHom,
    required this.presenzeHom,
    required this.mediaPresenzeHom,
  });

  factory RiepilogoAnnoAccademico.vuoto(String anno) =>
      RiepilogoAnnoAccademico(
        anno: anno,
        partecipanti: 0,
        daConfermare: 0,
        confermati: 0,
        rinunce: 0,
        insegnamenti: 0,
        insegnamentiMentorati: 0,
        mentoraggiConclusi: 0,
        eventi: 0,
        iscrizioniEventi: 0,
        presenzeEventi: 0,
        mediaPresenzeEventi: 0,
        houseOfMentore: 0,
        iscrizioniHom: 0,
        presenzeHom: 0,
        mediaPresenzeHom: 0,
      );

  final String anno;
  final int partecipanti;
  final int daConfermare;
  final int confermati;
  final int rinunce;
  final int insegnamenti;
  final int insegnamentiMentorati;
  final int mentoraggiConclusi;
  final int eventi;
  final int iscrizioniEventi;
  final int presenzeEventi;
  final double mediaPresenzeEventi;
  final int houseOfMentore;
  final int iscrizioniHom;
  final int presenzeHom;
  final double mediaPresenzeHom;
}

/// Pacchetto coerente di dati relativi a un singolo anno accademico.
///
/// La relazione annuale parte da `mentoraggi.anno_accademico`; gli
/// insegnamenti sono recuperati tramite `mentoraggi.insegnamento_id`.
class BackofficeDatiAnno {
  const BackofficeDatiAnno({
    required this.anno,
    required this.mentoraggi,
    required this.insegnamenti,
    required this.assegnazioni,
    required this.eventi,
    required this.partecipazioniEventi,
    required this.partecipazioniAnnuali,
    required this.houseOfMentore,
    required this.opzioniHouseOfMentore,
    required this.partecipazioniHouseOfMentore,
    required this.anagrafiche,
    required this.riservati,
    required this.ruoli,
  });

  final String anno;
  final List<Map<String, dynamic>> mentoraggi;
  final List<Map<String, dynamic>> insegnamenti;
  final List<Map<String, dynamic>> assegnazioni;
  final List<Map<String, dynamic>> eventi;
  final List<Map<String, dynamic>> partecipazioniEventi;
  final List<Map<String, dynamic>> partecipazioniAnnuali;
  final List<Map<String, dynamic>> houseOfMentore;
  final List<Map<String, dynamic>> opzioniHouseOfMentore;
  final List<Map<String, dynamic>> partecipazioniHouseOfMentore;
  final List<Map<String, dynamic>> anagrafiche;
  final List<Map<String, dynamic>> riservati;
  final List<Map<String, dynamic>> ruoli;

  Map<String, List<Map<String, dynamic>>> esportazione({
    required List<Map<String, dynamic>> rigaAnno,
  }) =>
      <String, List<Map<String, dynamic>>>{
        'anni_accademici': rigaAnno,
        'anagrafica': anagrafiche,
        'anagrafica_riservata': riservati,
        'user_roles': ruoli,
        'insegnamenti': insegnamenti,
        'mentoraggi': mentoraggi,
        'mentoraggio_mentori': assegnazioni,
        'eventi': eventi,
        'partecipazioni_eventi': partecipazioniEventi,
        'partecipazioni_annuali': partecipazioniAnnuali,
        'house_of_mentore': houseOfMentore,
        'house_of_mentore_opzioni': opzioniHouseOfMentore,
        'partecipazioni_house_of_mentore': partecipazioniHouseOfMentore,
      };
}

/// Controller del backoffice Anni accademici.
///
/// Possiede lo stato della pagina, costruisce le sintesi annuali e coordina
/// direttamente le tabelle necessarie tramite [DatabaseRepository].
class AnniAccademiciBackofficeController extends ChangeNotifier {
  AnniAccademiciBackofficeController(
    this.sessione, {
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  final SessioneController sessione;
  final DatabaseRepository db;

  final List<Map<String, dynamic>> anni = <Map<String, dynamic>>[];
  final Map<String, RiepilogoAnnoAccademico> riepiloghi =
      <String, RiepilogoAnnoAccademico>{};

  bool caricamento = false;
  bool salvataggio = false;
  String? errore;

  bool get puoAmministrare => sessione.ruolo?.puoAmministrare ?? false;

  String? get annoAttivo {
    for (final anno in anni) {
      if (_statoAnno(anno) == 'attivo') {
        final codice = anno['codice']?.toString();
        if (codice != null && codice.isNotEmpty) return codice;
      }
    }
    return null;
  }

  /// Carica anni accademici e relative sintesi.
  Future<void> carica() async {
    caricamento = true;
    errore = null;
    notifyListeners();

    try {
      final righeAnni = await db.tabella('anni_accademici').elenco(
        ordinamenti: const <OrdineDb>[
          OrdineDb('codice', crescente: false),
        ],
      );

      anni
        ..clear()
        ..addAll(righeAnni);

      final datiSintesi = await caricaDatiSintesi();
      _calcolaRiepiloghi(datiSintesi);
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile caricare gli anni accademici.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  /// Carica le tabelle necessarie al calcolo della sintesi annuale.
  Future<List<List<Map<String, dynamic>>>> caricaDatiSintesi() =>
      Future.wait<List<Map<String, dynamic>>>([
        db.tabella('insegnamenti').elenco(),
        db.tabella('mentoraggi').elenco(),
        db.tabella('mentoraggio_mentori').elenco(),
        db.tabella('eventi').elenco(),
        db.tabella('partecipazioni_eventi').elenco(),
        db.tabella('house_of_mentore').elenco(),
        db.tabella('partecipazioni_house_of_mentore').elenco(),
        db.tabella('partecipazioni_annuali').elenco(),
        db.tabella('user_roles').elenco(
          colonne: 'user_id, role',
        ),
      ]);

  /// Carica tutte le relazioni necessarie per esportare un singolo anno.
  Future<BackofficeDatiAnno> caricaDatiAnno(
    String anno, {
    bool caricaAnagrafiche = true,
  }) async {
    final filtroAnno = <FiltroDb>[
      FiltroDb.uguale('anno_accademico', anno),
    ];

    final principali = await Future.wait<List<Map<String, dynamic>>>([
      db.tabella('mentoraggi').elenco(filtri: filtroAnno),
      db.tabella('eventi').elenco(filtri: filtroAnno),
      db.tabella('house_of_mentore').elenco(filtri: filtroAnno),
      db.tabella('partecipazioni_annuali').elenco(filtri: filtroAnno),
    ]);

    final mentoraggi = principali[0];
    final eventi = principali[1];
    final house = principali[2];
    final annuali = principali[3];

    final insegnamentoIds = _idsUnivoci(mentoraggi, 'insegnamento_id');
    final mentoraggioIds = _idsUnivoci(mentoraggi, 'id');
    final eventoIds = _idsUnivoci(eventi, 'id');
    final houseIds = _idsUnivoci(house, 'id');

    final collegati = await Future.wait<List<Map<String, dynamic>>>([
      _elencoPerIds('insegnamenti', 'id', insegnamentoIds),
      _elencoPerIds(
        'mentoraggio_mentori',
        'mentoraggio_id',
        mentoraggioIds,
      ),
      _elencoPerIds(
        'partecipazioni_eventi',
        'evento_id',
        eventoIds,
      ),
      _elencoPerIds(
        'house_of_mentore_opzioni',
        'evento_id',
        houseIds,
      ),
      _elencoPerIds(
        'partecipazioni_house_of_mentore',
        'evento_id',
        houseIds,
      ),
    ]);

    final insegnamenti = collegati[0];
    final assegnazioni = collegati[1];
    final partecipazioniEventi = collegati[2];
    final opzioniHouse = collegati[3];
    final partecipazioniHouse = collegati[4];

    if (!caricaAnagrafiche) {
      return BackofficeDatiAnno(
        anno: anno,
        mentoraggi: mentoraggi,
        insegnamenti: insegnamenti,
        assegnazioni: assegnazioni,
        eventi: eventi,
        partecipazioniEventi: partecipazioniEventi,
        partecipazioniAnnuali: annuali,
        houseOfMentore: house,
        opzioniHouseOfMentore: opzioniHouse,
        partecipazioniHouseOfMentore: partecipazioniHouse,
        anagrafiche: const <Map<String, dynamic>>[],
        riservati: const <Map<String, dynamic>>[],
        ruoli: const <Map<String, dynamic>>[],
      );
    }

    final partecipanteIds = <String>{
      ...insegnamenti
          .map((r) => r['docente_id']?.toString())
          .whereType<String>(),
      ...assegnazioni
          .map((r) => r['mentore_id']?.toString())
          .whereType<String>(),
      ...partecipazioniEventi
          .map((r) => r['partecipante_id']?.toString())
          .whereType<String>(),
      ...partecipazioniHouse
          .map((r) => r['partecipante_id']?.toString())
          .whereType<String>(),
      ...annuali
          .map((r) => r['user_id']?.toString())
          .whereType<String>(),
    }..removeWhere((id) => id.isEmpty || id == 'null');

    final ids = partecipanteIds.toList(growable: false);
    final persone = await Future.wait<List<Map<String, dynamic>>>([
      _elencoPerIds('anagrafica', 'user_id', ids),
      _elencoPerIds('anagrafica_riservata', 'user_id', ids),
      _elencoPerIds('user_roles', 'user_id', ids),
    ]);

    return BackofficeDatiAnno(
      anno: anno,
      mentoraggi: mentoraggi,
      insegnamenti: insegnamenti,
      assegnazioni: assegnazioni,
      eventi: eventi,
      partecipazioniEventi: partecipazioniEventi,
      partecipazioniAnnuali: annuali,
      houseOfMentore: house,
      opzioniHouseOfMentore: opzioniHouse,
      partecipazioniHouseOfMentore: partecipazioniHouse,
      anagrafiche: persone[0],
      riservati: persone[1],
      ruoli: persone[2],
    );
  }

  Future<List<Map<String, dynamic>>> caricaRigaAnno(String anno) =>
      db.tabella('anni_accademici').elenco(
        filtri: <FiltroDb>[
          FiltroDb.uguale('codice', anno),
        ],
      );

  /// Crea un nuovo anno inizialmente in preparazione.
  Future<String?> aggiungiAnno(
    String codice,
    String? dataInizio,
    String? dataFine,
  ) =>
      _esegui(
        messaggio: 'Impossibile creare l’anno accademico.',
        azione: () async {
          _verificaAmministratore();

          final codicePulito = codice.trim();
          if (codicePulito.isEmpty) {
            throw const AppException(
              'Il codice dell’anno accademico è obbligatorio.',
            );
          }

          await db.tabella('anni_accademici').inserisci(
            <String, dynamic>{
              'codice': codicePulito,
              'data_inizio': dataInizio,
              'data_fine': dataFine,
              'stato': 'preparazione',
              'corrente': false,
            },
            colonne: 'codice',
          );
        },
      );

  /// Modifica lo stato dell'anno e mantiene coerente il flag `corrente`.
  Future<String?> impostaStatoAnno(
    String codice,
    String stato,
  ) =>
      _esegui(
        messaggio:
            'Impossibile modificare lo stato dell’anno accademico.',
        azione: () async {
          _verificaAmministratore();

          const stati = <String>{
            'preparazione',
            'attivo',
            'chiuso',
          };
          if (!stati.contains(stato)) {
            throw const AppException(
              'Stato dell’anno accademico non valido.',
            );
          }

          final tabella = db.tabella('anni_accademici');

          if (stato == 'attivo') {
            for (final anno in anni) {
              final altroCodice = anno['codice']?.toString();
              if (altroCodice == null ||
                  altroCodice.isEmpty ||
                  altroCodice == codice ||
                  anno['corrente'] != true) {
                continue;
              }

              await tabella.aggiorna(
                <String, dynamic>{
                  'corrente': false,
                  if (_statoAnno(anno) == 'attivo') 'stato': 'chiuso',
                },
                filtri: <FiltroDb>[
                  FiltroDb.uguale('codice', altroCodice),
                ],
                colonne: 'codice',
              );
            }
          }

          await tabella.aggiorna(
            <String, dynamic>{
              'stato': stato,
              'corrente': stato == 'attivo',
            },
            filtri: <FiltroDb>[
              FiltroDb.uguale('codice', codice),
            ],
            colonne: 'codice',
          );
        },
      );

/// Genera le richieste annuali senza duplicare righe già presenti.
Future<String?> generaRichiestePartecipazione(
  String annoDestinazione, {
  String? annoSorgente,
}) =>
    _esegui(
      messaggio:
          'Impossibile generare le richieste di partecipazione.',
      azione: () async {
        _verificaAmministratore();

        final sorgente = annoSorgente ?? annoAttivo;

        if (sorgente == null || sorgente.isEmpty) {
          throw const AppException(
            'Nessun anno attivo disponibile come sorgente.',
          );
        }

        if (sorgente == annoDestinazione) {
          throw const AppException(
            'Anno sorgente e destinazione devono essere diversi.',
          );
        }

        await db.rpc(
          'partecipazioni_annuali_genera',
          parametri: <String, dynamic>{
            'p_anno_destinazione': annoDestinazione,
            'p_anno_sorgente': sorgente,
          },
        );
      },
    );

  Future<List<Map<String, dynamic>>> _elencoPerIds(
    String tabella,
    String campo,
    List<String> ids,
  ) {
    if (ids.isEmpty) {
      return Future<List<Map<String, dynamic>>>.value(
        const <Map<String, dynamic>>[],
      );
    }

    return db.tabella(tabella).elenco(
      filtri: <FiltroDb>[
        FiltroDb.inLista(campo, ids.cast<Object>()),
      ],
    );
  }

  void _calcolaRiepiloghi(
    List<List<Map<String, dynamic>>> dati,
  ) {
    final insegnamenti = dati[0];
    final mentoraggi = dati[1];
    final assegnazioni = dati[2];
    final eventi = dati[3];
    final partecipazioniEventi = dati[4];
    final house = dati[5];
    final partecipazioniHouse = dati[6];
    final annuali = dati[7];
    final userRoles = dati[8];

    riepiloghi.clear();

    for (final rigaAnno in anni) {
      final anno = rigaAnno['codice']?.toString() ?? '';
      if (anno.isEmpty) continue;

      final mentoraggiAnno = mentoraggi
          .where(
            (r) => r['anno_accademico']?.toString() == anno,
          )
          .toList(growable: false);

      final insegnamentoIds = mentoraggiAnno
          .map((r) => r['insegnamento_id']?.toString())
          .whereType<String>()
          .toSet();

      final insegnamentiAnno = insegnamenti
          .where(
            (r) => insegnamentoIds.contains(r['id']?.toString()),
          )
          .toList(growable: false);

      final mentoraggioIds = mentoraggiAnno
          .map((r) => r['id']?.toString())
          .whereType<String>()
          .toSet();

      final mentoriIds = assegnazioni
          .where(
            (r) => mentoraggioIds
                .contains(r['mentoraggio_id']?.toString()),
          )
          .map((r) => r['mentore_id']?.toString())
          .whereType<String>();

      final menteeIds = insegnamentiAnno
          .map((r) => r['docente_id']?.toString())
          .whereType<String>();

      final partecipantiEffettivi = <String>{
        ...menteeIds,
        ...mentoriIds,
      }..removeWhere((id) => id.isEmpty || id == 'null');

      final eventiAnno = eventi
          .where(
            (r) => r['anno_accademico']?.toString() == anno,
          )
          .toList(growable: false);

      final eventoIds = eventiAnno
          .map((r) => r['id']?.toString())
          .whereType<String>()
          .toSet();

      final iscrizioniEventi = partecipazioniEventi
          .where(
            (r) => eventoIds.contains(r['evento_id']?.toString()),
          )
          .toList(growable: false);

      final presenzeEventi = iscrizioniEventi
          .where((r) => r['presente'] == true)
          .length;

      final houseAnno = house
          .where(
            (r) => r['anno_accademico']?.toString() == anno,
          )
          .toList(growable: false);

      final houseIds = houseAnno
          .map((r) => r['id']?.toString())
          .whereType<String>()
          .toSet();

      final iscrizioniHouse = partecipazioniHouse
          .where(
            (r) => houseIds.contains(r['evento_id']?.toString()),
          )
          .toList(growable: false);

      final presenzeHouse = iscrizioniHouse
          .where((r) => r['presente'] == true)
          .length;

      final annualiAnno = annuali
          .where(
            (r) => r['anno_accademico']?.toString() == anno,
          )
          .toList(growable: false);

      final amministratori = userRoles
          .where(
            (r) => const <String>{'owner', 'organizer'}
                .contains(r['role']?.toString()),
          )
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty && id != 'null')
          .toSet();

      final annualiIds = annualiAnno
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty && id != 'null')
          .toSet();

      final numeroPartecipanti = annualiAnno.isEmpty
          ? <String>{...partecipantiEffettivi, ...amministratori}.length
          : <String>{...annualiIds, ...amministratori}.length;

      riepiloghi[anno] = RiepilogoAnnoAccademico(
        anno: anno,
        partecipanti: numeroPartecipanti,
        daConfermare: annualiAnno
            .where(
              (r) => r['stato']?.toString() == 'da_contattare',
            )
            .length,
        confermati: annualiAnno
            .where(
              (r) => const <String>{'confermato', 'nuovo'}
                  .contains(r['stato']?.toString()),
            )
            .length,
        rinunce: annualiAnno
            .where(
              (r) => r['stato']?.toString() == 'rinuncia',
            )
            .length,
        insegnamenti: insegnamentiAnno.length,
        insegnamentiMentorati: insegnamentoIds.length,
        mentoraggiConclusi:
            mentoraggiAnno.where(_mentoraggioConcluso).length,
        eventi: eventiAnno.length,
        iscrizioniEventi: iscrizioniEventi.length,
        presenzeEventi: presenzeEventi,
        mediaPresenzeEventi: eventiAnno.isEmpty
            ? 0
            : presenzeEventi / eventiAnno.length,
        houseOfMentore: houseAnno.length,
        iscrizioniHom: iscrizioniHouse.length,
        presenzeHom: presenzeHouse,
        mediaPresenzeHom: houseAnno.isEmpty
            ? 0
            : presenzeHouse / houseAnno.length,
      );
    }
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

List<String> _idsUnivoci(
  List<Map<String, dynamic>> righe,
  String campo,
) =>
    righe
        .map((r) => r[campo]?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty && id != 'null')
        .toSet()
        .toList(growable: false);

String _statoAnno(Map<String, dynamic> anno) {
  final stato = anno['stato']?.toString();
  if (stato != null && stato.isNotEmpty) return stato;
  return anno['corrente'] == true ? 'attivo' : 'chiuso';
}

bool _mentoraggioConcluso(Map<String, dynamic> riga) {
  final invio = riga['data_invio_scheda'];
  if (invio != null && invio.toString().trim().isNotEmpty) return true;

  final stato = riga['stato']?.toString().toLowerCase() ?? '';
  return stato.contains('conclus') ||
      stato.contains('complet') ||
      stato.contains('termin');
}
