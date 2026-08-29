import 'package:flutter/material.dart';

import '../../ui/dinamico_schema.dart';
import '../../app/app_session_controller.dart';
import 'contatti_controller.dart';

/// Pagina dedicata a contatti.
class ContattiPage extends StatefulWidget {
  const ContattiPage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<ContattiPage> createState() => _ContattiPageState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _ContattiPageState extends State<ContattiPage> {
  /// Ordine dei campi nella visualizzazione del singolo contatto.
  static const _ordineVisualizzazione = <String>[
    'email_unipa',
    'cellulare',
    'cod_ssd',
    'dipartimento',
    'ufficio',
    'ruolo_accademico',
    'pagina_personale_unipa',
  ];

  /// Configurazione della sola visualizzazione dei dati di contatto.
  ///
  /// La pagina e' di sola consultazione: vengono dichiarati soltanto i campi
  /// nascosti e le etichette che non possono essere dedotte dallo schema.
  static const configurazione = ConfigurazionePaginaDinamica(
    tabella: 'anagrafica',
    campi: <String, PersonalizzazioneCampo>{
      'user_id': PersonalizzazioneCampo(nascosto: true),
      'nome': PersonalizzazioneCampo(nascosto: true),
      'cognome': PersonalizzazioneCampo(nascosto: true),
      'email_unipa': PersonalizzazioneCampo(etichetta: 'Email'),
      'cod_ssd': PersonalizzazioneCampo(etichetta: 'SSD'),
      'pagina_personale_unipa': PersonalizzazioneCampo(
        etichetta: 'Pagina personale',
      ),
    },
  );

  late final ContattiController _controller;

  bool get _partecipante => widget.sessione.ruolo == AppRole.participant;

  /// Inizializza lo stato della pagina e avvia le operazioni iniziali necessarie.
  @override
  void initState() {
    super.initState();
    _controller = ContattiController()..carica();
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
      final selezionato = _controller.selezionato;
      if (_controller.caricamento && _controller.contatti.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              onChanged: _controller.cerca,
              decoration: const InputDecoration(
                labelText: 'Cerca per nome, email o SSD',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_controller.errore != null) ...<Widget>[
              Text(
                _controller.errore!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: _controller.contatti.isEmpty
                  ? const Center(child: Text('Nessun contatto disponibile.'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final elenco = _elencoContatti();
                        final dettaglio = Card(
                          margin: EdgeInsets.zero,
                          child: selezionato == null
                              ? const Center(child: Text('Seleziona un contatto.'))
                              : _dettaglioContatto(selezionato),
                        );
                        if (constraints.maxWidth >= 800) {
                          return Row(
                            children: <Widget>[
                              SizedBox(width: 360, child: elenco),
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

  /// Costruisce localmente l'elenco dei contatti filtrati.
  Widget _elencoContatti() => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: ListView.separated(
      itemCount: _controller.contatti.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final contatto = _controller.contatti[index];
        return ListTile(
          selected: contatto['user_id']?.toString() ==
              _controller.selezionato?['user_id']?.toString(),
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(
            '${contatto['cognome'] ?? ''} ${contatto['nome'] ?? ''}'.trim(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(contatto['email_unipa']?.toString() ?? ''),
          onTap: () => _controller.seleziona(contatto),
        );
      },
    ),
  );

  /// Costruisce il dettaglio del contatto con ordine autonomo della pagina.
  Widget _dettaglioContatto(Map<String, dynamic> valori) => ListView(
    padding: const EdgeInsets.all(24),
    children: <Widget>[
      Text(
        '${valori['nome'] ?? ''} ${valori['cognome'] ?? ''}'.trim(),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const Divider(height: 28),
      FutureBuilder<SchemaDatabase>(
        future: _controller.caricaSchemaDatabase(),
        builder: (context, snapshot) {
          final tabella = ConfigurazioneMaschere.applica(
            snapshot.data?.tabella(configurazione.tabella) ??
                TabellaDatabase.daRiga(configurazione.tabella, valori),
            pagina: configurazione,
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
            children: <Widget>[
              for (final campo in campi)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    campo.etichetta,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: SelectableText(
                    (valori[campo.nome]?.toString().trim().isEmpty ?? true)
                        ? '—'
                        : valori[campo.nome].toString(),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
