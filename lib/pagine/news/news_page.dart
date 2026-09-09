import 'package:flutter/material.dart';

import '../../app/app_core.dart';
import '../../app/app_session_controller.dart';
import '../../supporto/notifiche_automatiche_service.dart';
import '../../supporto/utilita.dart';
import '../../ui/dinamico_maschera.dart';
import '../../ui/dinamico_schema.dart';
import 'news_controller.dart';

/// Pagina di consultazione e gestione delle news.
///
/// La pagina possiede interamente la composizione grafica e l'ordine della
/// visualizzazione. Il controller gestisce invece stato e operazioni sui dati.
class NewsPage extends StatefulWidget {
  const NewsPage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  /// Ordine dei campi nel dettaglio di sola visualizzazione.
  ///
  /// Questa configurazione riguarda soltanto la pagina News e non influenza
  /// l'ordine della maschera di modifica.
  static const _ordineVisualizzazione = <String>[
    'testo',
    'data_pubblicazione',
    'attiva',
  ];

  late final NewsController controller;

  bool get _partecipante => widget.sessione.ruolo == AppRole.participant;
  bool get _puoGestire => widget.sessione.ruolo?.puoAmministrare ?? false;

  /// Configurazione della sola maschera di modifica.
  ConfigurazionePaginaDinamica get configurazioneModifica =>
      ConfigurazionePaginaDinamica(
        tabella: 'news',
        ordineCampi: const <String>[
          'titolo',
          'testo',
          'data_pubblicazione',
          'attiva',
        ],
        campi: <String, PersonalizzazioneCampo>{
          'testo': const PersonalizzazioneCampo(
            tipo: TipoCampoDinamico.testoFormattato,
            modificabilePartecipante: false,
          ),
          'titolo': const PersonalizzazioneCampo(
            modificabilePartecipante: false,
          ),
          'data_pubblicazione': const PersonalizzazioneCampo(
            modificabilePartecipante: false,
          ),
          'attiva': PersonalizzazioneCampo(
            nascosto: _partecipante,
            modificabilePartecipante: false,
          ),
        },
      );

