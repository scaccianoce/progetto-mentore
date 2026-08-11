import 'package:flutter/material.dart';

import '../../sessione_controller.dart';
import 'house_of_mentore_controller.dart';

class HouseOfMentorePage extends StatefulWidget {
  const HouseOfMentorePage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<HouseOfMentorePage> createState() => _HouseOfMentorePageState();
}

class _HouseOfMentorePageState extends State<HouseOfMentorePage> {
  late final HouseOfMentoreController controller;

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
    builder: (context, _) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'House of Mentore',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Aggiorna',
                onPressed: controller.carica,
                icon: const Icon(Icons.refresh),
              ),
              if (controller.puoGestire)
                FilledButton.icon(
                  onPressed: () => _apriEditorEvento(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuovo'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: _contenuto()),
        ],
      ),
    ),
  );

  Widget _contenuto() {
    if (controller.caricamento && controller.eventi.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.errore != null && controller.eventi.isEmpty) {
      return Center(child: Text(controller.errore!));
    }
    if (controller.eventi.isEmpty) {
      return const Center(child: Text('Nessuna iniziativa disponibile.'));
    }

    final elenco = _elenco();
    final dettaglio = _dettaglio(controller.eventoSelezionato!);
    return LayoutBuilder(
      builder: (context, vincoli) {
        if (vincoli.maxWidth >= 850) {
          return Row(
            children: [
              SizedBox(width: 340, child: elenco),
              const VerticalDivider(width: 24),
              Expanded(child: dettaglio),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(height: 220, child: elenco),
            const Divider(height: 24),
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
        leading: const Icon(Icons.home_work_outlined),
        title: Text(
          _testo(evento['titolo']),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_data(evento['data_evento'])} · ${_testo(evento['anno_accademico'])}',
        ),
        trailing: controller.iscrizione(id) == null
            ? null
            : const Icon(Icons.check_circle, color: Colors.green),
        onTap: () => controller.seleziona(evento),
      );
    },
  );

  Widget _dettaglio(Map<String, dynamic> evento) {
    final eventoId = evento['id'].toString();
    final opzioni = controller.opzioni(eventoId);
    final iscrizione = controller.iscrizione(eventoId);
    final iscrizioniAperte = evento['iscrizioni_aperte'] == true;
    final locandina = _testo(evento['locandina_url']);

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: 16),
              Text(
                _testo(evento['titolo']),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _riga('Anno accademico', evento['anno_accademico']),
              _riga('Data', _data(evento['data_evento'])),
              _riga('Luogo', evento['luogo']),
              _riga('Descrizione', evento['descrizione']),
              const Divider(height: 32),
              Row(
                children: [
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
                    onModifica: () =>
                        _apriEditorOpzione(eventoId, opzione: opzione),
                    onElimina: () => _eliminaOpzione(opzione),
                  ),
              if (!iscrizioniAperte)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Le iscrizioni non sono aperte.'),
                ),
              if (iscrizione != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: iscrizioniAperte
                      ? () => _cancellaIscrizione(eventoId)
                      : null,
                  icon: const Icon(Icons.event_busy),
                  label: const Text('Cancella la mia iscrizione'),
                ),
              ],
              if (controller.puoGestire) ...[
                const Divider(height: 32),
                Wrap(
                  spacing: 8,
                  children: [
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
          ),
        ),
      ),
    );
  }

  Widget _riga(String etichetta, Object? valore) {
    final testo = _testo(valore);
    if (testo.isEmpty || testo == '—') {
      return const SizedBox.shrink();
    }
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
    if (!conferma) {
      return;
    }
    final errore = await controller.cancellaIscrizione(eventoId);
    _esito(errore, 'Iscrizione cancellata.');
  }

  Future<void> _apriEditorEvento([Map<String, dynamic>? evento]) async {
    final dati = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EventoHouseEditor(
        evento: evento,
        anniAccademici: controller.anniAccademici,
      ),
    );
    if (dati == null) {
      return;
    }
    final errore = await controller.salvaEvento(
      id: evento?['id']?.toString(),
      dati: dati,
    );
    _esito(errore, 'Evento salvato.');
  }

  Future<void> _eliminaEvento(Map<String, dynamic> evento) async {
    final conferma = await _conferma(
      'Eliminare House of Mentore?',
      'Verranno eliminate anche le relative alternative.',
    );
    if (!conferma) {
      return;
    }
    final errore = await controller.eliminaEvento(evento['id'].toString());
    _esito(errore, 'Evento eliminato.');
  }

  Future<void> _apriEditorOpzione(
    String eventoId, {
    Map<String, dynamic>? opzione,
  }) async {
    final dati = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _OpzioneEditor(opzione: opzione),
    );
    if (dati == null) {
      return;
    }
    final errore = await controller.salvaOpzione(
      id: opzione?['id']?.toString(),
      eventoId: eventoId,
      descrizione: dati['descrizione'].toString(),
      ordine: dati['ordine_visualizzazione'] as int,
    );
    _esito(errore, 'Alternativa salvata.');
  }

  Future<void> _eliminaOpzione(Map<String, dynamic> opzione) async {
    final conferma = await _conferma(
      'Eliminare l’alternativa?',
      _testo(opzione['descrizione']),
    );
    if (!conferma) {
      return;
    }
    final errore = await controller.eliminaOpzione(opzione['id'].toString());
    _esito(errore, 'Alternativa eliminata.');
  }

  Future<bool> _conferma(String titolo, String testo) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(titolo),
          content: Text(testo),
          actions: [
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
    if (!mounted) {
      return;
    }
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
              onSelected: (valore) {
                if (valore == 'modifica') {
                  onModifica();
                } else {
                  onElimina();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'modifica', child: Text('Modifica')),
                PopupMenuItem(value: 'elimina', child: Text('Elimina')),
              ],
            )
          : null,
    ),
  );
}

