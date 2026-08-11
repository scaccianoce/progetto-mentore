import 'package:flutter/material.dart';

import '../../app_exception.dart';
import '../../sessione_controller.dart';
import 'news_controller.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  late final NewsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = NewsController(
      ruolo: widget.sessione.ruolo ?? AppRole.participant,
    );
    _controller.carica();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _IntestazioneNews(
                puoGestire: _controller.puoGestire,
                caricamento: _controller.caricamento,
                onAggiorna: _controller.carica,
                onNuova: () => _apriEditor(),
              ),
              if (_controller.errore case final String errore) ...<Widget>[
                const SizedBox(height: 12),
                MaterialBanner(
                  content: Text(errore),
                  actions: <Widget>[
                    TextButton(
                      onPressed: _controller.carica,
                      child: const Text('Riprova'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Expanded(child: _contenuto()),
            ],
          ),
        );
      },
    );
  }

  Widget _contenuto() {
    if (_controller.caricamento && _controller.news.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.news.isEmpty) {
      return const Center(child: Text('Nessuna news disponibile.'));
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget elenco = _ElencoNews(
          news: _controller.news,
          selezionata: _controller.selezionata,
          onSeleziona: _controller.seleziona,
        );
        final Widget dettaglio = _DettaglioNews(
          news: _controller.selezionata,
          puoGestire: _controller.puoGestire,
          onModifica: _controller.selezionata == null
              ? null
              : () => _apriEditor(esistente: _controller.selezionata),
          onElimina: _controller.selezionata == null
              ? null
              : () => _confermaEliminazione(_controller.selezionata!),
        );

        if (constraints.maxWidth >= 800) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(width: 340, child: elenco),
              const VerticalDivider(width: 25),
              Expanded(child: dettaglio),
            ],
          );
        }

        return Column(
          children: <Widget>[
            Expanded(flex: 2, child: elenco),
            const Divider(height: 25),
            Expanded(flex: 3, child: dettaglio),
          ],
        );
      },
    );
  }

  Future<void> _apriEditor({News? esistente}) async {
    final bool? salvata = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: _EditorNews(controller: _controller, esistente: esistente),
        );
      },
    );

    if (salvata == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('News salvata.')));
    }
  }

  Future<void> _confermaEliminazione(News news) async {
    final bool? confermata = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminare la news?'),
          content: Text('La news “${news.titolo}” verrà eliminata.'),
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
        );
      },
    );

    if (confermata != true) {
      return;
    }

    try {
      await _controller.elimina(news);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('News eliminata.')));
      }
    } on AppException catch (errore) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errore.messaggio)));
      }
    }
  }
}

class _IntestazioneNews extends StatelessWidget {
  const _IntestazioneNews({
    required this.puoGestire,
    required this.caricamento,
    required this.onAggiorna,
    required this.onNuova,
  });

  final bool puoGestire;
  final bool caricamento;
  final VoidCallback onAggiorna;
  final VoidCallback onNuova;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text('News', style: Theme.of(context).textTheme.headlineSmall),
        ),
        IconButton(
          tooltip: 'Aggiorna',
          onPressed: caricamento ? null : onAggiorna,
          icon: const Icon(Icons.refresh),
        ),
        if (puoGestire)
          FilledButton.icon(
            onPressed: caricamento ? null : onNuova,
            icon: const Icon(Icons.add),
            label: const Text('Nuova'),
          ),
      ],
    );
  }
}

class _ElencoNews extends StatelessWidget {
  const _ElencoNews({
    required this.news,
    required this.selezionata,
    required this.onSeleziona,
  });

  final List<News> news;
  final News? selezionata;
  final ValueChanged<News> onSeleziona;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: news.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          final News elemento = news[index];
          return ListTile(
            selected: elemento.id == selezionata?.id,
            title: Text(
              elemento.titolo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(_formattaData(elemento.dataPubblicazione)),
            trailing: elemento.attiva
                ? null
                : const Tooltip(
                    message: 'News non attiva',
                    child: Icon(Icons.visibility_off_outlined),
                  ),
            onTap: () => onSeleziona(elemento),
          );
        },
      ),
    );
  }
}

class _DettaglioNews extends StatelessWidget {
  const _DettaglioNews({
    required this.news,
    required this.puoGestire,
    required this.onModifica,
    required this.onElimina,
  });

