import 'package:flutter/material.dart';

import 'backoffice_controller.dart';

class MentoriBackofficePage extends StatelessWidget {
  const MentoriBackofficePage({super.key, required this.controller});

  final BackofficeController controller;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: controller.mentoraggi.isEmpty ||
                        controller.partecipanti.isEmpty ||
                        controller.tipiMentoreDisponibili.isEmpty
                    ? null
                    : () => _nuovaAssegnazione(context),
                icon: const Icon(Icons.add),
                label: const Text('Assegna mentore'),
              ),
            ),
          ),
          Expanded(
            child: controller.assegnazioni.isEmpty
                ? const Center(child: Text('Nessun mentore assegnato.'))
                : ListView.builder(
                    itemCount: controller.assegnazioni.length,
                    itemBuilder: (context, i) {
                      final a = controller.assegnazioni[i];
                      return ListTile(
                        title: Text(controller.nomeUtente(a['mentore_id'])),
                        subtitle: Text(
                          '${a['tipo']} · mentoraggio ${a['mentoraggio_id']}',
                        ),
                        trailing: IconButton(
                          onPressed: () async {
                            final errore =
                                await controller.eliminaAssegnazione(a);
                            if (!context.mounted) return;
                            _errore(context, errore);
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );

  Future<void> _nuovaAssegnazione(BuildContext context) async {
    var mentoraggio = controller.mentoraggi.first['id'].toString();
    var mentore = controller.partecipanti.first['user_id'].toString();
    var tipo = controller.tipiMentoreDisponibili.first;

    final salva = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Assegna mentore'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: mentoraggio,
                      decoration: const InputDecoration(
                        labelText: 'Mentoraggio',
                      ),
                      items: controller.mentoraggi
                          .map(
                            (m) => DropdownMenuItem<String>(
                              value: m['id'].toString(),
                              child: Text(m['id'].toString()),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => mentoraggio = v);
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: mentore,
                      decoration: const InputDecoration(
                        labelText: 'Partecipante',
                      ),
                      items: controller.partecipanti
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p['user_id'].toString(),
                              child: Text(
                                '${p['cognome'] ?? ''} ${p['nome'] ?? ''}',
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => mentore = v);
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: tipo,
                      decoration: const InputDecoration(labelText: 'Funzione'),
                      items: controller.tipiMentoreDisponibili
                          .map(
                            (v) => DropdownMenuItem<String>(
                              value: v,
                              child: Text(v),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => tipo = v);
                      },
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
                  child: const Text('Assegna'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!salva) return;
    final errore = await controller.aggiungiAssegnazione(
      mentoraggio,
      mentore,
      tipo,
    );
    if (!context.mounted) return;
    _errore(context, errore);
  }
}

void _errore(BuildContext context, String? errore) {
  if (errore == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errore)));
}
