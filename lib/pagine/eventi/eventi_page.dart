import 'package:flutter/material.dart';

import '../../dinamico/maschera_dinamica_controller.dart';
import '../../dinamico/maschera_dinamica_widget.dart';
import '../../sessione_controller.dart';
import '../template/componenti_pagina_dinamica.dart';
import '../template/template_elenco_dettaglio_page.dart';
import 'eventi_controller.dart';

class EventiPage extends StatefulWidget {
  const EventiPage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<EventiPage> createState() => _EventiPageState();
}

class _EventiPageState extends State<EventiPage> {
  late final EventiController controller;

  bool get _partecipante => widget.sessione.ruolo == AppRole.participant;

  /// PERSONALIZZAZIONE EVENTI: solo tipi, scelte e vincoli speciali.
  ConfigurazionePaginaDinamica get _configurazione =>
      ConfigurazionePaginaDinamica(
        tabella: 'eventi',
        campi: <String, PersonalizzazioneCampo>{
          'titolo': const PersonalizzazioneCampo(
            modificabilePartecipante: false,
          ),
          'anno_accademico': PersonalizzazioneCampo(
            tipo: TipoCampoDinamico.scelta,
            valoriScelta: controller.anniAccademici,
            modificabilePartecipante: false,
          ),
          'data_evento': const PersonalizzazioneCampo(
            modificabilePartecipante: false,
          ),
          'tipologia': const PersonalizzazioneCampo(
            // Opzioni lette dal PostgreSQL ENUM del DB.
            modificabilePartecipante: false,
          ),
          'modalita': const PersonalizzazioneCampo(
            // Opzioni lette dal PostgreSQL ENUM del DB.
            modificabilePartecipante: false,
          ),
          'descrizione': const PersonalizzazioneCampo(
            tipo: TipoCampoDinamico.testoFormattato,
            modificabilePartecipante: false,
          ),
          'relatori': const PersonalizzazioneCampo(
            modificabilePartecipante: false,
          ),
          'moderatori': const PersonalizzazioneCampo(
            modificabilePartecipante: false,
          ),
          'note_organizzative': const PersonalizzazioneCampo(
            modificabilePartecipante: false,
          ),
          for (final campo in <String>[
            'luogo',
            'locandina_path',
            'modulo_partecipazione_url',
            'data_apertura_iscrizioni',
            'data_chiusura_iscrizioni',
          ])
            campo: const PersonalizzazioneCampo(
              modificabilePartecipante: false,
            ),
          'attiva': PersonalizzazioneCampo(
            // Nascosto ai partecipanti; owner/organizer possono decidere
            // direttamente se l'evento e pubblicato.
            nascosto: _partecipante,
            modificabilePartecipante: false,
          ),
          'questionario_gradimento_attivo': const PersonalizzazioneCampo(
            visibilePartecipante: false,
            modificabilePartecipante: false,
          ),
          'link_questionario_gradimento': const PersonalizzazioneCampo(
            visibilePartecipante: false,
            modificabilePartecipante: false,
          ),
        },
      );

