import 'package:flutter/foundation.dart';

import '../../../app/app_core.dart';
import '../../../dati/repository.dart';
import '../../../ui/dinamico_schema.dart';

/// Membro del team di mentoraggio mostrato nel controllo annuale.
class MembroTeamControllo {
  const MembroTeamControllo({
    required this.nome,
    required this.tipo,
  });

  final String nome;
  final String tipo;
}

/// Percorso in cui il partecipante svolge il ruolo di mentee.
class PercorsoMenteeControllo {
  const PercorsoMenteeControllo({
    required this.insegnamento,
    required this.insegnamentoRiga,
    required this.team,
    required this.mentoraggio,
  });

  final String insegnamento;
  final Map<String, dynamic> insegnamentoRiga;
  final List<MembroTeamControllo> team;
  final Map<String, dynamic> mentoraggio;
}

/// Percorso in cui il partecipante svolge il ruolo di mentore.
class PercorsoMentoreControllo {
  const PercorsoMentoreControllo({
    required this.insegnamento,
    required this.insegnamentoRiga,
    required this.mentee,
    required this.mioTipo,
    required this.altriTeam,
    required this.mentoraggio,
  });

  final String insegnamento;
  final Map<String, dynamic> insegnamentoRiga;
  final String mentee;
  final String mioTipo;
  final List<MembroTeamControllo> altriTeam;
  final Map<String, dynamic> mentoraggio;
}

/// Partecipazione a un evento.
class PartecipazioneEventoControllo {
  const PartecipazioneEventoControllo({
    required this.titolo,
    required this.presente,
  });

  final String titolo;
  final bool presente;
}

/// Riepilogo annuale pronto per essere visualizzato dalla pagina.
class PartecipanteAnnoControllo {
  const PartecipanteAnnoControllo({
    required this.persona,
    required this.mentee,
    required this.mentore,
    required this.eventi,
    required this.houseOfMentore,
  });

  final Map<String, dynamic> persona;
  final List<PercorsoMenteeControllo> mentee;
  final List<PercorsoMentoreControllo> mentore;
  final List<PartecipazioneEventoControllo> eventi;
  final List<String> houseOfMentore;
}

/// Dati grezzi di un singolo anno accademico.
///
/// Questa classe resta nel controller perché rappresenta il processo dati,
/// non la UI. L'anno appartiene ai `mentoraggi`; gli insegnamenti vengono
/// recuperati tramite `mentoraggi.insegnamento_id`.
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
}

