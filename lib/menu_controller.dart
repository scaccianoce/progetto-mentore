import 'package:flutter/material.dart';

import 'sessione_controller.dart';

enum MenuSezione {
  news(''),
  personale('PERSONALE'),
  mentoraggio('MENTORAGGIO'),
  comunita('COMUNITÀ'),
  gestione('GESTIONE');

  const MenuSezione(this.titolo);

  final String titolo;
}

class VoceMenu {
  const VoceMenu({
    required this.titolo,
    required this.icona,
    required this.percorso,
    required this.sezione,
    required this.ruoli,
  });

  final String titolo;
  final IconData icona;
  final String percorso;
  final MenuSezione sezione;
  final Set<AppRole> ruoli;

  bool visibilePer(AppRole ruolo) => ruoli.contains(ruolo);
}

abstract final class AppMenuController {
  static const Set<AppRole> _tutti = <AppRole>{
    AppRole.participant,
    AppRole.organizer,
    AppRole.owner,
  };

  static const Set<AppRole> _amministratori = <AppRole>{
    AppRole.organizer,
    AppRole.owner,
  };

  static const Set<AppRole> _soloOwner = <AppRole>{AppRole.owner};

  static const List<VoceMenu> voci = <VoceMenu>[
    VoceMenu(
      titolo: 'News',
      icona: Icons.newspaper_outlined,
      percorso: '/news',
      sezione: MenuSezione.news,
      ruoli: _tutti,
    ),
    VoceMenu(
      titolo: 'Notifiche',
      icona: Icons.notifications_none_outlined,
      percorso: '/notifiche',
      sezione: MenuSezione.news,
      ruoli: _tutti,
    ),
    VoceMenu(
      titolo: 'Il mio profilo',
      icona: Icons.person_outline,
      percorso: '/profilo',
      sezione: MenuSezione.personale,
      ruoli: _tutti,
    ),
    VoceMenu(
      titolo: 'I miei insegnamenti',
      icona: Icons.menu_book_outlined,
      percorso: '/insegnamento',
      sezione: MenuSezione.personale,
      ruoli: _tutti,
    ),
    VoceMenu(
      titolo: 'Ruolo mentee',
      icona: Icons.school_outlined,
      percorso: '/mentee',
      sezione: MenuSezione.mentoraggio,
      ruoli: _tutti,
    ),
    VoceMenu(
      titolo: 'Ruolo mentore',
      icona: Icons.groups_outlined,
      percorso: '/mentore',
      sezione: MenuSezione.mentoraggio,
      ruoli: _tutti,
    ),
    VoceMenu(
      titolo: 'Risorse per il mentoring',
      icona: Icons.folder_copy_outlined,
      percorso: '/risorse-mentoring',
      sezione: MenuSezione.mentoraggio,
      ruoli: _tutti,
    ),
    VoceMenu(
      titolo: 'Eventi',
      icona: Icons.event_outlined,
      percorso: '/eventi',
      sezione: MenuSezione.comunita,
      ruoli: _tutti,
    ),
    VoceMenu(
      titolo: 'House of Mentore',
      icona: Icons.home_outlined,
      percorso: '/house-of-mentore',
      sezione: MenuSezione.comunita,
      ruoli: _tutti,
    ),
    VoceMenu(
      titolo: 'Contatti',
      icona: Icons.contacts_outlined,
      percorso: '/contatti',
      sezione: MenuSezione.comunita,
      ruoli: _tutti,
    ),
    VoceMenu(
      titolo: 'Database',
      icona: Icons.storage_outlined,
      percorso: '/gestione/database',
      sezione: MenuSezione.gestione,
      ruoli: _soloOwner,
    ),
    VoceMenu(
      titolo: 'Partecipanti',
      icona: Icons.people_outline,
      percorso: '/gestione/partecipanti',
      sezione: MenuSezione.gestione,
      ruoli: _amministratori,
    ),
    VoceMenu(
      titolo: 'Insegnamenti',
      icona: Icons.menu_book_outlined,
      percorso: '/gestione/insegnamenti',
      sezione: MenuSezione.gestione,
      ruoli: _amministratori,
    ),
    VoceMenu(
      titolo: 'Anni accademici',
      icona: Icons.calendar_month_outlined,
      percorso: '/gestione/anni-accademici',
      sezione: MenuSezione.gestione,
      ruoli: _amministratori,
    ),
    VoceMenu(
      titolo: 'Controllo partecipanti',
      icona: Icons.fact_check_outlined,
      percorso: '/gestione/controllo-partecipanti',
      sezione: MenuSezione.gestione,
      ruoli: _amministratori,
    ),
    VoceMenu(
      titolo: 'Notifiche',
      icona: Icons.notifications_outlined,
      percorso: '/gestione/notifiche',
      sezione: MenuSezione.gestione,
      ruoli: _amministratori,
    ),
    VoceMenu(
      titolo: 'Questionari',
      icona: Icons.quiz_outlined,
      percorso: '/gestione/questionari',
      sezione: MenuSezione.gestione,
      ruoli: _amministratori,
    ),
  ];

  static List<VoceMenu> vociPerRuolo(AppRole ruolo) {
    return voci
        .where((VoceMenu voce) => voce.visibilePer(ruolo))
        .toList(growable: false);
  }

  static bool puoAprire(String percorso, AppRole ruolo) {
    return voci.any(
      (VoceMenu voce) =>
          percorso.startsWith(voce.percorso) && voce.visibilePer(ruolo),
    );
  }

  static String titoloPercorso(String percorso, AppRole ruolo) {
    for (final VoceMenu voce in vociPerRuolo(ruolo)) {
      if (percorso.startsWith(voce.percorso)) {
        return voce.titolo;
      }
    }
    return 'Progetto Mentore per la Didattica';
  }
}
