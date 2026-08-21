import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../sessione_controller.dart';
import 'risorse_mentoring_controller.dart';

class RisorseMentoringPage extends StatefulWidget {
  const RisorseMentoringPage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<RisorseMentoringPage> createState() => _RisorseMentoringPageState();
}

class _RisorseMentoringPageState extends State<RisorseMentoringPage> {
  late final RisorseMentoringController controller;

  @override
  void initState() {
    super.initState();
    controller = RisorseMentoringController(widget.sessione)..carica();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.caricamento && controller.risorse.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.errore != null && controller.risorse.isEmpty) {
            return Center(child: Text(controller.errore!));
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Risorse per il mentoring',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Aggiorna',
                    onPressed: controller.caricamento ? null : controller.carica,
                    icon: const Icon(Icons.refresh),
                  ),
                  if (controller.puoGestire) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _caricaNuovo,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Carica materiale'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Documenti e materiali condivisi per le attività del Progetto Mentore.',
              ),
              const SizedBox(height: 20),
              for (final categoria in RisorseMentoringController.categorie)
                _categoria(categoria),
            ],
          );
        },
      );

  Widget _categoria(String categoria) {
    final righe = controller.perCategoria(categoria);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.folder_outlined),
        title: Text(categoria),
        subtitle: Text('${righe.length} file'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: righe.isEmpty
            ? const [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Nessun materiale disponibile.'),
                  ),
                ),
              ]
            : [
                for (final riga in righe)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(riga['titolo']?.toString() ?? ''),
                    subtitle: Text(
                      <String>[
                        if ((riga['descrizione']?.toString() ?? '').isNotEmpty)
                          riga['descrizione'].toString(),
                        if ((riga['anno_accademico']?.toString() ?? '').isNotEmpty)
                          'A.A. ${riga['anno_accademico']}',
                        riga['nome_file']?.toString() ?? '',
                      ].where((v) => v.isNotEmpty).join(' · '),
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Scarica / apri',
                          onPressed: () => _apri(riga),
                          icon: const Icon(Icons.download_outlined),
                        ),
                        if (controller.puoGestire)
                          IconButton(
                            tooltip: 'Elimina',
                            onPressed: () => _elimina(riga),
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                  ),
              ],
      ),
    );
  }

  Future<void> _caricaNuovo() async {
    final file = await FilePicker.pickFile();
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;

    if (bytes.lengthInBytes > RisorseMentoringController.dimensioneMassima) {
      _messaggio('Il file supera il limite massimo di 20 MB.');
      return;
    }

    final titolo = TextEditingController(text: file.name);
    final descrizione = TextEditingController();
    var categoria = RisorseMentoringController.categorie.first;
    String? anno;

    final salva = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) => AlertDialog(
              title: const Text('Carica materiale'),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titolo,
                        decoration: const InputDecoration(
                          labelText: 'Titolo *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: categoria,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Categoria *',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final valore in RisorseMentoringController.categorie)
                            DropdownMenuItem(value: valore, child: Text(valore)),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => categoria = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: anno,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Anno accademico (facoltativo)',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Valido per tutti gli anni'),
                          ),
                          for (final valore in controller.anniAccademici)
                            DropdownMenuItem<String?>(
                              value: valore,
                              child: Text(valore),
                            ),
                        ],
                        onChanged: (value) => setDialogState(() => anno = value),
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
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: titolo.text.trim().isEmpty
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: const Text('Carica'),
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

    final errore = await controller.caricaRisorsa(
      bytes: bytes,
      nomeFile: file.name,
      titolo: titolo.text,
      categoria: categoria,
      descrizione: descrizione.text,
      annoAccademico: anno,
    );
    titolo.dispose();
    descrizione.dispose();
    if (!mounted) return;
    _messaggio(errore ?? 'Materiale caricato.');
  }

  Future<void> _apri(Map<String, dynamic> riga) async {
    try {
      final uri = await controller.urlDownload(riga);
      if (!mounted) return;
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _messaggio('Impossibile aprire il file.');
      }
    } catch (e) {
      if (!mounted) return;
      _messaggio(e.toString());
    }
  }

  Future<void> _elimina(Map<String, dynamic> riga) async {
    final conferma = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminare il materiale?'),
            content: Text(riga['titolo']?.toString() ?? ''),
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
    final errore = await controller.elimina(riga);
    if (!mounted) return;
    _messaggio(errore ?? 'Materiale eliminato.');
  }

  void _messaggio(String testo) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
  }
}
