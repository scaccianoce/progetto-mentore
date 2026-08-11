import 'package:flutter/material.dart';

import '../../app_exception.dart';
import 'mentore_controller.dart';

class MentorePage extends StatefulWidget {
  const MentorePage({super.key});
  @override
  State<MentorePage> createState() => _MentorePageState();
}

class _MentorePageState extends State<MentorePage> {
  late final MentoreController controller;
  static const Set<String> nonModificabili = {
    'id',
    'insegnamento_id',
    'created_at',
  };

  @override
  void initState() {
    super.initState();
    controller = MentoreController()..carica();
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
      if (controller.caricamento) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.errore != null) {
        return Center(child: Text(controller.errore!));
      }
      if (controller.percorsi.isEmpty) {
        return const Center(child: Text('Nessun mentoraggio assegnato.'));
      }
      final elenco = Card(
        child: ListView(
          children: controller.percorsi
              .map(
                (p) => ListTile(
                  selected:
                      p.mentoraggio['id'] ==
                      controller.selezionato?.mentoraggio['id'],
                  title: Text(p.insegnamento['insegnamento']?.toString() ?? ''),
                  subtitle: Text(
                    '${p.docente['nome'] ?? ''} ${p.docente['cognome'] ?? ''}'
                        .trim(),
                  ),
                  onTap: () => controller.seleziona(p),
                ),
              )
              .toList(growable: false),
        ),
      );
      final dettaglio = _dettaglio(context);
      return Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth >= 800) {
              return Row(
                children: [
                  SizedBox(width: 340, child: elenco),
                  const VerticalDivider(width: 24),
                  Expanded(child: dettaglio),
                ],
              );
            }
            return Column(
              children: [
                Expanded(child: elenco),
                const Divider(),
                Expanded(child: dettaglio),
              ],
            );
          },
        ),
      );
    },
  );

  Widget _dettaglio(BuildContext context) {
    final p = controller.selezionato;
    if (p == null) return const SizedBox.shrink();
    return Card(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ruolo mentore',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              FilledButton.icon(
                onPressed: _modifica,
                icon: const Icon(Icons.edit),
                label: const Text('Modifica'),
              ),
            ],
          ),
          ListTile(
            title: const Text('Insegnamento'),
            subtitle: Text(p.insegnamento['insegnamento']?.toString() ?? ''),
          ),
          ListTile(
            title: const Text(
              'Mentee',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${p.docente['nome'] ?? ''} ${p.docente['cognome'] ?? ''}'.trim(),
            ),
          ),
          const Divider(),
          Text('Team', style: Theme.of(context).textTheme.titleMedium),
          ...p.team.map(
            (m) => ListTile(
              title: Text('${m['nome'] ?? ''} ${m['cognome'] ?? ''}'.trim()),
              subtitle: Text(m['tipo']?.toString() ?? ''),
            ),
          ),
          const Divider(),
          ...p.mentoraggio.entries
              .where((e) => !nonModificabili.contains(e.key))
              .map(
                (e) => ListTile(
                  title: Text(
                    e.key.replaceAll('_', ' '),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(e.value?.toString() ?? '—'),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _modifica() async {
    final p = controller.selezionato!;
    final campi = <String, TextEditingController>{
      for (final e in p.mentoraggio.entries.where(
        (e) => !nonModificabili.contains(e.key),
      ))
        e.key: TextEditingController(text: e.value?.toString() ?? ''),
    };
    final salva = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aggiorna mentoraggio'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              children: campi.entries
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: e.value,
                        decoration: InputDecoration(
                          labelText: e.key.replaceAll('_', ' '),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
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
    );
    if (salva == true) {
      try {
        await controller.salvaMentoraggio({
          for (final e in campi.entries)
            e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
        });
      } on AppException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.messaggio)));
        }
      }
    }
    for (final c in campi.values) {
      c.dispose();
    }
  }
}
