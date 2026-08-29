import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/app_core.dart';
import 'package:flutter/material.dart';

import '../../../ui/dinamico_schema.dart';
import '../../../ui/dinamico_maschera.dart';
import '../../../app/app_session_controller.dart';
import '../../../ui/questionario_pubblico_card.dart';
import '../../../supporto/questionario_pubblico_controller.dart';
import '../../../ui/questionario_risultati_card.dart';
import '../../../supporto/questionario_risultati_controller.dart';
import 'insegnamenti_backoffice_controller.dart';


/// Gestione centralizzata di:
/// insegnamenti -> mentoraggi -> mentoraggio_mentori.
class InsegnamentiBackofficePage extends StatefulWidget {
  const InsegnamentiBackofficePage({
    super.key,
    required this.sessione,
    this.docenteIdIniziale,
  });

  final SessioneController sessione;
  final String? docenteIdIniziale;

  @override
  State<InsegnamentiBackofficePage> createState() =>
      _InsegnamentiBackofficePageState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _InsegnamentiBackofficePageState
    extends State<InsegnamentiBackofficePage> {
  final _filtro = TextEditingController();
  String? _docenteId;
  late final QuestionarioPubblicoController questionariController;
  late final QuestionarioRisultatiController questionarioRisultatiController;

  late final InsegnamentiBackofficeController controller;

  static const _configInsegnamento = ConfigurazionePaginaDinamica(
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
    campi: <String, PersonalizzazioneCampo>{
      'id': PersonalizzazioneCampo(nascosto: true),
      'cfu': PersonalizzazioneCampo(etichetta: 'CFU'),
      'cds': PersonalizzazioneCampo(etichetta: 'Corso di studi'),
    },
  );

  static const _configMentoraggio = ConfigurazionePaginaDinamica(
    tabella: 'mentoraggi',
    ordineCampi: <String>[
      'anno_accademico',
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
    campi: <String, PersonalizzazioneCampo>{
      'id': PersonalizzazioneCampo(nascosto: true),
      'insegnamento_id': PersonalizzazioneCampo(solaLettura: true),
      'anno_accademico': PersonalizzazioneCampo(solaLettura: true),
      'scheda_sintesi_pdf_url': PersonalizzazioneCampo(nascosto: true),
      'azioni_miglioramento': PersonalizzazioneCampo(
        etichetta: 'Azioni di miglioramento',
      ),
    },
  );


  /// Ordine dei campi nella visualizzazione backoffice dell'insegnamento.
  /// Può essere modificato senza influenzare la pagina del partecipante.
  static const _ordineVisualizzazioneInsegnamento = <String>[
    'insegnamento',
    'docente_id',
    'cds',
    'cfu',
    'semestre',
    'anno_corso',
    'note',
  ];

  /// Costruisce localmente il blocco dati dell'insegnamento.
  Widget _campiInsegnamento(Map<String, dynamic> valori) =>
      FutureBuilder<SchemaDatabase>(
        future: controller.caricaSchemaDatabase(),
        builder: (context, snapshot) {
          final tabella = ConfigurazioneMaschere.applica(
            snapshot.data?.tabella(_configInsegnamento.tabella) ??
                TabellaDatabase.daRiga(_configInsegnamento.tabella, valori),
            pagina: _configInsegnamento,
          );
          final campi = tabella.campi
              .where(
                (campo) =>
                    campo.visibilePer(partecipante: false) &&
                    valori.containsKey(campo.nome),
              )
              .toList()
            ..sort((a, b) {
              final ia = _ordineVisualizzazioneInsegnamento.indexOf(a.nome);
              final ib = _ordineVisualizzazioneInsegnamento.indexOf(b.nome);
              final oa = ia < 0 ? 1000 : ia;
              final ob = ib < 0 ? 1000 : ib;
              if (oa != ob) return oa.compareTo(ob);
              return a.etichetta.compareTo(b.etichetta);
            });
          return Column(
            children: [
              for (final campo in campi)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    campo.etichetta,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: _valoreCampoInsegnamento(
                    campo,
                    valori[campo.nome],
                  ),
                ),
            ],
          );
        },
      );

  /// Visualizza un singolo valore nel blocco locale dell'insegnamento.
  Widget _valoreCampoInsegnamento(CampoDatabase campo, Object? valore) {
    final testo = switch (valore) {
      null => '',
      bool value => value ? 'Sì' : 'No',
      _ => valore.toString(),
    };
    if (campo.tipo == TipoCampoDinamico.testoFormattato) {
      return TestoHtmlMinimo(testo: testo);
    }
    return SelectableText(testo.trim().isEmpty ? '—' : testo);
  }

  /// Inizializza lo stato della pagina e avvia le operazioni iniziali necessarie.
  @override
  void initState() {
    super.initState();
    controller = InsegnamentiBackofficeController(widget.sessione)..carica();
    controller.addListener(_aggiornaController);
    _docenteId = widget.docenteIdIniziale;
    questionariController = QuestionarioPubblicoController(widget.sessione)
      ..carica();
    questionariController.addListener(_ridisegna);
    questionarioRisultatiController = QuestionarioRisultatiController(
      widget.sessione,
    );
    _filtro.addListener(_ridisegna);
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
    _filtro.removeListener(_ridisegna);
    _filtro.dispose();
    questionariController.removeListener(_ridisegna);
    questionariController.dispose();
    super.dispose();
  }

  /// Richiede il ridisegno della pagina.
  void _ridisegna() {
    if (mounted) setState(() {});
  }

  /// Costruisce l’interfaccia grafica di questo componente.
  @override
  Widget build(BuildContext context) {
    final righe = _insegnamentiFiltrati();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 220, maxWidth: 520),
              child: Text(
                'Insegnamenti · mentoraggi · team',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Aggiorna',
              onPressed: controller.caricamento ? null : controller.carica,
              icon: const Icon(Icons.refresh),
            ),
            FilledButton.icon(
              onPressed: controller.caricamento ? null : _nuovoInsegnamento,
              icon: const Icon(Icons.add),
              label: const Text('Nuovo insegnamento'),
            ),
            if (controller.soloOwner)
              OutlinedButton.icon(
                onPressed: controller.caricamento
                    ? null
                    : () => _importaInsegnamenti(context),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Importa insegnamenti'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: MediaQuery.sizeOf(context).width < 760
                  ? double.infinity
                  : 360,
              child: TextField(
                controller: _filtro,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Cerca insegnamento, docente o email',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: MediaQuery.sizeOf(context).width < 760
                  ? double.infinity
                  : 360,
              child: DropdownButtonFormField<String?>(
                key: ValueKey<String>(
                  'docente-${controller.partecipanti.length}-${_docenteId ?? 'tutti'}',
                ),
                initialValue: _docenteId == null ||
                        controller.partecipanti.any(
                          (p) => p['user_id']?.toString() == _docenteId,
                        )
                    ? _docenteId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Filtra per docente',
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tutti i docenti'),
                  ),
                  ...controller.partecipanti.map(
                    (p) => DropdownMenuItem<String?>(
                      value: p['user_id']?.toString(),
                      child: Text(
                        controller.etichettaPersona(p['user_id']?.toString()),
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _docenteId = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: righe.isEmpty
              ? const Center(child: Text('Nessun insegnamento trovato.'))
              : ListView.builder(
                  itemCount: righe.length,
                  itemBuilder: (context, index) =>
                      _schedaInsegnamento(righe[index]),
                ),
        ),
      ],
    );
  }

  /// Gestisce l’operazione interna “insegnamenti filtrati” della pagina.
  List<Map<String, dynamic>> _insegnamentiFiltrati() {
    final testo = _filtro.text.trim().toLowerCase();
    final righe = controller.insegnamenti
        .where((i) {
          final docenteId = i['docente_id']?.toString();
          if (_docenteId != null && docenteId != _docenteId) return false;

          if (testo.isEmpty) return true;
          final nome = i['insegnamento']?.toString().toLowerCase() ?? '';
          final persona = controller.personaPerId(docenteId);
          final cognome = persona?['cognome']?.toString().toLowerCase() ?? '';
          final nomeDocente = persona?['nome']?.toString().toLowerCase() ?? '';
          final email = persona?['email_unipa']?.toString().toLowerCase() ?? '';
          return nome.contains(testo) ||
              cognome.contains(testo) ||
              nomeDocente.contains(testo) ||
              email.contains(testo);
        })
        .toList(growable: true);

    righe.sort((a, b) {
      final docenteA = controller.personaPerId(a['docente_id']?.toString());
      final docenteB = controller.personaPerId(b['docente_id']?.toString());
      final cognomeA = docenteA?['cognome']?.toString().toLowerCase() ?? '';
      final cognomeB = docenteB?['cognome']?.toString().toLowerCase() ?? '';
      final c = cognomeA.compareTo(cognomeB);
      if (c != 0) return c;
      final nomeA = docenteA?['nome']?.toString().toLowerCase() ?? '';
      final nomeB = docenteB?['nome']?.toString().toLowerCase() ?? '';
      final n = nomeA.compareTo(nomeB);
      if (n != 0) return n;
      return (a['insegnamento']?.toString().toLowerCase() ?? '').compareTo(
        b['insegnamento']?.toString().toLowerCase() ?? '',
      );
    });
    return righe;
  }

  /// Costruisce la scheda relativa a insegnamento.
  Widget _schedaInsegnamento(Map<String, dynamic> insegnamento) {
    final id = insegnamento['id']?.toString() ?? '';
    final docenteId = insegnamento['docente_id']?.toString();
    final titolo = insegnamento['insegnamento']?.toString() ?? 'Insegnamento';
    final mentoraggi =
        controller.mentoraggi
            .where((m) => m['insegnamento_id']?.toString() == id)
            .toList(growable: true)
          ..sort(
            (a, b) => (b['anno_accademico']?.toString() ?? '').compareTo(
              a['anno_accademico']?.toString() ?? '',
            ),
          );

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(titolo),
        subtitle: Text(controller.etichettaPersona(docenteId)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _modificaInsegnamento(insegnamento),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifica insegnamento'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _nuovoMentoraggio(insegnamento),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Nuovo mentoraggio'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.caricamento
                      ? null
                      : () => _eliminaInsegnamento(insegnamento),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Elimina insegnamento'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _campiInsegnamento(insegnamento),
          const Divider(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Mentoraggi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (mentoraggi.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Nessun mentoraggio associato.'),
              ),
            ),
          for (final m in mentoraggi) _schedaMentoraggio(m),
        ],
      ),
    );
  }

