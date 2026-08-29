import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/dinamico_schema.dart';
import '../../../ui/dinamico_maschera.dart';
import '../../../app/app_session_controller.dart';
import 'partecipanti_backoffice_controller.dart';

/// Gestione applicativa del partecipante su:
/// anagrafica + anagrafica_riservata + user_roles.
class PartecipantiBackofficePage extends StatefulWidget {
  const PartecipantiBackofficePage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<PartecipantiBackofficePage> createState() =>
      _PartecipantiBackofficePageState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _PartecipantiBackofficePageState
    extends State<PartecipantiBackofficePage> {
  final ScrollController _orizzontale = ScrollController();

  late final PartecipantiBackofficeController controller;

  /// Inizializza lo stato della pagina e avvia le operazioni iniziali necessarie.
  @override
  void initState() {
    super.initState();
    controller = PartecipantiBackofficeController(widget.sessione)..carica();
    controller.addListener(_aggiornaController);
  }

  /// Aggiorna controller.
  void _aggiornaController() {
    if (mounted) setState(() {});
  }

  /// Rilascia listener e controller associati allo stato della pagina.
  @override
  void dispose() {
    controller.removeListener(_aggiornaController);
    controller.dispose();
    _orizzontale.dispose();
    super.dispose();
  }

  /// Costruisce l’interfaccia grafica di questo componente.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, vincoli) {
          final mobile = vincoli.maxWidth < 760;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: mobile ? vincoli.maxWidth - 24 : 420,
                      child: Text(
                        'Partecipanti · dati da anagrafica + anagrafica_riservata',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Aggiorna',
                      onPressed:
                          controller.caricamento ? null : controller.carica,
                      icon: const Icon(Icons.refresh),
                    ),
                    FilledButton.icon(
                      onPressed: () => _nuovo(context),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Nuovo partecipante'),
                    ),
                    if (controller.soloOwner)
                      OutlinedButton.icon(
                        onPressed: controller.caricamento
                            ? null
                            : () => _importaPartecipanti(context),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Importa partecipanti'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: controller.partecipanti.length,
                  itemBuilder: (context, i) =>
                      _schedaPartecipante(controller.partecipanti[i]),
                ),
              ),
            ],
          );
        },
      );

  /// Costruisce la scheda relativa a partecipante.
  Widget _schedaPartecipante(Map<String, dynamic> p) {
    final id = p['user_id'].toString();
    final riservato = controller.riservati[id];
    final ruolo = controller.ruoli[id];

    return Card(
      child: ExpansionTile(
        leading: Icon(
          riservato?['attivo'] == false
              ? Icons.person_off_outlined
              : Icons.person_outline,
        ),
        title: Text('${p['cognome'] ?? ''} ${p['nome'] ?? ''}'.trim()),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${p['email_unipa'] ?? ''}'
              '${ruolo == null ? '' : ' · $ruolo'}',
            ),
            if (controller.annoPreparazione != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Partecipazione ${controller.annoPreparazione}: '
                  '${_etichettaStatoPartecipazione(controller.statoPartecipazione(id, controller.annoPreparazione!))}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (controller.annoGestioneInsegnamenti != null)
              Row(
                children: [
                  Switch.adaptive(
                    value: controller.gestioneInsegnamentiAttiva(id),
                    onChanged: controller.caricamento
                        ? null
                        : (abilita) => _impostaGestioneInsegnamenti(
                              context,
                              id,
                              abilita,
                            ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Inserisci/modifica insegnamenti · '
                      '${controller.annoGestioneInsegnamenti}',
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: IconButton(
          tooltip: 'Modifica / elimina',
          onPressed: () => _azioni(context, p, riservato),
          icon: const Icon(Icons.edit_outlined),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _SezioneDati(titolo: 'Anagrafica', dati: p),
          const SizedBox(height: 12),
          _SezioneDati(
            titolo: 'Anagrafica riservata',
            dati: riservato ?? const <String, dynamic>{},
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Ruolo applicativo: ${ruolo ?? '—'}'),
          ),
        ],
      ),
    );
  }


  /// Apre insegnamenti.
  void _apriInsegnamenti(
    BuildContext context,
    Map<String, dynamic> partecipante,
  ) {
    final userId = partecipante['user_id']?.toString();
    if (userId == null || userId.isEmpty) return;
    context.go(
      Uri(
        path: '/gestione/insegnamenti',
        queryParameters: <String, String>{'docente': userId},
      ).toString(),
    );
  }

  /// Gestisce l’operazione interna “nuovo” della pagina.
  Future<void> _nuovo(BuildContext context) async {
    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: const ConfigurazionePaginaDinamica(
        tabella: 'anagrafica',
        campi: <String, PersonalizzazioneCampo>{
          'user_id': PersonalizzazioneCampo(nascosto: true),
        },
      ),
      partecipante: false,
      valoriIniziali: const <String, dynamic>{},
      titolo: 'Nuovo partecipante',
    );
    if (valori == null || !context.mounted) return;

    final password = await _chiediPassword(
      context,
      titolo: 'Password temporanea',
      descrizione:
          'Imposta la password iniziale del nuovo partecipante (minimo 8 caratteri).',
    );
    if (password == null) return;

    final errore = await controller.creaPartecipante(valori, password);
    if (!context.mounted) return;
    _mostraErrore(context, errore);
  }

  /// Gestisce l’operazione interna “importa partecipanti” della pagina.
  Future<void> _importaPartecipanti(
  BuildContext context,
  ) async {
    final anno = '2026-27';

    final conferma =
        await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Importa partecipanti',
        ),
        content: Text(
          'Verranno importate tutte le righe '
          'non ancora elaborate presenti in '
          'import_partecipanti e associate '
          'all’anno accademico $anno.\n\n'
          'Continuare?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              context,
              false,
            ),
            child: const Text(
              'Annulla',
            ),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(
              context,
              true,
            ),
            child: const Text(
              'Importa',
            ),
          ),
        ],
      ),
    );

    if (conferma != true) return;

    final errore =
        await controller
            .importaPartecipanti(
      anno,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          errore ??
              'Importazione completata.',
        ),
      ),
    );
  }

  /// Gestisce l’operazione interna “azioni” della pagina.
  Future<void> _azioni(
    BuildContext context,
    Map<String, dynamic> partecipante,
    Map<String, dynamic>? riservato,
  ) async {
    final scelta = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Modifica anagrafica'),
              onTap: () => Navigator.pop(context, 'anagrafica'),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Dati riservati e ruolo'),
              onTap: () => Navigator.pop(context, 'riservati'),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Insegnamenti del docente'),
              onTap: () => Navigator.pop(context, 'insegnamenti'),
            ),
            if (controller.annoPreparazione != null)
              ListTile(
                leading: const Icon(Icons.how_to_reg_outlined),
                title: const Text('Partecipazione prossimo anno'),
                subtitle: Text('Anno ${controller.annoPreparazione}'),
                onTap: () => Navigator.pop(context, 'partecipazione_annuale'),
              ),
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('Abilitazioni insegnamento'),
              subtitle: Text(
                controller.annoGestioneInsegnamenti == null
                    ? 'Nessun anno attivo o in preparazione'
                    : 'Anno ${controller.annoGestioneInsegnamenti}',
              ),
              onTap: controller.annoGestioneInsegnamenti == null
                  ? null
                  : () => Navigator.pop(context, 'abilitazioni_insegnamento'),
            ),
            if (controller.soloOwner ||
                controller.ruoli[partecipante['user_id']?.toString()] ==
                    'participant')
              ListTile(
                leading: const Icon(Icons.password_outlined),
                title: const Text('Reimposta password'),
                onTap: () => Navigator.pop(context, 'password'),
              ),
            if (controller.soloOwner)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Elimina partecipante'),
                onTap: () => Navigator.pop(context, 'elimina'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || scelta == null) return;
    if (scelta == 'anagrafica') {
      await _modificaAnagrafica(context, partecipante);
      return;
    }
    if (scelta == 'riservati') {
      await _modificaRiservati(context, partecipante, riservato);
      return;
    }
    if (scelta == 'insegnamenti') {
      _apriInsegnamenti(context, partecipante);
      return;
    }
    if (scelta == 'partecipazione_annuale') {
      await _modificaPartecipazioneAnnuale(context, partecipante);
      return;
    }
    if (scelta == 'abilitazioni_insegnamento') {
      await _modificaAbilitazioniInsegnamento(context, partecipante);
      return;
    }
    if (scelta == 'password') {
      await _reimpostaPassword(context, partecipante);
      return;
    }
    if (scelta == 'elimina') {
      final conferma = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminare il partecipante?'),
          content: const Text(
            'La cancellazione puo essere bloccata dal database se esistono dati storici collegati.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Elimina'),
            ),
          ],
        ),
      );
      if (conferma != true) return;
      final errore = await controller.eliminaPartecipante(
        partecipante['user_id'].toString(),
      );
      if (!context.mounted) return;
      _mostraErrore(context, errore);
    }
  }

  /// Gestisce la modifica di anagrafica.
  Future<void> _modificaAnagrafica(
    BuildContext context,
    Map<String, dynamic> partecipante,
  ) async {
    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: const ConfigurazionePaginaDinamica(
        tabella: 'anagrafica',
        campi: <String, PersonalizzazioneCampo>{
          'user_id': PersonalizzazioneCampo(solaLettura: true),
        },
      ),
      partecipante: false,
      valoriIniziali: partecipante,
      titolo: 'Modifica partecipante',
    );
    if (valori == null) return;

    final errore = await controller.salvaAnagrafica(
      partecipante['user_id'].toString(),
      valori,
      originali: partecipante,
    );
    if (!context.mounted) return;
    _mostraErrore(context, errore);
  }

  /// Imposta gestione insegnamenti.
  Future<void> _impostaGestioneInsegnamenti(
    BuildContext context,
    String userId,
    bool abilita,
  ) async {
    final errore = await controller.impostaGestioneInsegnamentiCorrente(
      userId,
      abilita,
    );
    if (!context.mounted) return;
    _mostraErrore(context, errore);
  }

  /// Gestisce la modifica di abilitazioni insegnamento.
  Future<void> _modificaAbilitazioniInsegnamento(
    BuildContext context,
    Map<String, dynamic> partecipante,
  ) async {
    final anno = controller.annoGestioneInsegnamenti;
    final userId = partecipante['user_id']?.toString();
    if (anno == null || userId == null || userId.isEmpty) return;

    var puoSelezionare = controller.abilitazioneAttiva(
      userId,
      'insegnamento_selezione',
      anno,
    );
    var gestioneInsegnamenti = controller.gestioneInsegnamentiAttiva(userId);
    var nonRichiesto = controller.abilitazioneAttiva(
      userId,
      'insegnamento_non_richiesto',
      anno,
    );

    final salva = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(
                'Abilitazioni insegnamento · $anno',
              ),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Può scegliere un insegnamento precedente'),
                      value: puoSelezionare,
                      onChanged: nonRichiesto
                          ? null
                          : (v) => setDialogState(() => puoSelezionare = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Può inserire e modificare insegnamenti',
                      ),
                      subtitle: Text(
                        'Unica abilitazione valida per l’anno accademico $anno.',
                      ),
                      value: gestioneInsegnamenti,
                      onChanged: nonRichiesto
                          ? null
                          : (v) => setDialogState(
                                () => gestioneInsegnamenti = v,
                              ),
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Nessun insegnamento richiesto'),
                      subtitle: const Text(
                        'Se attivo, scelta e creazione vengono disabilitate.',
                      ),
                      value: nonRichiesto,
                      onChanged: (v) {
                        setDialogState(() {
                          nonRichiesto = v;
                          if (v) {
                            puoSelezionare = false;
                            gestioneInsegnamenti = false;
                          }
                        });
                      },
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

    if (!salva) return;

    final errore = await controller.impostaAbilitazioniInsegnamento(
      userId,
      <String, bool>{
        'insegnamento_selezione': puoSelezionare,
        'insegnamento_creazione': gestioneInsegnamenti,
        'insegnamento_modifica': gestioneInsegnamenti,
        'insegnamento_non_richiesto': nonRichiesto,
      },
    );

    if (!context.mounted) return;
    _mostraErrore(context, errore);
  }

  /// Gestisce la modifica di partecipazione annuale.
  Future<void> _modificaPartecipazioneAnnuale(
    BuildContext context,
    Map<String, dynamic> partecipante,
  ) async {
    final anno = controller.annoPreparazione;
    final userId = partecipante['user_id']?.toString();
    if (anno == null || userId == null || userId.isEmpty) return;

    var stato = controller.statoPartecipazione(userId, anno);
    if (stato == 'non_presente') stato = 'da_contattare';

    final nuovoStato = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Partecipazione · $anno'),
        content: SizedBox(
          width: 460,
          child: DropdownButtonFormField<String>(
            initialValue: stato,
            decoration: const InputDecoration(
              labelText: 'Stato partecipazione',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'da_contattare', child: Text('Da contattare')),
              DropdownMenuItem(value: 'confermato', child: Text('Confermato')),
              DropdownMenuItem(value: 'rinuncia', child: Text('Non partecipa')),
              DropdownMenuItem(value: 'nuovo', child: Text('Nuovo partecipante')),
              DropdownMenuItem(value: 'sospeso', child: Text('Sospeso')),
            ],
            onChanged: (value) => stato = value ?? stato,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, stato),
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (nuovoStato == null) return;
    final errore = await controller.impostaPartecipazioneAnnuale(
      userId: userId,
      annoAccademico: anno,
      stato: nuovoStato,
    );
    if (!context.mounted) return;
    _mostraErrore(context, errore);
  }

  /// Gestisce l’operazione interna “reimposta password” della pagina.
  Future<void> _reimpostaPassword(
    BuildContext context,
    Map<String, dynamic> partecipante,
  ) async {
    final id = partecipante['user_id']?.toString();
    if (id == null || id.isEmpty) return;
    final nome = '${partecipante['cognome'] ?? ''} ${partecipante['nome'] ?? ''}'.trim();
    final password = await _chiediPassword(
      context,
      titolo: 'Reimposta password',
      descrizione: 'Nuova password temporanea per $nome (minimo 8 caratteri).',
    );
    if (password == null) return;
    final errore = await controller.reimpostaPassword(id, password);
    if (!context.mounted) return;
    _mostraErrore(context, errore);
  }

  /// Gestisce l’operazione interna “chiedi password” della pagina.
  Future<String?> _chiediPassword(
    BuildContext context, {
    required String titolo,
    required String descrizione,
  }) async {
    final password = TextEditingController();
    final conferma = TextEditingController();
    String? errore;
    final risultato = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(titolo),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(descrizione),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: conferma,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Conferma password'),
                ),
                if (errore != null) ...[
                  const SizedBox(height: 8),
                  Text(errore!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                final valore = password.text;
                if (valore.length < 8) {
                  setState(() => errore = 'Minimo 8 caratteri.');
                  return;
                }
                if (valore != conferma.text) {
                  setState(() => errore = 'Le password non coincidono.');
                  return;
                }
                Navigator.pop(context, valore);
              },
              child: const Text('Conferma'),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    conferma.dispose();
    return risultato;
  }

  /// Gestisce la modifica di riservati.
  Future<void> _modificaRiservati(
    BuildContext context,
    Map<String, dynamic> partecipante,
    Map<String, dynamic>? riservato,
  ) async {
    final note = TextEditingController(
      text: riservato?['note_storiche']?.toString() ?? '',
    );
    var attivo = riservato?['attivo'] != false;
    String? ruolo = controller.ruoli[partecipante['user_id'].toString()];
    final salva = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text('${partecipante['cognome'] ?? ''} ${partecipante['nome'] ?? ''}'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Partecipante attivo'),
                      value: attivo,
                      onChanged: (v) => setDialogState(() => attivo = v),
                    ),
                    TextField(
                      controller: note,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Note storiche riservate'),
                    ),
                    // Il cambio di ruolo resta owner-only: l'organizer gestisce
                    // il partecipante ma non puo elevare privilegi applicativi.
                    if (controller.soloOwner && controller.ruoliDisponibili.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: ruolo,
                        decoration: const InputDecoration(labelText: 'Ruolo applicativo'),
                        items: controller.ruoliDisponibili
                            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                            .toList(growable: false),
                        onChanged: (v) => ruolo = v,
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
      partecipante['user_id'].toString(),
      <String, dynamic>{
        'attivo': attivo,
        'note_storiche': note.text,
      },
    );
    final ruoloSelezionato = ruolo;
    if (errore == null &&
        controller.soloOwner &&
        ruoloSelezionato != null &&
        ruoloSelezionato != controller.ruoli[partecipante['user_id'].toString()]) {
      errore = await controller.cambiaRuolo(
        partecipante['user_id'].toString(),
        ruoloSelezionato,
      );
    }
    note.dispose();
    if (!context.mounted) return;
    _mostraErrore(context, errore);
  }
}


