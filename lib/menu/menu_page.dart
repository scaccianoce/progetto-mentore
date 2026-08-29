import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_core.dart';
import '../app/app_session_controller.dart';
import '../supporto/notifiche_push_service.dart';
import 'menu_controller.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({
    super.key,
    required this.contenuto,
    required this.sessione,
  });

  final Widget contenuto;
  final SessioneController sessione;

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> 
    with WidgetsBindingObserver{
  late final MenuNovitaController _novitaController;
  
  Timer? _timerNovita;

  String? _ultimoPercorsoRegistrato;
  
@override
void initState() {
  super.initState();

  WidgetsBinding.instance.addObserver(this);

  _novitaController = MenuNovitaController(
    database: widget.sessione.db,
  );

  unawaited(_novitaController.carica());

  NotifichePushService.instance.aggiornamenti.addListener(
    _aggiornaNovita,
  );

  _timerNovita = Timer.periodic(
    const Duration(seconds: 30),
    (_) {
      if (!mounted) return;

      unawaited(_novitaController.carica());
    },
  );
}


  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_novitaController.carica());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final percorsoCorrente = GoRouterState.of(context).uri.path;
    final percorsoMenu = AppMenuController.percorsoMenu(
      percorsoCorrente,
    );

    if (percorsoMenu == null ||
        percorsoMenu == _ultimoPercorsoRegistrato) {
      return;
    }

    _ultimoPercorsoRegistrato = percorsoMenu;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      unawaited(
        _novitaController
            .registraAccesso(percorsoMenu)
            .then((_) => _novitaController.carica()),
      );
    });
  }

  @override
  void dispose() {
    _timerNovita?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    NotifichePushService.instance.aggiornamenti.removeListener(
      _aggiornaNovita,
    );
    _novitaController.dispose();
    super.dispose();
  }

  void _aggiornaNovita() {
    unawaited(_novitaController.carica());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
        <Listenable>[
          widget.sessione,
          _novitaController,
        ],
      ),
      builder: (BuildContext context, Widget? child) {
        final AppRole ruolo =
            widget.sessione.ruolo ?? AppRole.participant;
        final String percorso =
            GoRouterState.of(context).uri.path;
        final List<VoceMenu> voci =
            AppMenuController.vociPerRuolo(ruolo);

        return LayoutBuilder(
          builder: (
            BuildContext context,
            BoxConstraints constraints,
          ) {
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
                          sessione: widget.sessione,
                          novitaController: _novitaController,
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
                title: Text(
                  AppMenuController.titoloPercorso(
                    percorso,
                    ruolo,
                  ),
                ),
              ),
              drawer: SafeArea(
                minimum:
                    const EdgeInsets.fromLTRB(8, 8, 8, 12),
                child: Drawer(
                  child: _PannelloMenu(
                    voci: voci,
                    percorso: percorso,
                    sessione: widget.sessione,
                    novitaController: _novitaController,
                    chiudiPrimaDiNavigare: true,
                  ),
                ),
              ),
              body: child,
            );
          },
        );
      },
      child: widget.contenuto,
    );
  }
}

class _PannelloMenu extends StatelessWidget {
  const _PannelloMenu({
    required this.voci,
    required this.percorso,
    required this.sessione,
    required this.novitaController,
    required this.chiudiPrimaDiNavigare,
  });

  final List<VoceMenu> voci;
  final String percorso;
  final SessioneController sessione;
  final MenuNovitaController novitaController;
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
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Image.asset(
                    AppBranding.logoAssetWOtext,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Progetto Mentore\nper la Didattica',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(vertical: 8),
              children: _creaVoci(context),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
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
              padding:
                  const EdgeInsets.fromLTRB(16, 18, 16, 6),
              child: Text(
                voce.sezione.titolo,
                style:
                    Theme.of(context).textTheme.labelMedium,
              ),
            ),
          );
        }
      }

      elementi.add(
        ListTile(
          leading: Icon(voce.icona),
          title: Text(voce.titolo),
          trailing: _trailingVoce(context, voce),
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

  Widget? _trailingVoce(
    BuildContext context,
    VoceMenu voce,
  ) {
    if (voce.percorso == '/notifiche') {
      return const _NotificheBadge();
    }

    if (!novitaController.nuova(voce.percorso)) {
      return null;
    }

    return const _NuovoPallino();
  }
}

// ============================================================================
// BADGE NOTIFICHE NON LETTE
// ============================================================================

class _NotificheBadge extends StatelessWidget {
  const _NotificheBadge();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable:
          NotifichePushService.instance.nonLette,
      builder: (context, nonLette, _) {
        if (nonLette <= 0) {
          return const SizedBox.shrink();
        }

        return Badge(
          label: Text(
            nonLette > 99 ? '99+' : '$nonLette',
          ),
        );
      },
    );
  }
}

// ============================================================================
// INDICATORE NUOVO CONTENUTO
// ============================================================================

class _NuovoPallino extends StatelessWidget {
  const _NuovoPallino();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Nuovo contenuto',
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