  /// Costruisce la scheda relativa a mentoraggio.
  Widget _schedaMentoraggio(Map<String, dynamic> m) {
    final id = m['id']?.toString() ?? '';
    final anno = m['anno_accademico']?.toString() ?? '—';
    final team = controller.assegnazioni
        .where((a) => a['mentoraggio_id']?.toString() == id)
        .toList(growable: false);
    final questionario = questionariController.questionarioPerMentoraggio(id);

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Anno accademico $anno',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _modificaMentoraggio(m),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Modifica mentoraggio'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _gestisciTeam(m),
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text('Mentori / senior'),
                  ),
                  if (m['stato']?.toString().trim().toLowerCase() !=
                      'completato')
                    OutlinedButton.icon(
                      onPressed: controller.caricamento
                          ? null
                          : () => _eliminaMentoraggio(m),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Elimina mentoraggio'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Text('Stato: ${m['stato'] ?? '—'}'),
                Text('Data inizio: ${m['data_inizio'] ?? '—'}'),
                Text('Data fine: ${m['data_fine'] ?? '—'}'),
                Text('Visita 1: ${m['data_visita_1'] ?? '—'}'),
                Text('Focus group: ${m['data_focus_group'] ?? '—'}'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              team.isEmpty
                  ? 'Mentori / senior: —'
                  : 'Mentori / senior: ${team.map((a) => '${controller.etichettaPersona(a['mentore_id']?.toString())} (${a['tipo'] ?? '—'})').join(', ')}',
            ),
            if (questionario != null) ...[
              const SizedBox(height: 10),
              QuestionarioRisultatiCard(
                controller: questionarioRisultatiController,
                questionario: questionario,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Elimina mentoraggio.
  Future<void> _eliminaMentoraggio(Map<String, dynamic> mentoraggio) async {
    final id = mentoraggio['id']?.toString();

    if (id == null || id.isEmpty) {
      _messaggio('ID mentoraggio non disponibile.');
      return;
    }

    final stato = mentoraggio['stato']?.toString().trim().toLowerCase() ?? '';

    if (stato == 'completato') {
      _messaggio('Un mentoraggio completato non può essere eliminato.');
      return;
    }

    final anno = mentoraggio['anno_accademico']?.toString() ?? '—';

    final conferma =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Elimina mentoraggio'),
            content: Text(
              'Vuoi eliminare definitivamente il mentoraggio '
              'dell’anno accademico $anno?\n\n'
              'Questa operazione non elimina l’insegnamento.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Elimina'),
              ),
            ],
          ),
        ) ??
        false;

