import 'package:flutter/material.dart';

import '../../sessione_controller.dart';
import 'eventi_controller.dart';

class EventiPage extends StatefulWidget {
  const EventiPage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<EventiPage> createState() => _EventiPageState();
}

class _EventiPageState extends State<EventiPage> {
  late final EventiController controller;

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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Eventi',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: controller.carica,
                  icon: const Icon(Icons.refresh),
                ),
                if (controller.puoGestire)
                  FilledButton.icon(
                    onPressed: () => _apriEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nuovo'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: _corpo()),
          ],
        ),
      ),
    );
  }

  Widget _corpo() {
    if (controller.caricamento && controller.eventi.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.errore != null && controller.eventi.isEmpty) {
      return Center(child: Text(controller.errore!));
    }
    if (controller.eventi.isEmpty) {
      return const Center(child: Text('Nessun evento disponibile.'));
    }
    final elenco = _elenco();
    final dettaglio = _dettaglio(controller.eventoSelezionato!);
    return LayoutBuilder(
      builder: (context, vincoli) {
        if (vincoli.maxWidth >= 850) {
          return Row(
            children: [
              SizedBox(width: 340, child: elenco),
              const VerticalDivider(width: 1),
              Expanded(child: dettaglio),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(height: 230, child: elenco),
            const Divider(height: 1),
            Expanded(child: dettaglio),
          ],
        );
      },
    );
  }

  Widget _elenco() => ListView.builder(
    itemCount: controller.eventi.length,
    itemBuilder: (context, indice) {
      final evento = controller.eventi[indice];
      final id = evento['id'].toString();
      return ListTile(
        selected: id == controller.eventoSelezionatoId,
        title: Text(
          evento['titolo']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(_data(evento['data_evento'])),
        trailing: controller.iscritto(id)
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
        onTap: () => controller.seleziona(evento),
      );
    },
  );

  Widget _dettaglio(Map<String, dynamic> evento) {
    final id = evento['id'].toString();
    final iscritto = controller.iscritto(id);
    final aperte = controller.iscrizioniAperte(evento);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            evento['titolo']?.toString() ?? '',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.blue.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _riga('Data', _data(evento['data_evento'])),
          _riga('Anno accademico', evento['anno_accademico']),
          _riga('Tipologia', evento['tipologia']),
          _riga('Modalità', evento['modalita']),
          _riga('Luogo', evento['luogo']),
          _riga('Descrizione', evento['descrizione']),
          _riga('Relatori', evento['relatori']),
          _riga('Moderatori', evento['moderatori']),
          _riga('Note organizzative', evento['note_organizzative']),
          _riga('Locandina', evento['locandina_path']),
          _riga(
            'Modulo di partecipazione',
            evento['modulo_partecipazione_url'],
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
            SelectableText(
              _testo(evento['link_questionario_gradimento']),
              style: const TextStyle(color: Colors.blue),
            ),
          ],
          if (controller.puoGestire) ...[
            const Divider(height: 32),
            Wrap(
              spacing: 8,
              children: [
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
      ),
    );
  }

  Widget _riga(String etichetta, Object? valore) {
    final testo = _testo(valore);
    if (testo.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$etichetta: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: testo),
          ],
        ),
      ),
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
    final risultato = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EventoEditor(evento: evento),
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
            actions: [
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

class _EventoEditor extends StatefulWidget {
  const _EventoEditor({this.evento});
  final Map<String, dynamic>? evento;
  @override
  State<_EventoEditor> createState() => _EventoEditorState();
}

class _EventoEditorState extends State<_EventoEditor> {
  final form = GlobalKey<FormState>();
  final campi = <String, TextEditingController>{};
  DateTime? dataEvento;
  DateTime? aperturaIscrizioni;
  DateTime? chiusuraIscrizioni;
  String tipologia = 'Altro';
  String modalita = 'In presenza';
  bool questionario = false;

  static const etichette = <String, String>{
    'titolo': 'Titolo',
    'anno_accademico': 'Anno accademico',
    'data_evento': 'Data (AAAA-MM-GG)',
    'luogo': 'Luogo',
    'descrizione': 'Descrizione',
    'relatori': 'Relatori',
    'moderatori': 'Moderatori',
    'note_organizzative': 'Note organizzative',
    'locandina_path': 'Link/path locandina',
    'modulo_partecipazione_url': 'Modulo di partecipazione',
    'data_apertura_iscrizioni': 'Apertura iscrizioni (AAAA-MM-GG)',
    'data_chiusura_iscrizioni': 'Chiusura iscrizioni (AAAA-MM-GG)',
    'link_questionario_gradimento': 'Link questionario',
  };

  @override
  void initState() {
    super.initState();
    for (final chiave in etichette.keys) {
      campi[chiave] = TextEditingController(
        text: _testo(widget.evento?[chiave]),
      );
    }
    dataEvento = DateTime.tryParse(_testo(widget.evento?['data_evento']));
    aperturaIscrizioni = DateTime.tryParse(
      _testo(widget.evento?['data_apertura_iscrizioni']),
    );
    chiusuraIscrizioni = DateTime.tryParse(
      _testo(widget.evento?['data_chiusura_iscrizioni']),
    );
    tipologia = _testo(widget.evento?['tipologia']).isEmpty
        ? 'Altro'
        : _testo(widget.evento?['tipologia']);
    modalita = _testo(widget.evento?['modalita']).isEmpty
        ? 'In presenza'
        : _testo(widget.evento?['modalita']);
    questionario = widget.evento?['questionario_gradimento_attivo'] == true;
  }

  @override
  void dispose() {
    for (final c in campi.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.evento == null ? 'Nuovo evento' : 'Modifica evento'),
    content: SizedBox(
      width: 620,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (final voce in etichette.entries)
                if (voce.key != 'data_evento' &&
                    voce.key != 'data_apertura_iscrizioni' &&
                    voce.key != 'data_chiusura_iscrizioni')
                  TextFormField(
                    controller: campi[voce.key],
                    decoration: InputDecoration(labelText: voce.value),
                    maxLines:
                        const {
                          'descrizione',
                          'luogo',
                          'note_organizzative',
                        }.contains(voce.key)
                        ? 3
                        : 1,
                    validator:
                        voce.key == 'titolo' || voce.key == 'anno_accademico'
                            ? (v) => (v == null || v.trim().isEmpty)
                                  ? 'Campo obbligatorio'
                                  : null
                            : null,
                  ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  dataEvento == null
                      ? etichette['data_evento']!
                      : 'Data evento: ${_data(dataEvento)}',
                ),
                trailing: Wrap(
                  children: [
                    if (dataEvento != null)
                      IconButton(
                        tooltip: 'Rimuovi data evento',
                        onPressed: () => setState(() => dataEvento = null),
                        icon: const Icon(Icons.clear),
                      ),
                    IconButton(
                      tooltip: 'Scegli data evento',
                      onPressed: () => _scegliData((valore) {
                        setState(() => dataEvento = valore);
                      }, dataEvento),
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ],
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  aperturaIscrizioni == null
                      ? etichette['data_apertura_iscrizioni']!
                      : 'Apertura iscrizioni: ${_data(aperturaIscrizioni)}',
                ),
                trailing: Wrap(
                  children: [
                    if (aperturaIscrizioni != null)
                      IconButton(
                        tooltip: 'Rimuovi apertura iscrizioni',
                        onPressed: () => setState(() => aperturaIscrizioni = null),
                        icon: const Icon(Icons.clear),
                      ),
                    IconButton(
                      tooltip: 'Scegli apertura iscrizioni',
                      onPressed: () => _scegliData((valore) {
                        setState(() => aperturaIscrizioni = valore);
                      }, aperturaIscrizioni),
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ],
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  chiusuraIscrizioni == null
                      ? etichette['data_chiusura_iscrizioni']!
                      : 'Chiusura iscrizioni: ${_data(chiusuraIscrizioni)}',
                ),
                trailing: Wrap(
                  children: [
                    if (chiusuraIscrizioni != null)
                      IconButton(
                        tooltip: 'Rimuovi chiusura iscrizioni',
                        onPressed: () => setState(() => chiusuraIscrizioni = null),
                        icon: const Icon(Icons.clear),
                      ),
                    IconButton(
                      tooltip: 'Scegli chiusura iscrizioni',
                      onPressed: () => _scegliData((valore) {
                        setState(() => chiusuraIscrizioni = valore);
                      }, chiusuraIscrizioni),
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ],
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: tipologia,
                decoration: const InputDecoration(labelText: 'Tipologia'),
                items:
                    [
                          'Incontro di approfondimento',
                          'Seminario',
                          'Workshop',
                          'Altro',
                        ]
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged: (v) => tipologia = v!,
              ),
              DropdownButtonFormField<String>(
                initialValue: modalita,
                decoration: const InputDecoration(labelText: 'Modalità'),
                items: ['In presenza', 'A distanza', 'Misto']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => modalita = v!,
              ),
              SwitchListTile(
                title: const Text('Questionario di gradimento attivo'),
                value: questionario,
                onChanged: (v) => setState(() => questionario = v),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
      FilledButton(onPressed: _salva, child: const Text('Salva')),
    ],
  );

  void _salva() {
    if (!(form.currentState?.validate() ?? false)) return;
    final dati = <String, dynamic>{
      for (final e in campi.entries)
        e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
    };
    dati['data_evento'] = dataEvento?.toIso8601String().split('T').first;
    dati['data_apertura_iscrizioni'] =
        aperturaIscrizioni?.toIso8601String().split('T').first;
    dati['data_chiusura_iscrizioni'] =
        chiusuraIscrizioni?.toIso8601String().split('T').first;
    dati['tipologia'] = tipologia;
    dati['modalita'] = modalita;
    dati['questionario_gradimento_attivo'] = questionario;
    Navigator.pop(context, dati);
  }

  Future<void> _scegliData(
    ValueChanged<DateTime?> onChanged,
    DateTime? valoreIniziale,
  ) async {
    final DateTime? scelta = await showDatePicker(
      context: context,
      initialDate: valoreIniziale ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    onChanged(scelta);
  }
}

String _testo(Object? valore) => valore?.toString().trim() ?? '';
String _data(Object? valore) {
  final data = DateTime.tryParse(_testo(valore));
  if (data == null) return _testo(valore);
  return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
}
