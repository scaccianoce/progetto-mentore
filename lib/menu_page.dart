import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'menu_controller.dart';
import 'sessione_controller.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key, required this.contenuto, required this.sessione});

  final Widget contenuto;
  final SessioneController sessione;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sessione,
      builder: (BuildContext context, Widget? child) {
        final AppRole ruolo = sessione.ruolo ?? AppRole.participant;
        final String percorso = GoRouterState.of(context).uri.path;
        final List<VoceMenu> voci = AppMenuController.vociPerRuolo(ruolo);

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool desktop = constraints.maxWidth >= 900;

            if (desktop) {
              return Scaffold(
                body: SafeArea(
                  minimum: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 270,
                        child: _PannelloMenu(
                          voci: voci,
                          percorso: percorso,
                          sessione: sessione,
                          chiudiPrimaDiNavigare: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: child!),
                    ],
                  ),
                ),
              );
            }

            return Scaffold(
              appBar: AppBar(
                title: Text(AppMenuController.titoloPercorso(percorso, ruolo)),
              ),
              drawer: SafeArea(
                minimum: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                child: Drawer(
                  child: _PannelloMenu(
                    voci: voci,
                    percorso: percorso,
                    sessione: sessione,
                    chiudiPrimaDiNavigare: true,
                  ),
                ),
              ),
              body: child,
            );
          },
        );
      },
      child: contenuto,
    );
  }
}

class _PannelloMenu extends StatelessWidget {
  const _PannelloMenu({
    required this.voci,
    required this.percorso,
    required this.sessione,
    required this.chiudiPrimaDiNavigare,
  });

  final List<VoceMenu> voci;
  final String percorso;
  final SessioneController sessione;
  final bool chiudiPrimaDiNavigare;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  child: const Icon(Icons.school_outlined),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Progetto Mentore\nper la Didattica',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _creaVoci(context),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (sessione.utente?.email case final String email)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: sessione.caricamento
                      ? null
                      : () async {
                          if (chiudiPrimaDiNavigare) {
                            Navigator.of(context).pop();
                          }
                          await sessione.esci();
                        },
                  icon: const Icon(Icons.logout),
                  label: const Text('Esci'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _creaVoci(BuildContext context) {
    final List<Widget> elementi = <Widget>[];
    MenuSezione? sezionePrecedente;

    for (final VoceMenu voce in voci) {
      if (voce.sezione != sezionePrecedente) {
        sezionePrecedente = voce.sezione;
        if (voce.sezione.titolo.isNotEmpty) {
          elementi.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
              child: Text(
                voce.sezione.titolo,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          );
        }
      }

      elementi.add(
        ListTile(
          leading: Icon(voce.icona),
          title: Text(voce.titolo),
          selected: percorso.startsWith(voce.percorso),
          onTap: () {
            if (chiudiPrimaDiNavigare) {
              Navigator.of(context).pop();
            }
            context.go(voce.percorso);
          },
        ),
      );
    }

    return elementi;
  }
}