/// Controller del backoffice Controllo partecipanti.
///
/// Costruisce il riepilogo annuale completo e lo espone già pronto alla Page.
/// Tutti gli accessi remoti passano da [DatabaseRepository].
class ControlloPartecipantiBackofficeController extends ChangeNotifier {
  ControlloPartecipantiBackofficeController({
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  static const String bucketSchedeSintesi = 'schede-sintesi';

  final DatabaseRepository db;

  List<String> anni = const <String>[];
  String? annoSelezionato;
  List<PartecipanteAnnoControllo> partecipanti =
      const <PartecipanteAnnoControllo>[];

  bool caricamento = false;
  String? errore;

  /// Inizializza il controllo scegliendo, se disponibile, l'anno corrente.
  Future<void> inizializza() async {
    caricamento = true;
    errore = null;
    notifyListeners();

    try {
      final righe = await db.tabella('anni_accademici').elenco(
        colonne: 'codice, corrente',
        ordinamenti: const <OrdineDb>[
          OrdineDb('codice', crescente: false),
        ],
      );

      anni = righe
          .map((riga) => riga['codice']?.toString() ?? '')
          .where((codice) => codice.isNotEmpty)
          .toList(growable: false);

      final corrente = righe
          .where((riga) => riga['corrente'] == true)
          .map((riga) => riga['codice']?.toString())
          .whereType<String>()
          .firstOrNull;

      annoSelezionato = corrente ?? anni.firstOrNull;

      if (annoSelezionato != null) {
        partecipanti = await _costruisciPartecipanti(annoSelezionato!);
      }
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile inizializzare il controllo partecipanti.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  /// Cambia anno e ricostruisce il riepilogo.
  Future<void> selezionaAnno(String? anno) async {
    if (anno == null || anno.isEmpty) return;
    annoSelezionato = anno;
    await carica();
  }

  /// Ricarica il riepilogo dell'anno selezionato.
  Future<void> carica() async {
    final anno = annoSelezionato;
    if (anno == null) return;

    caricamento = true;
    errore = null;
    notifyListeners();

    try {
      partecipanti = await _costruisciPartecipanti(anno);
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile costruire il controllo partecipanti.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  /// Carica i dati grezzi coerenti con un singolo anno accademico.
  Future<BackofficeDatiAnno> caricaDatiAnno(
    String anno, {
    bool caricaAnagrafiche = true,
  }) async {
    final filtroAnno = <FiltroDb>[
      FiltroDb.uguale('anno_accademico', anno),
    ];

    final risultatiPrincipali =
        await Future.wait<List<Map<String, dynamic>>>([
      db.tabella('mentoraggi').elenco(
        filtri: filtroAnno,
      ),
      db.tabella('eventi').elenco(
        filtri: filtroAnno,
      ),
      db.tabella('house_of_mentore').elenco(
        filtri: filtroAnno,
      ),
      db.tabella('partecipazioni_annuali').elenco(
        filtri: filtroAnno,
      ),
    ]);

    final mentoraggi = risultatiPrincipali[0];
    final eventi = risultatiPrincipali[1];
    final house = risultatiPrincipali[2];
    final partecipazioniAnnuali = risultatiPrincipali[3];

    final insegnamentoIds = _idsUnivoci(
      mentoraggi,
      'insegnamento_id',
    );
    final mentoraggioIds = _idsUnivoci(mentoraggi, 'id');
    final eventoIds = _idsUnivoci(eventi, 'id');
    final houseIds = _idsUnivoci(house, 'id');

    final risultatiCollegati =
        await Future.wait<List<Map<String, dynamic>>>([
      _elencoPerIds(
        tabella: 'insegnamenti',
        campo: 'id',
        ids: insegnamentoIds,
      ),
      _elencoPerIds(
        tabella: 'mentoraggio_mentori',
        campo: 'mentoraggio_id',
        ids: mentoraggioIds,
      ),
      _elencoPerIds(
        tabella: 'partecipazioni_eventi',
        campo: 'evento_id',
        ids: eventoIds,
      ),
      _elencoPerIds(
        tabella: 'house_of_mentore_opzioni',
        campo: 'evento_id',
        ids: houseIds,
      ),
      _elencoPerIds(
        tabella: 'partecipazioni_house_of_mentore',
        campo: 'evento_id',
        ids: houseIds,
      ),
    ]);

    final insegnamenti = risultatiCollegati[0];
    final assegnazioni = risultatiCollegati[1];
    final partecipazioniEventi = risultatiCollegati[2];
    final opzioniHouse = risultatiCollegati[3];
    final partecipazioniHouse = risultatiCollegati[4];

    if (!caricaAnagrafiche) {
      return BackofficeDatiAnno(
        anno: anno,
        mentoraggi: mentoraggi,
        insegnamenti: insegnamenti,
        assegnazioni: assegnazioni,
        eventi: eventi,
        partecipazioniEventi: partecipazioniEventi,
        partecipazioniAnnuali: partecipazioniAnnuali,
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
          .map((riga) => riga['docente_id']?.toString())
          .whereType<String>(),
      ...assegnazioni
          .map((riga) => riga['mentore_id']?.toString())
          .whereType<String>(),
      ...partecipazioniEventi
          .map((riga) => riga['partecipante_id']?.toString())
          .whereType<String>(),
      ...partecipazioniHouse
          .map((riga) => riga['partecipante_id']?.toString())
          .whereType<String>(),
      ...partecipazioniAnnuali
          .map((riga) => riga['user_id']?.toString())
          .whereType<String>(),
    }..removeWhere(
        (id) => id.isEmpty || id == 'null',
      );

    final ids = partecipanteIds.toList(growable: false);

    final persone = await Future.wait<List<Map<String, dynamic>>>([
      _elencoPerIds(
        tabella: 'anagrafica',
        campo: 'user_id',
        ids: ids,
      ),
      _elencoPerIds(
        tabella: 'anagrafica_riservata',
        campo: 'user_id',
        ids: ids,
      ),
      _elencoPerIds(
        tabella: 'user_roles',
        campo: 'user_id',
        ids: ids,
      ),
    ]);

    return BackofficeDatiAnno(
      anno: anno,
      mentoraggi: mentoraggi,
      insegnamenti: insegnamenti,
      assegnazioni: assegnazioni,
      eventi: eventi,
      partecipazioniEventi: partecipazioniEventi,
      partecipazioniAnnuali: partecipazioniAnnuali,
      houseOfMentore: house,
      opzioniHouseOfMentore: opzioniHouse,
      partecipazioniHouseOfMentore: partecipazioniHouse,
      anagrafiche: persone[0],
      riservati: persone[1],
      ruoli: persone[2],
    );
  }

  /// Aggiorna un insegnamento.
  Future<void> aggiornaInsegnamento(
    String id,
    Map<String, dynamic> valori,
  ) async {
    await db.tabella('insegnamenti').aggiorna(
      valori,
      filtri: <FiltroDb>[
        FiltroDb.uguale('id', id),
      ],
      colonne: 'id',
    );
  }

  /// Aggiorna un mentoraggio tramite la RPC di backoffice.
  Future<void> aggiornaMentoraggio(
    String id,
    Map<String, dynamic> valori,
  ) async {
    await db.rpc(
      'mentoraggio_aggiorna_backoffice',
      parametri: <String, dynamic>{
        'p_mentoraggio_id': id,
        'p_valori': valori,
      },
    );
  }

  /// Carica assegnazioni, persone e stato attivo per la gestione del team.
  Future<List<dynamic>> caricaDatiTeam(String mentoraggioId) =>
      Future.wait<dynamic>([
        db.tabella('mentoraggio_mentori').elenco(
          filtri: <FiltroDb>[
            FiltroDb.uguale('mentoraggio_id', mentoraggioId),
          ],
        ),
        db.tabella('anagrafica').elenco(
          ordinamenti: const <OrdineDb>[
            OrdineDb('email_unipa'),
          ],
        ),
        db.tabella('anagrafica_riservata').elenco(
          colonne: 'user_id, attivo',
        ),
      ]);

  Future<SchemaDatabase> caricaSchemaDatabase() =>
      SchemaDatabase.carica(database: db);

  Future<void> rimuoviAssegnazione({
    required String mentoraggioId,
    required Object mentoreId,
    required Object tipo,
  }) async {
    await db.tabella('mentoraggio_mentori').elimina(
      filtri: <FiltroDb>[
        FiltroDb.uguale('mentoraggio_id', mentoraggioId),
        FiltroDb.uguale('mentore_id', mentoreId),
        FiltroDb.uguale('tipo', tipo),
      ],
    );
  }

  Future<void> aggiungiAssegnazione(
    Map<String, dynamic> valori,
  ) async {
    await db.tabella('mentoraggio_mentori').inserisci(
      valori,
      colonne: 'mentoraggio_id',
    );
  }

  /// Restituisce un URL temporaneo per la scheda di sintesi.
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

  Future<List<PartecipanteAnnoControllo>> _costruisciPartecipanti(
    String anno,
  ) async {
    final dati = await caricaDatiAnno(anno);

    final insegnamentiPerId = <String, Map<String, dynamic>>{
      for (final riga in dati.insegnamenti)
        if (riga['id'] != null)
          riga['id'].toString(): riga,
    };

    final eventiPerId = <String, Map<String, dynamic>>{
      for (final riga in dati.eventi)
        if (riga['id'] != null)
          riga['id'].toString(): riga,
    };

    final housePerId = <String, Map<String, dynamic>>{
      for (final riga in dati.houseOfMentore)
        if (riga['id'] != null)
          riga['id'].toString(): riga,
    };

    final persone = <String, Map<String, dynamic>>{
      for (final persona in dati.anagrafiche)
        if (persona['user_id'] != null)
          persona['user_id'].toString(): persona,
    };

    String nomePersona(String? id) {
      if (!_valido(id)) return '—';

      final persona = persone[id];
      if (persona == null) return id!;

      final nome =
          '${persona['cognome'] ?? ''} ${persona['nome'] ?? ''}'.trim();

      if (nome.isNotEmpty) return nome;
      return persona['email_unipa']?.toString() ?? id!;
    }

    final risultato = <PartecipanteAnnoControllo>[];

    for (final partecipanteId in persone.keys) {
      final mentee = <PercorsoMenteeControllo>[];
      final mentore = <PercorsoMentoreControllo>[];

      for (final mentoraggio in dati.mentoraggi) {
        final insegnamento = insegnamentiPerId[
          mentoraggio['insegnamento_id']?.toString()
        ];
        if (insegnamento == null) continue;

        final assegnati = dati.assegnazioni
            .where(
              (assegnazione) =>
                  assegnazione['mentoraggio_id']?.toString() ==
                  mentoraggio['id']?.toString(),
            )
            .toList(growable: false);

        final docenteId = insegnamento['docente_id']?.toString();

        if (docenteId == partecipanteId) {
          mentee.add(
            PercorsoMenteeControllo(
              insegnamento: _nomeInsegnamento(insegnamento),
              insegnamentoRiga: insegnamento,
              team: assegnati
                  .map(
                    (assegnazione) => MembroTeamControllo(
                      nome: nomePersona(
                        assegnazione['mentore_id']?.toString(),
                      ),
                      tipo:
                          assegnazione['tipo']?.toString() ?? '—',
                    ),
                  )
                  .toList(growable: false),
              mentoraggio: mentoraggio,
            ),
          );
        }

        final miaAssegnazione = assegnati
            .where(
              (assegnazione) =>
                  assegnazione['mentore_id']?.toString() ==
                  partecipanteId,
            )
            .firstOrNull;

        if (miaAssegnazione != null) {
          mentore.add(
            PercorsoMentoreControllo(
              insegnamento: _nomeInsegnamento(insegnamento),
              insegnamentoRiga: insegnamento,
              mentee: nomePersona(docenteId),
              mioTipo:
                  miaAssegnazione['tipo']?.toString() ?? '—',
              altriTeam: assegnati
                  .where(
                    (assegnazione) =>
                        assegnazione['mentore_id']?.toString() !=
                        partecipanteId,
                  )
                  .map(
                    (assegnazione) => MembroTeamControllo(
                      nome: nomePersona(
                        assegnazione['mentore_id']?.toString(),
                      ),
                      tipo:
                          assegnazione['tipo']?.toString() ?? '—',
                    ),
                  )
                  .toList(growable: false),
              mentoraggio: mentoraggio,
            ),
          );
        }
      }

      final eventi = dati.partecipazioniEventi
          .where(
            (riga) =>
                riga['partecipante_id']?.toString() ==
                partecipanteId,
          )
          .map(
            (riga) => PartecipazioneEventoControllo(
              titolo:
                  eventiPerId[riga['evento_id']?.toString()]
                          ?['titolo']
                      ?.toString() ??
                  riga['evento_id']?.toString() ??
                  '—',
              presente: riga['presente'] == true,
            ),
          )
          .toList(growable: false);

      final house = dati.partecipazioniHouseOfMentore
          .where(
            (riga) =>
                riga['partecipante_id']?.toString() ==
                partecipanteId,
          )
          .map(
            (riga) =>
                housePerId[riga['evento_id']?.toString()]
                        ?['titolo']
                    ?.toString() ??
                riga['evento_id']?.toString() ??
                '—',
          )
          .toList(growable: false);

      risultato.add(
        PartecipanteAnnoControllo(
          persona: persone[partecipanteId] ??
              <String, dynamic>{
                'user_id': partecipanteId,
              },
          mentee: mentee,
          mentore: mentore,
          eventi: eventi,
          houseOfMentore: house,
        ),
      );
    }

    risultato.sort((a, b) {
      final cognomeA =
          a.persona['cognome']?.toString().toLowerCase() ?? '';
      final cognomeB =
          b.persona['cognome']?.toString().toLowerCase() ?? '';

      final confronto = cognomeA.compareTo(cognomeB);
      if (confronto != 0) return confronto;

      final nomeA =
          a.persona['nome']?.toString().toLowerCase() ?? '';
      final nomeB =
          b.persona['nome']?.toString().toLowerCase() ?? '';

      return nomeA.compareTo(nomeB);
    });

    return risultato;
  }

  Future<List<Map<String, dynamic>>> _elencoPerIds({
    required String tabella,
    required String campo,
    required List<String> ids,
  }) {
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
}

List<String> _idsUnivoci(
  List<Map<String, dynamic>> righe,
  String campo,
) =>
    righe
        .map((riga) => riga[campo]?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty && id != 'null')
        .toSet()
        .toList(growable: false);

String _nomeInsegnamento(
  Map<String, dynamic> insegnamento,
) {
  final valore =
      insegnamento['insegnamento']?.toString().trim();

  return valore != null && valore.isNotEmpty
      ? valore
      : insegnamento['id']?.toString() ?? '—';
}

bool _valido(String? valore) =>
    valore != null &&
    valore.isNotEmpty &&
    valore != 'null';

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
