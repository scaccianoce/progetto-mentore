import 'package:flutter/material.dart';

import '../supporto/questionario_risultati_controller.dart';

/// Card UI per caricare e mostrare i risultati aggregati di un questionario.
class QuestionarioRisultatiCard extends StatefulWidget {
  const QuestionarioRisultatiCard({
    super.key,
    required this.controller,
    required this.questionario,
    this.consentiExport = true,
  });

  final QuestionarioRisultatiController controller;
  final Map<String, dynamic> questionario;
  final bool consentiExport;

  @override
  State<QuestionarioRisultatiCard> createState() =>
      _QuestionarioRisultatiCardState();
}

class _QuestionarioRisultatiCardState extends State<QuestionarioRisultatiCard> {
  Map<String, dynamic>? dati;
  bool caricamento = false;
  String? errore;

  Future<void> _carica() async {
    if (dati != null || caricamento) return;
    setState(() => caricamento = true);
    try {
      final risultato = await widget.controller.caricaRisultatiQuestionario(
        widget.questionario['id'].toString(),
      );
      if (!mounted) return;
      setState(() {
        dati = risultato;
        caricamento = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errore = e.toString();
        caricamento = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ExpansionTile(
      onExpansionChanged: (aperto) {
        if (aperto) _carica();
      },
      leading: const Icon(Icons.analytics_outlined),
      title: Text(widget.questionario['titolo']?.toString() ?? 'Questionario'),
      subtitle: Text(
        widget.questionario['provider']?.toString() == 'pubblico'
            ? 'Studenti'
            : 'Evento',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (caricamento) const LinearProgressIndicator(),
        if (errore != null) Text(errore!),
        if (dati != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Compilazioni: ${dati!['numero_compilazioni']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          for (final riga
              in (dati!['sintesi'] as List).cast<Map<String, dynamic>>())
            _sintesi(riga),
          if (widget.consentiExport) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final errore = await widget.controller.esportaCsvRisultati(
                    widget.questionario['id'].toString(),
                  );
                  if (!context.mounted || errore == null) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(errore)));
                },
                icon: const Icon(Icons.download_outlined),
                label: const Text('Esporta CSV'),
              ),
            ),
          ],
        ],
      ],
    ),
  );

  Widget _sintesi(Map<String, dynamic> riga) {
    final tipo = riga['tipo']?.toString() ?? '';
    String dettaglio;
    if (tipo == 'scala') {
      final media = riga['media'] as double?;
      dettaglio = media == null
          ? 'Nessuna risposta'
          : 'Media ${media.toStringAsFixed(2)} · ${riga['numero_risposte']} risposte';
    } else if (tipo == 'booleano' || tipo == 'scelta_singola') {
      final frequenze = Map<String, dynamic>.from(
        riga['frequenze'] as Map? ?? const {},
      );
      dettaglio = frequenze.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(' · ');
      if (dettaglio.isEmpty) dettaglio = 'Nessuna risposta';
    } else {
      dettaglio = '${riga['numero_risposte'] ?? 0} risposte testuali';
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(riga['testo']?.toString() ?? ''),
      subtitle: Text(dettaglio),
    );
  }
}
