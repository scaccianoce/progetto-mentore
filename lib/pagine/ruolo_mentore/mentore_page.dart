import 'package:flutter/material.dart';

import '../../app_exception.dart';
import '../../dinamico/maschera_dinamica_controller.dart';
import '../../dinamico/maschera_dinamica_widget.dart';
import '../../sessione_controller.dart';
import '../backoffice/questionari_controller.dart';
import '../backoffice/questionario_mentoraggio_widget.dart';
import '../backoffice/scheda_sintesi_file_card.dart';
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
  static const configurazione = ConfigurazionePaginaDinamica(
    tabella: 'mentoraggi',
    campi: <String, PersonalizzazioneCampo>{
      'insegnamento_id': PersonalizzazioneCampo(nascosto: true),
      'anno_accademico': PersonalizzazioneCampo(modificabilePartecipante: false),
      'data_inizio': PersonalizzazioneCampo(modificabilePartecipante: false),
      'data_fine': PersonalizzazioneCampo(modificabilePartecipante: false),
      'numero_studenti': PersonalizzazioneCampo(modificabilePartecipante: false),
      'sede': PersonalizzazioneCampo(modificabilePartecipante: false),
      'note': PersonalizzazioneCampo(modificabilePartecipante: false),
      'azioni_miglioramento': PersonalizzazioneCampo(
        etichetta: 'Azioni di miglioramento',
      ),
      'svolgimento': PersonalizzazioneCampo(modificabilePartecipante: false),
      'giorni_orari_lezioni': PersonalizzazioneCampo(modificabilePartecipante: false),
      'scheda_sintesi_pdf_url': PersonalizzazioneCampo(nascosto: true),
    },
  );

  late final MentoreController controller;
  late final QuestionariController questionariController;

  @override
  void initState() {
    super.initState();
    controller = MentoreController()..carica();
    questionariController = QuestionariController(widget.sessione)..carica();
  }

  @override
  void dispose() {
    controller.dispose();
    questionariController.dispose();
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
          larghezzaElenco: 390,
          elenco: ElencoRecordDinamico<PercorsoMentore>(
            elementi: controller.percorsi,
            idSelezionato: controller.selezionato?.mentoraggio['id']?.toString(),
            id: (p) => p.mentoraggio['id']?.toString() ?? '',
            titolo: (p) => p.insegnamento['insegnamento']?.toString() ?? '',
            sottotitolo: (p) {
              final docente =
                  '${p.docente['nome'] ?? ''} ${p.docente['cognome'] ?? ''}'.trim();
              final anno = p.mentoraggio['anno_accademico']?.toString() ?? '';
              return '$docente · $anno · ${p.mioRuolo}';
            },
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
      partecipante: true,
      prima: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Ruolo mentore · ${percorso.mentoraggio['anno_accademico'] ?? ''}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (percorso.annoCorrente)
              FilledButton.icon(
                onPressed: controller.salvataggio ? null : _modifica,
                icon: const Icon(Icons.edit),
                label: const Text('Modifica'),
              ),
          ],
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Insegnamento', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(percorso.insegnamento['insegnamento']?.toString() ?? ''),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Semestre', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(percorso.insegnamento['semestre']?.toString() ?? ''),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mentee', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${percorso.docente['nome'] ?? ''} ${percorso.docente['cognome'] ?? ''}'.trim(),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ruolo svolto', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(percorso.mioRuolo.isEmpty ? '—' : percorso.mioRuolo),
        ),
        if (!percorso.annoCorrente)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.lock_outline),
            title: Text('Mentoraggio storico', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('I mentoraggi degli anni precedenti sono consultabili ma non modificabili.'),
          ),
        const Divider(),
        Text('Team', style: Theme.of(context).textTheme.titleMedium),
        ...percorso.team.map(
          (mentore) => ListTile(
            title: Text('${mentore['nome'] ?? ''} ${mentore['cognome'] ?? ''}'.trim()),
            subtitle: Text(mentore['tipo']?.toString() ?? ''),
          ),
        ),
        const Divider(),
      ],
      dopo: <Widget>[
        const Divider(height: 28),
        SchedaSintesiFileCard(
          mentoraggio: percorso.mentoraggio,
          onAggiornato: controller.carica,
        ),
      ],
    );
  }

  Future<void> _modifica() async {
    final percorso = controller.selezionato;
    if (percorso == null || !percorso.annoCorrente) return;
    await questionariController.carica();
    if (!mounted) return;
    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: configurazione,
      valoriIniziali: percorso.mentoraggio,
      partecipante: true,
      titolo:
          'Aggiorna ${percorso.insegnamento['insegnamento'] ?? ''} · ${percorso.mentoraggio['anno_accademico'] ?? ''}',
      contenutoExtra: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionarioMentoraggioCard(
            controller: questionariController,
            mentoraggioId: percorso.mentoraggio['id'].toString(),
          ),
          const SizedBox(height: 12),
          SchedaSintesiFileCard(
            mentoraggio: percorso.mentoraggio,
            onAggiornato: controller.carica,
          ),
        ],
      ),
    );
    if (valori == null) return;
    try {
      await controller.salvaMentoraggio(valori);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.messaggio)));
    }
  }
}
