import 'package:flutter/material.dart';

import '../../ui/campo_questionario.dart';
import 'questionario_pubblico_compilazione_controller.dart';

/// Pagina pubblica anonima raggiunta tramite il link `/q/<token>`.
class QuestionarioPubblicoPage extends StatefulWidget {
  const QuestionarioPubblicoPage({super.key, required this.token});

  final String token;

  @override
  State<QuestionarioPubblicoPage> createState() =>
      _QuestionarioPubblicoPageState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _QuestionarioPubblicoPageState extends State<QuestionarioPubblicoPage> {
  late final QuestionarioPubblicoCompilazioneController controller;

  final Map<String, dynamic> risposte = <String, dynamic>{};

  /// Inizializza lo stato della pagina e avvia le operazioni iniziali necessarie.
  @override
  void initState() {
    super.initState();

    controller = QuestionarioPubblicoCompilazioneController()
      ..addListener(_ridisegna)
      ..carica(widget.token);
  }

  /// Richiede il ridisegno della pagina.
  void _ridisegna() {
    if (mounted) setState(() {});
  }

  /// Rilascia listener e controller associati allo stato della pagina.
  @override
  void dispose() {
    controller.removeListener(_ridisegna);
    controller.dispose();
    super.dispose();
  }

  /// Costruisce l’interfaccia grafica di questo componente.
  @override
  Widget build(BuildContext context) {
    if (controller.caricamento) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (controller.completato) {
      return const Scaffold(
        body: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 52),
                  SizedBox(height: 12),
                  Text('Grazie. Il questionario è stato inviato.'),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (controller.errore != null || controller.dati == null) {
      return Scaffold(
        body: Center(
          child: Text(controller.errore ?? 'Questionario non disponibile.'),
        ),
      );
    }

    final questionario = Map<String, dynamic>.from(
      controller.dati!['questionario'] as Map,
    );
    final domande = (controller.dati!['domande'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(questionario['titolo']?.toString() ?? 'Questionario'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if ((questionario['descrizione']?.toString() ?? '')
                  .isNotEmpty) ...[
                Text(questionario['descrizione'].toString()),
                const SizedBox(height: 20),
              ],
              for (final domanda in domande) ...[
                CampoQuestionario(
                  domanda: domanda,
                  valore: risposte[domanda['id'].toString()],
                  onChanged: (valore) => setState(
                    () => risposte[domanda['id'].toString()] = valore,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: controller.invio ? null : () => _invia(domande),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Invia questionario'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Gestisce l’operazione interna “invia” della pagina.
  Future<void> _invia(List<Map<String, dynamic>> domande) async {
    final erroreValidazione = validaRisposteQuestionario(domande, risposte);
    if (erroreValidazione != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(erroreValidazione)));
      return;
    }

    final errore = await controller.invia(widget.token, risposte);
    if (!mounted || errore == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errore)));
  }
}