    if (!conferma) return;

    final errore = await controller.eliminaMentoraggioBackoffice(id);

    if (!mounted) return;
    _messaggio(errore);
  }

  /// Avvia la creazione di insegnamento.
  Future<void> _nuovoInsegnamento() async {
    final docenteId = _docenteId;
    final configurazione = docenteId == null
        ? _configInsegnamento
        : const ConfigurazionePaginaDinamica(
            tabella: 'insegnamenti',
            campi: <String, PersonalizzazioneCampo>{
              'id': PersonalizzazioneCampo(nascosto: true),
              'docente_id': PersonalizzazioneCampo(nascosto: true),
              'cfu': PersonalizzazioneCampo(etichetta: 'CFU'),
              'cds': PersonalizzazioneCampo(etichetta: 'Corso di studi'),
            },
          );

    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: configurazione,
      valoriIniziali: <String, dynamic>{
        'docente_id': ?docenteId,
        'insegnamento': '',
      },
      partecipante: false,
      titolo: docenteId == null
          ? 'Nuovo insegnamento'
          : 'Nuovo insegnamento · ${controller.etichettaPersona(docenteId)}',
    );
    if (valori == null) return;

    final errore = await controller.salvaInsegnamentoBackoffice(
      valori,
      docenteIdForzato: docenteId,
    );
    if (!mounted) return;
    _messaggio(errore);
  }

  /// Gestisce la modifica di insegnamento.
  Future<void> _modificaInsegnamento(Map<String, dynamic> iniziali) async {
    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: _configInsegnamento,
      valoriIniziali: iniziali,
      partecipante: false,
      titolo: 'Modifica ${iniziali['insegnamento'] ?? 'insegnamento'}',
    );
    if (valori == null) return;

    final errore = await controller.salvaInsegnamentoBackoffice(
      valori,
      insegnamentoId: iniziali['id']?.toString(),
    );
    if (!mounted) return;
    _messaggio(errore);
  }

  /// Elimina insegnamento.
  Future<void> _eliminaInsegnamento(Map<String, dynamic> insegnamento) async {
    final id = insegnamento['id']?.toString();
    if (id == null || id.isEmpty) {
      _messaggio('ID insegnamento non disponibile.');
      return;
    }

    final nome = insegnamento['insegnamento']?.toString() ?? 'insegnamento';

    final conferma =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Elimina insegnamento'),
            content: Text(
              'Vuoi eliminare definitivamente l’insegnamento:\n\n'
              '“$nome”?\n\n'
              'Verranno eliminati anche gli eventuali mentoraggi '
              'non completati associati. Se esiste almeno un '
              'mentoraggio con stato “Completato”, la cancellazione '
              'sarà impedita.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Elimina'),
              ),
            ],
          ),
        ) ??
        false;

    if (!conferma) return;

    final errore = await controller.eliminaInsegnamentoBackoffice(id);
    if (!mounted) return;
    _messaggio(errore);
  }

  /// Avvia la creazione di mentoraggio.
  Future<void> _nuovoMentoraggio(Map<String, dynamic> insegnamento) async {
    final id = insegnamento['id']?.toString();
    if (id == null) return;
    final usati = controller.mentoraggi
        .where((m) => m['insegnamento_id']?.toString() == id)
        .map((m) => m['anno_accademico']?.toString())
        .whereType<String>()
        .toSet();
    final disponibili = controller.anni
        .map((a) => a['codice']?.toString())
        .whereType<String>()
        .where((a) => !usati.contains(a))
        .toList(growable: false);

    if (disponibili.isEmpty) {
      _messaggio(
        'Tutti gli anni accademici disponibili hanno già un mentoraggio.',
      );
      return;
    }

    String? anno = controller.annoGestioneInsegnamenti;
    if (!disponibili.contains(anno)) anno = disponibili.first;
    final conferma =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Nuovo mentoraggio'),
              content: DropdownButtonFormField<String>(
                initialValue: anno,
                decoration: const InputDecoration(
                  labelText: 'Anno accademico',
                  border: OutlineInputBorder(),
                ),
                items: disponibili
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(growable: false),
                onChanged: (v) => setDialogState(() => anno = v),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: anno == null
                      ? null
                      : () => Navigator.pop(context, true),
                  child: const Text('Crea'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!conferma || anno == null) return;
    final errore = await controller.creaMentoraggioBackoffice(id, anno!);
    if (!mounted) return;
    _messaggio(errore);
  }

  /// Gestisce la modifica di mentoraggio.
  Future<void> _modificaMentoraggio(Map<String, dynamic> iniziali) async {
    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: _configMentoraggio,
      valoriIniziali: iniziali,
      partecipante: false,
      mostraCampiSolaLettura: true,
      titolo: 'Mentoraggio ${iniziali['anno_accademico'] ?? ''}',
      contenutoExtra: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionarioPubblicoCard(
            controller: questionariController,
            mentoraggioId: iniziali['id'].toString(),
            consentiRigenerazione: true,
          ),
          const SizedBox(height: 12),
          _SchedaSintesiFileCard(
            controller: controller,
            mentoraggio: iniziali,
            onAggiornato: controller.carica,
          ),
        ],
      ),
    );
    if (valori == null) return;
    final id = iniziali['id']?.toString();
    if (id == null) return;

    final errore = await controller.salvaMentoraggioBackoffice(id, valori);
    if (!mounted) return;
    _messaggio(errore);
  }

  /// Gestisce team.
  Future<void> _gestisciTeam(Map<String, dynamic> mentoraggio) async {
    final mentoraggioId = mentoraggio['id']?.toString();
    if (mentoraggioId == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _DialogTeamMentoraggio(
        controller: controller,
        mentoraggioId: mentoraggioId,
        onAggiornato: () async {
          await controller.carica();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  /// Gestisce l’operazione interna “messaggio” della pagina.
  void _messaggio(String? errore) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errore ?? 'Operazione completata.')));
  }

  /// Gestisce l’operazione interna “importa insegnamenti” della pagina.
  Future<void> _importaInsegnamenti(BuildContext context) async {
    if (controller.anni.isEmpty) {
      _mostraErrore(context, 'Non risultano anni accademici disponibili.');
      return;
    }

    String? anno = controller.annoCorrente;

    anno ??= controller.anni
        .map((riga) => riga['codice']?.toString())
        .whereType<String>()
        .where((codice) => codice.isNotEmpty)
        .firstOrNull;

    if (anno == null) {
      _mostraErrore(context, 'Nessun anno accademico disponibile.');
      return;
    }

    final anni = controller.anni
        .map((riga) => riga['codice']?.toString())
        .whereType<String>()
        .where((codice) => codice.isNotEmpty)
        .toSet()
        .toList();

    final conferma =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Importa insegnamenti'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Verranno elaborate le righe non ancora '
                      'importate presenti nella tabella '
                      'import_insegnamenti.',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: anno,
                      decoration: const InputDecoration(
                        labelText: 'Anno accademico',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final codice in anni)
                          DropdownMenuItem(value: codice, child: Text(codice)),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => anno = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Per ogni riga verranno creati:\n'
                      '• l’insegnamento collegato al docente tramite email;\n'
                      '• il mentoraggio relativo all’anno selezionato.',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annulla'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.upload),
                  label: const Text('Importa'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!conferma || anno == null) return;

    final errore = await controller.importaInsegnamenti(anno!);

    if (!context.mounted) return;

    _mostraErrore(context, errore);
  }
}

