import 'package:flutter/material.dart';

import 'backoffice_controller.dart';

class AbilitazioniBackofficePage extends StatelessWidget {
  const AbilitazioniBackofficePage({super.key, required this.controller});

  final BackofficeController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.abilitazioni.isEmpty) {
      return const Center(child: Text('Nessuna richiesta di modifica.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: controller.abilitazioni.length,
      itemBuilder: (context, i) {
        final riga = controller.abilitazioni[i];
        final attiva =
            riga['abilitata'] == true && riga['revocata_at'] == null;
        return Card(
          child: ListTile(
            title: Text(controller.nomeUtente(riga['user_id'])),
            subtitle: Text('${riga['ambito']} · ${riga['anno_accademico']}'),
            trailing: FilledButton.tonal(
              onPressed: () async {
                final errore = await controller.cambiaAbilitazione(riga, !attiva);
                if (errore != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(errore)),
                  );
                }
              },
              child: Text(attiva ? 'Revoca' : 'Abilita'),
            ),
          ),
        );
      },
    );
  }
}
