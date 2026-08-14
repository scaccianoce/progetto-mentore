import 'package:flutter/material.dart';

import '../../dinamico/maschera_dinamica_controller.dart';
import '../../sessione_controller.dart';
import '../template/componenti_pagina_dinamica.dart';
import '../template/template_elenco_dettaglio_page.dart';
import 'contatti_controller.dart';

class ContattiPage extends StatefulWidget {
  const ContattiPage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<ContattiPage> createState() => _ContattiPageState();
}

class _ContattiPageState extends State<ContattiPage> {
  /// PERSONALIZZAZIONE CONTATTI - tabella di riferimento: Anagrafica.
  ///
  /// La pagina e di sola consultazione, quindi non servono vincoli di modifica.
  /// Si dichiarano solo i campi da non mostrare nel dettaglio e le etichette
  /// che non possono essere dedotte correttamente dal nome della colonna.
  static const configurazione = ConfigurazionePaginaDinamica(
    tabella: 'anagrafica',
    campi: <String, PersonalizzazioneCampo>{
      'user_id': PersonalizzazioneCampo(nascosto: true),
      'nome': PersonalizzazioneCampo(nascosto: true),
      'cognome': PersonalizzazioneCampo(nascosto: true),
      'email_unipa': PersonalizzazioneCampo(etichetta: 'Email'),
      'cod_ssd': PersonalizzazioneCampo(etichetta: 'SSD'),
      'pagina_personale_unipa': PersonalizzazioneCampo(
        etichetta: 'Pagina personale',
      ),
    },
  );

  late final ContattiController _controller;

  bool get _partecipante => widget.sessione.ruolo == AppRole.participant;

  @override
  void initState() {
    super.initState();
    _controller = ContattiController()..carica();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final selezionato = _controller.selezionato;
      return TemplatePaginaElencoDettaglio(
        caricamento: _controller.caricamento && _controller.contatti.isEmpty,
        errore: _controller.errore,
        vuoto: _controller.contatti.isEmpty,
        messaggioVuoto: 'Nessun contatto disponibile.',
        intestazione: TextField(
          onChanged: _controller.cerca,
          decoration: const InputDecoration(
            labelText: 'Cerca per nome, email o SSD',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        elenco: ElencoRecordDinamico<Map<String, dynamic>>(
          elementi: _controller.contatti,
          idSelezionato: selezionato?['user_id']?.toString(),
          id: (contatto) => contatto['user_id']?.toString() ?? '',
          titolo: (contatto) =>
              '${contatto['cognome'] ?? ''} ${contatto['nome'] ?? ''}'.trim(),
          sottotitolo: (contatto) =>
              contatto['email_unipa']?.toString() ?? '',
          leading: (_) => const CircleAvatar(
            child: Icon(Icons.person_outline),
          ),
          onSeleziona: _controller.seleziona,
        ),
        dettaglio: Card(
          margin: EdgeInsets.zero,
          child: selezionato == null
              ? const Center(child: Text('Seleziona un contatto.'))
              : DettaglioRecordDinamico(
                  configurazione: configurazione,
                  valori: selezionato,
                  partecipante: _partecipante,
                  padding: const EdgeInsets.all(24),
                  prima: <Widget>[
                    Text(
                      '${selezionato['nome'] ?? ''} ${selezionato['cognome'] ?? ''}'
                          .trim(),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Divider(height: 28),
                  ],
                ),
        ),
      );
    },
  );
}
