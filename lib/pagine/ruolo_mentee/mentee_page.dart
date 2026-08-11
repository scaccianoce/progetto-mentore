import 'package:flutter/material.dart';

import 'mentee_controller.dart';

class MenteePage extends StatefulWidget {
  const MenteePage({super.key});

  @override
  State<MenteePage> createState() => _MenteePageState();
}

class _MenteePageState extends State<MenteePage> {
  late final MenteeController controller;

  @override
  void initState() {
    super.initState();
    controller = MenteeController()..carica();
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
      if (controller.insegnamento == null) {
        return const Center(
          child: Text('Nessun insegnamento per l’anno corrente.'),
        );
      }
      if (controller.mentoraggio == null) {
        return const Center(child: Text('Mentoraggio non ancora disponibile.'));
      }
      return ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(
            'Ruolo mentee',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text(
                controller.insegnamento!['insegnamento']?.toString() ?? '',
              ),
              subtitle: Text(
                controller.insegnamento!['anno_accademico']?.toString() ?? '',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Team di mentoraggio',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...controller.mentori.map(
            (m) => ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text('${m['nome'] ?? ''} ${m['cognome'] ?? ''}'.trim()),
              subtitle: Text('${m['tipo'] ?? ''} · ${m['email_unipa'] ?? ''}'),
            ),
          ),
          const Divider(height: 28),
          ...controller.mentoraggio!.entries
              .where((e) => !<String>{'id', 'insegnamento_id'}.contains(e.key))
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
      );
    },
  );
}
