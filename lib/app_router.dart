import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'menu_controller.dart';
import 'menu_page.dart';
import 'pagine/backoffice/anni_accademici_backoffice_page.dart';
import 'pagine/backoffice/backoffice_controller_host.dart';
import 'pagine/backoffice/controllo_partecipanti_backoffice_page.dart';
import 'pagine/backoffice/database_backoffice_page.dart';
import 'pagine/backoffice/insegnamenti_backoffice_page.dart';
import 'pagine/backoffice/notifiche_backoffice_page.dart';
import 'pagine/backoffice/partecipanti_backoffice_page.dart';
import 'pagine/backoffice/questionari_backoffice_page.dart';
import 'pagine/backoffice/questionari_controller.dart';
import 'pagine/contatti/contatti_page.dart';
import 'pagine/eventi/eventi_page.dart';
import 'pagine/house_of_mentore/house_of_mentore_page.dart';
import 'pagine/insegnamento/insegnamento_page.dart';
import 'pagine/login/login_page.dart';
import 'pagine/news/news_page.dart';
import 'pagine/notifiche/notifiche_page.dart';
import 'pagine/profilo/profilo_page.dart';
import 'pagine/ruolo_mentee/mentee_page.dart';
import 'pagine/ruolo_mentore/mentore_page.dart';
import 'sessione_controller.dart';

GoRouter creaAppRouter(SessioneController sessione) => GoRouter(
  initialLocation: '/news',
  refreshListenable: sessione,
  redirect: (BuildContext context, GoRouterState stato) {
    final login = stato.uri.path == '/login';
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
      builder: (context, state) => SelectionArea(
        child: LoginPage(sessione: sessione),
      ),
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
        GoRoute(
          path: '/notifiche',
          builder: (_, _) => const NotifichePage(),
        ),
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
          builder: (_, _) => BackofficeControllerHost(
            sessione: sessione,
            builder: (_, controller) =>
                PartecipantiBackofficePage(controller: controller),
          ),
        ),
        GoRoute(
          path: '/gestione/insegnamenti',
          builder: (_, state) => BackofficeControllerHost(
            sessione: sessione,
            builder: (_, controller) => InsegnamentiBackofficePage(
              controller: controller,
              docenteIdIniziale: state.uri.queryParameters['docente'],
            ),
          ),
        ),
        GoRoute(
          path: '/gestione/anni-accademici',
          builder: (_, _) => BackofficeControllerHost(
            sessione: sessione,
            builder: (_, controller) =>
                AnniAccademiciBackofficePage(controller: controller),
          ),
        ),
        GoRoute(
          path: '/gestione/controllo-partecipanti',
          builder: (_, _) => const ControlloPartecipantiBackofficePage(),
        ),
        GoRoute(
          path: '/gestione/questionari',
          builder: (_, _) {
            final controller =
                QuestionariController(sessione);
            controller.carica();
            return QuestionariBackofficePage(
              controller: controller,
            );
          },
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
