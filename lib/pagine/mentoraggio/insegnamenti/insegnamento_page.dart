import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_core.dart';
import '../../../ui/dinamico_schema.dart';
import '../../../ui/dinamico_maschera.dart';
import '../../../app/app_session_controller.dart';

import 'insegnamento_controller.dart';

/// Pagina dedicata a insegnamento.
class InsegnamentoPage extends StatefulWidget {
  const InsegnamentoPage({
    super.key,
    required this.sessione,
  });

  final SessioneController sessione;

  @override
  State<InsegnamentoPage> createState() =>
      _InsegnamentoPageState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _InsegnamentoPageState
    extends State<InsegnamentoPage>
    with TickerProviderStateMixin {
  late final InsegnamentoController _controller;

  late final SceltaInsegnamentoAnnualeController
      _sceltaController;

  StatoInsegnamentoAnnuale? _statoAnnuale;

  List<Map<String, dynamic>>
      _insegnamentiDisponibili = const [];

  bool _caricamentoScelta = true;
  String? _erroreScelta;

  TabController? _tabs;

  static const _configInsegnamento =
      ConfigurazionePaginaDinamica(
    tabella: 'insegnamenti',
    ordineCampi: <String>[
      'insegnamento',
      'cds',
      'cfu',
      'semestre',
      'anno_corso',
      'note',
    ],
    campi: <String, PersonalizzazioneCampo>{
      'docente_id':
          PersonalizzazioneCampo(
        nascosto: true,
      ),
      'cfu':
          PersonalizzazioneCampo(
        etichetta: 'CFU',
      ),
      'cds':
          PersonalizzazioneCampo(
        etichetta: 'Corso di studi',
      ),
    },
  );


  /// Ordine dei campi nella visualizzazione dell'insegnamento in questa pagina.
  /// I campi non elencati vengono mostrati dopo questi, in ordine alfabetico.
  static const _ordineVisualizzazioneInsegnamento = <String>[
    'insegnamento',
    'cds',
    'cfu',
    'semestre',
    'anno_corso',
    'note',
  ];

  /// Costruisce localmente i campi dell'insegnamento senza delegare il layout
  /// a widget di pagina condivisi.
  Widget _campiInsegnamento(
    Map<String, dynamic> valori, {
    required bool partecipante,
  }) => FutureBuilder<SchemaDatabase>(
        future: _controller.caricaSchemaDatabase(),
        builder: (context, snapshot) {
          final tabella = ConfigurazioneMaschere.applica(
            snapshot.data?.tabella(_configInsegnamento.tabella) ??
                TabellaDatabase.daRiga(_configInsegnamento.tabella, valori),
            pagina: _configInsegnamento,
          );
          final campi = tabella.campi
              .where(
                (campo) =>
                    campo.visibilePer(partecipante: partecipante) &&
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

  /// Visualizza il valore di un campo mantenendo testo formattato e booleani.
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

    _controller = InsegnamentoController(
      sessione: widget.sessione,
    );
    _sceltaController = SceltaInsegnamentoAnnualeController(
      database: _controller.db,
    );

    _controller.addListener(
      _sincronizzaTabs,
    );

    _controller.carica();

    _caricaSceltaAnnuale();
  }

  /// Rilascia listener e controller associati allo stato della pagina.
  @override
  void dispose() {
    _controller.removeListener(
      _sincronizzaTabs,
    );

    _tabs?.dispose();
    _controller.dispose();

    super.dispose();
  }

  // ============================================================
  // TAB
  // ============================================================

  /// Sincronizza tabs.
  void _sincronizzaTabs() {
    final lunghezza =
        _controller.insegnamenti.length;

    if (lunghezza == 0) {
      _tabs?.dispose();
      _tabs = null;

      if (mounted) {
        setState(() {});
      }

      return;
    }

    if (_tabs?.length == lunghezza) {
      return;
    }

    _tabs?.dispose();

    _tabs = TabController(
      length: lunghezza,
      vsync: this,
    );

    _tabs!.addListener(() {
      if (!_tabs!.indexIsChanging) {
        _controller.seleziona(
          _tabs!.index,
        );
      }
    });

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // STATO ANNUALE
  // ============================================================

  /// Carica scelta annuale.
  Future<void> _caricaSceltaAnnuale() async {
    if (mounted) {
      setState(() {
        _caricamentoScelta = true;
        _erroreScelta = null;
      });
    }

    try {
      final stato =
          await _sceltaController
              .caricaStato();

      final insegnamenti =
          await _sceltaController
              .caricaInsegnamenti();

      if (!mounted) return;

      setState(() {
        _statoAnnuale = stato;

        _insegnamentiDisponibili =
            insegnamenti;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _erroreScelta = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _caricamentoScelta = false;
        });
      }
    }
  }

  /// Gestisce l’operazione interna “ricarica tutto” della pagina.
  Future<void> _ricaricaTutto() async {
    await _controller.carica();
    await _caricaSceltaAnnuale();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.caricamento &&
            _controller.insegnamenti.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (_controller.errore != null) {
          return Center(
            child: SelectableText(
              _controller.errore!,
            ),
          );
        }

        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            _intestazione(context),

            const SizedBox(height: 12),

            _sezioneSceltaAnnuale(
              context,
            ),

            const SizedBox(height: 12),

            Expanded(
              child: _contenutoPrincipale(
                context,
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // INTESTAZIONE
  // ============================================================

  /// Gestisce l’operazione interna “intestazione” della pagina.
  Widget _intestazione(
    BuildContext context,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'I miei insegnamenti',
            style: Theme.of(context)
                .textTheme
                .headlineSmall,
          ),
        ),

        if (_statoAnnuale?.puoCreare == true &&
            _statoAnnuale?.haMentoraggio != true &&
            _statoAnnuale?.nonRichiesto != true &&
            _statoAnnuale?.soloMentore != true)
          FilledButton.icon(
            onPressed: _controller.salvataggio ? null : _nuovoAnnuale,
            icon: const Icon(Icons.add),
            label: const Text('Nuovo insegnamento'),
          ),

        if (_statoAnnuale?.puoCreare == true &&
            _statoAnnuale?.haMentoraggio != true &&
            _statoAnnuale?.nonRichiesto != true &&
            _statoAnnuale?.soloMentore != true)
          const SizedBox(width: 8),

        IconButton(
          tooltip: 'Aggiorna',
          onPressed:
              _controller.caricamento
                  ? null
                  : _ricaricaTutto,
          icon: const Icon(
            Icons.refresh,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SEZIONE SCELTA ANNUALE
  // ============================================================

  /// Gestisce l’operazione interna “sezione scelta annuale” della pagina.
  Widget _sezioneSceltaAnnuale(
    BuildContext context,
  ) {
    if (_caricamentoScelta) {
      return const LinearProgressIndicator();
    }

    if (_erroreScelta != null) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: SelectableText(
            _erroreScelta!,
          ),
        ),
      );
    }

    final stato = _statoAnnuale;

    if (stato == null) {
      return const SizedBox.shrink();
    }

    // ----------------------------------------------------------
    // SOLO MENTORE
    //
    // Il partecipante ha confermato la partecipazione all'anno
    // accademico, ma ha dichiarato di voler svolgere soltanto
    // l'attività di mentore. Lo storico degli insegnamenti resta
    // comunque visibile nella parte inferiore della pagina.
    // ----------------------------------------------------------

    if (stato.soloMentore &&
        stato.partecipazioneConfermata &&
        !stato.haMentoraggio) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.supervisor_account_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Per l’anno accademico '
                  '${stato.annoAccademico} hai indicato di voler '
                  'svolgere soltanto l’attività di mentore. '
                  'Non è quindi necessario scegliere o inserire '
                  'un insegnamento da sottoporre a mentoraggio. '
                  'Gli insegnamenti e le schede degli anni '
                  'precedenti restano consultabili qui sotto.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // NON RICHIESTO
    // ----------------------------------------------------------

    if (stato.nonRichiesto &&
        !stato.haMentoraggio) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  'Per l’anno accademico '
                  '${stato.annoAccademico} '
                  'non è richiesto '
                  'l’inserimento di un '
                  'insegnamento.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // SCELTA GIÀ EFFETTUATA
    // ----------------------------------------------------------

    if (stato.haMentoraggio) {
      final insegnamento =
          _trovaInsegnamentoDisponibile(
        stato.insegnamentoId,
      );

      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Insegnamento '
                      '${stato.annoAccademico}',
                      style:
                          Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      insegnamento == null
                          ? 'Insegnamento selezionato'
                          : _titoloInsegnamento(
                              insegnamento,
                            ),
                    ),
                  ],
                ),
              ),

              if (stato.puoModificare &&
                  insegnamento != null)
                OutlinedButton.icon(
                  onPressed:
                      _controller.salvataggio
                          ? null
                          : () =>
                              _modificaAnnuale(
                                insegnamento,
                              ),
                  icon: const Icon(
                    Icons.edit_outlined,
                  ),
                  label: const Text(
                    'Modifica',
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // NON ABILITATO
    // ----------------------------------------------------------

    if (!stato.puoSelezionare &&
        !stato.puoCreare) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  stato.partecipazioneStato != null &&
                          stato.partecipazioneStato != 'confermato' &&
                          stato.partecipazioneStato != 'nuovo'
                      ? 'Per l’anno accademico ${stato.annoAccademico} '
                          'devi prima confermare la partecipazione dalla pagina '
                          '“Il mio profilo”.'
                      : 'Per l’anno accademico ${stato.annoAccademico} '
                          'la partecipazione è registrata, ma il backoffice non '
                          'ha ancora abilitato la scelta/inserimento dell’insegnamento.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // SCELTA ANCORA DA EFFETTUARE
    // ----------------------------------------------------------

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Insegnamento per '
              '${stato.annoAccademico}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Seleziona un insegnamento '
              'già inserito negli anni '
              'precedenti oppure inseriscine '
              'uno nuovo.',
            ),

            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (stato.puoSelezionare &&
                    !stato.soloMentore)
                  FilledButton.icon(
                    onPressed:
                        _insegnamentiDisponibili
                                .isEmpty
                            ? null
                            : _scegliPrecedente,
                    icon: const Icon(
                      Icons.history,
                    ),
                    label: const Text(
                      'Scegli precedente',
                    ),
                  ),

                if (stato.puoCreare &&
                    !stato.soloMentore)
                  OutlinedButton.icon(
                    onPressed:
                        _controller.salvataggio
                            ? null
                            : _nuovoAnnuale,
                    icon: const Icon(
                      Icons.add,
                    ),
                    label: const Text(
                      'Nuovo insegnamento',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONTENUTO PRINCIPALE
  // ============================================================

  /// Costruisce il contenuto principale della paginaprincipale.
  Widget _contenutoPrincipale(
    BuildContext context,
  ) {
    final elementi =
        _controller.insegnamenti;

    if (elementi.isEmpty) {
      return Center(
        child: Text(
          _statoAnnuale?.soloMentore == true
              ? 'Per questo anno hai scelto di partecipare '
                  'soltanto come mentore. Non hai insegnamenti '
                  'storici da visualizzare.'
              : _statoAnnuale?.nonRichiesto == true
                  ? 'Nessun insegnamento richiesto per l’anno '
                      'corrente.'
                  : 'Non hai ancora inserito insegnamenti.',
        ),
      );
    }

    final tabs = _tabs;

    if (tabs == null ||
        tabs.length != elementi.length) {
      WidgetsBinding.instance
          .addPostFrameCallback(
        (_) => _sincronizzaTabs(),
      );

      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: tabs,
          isScrollable: true,
          tabs: [
            for (final item in elementi)
              Tab(
                text:
                    item.insegnamento[
                                'insegnamento']
                            ?.toString() ??
                        'Insegnamento',
              ),
          ],
        ),

        const Divider(height: 1),

        Expanded(
          child: TabBarView(
            controller: tabs,
            children: [
              for (final item in elementi)
                _tabInsegnamento(item),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TAB SINGOLO INSEGNAMENTO
  // ============================================================

  /// Gestisce l’operazione interna “tab insegnamento” della pagina.
  Widget _tabInsegnamento(
    InsegnamentoStorico item,
  ) {
    final id =
        item.insegnamento['id']
            ?.toString();

    final modificabile =
        _statoAnnuale
                ?.puoModificare ==
            true &&
        _statoAnnuale
                ?.insegnamentoId ==
            id;

    return ListView(
      padding:
          const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.insegnamento[
                            'insegnamento']
                        ?.toString() ??
                    '',
                style:
                    Theme.of(context)
                        .textTheme
                        .titleLarge,
              ),
            ),

            if (modificabile)
              OutlinedButton.icon(
                onPressed:
                    _controller.salvataggio
                        ? null
                        : () =>
                            _modificaAnnuale(
                              item.insegnamento,
                            ),
                icon: const Icon(
                  Icons.edit_outlined,
                ),
                label: const Text(
                  'Modifica insegnamento',
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        _campiInsegnamento(item.insegnamento, partecipante: true),

        const Divider(
          height: 32,
        ),

        Text(
          'Anni accademici mentorati',
          style: Theme.of(context)
              .textTheme
              .titleMedium,
        ),

        const SizedBox(height: 8),

        if (item.mentoraggi.isEmpty)
          const Text(
            'Questo insegnamento non '
            'risulta ancora mentorato.',
          ),

        for (final mentoraggio
            in item.mentoraggi)
          _schedaAnno(
            mentoraggio,
          ),
      ],
    );
  }

  // ============================================================
  // SCHEDA ANNO
  // ============================================================

  /// Costruisce la scheda relativa a anno.
  Widget _schedaAnno(
    Map<String, dynamic> mentoraggio,
  ) {
    final anno = mentoraggio['anno_accademico']?.toString() ?? '—';
    final sintesi = mentoraggio['scheda_sintesi']?.toString() ?? '';
    final azioni = mentoraggio['azioni_miglioramento']?.toString() ?? '';
    final file = mentoraggio['scheda_sintesi_pdf_url']?.toString().trim() ?? '';
    final mentoraggioId = mentoraggio['id']?.toString() ?? '';

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      margin: const EdgeInsets.only(top: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.timeline_outlined),
        title: Text('$anno · ${_controller.selezionato?.insegnamento['insegnamento'] ?? ''}'),
        subtitle: Text('Stato: ${mentoraggio['stato'] ?? '—'}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: _controller.risultatiMentoraggio(mentoraggioId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Risultati questionario non disponibili: ${snapshot.error}'),
                );
              }
              final dati = snapshot.data;
              final numero = dati?['numero_compilazioni'] ?? 0;
              final sintesiDomande = (dati?['sintesi'] as List? ?? const [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(growable: false);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Questionario studenti',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (dati == null || dati['questionario_id'] == null)
                    const Text('Nessun questionario studenti disponibile.')
                  else ...[
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final riga in sintesiDomande)
                              _rigaSintesiQuestionario(riga),
                            const Divider(),
                            Text('Risposte: $numero'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _mostraRisultatiCompleti(dati),
                          icon: const Icon(Icons.analytics_outlined),
                          label: const Text('Visualizza risultati completi'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final errore = await _controller
                                .esportaCsvQuestionarioMentoraggio(mentoraggioId);
                            if (!mounted || errore == null) return;
                            _messaggio(errore);
                          },
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Esporta CSV'),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const Divider(height: 28),
          Text(
            'Scheda di sintesi',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (sintesi.isEmpty)
            const Text('Scheda di sintesi non ancora disponibile.')
          else
            TestoHtmlMinimo(testo: sintesi),
          const Divider(height: 28),
          Text(
            'Azioni di miglioramento',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(azioni.isEmpty ? '—' : azioni),
          if (file.isNotEmpty) ...[
            const Divider(height: 28),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _apriSchedaSintesi(file),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Scheda di sintesi PDF/DOCX'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Costruisce la riga relativa a sintesi questionario.
  Widget _rigaSintesiQuestionario(Map<String, dynamic> riga) {
    final tipo = riga['tipo']?.toString() ?? '';
    String valore;
    if (tipo == 'scala') {
      final media = double.tryParse(riga['media']?.toString() ?? '');
      valore = media == null ? '—' : media.toStringAsFixed(2);
    } else if (tipo == 'booleano' || tipo == 'scelta_singola') {
      final frequenze = Map<String, dynamic>.from(riga['frequenze'] as Map? ?? const {});
      valore = frequenze.entries.map((e) => '${e.key}: ${e.value}').join(' · ');
      if (valore.isEmpty) valore = '—';
    } else {
      valore = '${riga['numero_risposte'] ?? 0} risposte';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(riga['testo']?.toString() ?? '')),
          const SizedBox(width: 12),
          Text(valore),
        ],
      ),
    );
  }

  /// Mostra risultati completi.
  Future<void> _mostraRisultatiCompleti(Map<String, dynamic> dati) async {
    final sintesi = (dati['sintesi'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Risultati questionario studenti'),
        content: SizedBox(
          width: 720,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('Compilazioni: ${dati['numero_compilazioni'] ?? 0}'),
              const SizedBox(height: 12),
              for (final riga in sintesi) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(riga['testo']?.toString() ?? ''),
                  subtitle: Text(_descrizioneRisultato(riga)),
                ),
                if ((riga['testi'] as List? ?? const []).isNotEmpty)
                  ...((riga['testi'] as List).map(
                    (testo) => Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 6),
                      child: Text('• $testo'),
                    ),
                  )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  /// Gestisce l’operazione interna “descrizione risultato” della pagina.
  String _descrizioneRisultato(Map<String, dynamic> riga) {
    final tipo = riga['tipo']?.toString() ?? '';
    if (tipo == 'scala') {
      final media = double.tryParse(riga['media']?.toString() ?? '');
      return media == null
          ? 'Nessuna risposta'
          : 'Media ${media.toStringAsFixed(2)} · ${riga['numero_risposte'] ?? 0} risposte';
    }
    if (tipo == 'booleano' || tipo == 'scelta_singola') {
      final frequenze = Map<String, dynamic>.from(riga['frequenze'] as Map? ?? const {});
      return frequenze.entries.map((e) => '${e.key}: ${e.value}').join(' · ');
    }
    return '${riga['numero_risposte'] ?? 0} risposte testuali';
  }

  /// Apre scheda sintesi.
  Future<void> _apriSchedaSintesi(String valore) async {
    try {
      final url = await _controller.urlSchedaSintesi(valore);
      await _apriPdf(url);
    } catch (e) {
      final eccezione = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile aprire la scheda di sintesi.',
      );
      _messaggio(eccezione.messaggio);
    }
  }

  // ============================================================
  // SCELTA PRECEDENTE
  // ============================================================

  Future<void>
      _scegliPrecedente() async {
    if (_statoAnnuale?.soloMentore == true) {
      _messaggio(
        'Hai scelto di partecipare soltanto come mentore: '
        'non è richiesto un insegnamento.',
      );
      return;
    }

    String? selezionato;

    final conferma =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          StatefulBuilder(
        builder: (
          context,
          setDialogState,
        ) {
          return AlertDialog(
            title: const Text(
              'Scegli insegnamento',
            ),

            content: SizedBox(
              width: 520,
              child:
                  DropdownButtonFormField<
                      String>(
                isExpanded: true,

                decoration:
                    const InputDecoration(
                  labelText:
                      'Insegnamento',
                  border:
                      OutlineInputBorder(),
                ),

                items: [
                  for (final insegnamento
                      in _insegnamentiDisponibili)
                    DropdownMenuItem<
                        String>(
                      value:
                          insegnamento[
                                  'id']
                              ?.toString(),
                      child: Text(
                        _titoloInsegnamento(
                          insegnamento,
                        ),
                      ),
                    ),
                ],

                onChanged: (value) {
                  setDialogState(
                    () {
                      selezionato =
                          value;
                    },
                  );
                },
              ),
            ),

            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                  dialogContext,
                  false,
                ),
                child: const Text(
                  'Annulla',
                ),
              ),

              FilledButton(
                onPressed:
                    selezionato == null
                        ? null
                        : () =>
                            Navigator.pop(
                              dialogContext,
                              true,
                            ),
                child: const Text(
                  'Conferma',
                ),
              ),
            ],
          );
        },
      ),
    );

    if (conferma != true ||
        selezionato == null) {
      return;
    }

    try {
      await _sceltaController
          .seleziona(
        selezionato!,
      );

      await _ricaricaTutto();

      if (!mounted) return;

      _messaggio(
        'Insegnamento associato '
        'all’anno accademico.',
      );
    } on AppException catch (e) {
      if (!mounted) return;

      _messaggio(
        e.messaggio,
      );
    } catch (e) {
      if (!mounted) return;

      _messaggio(
        e.toString(),
      );
    }
  }

  // ============================================================
  // NUOVO INSEGNAMENTO ANNUALE
  // ============================================================

  Future<void>
      _nuovoAnnuale() async {
    if (_statoAnnuale?.soloMentore == true) {
      _messaggio(
        'Hai scelto di partecipare soltanto come mentore: '
        'non è richiesto un insegnamento.',
      );
      return;
    }

    final valori =
        await mostraMascheraDinamica(
      context: context,
      configurazione:
          _configInsegnamento,
      valoriIniziali:
          <String, dynamic>{
        'insegnamento': '',
      },
      partecipante: true,
      titolo:
          'Nuovo insegnamento',
    );

    if (valori == null) {
      return;
    }

    try {
      await _sceltaController.crea(
        valori,
      );

      await _ricaricaTutto();

      if (!mounted) return;

      _messaggio(
        'Insegnamento creato e '
        'associato all’anno corrente.',
      );
    } on AppException catch (e) {
      if (!mounted) return;

      _messaggio(
        e.messaggio,
      );
    } catch (e) {
      if (!mounted) return;

      _messaggio(
        e.toString(),
      );
    }
  }

  // ============================================================
  // MODIFICA AUTORIZZATA
  // ============================================================

  /// Gestisce la modifica di annuale.
  Future<void> _modificaAnnuale(
    Map<String, dynamic> iniziali,
  ) async {
    final id =
        iniziali['id']
            ?.toString();

    if (id == null) {
      return;
    }

    final valori =
        await mostraMascheraDinamica(
      context: context,
      configurazione:
          _configInsegnamento,
      valoriIniziali:
          iniziali,
      partecipante: true,
      titolo:
          'Dati dell’insegnamento '
          '${iniziali['insegnamento'] ?? ''}',
    );

    if (valori == null) {
      return;
    }

    try {
      await _sceltaController
          .modifica(
        id,
        valori,
      );

      await _ricaricaTutto();

      if (!mounted) return;

      _messaggio(
        'Insegnamento aggiornato.',
      );
    } on AppException catch (e) {
      if (!mounted) return;

      _messaggio(
        e.messaggio,
      );
    } catch (e) {
      if (!mounted) return;

      _messaggio(
        e.toString(),
      );
    }
  }

  // ============================================================
  // PDF
  // ============================================================

  /// Apre pdf.
  Future<void> _apriPdf(
    String url,
  ) async {
    final uri =
        Uri.tryParse(url);

    if (uri == null ||
        !await launchUrl(
          uri,
          mode:
              LaunchMode.externalApplication,
        )) {
      if (!mounted) return;

      _messaggio(
        'Impossibile aprire il PDF.',
      );
    }
  }

  // ============================================================
  // UTILITÀ
  // ============================================================

  Map<String, dynamic>?
      _trovaInsegnamentoDisponibile(
    String? id,
  ) {
    if (id == null) {
      return null;
    }

    for (final insegnamento
        in _insegnamentiDisponibili) {
      if (insegnamento['id']
              ?.toString() ==
          id) {
        return insegnamento;
      }
    }

    return null;
  }

  /// Costruisce il titolo relativo a insegnamento.
  String _titoloInsegnamento(
    Map<String, dynamic> insegnamento,
  ) {
    final valore = insegnamento['insegnamento']?.toString().trim() ?? '';
    return valore.isEmpty ? 'Insegnamento' : valore;
  }

  /// Gestisce l’operazione interna “messaggio” della pagina.
  void _messaggio(
    String messaggio,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          messaggio,
        ),
      ),
    );
  }
}