/// Modello o componente interno “DialogTeamMentoraggio” usato esclusivamente da questo file.
class _DialogTeamMentoraggio extends StatefulWidget {
  const _DialogTeamMentoraggio({
    required this.controller,
    required this.mentoraggioId,
    required this.onAggiornato,
  });

  final InsegnamentiBackofficeController controller;
  final String mentoraggioId;
  final Future<void> Function() onAggiornato;

  @override
  State<_DialogTeamMentoraggio> createState() => _DialogTeamMentoraggioState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _DialogTeamMentoraggioState extends State<_DialogTeamMentoraggio> {
  String? _personaId;
  String? _tipo;
  bool _salvataggio = false;

  List<Map<String, dynamic>> get _assegnazioni => widget.controller.assegnazioni
      .where((a) => a['mentoraggio_id']?.toString() == widget.mentoraggioId)
      .toList(growable: false);

  /// Costruisce l’interfaccia grafica di questo componente.
  @override
  Widget build(BuildContext context) {
    final tipi = widget.controller.tipiMentoreDisponibili.isEmpty
        ? const <String>['mentor', 'senior']
        : widget.controller.tipiMentoreDisponibili;
    _tipo ??= tipi.firstOrNull;

    return AlertDialog(
      title: const Text('Mentori / senior'),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Non è previsto alcun limite numerico per mentor o senior. '
              'È impedita soltanto la duplicazione della stessa persona con lo stesso ruolo.',
            ),
            const SizedBox(height: 12),
            if (_assegnazioni.isEmpty)
              const Text('Nessun membro assegnato.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final a in _assegnazioni)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          widget.controller.etichettaPersona(
                            a['mentore_id']?.toString(),
                          ),
                        ),
                        subtitle: Text(a['tipo']?.toString() ?? '—'),
                        trailing: IconButton(
                          tooltip: 'Rimuovi',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _salvataggio ? null : () => _rimuovi(a),
                        ),
                      ),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _personaId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Persona (email)',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.controller.partecipanti
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: p['user_id']?.toString(),
                            child: Text(
                              widget.controller.etichettaPersona(
                                p['user_id']?.toString(),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _salvataggio
                        ? null
                        : (v) => setState(() => _personaId = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _tipo,
                    decoration: const InputDecoration(
                      labelText: 'Ruolo',
                      border: OutlineInputBorder(),
                    ),
                    items: tipi
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(growable: false),
                    onChanged: _salvataggio
                        ? null
                        : (v) => setState(() => _tipo = v),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _salvataggio || _personaId == null || _tipo == null
                      ? null
                      : _aggiungi,
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvataggio ? null : () => Navigator.pop(context),
          child: const Text('Chiudi'),
        ),
      ],
    );
  }

  /// Gestisce l’operazione interna “aggiungi” della pagina.
  Future<void> _aggiungi() async {
    setState(() => _salvataggio = true);
    final errore = await widget.controller.aggiungiAssegnazione(
      widget.mentoraggioId,
      _personaId!,
      _tipo!,
    );
    if (!mounted) return;
    if (errore != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errore)));
    } else {
      _personaId = null;
      await widget.onAggiornato();
    }
    if (mounted) setState(() => _salvataggio = false);
  }

  /// Gestisce l’operazione interna “rimuovi” della pagina.
  Future<void> _rimuovi(Map<String, dynamic> riga) async {
    setState(() => _salvataggio = true);
    final errore = await widget.controller.eliminaAssegnazione(riga);
    if (!mounted) return;
    if (errore != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errore)));
    } else {
      await widget.onAggiornato();
    }
    if (mounted) setState(() => _salvataggio = false);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Mostra errore.