  @override
  void initState() {
    super.initState();
    controller = NewsController(
      partecipante: _partecipante,
      puoGestire: _puoGestire,
    )..carica();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.caricamento && controller.news.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _intestazione(),
                if (controller.errore != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    controller.errore!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(child: _contenuto()),
              ],
            ),
          );
        },
      );

  /// Costruisce l'intestazione e le azioni principali della pagina.
  Widget _intestazione() => Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'News',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: controller.caricamento ? null : controller.carica,
            icon: const Icon(Icons.refresh),
          ),
          if (_puoGestire)
            FilledButton.icon(
              onPressed: controller.salvataggio ? null : () => _apriEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Nuova'),
            ),
        ],
      );

  /// Costruisce il layout elenco/dettaglio responsive della pagina News.
  Widget _contenuto() {
    if (controller.news.isEmpty) {
      return const Center(child: Text('Nessuna news disponibile.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final elenco = _elencoNews();
        final dettaglio = Card(
          margin: EdgeInsets.zero,
          child: _dettaglio(),
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
            SizedBox(height: 220, child: elenco),
            const Divider(height: 20),
            Expanded(child: dettaglio),
          ],
        );
      },
    );
  }

  /// Costruisce localmente l'elenco delle news.
  Widget _elencoNews() => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListView.separated(
          itemCount: controller.news.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final news = controller.news[index];
            return ListTile(
              selected: news['id']?.toString() ==
                  controller.selezionata?['id']?.toString(),
              title: Text(
                news['titolo']?.toString() ?? '-',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                formattaData(
                  news['data_pubblicazione'],
                  valoreAssente: 'Data non indicata',
                ),
              ),
              onTap: () => controller.seleziona(news),
            );
          },
        ),
      );

  /// Costruisce il dettaglio della news selezionata.
  Widget _dettaglio() {
    final news = controller.selezionata;
    if (news == null) {
      return const Center(child: Text('Seleziona una news.'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                news['titolo']?.toString() ?? 'News',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (_puoGestire) ...<Widget>[
              IconButton(
                tooltip: 'Modifica',
                onPressed: controller.salvataggio
                    ? null
                    : () => _apriEditor(esistente: news),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Elimina',
                onPressed: controller.salvataggio
                    ? null
                    : () => _confermaEliminazione(news),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
        const Divider(height: 32),
        _campiNews(news),
      ],
    );
  }

  /// Visualizza i campi nell'ordine deciso esclusivamente dalla pagina News.
  Widget _campiNews(Map<String, dynamic> valori) => FutureBuilder<SchemaDatabase>(
        future: SchemaDatabase.carica(),
        builder: (context, snapshot) {
          final tabella = ConfigurazioneMaschere.applica(
            snapshot.data?.tabella(configurazioneModifica.tabella) ??
                TabellaDatabase.daRiga(configurazioneModifica.tabella, valori),
            pagina: configurazioneModifica,
          );

          final campi = tabella.campi
              .where(
                (campo) =>
                    campo.visibilePer(partecipante: _partecipante) &&
                    campo.nome != 'titolo' &&
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
              for (final campo in campi) _valoreCampo(campo, valori),
            ],
          );
        },
      );

  /// Rende ogni campo secondo la grafica specifica della pagina News.
  ///
  /// Le etichette non vengono mostrate: la pagina presenta la news come un
  /// articolo e non come una scheda di database.
  Widget _valoreCampo(CampoDatabase campo, Map<String, dynamic> valori) {
    final valore = valori[campo.nome];

    if (campo.nome == 'testo') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TestoHtmlMinimo(testo: valore?.toString() ?? ''),
      );
    }

    if (campo.nome == 'data_pubblicazione') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              formattaData(valore, valoreAssente: 'Data non indicata'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    if (campo.nome == 'attiva') {
      final pubblicata = valore == true;
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Chip(
            avatar: Icon(
              pubblicata
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 16,
            ),
            label: Text(pubblicata ? 'Pubblicata' : 'Non pubblicata'),
          ),
        ),
      );
    }

    final testo = valore?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SelectableText(testo.isEmpty ? '-' : testo),
    );
  }

  /// Apre la maschera dinamica di modifica e delega il salvataggio al controller.
  Future<void> _apriEditor({Map<String, dynamic>? esistente}) async {
    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: configurazioneModifica,
      partecipante: _partecipante,
      valoriIniziali: esistente ??
          <String, dynamic>{
            'titolo': '',
            'testo': null,
            'data_pubblicazione':
                DateTime.now().toIso8601String().split('T').first,
            'attiva': true,
          },
      titolo: esistente == null ? 'Nuova news' : 'Modifica news',
    );
    if (valori == null) return;

    try {
      final salvato = await controller.salva(
        esistente: esistente,
        valori: valori,
      );

      if (esistente == null && salvato['attiva'] == true) {
        final anno = salvato['anno_accademico']?.toString().trim() ?? '';
        if (anno.isNotEmpty) {
          try {
            await NotificheAutomaticheService.inviaAnnoAccademico(
              annoAccademico: anno,
              titolo: 'Nuova news',
              messaggio: salvato['titolo']?.toString() ??
                  'E disponibile una nuova news.',
            );
          } catch (_) {
            // Il salvataggio della news resta valido anche se la push fallisce.
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('News salvata.')),
      );
    } on AppException catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errore.messaggio)),
      );
    }
  }

  /// Chiede conferma e rimuove la news selezionata.
  Future<void> _confermaEliminazione(Map<String, dynamic> news) async {
    final confermata = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare la news?'),
        content: Text('"${news['titolo'] ?? ''}" verra eliminata.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confermata != true) return;

    try {
      await controller.elimina(news);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('News eliminata.')),
      );
    } on AppException catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errore.messaggio)),
      );
    }
  }
}
