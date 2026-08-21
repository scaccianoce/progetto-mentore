import '../../supabase_config.dart';

/// Pacchetto coerente di dati relativi a un singolo anno accademico.
///
/// La relazione annuale parte SEMPRE da `mentoraggi.anno_accademico`.
/// `insegnamenti` non contiene piu l'anno accademico: gli insegnamenti
/// vengono recuperati attraverso `mentoraggi.insegnamento_id`.
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

  static Future<BackofficeDatiAnno> carica(
    String anno, {
    bool caricaAnagrafiche = true,
  }) async {
    final db = SupabaseConfig.client;

    // L'anno accademico appartiene al mentoraggio, non all'insegnamento.
    final risultatiPrincipali = await Future.wait<dynamic>([
      db.from('mentoraggi').select().eq('anno_accademico', anno),
      db.from('eventi').select().eq('anno_accademico', anno),
      db.from('house_of_mentore').select().eq('anno_accademico', anno),
      db.from('partecipazioni_annuali').select().eq('anno_accademico', anno),
    ]);

    final mentoraggi = _mappe(risultatiPrincipali[0]);
    final eventi = _mappe(risultatiPrincipali[1]);
    final hom = _mappe(risultatiPrincipali[2]);
    final partecipazioniAnnuali = _mappe(risultatiPrincipali[3]);

    final insegnamentoIds = _ids(mentoraggi, 'insegnamento_id');
    final mentoraggioIds = _ids(mentoraggi, 'id');
    final eventoIds = _ids(eventi, 'id');
    final homIds = _ids(hom, 'id');

    final risultatiCollegati = await Future.wait<dynamic>([
      insegnamentoIds.isEmpty
          ? Future.value(<Map<String, dynamic>>[])
          : db.from('insegnamenti').select().inFilter('id', insegnamentoIds),
      mentoraggioIds.isEmpty
          ? Future.value(<Map<String, dynamic>>[])
          : db
              .from('mentoraggio_mentori')
              .select()
              .inFilter('mentoraggio_id', mentoraggioIds),
      eventoIds.isEmpty
          ? Future.value(<Map<String, dynamic>>[])
          : db
              .from('partecipazioni_eventi')
              .select()
              .inFilter('evento_id', eventoIds),
      homIds.isEmpty
          ? Future.value(<Map<String, dynamic>>[])
          : db
              .from('house_of_mentore_opzioni')
              .select()
              .inFilter('evento_id', homIds),
      homIds.isEmpty
          ? Future.value(<Map<String, dynamic>>[])
          : db
              .from('partecipazioni_house_of_mentore')
              .select()
              .inFilter('evento_id', homIds),
    ]);

    final insegnamenti = _mappe(risultatiCollegati[0]);
    final assegnazioni = _mappe(risultatiCollegati[1]);
    final partecipazioniEventi = _mappe(risultatiCollegati[2]);
    final opzioniHom = _mappe(risultatiCollegati[3]);
    final partecipazioniHom = _mappe(risultatiCollegati[4]);

    if (!caricaAnagrafiche) {
      return BackofficeDatiAnno(
        anno: anno,
        mentoraggi: mentoraggi,
        insegnamenti: insegnamenti,
        assegnazioni: assegnazioni,
        eventi: eventi,
        partecipazioniEventi: partecipazioniEventi,
        partecipazioniAnnuali: partecipazioniAnnuali,
        houseOfMentore: hom,
        opzioniHouseOfMentore: opzioniHom,
        partecipazioniHouseOfMentore: partecipazioniHom,
        anagrafiche: const [],
        riservati: const [],
        ruoli: const [],
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
      ...partecipazioniHom
          .map((r) => r['partecipante_id']?.toString())
          .whereType<String>(),
      ...partecipazioniAnnuali
          .map((r) => r['user_id']?.toString())
          .whereType<String>(),
    }..removeWhere((v) => v.isEmpty || v == 'null');

    final ids = partecipanteIds.toList();
    final risultatiPersone = ids.isEmpty
        ? <dynamic>[
            <Map<String, dynamic>>[],
            <Map<String, dynamic>>[],
            <Map<String, dynamic>>[],
          ]
        : await Future.wait<dynamic>([
            db.from('anagrafica').select().inFilter('user_id', ids),
            db.from('anagrafica_riservata').select().inFilter('user_id', ids),
            db.from('user_roles').select().inFilter('user_id', ids),
          ]);

    return BackofficeDatiAnno(
      anno: anno,
      mentoraggi: mentoraggi,
      insegnamenti: insegnamenti,
      assegnazioni: assegnazioni,
      eventi: eventi,
      partecipazioniEventi: partecipazioniEventi,
      partecipazioniAnnuali: partecipazioniAnnuali,
      houseOfMentore: hom,
      opzioniHouseOfMentore: opzioniHom,
      partecipazioniHouseOfMentore: partecipazioniHom,
      anagrafiche: _mappe(risultatiPersone[0]),
      riservati: _mappe(risultatiPersone[1]),
      ruoli: _mappe(risultatiPersone[2]),
    );
  }

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

List<String> _ids(List<Map<String, dynamic>> righe, String campo) => righe
    .map((r) => r[campo]?.toString())
    .whereType<String>()
    .where((v) => v.isNotEmpty && v != 'null')
    .toSet()
    .toList();

List<Map<String, dynamic>> _mappe(dynamic valore) {
  if (valore is! List) return const <Map<String, dynamic>>[];
  return valore
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
}
