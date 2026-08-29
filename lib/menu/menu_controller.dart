import 'package:flutter/material.dart';

import '../app/app_core.dart';
import '../app/app_session_controller.dart';
import '../dati/repository.dart';

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

/// Configurazione statica delle voci di menu.
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
          percorso.startsWith(voce.percorso) &&
          voce.visibilePer(ruolo),
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

  /// Restituisce il percorso base del menu corrispondente alla route corrente.
  static String? percorsoMenu(String percorso) {
    for (final VoceMenu voce in voci) {
      if (percorso.startsWith(voce.percorso)) {
        return voce.percorso;
      }
    }
    return null;
  }
}

/// Stato dinamico dei pallini "nuovo" del menu.
///
/// Il badge numerico di `/notifiche` resta gestito dal sottosistema notifiche.
class MenuNovitaController extends ChangeNotifier {
  MenuNovitaController({
    required this.database,
  });

  final DatabaseRepository database;

  Map<String, bool> _novita = const <String, bool>{};
  bool _caricamento = false;
  String? _errore;

  bool get caricamento => _caricamento;
  String? get errore => _errore;

  bool nuova(String percorso) => _novita[percorso] == true;

  /// Ricarica in una sola RPC lo stato di tutte le voci monitorate.
  Future<void> carica() async {
      debugPrint('MENU NOVITA - userIdCorrente: ${database.userIdCorrente}',);
    if (database.userIdCorrente == null) {
      debugPrint('MENU NOVITA - nessun utente corrente',);
      _novita = const <String, bool>{};
      notifyListeners();
      return;
    }

    _caricamento = true;
    _errore = null;
    notifyListeners();

    try {
      final raw = await database.rpcMappa('menu_stato_novita');
      debugPrint('MENU NOVITA - risposta RPC: $raw',);

      _novita = <String, bool>{
        for (final voce in (raw ?? const <String, dynamic>{}).entries)
          voce.key: voce.value == true,
      };
      
      debugPrint('MENU NOVITA - mappa elaborata: $_novita',);

      debugPrint('MENU NOVITA - /insegnamento: '
      '${_novita['/insegnamento']}',);

    } catch (e) {
      debugPrint('MENU NOVITA - ERRORE: $e',);
      
      _errore = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile aggiornare gli indicatori del menu.',
      ).messaggio;
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  /// Registra che la sezione e' stata aperta e rimuove subito il pallino.
  Future<void> registraAccesso(String percorso) async {
    if (database.userIdCorrente == null) return;

    if (_novita[percorso] == true) {
      _novita = <String, bool>{
        ..._novita,
        percorso: false,
      };
      notifyListeners();
    }

    try {
      await database.rpc(
        'menu_registra_accesso',
        parametri: <String, dynamic>{
          'p_percorso': percorso,
        },
      );
    } catch (e) {
      _errore = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile registrare l’accesso alla sezione.',
      ).messaggio;
      notifyListeners();
    }
  }
}
