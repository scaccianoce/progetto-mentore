import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

import '../../../app/app_core.dart';
import '../../../ui/dinamico_schema.dart';
import '../../../ui/dinamico_maschera.dart';
import '../../../app/app_session_controller.dart';
import '../../../ui/questionario_pubblico_card.dart';
import '../../../supporto/questionario_pubblico_controller.dart';
import 'mentore_controller.dart';

/// Pagina dedicata a mentore.
class MentorePage extends StatefulWidget {
  const MentorePage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<MentorePage> createState() => _MentorePageState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _MentorePageState extends State<MentorePage> {
  /// Ordine dei campi nella sola visualizzazione della pagina Mentore.
  ///
  /// La lista è indipendente da Mentee e dalla maschera di modifica.
  static const _ordineVisualizzazione = <String>[
    'data_inizio',
    'data_fine',
    'giorni_orari_lezioni',
    'sede',
    'numero_studenti',
    'svolgimento',
    'note',
    'stato_mentoraggio',
    'stato',
    'osservazioni_aula',
    'data_visita_1',
    'data_visita_2',
    'data_visita_3',
    'data_visita_4',
    'osservazioni_focus_group',
    'data_focus_group',
    'data_incontro_finale',
    'scheda_sintesi',
    'data_invio_scheda',
    'azioni_miglioramento',
    'anno_accademico',
    'link_questionario',
  ];

  static const configurazione = ConfigurazionePaginaDinamica(
    tabella: 'mentoraggi',
    ordineCampi: <String>[
      'stato_mentoraggio',
      'stato',
      'osservazioni_aula',
      'data_visita_1',
      'data_visita_2',
      'data_visita_3',
      'data_visita_4',
      'osservazioni_focus_group',
      'data_focus_group',
      'data_incontro_finale',
      'scheda_sintesi',
      'data_invio_scheda',
      'azioni_miglioramento',
      'link_questionario',
    ],
    campi: <String, PersonalizzazioneCampo>{
      'insegnamento_id': PersonalizzazioneCampo(nascosto: true),
      'anno_accademico': PersonalizzazioneCampo(
        modificabilePartecipante: false,
      ),
      'data_inizio': PersonalizzazioneCampo(modificabilePartecipante: false),
      'data_fine': PersonalizzazioneCampo(modificabilePartecipante: false),
      'numero_studenti': PersonalizzazioneCampo(
        modificabilePartecipante: false,
      ),
      'sede': PersonalizzazioneCampo(modificabilePartecipante: false),
      'note': PersonalizzazioneCampo(modificabilePartecipante: false),
      'azioni_miglioramento': PersonalizzazioneCampo(
        etichetta: 'Azioni di miglioramento',
      ),
      'svolgimento': PersonalizzazioneCampo(modificabilePartecipante: false),
      'giorni_orari_lezioni': PersonalizzazioneCampo(
        modificabilePartecipante: false,
      ),
      'data_invio_scheda': PersonalizzazioneCampo(solaLettura: true),
      'scheda_sintesi_pdf_url': PersonalizzazioneCampo(nascosto: true),
    },
  );

  late final MentoreController controller;
  late final QuestionarioPubblicoController questionariController;

  Iterable<PercorsoMentore> get _percorsiPrecedenti =>
      controller.percorsi.where((percorso) => !percorso.annoCorrente);

  /// Inizializza lo stato della pagina e avvia le operazioni iniziali necessarie.
  @override
  void initState() {
    super.initState();
    controller = MentoreController()..carica();
    questionariController = QuestionarioPubblicoController(widget.sessione)
      ..carica();
  }

  /// Rilascia listener e controller associati allo stato della pagina.
  @override
  void dispose() {
    controller.dispose();
    questionariController.dispose();
    super.dispose();
  }

  /// Costruisce l’interfaccia grafica di questo componente.
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (controller.caricamento && controller.percorsi.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (controller.errore != null) ...<Widget>[
              Text(
                controller.errore!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: controller.percorsi.isEmpty
                  ? const Center(child: Text('Nessun mentoraggio assegnato.'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final elenco = _elencoMentoraggi();
                        final dettaglio = Card(
                          margin: EdgeInsets.zero,
                          child: _dettaglio(),
                        );
                        if (constraints.maxWidth >= 800) {
                          return Row(
                            children: <Widget>[
                              SizedBox(width: 390, child: elenco),
                              const VerticalDivider(width: 24),
                              Expanded(child: dettaglio),
                            ],
                          );
                        }
                        return Column(
                          children: <Widget>[
                            Expanded(flex: 1, child: elenco),
                            const Divider(height: 20),
                            Expanded(flex: 2, child: dettaglio),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );

  /// Costruisce localmente l'elenco dei mentoraggi assegnati al mentore.
  Widget _elencoMentoraggi() => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: ListView.separated(
      itemCount: controller.percorsi.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final percorso = controller.percorsi[index];
        final id = percorso.mentoraggio['id']?.toString() ?? '';
        final docente =
            '${percorso.docente['nome'] ?? ''} ${percorso.docente['cognome'] ?? ''}'
                .trim();
        final anno = percorso.mentoraggio['anno_accademico']?.toString() ?? '';
        return ListTile(
          selected: id == controller.selezionato?.mentoraggio['id']?.toString(),
          title: Text(
            percorso.insegnamento['insegnamento']?.toString() ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('$docente · $anno · ${percorso.mioRuolo}'),
          onTap: () => controller.seleziona(percorso),
        );
      },
    ),
  );

  /// Costruisce la visualizzazione completa del mentoraggio selezionato.
  Widget _dettaglio() {
    final percorso = controller.selezionato;
    if (percorso == null) {
      return const Center(child: Text('Seleziona un mentoraggio.'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        LayoutBuilder(
          builder: (context, constraints) {
            final titolo = Text(
              'Ruolo mentore · ${percorso.mentoraggio['anno_accademico'] ?? ''}',
              style: Theme.of(context).textTheme.headlineSmall,
            );
            if (!percorso.annoCorrente) {
              return titolo;
            }
            final pulsante = FilledButton.icon(
              onPressed: controller.salvataggio ? null : _modifica,
              icon: const Icon(Icons.edit),
              label: const Text('Modifica'),
            );
            if (constraints.maxWidth < 480) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  titolo,
                  const SizedBox(height: 12),
                  pulsante,
                ],
              );
            }
            return Row(
              children: <Widget>[
                Expanded(child: titolo),
                pulsante,
              ],
            );
          },
        ),
        _rigaInformazione(
          'Insegnamento',
          percorso.insegnamento['insegnamento']?.toString() ?? '',
        ),
        _rigaInformazione(
          'Semestre',
          percorso.insegnamento['semestre']?.toString() ?? '',
        ),
        _rigaInformazione(
          'Mentee',
          '${percorso.docente['nome'] ?? ''} ${percorso.docente['cognome'] ?? ''}'
              .trim(),
        ),
        _rigaInformazione(
          'Ruolo svolto',
          percorso.mioRuolo.isEmpty ? '—' : percorso.mioRuolo,
        ),
        if (!percorso.annoCorrente)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.lock_outline),
            title: Text(
              'Mentoraggio storico',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'I mentoraggi degli anni precedenti sono consultabili ma non modificabili.',
            ),
          ),
        const Divider(),
        Text('Team', style: Theme.of(context).textTheme.titleMedium),
        ...percorso.team.map(
          (mentore) => ListTile(
            title: Text(
              '${mentore['nome'] ?? ''} ${mentore['cognome'] ?? ''}'.trim(),
            ),
            subtitle: Text(mentore['tipo']?.toString() ?? ''),
          ),
        ),
        const Divider(),
        _campiMentoraggio(percorso.mentoraggio),
        const Divider(height: 28),
        _SchedaSintesiFileCard(
          mentoraggio: percorso.mentoraggio,
          controller: controller,
          solaLettura: !percorso.annoCorrente,
          onAggiornato: controller.carica,
        ),
        if (percorso.annoCorrente && _percorsiPrecedenti.isNotEmpty) ...[
          const Divider(height: 40),
          Text(
            'Percorsi precedenti',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final storico in _percorsiPrecedenti) ...[
            Text(
              '${storico.insegnamento['insegnamento'] ?? ''} · '
              '${storico.mentoraggio['anno_accademico'] ?? ''}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _rigaInformazione(
              'Scheda di sintesi',
              storico.mentoraggio['scheda_sintesi']?.toString() ?? '',
            ),
            _rigaInformazione(
              'Azioni di miglioramento',
              storico.mentoraggio['azioni_miglioramento']?.toString() ?? '',
            ),
            _SchedaSintesiFileCard(
              mentoraggio: storico.mentoraggio,
              controller: controller,
              solaLettura: true,
            ),
            const Divider(height: 32),
          ],
        ],
      ],
    );
  }

  /// Crea una riga informativa standard del dettaglio Mentore.
  Widget _rigaInformazione(String etichetta, String valore) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(etichetta, style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Text(valore.trim().isEmpty ? '—' : valore),
  );

  /// Visualizza i campi del mentoraggio con un ordine autonomo per il Mentore.
  Widget _campiMentoraggio(Map<String, dynamic> valori) {
    return FutureBuilder<SchemaDatabase>(
      future: controller.caricaSchemaDatabase(),
      builder: (context, snapshot) {
        final tabella = ConfigurazioneMaschere.applica(
          snapshot.data?.tabella(configurazione.tabella) ??
              TabellaDatabase.daRiga(configurazione.tabella, valori),
          pagina: configurazione,
        );
        final campi = tabella.campi
            .where(
              (campo) =>
                  campo.visibilePer(partecipante: true) &&
                  valori.containsKey(campo.nome),
            )
            .toList(growable: false);

        int posizione(String nome) {
          final indice = _ordineVisualizzazione.indexOf(nome);
          return indice < 0 ? 1000 : indice;
        }

        campi.sort((a, b) {
          final confronto = posizione(a.nome).compareTo(posizione(b.nome));
          return confronto != 0
              ? confronto
              : a.etichetta.compareTo(b.etichetta);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Attività di mentoraggio',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            for (final campo in campi)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  campo.etichetta,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: _valoreVisualizzato(campo, valori[campo.nome]),
              ),
          ],
        );
      },
    );
  }

  /// Converte il valore di un campo nel widget di sola visualizzazione.
  Widget _valoreVisualizzato(CampoDatabase campo, Object? valore) {
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

  /// Gestisce l’operazione interna “modifica” della pagina.
  Future<void> _modifica() async {
    final percorso = controller.selezionato;
    if (percorso == null || !percorso.annoCorrente) return;
    await questionariController.carica();
    if (!mounted) return;
    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: configurazione,
      valoriIniziali: percorso.mentoraggio,
      partecipante: true,
      titolo:
          'Aggiorna ${percorso.insegnamento['insegnamento'] ?? ''} · ${percorso.mentoraggio['anno_accademico'] ?? ''}',
      contenutoExtra: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionarioPubblicoCard(
            controller: questionariController,
            mentoraggioId: percorso.mentoraggio['id'].toString(),
          ),
          const SizedBox(height: 12),
          _SchedaSintesiFileCard(
            mentoraggio: percorso.mentoraggio,
            controller: controller,
            onAggiornato: controller.carica,
          ),
        ],
      ),
    );
    if (valori == null) return;
    try {
      await controller.salvaMentoraggio(valori);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.messaggio)));
    }
  }
}

// ============================================================================
// WIDGET PRIVATO: SCHEDA DI SINTESI SU STORAGE
// ============================================================================

/// Modello o componente interno “SchedaSintesiFileCard” usato esclusivamente da questo file.
class _SchedaSintesiFileCard extends StatefulWidget {
  const _SchedaSintesiFileCard({
    required this.mentoraggio,
    required this.controller,
    this.solaLettura = false,
    this.onAggiornato,
  });

  final Map<String, dynamic> mentoraggio;
  final MentoreController controller;
  final bool solaLettura;
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
              widget.solaLettura
                  ? 'Documento disponibile in sola lettura.'
                  : _completato
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
                if (!widget.solaLettura)
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
      final path = '$anno/$id/scheda_sintesi.$estensione';
      final contentType = estensione == 'pdf'
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

      final precedente = _valoreFile;
      await widget.controller.salvaSchedaSintesi(
        mentoraggioId: id,
        annoAccademico: anno,
        estensione: estensione,
        bytes: bytes,
        contentType: contentType,
        percorsoPrecedente: precedente,
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
