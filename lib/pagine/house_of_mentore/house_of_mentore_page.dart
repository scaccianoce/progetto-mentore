import 'package:flutter/material.dart';

import '../../dinamico/maschera_dinamica_controller.dart';
import '../../dinamico/maschera_dinamica_widget.dart';
import '../../sessione_controller.dart';
import '../template/componenti_pagina_dinamica.dart';
import '../template/template_elenco_dettaglio_page.dart';
import 'house_of_mentore_controller.dart';

class HouseOfMentorePage extends StatefulWidget {
  const HouseOfMentorePage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<HouseOfMentorePage> createState() => _HouseOfMentorePageState();
}

class _HouseOfMentorePageState extends State<HouseOfMentorePage> {
  late final HouseOfMentoreController controller;

  bool get _partecipante => widget.sessione.ruolo == AppRole.participant;

  /// PERSONALIZZAZIONE HOUSE OF MENTORE:
  /// il layout resta nel template, qui rimangono solo tipi e vincoli speciali.
  ConfigurazionePaginaDinamica get _configurazioneEvento =>
      ConfigurazionePaginaDinamica(
        tabella: 'house_of_mentore',
        campi: <String, PersonalizzazioneCampo>{
          'titolo': const PersonalizzazioneCampo(
            modificabilePartecipante: false,
          ),
          'descrizione': const PersonalizzazioneCampo(
            tipo: TipoCampoDinamico.testoFormattato,
            modificabilePartecipante: false,
          ),
          'anno_accademico': PersonalizzazioneCampo(
            tipo: TipoCampoDinamico.scelta,
            valoriScelta: controller.anniAccademici,
            modificabilePartecipante: false,
          ),
          for (final campo in <String>[
            'data_evento',
            'luogo',
            'locandina_url',
            'iscrizioni_aperte',
          ])
            campo: const PersonalizzazioneCampo(
              modificabilePartecipante: false,
            ),
        },
      );

  static const _configurazioneOpzione = ConfigurazionePaginaDinamica(
    tabella: 'house_of_mentore_opzioni',
    campi: <String, PersonalizzazioneCampo>{
      'evento_id': PersonalizzazioneCampo(nascosto: true),
    },
  );

