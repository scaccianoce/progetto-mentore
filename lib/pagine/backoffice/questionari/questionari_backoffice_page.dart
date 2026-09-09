import 'package:flutter/material.dart';

import 'questionari_backoffice_controller.dart';

/// Backoffice per la gestione dei template e delle domande dei questionari.
class QuestionariBackofficePage extends StatefulWidget {
  const QuestionariBackofficePage({super.key, required this.controller});

  final QuestionariBackofficeController controller;

  @override
  State<QuestionariBackofficePage> createState() =>
      _QuestionariBackofficePageState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _QuestionariBackofficePageState extends State<QuestionariBackofficePage> {
  QuestionariBackofficeController get controller => widget.controller;

  /// Costruisce l’interfaccia grafica di questo componente.
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.caricamento && controller.template.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.errore != null && controller.template.isEmpty) {
          return Center(child: Text(controller.errore!));
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Questionari',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Aggiorna',
                  onPressed: controller.caricamento ? null : controller.carica,
                  icon: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _nuovoTemplate(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuovo template'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'I template per i partecipanti alimentano i questionari interni '
              'agli eventi. I template per gli studenti generano questionari '
              'pubblici anonimi associati ai mentoraggi.',
            ),
            const SizedBox(height: 20),
            for (final template in controller.template)
              _schedaTemplate(context, template),
          ],
        );
      },
    );
  }

  /// Costruisce la scheda relativa a template.
  Widget _schedaTemplate(BuildContext context, Map<String, dynamic> template) {
    final id = template['id'].toString();
    final domande = controller.domandeTemplate(id);
    final destinatario = template['destinatario']?.toString() ?? '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          destinatario == 'studenti'
              ? Icons.groups_outlined
              : Icons.badge_outlined,
        ),
        title: Text(template['titolo']?.toString() ?? 'Template'),
        subtitle: Text(
          '${destinatario == 'studenti' ? 'Studenti esterni' : 'Partecipanti'}'
          ' · ${domande.length} domande'
          '${template['attivo'] == false ? ' · disattivato' : ''}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if ((template['descrizione']?.toString() ?? '').isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(template['descrizione'].toString()),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _modificaTemplate(context, template),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifica template'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _nuovaDomanda(context, template),
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi domanda'),
                ),
              ],
            ),
          ),
          const Divider(height: 28),
          if (domande.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Nessuna domanda inserita.'),
            ),
          for (var indice = 0; indice < domande.length; indice++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${indice + 1}')),
              title: Text(domande[indice]['testo']?.toString() ?? ''),
              subtitle: Text(
                '${domande[indice]['tipo'] ?? ''}'
                '${domande[indice]['obbligatoria'] == true ? ' · obbligatoria' : ''}',
              ),
              trailing: Wrap(
                spacing: 2,
                children: [
                  IconButton(
                    tooltip: 'Sposta su',
                    onPressed: indice == 0
                        ? null
                        : () => _spostaDomanda(
                            context,
                            templateId: id,
                            domanda: domande[indice],
                            versoAlto: true,
                          ),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: 'Sposta giù',
                    onPressed: indice == domande.length - 1
                        ? null
                        : () => _spostaDomanda(
                            context,
                            templateId: id,
                            domanda: domande[indice],
                            versoAlto: false,
                          ),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  IconButton(
                    tooltip: 'Modifica domanda',
                    onPressed: () => _modificaDomanda(
                      context,
                      template,
                      domande[indice],
                    ),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Elimina domanda',
                    onPressed: () => _eliminaDomanda(context, domande[indice]),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Avvia la creazione di template.
  Future<void> _nuovoTemplate(BuildContext context) async {
    await _editorTemplate(context, null);
  }

  /// Gestisce la modifica di template.
  Future<void> _modificaTemplate(
    BuildContext context,
    Map<String, dynamic> template,
  ) async {
    await _editorTemplate(context, template);
  }

  /// Apre e gestisce l’editor del recordtemplate.
  Future<void> _editorTemplate(
    BuildContext context,
    Map<String, dynamic>? iniziali,
  ) async {
    final titolo = TextEditingController(
      text: iniziali?['titolo']?.toString() ?? '',
    );
    final descrizione = TextEditingController(
      text: iniziali?['descrizione']?.toString() ?? '',
    );
    var destinatario = iniziali?['destinatario']?.toString() ?? 'partecipanti';
    var attivo = iniziali?['attivo'] != false;

    final salva =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(
                iniziali == null ? 'Nuovo template' : 'Modifica template',
              ),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titolo,
                      decoration: const InputDecoration(
                        labelText: 'Titolo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: destinatario,
                      decoration: const InputDecoration(
                        labelText: 'Destinatari',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'partecipanti',
                          child: Text('Partecipanti autenticati'),
                        ),
                        DropdownMenuItem(
                          value: 'studenti',
                          child: Text('Studenti esterni'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          destinatario = value;
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descrizione,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Descrizione',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Template attivo'),
                      value: attivo,
                      onChanged: (value) =>
                          setDialogState(() => attivo = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Salva'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!salva) {
      titolo.dispose();
      descrizione.dispose();
      return;
    }

    final errore = await controller.salvaTemplate(
      id: iniziali?['id']?.toString(),
      titolo: titolo.text,
      destinatario: destinatario,
      descrizione: descrizione.text,
      attivo: attivo,
    );

    titolo.dispose();
    descrizione.dispose();

    if (!context.mounted) return;
    _messaggio(context, errore);
  }

  /// Avvia la creazione di domanda.
  Future<void> _nuovaDomanda(
    BuildContext context,
    Map<String, dynamic> template,
  ) => _editorDomanda(context, template, null);

  Future<void> _modificaDomanda(
    BuildContext context,
    Map<String, dynamic> template,
    Map<String, dynamic> domanda,
  ) => _editorDomanda(context, template, domanda);

  Future<void> _editorDomanda(
    BuildContext context,
    Map<String, dynamic> template,
    Map<String, dynamic>? iniziali,
  ) async {
    final testo = TextEditingController(
      text: iniziali?['testo']?.toString() ?? '',
    );
    final opzioni = TextEditingController(
      text: _testoOpzioni(iniziali),
    );
    var tipo = iniziali?['tipo']?.toString() ?? 'testo_breve';
    var obbligatoria = iniziali?['obbligatoria'] == true;

    final domande = controller.domandeTemplate(template['id'].toString());
    final ordine = iniziali?['ordine'] is int
        ? iniziali!['ordine'] as int
        : int.tryParse(iniziali?['ordine']?.toString() ?? '') ??
            (domande.isEmpty
        ? 10
        : ((domande
                  .map((d) => int.tryParse(d['ordine'].toString()) ?? 0)
                  .reduce((a, b) => a > b ? a : b)) +
              10));

    final salva =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(
                iniziali == null ? 'Aggiungi domanda' : 'Modifica domanda',
              ),
              content: SizedBox(
                width: 600,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: testo,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Domanda',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: tipo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo risposta',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'testo_breve',
                          child: Text('Testo breve'),
                        ),
                        DropdownMenuItem(
                          value: 'testo_lungo',
                          child: Text('Testo lungo'),
                        ),
                        DropdownMenuItem(
                          value: 'booleano',
                          child: Text('Sì / No'),
                        ),
                        DropdownMenuItem(
                          value: 'scelta_singola',
                          child: Text('Scelta singola'),
                        ),
                        DropdownMenuItem(
                          value: 'scala',
                          child: Text('Scala numerica'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => tipo = value);
                        }
                      },
                    ),
                    if (tipo == 'scelta_singola' || tipo == 'scala') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: opzioni,
                        decoration: InputDecoration(
                          labelText: tipo == 'scelta_singola'
                              ? 'Opzioni separate da ;'
                              : 'Minimo;Massimo (es. 1;5)',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Risposta obbligatoria'),
                      value: obbligatoria,
                      onChanged: (value) =>
                          setDialogState(() => obbligatoria = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(iniziali == null ? 'Aggiungi' : 'Salva'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!salva) {
      testo.dispose();
      opzioni.dispose();
      return;
    }

    Object? opzioniJson;
    if (tipo == 'scelta_singola') {
      opzioniJson = opzioni.text
          .split(';')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList(growable: false);
    } else if (tipo == 'scala') {
      final parti = opzioni.text.split(';');
      final minimo = parti.isNotEmpty
          ? int.tryParse(parti.first.trim()) ?? 1
          : 1;
      final massimo = parti.length > 1 ? int.tryParse(parti[1].trim()) ?? 5 : 5;
      opzioniJson = <String, dynamic>{'min': minimo, 'max': massimo};
    }

    final errore = iniziali == null
        ? await controller.aggiungiDomanda(
            templateId: template['id'].toString(),
            ordine: ordine,
            testo: testo.text,
            tipo: tipo,
            obbligatoria: obbligatoria,
            opzioni: opzioniJson,
          )
        : await controller.salvaDomanda(
            domandaId: iniziali['id'].toString(),
            testo: testo.text,
            tipo: tipo,
            obbligatoria: obbligatoria,
            opzioni: opzioniJson,
          );

    testo.dispose();
    opzioni.dispose();

    if (!context.mounted) return;
    _messaggio(context, errore);
  }

  String _testoOpzioni(Map<String, dynamic>? domanda) {
    final opzioni = domanda?['opzioni'];
    if (opzioni is List) return opzioni.join(';');
    if (opzioni is Map) {
      return '${opzioni['min'] ?? 1};${opzioni['max'] ?? 5}';
    }
    return '';
  }

  /// Gestisce l’operazione interna “sposta domanda” della pagina.
  Future<void> _spostaDomanda(
    BuildContext context, {
    required String templateId,
    required Map<String, dynamic> domanda,
    required bool versoAlto,
  }) async {
    final errore = await controller.spostaDomanda(
      templateId: templateId,
      domandaId: domanda['id'].toString(),
      versoAlto: versoAlto,
    );

    if (!context.mounted) return;
    _messaggio(context, errore);
  }

  /// Elimina domanda.
  Future<void> _eliminaDomanda(
    BuildContext context,
    Map<String, dynamic> domanda,
  ) async {
    final conferma =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminare la domanda?'),
            content: Text(domanda['testo']?.toString() ?? ''),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Elimina'),
              ),
            ],
          ),
        ) ??
        false;

    if (!conferma) return;

    final errore = await controller.eliminaDomanda(domanda['id'].toString());

    if (!context.mounted) return;
    _messaggio(context, errore);
  }
}

/// Gestisce l’operazione interna “messaggio” della pagina.
void _messaggio(BuildContext context, String? errore) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(errore ?? 'Operazione completata.')));
}
