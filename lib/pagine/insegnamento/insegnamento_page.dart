import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_exception.dart';
import '../../dinamico/maschera_dinamica_controller.dart';
import '../../dinamico/maschera_dinamica_widget.dart';
import '../../sessione_controller.dart';

import 'insegnamento_controller.dart';
import 'scelta_insegnamento_annuale_controller.dart';

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

class _InsegnamentoPageState
    extends State<InsegnamentoPage>
    with TickerProviderStateMixin {
  late final InsegnamentoController _controller;

  final SceltaInsegnamentoAnnualeController
      _sceltaController =
      SceltaInsegnamentoAnnualeController();

  StatoInsegnamentoAnnuale? _statoAnnuale;

  List<Map<String, dynamic>>
      _insegnamentiDisponibili = const [];

  bool _caricamentoScelta = true;
  String? _erroreScelta;

  TabController? _tabs;

  static const _configInsegnamento =
      ConfigurazionePaginaDinamica(
    tabella: 'insegnamenti',
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

  @override
  void initState() {
    super.initState();

    _controller = InsegnamentoController(
      sessione: widget.sessione,
    );

    _controller.addListener(
      _sincronizzaTabs,
    );

    _controller.carica();

    _caricaSceltaAnnuale();
  }

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

  Widget _sezioneSceltaAnnuale(
    BuildContext context,
  ) {
    if (_caricamentoScelta) {
      return const LinearProgressIndicator();
    }

    if (_erroreScelta != null) {
      return Card(
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

        CampiTabellaDinamici(
          configurazione:
              _configInsegnamento,
          valori:
              item.insegnamento,
          partecipante: true,
        ),

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

  Widget _schedaAnno(
    Map<String, dynamic> mentoraggio,
  ) {
    final anno =
        mentoraggio[
                    'anno_accademico']
                ?.toString() ??
            '—';

    final sintesi =
        mentoraggio[
                    'scheda_sintesi']
                ?.toString() ??
            '';

    final pdf =
        mentoraggio[
                    'scheda_sintesi_pdf_url']
                ?.toString()
                .trim() ??
            '';

    return Card(
      margin:
          const EdgeInsets.only(
        top: 12,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    anno,
                    style:
                        Theme.of(context)
                            .textTheme
                            .titleMedium,
                  ),
                ),

                if (pdf.isNotEmpty)
                  TextButton.icon(
                    onPressed: () =>
                        _apriPdf(pdf),
                    icon: const Icon(
                      Icons
                          .picture_as_pdf_outlined,
                    ),
                    label: const Text(
                      'Scheda PDF',
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            if (sintesi.isEmpty)
              const Text(
                'Scheda di sintesi non '
                'ancora disponibile.',
              )
            else
              TestoHtmlMinimo(
                testo: sintesi,
              ),
          ],
        ),
      ),
    );
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

  String _titoloInsegnamento(
    Map<String, dynamic> insegnamento,
  ) {
    final valore = insegnamento['insegnamento']?.toString().trim() ?? '';
    final email = widget.sessione.utente?.email?.trim() ?? '';

    if (valore.isEmpty) {
      return email.isEmpty ? 'Insegnamento' : 'Insegnamento — $email';
    }

    return email.isEmpty ? valore : '$valore — $email';
  }

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