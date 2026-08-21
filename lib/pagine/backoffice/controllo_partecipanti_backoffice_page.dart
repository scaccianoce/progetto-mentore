import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../supabase_config.dart';
import '../../dinamico/maschera_dinamica_controller.dart';
import '../../dinamico/maschera_dinamica_widget.dart';
import 'backoffice_dati_anno.dart';

/// Controllo operativo per anno accademico costruito direttamente dalle
/// tabelle reali del database, senza view di riepilogo.
class ControlloPartecipantiBackofficePage extends StatefulWidget {
  const ControlloPartecipantiBackofficePage({super.key});

  @override
  State<ControlloPartecipantiBackofficePage> createState() =>
      _ControlloPartecipantiBackofficePageState();
}

class _ControlloPartecipantiBackofficePageState
    extends State<ControlloPartecipantiBackofficePage> {
  List<String> _anni = const [];
  String? _anno;
  List<_PartecipanteAnno> _partecipanti = const [];
  bool _caricamento = true;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _inizializza();
  }

  Future<void> _inizializza() async {
    try {
      final anni = await SupabaseConfig.client
          .from('anni_accademici')
          .select('codice, corrente')
          .order('codice', ascending: false);
      final lista = anni.map((e) => e['codice'].toString()).toList();
      final corrente = anni
          .where((e) => e['corrente'] == true)
          .map((e) => e['codice'].toString())
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        _anni = lista;
        _anno = corrente ?? lista.firstOrNull;
      });
      await _carica();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = e.toString();
        _caricamento = false;
      });
    }
  }

  Future<void> _carica() async {
    final anno = _anno;
    if (anno == null) return;

    setState(() {
      _caricamento = true;
      _errore = null;
    });

    try {
      final dati = await BackofficeDatiAnno.carica(anno);

      final mentoraggi = dati.mentoraggi;
      final insegnamenti = dati.insegnamenti;
      final assegnazioni = dati.assegnazioni;
      final eventi = dati.eventi;
      final partecipazioniEventi = dati.partecipazioniEventi;
      final hom = dati.houseOfMentore;
      final partecipazioniHom = dati.partecipazioniHouseOfMentore;
      final anagrafiche = dati.anagrafiche;

      final insegnamentiPerId = <String, Map<String, dynamic>>{
        for (final r in insegnamenti) r['id'].toString(): r,
      };
      final eventiPerId = <String, Map<String, dynamic>>{
        for (final r in eventi) r['id'].toString(): r,
      };
      final homPerId = <String, Map<String, dynamic>>{
        for (final r in hom) r['id'].toString(): r,
      };
      final persone = <String, Map<String, dynamic>>{
        for (final p in anagrafiche) p['user_id'].toString(): p,
      };

      final partecipanteIds = <String>{
        ...persone.keys,
      };

      String nomePersona(String? id) {
        if (!_valido(id)) return '—';
        final p = persone[id];
        if (p == null) return id!;
        final nome = '${p['cognome'] ?? ''} ${p['nome'] ?? ''}'.trim();
        if (nome.isNotEmpty) return nome;
        return p['email_unipa']?.toString() ?? id!;
      }

      final risultato = <_PartecipanteAnno>[];

      for (final partecipanteId in partecipanteIds) {
        final mentee = <_PercorsoMentee>[];
        final mentore = <_PercorsoMentore>[];

        for (final m in mentoraggi) {
          final insegnamento =
              insegnamentiPerId[m['insegnamento_id']?.toString()];
          if (insegnamento == null) continue;

          final assegnati = assegnazioni
              .where(
                (a) =>
                    a['mentoraggio_id']?.toString() ==
                    m['id']?.toString(),
              )
              .toList();

          final docenteId = insegnamento['docente_id']?.toString();

          if (docenteId == partecipanteId) {
            mentee.add(
              _PercorsoMentee(
                insegnamento: _nomeInsegnamento(insegnamento),
                insegnamentoRiga: insegnamento,
                team: assegnati
                    .map(
                      (a) => _MembroTeam(
                        nome: nomePersona(a['mentore_id']?.toString()),
                        tipo: a['tipo']?.toString() ?? '—',
                      ),
                    )
                    .toList(),
                mentoraggio: m,
              ),
            );
          }

          final miaAssegnazione = assegnati
              .where(
                (a) => a['mentore_id']?.toString() == partecipanteId,
              )
              .firstOrNull;

          if (miaAssegnazione != null) {
            mentore.add(
              _PercorsoMentore(
                insegnamento: _nomeInsegnamento(insegnamento),
                insegnamentoRiga: insegnamento,
                mentee: nomePersona(docenteId),
                mioTipo: miaAssegnazione['tipo']?.toString() ?? '—',
                altriTeam: assegnati
                    .where(
                      (a) =>
                          a['mentore_id']?.toString() != partecipanteId,
                    )
                    .map(
                      (a) => _MembroTeam(
                        nome: nomePersona(a['mentore_id']?.toString()),
                        tipo: a['tipo']?.toString() ?? '—',
                      ),
                    )
                    .toList(),
                mentoraggio: m,
              ),
            );
          }
        }

        final partecipazioni = partecipazioniEventi
            .where(
              (p) => p['partecipante_id']?.toString() == partecipanteId,
            )
            .map(
              (p) => _PartecipazioneEvento(
                titolo:
                    eventiPerId[p['evento_id']?.toString()]?['titolo']
                        ?.toString() ??
                    p['evento_id']?.toString() ??
                    '—',
                presente: p['presente'] == true,
              ),
            )
            .toList();

        final house = partecipazioniHom
            .where(
              (p) => p['partecipante_id']?.toString() == partecipanteId,
            )
            .map(
              (p) =>
                  homPerId[p['evento_id']?.toString()]?['titolo']?.toString() ??
                  p['evento_id']?.toString() ??
                  '—',
            )
            .toList();

        risultato.add(
          _PartecipanteAnno(
            persona:
                persone[partecipanteId] ??
                <String, dynamic>{'user_id': partecipanteId},
            mentee: mentee,
            mentore: mentore,
            eventi: partecipazioni,
            houseOfMentore: house,
          ),
        );
      }

      risultato.sort((a, b) {
        final cognomeA =
            a.persona['cognome']?.toString().toLowerCase() ?? '';
        final cognomeB =
            b.persona['cognome']?.toString().toLowerCase() ?? '';
        final confronto = cognomeA.compareTo(cognomeB);
        if (confronto != 0) return confronto;
        final nomeA = a.persona['nome']?.toString().toLowerCase() ?? '';
        final nomeB = b.persona['nome']?.toString().toLowerCase() ?? '';
        return nomeA.compareTo(nomeB);
      });

      if (!mounted) return;
      setState(() => _partecipanti = risultato);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errore =
            'Impossibile costruire il controllo partecipanti.\n$e',
      );
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _anno,
                  decoration:
                      const InputDecoration(labelText: 'Anno accademico'),
                  items: [
                    for (final anno in _anni)
                      DropdownMenuItem(value: anno, child: Text(anno)),
                  ],
                  onChanged: (v) async {
                    setState(() => _anno = v);
                    await _carica();
                  },
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Aggiorna',
                onPressed: _carica,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _contenuto()),
        ],
      );

  Widget _contenuto() {
    if (_caricamento) return const Center(child: CircularProgressIndicator());
    if (_errore != null) return Center(child: Text(_errore!));
    if (_partecipanti.isEmpty) {
      return const Center(child: Text('Nessun partecipante per questo anno.'));
    }

    return ListView.builder(
      itemCount: _partecipanti.length,
      itemBuilder: (context, index) {
        final r = _partecipanti[index];
        final nome =
            '${r.persona['cognome'] ?? ''} ${r.persona['nome'] ?? ''}'.trim();
        return Card(
          child: ExpansionTile(
            title: Text(
              nome.isEmpty ? r.persona['user_id'].toString() : nome,
            ),
            subtitle: Text(r.persona['email_unipa']?.toString() ?? ''),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _titolo('Ruolo da mentee'),
              if (r.mentee.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Nessun insegnamento mentorato.'),
                ),
              for (final percorso in r.mentee) _schedaMentee(percorso),
              const SizedBox(height: 12),
              _titolo('Ruolo da mentore'),
              if (r.mentore.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Nessun incarico come mentore.'),
                ),
              for (final percorso in r.mentore) _schedaMentore(percorso),
              const SizedBox(height: 12),
              _titolo('Eventi'),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Partecipati: ${r.eventi.where((e) => e.presente).length} '
                  'su ${r.eventi.length} iscrizioni',
                ),
              ),
              for (final evento in r.eventi)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    evento.presente
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                  ),
                  title: Text(evento.titolo),
                  trailing:
                      Text(evento.presente ? 'Presente' : 'Non presente'),
                ),
              const SizedBox(height: 12),
              _titolo('House of Mentore'),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Partecipazioni registrate: ${r.houseOfMentore.length}',
                ),
              ),
              for (final titolo in r.houseOfMentore)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.home_outlined),
                  title: Text(titolo),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _schedaMentee(_PercorsoMentee p) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                p.insegnamento,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Mentori / senior: ${_team(p.team)}'),
              _statoMentoraggio(p.mentoraggio),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _modificaInsegnamento(p.insegnamentoRiga),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Modifica insegnamento'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _modificaMentoraggio(p.mentoraggio),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Modifica mentoraggio'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _gestisciTeamMentoraggio(p.mentoraggio),
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text('Mentori / senior'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _schedaMentore(_PercorsoMentore p) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                p.insegnamento,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Mentee: ${p.mentee}'),
              Text('Ruolo: ${p.mioTipo}'),
              Text('Co-mentore / senior: ${_team(p.altriTeam)}'),
              _statoMentoraggio(p.mentoraggio),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _modificaInsegnamento(p.insegnamentoRiga),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Modifica insegnamento'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _modificaMentoraggio(p.mentoraggio),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Modifica mentoraggio'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _gestisciTeamMentoraggio(p.mentoraggio),
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text('Mentori / senior'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _statoMentoraggio(Map<String, dynamic> m) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                Text('Stato: ${m['stato'] ?? '—'}'),
                Text('Visita 1: ${m['data_visita_1'] ?? '—'}'),
                Text('Visita 2: ${m['data_visita_2'] ?? '—'}'),
                if (m['data_visita_3'] != null)
                  Text('Visita 3: ${m['data_visita_3']}'),
                if (m['data_visita_4'] != null)
                  Text('Visita 4: ${m['data_visita_4']}'),
                Text('Focus group: ${m['data_focus_group'] ?? '—'}'),
                Text('Incontro finale: ${m['data_incontro_finale'] ?? '—'}'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if ((m['scheda_sintesi_pdf_url']?.toString().trim() ?? '').isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _apriPdf(m['scheda_sintesi_pdf_url'].toString()),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Apri PDF'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _modificaPdfMentoraggio(m),
                  icon: const Icon(Icons.link_outlined),
                  label: const Text('Modifica link PDF'),
                ),
              ],
            ),
          ],
        ),
      );

  Future<void> _modificaInsegnamento(
    Map<String, dynamic> insegnamento,
  ) async {
    final id = insegnamento['id']?.toString();
    if (id == null || id.isEmpty) return;

    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: const ConfigurazionePaginaDinamica(
        tabella: 'insegnamenti',
      ),
      valoriIniziali: insegnamento,
      partecipante: false,
      mostraCampiSolaLettura: true,
      titolo: 'Modifica insegnamento',
    );
    if (valori == null) return;

    try {
      final dati = Map<String, dynamic>.from(valori)
        ..remove('id')
        ..remove('created_at')
        ..remove('updated_at');
      if (dati.isNotEmpty) {
        await SupabaseConfig.client
            .from('insegnamenti')
            .update(dati)
            .eq('id', id);
      }
      await _carica();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile modificare l’insegnamento: $e')),
      );
    }
  }

  Future<void> _modificaMentoraggio(
    Map<String, dynamic> mentoraggio,
  ) async {
    final id = mentoraggio['id']?.toString();
    if (id == null || id.isEmpty) return;

    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: const ConfigurazionePaginaDinamica(
        tabella: 'mentoraggi',
      ),
      valoriIniziali: mentoraggio,
      partecipante: false,
      mostraCampiSolaLettura: true,
      titolo: 'Modifica mentoraggio · ${mentoraggio['anno_accademico'] ?? ''}',
    );
    if (valori == null) return;

    try {
      final dati = Map<String, dynamic>.from(valori)
        ..remove('id')
        ..remove('created_at')
        ..remove('updated_at');

      await SupabaseConfig.client.rpc(
        'mentoraggio_aggiorna_backoffice',
        params: <String, dynamic>{
          'p_mentoraggio_id': id,
          'p_valori': dati,
        },
      );
      await _carica();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile modificare il mentoraggio: $e')),
      );
    }
  }

  Future<void> _gestisciTeamMentoraggio(
    Map<String, dynamic> mentoraggio,
  ) async {
    final mentoraggioId = mentoraggio['id']?.toString();
    if (mentoraggioId == null || mentoraggioId.isEmpty) return;

    try {
      final db = SupabaseConfig.client;
      final risultati = await Future.wait<dynamic>([
        db
            .from('mentoraggio_mentori')
            .select()
            .eq('mentoraggio_id', mentoraggioId),
        db.from('anagrafica').select().order('email_unipa'),
        db.from('anagrafica_riservata').select('user_id, attivo'),
      ]);

      final assegnazioni = (risultati[0] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final persone = (risultati[1] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final attivi = <String, bool>{
        for (final r in (risultati[2] as List))
          (r as Map)['user_id'].toString(): r['attivo'] == true,
      };

      final personeAttive = persone
          .where(
            (p) => attivi[p['user_id']?.toString()] == true,
          )
          .toList();

      final schema = await SupabaseConfig.caricaSchemaDatabase();
      final tipi = schema
              .tabella('mentoraggio_mentori')
              ?.campo('tipo')
              ?.valoriScelta ??
          const <String>[];

      if (!mounted) return;

      String? nuovoUtente;
      String? nuovoTipo = tipi.isEmpty ? null : tipi.first;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            String etichettaPersona(String? userId) {
              final persona = persone
                  .where((p) => p['user_id']?.toString() == userId)
                  .firstOrNull;
              if (persona == null) return userId ?? '—';
              final email = persona['email_unipa']?.toString().trim() ?? '';
              final nome =
                  '${persona['cognome'] ?? ''} ${persona['nome'] ?? ''}'.trim();
              if (email.isNotEmpty && nome.isNotEmpty) return '$email — $nome';
              return email.isNotEmpty ? email : (nome.isNotEmpty ? nome : userId ?? '—');
            }

            return AlertDialog(
              title: Text(
                'Mentori / senior · ${mentoraggio['anno_accademico'] ?? ''}',
              ),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (assegnazioni.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text('Nessun mentore/senior associato.'),
                        ),
                      for (final assegnazione in List<Map<String, dynamic>>.from(
                        assegnazioni,
                      ))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            etichettaPersona(
                              assegnazione['mentore_id']?.toString(),
                            ),
                          ),
                          subtitle: Text(
                            assegnazione['tipo']?.toString() ?? '—',
                          ),
                          trailing: IconButton(
                            tooltip: 'Rimuovi',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              try {
                                await db
                                    .from('mentoraggio_mentori')
                                    .delete()
                                    .eq('mentoraggio_id', mentoraggioId)
                                    .eq(
                                      'mentore_id',
                                      assegnazione['mentore_id'],
                                    )
                                    .eq('tipo', assegnazione['tipo']);
                                setDialogState(
                                  () => assegnazioni.remove(assegnazione),
                                );
                              } catch (e) {
                                if (!dialogContext.mounted) return;
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Impossibile rimuovere l’assegnazione: $e',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      const Divider(),
                      DropdownButtonFormField<String>(
                        initialValue: nuovoUtente,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Partecipante',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final persona in personeAttive)
                            DropdownMenuItem<String>(
                              value: persona['user_id']?.toString(),
                              child: Text(
                                etichettaPersona(
                                  persona['user_id']?.toString(),
                                ),
                              ),
                            ),
                        ],
                        onChanged: (v) => nuovoUtente = v,
                      ),
                      const SizedBox(height: 12),
                      if (tipi.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: nuovoTipo,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Ruolo nel mentoraggio',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final tipo in tipi)
                              DropdownMenuItem<String>(
                                value: tipo,
                                child: Text(tipo),
                              ),
                          ],
                          onChanged: (v) => nuovoTipo = v,
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Chiudi'),
                ),
                FilledButton.icon(
                  onPressed: nuovoUtente == null || nuovoTipo == null
                      ? null
                      : () async {
                          try {
                            final riga = <String, dynamic>{
                              'mentoraggio_id': mentoraggioId,
                              'mentore_id': nuovoUtente,
                              'tipo': nuovoTipo,
                              'assegnato_il': DateTime.now()
                                  .toIso8601String()
                                  .split('T')
                                  .first,
                            };
                            await db.from('mentoraggio_mentori').insert(riga);
                            setDialogState(() {
                              assegnazioni.add(riga);
                              nuovoUtente = null;
                            });
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Impossibile aggiungere l’assegnazione: $e',
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi'),
                ),
              ],
            );
          },
        ),
      );

      await _carica();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile gestire mentori/senior: $e')),
      );
    }
  }

  Future<void> _apriPdf(String valore) async {
    final uri = Uri.tryParse(valore);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il PDF.')),
      );
    }
  }

  Future<void> _modificaPdfMentoraggio(Map<String, dynamic> mentoraggio) async {
    final controller = TextEditingController(
      text: mentoraggio['scheda_sintesi_pdf_url']?.toString() ?? '',
    );
    final salva = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Scheda di sintesi PDF'),
            content: SizedBox(
              width: 560,
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'URL PDF',
                  hintText: 'https://...',
                ),
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
        ) ??
        false;
    if (!salva) {
      controller.dispose();
      return;
    }
    try {
      await SupabaseConfig.client.rpc(
        'mentoraggio_aggiorna_backoffice',
        params: <String, dynamic>{
          'p_mentoraggio_id': mentoraggio['id'],
          'p_valori': <String, dynamic>{
            'scheda_sintesi_pdf_url': controller.text.trim().isEmpty
                ? null
                : controller.text.trim(),
          },
        },
      );
      await _carica();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile salvare il link PDF: $e')),
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _titolo(String testo) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          testo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );

  String _team(List<_MembroTeam> team) => team.isEmpty
      ? '—'
      : team.map((m) => '${m.nome} (${m.tipo})').join(', ');
}

