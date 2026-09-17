import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../ui/dinamico_schema.dart';
import '../../../ui/dinamico_maschera.dart';
import '../../../app/app_core.dart';
import '../../../app/app_session_controller.dart';
import 'mentee_controller.dart';

/// Pagina dedicata a mentee.
class MenteePage extends StatefulWidget {
  const MenteePage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<MenteePage> createState() => _MenteePageState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _MenteePageState extends State<MenteePage> {
  static const _campiMentee = <String>{
    'data_inizio',
    'data_fine',
    'numero_studenti',
    'sede',
    'note',
    'svolgimento',
    'giorni_orari_lezioni',
  };

  /// Ordine dei campi nella sola visualizzazione della pagina Mentee.
  ///
  /// È volutamente locale alla pagina: modificare questa lista non cambia né
  /// la pagina Mentore né l'ordine dei campi nella maschera di modifica.
  static const _ordineVisualizzazione = <String>[
    'data_inizio',
    'data_fine',
    'numero_studenti',
    'sede',
    'svolgimento',
    'giorni_orari_lezioni',
    'note',
  ];

  static const configurazione = ConfigurazionePaginaDinamica(
    tabella: 'mentoraggi',
    ordineCampi: <String>[
      'data_inizio',
      'data_fine',
      'numero_studenti',
      'sede',
      'svolgimento',
      'giorni_orari_lezioni',
      'note',
    ],
    prefissiNascostiPartecipante: <String>['osservazioni'],
    campiModificabiliPartecipante: _campiMentee,
    campi: <String, PersonalizzazioneCampo>{
      'insegnamento_id': PersonalizzazioneCampo(nascosto: true),
      'anno_accademico': PersonalizzazioneCampo(
        modificabilePartecipante: false,
      ),
      'scheda_sintesi_pdf_url': PersonalizzazioneCampo(nascosto: true),
    },
  );

  late final MenteeController controller;

  /// Inizializza lo stato della pagina e avvia le operazioni iniziali necessarie.
  @override
  void initState() {
    super.initState();
    controller = MenteeController()..carica();
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
                  ? const Center(
                      child: Text(
                        'Nessun mentoraggio disponibile nel ruolo mentee.',
                      ),
                    )
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
                              SizedBox(width: 350, child: elenco),
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

  /// Costruisce localmente l'elenco dei mentoraggi disponibili al mentee.
  Widget _elencoMentoraggi() => Card(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: ListView.separated(
      itemCount: controller.percorsi.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final percorso = controller.percorsi[index];
        final id = percorso.mentoraggio['id']?.toString() ?? '';
        return ListTile(
          selected: id == controller.selezionato?.mentoraggio['id']?.toString(),
          title: Text(
            percorso.insegnamento['insegnamento']?.toString() ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${percorso.mentoraggio['anno_accademico'] ?? ''}'
            '${percorso.annoCorrente ? ' · corrente' : ' · storico'}',
          ),
          onTap: () => controller.seleziona(percorso),
        );
      },
    ),
  );

  /// Costruisce il dettaglio del mentoraggio selezionato.
  ///
  /// Tutta la composizione grafica è contenuta in questo file; lo schema DB è
  /// usato soltanto per etichette e tipi dei valori.
  Widget _dettaglio() {
    final percorso = controller.selezionato;
    if (percorso == null) {
      return const Center(child: Text('Seleziona un mentoraggio.'));
    }

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
        LayoutBuilder(
          builder: (context, constraints) {
            final titolo = Text(
              'Ruolo mentee · ${percorso.mentoraggio['anno_accademico'] ?? ''}',
              style: Theme.of(context).textTheme.headlineSmall,
            );
            if (!percorso.annoCorrente) {
              return titolo;
            }
            final pulsante = FilledButton.icon(
              onPressed: controller.salvataggio ? null : _modifica,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifica dati annuali'),
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
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Insegnamento'),
          subtitle: Text(
            percorso.insegnamento['insegnamento']?.toString() ?? '',
          ),
        ),
        if (!percorso.annoCorrente)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.lock_outline),
            title: Text('Mentoraggio storico'),
            subtitle: Text(
              'I dati degli anni accademici precedenti sono in sola lettura.',
            ),
          ),
        const Divider(),
        Text(
          'Team di mentoraggio',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ...percorso.mentori.map(
          (mentore) => ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(
              '${mentore['nome'] ?? ''} ${mentore['cognome'] ?? ''}'.trim(),
            ),
            subtitle: Text(
              '${mentore['tipo'] ?? ''} · ${mentore['email_unipa'] ?? ''}',
            ),
          ),
        ),
        const Divider(),
        _campiMentoraggio(percorso.mentoraggio),
        ..._linkPdf(percorso.mentoraggio),
        ],
      ),
    );
  }

  /// Visualizza i campi del mentoraggio nell'ordine specifico di questa pagina.
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

  /// Converte un valore del database nel widget di sola visualizzazione.
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

  /// Gestisce l’operazione interna “link pdf” della pagina.
  List<Widget> _linkPdf(Map<String, dynamic> mentoraggio) {
    final valore =
        mentoraggio['scheda_sintesi_pdf_url']?.toString().trim() ?? '';

    if (valore.isEmpty) {
      return const <Widget>[];
    }

    final nomeFile = valore.split('/').last;

    return <Widget>[
      Card(
        margin: const EdgeInsets.only(top: 12),
        child: ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Scheda di sintesi'),
          subtitle: Text(nomeFile.isEmpty ? 'Documento disponibile' : nomeFile),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => _apriPdf(valore),
        ),
      ),
    ];
  }

  /// Apre pdf.
  Future<void> _apriPdf(String valore) async {
    try {
      final url = await controller.urlSchedaSintesi(valore);
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('URL non apribile');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile aprire la scheda di sintesi.'),
        ),
      );
    }
  }

  /// Gestisce l’operazione interna “modifica” della pagina.
  Future<void> _modifica() async {
    final percorso = controller.selezionato;
    if (percorso == null || !percorso.annoCorrente) return;
    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: configurazione,
      valoriIniziali: percorso.mentoraggio,
      partecipante: true,
      titolo:
          'Dati ${percorso.insegnamento['insegnamento'] ?? ''} · ${percorso.mentoraggio['anno_accademico'] ?? ''}',
    );
    if (valori == null) return;
    try {
      await controller.salva(valori);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.messaggio)));
    }
  }
}
