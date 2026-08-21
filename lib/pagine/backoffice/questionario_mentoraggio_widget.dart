import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'questionari_controller.dart';

/// Il mentore non modifica template o domande.
/// Può soltanto generare una volta il questionario studenti predisposto
/// da owner/organizer e poi condividere URL e QR code.
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

    final templateStudenti =
        controller.templatePer('studenti');

    final url = esistente == null
        ? null
        : controller.urlQuestionarioPubblico(esistente);

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
            const Text(
              'Il questionario utilizza il template predisposto '
              'dall’organizzazione. Il mentore può soltanto generarlo '
              'e condividerlo con gli studenti.',
            ),
            const SizedBox(height: 12),

            FilledButton.tonalIcon(
              // Una volta generato il pulsante resta visibile ma disabilitato.
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
                child: Text(
                  'Nessun template studenti attivo. '
                  'Deve essere predisposto da owner/organizer.',
                ),
              ),

            if (esistente != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                esistente['titolo']?.toString() ??
                    'Questionario studenti',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),

              if (url == null)
                const Text(
                  'Token pubblico non disponibile. '
                  'Verificare la configurazione del database.',
                )
              else ...[
                SelectableText(url),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: url,
                      version: QrVersions.auto,
                      size: 220,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: url),
                        );
                        if (!context.mounted) return;
                        _messaggio(
                          context,
                          'URL copiato negli appunti.',
                        );
                      },
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copia URL'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _apri(url),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Apri questionario'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _mostraDomande(context, esistente),
                      icon: const Icon(Icons.list_alt_outlined),
                      label: const Text('Mostra domande'),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _genera(
    List<Map<String, dynamic>> templateStudenti,
  ) async {
    // Il mentore non sceglie/modifica il template. Usiamo il primo template
    // studenti attivo restituito dal backoffice.
    final template = templateStudenti.first;
    final templateId = template['id'].toString();

    final conferma = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Genera questionario studenti'),
            content: Text(
              'Verrà generato il questionario utilizzando il template:\n\n'
              '${template['titolo'] ?? 'Questionario studenti'}\n\n'
              'Dopo la generazione il template non potrà essere cambiato '
              'dal mentore.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, true),
                child: const Text('Genera'),
              ),
            ],
          ),
        ) ??
        false;

    if (!conferma || !mounted) return;

    final errore =
        await controller.creaQuestionarioMentoraggio(
      mentoraggioId: widget.mentoraggioId,
      templateId: templateId,
      titolo:
          template['titolo']?.toString() ?? 'Questionario studenti',
    );

    if (!mounted) return;

    _messaggio(context, errore);

    if (errore == null) {
      setState(() {});
    }
  }

  Future<void> _mostraDomande(
    BuildContext context,
    Map<String, dynamic> questionario,
  ) async {
    final templateId =
        questionario['template_id'].toString();
    final domande =
        controller.domandeTemplate(templateId);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Domande del questionario'),
        content: SizedBox(
          width: 650,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: domande.length,
            separatorBuilder: (_, _) =>
                const Divider(),
            itemBuilder: (context, index) {
              final domanda = domande[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text('${index + 1}'),
                title: Text(
                  domanda['testo']?.toString() ?? '',
                ),
                subtitle: Text(
                  domanda['tipo']?.toString() ?? '',
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<void> _apri(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null ||
        !await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        )) {
      if (!mounted) return;
      _messaggio(
        context,
        'Impossibile aprire il questionario.',
      );
    }
  }
}

void _messaggio(
  BuildContext context,
  String? errore,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        errore ?? 'Operazione completata.',
      ),
    ),
  );
}
