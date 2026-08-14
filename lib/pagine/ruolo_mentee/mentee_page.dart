import 'package:flutter/material.dart';

import '../../dinamico/maschera_dinamica_controller.dart';
import '../../sessione_controller.dart';
import '../template/pagina_scheda_dinamica.dart';
import 'mentee_controller.dart';

class MenteePage extends StatefulWidget {
  const MenteePage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<MenteePage> createState() => _MenteePageState();
}

class _MenteePageState extends State<MenteePage> {
  /// PERSONALIZZAZIONE MENTEE:
  /// i tipi dei campi mentoraggio sono condivisi a livello di tabella; qui
  /// resta solo il vincolo specifico del partecipante.
  static const configurazione = ConfigurazionePaginaDinamica(
    tabella: 'mentoraggi',
    campi: <String, PersonalizzazioneCampo>{
      'osservazioni_aula': PersonalizzazioneCampo(
        modificabilePartecipante: false,
      ),
      'osservazioni_focus_group': PersonalizzazioneCampo(
        modificabilePartecipante: false,
      ),
      'scheda_sintesi': PersonalizzazioneCampo(
        modificabilePartecipante: false,
      ),
    },
  );

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
      final mentoraggio = controller.mentoraggio;
      final messaggioVuoto = controller.insegnamento == null
          ? 'Nessun insegnamento per l’anno corrente.'
          : 'Mentoraggio non ancora disponibile.';
      return PaginaSchedaDinamica(
        titolo: 'Ruolo mentee',
        configurazione: configurazione,
        valori: mentoraggio,
        partecipante: widget.sessione.ruolo == AppRole.participant,
        caricamento: controller.caricamento,
        errore: controller.errore,
        vuoto: mentoraggio == null,
        messaggioVuoto: messaggioVuoto,
        primaDeiCampi: mentoraggio == null
            ? const <Widget>[]
            : <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    controller.insegnamento!['insegnamento']?.toString() ?? '',
                  ),
                  subtitle: Text(
                    controller.insegnamento!['anno_accademico']?.toString() ?? '',
                  ),
                ),
                const Divider(height: 28),
                Text(
                  'Team di mentoraggio',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ...controller.mentori.map(
                  (mentore) => ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(
                      '${mentore['nome'] ?? ''} ${mentore['cognome'] ?? ''}'.trim(),
                    ),
                    subtitle: Text(
                      '${mentore['tipo'] ?? ''} · ${mentore['email_unipa'] ?? ''}',
                    ),
                  ),
                ),
                const Divider(height: 28),
              ],
      );
    },
  );
}