void _mostraErrore(BuildContext context, String? errore) {
  if (!context.mounted) return;

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(errore ?? 'Operazione completata.')));
}

// ============================================================================
// WIDGET PRIVATO: SCHEDA DI SINTESI SU STORAGE
// ============================================================================

/// Modello o componente interno “SchedaSintesiFileCard” usato esclusivamente da questo file.
class _SchedaSintesiFileCard extends StatefulWidget {
  const _SchedaSintesiFileCard({
    required this.controller,
    required this.mentoraggio,
    this.onAggiornato,
  });

  final InsegnamentiBackofficeController controller;
  final Map<String, dynamic> mentoraggio;
  final Future<void> Function()? onAggiornato;

  @override
  State<_SchedaSintesiFileCard> createState() => _SchedaSintesiFileCardState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _SchedaSintesiFileCardState extends State<_SchedaSintesiFileCard> {
  bool _operazione = false;

  String get _stato =>
      widget.mentoraggio['stato']?.toString().trim().toLowerCase() ?? '';

  String get _valoreFile =>
      widget.mentoraggio['scheda_sintesi_pdf_url']?.toString().trim() ?? '';

  bool get _completato => _stato == 'completato';

  /// Costruisce l’interfaccia grafica di questo componente.
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Scheda di sintesi · documento',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              _completato
                  ? 'Puoi caricare o sostituire la scheda definitiva in PDF o DOCX.'
                  : 'Il caricamento è disponibile quando il mentoraggio è in stato Completato.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_valoreFile.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: _operazione ? null : _apri,
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Apri / scarica'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: !_completato || _operazione ? null : _carica,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(
                    _valoreFile.isEmpty
                        ? 'Carica scheda di sintesi'
                        : 'Sostituisci scheda',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Gestisce l’operazione interna “carica” della pagina.
  Future<void> _carica() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx'],
    );
    if (file == null) return;

