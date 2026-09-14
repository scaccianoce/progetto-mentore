import 'package:flutter/material.dart';

import 'campo_questionario.dart';

class QuestionarioInternoDialog extends StatefulWidget {
  const QuestionarioInternoDialog({
    super.key,
    required this.eventoId,
    required this.caricaQuestionario,
    required this.inviaQuestionario,
  });

  final String eventoId;
  final Future<Map<String, dynamic>?> Function(String eventoId)
  caricaQuestionario;
  final Future<String?> Function({
    required String questionarioId,
    required Map<String, dynamic> risposte,
  })
  inviaQuestionario;

  @override
  State<QuestionarioInternoDialog> createState() =>
      _QuestionarioInternoDialogState();
}

class _QuestionarioInternoDialogState extends State<QuestionarioInternoDialog> {
  Map<String, dynamic>? _dati;
  final Map<String, dynamic> _risposte = <String, dynamic>{};
  bool _caricamento = true;
  bool _invio = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    try {
      final dati = await widget.caricaQuestionario(widget.eventoId);

      if (!mounted) return;

      setState(() {
        _dati = dati;
        _caricamento = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = e.toString();
        _caricamento = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_caricamento) {
      return const AlertDialog(
        content: SizedBox(
          width: 500,
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_errore != null) {
      return AlertDialog(
        title: const Text('Questionario'),
        content: Text(_errore!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      );
    }

    if (_dati == null) {
      return AlertDialog(
        title: const Text('Questionario'),
        content: const Text(
          'Nessun questionario di gradimento attivo per questo evento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      );
    }

    final questionario = _dati!['questionario'] as Map<String, dynamic>;
    final domande = (_dati!['domande'] as List).cast<Map<String, dynamic>>();

    return AlertDialog(
      title: Text(questionario['titolo']?.toString() ?? 'Questionario'),
      content: SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final domanda in domande) ...[
                  CampoQuestionario(
                    domanda: domanda,
                    valore: _risposte[domanda['id'].toString()],
                    onChanged: (valore) => setState(
                      () => _risposte[domanda['id'].toString()] = valore,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _invio ? null : () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton.icon(
          onPressed: _invio ? null : () => _invia(questionario, domande),
          icon: _invio
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: const Text('Invia'),
        ),
      ],
    );
  }

  Future<void> _invia(
    Map<String, dynamic> questionario,
    List<Map<String, dynamic>> domande,
  ) async {
    final erroreValidazione = validaRisposteQuestionario(domande, _risposte);
    if (erroreValidazione != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(erroreValidazione)));
      return;
    }

    setState(() => _invio = true);

    final errore = await widget.inviaQuestionario(
      questionarioId: questionario['id'].toString(),
      risposte: _risposte,
    );

    if (!mounted) return;

    setState(() => _invio = false);

    if (errore != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errore)));
      return;
    }

    Navigator.pop(context, true);
  }
}
