import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';
import '../supporto/notifiche_push_service.dart';
import 'app_session_controller.dart';

class MentoreApp extends StatefulWidget {
  const MentoreApp({super.key, this.erroreAvvio});

  final String? erroreAvvio;

  @override
  State<MentoreApp> createState() => _MentoreAppState();
}

class _MentoreAppState extends State<MentoreApp> {
  SessioneController? sessione;
  GoRouter? router;
  StreamSubscription<dynamic>? _notificheAperteSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.erroreAvvio == null) {
      sessione = SessioneController();
      unawaited(sessione!.inizializza());
      router = creaAppRouter(sessione!);

      _notificheAperteSubscription = NotifichePushService
          .instance
          .apertureNotifiche
          .listen((messaggio) {
            final percorso = NotifichePushService.instance.percorsoPer(
              messaggio,
            );
            router?.go(percorso);
          });
    }
  }

  @override
  void dispose() {
    _notificheAperteSubscription?.cancel();
    router?.dispose();
    sessione?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //final tema = ThemeData(
    //  useMaterial3: true,
    //  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
    //  inputDecorationTheme: const InputDecorationTheme(
    //    labelStyle: TextStyle(fontWeight: FontWeight.bold),
    //    floatingLabelStyle: TextStyle(fontWeight: FontWeight.bold),
    //  ),
    // );

    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1565C0),
      brightness: Brightness.light,
    );

    final tema = ThemeData(
      useMaterial3: true,
      colorScheme: base.copyWith(
        surface: const Color(0xFFF7F9FC),
        surfaceContainerLowest: const Color(0xFFFFFFFF),
        surfaceContainerLow: const Color(0xFFF1F5FB),
        surfaceContainer: const Color(0xFFE9F0FA),
        surfaceContainerHigh: const Color(0xFFE1EBF8),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFF1F5FB),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFD7E3F4)),
        ),
      ),
      dialogTheme: const DialogThemeData(backgroundColor: Color(0xFFFBFDFF)),
    );

    if (widget.erroreAvvio != null) {
      return MaterialApp(
        title: 'Progetto Mentore per la Didattica',
        debugShowCheckedModeBanner: false,
        theme: tema,
        home: SelectionArea(
          child: _PaginaErroreAvvio(messaggio: widget.erroreAvvio!),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Progetto Mentore per la Didattica',
      debugShowCheckedModeBanner: false,
      theme: tema,
      routerConfig: router!,
    );
  }
}

class _PaginaErroreAvvio extends StatelessWidget {
  const _PaginaErroreAvvio({required this.messaggio});

  final String messaggio;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.cloud_off_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 20),
                Text(
                  'Impossibile avviare l’app',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(messaggio, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