  final News? news;
  final bool puoGestire;
  final VoidCallback? onModifica;
  final VoidCallback? onElimina;

  @override
  Widget build(BuildContext context) {
    final News? elemento = news;
    if (elemento == null) {
      return const Center(child: Text('Seleziona una news.'));
    }

    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    elemento.titolo,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (puoGestire) ...<Widget>[
                  IconButton(
                    tooltip: 'Modifica',
                    onPressed: onModifica,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Elimina',
                    onPressed: onElimina,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(_formattaData(elemento.dataPubblicazione)),
            if (!elemento.attiva) ...<Widget>[
              const SizedBox(height: 8),
              const Chip(label: Text('Non attiva')),
            ],
            const Divider(height: 32),
            _TestoHtmlMinimo(testo: elemento.testo ?? ''),
          ],
        ),
      ),
    );
  }
}

class _EditorNews extends StatefulWidget {
  const _EditorNews({required this.controller, this.esistente});

  final NewsController controller;
  final News? esistente;

  @override
  State<_EditorNews> createState() => _EditorNewsState();
}

class _EditorNewsState extends State<_EditorNews> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titoloController;
  late final TextEditingController _testoController;
  late DateTime _data;
  late bool _attiva;
  bool _salvataggio = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _titoloController = TextEditingController(
      text: widget.esistente?.titolo ?? '',
    );
    _testoController = TextEditingController(
      text: widget.esistente?.testo ?? '',
    );
    final DateTime iniziale =
        widget.esistente?.dataPubblicazione ?? DateTime.now();
    _data = DateTime(iniziale.year, iniziale.month, iniziale.day);
    _attiva = widget.esistente?.attiva ?? true;
  }

  @override
  void dispose() {
    _titoloController.dispose();
    _testoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.esistente == null ? 'Nuova news' : 'Modifica news',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titoloController,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Titolo',
                border: OutlineInputBorder(),
              ),
              validator: (String? valore) {
                return valore == null || valore.trim().isEmpty
                    ? 'Il titolo è obbligatorio.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Formattazione',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Wrap(
              spacing: 4,
              children: <Widget>[
                _PulsanteTag(
                  tooltip: 'Grassetto',
                  etichetta: 'B',
                  stile: const TextStyle(fontWeight: FontWeight.bold),
                  onPressed: () => _inserisciTag('<b>', '</b>'),
                ),
                _PulsanteTag(
                  tooltip: 'Corsivo',
                  etichetta: 'I',
                  stile: const TextStyle(fontStyle: FontStyle.italic),
                  onPressed: () => _inserisciTag('<i>', '</i>'),
                ),
                _PulsanteTag(
                  tooltip: 'Testo più piccolo',
                  etichetta: 'A−',
                  onPressed: () => _inserisciTag('<small>', '</small>'),
                ),
                _PulsanteTag(
                  tooltip: 'Testo più grande',
                  etichetta: 'A+',
                  onPressed: () => _inserisciTag('<big>', '</big>'),
                ),
                IconButton(
                  tooltip: 'Vai a capo',
                  onPressed: () => _inserisciTesto('<br>'),
                  icon: const Icon(Icons.keyboard_return),
                ),
              ],
            ),
            TextFormField(
              controller: _testoController,
              minLines: 8,
              maxLines: 14,
              decoration: const InputDecoration(
                labelText: 'Testo',
                hintText: 'Puoi usare <b>, <i>, <small>, <big> e <br>.',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _salvataggio ? null : _scegliData,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('Data: ${_formattaData(_data)}'),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('News attiva'),
              subtitle: Text(
                _attiva ? 'Visibile ai partecipanti' : 'Non visibile',
              ),
              value: _attiva,
              onChanged: _salvataggio
                  ? null
                  : (bool valore) => setState(() => _attiva = valore),
            ),
            if (_errore case final String errore) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                errore,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _salvataggio ? null : _salva,
              icon: _salvataggio
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scegliData() async {
    final DateTime? scelta = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (scelta != null) {
      setState(() => _data = scelta);
    }
  }

  void _inserisciTag(String apertura, String chiusura) {
    final TextSelection selezione = _testoController.selection;
    final int inizio = selezione.isValid ? selezione.start : 0;
    final int fine = selezione.isValid ? selezione.end : inizio;
    final String testo = _testoController.text;
    final String selezionato = testo.substring(inizio, fine);
    final String inserimento = '$apertura$selezionato$chiusura';

    _testoController.value = TextEditingValue(
      text: testo.replaceRange(inizio, fine, inserimento),
      selection: TextSelection(
        baseOffset: inizio + apertura.length,
        extentOffset: inizio + apertura.length + selezionato.length,
      ),
    );
  }

  void _inserisciTesto(String inserimento) {
    final TextSelection selezione = _testoController.selection;
    final int posizione = selezione.isValid ? selezione.start : 0;
    final String testo = _testoController.text;
    _testoController.value = TextEditingValue(
      text: testo.replaceRange(posizione, posizione, inserimento),
      selection: TextSelection.collapsed(
        offset: posizione + inserimento.length,
      ),
    );
  }

  Future<void> _salva() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _salvataggio = true;
      _errore = null;
    });

    try {
      await widget.controller.salva(
        esistente: widget.esistente,
        titolo: _titoloController.text,
        testo: _testoController.text,
        dataPubblicazione: _data,
        attiva: _attiva,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on AppException catch (errore) {
      if (mounted) {
        setState(() {
          _errore = errore.messaggio;
          _salvataggio = false;
        });
      }
    }
  }
}

