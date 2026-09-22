import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_session_controller.dart';
import 'google_sheet_controller.dart';

class GoogleSheetPage extends StatefulWidget {
  const GoogleSheetPage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<GoogleSheetPage> createState() => _GoogleSheetPageState();
}

class _GoogleSheetPageState extends State<GoogleSheetPage> {
  late final GoogleSheetController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GoogleSheetController(widget.sessione);
    unawaited(_controller.carica());
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
      builder: (context, _) {
        if (!_controller.puoGestire) return const SizedBox.shrink();
        return Scaffold(
          body: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sincronizzazione Google Sheet',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Aggiorna',
                      onPressed: _controller.caricamento
                          ? null
                          : _controller.carica,
                      icon: const Icon(Icons.refresh),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _controller.sorgenti.isEmpty
                          ? null
                          : () => _apriEditor(),
                      icon: const Icon(Icons.add),
                      label: const Text('Nuova'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Configura una sorgente autorizzata e associa i suoi campi '
                  'alle intestazioni del foglio. Il secret resta cifrato nel Vault.',
                ),
                const SizedBox(height: 16),
                if (_controller.caricamento) const LinearProgressIndicator(),
                if (_controller.errore != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_controller.errore!),
                  ),
                Expanded(
                  child:
                      _controller.configurazioni.isEmpty &&
                          !_controller.caricamento
                      ? const Center(
                          child: Text('Nessuna configurazione presente.'),
                        )
                      : ListView.separated(
                          itemCount: _controller.configurazioni.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, indice) =>
                              _card(_controller.configurazioni[indice]),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card(Map<String, dynamic> configurazione) {
    final mappature = (configurazione['mappature'] as List?) ?? const [];
    final sheetUrl = configurazione['sheet_url']?.toString() ?? '';
    return Card(
      child: ListTile(
        leading: Icon(
          configurazione['attiva'] == true ? Icons.sync : Icons.sync_disabled,
        ),
        title: Text(configurazione['nome']?.toString() ?? 'Configurazione'),
        subtitle: Text(
          '${configurazione['sorgente_view']} · ${mappature.length} '
          'corrispondenze · ${configurazione['attiva'] == true ? 'attiva' : 'inattiva'}',
        ),
        onTap: () => _apriEditor(configurazione),
        trailing: Wrap(
          spacing: 4,
          children: [
            if (sheetUrl.isNotEmpty)
              IconButton(
                tooltip: 'Apri foglio',
                onPressed: () => launchUrl(
                  Uri.parse(sheetUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new),
              ),
            IconButton(
              tooltip: 'Elimina',
              onPressed: () => _elimina(configurazione),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _apriEditor([Map<String, dynamic>? esistente]) async {
    final valori = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GoogleSheetEditor(
        sorgenti: _controller.sorgenti,
        esistente: esistente,
      ),
    );
    if (valori == null) return;
    final errore = await _controller.salva(valori);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errore ?? 'Configurazione salvata.'),
        backgroundColor: errore == null
            ? null
            : Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _elimina(Map<String, dynamic> configurazione) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare la configurazione?'),
        content: Text(
          'Verranno eliminate anche le corrispondenze e il secret cifrato di '
          '“${configurazione['nome']}”.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (conferma != true) return;
    final errore = await _controller.elimina(configurazione['id'].toString());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errore ?? 'Configurazione eliminata.')),
    );
  }
}

class _GoogleSheetEditor extends StatefulWidget {
  const _GoogleSheetEditor({required this.sorgenti, this.esistente});

  final List<Map<String, dynamic>> sorgenti;
  final Map<String, dynamic>? esistente;

  @override
  State<_GoogleSheetEditor> createState() => _GoogleSheetEditorState();
}

class _GoogleSheetEditorState extends State<_GoogleSheetEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _scriptUrl;
  late final TextEditingController _sheetUrl;
  late final TextEditingController _secret;
  late String _sorgente;
  late String _campoId;
  late String _campoEmail;
  late bool _attiva;
  final List<_MappaEditor> _mappature = [];

  Map<String, dynamic> get _sorgenteCorrente =>
      widget.sorgenti.firstWhere((s) => s['nome_view'] == _sorgente);

  List<String> get _campi => ((_sorgenteCorrente['campi'] as List?) ?? const [])
      .map((e) => e.toString())
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    final e = widget.esistente;
    _nome = TextEditingController(text: e?['nome']?.toString() ?? '');
    _scriptUrl = TextEditingController(
      text: e?['script_url']?.toString() ?? '',
    );
    _sheetUrl = TextEditingController(text: e?['sheet_url']?.toString() ?? '');
    _secret = TextEditingController();
    _sorgente =
        e?['sorgente_view']?.toString() ??
        widget.sorgenti.first['nome_view'].toString();
    _campoId =
        e?['campo_id']?.toString() ??
        _sorgenteCorrente['campo_id_default'].toString();
    _campoEmail =
        e?['campo_email']?.toString() ??
        _sorgenteCorrente['campo_email_default'].toString();
    _attiva = e?['attiva'] == true;
    final righe = (e?['mappature'] as List?) ?? const [];
    for (final raw in righe.whereType<Map>()) {
      _mappature.add(
        _MappaEditor(
          campo: raw['campo_sorgente']?.toString(),
          colonna: raw['colonna_google']?.toString() ?? '',
        ),
      );
    }
    if (_mappature.isEmpty) {
      _mappature.add(_MappaEditor());
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _scriptUrl.dispose();
    _sheetUrl.dispose();
    _secret.dispose();
    for (final mappa in _mappature) {
      mappa.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.esistente == null
            ? 'Nuova configurazione'
            : 'Modifica configurazione',
      ),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nome,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: _obbligatorio,
                ),
                TextFormField(
                  controller: _scriptUrl,
                  decoration: const InputDecoration(
                    labelText: 'URL Web App Google Apps Script (/exec)',
                  ),
                  validator: _obbligatorio,
                ),
                TextFormField(
                  controller: _sheetUrl,
                  decoration: const InputDecoration(
                    labelText: 'Link al foglio Google',
                  ),
                  validator: _obbligatorio,
                ),
                TextFormField(
                  controller: _secret,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: widget.esistente == null
                        ? 'Google Script secret'
                        : 'Nuovo secret (lascia vuoto per conservarlo)',
                  ),
                  validator: widget.esistente == null ? _obbligatorio : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('sorgente-$_sorgente'),
                  isExpanded: true,
                  initialValue: _sorgente,
                  decoration: const InputDecoration(
                    labelText: 'Sorgente autorizzata',
                  ),
                  items: [
                    for (final s in widget.sorgenti)
                      DropdownMenuItem(
                        value: s['nome_view'].toString(),
                        child: Text(
                          s['descrizione']?.toString() ??
                              s['nome_view'].toString(),
                        ),
                      ),
                  ],
                  onChanged: (valore) {
                    if (valore == null) return;
                    setState(() {
                      _sorgente = valore;
                      _campoId = _sorgenteCorrente['campo_id_default']
                          .toString();
                      _campoEmail = _sorgenteCorrente['campo_email_default']
                          .toString();
                      for (final m in _mappature) {
                        m.campo = null;
                      }
                    });
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: _dropdownCampo(
                        'Campo identificativo',
                        _campoId,
                        (v) => setState(() => _campoId = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dropdownCampo(
                        'Campo email',
                        _campoEmail,
                        (v) => setState(() => _campoEmail = v!),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Configurazione attiva'),
                  subtitle: const Text(
                    'Può essere attiva una sola configurazione per sorgente.',
                  ),
                  value: _attiva,
                  onChanged: (v) => setState(() => _attiva = v),
                ),
                const Divider(),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Corrispondenze',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _mappature.add(_MappaEditor())),
                      icon: const Icon(Icons.add),
                      label: const Text('Aggiungi riga'),
                    ),
                  ],
                ),
                for (var i = 0; i < _mappature.length; i++) _rigaMappa(i),
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
        FilledButton(onPressed: _salva, child: const Text('Salva')),
      ],
    );
  }

  Widget _dropdownCampo(
    String etichetta,
    String valore,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$etichetta-$_sorgente-$valore'),
      isExpanded: true,
      initialValue: _campi.contains(valore) ? valore : null,
      decoration: InputDecoration(labelText: etichetta),
      items: [
        for (final campo in _campi)
          DropdownMenuItem(value: campo, child: Text('$_sorgente.$campo')),
      ],
      onChanged: onChanged,
      validator: (v) => v == null ? 'Campo obbligatorio' : null,
    );
  }