String _nomeInsegnamento(Map<String, dynamic> insegnamento) {
  final valore = insegnamento['insegnamento']?.toString().trim();
  return (valore != null && valore.isNotEmpty)
      ? valore
      : insegnamento['id']?.toString() ?? '—';
}

bool _valido(String? valore) =>
    valore != null && valore.isNotEmpty && valore != 'null';

class _MembroTeam {
  const _MembroTeam({required this.nome, required this.tipo});
  final String nome;
  final String tipo;
}

class _PercorsoMentee {
  const _PercorsoMentee({
    required this.insegnamento,
    required this.insegnamentoRiga,
    required this.team,
    required this.mentoraggio,
  });
  final String insegnamento;
  final Map<String, dynamic> insegnamentoRiga;
  final List<_MembroTeam> team;
  final Map<String, dynamic> mentoraggio;
}

class _PercorsoMentore {
  const _PercorsoMentore({
    required this.insegnamento,
    required this.insegnamentoRiga,
    required this.mentee,
    required this.mioTipo,
    required this.altriTeam,
    required this.mentoraggio,
  });
  final String insegnamento;
  final Map<String, dynamic> insegnamentoRiga;
  final String mentee;
  final String mioTipo;
  final List<_MembroTeam> altriTeam;
  final Map<String, dynamic> mentoraggio;
}

class _PartecipazioneEvento {
  const _PartecipazioneEvento({required this.titolo, required this.presente});
  final String titolo;
  final bool presente;
}

class _PartecipanteAnno {
  const _PartecipanteAnno({
    required this.persona,
    required this.mentee,
    required this.mentore,
    required this.eventi,
    required this.houseOfMentore,
  });
  final Map<String, dynamic> persona;
  final List<_PercorsoMentee> mentee;
  final List<_PercorsoMentore> mentore;
  final List<_PartecipazioneEvento> eventi;
  final List<String> houseOfMentore;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
