import 'package:flutter/material.dart';

import '../../app_exception.dart';
import '../../sessione_controller.dart';
import 'insegnamento_controller.dart';

class InsegnamentoPage extends StatefulWidget {
  const InsegnamentoPage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<InsegnamentoPage> createState() => _InsegnamentoPageState();
}

class _InsegnamentoPageState extends State<InsegnamentoPage> {
  late final InsegnamentoController _controller;

  static const Map<String, String> campi = <String, String>{
    'insegnamento': 'Insegnamento',
    'semestre': 'Semestre',
    'cfu': 'CFU',
    'ore': 'Ore',
    'cds': 'Corso di studi',
    'anno_erogazione': 'Anno di erogazione',
    'data_inizio': 'Data inizio',
    'data_fine': 'Data fine',
    'numero_studenti': 'Numero studenti',
    'sede': 'Sede',
    'svolgimento': 'Svolgimento',
    'gia_mentorato': 'Già mentorato',
    'giorni_orari_lezioni': 'Giorni e orari delle lezioni',
    'note': 'Note',
  };

  static const Set<String> _campiNumerici = <String>{
    'cfu',
    'ore',
    'numero_studenti',
  };

  static const Set<String> _campiData = <String>{'data_inizio', 'data_fine'};

  static const Set<String> _campiMultilinea = <String>{
    'note',
    'giorni_orari_lezioni',
  };

  static const Map<String, List<String>> _opzioniCampi = <String, List<String>>{
    'semestre': <String>['I semestre', 'II semestre', 'Annuale'],
    'anno_erogazione': <String>[
      '1° anno',
      '2° anno',
      '3° anno',
      '4° anno',
      '5° anno',
    ],
    'svolgimento': <String>['In presenza', 'Online', 'Misto'],
  };

  static const List<String> _opzioniGiaMentorato = <String>[
    '1 volta',
    '2 volte',
    '3 o più volte',
  ];