  Widget _rigaMappa(int indice) {
    final mappa = _mappature[indice];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              key: ValueKey('mappa-$indice-$_sorgente-${mappa.campo}'),
              isExpanded: true,
              initialValue: _campi.contains(mappa.campo) ? mappa.campo : null,
              decoration: const InputDecoration(labelText: 'Tabella.campo'),
              items: [
                for (final campo in _campi)
                  DropdownMenuItem(
                    value: campo,
                    child: Text('$_sorgente.$campo'),
                  ),
              ],
              onChanged: (v) => mappa.campo = v,
              validator: (v) => v == null ? 'Campo obbligatorio' : null,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward),
          ),
          Expanded(
            child: TextFormField(
              controller: mappa.colonna,
              decoration: const InputDecoration(
                labelText: 'Colonna Google Sheet',
              ),
              validator: _obbligatorio,
            ),
          ),
          IconButton(
            tooltip: 'Rimuovi riga',
            onPressed: _mappature.length == 1
                ? null
                : () => setState(() {
                    _mappature.removeAt(indice).dispose();
                  }),
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ],
      ),
    );
  }

  String? _obbligatorio(String? valore) =>
      valore == null || valore.trim().isEmpty ? 'Campo obbligatorio' : null;

  void _salva() {
    if (!_formKey.currentState!.validate()) return;
    final campi = _mappature.map((m) => m.campo).toList(growable: false);
    final colonne = _mappature
        .map((m) => m.colonna.text.trim().toLowerCase())
        .toList(growable: false);
    if (campi.toSet().length != campi.length ||
        colonne.toSet().length != colonne.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ogni campo sorgente e ogni colonna Google possono comparire una sola volta.',
          ),
        ),
      );
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'id': widget.esistente?['id'],
      'nome': _nome.text.trim(),
      'script_url': _scriptUrl.text.trim(),
      'sheet_url': _sheetUrl.text.trim(),
      'secret': _secret.text.trim(),
      'sorgente_view': _sorgente,
      'campo_id': _campoId,
      'campo_email': _campoEmail,
      'attiva': _attiva,
      'mappature': [
        for (var i = 0; i < _mappature.length; i++)
          {
            'campo_sorgente': _mappature[i].campo,
            'colonna_google': _mappature[i].colonna.text.trim(),
            'ordine': i,
          },
      ],
    });
  }
}

class _MappaEditor {
  _MappaEditor({this.campo, String colonna = ''})
    : colonna = TextEditingController(text: colonna);

  String? campo;
  final TextEditingController colonna;

  void dispose() => colonna.dispose();
}
