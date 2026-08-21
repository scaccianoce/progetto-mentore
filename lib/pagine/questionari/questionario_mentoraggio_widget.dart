import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'questionari_controller.dart';

/// Widget riutilizzabile da inserire nella scheda di un mentoraggio.
///
/// Prima versione:
/// - seleziona un template "studenti";
/// - crea l'istanza collegata al mentoraggio;
/// - il mentore incolla l'URL della copia del Google Form;
/// - template e URL restano tracciati in Supabase.
class QuestionarioMentoraggioCard extends StatefulWidget {
  const QuestionarioMentoraggioCard({
    super.key,
    required this.controller,
    required this.mentoraggioId,
  });

  final QuestionariController controller;
  final String mentoraggioId;

  @override
  State<QuestionarioMentoraggioCard> createState() =>
      _QuestionarioMentoraggioCardState();
}

class _QuestionarioMentoraggioCardState
    extends State<QuestionarioMentoraggioCard> {
  QuestionariController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final esistente =
        controller.questionarioMentoraggio(widget.mentoraggioId);
    final template = controller.templatePer('studenti');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Questionario studenti',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (esistente == null) ...[
              const Text(
                'Crea il questionario a partire da un template. '
                'In questa versione il modulo viene compilato con Google Forms '
                'e l’URL viene associato al mentoraggio.',
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: template.isEmpty
                    ? null
                    : () => _creaQuestionario(context, template),
                icon: const Icon(Icons.quiz_outlined),
                label: const Text('Genera questionario'),
              ),
              if (template.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Nessun template studenti attivo. '
                    'Crealo dal backoffice Questionari.',
                  ),
                ),
            ] else ...[
              Text(esistente['titolo']?.toString() ?? ''),
              const SizedBox(height: 8),
              Text(
                esistente['url_esterno'] == null
                    ? 'Google Form non ancora associato.'
                    : esistente['url_esterno'].toString(),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _modificaUrl(context, esistente),
                    icon: const Icon(Icons.link),
                    label: Text(
                      esistente['url_esterno'] == null
                          ? 'Inserisci link'
                          : 'Modifica link',
                    ),
                  ),
                  if (esistente['url_esterno'] != null)
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          _apri(esistente['url_esterno'].toString()),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Apri Google Form'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _mostraDomande(context, esistente),
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text('Mostra domande'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _creaQuestionario(
    BuildContext context,
    List<Map<String, dynamic>> template,
  ) async {
    String? templateId = template.first['id']?.toString();

    final scelto = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Template questionario studenti'),
        content: SizedBox(
          width: 520,
          child: DropdownButtonFormField<String>(
            initialValue: templateId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Template',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final t in template)
                DropdownMenuItem(
                  value: t['id'].toString(),
                  child: Text(t['titolo']?.toString() ?? ''),
                ),
            ],
            onChanged: (value) => templateId = value,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, templateId),
            child: const Text('Crea'),
          ),
        ],
      ),
    );

    if (scelto == null) return;

    final t = template.firstWhere((riga) => riga['id'].toString() == scelto);

    final errore = await controller.creaQuestionarioMentoraggio(
      mentoraggioId: widget.mentoraggioId,
      templateId: scelto,
      titolo: t['titolo']?.toString() ?? 'Questionario studenti',
    );

    if (!context.mounted) return;

    _messaggio(context, errore);

    if (errore == null) {
      await _modificaUrl(
        context,
        controller.questionarioMentoraggio(widget.mentoraggioId)!,
      );
    }
  }

  Future<void> _modificaUrl(
    BuildContext context,
    Map<String, dynamic> questionario,
  ) async {
    final testo = TextEditingController(
      text: questionario['url_esterno']?.toString() ?? '',
    );

    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google Form'),
        content: SizedBox(
          width: 580,
          child: TextField(
            controller: testo,
            decoration: const InputDecoration(
              labelText: 'URL del Google Form',
              hintText: 'https://forms.gle/...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, testo.text),
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    testo.dispose();

    if (url == null) return;

    final errore = await controller.salvaUrlGoogleForm(
      questionario['id'].toString(),
      url,
    );

    if (!context.mounted) return;
    _messaggio(context, errore);
  }

  Future<void> _mostraDomande(
    BuildContext context,
    Map<String, dynamic> questionario,
  ) async {
    final templateId = questionario['template_id'].toString();
    final domande = controller.domandeTemplate(templateId);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Domande del template'),
        content: SizedBox(
          width: 650,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: domande.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final domanda = domande[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(domanda['ordine'].toString()),
                title: Text(domanda['testo']?.toString() ?? ''),
                subtitle: Text(domanda['tipo']?.toString() ?? ''),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<void> _apri(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      _messaggio(context, 'Impossibile aprire il Google Form.');
    }
  }
}

void _messaggio(
  BuildContext context,
  String? errore,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(errore ?? 'Operazione completata.'),
    ),
  );
}
