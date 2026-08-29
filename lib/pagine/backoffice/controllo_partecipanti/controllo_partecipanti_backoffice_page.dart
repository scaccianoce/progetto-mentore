import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'controllo_partecipanti_backoffice_controller.dart';

import '../../../app/app_core.dart';
import '../../../ui/dinamico_schema.dart';
import '../../../ui/dinamico_maschera.dart';

/// Controllo operativo per anno accademico costruito direttamente dalle
/// tabelle reali del database, senza view di riepilogo.
class ControlloPartecipantiBackofficePage extends StatefulWidget {
  const ControlloPartecipantiBackofficePage({super.key});

  @override
  State<ControlloPartecipantiBackofficePage> createState() =>
      _ControlloPartecipantiBackofficePageState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _ControlloPartecipantiBackofficePageState
    extends State<ControlloPartecipantiBackofficePage> {
  late final ControlloPartecipantiBackofficeController controller;

  @override
  void initState() {
    super.initState();
    controller = ControlloPartecipantiBackofficeController()
      ..inizializza();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Costruisce l’interfaccia grafica di questo componente.
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          children: [
          Row(
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: controller.annoSelezionato,
                  decoration:
                      const InputDecoration(labelText: 'Anno accademico'),
                  items: [
                    for (final anno in controller.anni)
                      DropdownMenuItem(value: anno, child: Text(anno)),
                  ],
                  onChanged: controller.caricamento
                      ? null
                      : controller.selezionaAnno,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Aggiorna',
                onPressed: controller.carica,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _contenuto()),
        ],
        ),
      );

  /// Costruisce il contenuto principale della pagina.
  Widget _contenuto() {
    if (controller.caricamento) return const Center(child: CircularProgressIndicator());
    if (controller.errore != null) return Center(child: Text(controller.errore!));
    if (controller.partecipanti.isEmpty) {
      return const Center(child: Text('Nessun partecipante per questo anno.'));
    }

    return ListView.builder(
      itemCount: controller.partecipanti.length,
      itemBuilder: (context, index) {
        final r = controller.partecipanti[index];
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

  /// Costruisce la scheda relativa a mentee.
  Widget _schedaMentee(PercorsoMenteeControllo p) => Card(
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

  /// Costruisce la scheda relativa a mentore.
  Widget _schedaMentore(PercorsoMentoreControllo p) => Card(
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

  /// Gestisce l’operazione interna “stato mentoraggio” della pagina.
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
              ],
            ),
          ],
        ),
      );

  /// Gestisce la modifica di insegnamento.
  Future<void> _modificaInsegnamento(
    Map<String, dynamic> insegnamento,
  ) async {
    final id = insegnamento['id']?.toString();
    if (id == null || id.isEmpty) return;

    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: const ConfigurazionePaginaDinamica(
        tabella: 'insegnamenti',
        ordineCampi: <String>[
          'insegnamento',
          'docente_id',
          'cds',
          'cfu',
          'semestre',
          'anno_corso',
          'note',
        ],
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
        await controller.aggiornaInsegnamento(id, dati);
      }
      await controller.carica();
    } catch (e) {
      if (!mounted) return;
      final eccezione = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile modificare l’insegnamento.',
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(eccezione.messaggio)));
    }
  }

  /// Gestisce la modifica di mentoraggio.
  Future<void> _modificaMentoraggio(
    Map<String, dynamic> mentoraggio,
  ) async {
    final id = mentoraggio['id']?.toString();
    if (id == null || id.isEmpty) return;

    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: const ConfigurazionePaginaDinamica(
        tabella: 'mentoraggi',
        ordineCampi: <String>[
          'data_inizio',
          'data_fine',
          'numero_studenti',
          'sede',
          'svolgimento',
          'giorni_orari_lezioni',
          'note',
          'azioni_miglioramento',
          'osservazioni_aula',
          'osservazioni_focus_group',
          'stato_mentoraggio',
          'stato',
        ],
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

      await controller.aggiornaMentoraggio(id, dati);
      await controller.carica();
    } catch (e) {
      if (!mounted) return;
      final eccezione = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile modificare il mentoraggio.',
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(eccezione.messaggio)));
    }
  }

  /// Gestisce team mentoraggio.
  Future<void> _gestisciTeamMentoraggio(
    Map<String, dynamic> mentoraggio,
  ) async {
    final mentoraggioId = mentoraggio['id']?.toString();
    if (mentoraggioId == null || mentoraggioId.isEmpty) return;

    try {
      final risultati = await controller.caricaDatiTeam(mentoraggioId);

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

      final schema = await controller.caricaSchemaDatabase();
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
                                await controller.rimuoviAssegnazione(
                                  mentoraggioId: mentoraggioId,
                                  mentoreId: assegnazione['mentore_id'],
                                  tipo: assegnazione['tipo'],
                                );
                                setDialogState(
                                  () => assegnazioni.remove(assegnazione),
                                );
                              } catch (e) {
                                if (!dialogContext.mounted) return;
                                final eccezione = AppErrorMapper.converti(
                                  e,
                                  messaggioGenerico:
                                      'Impossibile rimuovere l’assegnazione.',
                                );
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(content: Text(eccezione.messaggio)),
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
                            await controller.aggiungiAssegnazione(riga);
                            setDialogState(() {
                              assegnazioni.add(riga);
                              nuovoUtente = null;
                            });
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            final eccezione = AppErrorMapper.converti(
                              e,
                              messaggioGenerico:
                                  'Impossibile aggiungere l’assegnazione.',
                            );
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(eccezione.messaggio)),
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

      await controller.carica();
    } catch (e) {
      if (!mounted) return;
      final eccezione = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile gestire mentori/senior.',
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(eccezione.messaggio)));
    }
  }

  /// Apre pdf.
  Future<void> _apriPdf(String valore) async {
    try {
      final url = await controller.urlSchedaSintesi(valore);
      final uri = Uri.tryParse(url);

      if (uri == null ||
          !await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          )) {
        throw const AppException(
          'Impossibile aprire il documento.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      final errore = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile aprire la scheda di sintesi.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errore.messaggio)),
      );
    }
  }


  /// Gestisce l’operazione interna “titolo” della pagina.
  Widget _titolo(String testo) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          testo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );

  /// Gestisce l’operazione interna “team” della pagina.
  String _team(List<MembroTeamControllo> team) => team.isEmpty
      ? '—'
      : team.map((m) => '${m.nome} (${m.tipo})').join(', ');
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