  @override
  void initState() {
    super.initState();
    controller = EventiController(widget.sessione)..carica();
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
      messaggioVuoto: 'Nessun evento disponibile.',
      larghezzaElenco: 340,
      intestazione: IntestazionePaginaDinamica(
        titolo: 'Eventi',
        onAggiorna: controller.carica,
        onNuovo: controller.puoGestire ? () => _apriEditor() : null,
      ),
      elenco: ElencoRecordDinamico<Map<String, dynamic>>(
        elementi: controller.eventi,
        idSelezionato: controller.eventoSelezionatoId,
        id: (evento) => evento['id'].toString(),
        titolo: (evento) => evento['titolo']?.toString() ?? '',
        sottotitolo: (evento) => _data(evento['data_evento']),
        trailing: (evento) => controller.iscritto(evento['id'].toString())
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
        onSeleziona: controller.seleziona,
      ),
      dettaglio: controller.eventoSelezionato == null
          ? const Center(child: Text('Seleziona un evento.'))
          : Card(
              margin: EdgeInsets.zero,
              child: _dettaglio(controller.eventoSelezionato!),
            ),
    ),
  );

  Widget _dettaglio(Map<String, dynamic> evento) {
    final id = evento['id'].toString();
    final iscritto = controller.iscritto(id);
    final aperte = controller.iscrizioniAperte(evento);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        CampiTabellaDinamici(
          configurazione: _configurazione,
          valori: evento,
          partecipante: _partecipante,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: aperte ? () => _cambiaIscrizione(evento) : null,
          icon: Icon(iscritto ? Icons.event_busy : Icons.event_available),
          label: Text(iscritto ? 'Annulla iscrizione' : 'Iscriviti'),
        ),
        if (!aperte)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Le iscrizioni non sono aperte.'),
          ),
        if (iscritto &&
            evento['questionario_gradimento_attivo'] == true &&
            _testo(evento['link_questionario_gradimento']).isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Questionario di gradimento',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SelectableText(_testo(evento['link_questionario_gradimento'])),
        ],
        if (controller.puoGestire) ...[
          const Divider(height: 32),
          _elencoIscrittiEvento(evento),
          const Divider(height: 32),
          Wrap(
            spacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _apriEditor(evento),
                icon: const Icon(Icons.edit),
                label: const Text('Modifica'),
              ),
              OutlinedButton.icon(
                onPressed: () => _elimina(evento),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Elimina'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _elencoIscrittiEvento(Map<String, dynamic> evento) {
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
                DataColumn(label: Text('Presente')),
                DataColumn(label: Text('Questionario compilato')),
                DataColumn(label: Text('Data compilazione')),
              ],
              rows: <DataRow>[
                for (var indice = 0; indice < iscritti.length; indice++)
                  _rigaIscrittoEvento(
                    eventoId: eventoId,
                    indice: indice,
                    partecipazione: iscritti[indice],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  DataRow _rigaIscrittoEvento({
    required String eventoId,
    required int indice,
    required Map<String, dynamic> partecipazione,
  }) {
    final partecipanteId = partecipazione['partecipante_id']?.toString() ?? '';
    final presente = partecipazione['presente'] == true;
    final questionario = partecipazione['questionario_compilato'] == true;
    final dataCompilazione = DateTime.tryParse(
      partecipazione['data_compilazione']?.toString() ?? '',
    );

    Future<void> salva({
      bool? nuovoPresente,
      bool? nuovoQuestionario,
      DateTime? nuovaData,
      bool modificaData = false,
    }) async {
      final errore = await controller.aggiornaPartecipazione(
        eventoId: eventoId,
        partecipanteId: partecipanteId,
        presente: nuovoPresente ?? presente,
        questionarioCompilato: nuovoQuestionario ?? questionario,
        dataCompilazione: modificaData ? nuovaData : dataCompilazione,
      );
      if (!mounted || errore == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errore)),
      );
    }

    return DataRow(
      cells: <DataCell>[
        DataCell(Text('${indice + 1}')),
        DataCell(Text(controller.nomePartecipante(partecipanteId))),
        DataCell(
          Checkbox(
            value: presente,
            onChanged: (valore) {
              if (valore != null) salva(nuovoPresente: valore);
            },
          ),
        ),
        DataCell(
          Checkbox(
            value: questionario,
            onChanged: (valore) {
              if (valore != null) salva(nuovoQuestionario: valore);
            },
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(dataCompilazione == null ? '—' : _data(dataCompilazione)),
              IconButton(
                tooltip: 'Modifica data compilazione',
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () async {
                  final scelta = await showDatePicker(
                    context: context,
                    initialDate: dataCompilazione ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2200),
                  );
                  if (scelta != null) {
                    await salva(nuovaData: scelta, modificaData: true);
                  }
                },
              ),
              if (dataCompilazione != null)
                IconButton(
                  tooltip: 'Cancella data compilazione',
                  icon: const Icon(Icons.clear),
                  onPressed: () => salva(nuovaData: null, modificaData: true),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _cambiaIscrizione(Map<String, dynamic> evento) async {
    final errore = await controller.cambiaIscrizione(evento);
    if (mounted && errore != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errore)));
    }
  }

  Future<void> _apriEditor([Map<String, dynamic>? evento]) async {
    final iniziali =
        evento ??
        <String, dynamic>{
          'titolo': '',
          'anno_accademico': controller.anniAccademici.isEmpty
              ? null
              : controller.anniAccademici.first,
          'questionario_gradimento_attivo': false,
          'attiva': true,
        };
    final risultato = await mostraMascheraDinamica(
      context: context,
      configurazione: _configurazione,
      valoriIniziali: iniziali,
      partecipante: _partecipante,
      titolo: evento == null ? 'Nuovo evento' : 'Modifica evento',
    );
    if (risultato == null) return;
    final errore = await controller.salva(
      id: evento?['id']?.toString(),
      dati: risultato,
    );
    if (mounted && errore != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errore)));
    }
  }

  Future<void> _elimina(Map<String, dynamic> evento) async {
    final conferma =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Eliminare l’evento?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sì'),
              ),
            ],
          ),
        ) ??
        false;
    if (!conferma) return;
    final errore = await controller.elimina(evento['id'].toString());
    if (mounted && errore != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errore)));
    }
  }
}

String _testo(Object? valore) => valore?.toString().trim() ?? '';

String _data(Object? valore) {
  final data = DateTime.tryParse(_testo(valore));
  if (data == null) return _testo(valore);
  return '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/${data.year}';
}
