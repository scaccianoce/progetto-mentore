import 'package:flutter/material.dart';

import '../../app_exception.dart';
import '../../sessione_controller.dart';
import 'profilo_controller.dart';

class ProfiloPage extends StatefulWidget {
  const ProfiloPage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<ProfiloPage> createState() => _ProfiloPageState();
}

class _ProfiloPageState extends State<ProfiloPage> {
  late final ProfiloController _controller;

  static const Map<String, String> _etichette = <String, String>{
    'email_unipa': 'Email UNIPA',
    'cognome': 'Cognome',
    'nome': 'Nome',
    'cod_ssd': 'SSD',
    'dipartimento': 'Dipartimento',
    'ufficio': 'Ufficio',
    'ruolo_accademico': 'Ruolo accademico',
    'cellulare': 'Cellulare',
    'fascia_eta': 'Fascia d’età',
    'pagina_personale_unipa': 'Pagina personale UNIPA',
    'anno_prima_partecipazione': 'Prima partecipazione',
  };

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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        if (_controller.caricamento && _controller.profilo == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_controller.profilo == null) {
          return _MessaggioProfilo(
            messaggio: _controller.errore ?? 'Profilo non trovato.',
            onRiprova: _controller.carica,
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
                          if (_controller.puoModificare)
                            FilledButton.icon(
                              onPressed: _controller.salvataggio
                                  ? null
                                  : _apriEditor,
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
                      if (_controller.errore case final String errore) ...[
                        const SizedBox(height: 12),
                        Text(
                          errore,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const Divider(height: 32),
                      ..._etichette.entries.map((MapEntry<String, String> e) {
                        final String valore =
                            _controller.profilo![e.key]?.toString().trim() ??
                            '';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            e.value,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(valore.isEmpty ? '—' : valore),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _apriEditor() async {
    final Map<String, dynamic>? valori = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ProfiloEditor(
        profilo: _controller.profilo!,
        ssd: _controller.ssd,
        anniAccademici: _controller.anniAccademici,
      ),
    );

    if (valori != null) {
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
}

class _ProfiloEditor extends StatefulWidget {
  const _ProfiloEditor({
    required this.profilo,
    required this.ssd,
    required this.anniAccademici,
  });

  final Map<String, dynamic> profilo;
  final List<Map<String, dynamic>> ssd;
  final List<String> anniAccademici;

  @override
  State<_ProfiloEditor> createState() => _ProfiloEditorState();
}

class _ProfiloEditorState extends State<_ProfiloEditor> {
  static const ruoliAccademici = <String>[
    'PO',
    'PA',
    'RU',
    'RTT',
    'RTDb',
    'RTDa',
    'altro',
  ];
  static const fasceEta = <String>[
    '<35',
    '35-40',
    '41-50',
    '51-60',
    '61-70',
    '>70',
  ];

  final form = GlobalKey<FormState>();
  final campi = <String, TextEditingController>{};
  String? codSsd;
  String? ruoloAccademico;
  String? fasciaEta;
  String? annoPrimaPartecipazione;

  @override
  void initState() {
    super.initState();
    for (final chiave in <String>[
      'email_unipa',
      'cognome',
      'nome',
      'dipartimento',
      'ufficio',
      'cellulare',
      'pagina_personale_unipa',
    ]) {
      campi[chiave] = TextEditingController(
        text: widget.profilo[chiave]?.toString() ?? '',
      );
    }
    codSsd = _valore(widget.profilo['cod_ssd']);
    ruoloAccademico = _valore(widget.profilo['ruolo_accademico']);
    fasciaEta = _valore(widget.profilo['fascia_eta']);
    annoPrimaPartecipazione = _valore(
      widget.profilo['anno_prima_partecipazione'],
    );
  }

  @override
  void dispose() {
    for (final controller in campi.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Modifica profilo'),
    content: SizedBox(
      width: 680,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _campoTesto(
                'email_unipa',
                'Email UNIPA',
                obbligatorio: true,
                tastiera: TextInputType.emailAddress,
                validatore: _email,
                abilitato: false,
              ),
              _campoTesto('cognome', 'Cognome', obbligatorio: true),
              _campoTesto('nome', 'Nome', obbligatorio: true),
              _selezione<String?>(
                etichetta: 'SSD',
                valore: codSsd,
                elementi: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Non specificato'),
                  ),
                  ...widget.ssd.map(
                    (riga) => DropdownMenuItem(
                      value: riga['cod_ssd'].toString(),
                      child: Text(_descrizioneSsd(riga)),
                    ),
                  ),
                ],
                onChanged: (valore) => setState(() => codSsd = valore),
              ),
              _selezione<String?>(
                etichetta: 'Ruolo accademico',
                valore: ruoloAccademico,
                elementi: <DropdownMenuItem<String?>>[
                  ...ruoliAccademici.map(
                    (valore) => DropdownMenuItem<String?>(
                      value: valore,
                      child: Text(valore),
                    ),
                  ),
                ],
                onChanged: (valore) => setState(() => ruoloAccademico = valore),
                validatore: (valore) => valore == null ? 'Obbligatorio' : null,
              ),
              _selezione<String?>(
                etichetta: 'Fascia d’età',
                valore: fasciaEta,
                elementi: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Non specificata'),
                  ),
                  ...fasceEta.map(
                    (valore) =>
                        DropdownMenuItem(value: valore, child: Text(valore)),
                  ),
                ],
                onChanged: (valore) => setState(() => fasciaEta = valore),
              ),
              _selezione<String?>(
                etichetta: 'Anno prima partecipazione',
                valore: annoPrimaPartecipazione,
                elementi: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Non specificato'),
                  ),
                  ...widget.anniAccademici.map(
                    (valore) =>
                        DropdownMenuItem(value: valore, child: Text(valore)),
                  ),
                ],
                onChanged: (valore) =>
                    setState(() => annoPrimaPartecipazione = valore),
              ),
              _campoTesto('dipartimento', 'Dipartimento', largo: true),
              _campoTesto('ufficio', 'Ufficio'),
              _campoTesto(
                'cellulare',
                'Cellulare',
                tastiera: TextInputType.phone,
                validatore: _telefono,
              ),
              _campoTesto(
                'pagina_personale_unipa',
                'Pagina personale UNIPA',
                largo: true,
                tastiera: TextInputType.url,
                validatore: _url,
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
      FilledButton(onPressed: _salva, child: const Text('Salva')),
    ],
  );

  Widget _campoTesto(
    String chiave,
    String etichetta, {
    bool obbligatorio = false,
    bool largo = false,
    TextInputType? tastiera,
    String? Function(String?)? validatore,
    bool abilitato = true,
  }) => SizedBox(
    width: largo ? 656 : 320,
    child: TextFormField(
      controller: campi[chiave],
      enabled: abilitato,
      keyboardType: tastiera,
      decoration: InputDecoration(labelText: etichetta),
      validator:
          validatore ??
          (obbligatorio
              ? (valore) => valore == null || valore.trim().isEmpty
                    ? 'Campo obbligatorio'
                    : null
              : null),
    ),
  );

  Widget _selezione<T>({
    required String etichetta,
    required T valore,
    required List<DropdownMenuItem<T>> elementi,
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validatore,
  }) => SizedBox(
    width: 320,
    child: DropdownButtonFormField<T>(
      initialValue: valore,
      isExpanded: true,
      decoration: InputDecoration(labelText: etichetta),
      items: elementi,
      onChanged: onChanged,
      validator: validatore,
    ),
  );

  void _salva() {
    if (!(form.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      for (final voce in campi.entries) voce.key: _nullSeVuoto(voce.value.text),
      'cod_ssd': codSsd,
      'ruolo_accademico': ruoloAccademico,
      'fascia_eta': fasciaEta,
      'anno_prima_partecipazione': annoPrimaPartecipazione,
    });
  }

  String _descrizioneSsd(Map<String, dynamic> riga) {
    final codice = riga['cod_ssd'].toString();
    final area = _valore(riga['area']);
    return area == null ? codice : '$codice — $area';
  }

  String? _email(String? valore) {
    final testo = valore?.trim() ?? '';
    if (testo.isEmpty) {
      return 'Campo obbligatorio';
    }
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(testo)
        ? null
        : 'Email non valida';
  }

  String? _telefono(String? valore) {
    final testo = valore?.trim() ?? '';
    if (testo.isEmpty) {
      return null;
    }
    return RegExp(r'^\+[0-9]{6,18}$').hasMatch(testo)
        ? null
        : 'Usa il formato internazionale, per esempio +39...';
  }

  String? _url(String? valore) {
    final testo = valore?.trim() ?? '';
    if (testo.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(testo);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https')
        ? null
        : 'Inserisci un URL http o https';
  }
}

String? _valore(Object? valore) {
  final testo = valore?.toString().trim() ?? '';
  return testo.isEmpty ? null : testo;
}

String? _nullSeVuoto(String valore) =>
    valore.trim().isEmpty ? null : valore.trim();

class _MessaggioProfilo extends StatelessWidget {
  const _MessaggioProfilo({required this.messaggio, required this.onRiprova});

  final String messaggio;
  final VoidCallback onRiprova;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(messaggio),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRiprova, child: const Text('Riprova')),
        ],
      ),
    );
  }
}