class _EventoHouseEditor extends StatefulWidget {
  const _EventoHouseEditor({
    required this.evento,
    required this.anniAccademici,
  });

  final Map<String, dynamic>? evento;
  final List<String> anniAccademici;

  @override
  State<_EventoHouseEditor> createState() => _EventoHouseEditorState();
}

class _EventoHouseEditorState extends State<_EventoHouseEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController titolo;
  late final TextEditingController descrizione;
  late final TextEditingController luogo;
  late final TextEditingController locandina;
  DateTime? data;
  String? anno;
  bool iscrizioniAperte = false;

  @override
  void initState() {
    super.initState();
    titolo = TextEditingController(text: _testo(widget.evento?['titolo']));
    descrizione = TextEditingController(
      text: _testo(widget.evento?['descrizione']),
    );
    luogo = TextEditingController(text: _testo(widget.evento?['luogo']));
    locandina = TextEditingController(
      text: _testo(widget.evento?['locandina_url']),
    );
    data = DateTime.tryParse(_testo(widget.evento?['data_evento']));
    anno = _testo(widget.evento?['anno_accademico']);
    if (anno!.isEmpty) {
      anno = widget.anniAccademici.isEmpty ? null : widget.anniAccademici.first;
    }
    iscrizioniAperte = widget.evento?['iscrizioni_aperte'] == true;
  }

  @override
  void dispose() {
    titolo.dispose();
    descrizione.dispose();
    luogo.dispose();
    locandina.dispose();
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
              TextFormField(
                controller: titolo,
                decoration: const InputDecoration(labelText: 'Titolo'),
                validator: _obbligatorio,
              ),
              DropdownButtonFormField<String>(
                initialValue: anno,
                decoration: const InputDecoration(labelText: 'Anno accademico'),
                items: widget.anniAccademici
                    .map(
                      (valore) =>
                          DropdownMenuItem(value: valore, child: Text(valore)),
                    )
                    .toList(),
                onChanged: (valore) => anno = valore,
                validator: (valore) => valore == null ? 'Obbligatorio' : null,
              ),
              TextFormField(
                controller: descrizione,
                decoration: const InputDecoration(labelText: 'Descrizione'),
                maxLines: 4,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(data == null ? 'Data da definire' : _data(data)),
                trailing: Wrap(
                  children: [
                    if (data != null)
                      IconButton(
                        tooltip: 'Rimuovi data',
                        onPressed: () => setState(() => data = null),
                        icon: const Icon(Icons.clear),
                      ),
                    IconButton(
                      tooltip: 'Scegli data',
                      onPressed: _scegliData,
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ],
                ),
              ),
              TextFormField(
                controller: luogo,
                decoration: const InputDecoration(
                  labelText: 'Luogo (facoltativo)',
                ),
              ),
              TextFormField(
                controller: locandina,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL pubblico della locandina',
                ),
                validator: (valore) {
                  final testo = valore?.trim() ?? '';
                  if (testo.isEmpty) {
                    return null;
                  }
                  final uri = Uri.tryParse(testo);
                  return uri != null &&
                          (uri.scheme == 'http' || uri.scheme == 'https')
                      ? null
                      : 'Inserisci un URL http o https';
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Iscrizioni aperte'),
                value: iscrizioniAperte,
                onChanged: (valore) =>
                    setState(() => iscrizioniAperte = valore),
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

  Future<void> _scegliData() async {
    final scelta = await showDatePicker(
      context: context,
      initialDate: data ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (scelta != null) {
      setState(() => data = scelta);
    }
  }

  void _salva() {
    if (!(form.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'titolo': titolo.text.trim(),
      'descrizione': _nullSeVuoto(descrizione.text),
      'anno_accademico': anno,
      'data_evento': data?.toIso8601String().split('T').first,
      'luogo': _nullSeVuoto(luogo.text),
      'locandina_url': _nullSeVuoto(locandina.text),
      'iscrizioni_aperte': iscrizioniAperte,
    });
  }
}

class _OpzioneEditor extends StatefulWidget {
  const _OpzioneEditor({this.opzione});

  final Map<String, dynamic>? opzione;

  @override
  State<_OpzioneEditor> createState() => _OpzioneEditorState();
}

class _OpzioneEditorState extends State<_OpzioneEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController descrizione;
  late final TextEditingController ordine;

  @override
  void initState() {
    super.initState();
    descrizione = TextEditingController(
      text: _testo(widget.opzione?['descrizione']),
    );
    ordine = TextEditingController(
      text: _testo(widget.opzione?['ordine_visualizzazione']).isEmpty
          ? '0'
          : _testo(widget.opzione?['ordine_visualizzazione']),
    );
  }

  @override
  void dispose() {
    descrizione.dispose();
    ordine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.opzione == null ? 'Nuova alternativa' : 'Modifica alternativa',
    ),
    content: SizedBox(
      width: 500,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: descrizione,
              decoration: const InputDecoration(
                labelText: 'Descrizione',
                hintText: 'Esempio: Aperitivo 20 €',
              ),
              validator: _obbligatorio,
            ),
            TextFormField(
              controller: ordine,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ordine di visualizzazione',
              ),
              validator: (valore) => int.tryParse(valore ?? '') == null
                  ? 'Inserisci un numero intero'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
      FilledButton(
        onPressed: () {
          if (!(form.currentState?.validate() ?? false)) {
            return;
          }
          Navigator.pop(context, <String, dynamic>{
            'descrizione': descrizione.text.trim(),
            'ordine_visualizzazione': int.parse(ordine.text),
          });
        },
        child: const Text('Salva'),
      ),
    ],
  );
}

String? _obbligatorio(String? valore) =>
    valore == null || valore.trim().isEmpty ? 'Campo obbligatorio' : null;

String? _nullSeVuoto(String valore) =>
    valore.trim().isEmpty ? null : valore.trim();

String _testo(Object? valore) => valore?.toString().trim() ?? '';

String _data(Object? valore) {
  final data = valore is DateTime ? valore : DateTime.tryParse(_testo(valore));
  if (data == null) {
    return '—';
  }
  return '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/${data.year}';
}