class _PulsanteTag extends StatelessWidget {
  const _PulsanteTag({
    required this.tooltip,
    required this.etichetta,
    required this.onPressed,
    this.stile,
  });

  final String tooltip;
  final String etichetta;
  final VoidCallback onPressed;
  final TextStyle? stile;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: onPressed,
        child: Text(etichetta, style: stile),
      ),
    );
  }
}

class _TestoHtmlMinimo extends StatelessWidget {
  const _TestoHtmlMinimo({required this.testo});

  final String testo;

  @override
  Widget build(BuildContext context) {
    if (testo.trim().isEmpty) {
      return const Text('Nessun testo.');
    }

    final TextStyle base =
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
    final List<InlineSpan> parti = <InlineSpan>[];
    final RegExp tag = RegExp(
      r'<\s*(/?)\s*(b|strong|i|em|small|big|br)\s*/?\s*>',
      caseSensitive: false,
    );

    int posizione = 0;
    int grassetto = 0;
    int corsivo = 0;
    final List<double> dimensioni = <double>[1];

    void aggiungi(String valore) {
      if (valore.isEmpty) {
        return;
      }
      parti.add(
        TextSpan(
          text: _decodificaHtml(valore),
          style: base.copyWith(
            fontWeight: grassetto > 0 ? FontWeight.bold : base.fontWeight,
            fontStyle: corsivo > 0 ? FontStyle.italic : base.fontStyle,
            fontSize: (base.fontSize ?? 16) * dimensioni.last,
          ),
        ),
      );
    }

    for (final RegExpMatch corrispondenza in tag.allMatches(testo)) {
      aggiungi(testo.substring(posizione, corrispondenza.start));
      final bool chiusura = corrispondenza.group(1) == '/';
      final String nome = corrispondenza.group(2)!.toLowerCase();

      if (nome == 'br') {
        aggiungi('\n');
      } else if (nome == 'b' || nome == 'strong') {
        grassetto = chiusura
            ? (grassetto > 0 ? grassetto - 1 : 0)
            : grassetto + 1;
      } else if (nome == 'i' || nome == 'em') {
        corsivo = chiusura ? (corsivo > 0 ? corsivo - 1 : 0) : corsivo + 1;
      } else if (nome == 'small' || nome == 'big') {
        if (chiusura) {
          if (dimensioni.length > 1) {
            dimensioni.removeLast();
          }
        } else {
          dimensioni.add(dimensioni.last * (nome == 'small' ? 0.85 : 1.2));
        }
      }

      posizione = corrispondenza.end;
    }

    aggiungi(testo.substring(posizione));
    return Text.rich(TextSpan(children: parti));
  }
}

String _formattaData(DateTime? data) {
  if (data == null) {
    return 'Data non indicata';
  }
  String dueCifre(int valore) => valore.toString().padLeft(2, '0');
  return '${dueCifre(data.day)}/${dueCifre(data.month)}/${data.year}';
}

String _decodificaHtml(String valore) {
  return valore
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}
