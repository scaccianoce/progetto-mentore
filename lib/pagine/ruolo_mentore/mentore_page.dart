import 'package:flutter/material.dart';

import '../../app_exception.dart';
import 'mentore_controller.dart';

class MentorePage extends StatefulWidget {
  const MentorePage({super.key});
  @override
  State<MentorePage> createState() => _MentorePageState();
}

class _MentorePageState extends State<MentorePage> {
  late final MentoreController controller;
  static const Set<String> nonModificabili = {
    'id',
    'insegnamento_id',
    'created_at',
  };
  static const Set<String> campiMultilinea = {
    'osservazioni_aula',
    'osservazioni_focus_group',
    'scheda_sintesi',
  };
  static const List<String> statiMentoraggio = <String>[
    'Non iniziato',
    'In corso',
    'Completato',
  ];

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
    builder: (context, _) {
      if (controller.caricamento) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.errore != null) {
        return Center(child: Text(controller.errore!));
      }
      if (controller.percorsi.isEmpty) {
        return const Center(child: Text('Nessun mentoraggio assegnato.'));
      }
      final elenco = Card(
        child: ListView(
          children: controller.percorsi
              .map(
                (p) => ListTile(
                  selected:
                      p.mentoraggio['id'] ==
                      controller.selezionato?.mentoraggio['id'],
                  title: Text(p.insegnamento['insegnamento']?.toString() ?? ''),
                  subtitle: Text(
                    '${p.docente['nome'] ?? ''} ${p.docente['cognome'] ?? ''}'
                        .trim(),
                  ),
                  onTap: () => controller.seleziona(p),
                ),
              )
              .toList(growable: false),
        ),
      );
      final dettaglio = _dettaglio(context);
      return Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth >= 800) {
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
                Expanded(child: elenco),
                const Divider(),
                Expanded(child: dettaglio),
              ],
            );
          },
        ),
      );
    },
  );

  Widget _dettaglio(BuildContext context) {
    final p = controller.selezionato;
    if (p == null) return const SizedBox.shrink();
    return Card(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ruolo mentore',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              FilledButton.icon(
                onPressed: _modifica,
                icon: const Icon(Icons.edit),
                label: const Text('Modifica'),
              ),
            ],
          ),
          ListTile(
            title: const Text('Insegnamento'),
            subtitle: Text(p.insegnamento['insegnamento']?.toString() ?? ''),
          ),
          ListTile(
            title: const Text(
              'Mentee',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${p.docente['nome'] ?? ''} ${p.docente['cognome'] ?? ''}'.trim(),
            ),
          ),
          const Divider(),
          Text('Team', style: Theme.of(context).textTheme.titleMedium),
          ...p.team.map(
            (m) => ListTile(
              title: Text('${m['nome'] ?? ''} ${m['cognome'] ?? ''}'.trim()),
              subtitle: Text(m['tipo']?.toString() ?? ''),
            ),
          ),
          const Divider(),
          ...p.mentoraggio.entries
              .where((e) => !nonModificabili.contains(e.key))
              .map(
                (e) => ListTile(
                  title: Text(
                    e.key.replaceAll('_', ' '),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(e.value?.toString() ?? '—'),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _modifica() async {
    final p = controller.selezionato!;
    final campiModificabili = p.mentoraggio.entries
        .where((e) => !nonModificabili.contains(e.key))
        .toList(growable: false);
    final date = <String, DateTime?>{
      for (final e in campiModificabili.where((e) => e.key.startsWith('data_')))
        e.key: DateTime.tryParse(e.value?.toString() ?? ''),
    };
    final campi = <String, TextEditingController>{
      for (final e in campiModificabili)
        if (!e.key.startsWith('data_') && e.key != 'stato')
          e.key: TextEditingController(text: e.value?.toString() ?? ''),
    };
    final statoDb = p.mentoraggio['stato']?.toString();
    var stato = statiMentoraggio.contains(statoDb)
        ? statoDb!
        : statiMentoraggio.first;
    final form = GlobalKey<FormState>();
    final salva = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Aggiorna mentoraggio'),
          content: SizedBox(
            width: 650,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  children: campiModificabili
                      .map((e) {
                        final chiave = e.key;
                        if (chiave.startsWith('data_')) {
                          final valore = date[chiave];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                valore == null
                                    ? _etichettaCampo(chiave)
                                    : '${_etichettaCampo(chiave)}: ${_formattaData(valore)}',
                              ),
                              trailing: Wrap(
                                children: [
                                  if (valore != null)
                                    IconButton(
                                      tooltip: 'Rimuovi data',
                                      onPressed: () => setDialogState(
                                        () => date[chiave] = null,
                                      ),
                                      icon: const Icon(Icons.clear),
                                    ),
                                  IconButton(
                                    tooltip: 'Scegli data',
                                    onPressed: () async {
                                      final scelta = await showDatePicker(
                                        context: context,
                                        initialDate: valore ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                      );
                                      if (scelta != null) {
                                        setDialogState(
                                          () => date[chiave] = scelta,
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.calendar_month_outlined,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        if (chiave == 'stato') {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DropdownButtonFormField<String>(
                              initialValue: stato,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Stato',
                                border: OutlineInputBorder(),
                              ),
                              items: statiMentoraggio
                                  .map(
                                    (valore) => DropdownMenuItem<String>(
                                      value: valore,
                                      child: Text(valore),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (valore) {
                                if (valore != null) stato = valore;
                              },
                            ),
                          );
                        }
                        final multilinea = campiMultilinea.contains(chiave);
                        final url = chiave.startsWith('link_');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextFormField(
                            controller: campi[chiave],
                            keyboardType: url
                                ? TextInputType.url
                                : multilinea
                                ? TextInputType.multiline
                                : TextInputType.text,
                            minLines: multilinea ? 4 : 1,
                            maxLines: multilinea ? 8 : 1,
                            validator: url ? _validaUrl : null,
                            decoration: InputDecoration(
                              labelText: _etichettaCampo(chiave),
                              border: const OutlineInputBorder(),
                              hintText: url ? 'https://...' : null,
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState?.validate() ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    if (salva == true) {
      try {
        final valori = <String, dynamic>{};
        for (final e in campiModificabili) {
          final chiave = e.key;
          if (chiave.startsWith('data_')) {
            valori[chiave] = date[chiave]?.toIso8601String().split('T').first;
          } else if (chiave == 'stato') {
            valori[chiave] = stato;
          } else {
            final testo = campi[chiave]!.text.trim();
            valori[chiave] = testo.isEmpty ? null : testo;
          }
        }
        await controller.salvaMentoraggio(valori);
      } on AppException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.messaggio)));
        }
      }
    }
    for (final c in campi.values) {
      c.dispose();
    }
  }

  String? _validaUrl(String? valore) {
    final testo = valore?.trim() ?? '';
    if (testo.isEmpty) return null;
    final uri = Uri.tryParse(testo);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Inserisci un URL valido (https://...)';
    }
    return null;
  }

  String _etichettaCampo(String chiave) {
    final testo = chiave.replaceAll('_', ' ');
    return '${testo[0].toUpperCase()}${testo.substring(1)}';
  }

  String _formattaData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }
}
