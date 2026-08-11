import 'package:flutter/material.dart';

import '../../sessione_controller.dart';
import 'amministrazione_controller.dart';

class AmministrazionePage extends StatefulWidget {
  const AmministrazionePage({super.key, required this.sessione});
  final SessioneController sessione;

  @override
  State<AmministrazionePage> createState() => _AmministrazionePageState();
}

class _AmministrazionePageState extends State<AmministrazionePage> {
  late final AmministrazioneController controller;

  @override
  void initState() {
    super.initState();
    controller = AmministrazioneController(widget.sessione)..carica();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => DefaultTabController(
      length: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Amministrazione',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: controller.carica,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Partecipanti'),
                Tab(text: 'Abilitazioni'),
                Tab(text: 'Anni accademici'),
                Tab(text: 'Mentori'),
              ],
            ),
            Expanded(
              child: controller.caricamento && controller.partecipanti.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : controller.errore != null && controller.partecipanti.isEmpty
                  ? Center(child: Text(controller.errore!))
                  : TabBarView(
                      children: [
                        _partecipanti(),
                        _abilitazioni(),
                        _anni(),
                        _mentori(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _partecipanti() => ListView.builder(
    padding: const EdgeInsets.all(12),
    itemCount: controller.partecipanti.length,
    itemBuilder: (context, i) {
      final p = controller.partecipanti[i];
      final id = p['user_id'].toString();
      final riservato = controller.riservati[id];
      return Card(
        child: ListTile(
          leading: Icon(
            riservato?['attivo'] == false
                ? Icons.person_off_outlined
                : Icons.person_outline,
          ),
          title: Text('${p['cognome'] ?? ''} ${p['nome'] ?? ''}'),
          subtitle: Text(
            '${p['email_unipa'] ?? ''}${controller.soloOwner ? ' · ${controller.ruoli[id] ?? 'participant'}' : ''}',
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _modificaPartecipante(p, riservato),
        ),
      );
    },
  );

  Widget _abilitazioni() {
    if (controller.abilitazioni.isEmpty) {
      return const Center(child: Text('Nessuna richiesta di modifica.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: controller.abilitazioni.length,
      itemBuilder: (context, i) {
        final a = controller.abilitazioni[i];
        final attiva = a['abilitata'] == true && a['revocata_at'] == null;
        return Card(
          child: ListTile(
            title: Text(controller.nomeUtente(a['user_id'])),
            subtitle: Text('${a['ambito']} · ${a['anno_accademico']}'),
            trailing: FilledButton.tonal(
              onPressed: () => _abilita(a, !attiva),
              child: Text(attiva ? 'Revoca' : 'Abilita'),
            ),
          ),
        );
      },
    );
  }

  Widget _anni() => Column(
    children: [
      if (!controller.soloOwner)
        const MaterialBanner(
          content: Text(
            'La gestione degli anni accademici è riservata al proprietario.',
          ),
          actions: [SizedBox.shrink()],
        ),
      if (controller.soloOwner)
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: _nuovoAnno,
              icon: const Icon(Icons.add),
              label: const Text('Nuovo anno'),
            ),
          ),
        ),
      Expanded(
        child: ListView.builder(
          itemCount: controller.anni.length,
          itemBuilder: (context, i) {
            final anno = controller.anni[i];
            return ListTile(
              leading: Icon(
                anno['corrente'] == true
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: anno['corrente'] == true ? Colors.green : null,
              ),
              title: Text(anno['codice'].toString()),
              subtitle: Text(
                '${anno['data_inizio'] ?? '—'} — ${anno['data_fine'] ?? '—'}',
              ),
              trailing: controller.soloOwner && anno['corrente'] != true
                  ? TextButton(
                      onPressed: () => _annoCorrente(anno['codice'].toString()),
                      child: const Text('Rendi corrente'),
                    )
                  : null,
            );
          },
        ),
      ),
    ],
  );

  Widget _mentori() => Column(
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _nuovaAssegnazione,
            icon: const Icon(Icons.add),
            label: const Text('Assegna mentore'),
          ),
        ),
      ),
      Expanded(
        child: controller.assegnazioni.isEmpty
            ? const Center(child: Text('Nessun mentore assegnato.'))
            : ListView.builder(
                itemCount: controller.assegnazioni.length,
                itemBuilder: (context, i) {
                  final a = controller.assegnazioni[i];
                  return ListTile(
                    title: Text(controller.nomeUtente(a['mentore_id'])),
                    subtitle: Text(
                      '${a['tipo']} · mentoraggio ${a['mentoraggio_id']}',
                    ),
                    trailing: IconButton(
                      onPressed: () => _eliminaAssegnazione(a),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  );
                },
              ),
      ),
    ],
  );

  Future<void> _modificaPartecipante(
    Map<String, dynamic> p,
    Map<String, dynamic>? r,
  ) async {
    final note = TextEditingController(
      text: r?['note_storiche']?.toString() ?? '',
    );
    var attivo = r?['attivo'] != false;
    var ruolo = controller.ruoli[p['user_id'].toString()] ?? 'participant';
    final salva =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text('${p['cognome']} ${p['nome']}'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: const Text('Partecipante attivo'),
                      value: attivo,
                      onChanged: (v) => setDialogState(() => attivo = v),
                    ),
                    TextField(
                      controller: note,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Note storiche riservate',
                      ),
                    ),
                    if (controller.soloOwner)
                      DropdownButtonFormField<String>(
                        initialValue: ruolo,
                        decoration: const InputDecoration(
                          labelText: 'Ruolo applicativo',
                        ),
                        items: ['participant', 'organizer', 'owner']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) => ruolo = v!,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Salva'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!salva) {
      note.dispose();
      return;
    }
    var errore = await controller.salvaRiservati(
      p['user_id'].toString(),
      attivo,
      note.text,
    );
    if (errore == null &&
        controller.soloOwner &&
        ruolo != controller.ruoli[p['user_id'].toString()]) {
      errore = await controller.cambiaRuolo(p['user_id'].toString(), ruolo);
    }
    note.dispose();
    _mostraErrore(errore);
  }

  Future<void> _abilita(Map<String, dynamic> a, bool valore) async =>
      _mostraErrore(await controller.cambiaAbilitazione(a, valore));

  Future<void> _nuovoAnno() async {
    final codice = TextEditingController();
    DateTime? inizio;
    DateTime? fine;
    final salva =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Nuovo anno accademico'),
            content: StatefulBuilder(
              builder: (context, setDialogState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codice,
                    decoration: const InputDecoration(
                      labelText: 'Codice (es. 2026-27)',
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      inizio == null
                          ? 'Data inizio'
                          : 'Data inizio: ${_formattaData(inizio!)}',
                    ),
                    trailing: Wrap(
                      children: [
                        if (inizio != null)
                          IconButton(
                            tooltip: 'Rimuovi data inizio',
                            onPressed: () => setDialogState(() => inizio = null),
                            icon: const Icon(Icons.clear),
                          ),
                        IconButton(
                          tooltip: 'Scegli data inizio',
                          onPressed: () async {
                            final scelta = await showDatePicker(
                              context: context,
                              initialDate: inizio ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            setDialogState(() => inizio = scelta);
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      fine == null
                          ? 'Data fine'
                          : 'Data fine: ${_formattaData(fine!)}',
                    ),
                    trailing: Wrap(
                      children: [
                        if (fine != null)
                          IconButton(
                            tooltip: 'Rimuovi data fine',
                            onPressed: () => setDialogState(() => fine = null),
                            icon: const Icon(Icons.clear),
                          ),
                        IconButton(
                          tooltip: 'Scegli data fine',
                          onPressed: () async {
                            final scelta = await showDatePicker(
                              context: context,
                              initialDate: fine ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            setDialogState(() => fine = scelta);
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Crea'),
              ),
            ],
          ),
        ) ??
        false;
    if (salva) {
      _mostraErrore(
        await controller.aggiungiAnno(
          codice.text,
          inizio?.toIso8601String().split('T').first,
          fine?.toIso8601String().split('T').first,
        ),
      );
    }
    codice.dispose();
  }

  String _formattaData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  Future<void> _annoCorrente(String codice) async =>
      _mostraErrore(await controller.impostaAnnoCorrente(codice));

  Future<void> _nuovaAssegnazione() async {
    if (controller.mentoraggi.isEmpty || controller.partecipanti.isEmpty) {
      return;
    }
    var mentoraggio = controller.mentoraggi.first['id'].toString();
    var mentore = controller.partecipanti.first['user_id'].toString();
    var tipo = 'mentor';
    final salva =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: const Text('Assegna mentore'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: mentoraggio,
                      decoration: const InputDecoration(
                        labelText: 'Mentoraggio',
                      ),
                      items: controller.mentoraggi
                          .map(
                            (m) => DropdownMenuItem(
                              value: m['id'].toString(),
                              child: Text(m['id'].toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => mentoraggio = v!,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: mentore,
                      decoration: const InputDecoration(
                        labelText: 'Partecipante',
                      ),
                      items: controller.partecipanti
                          .map(
                            (p) => DropdownMenuItem(
                              value: p['user_id'].toString(),
                              child: Text('${p['cognome']} ${p['nome']}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => mentore = v!,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: tipo,
                      decoration: const InputDecoration(labelText: 'Funzione'),
                      items: ['mentor', 'senior']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => tipo = v!,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Assegna'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (salva) {
      _mostraErrore(
        await controller.aggiungiAssegnazione(mentoraggio, mentore, tipo),
      );
    }
  }

  Future<void> _eliminaAssegnazione(Map<String, dynamic> a) async =>
      _mostraErrore(await controller.eliminaAssegnazione(a));
  void _mostraErrore(String? errore) {
    if (mounted && errore != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errore)));
    }
  }
}
