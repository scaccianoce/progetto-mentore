import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../ui/dinamico_schema.dart';
import '../../ui/dinamico_maschera.dart';
import '../../app/app_session_controller.dart';
import '../../ui/questionario_interno_dialog.dart';
import '../../supporto/utilita.dart';
import 'eventi_controller.dart';

/// Pagina dedicata a eventi.
class EventiPage extends StatefulWidget {
  const EventiPage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<EventiPage> createState() => _EventiPageState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _EventiPageState extends State<EventiPage> {
  /// Ordine dei campi nella visualizzazione del dettaglio Evento.
  static const _ordineVisualizzazione = <String>[
    'titolo',
    'anno_accademico',
    'data_evento',
    'tipologia',
    'modalita',
    'luogo',
    'descrizione',
    'relatori',
    'moderatori',
    'data_apertura_iscrizioni',
    'data_chiusura_iscrizioni',
    'note_organizzative',
    'attiva',
  ];

  late final EventiController controller;

  bool get _partecipante => widget.sessione.ruolo == AppRole.participant;

  ConfigurazionePaginaDinamica
  get _configurazione => ConfigurazionePaginaDinamica(
    tabella: 'eventi',
    ordineCampi: const <String>[
      'titolo',
      'anno_accademico',
      'data_evento',
      'tipologia',
      'modalita',
      'luogo',
      'descrizione',
      'relatori',
      'moderatori',
      'data_apertura_iscrizioni',
      'data_chiusura_iscrizioni',
      'note_organizzative',
      'attiva',
    ],
    campi: <String, PersonalizzazioneCampo>{
      'titolo': const PersonalizzazioneCampo(modificabilePartecipante: false),
      'anno_accademico': PersonalizzazioneCampo(
        tipo: TipoCampoDinamico.scelta,
        valoriScelta: controller.anniAccademici,
        nascosto: false,
        modificabilePartecipante: false,
      ),
      'data_evento': const PersonalizzazioneCampo(
        modificabilePartecipante: false,
      ),
      'tipologia': const PersonalizzazioneCampo(
        modificabilePartecipante: false,
      ),
      'modalita': const PersonalizzazioneCampo(modificabilePartecipante: false),
      'descrizione': const PersonalizzazioneCampo(
        tipo: TipoCampoDinamico.testoFormattato,
        modificabilePartecipante: false,
      ),
      'relatori': const PersonalizzazioneCampo(modificabilePartecipante: false),
      'moderatori': const PersonalizzazioneCampo(
        modificabilePartecipante: false,
      ),
      'note_organizzative': const PersonalizzazioneCampo(
        modificabilePartecipante: false,
      ),
      for (final campo in <String>[
        'luogo',
        'data_apertura_iscrizioni',
        'data_chiusura_iscrizioni',
      ])
        campo: const PersonalizzazioneCampo(modificabilePartecipante: false),
      'locandina_url': const PersonalizzazioneCampo(
        nascosto: true,
        modificabilePartecipante: false,
      ),
      'attiva': PersonalizzazioneCampo(
        nascosto: _partecipante,
        modificabilePartecipante: false,
      ),
    },
  );

  /// Inizializza lo stato della pagina e avvia le operazioni iniziali necessarie.
  @override
  void initState() {
    super.initState();

    controller = EventiController(widget.sessione)..carica();
  }

  /// Rilascia listener e controller associati allo stato della pagina.
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Costruisce l’interfaccia grafica di questo componente.
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (controller.caricamento && controller.eventi.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('Eventi', style: Theme.of(context).textTheme.headlineSmall),
                ),
                IconButton(
                  tooltip: 'Aggiorna',
                  onPressed: controller.carica,
                  icon: const Icon(Icons.refresh),
                ),
                if (controller.puoGestire)
                  FilledButton.icon(
                    onPressed: () => _apriEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nuovo'),
                  ),
              ],
            ),
            if (controller.errore != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                controller.errore!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: controller.eventi.isEmpty
                  ? const Center(child: Text('Nessun evento disponibile.'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final elenco = _elencoEventi();
                        final selezionato = controller.eventoSelezionato;
                        final dettaglio = selezionato == null
                            ? const Center(child: Text('Seleziona un evento.'))
                            : Card(
                                margin: EdgeInsets.zero,
                                child: _dettaglio(selezionato),
                              );
                        if (constraints.maxWidth >= 800) {
                          return Row(
                            children: <Widget>[
                              SizedBox(width: 340, child: elenco),
                              const VerticalDivider(width: 24),
                              Expanded(child: dettaglio),
                            ],
                          );
                        }
                        return Column(
                          children: <Widget>[
                            Expanded(child: elenco),
                            const Divider(height: 20),
                            Expanded(child: dettaglio),
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

  /// Costruisce localmente l'elenco eventi.
  Widget _elencoEventi() => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: ListView.separated(
      itemCount: controller.eventi.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final evento = controller.eventi[index];
        final id = evento['id'].toString();
        return ListTile(
          selected: id == controller.eventoSelezionatoId,
          title: Text(
            evento['titolo']?.toString() ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(_data(evento['data_evento'])),
          trailing: controller.iscritto(id)
              ? const Icon(Icons.check_circle, color: Colors.green)
              : null,
          onTap: () => controller.seleziona(evento),
        );
      },
    ),
  );


  /// Costruisce il pannello di dettaglio.
  Widget _dettaglio(Map<String, dynamic> evento) {
    final id = evento['id'].toString();
    final iscritto = controller.iscritto(id);
    final aperte = controller.iscrizioniAperte(evento);
    final presente = controller.presente(id);
    final haQuestionario = controller.haQuestionario(id);
    final compilato = controller.questionarioCompilato(id);

    final locandina = testoDa(evento['locandina_url']);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        if (locandina.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              locandina,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Impossibile caricare la locandina.'),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        _campiEvento(evento),

        const SizedBox(height: 16),

        FilledButton.icon(
          onPressed: aperte ? () => _cambiaIscrizione(evento) : null,
          icon: Icon(iscritto ? Icons.event_busy : Icons.event_available),
          label: Text(iscritto ? 'Annulla iscrizione' : 'Iscriviti'),
        ),

        if (!aperte)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Le iscrizioni non sono aperte.'),
          ),

        if (iscritto && haQuestionario) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Questionario di gradimento',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),

                  if (compilato)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.check_circle_outline),
                      title: Text('Questionario compilato'),
                    )
                  else if (!presente)
                    const Text(
                      'Il questionario sarà disponibile '
                      'dopo che la presenza sarà stata '
                      'registrata dall’organizzazione.',
                    )
                  else
                    FilledButton.tonalIcon(
                      onPressed: () => _apriQuestionario(id),
                      icon: const Icon(Icons.quiz_outlined),
                      label: const Text('Compila questionario'),
                    ),
                ],
              ),
            ),
          ),
        ],

        if (controller.puoGestire) ...[
          const Divider(height: 32),
          _elencoIscrittiEvento(evento),
          const Divider(height: 32),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _apriEditor(evento),
                icon: const Icon(Icons.edit),
                label: const Text('Modifica'),
              ),
              OutlinedButton.icon(
                onPressed: () => _elimina(evento),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Elimina'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Costruisce o restituisce l’elenco di iscritti evento.
  Widget _elencoIscrittiEvento(Map<String, dynamic> evento) {
    final eventoId = evento['id'].toString();
    final iscritti = controller.iscritti(eventoId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Iscritti (${iscritti.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),

        if (iscritti.isEmpty)
          const Text('Nessun partecipante iscritto.')
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('#'), numeric: true),
                DataColumn(label: Text('Partecipante')),
                DataColumn(label: Text('Presente')),
                DataColumn(label: Text('Questionario compilato')),
                DataColumn(label: Text('Data compilazione')),
              ],
              rows: <DataRow>[
                for (var indice = 0; indice < iscritti.length; indice++)
                  _rigaIscrittoEvento(
                    eventoId: eventoId,
                    indice: indice,
                    partecipazione: iscritti[indice],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// Costruisce la riga relativa a iscritto evento.
  DataRow _rigaIscrittoEvento({
    required String eventoId,
    required int indice,
    required Map<String, dynamic> partecipazione,
  }) {
    final partecipanteId = partecipazione['partecipante_id']?.toString() ?? '';

    final presente = partecipazione['presente'] == true;

    final questionario = controller.questionarioCompilato(
      eventoId,
      partecipanteId: partecipanteId,
    );

    final dataCompilazione = controller.dataCompilazione(
      eventoId,
      partecipanteId,
    );

    return DataRow(
      cells: <DataCell>[
        DataCell(Text('${indice + 1}')),
        DataCell(Text(controller.nomePartecipante(partecipanteId))),
        DataCell(
          Checkbox(
            value: presente,
            onChanged: (valore) async {
              if (valore == null) return;

              final errore = await controller.aggiornaPresenza(
                eventoId: eventoId,
                partecipanteId: partecipanteId,
                presente: valore,
              );

              if (!mounted || errore == null) {
                return;
              }

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(errore)));
            },
          ),
        ),
        DataCell(
          Icon(questionario ? Icons.check_circle : Icons.remove_circle_outline),
        ),
        DataCell(
          Text(dataCompilazione == null ? '—' : _data(dataCompilazione)),
        ),
      ],
    );
  }

  /// Apre questionario.
  Future<void> _apriQuestionario(String eventoId) async {
    final compilato = await showDialog<bool>(
      context: context,
      builder: (context) => QuestionarioInternoDialog(
        eventoId: eventoId,
        caricaQuestionario: controller.caricaQuestionarioEvento,
        inviaQuestionario: controller.inviaQuestionario,
      ),
    );

    if (compilato == true) {
      await controller.carica();
    }
  }


  /// Visualizza i campi dell'evento nell'ordine definito da questa pagina.
  Widget _campiEvento(Map<String, dynamic> valori) =>
      FutureBuilder<SchemaDatabase>(
        future: controller.caricaSchemaDatabase(),
        builder: (context, snapshot) {
          final tabella = ConfigurazioneMaschere.applica(
            snapshot.data?.tabella(_configurazione.tabella) ??
                TabellaDatabase.daRiga(_configurazione.tabella, valori),
            pagina: _configurazione,
          );
          final campi = tabella.campi
              .where(
                (campo) => campo.visibilePer(partecipante: _partecipante) &&
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
              for (final campo in campi)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    campo.etichetta,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: campo.tipo == TipoCampoDinamico.testoFormattato
                      ? TestoHtmlMinimo(
                          testo: valori[campo.nome]?.toString() ?? '',
                        )
                      : SelectableText(
                          (valori[campo.nome]?.toString().trim().isEmpty ?? true)
                              ? '—'
                              : valori[campo.nome].toString(),
                        ),
                ),
            ],
          );
        },
      );


  /// Gestisce l’operazione interna “cambia iscrizione” della pagina.
  Future<void> _cambiaIscrizione(Map<String, dynamic> evento) async {
    final errore = await controller.cambiaIscrizione(evento);

    if (mounted && errore != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errore)));
    }
  }

  /// Apre editor.
  Future<void> _apriEditor([Map<String, dynamic>? evento]) async {
    if (controller.anniAccademici.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun anno accademico disponibile.')),
      );
      return;
    }

    // I template e i questionari privati sono gia' caricati dal controller.
    final templatePartecipanti = controller.templatePer('partecipanti');

    final questionarioEsistente = evento == null
        ? null
        : controller.questionarioEvento(evento['id'].toString());

    final configurazioneIniziale = await _scegliConfigurazioneEvento(
      annoIniziale:
          evento?['anno_accademico']?.toString() ??
          controller.anniAccademici.first,
      templateIniziale: questionarioEsistente?['template_id']?.toString(),
      templateDisponibili: templatePartecipanti,
      locandinaUrlIniziale: evento?['locandina_url']?.toString(),
    );

    if (configurazioneIniziale == null) {
      return;
    }

    final annoSelezionato = configurazioneIniziale.annoAccademico;

    final templateSelezionato = configurazioneIniziale.templateQuestionarioId;

    final locandinaBytes = configurazioneIniziale.locandinaBytes;
    final locandinaNomeFile = configurazioneIniziale.locandinaNomeFile;
    final rimuoviLocandina = configurazioneIniziale.rimuoviLocandina;

    final iniziali =
        evento == null
              ? <String, dynamic>{
                  'titolo': '',
                  'anno_accademico': annoSelezionato,
                  'attiva': true,
                }
              : Map<String, dynamic>.from(evento)
          ..['anno_accademico'] = annoSelezionato;

    if (!mounted) return;

    final risultato = await mostraMascheraDinamica(
      context: context,
      configurazione: _configurazione,
      valoriIniziali: iniziali,
      partecipante: _partecipante,
      titolo: evento == null ? 'Nuovo evento' : 'Modifica evento',
    );

    if (risultato == null) return;

    risultato['anno_accademico'] = annoSelezionato;

    final errore = await controller.salva(
      id: evento?['id']?.toString(),
      dati: risultato,
      aggiornaQuestionario: true,
      templateQuestionarioId: templateSelezionato,
      locandinaBytes: locandinaBytes,
      locandinaNomeFile: locandinaNomeFile,
      rimuoviLocandina: rimuoviLocandina,
    );

    if (!mounted) return;

    if (errore != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errore)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(evento == null ? 'Evento creato.' : 'Evento aggiornato.'),
      ),
    );
  }

  /// Gestisce la selezione di configurazione evento.
  Future<_ConfigurazioneEvento?> _scegliConfigurazioneEvento({
    required String annoIniziale,
    required String? templateIniziale,
    required List<Map<String, dynamic>> templateDisponibili,
    required String? locandinaUrlIniziale,
  }) async {
    var anno = annoIniziale;
    String template = templateIniziale ?? '';

    Uint8List? locandinaBytes;
    String? locandinaNomeFile;
    var rimuoviLocandina = false;
    String? erroreLocandina;

    return showDialog<_ConfigurazioneEvento>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Configurazione evento'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: anno,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Anno accademico',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final valore in controller.anniAccademici)
                        DropdownMenuItem(value: valore, child: Text(valore)),
                    ],
                    onChanged: (valore) {
                      if (valore != null) {
                        setDialogState(() => anno = valore);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: template,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Questionario di gradimento',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Nessun questionario'),
                      ),
                      for (final modello in templateDisponibili)
                        DropdownMenuItem(
                          value: modello['id'].toString(),
                          child: Text(
                            modello['titolo']?.toString() ?? 'Template',
                          ),
                        ),
                    ],
                    onChanged: (valore) {
                      setDialogState(() => template = valore ?? '');
                    },
                  ),
                  if (templateDisponibili.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Nessun template per partecipanti attivo. '
                        'Puoi creare l’evento senza questionario '
                        'e associarlo successivamente.',
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'Locandina',
                    style: Theme.of(dialogContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(
                      minHeight: 140,
                      maxHeight: 260,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(
                          dialogContext,
                        ).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: locandinaBytes != null
                        ? Image.memory(locandinaBytes!, fit: BoxFit.contain)
                        : (!rimuoviLocandina &&
                              testoDa(locandinaUrlIniziale).isNotEmpty)
                        ? Image.network(
                            locandinaUrlIniziale!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Anteprima non disponibile. '
                                'Puoi sostituire la locandina.',
                              ),
                            ),
                          )
                        : const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Nessuna locandina'),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    locandinaNomeFile ??
                        (rimuoviLocandina
                            ? 'La locandina attuale verrà eliminata.'
                            : 'JPG, JPEG o PNG · massimo 300 KB'),
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  if (erroreLocandina != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        erroreLocandina!,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final file = await FilePicker.pickFile(
                            type: FileType.custom,
                            allowedExtensions: const ['jpg', 'jpeg', 'png'],
                          );

                          if (file == null || !dialogContext.mounted) {
                            return;
                          }

                          final bytes = await file.readAsBytes();

                          if (!dialogContext.mounted) {
                            return;
                          }

                          if (bytes.lengthInBytes >
                              EventiController.dimensioneMassimaLocandina) {
                            setDialogState(() {
                              erroreLocandina =
                                  'Il file supera il limite massimo di 300 KB.';
                            });
                            return;
                          }

                          setDialogState(() {
                            locandinaBytes = bytes;
                            locandinaNomeFile = file.name;
                            rimuoviLocandina = false;
                            erroreLocandina = null;
                          });
                        },
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(
                          locandinaUrlIniziale == null && locandinaBytes == null
                              ? 'Carica immagine'
                              : 'Sostituisci',
                        ),
                      ),
                      if (testoDa(locandinaUrlIniziale).isNotEmpty ||
                          locandinaBytes != null)
                        OutlinedButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              locandinaBytes = null;
                              locandinaNomeFile = null;
                              rimuoviLocandina = true;
                              erroreLocandina = null;
                            });
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Elimina locandina'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _ConfigurazioneEvento(
                  annoAccademico: anno,
                  templateQuestionarioId: template.isEmpty ? null : template,
                  locandinaBytes: locandinaBytes,
                  locandinaNomeFile: locandinaNomeFile,
                  rimuoviLocandina: rimuoviLocandina,
                ),
              ),
              child: const Text('Continua'),
            ),
          ],
        ),
      ),
    );
  }

  /// Gestisce l’operazione interna “elimina” della pagina.
  Future<void> _elimina(Map<String, dynamic> evento) async {
    final dataEvento = DateTime.tryParse(
      evento['data_evento']?.toString() ?? '',
    );

    final oggi = DateTime.now();
    final oggiSoloData = DateTime(oggi.year, oggi.month, oggi.day);

    final eventoPassato =
        dataEvento != null && dataEvento.isBefore(oggiSoloData);

    final conferma =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminare l’evento?'),
            content: Text(
              eventoPassato
                  ? 'Questo evento risulta già trascorso.\n\n'
                        'La cancellazione rimuoverà anche le iscrizioni '
                        'associate.\n\n'
                        'Vuoi continuare?'
                  : 'La cancellazione rimuoverà anche le iscrizioni '
                        'associate.\n\n'
                        'Vuoi continuare?',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continua'),
              ),
            ],
          ),
        ) ??
        false;

    if (!conferma) return;

    if (!mounted) return;

    // Seconda conferma soltanto per eventi già trascorsi.
    if (eventoPassato) {
      final confermaFinale =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Conferma definitiva'),
              content: Text(
                'Stai per eliminare definitivamente '
                'l’evento:\n\n'
                '"${evento['titolo'] ?? ''}"\n\n'
                'L’operazione non può essere annullata.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annulla'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Elimina definitivamente'),
                ),
              ],
            ),
          ) ??
          false;

      if (!confermaFinale) return;
    }

    final errore = await controller.elimina(evento['id'].toString());

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errore ?? 'Evento eliminato.')));
  }
}

/// Modello o componente interno “ConfigurazioneEvento” usato esclusivamente da questo file.
class _ConfigurazioneEvento {
  const _ConfigurazioneEvento({
    required this.annoAccademico,
    required this.templateQuestionarioId,
    required this.locandinaBytes,
    required this.locandinaNomeFile,
    required this.rimuoviLocandina,
  });

  final String annoAccademico;
  final String? templateQuestionarioId;
  final Uint8List? locandinaBytes;
  final String? locandinaNomeFile;
  final bool rimuoviLocandina;
}

/// Gestisce l’operazione interna “data” della pagina.
String _data(Object? valore) {
  return formattaData(
    valore,
    valoreAssente: '',
    mantieniValoreNonValido: true,
  );
}