  @override
  void initState() {
    super.initState();
    controller = HouseOfMentoreController(widget.sessione)..carica();
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
      caricamento: controller.caricamento && controller.eventi.isEmpty,
      errore: controller.errore,
      vuoto: controller.eventi.isEmpty,
      messaggioVuoto: 'Nessuna iniziativa disponibile.',
      larghezzaElenco: 340,
      intestazione: IntestazionePaginaDinamica(
        titolo: 'House of Mentore',
        onAggiorna: controller.carica,
        onNuovo: controller.puoGestire ? () => _apriEditorEvento() : null,
      ),
      elenco: ElencoRecordDinamico<Map<String, dynamic>>(
        elementi: controller.eventi,
        idSelezionato: controller.eventoSelezionatoId,
        id: (evento) => evento['id'].toString(),
        titolo: (evento) => _testo(evento['titolo']),
        sottotitolo: (evento) =>
            '${_data(evento['data_evento'])} · ${_testo(evento['anno_accademico'])}',
        leading: (_) => const Icon(Icons.home_work_outlined),
        trailing: (evento) =>
            controller.iscrizione(evento['id'].toString()) == null
            ? null
            : const Icon(Icons.check_circle, color: Colors.green),
        onSeleziona: controller.seleziona,
      ),
      dettaglio: controller.eventoSelezionato == null
          ? const Center(child: Text('Seleziona un’iniziativa.'))
          : Card(
              margin: EdgeInsets.zero,
              child: _dettaglio(controller.eventoSelezionato!),
            ),
    ),
  );

  Widget _dettaglio(Map<String, dynamic> evento) {
    final eventoId = evento['id'].toString();
    final opzioni = controller.opzioni(eventoId);
    final iscrizione = controller.iscrizione(eventoId);
    final iscrizioniAperte = evento['iscrizioni_aperte'] == true;
    final locandina = _testo(evento['locandina_url']);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        if (locandina.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              locandina,
              height: 260,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 100,
                child: Center(child: Text('Locandina non disponibile.')),
              ),
            ),
          ),
        CampiTabellaDinamici(
          configurazione: _configurazioneEvento,
          valori: evento,
          partecipante: _partecipante,
        ),
        const Divider(height: 32),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Alternative di partecipazione',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (controller.puoGestire)
              TextButton.icon(
                onPressed: () => _apriEditorOpzione(eventoId),
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi'),
              ),
          ],
        ),
        if (opzioni.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Le alternative non sono ancora disponibili.'),
          )
        else
          for (final opzione in opzioni)
            _OpzioneTile(
              opzione: opzione,
              selezionata:
                  iscrizione?['opzione_id']?.toString() ==
                  opzione['id'].toString(),
              abilitata: iscrizioniAperte,
              puoGestire: controller.puoGestire,
              onScegli: () => _scegli(eventoId, opzione['id'].toString()),
              onModifica: () => _apriEditorOpzione(eventoId, opzione: opzione),
              onElimina: () => _eliminaOpzione(opzione),
            ),
        if (!iscrizioniAperte)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Le iscrizioni non sono aperte.'),
          ),
        if (iscrizione != null)
          TextButton.icon(
            onPressed: iscrizioniAperte
                ? () => _cancellaIscrizione(eventoId)
                : null,
            icon: const Icon(Icons.event_busy),
            label: const Text('Cancella la mia iscrizione'),
          ),
        if (controller.puoGestire) ...<Widget>[
          const Divider(height: 32),
          _elencoIscritti(evento),
          const Divider(height: 32),
          Wrap(
            spacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _apriEditorEvento(evento),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modifica evento'),
              ),
              OutlinedButton.icon(
                onPressed: () => _eliminaEvento(evento),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Elimina evento'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _elencoIscritti(Map<String, dynamic> evento) {
    final eventoId = evento['id'].toString();
    final iscritti = controller.iscritti(eventoId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Iscritti (${iscritti.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (iscritti.isEmpty)
          const Text('Nessun partecipante iscritto.')
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('#'), numeric: true),
                DataColumn(label: Text('Partecipante')),
                DataColumn(label: Text('Opzione scelta')),
                DataColumn(label: Text('Presente')),
              ],
              rows: <DataRow>[
                for (var indice = 0; indice < iscritti.length; indice++)
                  DataRow(
                    cells: <DataCell>[
                      DataCell(Text('${indice + 1}')),
                      DataCell(
                        Text(
                          controller.nomePartecipante(
                            iscritti[indice]['partecipante_id']?.toString() ?? '',
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          controller.descrizioneOpzione(
                            eventoId,
                            iscritti[indice]['opzione_id'],
                          ),
                        ),
                      ),
                      DataCell(
                        Checkbox(
                          value: iscritti[indice]['presente'] == true,
                          onChanged: (valore) async {
                            if (valore == null) return;
                            final errore = await controller.aggiornaPresenza(
                              eventoId: eventoId,
                              partecipanteId:
                                  iscritti[indice]['partecipante_id']?.toString() ?? '',
                              presente: valore,
                            );
                            _esito(errore, 'Presenza aggiornata.');
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _scegli(String eventoId, String opzioneId) async {
    final errore = await controller.scegliOpzione(
      eventoId: eventoId,
      opzioneId: opzioneId,
    );
    _esito(errore, 'Scelta registrata.');
  }

  Future<void> _cancellaIscrizione(String eventoId) async {
    final conferma = await _conferma(
      'Cancellare l’iscrizione?',
      'Potrai iscriverti nuovamente finché le iscrizioni saranno aperte.',
    );
    if (!conferma) return;
    final errore = await controller.cancellaIscrizione(eventoId);
    _esito(errore, 'Iscrizione cancellata.');
  }

  Future<void> _apriEditorEvento([Map<String, dynamic>? evento]) async {
    final dati = await mostraMascheraDinamica(
      context: context,
      configurazione: _configurazioneEvento,
      valoriIniziali:
          evento ??
          <String, dynamic>{
            'titolo': '',
            'anno_accademico': controller.anniAccademici.isEmpty
                ? null
                : controller.anniAccademici.first,
            'iscrizioni_aperte': false,
          },
      partecipante: _partecipante,
      titolo: evento == null ? 'Nuovo evento' : 'Modifica evento',
    );
    if (dati == null) return;
    final errore = await controller.salvaEvento(
      id: evento?['id']?.toString(),
      dati: dati,
    );
    _esito(errore, 'Evento salvato.');
  }

  Future<void> _apriEditorOpzione(
    String eventoId, {
    Map<String, dynamic>? opzione,
  }) async {
    final dati = await mostraMascheraDinamica(
      context: context,
      configurazione: _configurazioneOpzione,
      valoriIniziali:
          opzione ??
          <String, dynamic>{
            'evento_id': eventoId,
            'descrizione': '',
            'ordine_visualizzazione': 0,
          },
      partecipante: false,
      titolo: opzione == null ? 'Nuova alternativa' : 'Modifica alternativa',
    );
    if (dati == null) return;
    final errore = await controller.salvaOpzione(
      id: opzione?['id']?.toString(),
      eventoId: eventoId,
      descrizione: dati['descrizione'].toString(),
      ordine: (dati['ordine_visualizzazione'] as num).toInt(),
    );
    _esito(errore, 'Alternativa salvata.');
  }

  Future<void> _eliminaEvento(Map<String, dynamic> evento) async {
    final conferma = await _conferma(
      'Eliminare House of Mentore?',
      'Verranno eliminate anche le relative alternative.',
    );
    if (!conferma) return;
    final errore = await controller.eliminaEvento(evento['id'].toString());
    _esito(errore, 'Evento eliminato.');
  }

  Future<void> _eliminaOpzione(Map<String, dynamic> opzione) async {
    final conferma = await _conferma(
      'Eliminare l’alternativa?',
      _testo(opzione['descrizione']),
    );
    if (!conferma) return;
    final errore = await controller.eliminaOpzione(opzione['id'].toString());
    _esito(errore, 'Alternativa eliminata.');
  }

  Future<bool> _conferma(String titolo, String testo) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(titolo),
          content: Text(testo),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Conferma'),
            ),
          ],
        ),
      ) ??
      false;

  void _esito(String? errore, String successo) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errore ?? successo)));
  }
}

class _OpzioneTile extends StatelessWidget {
  const _OpzioneTile({
    required this.opzione,
    required this.selezionata,
    required this.abilitata,
    required this.puoGestire,
    required this.onScegli,
    required this.onModifica,
    required this.onElimina,
  });

  final Map<String, dynamic> opzione;
  final bool selezionata;
  final bool abilitata;
  final bool puoGestire;
  final VoidCallback onScegli;
  final VoidCallback onModifica;
  final VoidCallback onElimina;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        selezionata ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selezionata
            ? Theme.of(context).colorScheme.primary
            : abilitata
            ? null
            : Theme.of(context).disabledColor,
      ),
      title: Text(_testo(opzione['descrizione'])),
      onTap: abilitata ? onScegli : null,
      trailing: puoGestire
          ? PopupMenuButton<String>(
              onSelected: (valore) =>
                  valore == 'modifica' ? onModifica() : onElimina(),
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem(value: 'modifica', child: Text('Modifica')),
                PopupMenuItem(value: 'elimina', child: Text('Elimina')),
              ],
            )
          : null,
    ),
  );
}

String _testo(Object? valore) => valore?.toString().trim() ?? '';

String _data(Object? valore) {
  final data = valore is DateTime ? valore : DateTime.tryParse(_testo(valore));
  if (data == null) return '—';
  return '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/${data.year}';
}
