import 'package:flutter/material.dart';

import '../../ui/dinamico_schema.dart';
import '../../ui/dinamico_maschera.dart';
import '../../app/app_session_controller.dart';
import '../../supporto/utilita.dart';
import 'house_of_mentore_controller.dart';

/// Pagina dedicata a house of mentore.
class HouseOfMentorePage extends StatefulWidget {
  const HouseOfMentorePage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<HouseOfMentorePage> createState() => _HouseOfMentorePageState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _HouseOfMentorePageState extends State<HouseOfMentorePage> {
  /// Ordine dei campi nella visualizzazione della singola iniziativa.
  static const _ordineVisualizzazione = <String>[
    'titolo',
    'anno_accademico',
    'data_evento',
    'luogo',
    'descrizione',
    'iscrizioni_aperte',
  ];

  late final HouseOfMentoreController controller;

  bool get _partecipante => widget.sessione.ruolo == AppRole.participant;

  /// Configurazione della sola maschera di modifica House of Mentore.
  ///
  /// Il layout di visualizzazione resta interamente in questa pagina.
  ConfigurazionePaginaDinamica get _configurazioneEvento =>
      ConfigurazionePaginaDinamica(
        tabella: 'house_of_mentore',
        ordineCampi: const <String>[
          'titolo',
          'anno_accademico',
          'data_evento',
          'luogo',
          'descrizione',
          'iscrizioni_aperte',
          'attiva',
        ],
        campi: <String, PersonalizzazioneCampo>{
          'titolo': const PersonalizzazioneCampo(
            modificabilePartecipante: false,
          ),
          'descrizione': const PersonalizzazioneCampo(
            tipo: TipoCampoDinamico.testoFormattato,
            modificabilePartecipante: false,
          ),
          'anno_accademico': PersonalizzazioneCampo(
            tipo: TipoCampoDinamico.scelta,
            valoriScelta: controller.anniAccademici,
            modificabilePartecipante: false,
          ),
          for (final campo in <String>[
            'data_evento',
            'luogo',
            'locandina_url',
            'iscrizioni_aperte',
          ])
            campo: const PersonalizzazioneCampo(
              modificabilePartecipante: false,
            ),
        },
      );

  static const _configurazioneOpzione = ConfigurazionePaginaDinamica(
    tabella: 'house_of_mentore_opzioni',
    ordineCampi: <String>[
      'descrizione',
      'ordine_visualizzazione',
    ],
    campi: <String, PersonalizzazioneCampo>{
      'evento_id': PersonalizzazioneCampo(nascosto: true),
    },
  );

  /// Inizializza lo stato della pagina e avvia le operazioni iniziali necessarie.
  @override
  void initState() {
    super.initState();
    controller = HouseOfMentoreController(widget.sessione)..carica();
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
                  child: Text(
                    'House of Mentore',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Aggiorna',
                  onPressed: controller.carica,
                  icon: const Icon(Icons.refresh),
                ),
                if (controller.puoGestire)
                  FilledButton.icon(
                    onPressed: () => _apriEditorEvento(),
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
                  ? const Center(child: Text('Nessuna iniziativa disponibile.'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final elenco = _elencoEventi();
                        final selezionato = controller.eventoSelezionato;
                        final dettaglio = selezionato == null
                            ? const Center(
                                child: Text('Seleziona un’iniziativa.'),
                              )
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

  /// Costruisce localmente l'elenco delle iniziative House of Mentore.
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
          leading: const Icon(Icons.home_work_outlined),
          title: Text(
            testoDa(evento['titolo']),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${_data(evento['data_evento'])} · ${testoDa(evento['anno_accademico'])}',
          ),
          trailing: controller.iscrizione(id) == null
              ? null
              : const Icon(Icons.check_circle, color: Colors.green),
          onTap: () => controller.seleziona(evento),
        );
      },
    ),
  );


  /// Costruisce il pannello di dettaglio.
  Widget _dettaglio(Map<String, dynamic> evento) {
    final eventoId = evento['id'].toString();
    final opzioni = controller.opzioni(eventoId);
    final iscrizione = controller.iscrizione(eventoId);
    final iscrizioniAperte = evento['iscrizioni_aperte'] == true;
    final locandina = testoDa(evento['locandina_url']);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        if (locandina.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              locandina,
              height: 260,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 100,
                child: Center(child: Text('Locandina non disponibile.')),
              ),
            ),
          ),
        _campiEvento(evento),
        const Divider(height: 32),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Alternative di partecipazione',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (controller.puoGestire)
              TextButton.icon(
                onPressed: () => _apriEditorOpzione(eventoId),
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi'),
              ),
          ],
        ),
        if (opzioni.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Le alternative non sono ancora disponibili.'),
          )
        else
          for (final opzione in opzioni)
            _OpzioneTile(
              opzione: opzione,
              selezionata:
                  iscrizione?['opzione_id']?.toString() ==
                  opzione['id'].toString(),
              abilitata: iscrizioniAperte,
              puoGestire: controller.puoGestire,
              onScegli: () => _scegli(eventoId, opzione['id'].toString()),
              onModifica: () => _apriEditorOpzione(eventoId, opzione: opzione),
              onElimina: () => _eliminaOpzione(opzione),
            ),
        if (!iscrizioniAperte)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Le iscrizioni non sono aperte.'),
          ),
        if (iscrizione != null)
          TextButton.icon(
            onPressed: iscrizioniAperte
                ? () => _cancellaIscrizione(eventoId)
                : null,
            icon: const Icon(Icons.event_busy),
            label: const Text('Cancella la mia iscrizione'),
          ),
        if (controller.puoGestire) ...<Widget>[
          const Divider(height: 32),
          _elencoIscritti(evento),
          const Divider(height: 32),
          Wrap(
            spacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _apriEditorEvento(evento),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modifica evento'),
              ),
              OutlinedButton.icon(
                onPressed: () => _eliminaEvento(evento),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Elimina evento'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Costruisce o restituisce l’elenco di iscritti.
  Widget _elencoIscritti(Map<String, dynamic> evento) {
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
                DataColumn(label: Text('Opzione scelta')),
                DataColumn(label: Text('Presente')),
              ],
              rows: <DataRow>[
                for (var indice = 0; indice < iscritti.length; indice++)
                  DataRow(
                    cells: <DataCell>[
                      DataCell(Text('${indice + 1}')),
                      DataCell(
                        Text(
                          controller.nomePartecipante(
                            iscritti[indice]['partecipante_id']?.toString() ?? '',
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          controller.descrizioneOpzione(
                            eventoId,
                            iscritti[indice]['opzione_id'],
                          ),
                        ),
                      ),
                      DataCell(
                        Checkbox(
                          value: iscritti[indice]['presente'] == true,
                          onChanged: (valore) async {
                            if (valore == null) return;
                            final errore = await controller.aggiornaPresenza(
                              eventoId: eventoId,
                              partecipanteId:
                                  iscritti[indice]['partecipante_id']?.toString() ?? '',
                              presente: valore,
                            );
                            _esito(errore, 'Presenza aggiornata.');
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }


  /// Visualizza i campi dell'iniziativa con ordine autonomo della pagina.
  Widget _campiEvento(Map<String, dynamic> valori) =>
      FutureBuilder<SchemaDatabase>(
        future: controller.caricaSchemaDatabase(),
        builder: (context, snapshot) {
          final tabella = ConfigurazioneMaschere.applica(
            snapshot.data?.tabella(_configurazioneEvento.tabella) ??
                TabellaDatabase.daRiga(_configurazioneEvento.tabella, valori),
            pagina: _configurazioneEvento,
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


  /// Gestisce l’operazione interna “scegli” della pagina.
  Future<void> _scegli(String eventoId, String opzioneId) async {
    final errore = await controller.scegliOpzione(
      eventoId: eventoId,
      opzioneId: opzioneId,
    );
    _esito(errore, 'Scelta registrata.');
  }

  /// Gestisce l’operazione interna “cancella iscrizione” della pagina.
  Future<void> _cancellaIscrizione(String eventoId) async {
    final conferma = await _conferma(
      'Cancellare l’iscrizione?',
      'Potrai iscriverti nuovamente finché le iscrizioni saranno aperte.',
    );
    if (!conferma) return;
    final errore = await controller.cancellaIscrizione(eventoId);
    _esito(errore, 'Iscrizione cancellata.');
  }

  /// Apre editor evento.
  Future<void> _apriEditorEvento([Map<String, dynamic>? evento]) async {
    final dati = await mostraMascheraDinamica(
      context: context,
      configurazione: _configurazioneEvento,
      valoriIniziali:
          evento ??
          <String, dynamic>{
            'titolo': '',
            'anno_accademico': controller.anniAccademici.isEmpty
                ? null
                : controller.anniAccademici.first,
            'iscrizioni_aperte': false,
          },
      partecipante: _partecipante,
      titolo: evento == null ? 'Nuovo evento' : 'Modifica evento',
    );
    if (dati == null) return;
    final errore = await controller.salvaEvento(
      id: evento?['id']?.toString(),
      dati: dati,
    );
    _esito(errore, 'Evento salvato.');
  }

  /// Apre editor opzione.
  Future<void> _apriEditorOpzione(
    String eventoId, {
    Map<String, dynamic>? opzione,
  }) async {
    final dati = await mostraMascheraDinamica(
      context: context,
      configurazione: _configurazioneOpzione,
      valoriIniziali:
          opzione ??
          <String, dynamic>{
            'evento_id': eventoId,
            'descrizione': '',
            'ordine_visualizzazione': 0,
          },
      partecipante: false,
      titolo: opzione == null ? 'Nuova alternativa' : 'Modifica alternativa',
    );
    if (dati == null) return;
    final errore = await controller.salvaOpzione(
      id: opzione?['id']?.toString(),
      eventoId: eventoId,
      descrizione: dati['descrizione'].toString(),
      ordine: (dati['ordine_visualizzazione'] as num).toInt(),
    );
    _esito(errore, 'Alternativa salvata.');
  }

  /// Elimina evento.
  Future<void> _eliminaEvento(Map<String, dynamic> evento) async {
    final conferma = await _conferma(
      'Eliminare House of Mentore?',
      'Verranno eliminate anche le relative alternative.',
    );
    if (!conferma) return;
    final errore = await controller.eliminaEvento(evento['id'].toString());
    _esito(errore, 'Evento eliminato.');
  }

  /// Elimina opzione.
  Future<void> _eliminaOpzione(Map<String, dynamic> opzione) async {
    final conferma = await _conferma(
      'Eliminare l’alternativa?',
      testoDa(opzione['descrizione']),
    );
    if (!conferma) return;
    final errore = await controller.eliminaOpzione(opzione['id'].toString());
    _esito(errore, 'Alternativa eliminata.');
  }

  /// Gestisce l’operazione interna “conferma” della pagina.
  Future<bool> _conferma(String titolo, String testo) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(titolo),
          content: Text(testo),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Conferma'),
            ),
          ],
        ),
      ) ??
      false;

  /// Gestisce l’operazione interna “esito” della pagina.
  void _esito(String? errore, String successo) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errore ?? successo)));
  }
}

/// Modello o componente interno “OpzioneTile” usato esclusivamente da questo file.
class _OpzioneTile extends StatelessWidget {
  const _OpzioneTile({
    required this.opzione,
    required this.selezionata,
    required this.abilitata,
    required this.puoGestire,
    required this.onScegli,
    required this.onModifica,
    required this.onElimina,
  });

  final Map<String, dynamic> opzione;
  final bool selezionata;
  final bool abilitata;
  final bool puoGestire;
  final VoidCallback onScegli;
  final VoidCallback onModifica;
  final VoidCallback onElimina;

  /// Costruisce l’interfaccia grafica di questo componente.
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        selezionata ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selezionata
            ? Theme.of(context).colorScheme.primary
            : abilitata
            ? null
            : Theme.of(context).disabledColor,
      ),
      title: Text(testoDa(opzione['descrizione'])),
      onTap: abilitata ? onScegli : null,
      trailing: puoGestire
          ? PopupMenuButton<String>(
              onSelected: (valore) =>
                  valore == 'modifica' ? onModifica() : onElimina(),
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem(value: 'modifica', child: Text('Modifica')),
                PopupMenuItem(value: 'elimina', child: Text('Elimina')),
              ],
            )
          : null,
    ),
  );
}

/// Gestisce l’operazione interna “data” della pagina.
String _data(Object? valore) {
  return formattaData(valore);
}
