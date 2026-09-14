import 'package:flutter/material.dart';

/// Widget comune per il rendering di una domanda di questionario.
///
/// E' condiviso dai flussi privato e pubblico e non contiene accesso ai dati.
class CampoQuestionario extends StatelessWidget {
  const CampoQuestionario({
    super.key,
    required this.domanda,
    required this.valore,
    required this.onChanged,
  });

  final Map<String, dynamic> domanda;
  final Object? valore;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final testo = domanda['testo']?.toString() ?? '';
    final tipo = domanda['tipo']?.toString() ?? 'testo_breve';
    final domandaDecorazione = BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(4),
    );
    final rispostaDecorazione = InputDecoration(
      labelText: 'Risposta',
      border: const OutlineInputBorder(),
    );

    Widget campoRisposta(Widget campo) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: domandaDecorazione,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              domanda['obbligatoria'] == true ? '$testo *' : testo,
              softWrap: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        campo,
      ],
    );

    if (tipo == 'booleano') {
      return campoRisposta(
        InputDecorator(
          decoration: rispostaDecorazione,
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Sì'),
                selected: valore == true,
                onSelected: (_) => onChanged(true),
              ),
              ChoiceChip(
                label: const Text('No'),
                selected: valore == false,
                onSelected: (_) => onChanged(false),
              ),
            ],
          ),
        ),
      );
    }

    if (tipo == 'scala') {
      final opzioni = Map<String, dynamic>.from(
        domanda['opzioni'] as Map? ?? const {},
      );
      final minimo = int.tryParse(opzioni['min']?.toString() ?? '') ?? 1;
      final massimo = int.tryParse(opzioni['max']?.toString() ?? '') ?? 5;
      return campoRisposta(
        DropdownButtonFormField<int>(
          initialValue: valore as int?,
          decoration: rispostaDecorazione,
          items: [
            for (var numero = minimo; numero <= massimo; numero++)
              DropdownMenuItem(value: numero, child: Text(numero.toString())),
          ],
          onChanged: onChanged,
        ),
      );
    }

    if (tipo == 'scelta_singola') {
      final opzioni = (domanda['opzioni'] as List? ?? const [])
          .map((opzione) => opzione.toString())
          .toList(growable: false);
      return campoRisposta(
        DropdownButtonFormField<String>(
          initialValue: valore?.toString(),
          isExpanded: true,
          decoration: rispostaDecorazione,
          items: [
            for (final opzione in opzioni)
              DropdownMenuItem(value: opzione, child: Text(opzione)),
          ],
          onChanged: onChanged,
        ),
      );
    }

    return campoRisposta(
      TextFormField(
        initialValue: valore?.toString(),
        minLines: tipo == 'testo_lungo' ? 4 : 1,
        maxLines: tipo == 'testo_lungo' ? 8 : 1,
        decoration: rispostaDecorazione,
        onChanged: onChanged,
      ),
    );
  }
}

String? validaRisposteQuestionario(
  List<Map<String, dynamic>> domande,
  Map<String, dynamic> risposte,
) {
  for (final domanda in domande) {
    if (domanda['obbligatoria'] != true) continue;
    final valore = risposte[domanda['id'].toString()];
    if (valore == null || (valore is String && valore.trim().isEmpty)) {
      return 'Risposta obbligatoria: ${domanda['testo'] ?? ''}';
    }
  }
  return null;
}