/// Modello o componente interno “SezioneDati” usato esclusivamente da questo file.
class _SezioneDati extends StatelessWidget {
  const _SezioneDati({required this.titolo, required this.dati});

  final String titolo;
  final Map<String, dynamic> dati;

  /// Costruisce l’interfaccia grafica di questo componente.
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titolo, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          if (dati.isEmpty)
            const Text('—')
          else
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                for (final voce in dati.entries.where((voce) => voce.key != 'user_id'))
                  SizedBox(
                    width: 300,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${_etichetta(voce.key)}: ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: _valore(voce.value)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      );
}

/// Gestisce l’operazione interna “etichetta stato partecipazione” della pagina.
String _etichettaStatoPartecipazione(String? stato) => switch (stato) {
  'da_contattare' => 'da confermare',
  'confermato' => 'confermato',
  'rinuncia' => 'non partecipa',
  'nuovo' => 'nuovo',
  'sospeso' => 'sospeso',
  _ => 'non impostata',
};

/// Gestisce l’operazione interna “etichetta” della pagina.
String _etichetta(String nome) {
  if (nome.isEmpty) return nome;
  final testo = nome.replaceAll('_', ' ');
  return '${testo[0].toUpperCase()}${testo.substring(1)}';
}

/// Gestisce l’operazione interna “valore” della pagina.
String _valore(Object? valore) {
  if (valore == null) return '—';
  if (valore is bool) return valore ? 'Sì' : 'No';
  final testo = valore.toString();
  return testo.isEmpty ? '—' : testo;
}

/// Mostra errore.
void _mostraErrore(BuildContext context, String? errore) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(errore ?? 'Operazione completata.')),
  );
}
