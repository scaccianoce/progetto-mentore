import 'package:flutter/material.dart';

import '../../app/app_core.dart';
import '../../ui/dinamico_schema.dart';
import '../../ui/dinamico_maschera.dart';
import '../../app/app_session_controller.dart';
import '../../supporto/utilita.dart';
import 'profilo_controller.dart';

/// Pagina dedicata a profilo.
class ProfiloPage extends StatefulWidget {
  const ProfiloPage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<ProfiloPage> createState() => _ProfiloPageState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _ProfiloPageState extends State<ProfiloPage> {
  /// Ordine dei campi nella sola visualizzazione del profilo.
  ///
  /// La maschera di modifica continua a seguire la propria configurazione e
  /// può quindi evolvere indipendentemente da questa lista.
  static const _ordineVisualizzazione = <String>[
    'nome',
    'cognome',
    'email_unipa',
    'cellulare',
    'cod_ssd',
    'anno_prima_partecipazione',
    'pagina_personale_unipa',
  ];

  late final ProfiloController _controller;

  bool get _partecipante => widget.sessione.ruolo == AppRole.participant;

  ConfigurazionePaginaDinamica get _configurazione =>
      ConfigurazionePaginaDinamica(
        tabella: 'anagrafica',
        ordineCampi: const <String>[
          'nome',
          'cognome',
          'email_unipa',
          'cellulare',
          'cod_ssd',
          'anno_prima_partecipazione',
          'pagina_personale_unipa',
        ],
        campi: <String, PersonalizzazioneCampo>{
          'user_id': const PersonalizzazioneCampo(nascosto: true),
          'email_unipa': const PersonalizzazioneCampo(solaLettura: true),
          'cod_ssd': PersonalizzazioneCampo(
            tipo: TipoCampoDinamico.scelta,
            valoriScelta: _controller.ssd
                .map((riga) => riga['cod_ssd'].toString())
                .toList(growable: false),
          ),
          'anno_prima_partecipazione': PersonalizzazioneCampo(
            tipo: TipoCampoDinamico.scelta,
            valoriScelta: _controller.anniAccademici,
          ),
        },
      );

  /// Inizializza lo stato della pagina e avvia le operazioni iniziali necessarie.
  @override
  void initState() {
    super.initState();
    _controller = ProfiloController(sessione: widget.sessione)..carica();
  }

  /// Rilascia listener e controller associati allo stato della pagina.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Costruisce l’interfaccia grafica di questo componente.
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final profilo = _controller.profilo;
      final cardPartecipazione = _cardPartecipazione(context);
      if (_controller.caricamento && profilo == null) {
        return const Center(child: CircularProgressIndicator());
      }

      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Il mio profilo',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _controller.salvataggioPassword
                          ? null
                          : _cambiaPassword,
                      icon: const Icon(Icons.password_outlined),
                      label: const Text('Modifica password'),
                    ),
                    const SizedBox(width: 8),
                    if (_controller.puoModificare)
                      FilledButton.icon(
                        onPressed: _controller.salvataggio ? null : _apriEditor,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Modifica'),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _controller.richiediModifica,
                        icon: const Icon(Icons.lock_open_outlined),
                        label: const Text('Richiedi modifica'),
                      ),
                  ],
                ),
                if (_controller.errore != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _controller.errore!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: profilo == null
                      ? const Center(child: Text('Profilo non trovato.'))
                      : ListView(
                          children: <Widget>[
                            _campiProfilo(profilo),
                            if (cardPartecipazione != null) ...<Widget>[
                              const SizedBox(height: 20),
                              cardPartecipazione,
                            ],
                            const SizedBox(height: 20),
                            _storicoPartecipazioni(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  /// Visualizza i campi anagrafici nell'ordine specifico della pagina Profilo.
  Widget _campiProfilo(Map<String, dynamic> valori) =>
      FutureBuilder<SchemaDatabase>(
        future: _controller.caricaSchemaDatabase(),
        builder: (context, snapshot) {
          final tabella = ConfigurazioneMaschere.applica(
            snapshot.data?.tabella(_configurazione.tabella) ??
                TabellaDatabase.daRiga(_configurazione.tabella, valori),
            pagina: _configurazione,
          );
          final campi = tabella.campi
              .where(
                (campo) =>
                    campo.visibilePer(partecipante: _partecipante) &&
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

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final campo in campi)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        campo.etichetta,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: _valoreProfilo(campo, valori[campo.nome]),
                    ),
                ],
              ),
            ),
          );
        },
      );

  /// Converte un valore del profilo nel widget di sola lettura.
  Widget _valoreProfilo(CampoDatabase campo, Object? valore) {
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

  Widget? _cardPartecipazione(BuildContext context) {
    final stato = _controller.partecipazioneAnnuale;
    if (stato == null || !stato.disponibile || stato.annoAccademico == null) {
      return null;
    }

    final anno = stato.annoAccademico!;
    final tema = Theme.of(context);

    if (stato.daConfermare) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Partecipazione $anno',
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Conferma se desideri partecipare al Progetto Mentore nel '
                'prossimo anno accademico. Se confermi, ti verranno chieste '
                'alcune informazioni sulle preferenze per l’attività di '
                'mentoraggio. La comunicazione dell’insegnamento avverrà '
                'separatamente nella pagina “I miei insegnamenti”.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _controller.salvataggioPartecipazione
                        ? null
                        : _apriRicognizioneAnnuale,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Confermo la partecipazione'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _controller.salvataggioPartecipazione
                        ? null
                        : () => _rispondiPartecipazione(false),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Non parteciperò'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return null;
  }

  /// Mostra le risposte storiche raggruppate per anno accademico.
  Widget _storicoPartecipazioni() {
    final partecipazioni = _controller.partecipazioniAnnuali;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Partecipazioni per anno accademico',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Aggiorna partecipazioni',
                  onPressed: _controller.caricamento
                      ? null
                      : _controller.carica,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (partecipazioni.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Text(
                'Nessuna partecipazione annuale associata a questo account.',
              ),
            ),
          for (
            var indice = 0;
            indice < partecipazioni.length;
            indice++
          ) ...<Widget>[
            if (indice > 0) const Divider(height: 1),
            _tilePartecipazione(partecipazioni[indice]),
          ],
        ],
      ),
    );
  }

  Widget _tilePartecipazione(PartecipazioneAnnualeProfilo partecipazione) {
    final righe =
        <({String etichetta, Object? valore})>[
          (etichetta: 'Stato', valore: _etichettaStato(partecipazione.stato)),
          (etichetta: 'Risposta inviata', valore: partecipazione.rispostaAt),
          (
            etichetta: 'Periodo preferito per l’attività di mentore',
            valore: partecipazione.preferenzaPeriodoMentore,
          ),
          (
            etichetta: 'Note sull’attività di mentore',
            valore: partecipazione.noteAttivitaMentore,
          ),
          (
            etichetta: 'Solo attività di mentore',
            valore: partecipazione.soloMentore,
          ),
          (
            etichetta: 'Valutazione dei mentori precedenti',
            valore: partecipazione.valutazioneMentoriPrecedenti,
          ),
          (
            etichetta: 'Richiesta di cambiare mentore',
            valore: partecipazione.cambiareMentore,
          ),
          (
            etichetta: 'Note sui mentori',
            valore: partecipazione.noteSuiMentori,
          ),
          (
            etichetta: 'Indicazioni sui mentee seguiti',
            valore: partecipazione.cambiareMenteeSeguiti,
          ),
          (
            etichetta: 'Disponibile per il mentoring degli esami',
            valore: partecipazione.disponibileMentoringEsami,
          ),
          (
            etichetta: 'Segnalazioni e suggerimenti',
            valore: partecipazione.segnalazioniSuggerimenti,
          ),
        ].where(
          (riga) =>
              riga.valore != null && riga.valore.toString().trim().isNotEmpty,
        );

    return ExpansionTile(
      key: ValueKey<String?>(partecipazione.annoAccademico),
      leading: Icon(_iconaStato(partecipazione.stato)),
      title: Text(partecipazione.annoAccademico ?? 'Anno non indicato'),
      subtitle: Text(_etichettaStato(partecipazione.stato)),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: <Widget>[
        for (final riga in righe)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              riga.etichetta,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: SelectableText(_formattaRispostaAnnuale(riga.valore)),
          ),
      ],
    );
  }

  String _formattaRispostaAnnuale(Object? valore) => switch (valore) {
    DateTime data => formattaData(data),
    bool risposta => risposta ? 'Sì' : 'No',
    _ => valore?.toString() ?? '—',
  };

  String _etichettaStato(String? stato) => switch (stato) {
    'da_contattare' => 'Da confermare',
    'confermato' => 'Partecipazione confermata',
    'rinuncia' => 'Non partecipa',
    'nuovo' => 'Nuovo partecipante',
    'sospeso' => 'Partecipazione sospesa',
    _ => 'Stato non indicato',
  };

  IconData _iconaStato(String? stato) => switch (stato) {
    'confermato' || 'nuovo' => Icons.check_circle_outline,
    'rinuncia' => Icons.event_busy_outlined,
    'sospeso' => Icons.pause_circle_outline,
    _ => Icons.info_outline,
  };

  /// Gestisce l’operazione interna “rispondi partecipazione” della pagina.
  Future<void> _rispondiPartecipazione(bool partecipa) async {
    try {
      await _controller.rispondiPartecipazione(partecipa);
    } on AppException catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errore.messaggio)));
    }
  }

  /// Apre ricognizione annuale.
  Future<void> _apriRicognizioneAnnuale() async {
    final stato = _controller.partecipazioneAnnuale;
    if (stato == null || stato.annoAccademico == null) return;

    final risultato = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RicognizioneAnnualeDialog(
        annoAccademico: stato.annoAccademico!,
        iniziali: stato,
      ),
    );

    if (risultato == null) return;

    try {
      await _controller.salvaRicognizioneAnnuale(risultato);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Partecipazione e preferenze registrate correttamente.',
          ),
        ),
      );
    } on AppException catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errore.messaggio)));
    }
  }

  /// Gestisce l’operazione interna “cambia password” della pagina.
  Future<void> _cambiaPassword() async {
    final password = TextEditingController();
    final conferma = TextEditingController();
    String? errore;

    final nuovaPassword = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Modifica password'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nuova password',
                    helperText: 'Minimo 8 caratteri',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: conferma,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Conferma nuova password',
                  ),
                ),
                if (errore != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      errore!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
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
                  setState(() => errore = 'Inserisci almeno 8 caratteri.');
                  return;
                }
                if (valore != conferma.text) {
                  setState(() => errore = 'Le password non coincidono.');
                  return;
                }
                Navigator.pop(context, valore);
              },
              child: const Text('Salva password'),
            ),
          ],
        ),
      ),
    );

    password.dispose();
    conferma.dispose();
    if (nuovaPassword == null) return;

    try {
      await _controller.cambiaPassword(nuovaPassword);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password modificata correttamente.')),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.messaggio)));
    }
  }

  /// Apre editor.
  Future<void> _apriEditor() async {
    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: _configurazione,
      valoriIniziali: _controller.profilo!,
      partecipante: _partecipante,
      titolo: 'Modifica profilo',
    );
    if (valori == null) return;
    try {
      await _controller.salva(valori);
    } on AppException catch (errore) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errore.messaggio)));
      }
    }
  }
}

