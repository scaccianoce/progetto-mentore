import 'package:flutter/material.dart';

import '../../app_exception.dart';
import '../../dinamico/maschera_dinamica_controller.dart';
import '../../dinamico/maschera_dinamica_widget.dart';
import '../../sessione_controller.dart';
import '../template/componenti_pagina_dinamica.dart';
import '../template/template_elenco_dettaglio_page.dart';
import 'mentore_controller.dart';

class MentorePage extends StatefulWidget {
  const MentorePage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<MentorePage> createState() => _MentorePageState();
}

class _MentorePageState extends State<MentorePage> {
  /// PERSONALIZZAZIONE MENTORE:
  /// la configurazione standard della tabella mentoraggi e centralizzata in
  /// ConfigurazioneMaschere; questa pagina non ripete piu i campi.
  static const configurazione = ConfigurazionePaginaDinamica(
    tabella: 'mentoraggi',
  );

  late final MentoreController controller;

  bool get _partecipante => widget.sessione.ruolo == AppRole.participant;

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
    builder: (context, _) => TemplatePaginaElencoDettaglio(
      caricamento: controller.caricamento && controller.percorsi.isEmpty,
      errore: controller.errore,
      vuoto: controller.percorsi.isEmpty,
      messaggioVuoto: 'Nessun mentoraggio assegnato.',
      larghezzaElenco: 340,
      elenco: ElencoRecordDinamico<PercorsoMentore>(
        elementi: controller.percorsi,
        idSelezionato: controller.selezionato?.mentoraggio['id']?.toString(),
        id: (percorso) => percorso.mentoraggio['id']?.toString() ?? '',
        titolo: (percorso) =>
            percorso.insegnamento['insegnamento']?.toString() ?? '',
        sottotitolo: (percorso) =>
            '${percorso.docente['nome'] ?? ''} ${percorso.docente['cognome'] ?? ''}'
                .trim(),
        onSeleziona: controller.seleziona,
      ),
      dettaglio: Card(margin: EdgeInsets.zero, child: _dettaglio()),
    ),
  );

  Widget _dettaglio() {
    final percorso = controller.selezionato;
    if (percorso == null) {
      return const Center(child: Text('Seleziona un mentoraggio.'));
    }
    return DettaglioRecordDinamico(
      configurazione: configurazione,
      valori: percorso.mentoraggio,
      partecipante: _partecipante,
      prima: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Ruolo mentore',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: controller.salvataggio ? null : _modifica,
              icon: const Icon(Icons.edit),
              label: const Text('Modifica'),
            ),
          ],
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Insegnamento'),
          subtitle: Text(
            percorso.insegnamento['insegnamento']?.toString() ?? '',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Mentee',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${percorso.docente['nome'] ?? ''} ${percorso.docente['cognome'] ?? ''}'
                .trim(),
          ),
        ),
        const Divider(),
        Text('Team', style: Theme.of(context).textTheme.titleMedium),
        ...percorso.team.map(
          (mentore) => ListTile(
            title: Text(
              '${mentore['nome'] ?? ''} ${mentore['cognome'] ?? ''}'.trim(),
            ),
            subtitle: Text(mentore['tipo']?.toString() ?? ''),
          ),
        ),
        const Divider(),
      ],
    );
  }

  Future<void> _modifica() async {
    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: configurazione,
      valoriIniziali: controller.selezionato!.mentoraggio,
      partecipante: _partecipante,
      titolo: 'Aggiorna mentoraggio',
    );
    if (valori == null) return;
    try {
      await controller.salvaMentoraggio(valori);
    } on AppException catch (errore) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errore.messaggio)));
      }
    }
  }
}