    final estensione = file.name.split('.').last.toLowerCase();
    if (!const {'pdf', 'docx'}.contains(estensione)) {
      _messaggio('Sono ammessi soltanto file PDF e DOCX.');
      return;
    }

    setState(() => _operazione = true);
    try {
      final bytes = await file.readAsBytes();
      final id = widget.mentoraggio['id'].toString();
      final anno =
          widget.mentoraggio['anno_accademico']?.toString() ?? 'senza-anno';
      final contentType = estensione == 'pdf'
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      final path = await widget.controller.salvaSchedaSintesi(
        mentoraggioId: id,
        annoAccademico: anno,
        estensione: estensione,
        bytes: bytes,
        contentType: contentType,
        percorsoPrecedente: _valoreFile,
      );

      widget.mentoraggio['scheda_sintesi_pdf_url'] = path;
      if (widget.onAggiornato != null) {
        await widget.onAggiornato!();
      }
      if (!mounted) return;
      setState(() {});
      _messaggio('Scheda di sintesi caricata.');
    } catch (e) {
      _messaggio(
        AppErrorMapper.converti(
          e,
          messaggioGenerico: 'Impossibile caricare la scheda di sintesi.',
        ).messaggio,
      );
    } finally {
      if (mounted) setState(() => _operazione = false);
    }
  }

  /// Gestisce l’operazione interna “apri” della pagina.
  Future<void> _apri() async {
    setState(() => _operazione = true);
    try {
      final valore = _valoreFile;
      final url = await widget.controller.urlSchedaSintesi(valore);

      final uri = Uri.tryParse(url);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const AppException('Impossibile aprire il documento.');
      }
    } catch (e) {
      _messaggio(
        AppErrorMapper.converti(
          e,
          messaggioGenerico: 'Impossibile aprire la scheda di sintesi.',
        ).messaggio,
      );
    } finally {
      if (mounted) setState(() => _operazione = false);
    }
  }

  /// Gestisce l’operazione interna “messaggio” della pagina.
  void _messaggio(String testo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
  }
}
