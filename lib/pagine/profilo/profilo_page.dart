import 'package:flutter/material.dart';

import '../../app_exception.dart';
import '../../dinamico/maschera_dinamica_controller.dart';
import '../../dinamico/maschera_dinamica_widget.dart';
import '../../sessione_controller.dart';
import '../template/pagina_scheda_dinamica.dart';
import 'profilo_controller.dart';

class ProfiloPage extends StatefulWidget {
  const ProfiloPage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<ProfiloPage> createState() => _ProfiloPageState();
}

class _ProfiloPageState extends State<ProfiloPage> {
  late final ProfiloController _controller;

  bool get _partecipante => widget.sessione.ruolo == AppRole.participant;

  ConfigurazionePaginaDinamica get _configurazione =>
      ConfigurazionePaginaDinamica(
        tabella: 'anagrafica',
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

  @override
  void initState() {
    super.initState();
    _controller = ProfiloController(sessione: widget.sessione)..carica();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final profilo = _controller.profilo;
      final cardPartecipazione = _cardPartecipazione(context);

      return PaginaSchedaDinamica(
        titolo: 'Il mio profilo',
        configurazione: _configurazione,
        valori: profilo,
        partecipante: _partecipante,
        caricamento: _controller.caricamento && profilo == null,
        errore: _controller.errore,
        vuoto: profilo == null,
        messaggioVuoto: 'Profilo non trovato.',
        primaDeiCampi: cardPartecipazione == null
            ? const <Widget>[]
            : <Widget>[cardPartecipazione, const SizedBox(height: 20)],
        azioni: <Widget>[
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
      );
    },
  );

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

    final testo = switch (stato.stato) {
      'confermato' => stato.soloMentore == true
          ? 'Partecipazione confermata come solo mentore. Per questo anno '
                'accademico non è necessario indicare un insegnamento da '
                'mentorare.'
          : 'Partecipazione confermata. Quando il backoffice abiliterà la fase '
                'insegnamenti, potrai confermare o inserire l’insegnamento da '
                '“I miei insegnamenti”.',
      'nuovo' => 'Partecipazione registrata come nuovo partecipante.',
      'rinuncia' =>
        'Hai indicato che non parteciperai nell’anno accademico $anno. '
            'Il tuo account e lo storico restano comunque disponibili.',
      'sospeso' => 'Partecipazione temporaneamente sospesa dal backoffice.',
      _ => 'Stato partecipazione: ${stato.stato ?? '—'}',
    };

    return Card(
      child: ListTile(
        leading: Icon(
          stato.confermata || stato.nuovo
              ? Icons.check_circle_outline
              : stato.rinuncia
              ? Icons.event_busy_outlined
              : Icons.info_outline,
        ),
        title: Text('Partecipazione $anno'),
        subtitle: Text(testo),
      ),
    );
  }

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

  @override
  void dispose() {
    _noteAttivitaMentore.dispose();
    _noteSuiMentori.dispose();
    _cambiareMenteeSeguiti.dispose();
    _segnalazioniSuggerimenti.dispose();
    super.dispose();
  }

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
                    labelText: 'Quando preferiresti svolgere la funzione di mentore?',
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

  void _salva() {
    if (!(_form.currentState?.validate() ?? false)) return;

    Navigator.pop(
      context,
      <String, dynamic>{
        'preferenza_periodo_mentore': _preferenzaPeriodo,
        'note_attivita_mentore': _noteAttivitaMentore.text,
        'solo_mentore': _soloMentore,
        'valutazione_mentori_precedenti': _valutazioneMentori,
        'cambiare_mentore': _cambiareMentore,
        'note_sui_mentori': _noteSuiMentori.text,
        'cambiare_mentee_seguiti': _cambiareMenteeSeguiti.text,
        'disponibile_mentoring_esami': _mentoringEsami,
        'segnalazioni_suggerimenti': _segnalazioniSuggerimenti.text,
      },
    );
  }
}

class _SceltaSiNo extends StatelessWidget {
  const _SceltaSiNo({
    required this.titolo,
    required this.valore,
    required this.onChanged,
  });

  final String titolo;
  final bool? valore;
  final ValueChanged<bool?> onChanged;

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
