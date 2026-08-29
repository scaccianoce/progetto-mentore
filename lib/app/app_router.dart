import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../menu/menu_controller.dart';
import '../menu/menu_page.dart';
import '../pagine/backoffice/anni_accademici/anni_accademici_backoffice_page.dart';
import '../pagine/backoffice/controllo_partecipanti/controllo_partecipanti_backoffice_page.dart';
import '../pagine/backoffice/database/database_backoffice_page.dart';
import '../pagine/backoffice/insegnamenti/insegnamenti_backoffice_page.dart';
import '../pagine/backoffice/notifiche/notifiche_backoffice_page.dart';
import '../pagine/backoffice/partecipanti/partecipanti_backoffice_page.dart';
import '../pagine/backoffice/questionari/questionari_backoffice_page.dart';
import '../pagine/backoffice/questionari/questionari_backoffice_controller.dart';
import '../pagine/questionari/questionario_pubblico_page.dart';
import '../pagine/contatti/contatti_page.dart';
import '../pagine/eventi/eventi_page.dart';
import '../pagine/house_of_mentore/house_of_mentore_page.dart';
import '../pagine/mentoraggio/insegnamenti/insegnamento_page.dart';
import '../pagine/login/login_page.dart';
import '../pagine/news/news_page.dart';
import '../pagine/notifiche/notifiche_page.dart';
import '../pagine/profilo/profilo_page.dart';
import '../pagine/mentoraggio/ruolo_mentee/mentee_page.dart';
import '../pagine/mentoraggio/ruolo_mentore/mentore_page.dart';
import '../pagine/mentoraggio/risorse/risorse_mentoring_page.dart';
import 'app_session_controller.dart';

GoRouter creaAppRouter(SessioneController sessione) => GoRouter(
  initialLocation: '/news',
  refreshListenable: sessione,
  redirect: (BuildContext context, GoRouterState stato) {
    final path = stato.uri.path;
    final login = path == '/login';

    // La compilazione del questionario pubblico non richiede
    // sessione, ruolo o menu autenticato.
    if (path == '/q' || path.startsWith('/q/')) return null;
    if (!sessione.autenticato) return login ? null : '/login';
    if (!sessione.pronto) return null;
    if (login) return '/news';
    final ruolo = sessione.ruolo;
    if (ruolo != null &&
        stato.uri.path != '/' &&
        !AppMenuController.puoAprire(stato.uri.path, ruolo)) {
      return '/news';
    }
    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/login',
      builder: (context, state) =>
          SelectionArea(child: LoginPage(sessione: sessione)),
    ),
    GoRoute(
      path: '/q/:token',
      builder: (_, state) =>
          QuestionarioPubblicoPage(token: state.pathParameters['token'] ?? ''),
    ),
    ShellRoute(
      builder: (context, state, child) => SelectionArea(
        child: MenuPage(sessione: sessione, contenuto: child),
      ),
      routes: <RouteBase>[
        GoRoute(path: '/', redirect: (_, _) => '/news'),
        GoRoute(
          path: '/news',
          builder: (_, _) => NewsPage(sessione: sessione),
        ),
        GoRoute(path: '/notifiche', builder: (_, _) => const NotifichePage()),
        GoRoute(
          path: '/profilo',
          builder: (_, _) => ProfiloPage(sessione: sessione),
        ),
        GoRoute(
          path: '/insegnamento',
          builder: (_, _) => InsegnamentoPage(sessione: sessione),
        ),
        GoRoute(
          path: '/mentee',
          builder: (_, _) => MenteePage(sessione: sessione),
        ),
        GoRoute(
          path: '/mentore',
          builder: (_, _) => MentorePage(sessione: sessione),
        ),
        GoRoute(
          path: '/risorse-mentoring',
          builder: (_, _) => RisorseMentoringPage(sessione: sessione),
        ),
        GoRoute(
          path: '/eventi',
          builder: (_, _) => EventiPage(sessione: sessione),
        ),
        GoRoute(
          path: '/house-of-mentore',
          builder: (_, _) => HouseOfMentorePage(sessione: sessione),
        ),
        GoRoute(
          path: '/contatti',
          builder: (_, _) => ContattiPage(sessione: sessione),
        ),
        GoRoute(
          path: '/gestione/database',
          builder: (_, _) => DatabaseBackofficePage(sessione: sessione),
        ),
        GoRoute(
          path: '/gestione/partecipanti',
          builder: (_, _) => PartecipantiBackofficePage(sessione: sessione),
        ),
        GoRoute(
          path: '/gestione/insegnamenti',
          builder: (_, state) => InsegnamentiBackofficePage(
            sessione: sessione,
            docenteIdIniziale: state.uri.queryParameters['docente'],
          ),
        ),
        GoRoute(
          path: '/gestione/anni-accademici',
          builder: (_, _) => AnniAccademiciBackofficePage(sessione: sessione),
        ),
        GoRoute(
          path: '/gestione/controllo-partecipanti',
          builder: (_, _) => const ControlloPartecipantiBackofficePage(),
        ),
        GoRoute(
          path: '/gestione/questionari',
          builder: (_, _) => QuestionariBackofficePage(
            controller: QuestionariBackofficeController(sessione)
              ..carica(),
          ),
        ),
        GoRoute(
          path: '/gestione/notifiche',
          builder: (_, _) => const NotificheBackofficePage(),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => SelectionArea(
    child: Scaffold(
      body: Center(child: Text('Pagina non trovata: ${state.uri.path}')),
    ),
  ),
);
