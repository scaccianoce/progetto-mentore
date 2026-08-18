import 'package:flutter/material.dart';

import 'notifiche_messaggi_backoffice_page.dart';
import 'notifiche_regole_backoffice_page.dart';

/// Gestione notifiche riservata a owner e organizer.
///
/// Il router/menu applicano il controllo di ruolo; le RLS DB devono mantenere
/// lo stesso vincolo lato server.
class NotificheBackofficePage extends StatelessWidget {
  const NotificheBackofficePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          minimum: EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              TabBar(
                tabs: <Widget>[
                  Tab(icon: Icon(Icons.notifications_outlined), text: 'Messaggi'),
                  Tab(icon: Icon(Icons.rule_outlined), text: 'Regole'),
                ],
              ),
              SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    NotificheMessaggiBackofficePage(),
                    NotificheRegoleBackofficePage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
