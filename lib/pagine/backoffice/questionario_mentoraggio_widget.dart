import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'questionari_controller.dart';

class QuestionarioMentoraggioCard extends StatefulWidget {
  const QuestionarioMentoraggioCard({
    super.key,
    required this.controller,
    required this.mentoraggioId,
    this.consentiRigenerazione = false,
  });

  final QuestionariController controller;
  final String mentoraggioId;

  /// True solo nel backoffice: consente di eliminare e rigenerare il
  /// questionario finché non esistono compilazioni.
  final bool consentiRigenerazione;

  @override
  State<QuestionarioMentoraggioCard> createState() =>
      _QuestionarioMentoraggioCardState();
}

class _QuestionarioMentoraggioCardState
    extends State<QuestionarioMentoraggioCard> {
  QuestionariController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final esistente = controller.questionarioMentoraggio(widget.mentoraggioId);
    final templateStudenti = controller.templatePer('studenti');
    final url = esistente == null
        ? null
        : controller.urlQuestionarioPubblico(esistente);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Questionario studenti',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Il template viene predisposto da owner/organizer. '
              'Il mentore può generare e condividere il questionario.',
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: esistente != null || templateStudenti.isEmpty
                  ? null
                  : () => _genera(templateStudenti),
              icon: const Icon(Icons.qr_code_2_outlined),
              label: Text(
                esistente == null
                    ? 'Genera URL e QR code'
                    : 'Questionario già generato',
              ),
            ),
            if (esistente == null && templateStudenti.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Nessun template studenti attivo.'),
              ),
            if (esistente != null) ...[
              const SizedBox(height: 14),
              Text(esistente['titolo']?.toString() ?? 'Questionario studenti'),
              const SizedBox(height: 8),
              if (url != null) ...[
                SelectableText(url),
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(10),
                    child: QrImageView(
                      data: url,
                      version: QrVersions.auto,
                      size: 190,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (!context.mounted) return;
                        _messaggio(context, 'URL copiato negli appunti.');
                      },
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copia URL'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _apri(url),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Apri'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _mostraDomande(context, esistente),
                      icon: const Icon(Icons.list_alt_outlined),
                      label: const Text('Mostra domande'),
                    ),
                  ],
                ),
              ],
              if (widget.consentiRigenerazione)
                FutureBuilder<int>(
                  future: controller.contaCompilazioni(esistente['id'].toString()),
                  builder: (context, snapshot) {
                    final numero = snapshot.data;
                    if (numero == null) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: LinearProgressIndicator(),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Risposte ricevute: $numero'),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: numero == 0
                                ? () => _eliminaPerRigenerare(esistente)
                                : null,
                            icon: const Icon(Icons.restart_alt),
                            label: Text(
                              numero == 0
                                  ? 'Elimina e consenti nuova generazione'
                                  : 'Questionario bloccato: sono presenti risposte',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _genera(List<Map<String, dynamic>> templateStudenti) async {
    String? templateId = templateStudenti.length == 1
        ? templateStudenti.first['id'].toString()
        : null;

    final scelto = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Genera questionario studenti'),
          content: SizedBox(
            width: 520,
            child: DropdownButtonFormField<String>(
              initialValue: templateId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Template *',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final template in templateStudenti)
                  DropdownMenuItem(
                    value: template['id'].toString(),
                    child: Text(template['titolo']?.toString() ?? 'Template'),
                  ),
              ],
              onChanged: (value) => setDialogState(() => templateId = value),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: templateId == null
                  ? null
                  : () => Navigator.pop(dialogContext, templateId),
              child: const Text('Genera'),
            ),
          ],
        ),
      ),
    );

    if (scelto == null || !mounted) return;
    final template = templateStudenti.firstWhere(
      (t) => t['id'].toString() == scelto,
    );
    final errore = await controller.creaQuestionarioMentoraggio(
      mentoraggioId: widget.mentoraggioId,
      templateId: scelto,
      titolo: template['titolo']?.toString() ?? 'Questionario studenti',
    );
    if (!mounted) return;
    _messaggio(context, errore ?? 'Questionario generato.');
    if (errore == null) setState(() {});
  }

  Future<void> _eliminaPerRigenerare(Map<String, dynamic> questionario) async {
    final conferma = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminare il questionario?'),
            content: const Text(
              'Non sono presenti risposte. Il questionario verrà eliminato '
              'e potrà essere rigenerato scegliendo anche un template diverso.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Elimina'),
              ),
            ],
          ),
        ) ??
        false;
    if (!conferma) return;
    final errore = await controller
        .eliminaQuestionarioMentoraggio(questionario['id'].toString());
    if (!mounted) return;
    _messaggio(context, errore ?? 'Questionario eliminato. Ora può essere rigenerato.');
    if (errore == null) setState(() {});
  }

  Future<void> _mostraDomande(
    BuildContext context,
    Map<String, dynamic> questionario,
  ) async {
    final domande = controller.domandeTemplate(questionario['template_id'].toString());
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Domande del questionario'),
        content: SizedBox(
          width: 650,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: domande.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (_, index) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text('${index + 1}'),
              title: Text(domande[index]['testo']?.toString() ?? ''),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
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
      _messaggio(context, 'Impossibile aprire il questionario.');
    }
  }
}

void _messaggio(BuildContext context, String testo) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
}