  @override
  void initState() {
    super.initState();
    _controller = InsegnamentoController(sessione: widget.sessione)..carica();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        if (_controller.caricamento) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Il mio insegnamento — ${_controller.annoCorrente ?? ''}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _controller.salvataggio ? null : _apriEditor,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    _controller.insegnamento == null ? 'Inserisci' : 'Modifica',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_controller.errore != null)
              Text(_controller.errore!)
            else if (_controller.insegnamento == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nessun insegnamento per l’anno corrente.'),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: campi.entries
                        .map((e) {
                          final String valore =
                              _controller.insegnamento![e.key]?.toString() ??
                              '';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              e.value,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(valore.isEmpty ? '—' : valore),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _apriEditor() async {
    final bool bloccaDatiIdentificativi =
        _controller.insegnamento != null &&
        widget.sessione.ruolo == AppRole.participant;
    DateTime? dataInizio = DateTime.tryParse(
      _controller.insegnamento?['data_inizio']?.toString() ?? '',
    );
    DateTime? dataFine = DateTime.tryParse(
      _controller.insegnamento?['data_fine']?.toString() ?? '',
    );
    final String? giaMentoratoDb = _controller.insegnamento?['gia_mentorato']
        ?.toString();
    String? giaMentorato = _opzioniGiaMentorato.contains(giaMentoratoDb)
        ? giaMentoratoDb
        : null;
    final Map<String, String> valoriScelta = <String, String>{
      for (final MapEntry<String, List<String>> campo in _opzioniCampi.entries)
        campo.key:
            campo.value.contains(
              _controller.insegnamento?[campo.key]?.toString(),
            )
            ? _controller.insegnamento![campo.key].toString()
            : campo.value.first,
    };
    final Map<String, TextEditingController> controllers = {
      for (final String chiave in campi.keys)
        if (!_campiData.contains(chiave) &&
            chiave != 'gia_mentorato' &&
            !_opzioniCampi.containsKey(chiave))
          chiave: TextEditingController(
            text: _controller.insegnamento?[chiave]?.toString() ?? '',
          ),
    };
    final bool? salva = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('Dati dell’insegnamento'),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (bloccaDatiIdentificativi)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Il nome dell’insegnamento e il semestre possono essere modificati soltanto da organizer o owner.',
                      ),
                    ),
                  ...campi.entries
                      .where(
                        (e) =>
                            !_campiData.contains(e.key) &&
                            e.key != 'gia_mentorato',
                      )
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _opzioniCampi.containsKey(e.key)
                              ? DropdownButtonFormField<String>(
                                  initialValue: valoriScelta[e.key],
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: e.value,
                                    border: const OutlineInputBorder(),
                                    helperText:
                                        bloccaDatiIdentificativi &&
                                            e.key == 'semestre'
                                        ? 'Campo riservato a organizer e owner'
                                        : null,
                                  ),
                                  items: _opzioniCampi[e.key]!
                                      .map(
                                        (String valore) =>
                                            DropdownMenuItem<String>(
                                              value: valore,
                                              child: Text(valore),
                                            ),
                                      )
                                      .toList(growable: false),
                                  onChanged:
                                      bloccaDatiIdentificativi &&
                                          e.key == 'semestre'
                                      ? null
                                      : (String? valore) {
                                          if (valore != null) {
                                            setDialogState(
                                              () =>
                                                  valoriScelta[e.key] = valore,
                                            );
                                          }
                                        },
                                )
                              : TextField(
                                  controller: controllers[e.key],
                                  keyboardType: _campiNumerici.contains(e.key)
                                      ? TextInputType.number
                                      : _campiMultilinea.contains(e.key)
                                      ? TextInputType.multiline
                                      : null,
                                  minLines: _campiMultilinea.contains(e.key)
                                      ? 3
                                      : 1,
                                  maxLines: _campiMultilinea.contains(e.key)
                                      ? 6
                                      : 1,
                                  enabled:
                                      !bloccaDatiIdentificativi ||
                                      e.key != 'insegnamento',
                                  decoration: InputDecoration(
                                    labelText: e.value,
                                    border: const OutlineInputBorder(),
                                    helperText:
                                        bloccaDatiIdentificativi &&
                                            e.key == 'insegnamento'
                                        ? 'Campo riservato a organizer e owner'
                                        : null,
                                  ),
                                ),
                        ),
                      ),
                  _dataTile(
                    label: campi['data_inizio']!,
                    value: dataInizio,
                    onChanged: (valore) =>
                        setDialogState(() => dataInizio = valore),
                  ),
                  _dataTile(
                    label: campi['data_fine']!,
                    value: dataFine,
                    onChanged: (valore) =>
                        setDialogState(() => dataFine = valore),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: giaMentorato,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: campi['gia_mentorato']!,
                      border: const OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Mai o non specificato'),
                      ),
                      ..._opzioniGiaMentorato.map(
                        (String valore) => DropdownMenuItem<String?>(
                          value: valore,
                          child: Text(valore),
                        ),
                      ),
                    ],
                    onChanged: (String? valore) =>
                        setDialogState(() => giaMentorato = valore),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    if (salva == true) {
      dynamic numero(String chiave) {
        final String valore = controllers[chiave]!.text.trim();
        return valore.isEmpty ? null : num.tryParse(valore);
      }

      try {
        final Map<String, dynamic> valori = <String, dynamic>{};
        for (final String chiave in campi.keys) {
          if (_campiData.contains(chiave) || chiave == 'gia_mentorato') {
            continue;
          }
          if (_opzioniCampi.containsKey(chiave)) {
            valori[chiave] = valoriScelta[chiave];
          } else {
            valori[chiave] = _campiNumerici.contains(chiave)
                ? numero(chiave)
                : (controllers[chiave]!.text.trim().isEmpty
                      ? null
                      : controllers[chiave]!.text.trim());
          }
        }
        valori['data_inizio'] = dataInizio?.toIso8601String().split('T').first;
        valori['data_fine'] = dataFine?.toIso8601String().split('T').first;
        valori['gia_mentorato'] = giaMentorato;
        await _controller.salva(valori);
      } on AppException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.messaggio)));
        }
      }
    }
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  Widget _dataTile({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(value == null ? label : '$label: ${_formattaData(value)}'),
      trailing: Wrap(
        children: [
          if (value != null)
            IconButton(
              tooltip: 'Rimuovi data',
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.clear),
            ),
          IconButton(
            tooltip: 'Scegli data',
            onPressed: () async {
              final DateTime? scelta = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              onChanged(scelta);
            },
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
    ),
  );
}

String _formattaData(DateTime data) {
  return '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/${data.year}';
}
