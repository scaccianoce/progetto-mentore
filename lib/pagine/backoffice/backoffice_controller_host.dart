import 'package:flutter/material.dart';

import '../../sessione_controller.dart';
import 'backoffice_controller.dart';

/// Ospita una singola pagina di backoffice che usa [BackofficeController].
/// Ogni voce del menu laterale e cosi una pagina autonoma, pur condividendo
/// lo stesso controller applicativo.
class BackofficeControllerHost extends StatefulWidget {
  const BackofficeControllerHost({
    super.key,
    required this.sessione,
    required this.builder,
  });

  final SessioneController sessione;
  final Widget Function(BuildContext context, BackofficeController controller)
      builder;

  @override
  State<BackofficeControllerHost> createState() => _BackofficeControllerHostState();
}

class _BackofficeControllerHostState extends State<BackofficeControllerHost> {
  late final BackofficeController controller;

  @override
  void initState() {
    super.initState();
    controller = BackofficeController(widget.sessione)..carica();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!(widget.sessione.ruolo?.puoAmministrare ?? false)) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.caricamento && controller.partecipanti.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errore != null && controller.partecipanti.isEmpty) {
          return Center(child: Text(controller.errore!));
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: widget.builder(context, controller),
        );
      },
    );
  }
}
