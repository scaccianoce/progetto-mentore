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

  static const List<VoceMenu> voci = <VoceMenu>[
    VoceMenu(
      titolo: 'News',
      icona: Icons.newspaper_outlined,
      percorso: '/news',
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
      titolo: 'Il mio insegnamento',
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
      titolo: 'Amministrazione',
      icona: Icons.admin_panel_settings_outlined,
      percorso: '/amministrazione',
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
