import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_exception.dart';
import '../../supabase_config.dart';

class SchedaSintesiFileCard extends StatefulWidget {
  const SchedaSintesiFileCard({
    super.key,
    required this.mentoraggio,
    this.onAggiornato,
  });

  final Map<String, dynamic> mentoraggio;
  final Future<void> Function()? onAggiornato;

  @override
  State<SchedaSintesiFileCard> createState() =>
      _SchedaSintesiFileCardState();
}

class _SchedaSintesiFileCardState extends State<SchedaSintesiFileCard> {
  static const _bucket = 'schede-sintesi';
  bool _operazione = false;

  String get _stato =>
      widget.mentoraggio['stato']?.toString().trim().toLowerCase() ?? '';

  String get _valoreFile =>
      widget.mentoraggio['scheda_sintesi_pdf_url']?.toString().trim() ?? '';

  bool get _completato => _stato == 'completato';

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Scheda di sintesi · documento',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              _completato
                  ? 'Puoi caricare o sostituire la scheda definitiva in PDF o DOCX.'
                  : 'Il caricamento è disponibile quando il mentoraggio è in stato Completato.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_valoreFile.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: _operazione ? null : _apri,
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Apri / scarica'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: !_completato || _operazione ? null : _carica,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(
                    _valoreFile.isEmpty
                        ? 'Carica scheda di sintesi'
                        : 'Sostituisci scheda',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _carica() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx'],
    );
    if (file == null) return;

    final estensione = file.name.split('.').last.toLowerCase();
    if (!const {'pdf', 'docx'}.contains(estensione)) {
      _messaggio('Sono ammessi soltanto file PDF e DOCX.');
      return;
    }

    setState(() => _operazione = true);
    try {
      final bytes = await file.readAsBytes();
      final id = widget.mentoraggio['id'].toString();
      final anno = widget.mentoraggio['anno_accademico']?.toString() ?? 'senza-anno';
      final path = '$anno/$id/scheda_sintesi.$estensione';
      final contentType = estensione == 'pdf'
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

      await SupabaseConfig.client.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
            ),
          );

      await SupabaseConfig.client.rpc(
        'mentoraggio_scheda_sintesi_imposta',
        params: {
          'p_mentoraggio_id': id,
          'p_storage_path': path,
        },
      );

      final precedente = _valoreFile;
      if (precedente.isNotEmpty &&
          precedente != path &&
          !precedente.startsWith('http://') &&
          !precedente.startsWith('https://')) {
        try {
          await SupabaseConfig.client.storage
              .from(_bucket)
              .remove([precedente]);
        } catch (_) {
          // Il nuovo documento e gia valido: un residuo del vecchio file
          // non deve annullare l'operazione.
        }
      }

      widget.mentoraggio['scheda_sintesi_pdf_url'] = path;
      if (widget.onAggiornato != null) {
        await widget.onAggiornato!();
      }
      if (!mounted) return;
      setState(() {});
      _messaggio('Scheda di sintesi caricata.');
    } catch (e) {
      _messaggio(
        AppErrorMapper.converti(
          e,
          messaggioGenerico: 'Impossibile caricare la scheda di sintesi.',
        ).messaggio,
      );
    } finally {
      if (mounted) setState(() => _operazione = false);
    }
  }

  Future<void> _apri() async {
    setState(() => _operazione = true);
    try {
      final valore = _valoreFile;
      final url = valore.startsWith('http://') || valore.startsWith('https://')
          ? valore
          : await SupabaseConfig.client.storage
              .from(_bucket)
              .createSignedUrl(valore, 3600);

      final uri = Uri.tryParse(url);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const AppException('Impossibile aprire il documento.');
      }
    } catch (e) {
      _messaggio(
        AppErrorMapper.converti(
          e,
          messaggioGenerico: 'Impossibile aprire la scheda di sintesi.',
        ).messaggio,
      );
    } finally {
      if (mounted) setState(() => _operazione = false);
    }
  }

  void _messaggio(String testo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(testo)),
    );
  }
}
