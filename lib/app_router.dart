import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'menu_controller.dart';
import 'menu_page.dart';
import 'pagine/amministrazione/amministrazione_page.dart';
import 'pagine/contatti/contatti_page.dart';
import 'pagine/eventi/eventi_page.dart';
import 'pagine/house_of_mentore/house_of_mentore_page.dart';
import 'pagine/insegnamento/insegnamento_page.dart';
import 'pagine/login/login_page.dart';
import 'pagine/news/news_page.dart';
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
      builder: (context, state) => LoginPage(sessione: sessione),
    ),
    ShellRoute(
      builder: (context, state, child) =>
          MenuPage(sessione: sessione, contenuto: child),
      routes: <RouteBase>[
        GoRoute(path: '/', redirect: (_, _) => '/news'),
        GoRoute(
          path: '/news',
          builder: (_, _) => NewsPage(sessione: sessione),
        ),
        GoRoute(
          path: '/profilo',
          builder: (_, _) => ProfiloPage(sessione: sessione),
        ),
        GoRoute(
          path: '/insegnamento',
          builder: (_, _) => InsegnamentoPage(sessione: sessione),
        ),
        GoRoute(path: '/mentee', builder: (_, _) => const MenteePage()),
        GoRoute(path: '/mentore', builder: (_, _) => const MentorePage()),
        GoRoute(
          path: '/eventi',
          builder: (_, _) => EventiPage(sessione: sessione),
        ),
        GoRoute(
          path: '/house-of-mentore',
          builder: (_, _) => HouseOfMentorePage(sessione: sessione),
        ),
        GoRoute(path: '/contatti', builder: (_, _) => const ContattiPage()),
        GoRoute(
          path: '/amministrazione',
          builder: (_, _) => AmministrazionePage(sessione: sessione),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Pagina non trovata: ${state.uri.path}')),
  ),
);