/// Modello o componente interno “RicognizioneAnnualeDialog” usato esclusivamente da questo file.
class _RicognizioneAnnualeDialog extends StatefulWidget {
  const _RicognizioneAnnualeDialog({
    required this.annoAccademico,
    required this.iniziali,
  });

  final String annoAccademico;
  final PartecipazioneAnnualeProfilo iniziali;

  @override
  State<_RicognizioneAnnualeDialog> createState() =>
      _RicognizioneAnnualeDialogState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _RicognizioneAnnualeDialogState
    extends State<_RicognizioneAnnualeDialog> {
  final _form = GlobalKey<FormState>();

  late final TextEditingController _noteAttivitaMentore;
  late final TextEditingController _noteSuiMentori;
  late final TextEditingController _cambiareMenteeSeguiti;
  late final TextEditingController _segnalazioniSuggerimenti;

  String? _preferenzaPeriodo;
  bool _soloMentore = false;
  int? _valutazioneMentori;
  bool? _cambiareMentore;
  bool? _mentoringEsami;

  static const _periodi = <String>[
    'Soltanto nel primo semestre',
    'Soltanto nel secondo semestre',
    'Una volta per semestre',
    'Soltanto in uno dei due semestri, non è importante quale',
    'Indifferente',
  ];

  /// Inizializza lo stato della pagina e avvia le operazioni iniziali necessarie.
  @override
  void initState() {
    super.initState();

    final iniziali = widget.iniziali;
    _preferenzaPeriodo = iniziali.preferenzaPeriodoMentore;
    _soloMentore = iniziali.soloMentore ?? false;
    _valutazioneMentori = iniziali.valutazioneMentoriPrecedenti;
    _cambiareMentore = iniziali.cambiareMentore;
    _mentoringEsami = iniziali.disponibileMentoringEsami;

    _noteAttivitaMentore = TextEditingController(
      text: iniziali.noteAttivitaMentore ?? '',
    );
    _noteSuiMentori = TextEditingController(
      text: iniziali.noteSuiMentori ?? '',
    );
    _cambiareMenteeSeguiti = TextEditingController(
      text: iniziali.cambiareMenteeSeguiti ?? '',
    );
    _segnalazioniSuggerimenti = TextEditingController(
      text: iniziali.segnalazioniSuggerimenti ?? '',
    );
  }

  /// Rilascia listener e controller associati allo stato della pagina.
  @override
  void dispose() {
    _noteAttivitaMentore.dispose();
    _noteSuiMentori.dispose();
    _cambiareMenteeSeguiti.dispose();
    _segnalazioniSuggerimenti.dispose();
    super.dispose();
  }

  /// Costruisce l’interfaccia grafica di questo componente.
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Partecipazione ${widget.annoAccademico}'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Prima di confermare la partecipazione, indicaci le tue '
                  'preferenze per il prossimo anno accademico.',
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _preferenzaPeriodo,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText:
                        'Quando preferiresti svolgere la funzione di mentore?',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final periodo in _periodi)
                      DropdownMenuItem(value: periodo, child: Text(periodo)),
                  ],
                  onChanged: (value) => _preferenzaPeriodo = value,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteAttivitaMentore,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Note relative all’attività di mentore',
                    hintText: 'Eventuali esigenze particolari',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Per quest’anno intendo svolgere soltanto l’attività di mentore',
                  ),
                  subtitle: const Text(
                    'Se selezionato, non sarà necessario indicare un insegnamento '
                    'da mentorare.',
                  ),
                  value: _soloMentore,
                  onChanged: (value) => setState(() => _soloMentore = value),
                ),
                const Divider(height: 32),
                Text(
                  'Esperienza con i mentori',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _valutazioneMentori,
                  decoration: const InputDecoration(
                    labelText: 'Valutazione dei mentori dell’ultimo anno',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 1,
                      child: Text('1 - Per nulla soddisfatto'),
                    ),
                    DropdownMenuItem(value: 2, child: Text('2')),
                    DropdownMenuItem(value: 3, child: Text('3')),
                    DropdownMenuItem(value: 4, child: Text('4')),
                    DropdownMenuItem(
                      value: 5,
                      child: Text('5 - Molto soddisfatto'),
                    ),
                  ],
                  onChanged: (value) => _valutazioneMentori = value,
                ),
                const SizedBox(height: 12),
                _SceltaSiNo(
                  titolo:
                      'Gradiresti che almeno uno dei mentori fosse cambiato?',
                  valore: _cambiareMentore,
                  onChanged: (value) =>
                      setState(() => _cambiareMentore = value),
                ),
                if (_cambiareMentore == true) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteSuiMentori,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Note sui mentori',
                      hintText:
                          'Puoi indicare eventuali preferenze o motivazioni.',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cambiareMenteeSeguiti,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Mentee seguiti negli anni precedenti',
                    hintText:
                        'Indica per ciascun mentee se preferiresti continuare '
                        'a seguirlo o cambiare.',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const Divider(height: 32),
                _SceltaSiNo(
                  titolo:
                      'Sei disponibile a partecipare alla sperimentazione sul '
                      'mentoring per gli esami?',
                  valore: _mentoringEsami,
                  onChanged: (value) => setState(() => _mentoringEsami = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _segnalazioniSuggerimenti,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Segnalazioni e suggerimenti',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton.icon(
          onPressed: _salva,
          icon: const Icon(Icons.check),
          label: const Text('Salva e conferma'),
        ),
      ],
    );
  }

  /// Gestisce l’operazione interna “salva” della pagina.
  void _salva() {
    if (!(_form.currentState?.validate() ?? false)) return;

    Navigator.pop(context, <String, dynamic>{
      'preferenza_periodo_mentore': _preferenzaPeriodo,
      'note_attivita_mentore': _noteAttivitaMentore.text,
      'solo_mentore': _soloMentore,
      'valutazione_mentori_precedenti': _valutazioneMentori,
      'cambiare_mentore': _cambiareMentore,
      'note_sui_mentori': _noteSuiMentori.text,
      'cambiare_mentee_seguiti': _cambiareMenteeSeguiti.text,
      'disponibile_mentoring_esami': _mentoringEsami,
      'segnalazioni_suggerimenti': _segnalazioniSuggerimenti.text,
    });
  }
}

/// Modello o componente interno “SceltaSiNo” usato esclusivamente da questo file.
class _SceltaSiNo extends StatelessWidget {
  const _SceltaSiNo({
    required this.titolo,
    required this.valore,
    required this.onChanged,
  });

  final String titolo;
  final bool? valore;
  final ValueChanged<bool?> onChanged;

  /// Costruisce l’interfaccia grafica di questo componente.
  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: titolo,
        border: const OutlineInputBorder(),
      ),
      child: SegmentedButton<bool>(
        segments: const <ButtonSegment<bool>>[
          ButtonSegment<bool>(value: true, label: Text('Sì')),
          ButtonSegment<bool>(value: false, label: Text('No')),
        ],
        selected: valore == null ? <bool>{} : <bool>{valore!},
        emptySelectionAllowed: true,
        onSelectionChanged: (selezione) {
          onChanged(selezione.isEmpty ? null : selezione.first);
        },
      ),
    );
  }
}
