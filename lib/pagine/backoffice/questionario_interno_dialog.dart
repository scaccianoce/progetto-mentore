import 'package:flutter/material.dart';

import 'questionari_controller.dart';

class QuestionarioInternoDialog extends StatefulWidget {
  const QuestionarioInternoDialog({
    super.key,
    required this.controller,
    required this.eventoId,
  });

  final QuestionariController controller;
  final String eventoId;

  @override
  State<QuestionarioInternoDialog> createState() =>
      _QuestionarioInternoDialogState();
}

class _QuestionarioInternoDialogState
    extends State<QuestionarioInternoDialog> {
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
      final dati =
          await widget.controller.caricaQuestionarioEvento(widget.eventoId);

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

    final questionario =
        _dati!['questionario'] as Map<String, dynamic>;
    final domande =
        (_dati!['domande'] as List).cast<Map<String, dynamic>>();

    return AlertDialog(
      title: Text(questionario['titolo']?.toString() ?? 'Questionario'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final domanda in domande) ...[
                _campo(domanda),
                const SizedBox(height: 16),
              ],
            ],
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

  Widget _campo(Map<String, dynamic> domanda) {
    final id = domanda['id'].toString();
    final testo = domanda['testo']?.toString() ?? '';
    final tipo = domanda['tipo']?.toString() ?? 'testo_breve';
    final obbligatoria = domanda['obbligatoria'] == true;

    if (tipo == 'booleano') {
      final valore = _risposte[id] as bool?;
      return InputDecorator(
        decoration: InputDecoration(
          labelText: obbligatoria ? '$testo *' : testo,
          border: const OutlineInputBorder(),
        ),
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('Sì'),
              selected: valore == true,
              onSelected: (_) => setState(() => _risposte[id] = true),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('No'),
              selected: valore == false,
              onSelected: (_) => setState(() => _risposte[id] = false),
            ),
          ],
        ),
      );
    }

    if (tipo == 'scelta_singola') {
      final opzioni = (domanda['opzioni'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false);

      return DropdownButtonFormField<String>(
        initialValue: _risposte[id]?.toString(),
        isExpanded: true,
        decoration: InputDecoration(
          labelText: obbligatoria ? '$testo *' : testo,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final opzione in opzioni)
            DropdownMenuItem(
              value: opzione,
              child: Text(opzione),
            ),
        ],
        onChanged: (value) => _risposte[id] = value,
      );
    }

    if (tipo == 'scala') {
      final opzioni =
          Map<String, dynamic>.from(domanda['opzioni'] as Map? ?? const {});
      final min = int.tryParse(opzioni['min']?.toString() ?? '') ?? 1;
      final max = int.tryParse(opzioni['max']?.toString() ?? '') ?? 5;

      return DropdownButtonFormField<int>(
        initialValue: _risposte[id] as int?,
        decoration: InputDecoration(
          labelText: obbligatoria ? '$testo *' : testo,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (var valore = min; valore <= max; valore++)
            DropdownMenuItem(
              value: valore,
              child: Text(valore.toString()),
            ),
        ],
        onChanged: (value) => _risposte[id] = value,
      );
    }

    return TextFormField(
      minLines: tipo == 'testo_lungo' ? 4 : 1,
      maxLines: tipo == 'testo_lungo' ? 8 : 1,
      decoration: InputDecoration(
        labelText: obbligatoria ? '$testo *' : testo,
        border: const OutlineInputBorder(),
        alignLabelWithHint: tipo == 'testo_lungo',
      ),
      onChanged: (value) => _risposte[id] = value,
    );
  }

  Future<void> _invia(
    Map<String, dynamic> questionario,
    List<Map<String, dynamic>> domande,
  ) async {
    for (final domanda in domande) {
      if (domanda['obbligatoria'] != true) continue;

      final id = domanda['id'].toString();
      final valore = _risposte[id];

      final vuoto = valore == null ||
          (valore is String && valore.trim().isEmpty);

      if (vuoto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Risposta obbligatoria: ${domanda['testo'] ?? ''}',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _invio = true);

    final errore = await widget.controller.inviaQuestionarioInterno(
      questionarioId: questionario['id'].toString(),
      risposte: _risposte,
    );

    if (!mounted) return;

    setState(() => _invio = false);

    if (errore != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errore)),
      );
      return;
    }

    Navigator.pop(context, true);
  }
}
