import 'dart:convert';

import 'package:flutter/material.dart';

import '../supporto/utilita.dart';

import '../dati/repository.dart';
import 'dinamico_schema.dart';


/// Apre l'editor dinamico condiviso usato per la modifica dei record.
Future<Map<String, dynamic>?> mostraMascheraDinamica({
  required BuildContext context,
  required Map<String, dynamic> valoriIniziali,
  ConfigurazionePaginaDinamica? configurazione,
  String? tabella,
  bool partecipante = false,
  bool mostraCampiSolaLettura = false,
  String? titolo,
  Widget? contenutoExtra,
}) async {
  assert(
    configurazione != null || tabella != null,
    'Specificare configurazione oppure tabella.',
  );
  final configurazioneEffettiva =
      configurazione ?? ConfigurazionePaginaDinamica(tabella: tabella!);
  TabellaDatabase definizione;
  try {
    final schema = await SchemaDatabase.carica();
    definizione =
        schema.tabella(configurazioneEffettiva.tabella) ??
        TabellaDatabase.daRiga(configurazioneEffettiva.tabella, valoriIniziali);
  } catch (_) {
    // Consente l'uso delle maschere anche prima di installare la RPC.
    definizione = TabellaDatabase.daRiga(
      configurazioneEffettiva.tabella,
      valoriIniziali,
    );
  }
  definizione = ConfigurazioneMaschere.applica(
    definizione,
    pagina: configurazioneEffettiva,
  );
  definizione = _ordinaDefinizione(
    definizione,
    configurazioneEffettiva.ordineCampi,
  );
  if (!context.mounted) return null;

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => MascheraDinamica(
      tabella: definizione,
      valoriIniziali: valoriIniziali,
      partecipante: partecipante,
      mostraCampiSolaLettura: mostraCampiSolaLettura,
      titolo: titolo,
      contenutoExtra: contenutoExtra,
    ),
  );
}

/// Dialog dinamico usato esclusivamente per la modifica dei record.
class MascheraDinamica extends StatefulWidget {
  const MascheraDinamica({
    super.key,
    required this.tabella,
    required this.valoriIniziali,
    this.partecipante = false,
    this.mostraCampiSolaLettura = false,
    this.titolo,
    this.contenutoExtra,
  });

  final TabellaDatabase tabella;
  final Map<String, dynamic> valoriIniziali;
  final bool partecipante;
  final bool mostraCampiSolaLettura;
  final String? titolo;
  final Widget? contenutoExtra;

  @override
  State<MascheraDinamica> createState() => _MascheraDinamicaState();
}

/// Componente `MascheraDinamicaState`: incapsula responsabilità specifiche del relativo modulo.
class _MascheraDinamicaState extends State<MascheraDinamica> {
  final DatabaseRepository _database = DatabaseRepository();
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controller = {};
  final Map<String, dynamic> _valori = {};
  final Map<String, List<_OpzioneRelazione>> _opzioniRelazione = {};
  final Set<String> _relazioniInCaricamento = {};

  Iterable<CampoDatabase> get _campi => widget.tabella.campi.where((campo) {
    if (widget.mostraCampiSolaLettura) {
      return campo.visibilePer(partecipante: widget.partecipante);
    }
    return campo.modificabilePer(partecipante: widget.partecipante);
  });

  /// Campi gia' ordinati dalla configurazione della maschera o dallo schema DB.
  List<CampoDatabase> get _campiOrdinati => _campi.toList(growable: false);

  bool _modificabile(CampoDatabase campo) =>
      campo.modificabilePer(partecipante: widget.partecipante);


  String _etichettaCampo(CampoDatabase campo) =>
      campo.obbligatorio && _modificabile(campo)
          ? '${campo.etichetta} *'
          : campo.etichetta;

  @override
  void initState() {
    super.initState();
    for (final campo in _campiOrdinati) {
      final valore = widget.valoriIniziali[campo.nome];
      _valori[campo.nome] = valore;
      if (_usaController(campo.tipo)) {
        _controller[campo.nome] = TextEditingController(
          text: _testoIniziale(campo, valore),
        );
      }
      if (campo.tipo == TipoCampoDinamico.relazione) {
        _caricaRelazione(campo);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controller.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.titolo ?? 'Modifica ${widget.tabella.nome}'),
    content: SizedBox(
      width: 680,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ..._costruisciCampi(),
                if (widget.contenutoExtra != null) ...[
                  const Divider(height: 28),
                  widget.contenutoExtra!,
                ],
              ],
            ),
          ),
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
      FilledButton(onPressed: _salva, child: const Text('Salva')),
    ],
  );


  List<Widget> _costruisciCampi() => _campiOrdinati
      .map(
        (campo) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _costruisciCampo(campo),
        ),
      )
      .toList(growable: false);

  Widget _costruisciCampo(CampoDatabase campo) => switch (campo.tipo) {
    TipoCampoDinamico.booleano => SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_etichettaCampo(campo)),
      value: _valori[campo.nome] == true,
      onChanged: _modificabile(campo)
          ? (value) => setState(() => _valori[campo.nome] = value)
          : null,
    ),
    TipoCampoDinamico.data || TipoCampoDinamico.dataOra => _CampoData(
      campo: campo,
      valore: dataDa(_valori[campo.nome]),
      conOra: campo.tipo == TipoCampoDinamico.dataOra,
      onChanged: _modificabile(campo)
          ? (value) => setState(() => _valori[campo.nome] = value)
          : null,
    ),
    TipoCampoDinamico.scelta => _menuScelta(campo),
    TipoCampoDinamico.relazione => _menuRelazione(campo),
    TipoCampoDinamico.testoFormattato => _modificabile(campo)
        ? EditorTestoFormattato(
            controller: _controller[campo.nome]!,
            etichetta: _etichettaCampo(campo),
            minLines: 5,
            maxLines: 10,
            validator: (value) => _validaTesto(campo, value),
          )
        : TextFormField(
            controller: _controller[campo.nome],
            readOnly: true,
            minLines: 4,
            maxLines: null,
            decoration: InputDecoration(
              labelText: _etichettaCampo(campo),
              border: const OutlineInputBorder(),
            ),
          ),
    _ => TextFormField(
      controller: _controller[campo.nome],
      readOnly: !_modificabile(campo),
      minLines: campo.tipo == TipoCampoDinamico.testoMultiriga ? 4 : 1,
      maxLines: campo.tipo == TipoCampoDinamico.testoMultiriga ? null : 1,
      keyboardType: switch (campo.tipo) {
        TipoCampoDinamico.numeroIntero => TextInputType.number,
        TipoCampoDinamico.numeroDecimale =>
          const TextInputType.numberWithOptions(decimal: true),
        TipoCampoDinamico.testoMultiriga || TipoCampoDinamico.json =>
          TextInputType.multiline,
        _ => TextInputType.text,
      },
      textInputAction: campo.tipo == TipoCampoDinamico.testoMultiriga
          ? TextInputAction.newline
          : null,
      validator: (value) => _validaTesto(campo, value),
      decoration: InputDecoration(
        labelText: _etichettaCampo(campo),
        alignLabelWithHint: campo.tipo == TipoCampoDinamico.testoMultiriga,
        border: const OutlineInputBorder(),
      ),
    ),
  };

  Widget _menuScelta(CampoDatabase campo) {
    final corrente = _valori[campo.nome]?.toString();
    final scelte = <String>{...campo.valoriScelta};
    if (corrente != null && corrente.isNotEmpty) scelte.add(corrente);
    return DropdownButtonFormField<String?>(
      initialValue: corrente,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: _etichettaCampo(campo),
        border: const OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<String?>>[
        if (!campo.obbligatorio)
          const DropdownMenuItem<String?>(value: null, child: Text('—')),
        ...scelte.map(
          (value) =>
              DropdownMenuItem<String?>(value: value, child: Text(value)),
        ),
      ],
      validator: (value) => campo.obbligatorio && (value == null || value.isEmpty)
          ? 'Campo obbligatorio'
          : null,
      onChanged: _modificabile(campo)
          ? (value) => _valori[campo.nome] = value
          : null,
    );
  }

  Widget _menuRelazione(CampoDatabase campo) {
    final caricamento = _relazioniInCaricamento.contains(campo.nome);
    final opzioni = _opzioniRelazione[campo.nome] ?? const [];
    final corrente = _valori[campo.nome]?.toString();
    final presente = opzioni.any((opzione) => opzione.valore == corrente);
    final voci = <_OpzioneRelazione>[
      ...opzioni,
      if (corrente != null && !presente)
        _OpzioneRelazione(valore: corrente, etichetta: corrente),
    ];
    return DropdownButtonFormField<String?>(
      initialValue: corrente,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: _etichettaCampo(campo),
        border: const OutlineInputBorder(),
        suffixIcon: caricamento
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
      items: <DropdownMenuItem<String?>>[
        if (!campo.obbligatorio)
          const DropdownMenuItem<String?>(value: null, child: Text('—')),
        ...voci.map(
          (opzione) => DropdownMenuItem<String?>(
            value: opzione.valore,
            child: Text(opzione.etichetta),
          ),
        ),
      ],
      validator: (value) =>
          campo.obbligatorio && value == null ? 'Campo obbligatorio' : null,
      onChanged: caricamento || !_modificabile(campo)
          ? null
          : (value) => _valori[campo.nome] = value,
    );
  }

  /// Carica in modo generico le opzioni di un campo relazionale.
  ///
  /// La maschera non contiene eccezioni per tabelle applicative specifiche:
  /// usa la relazione dichiarata dallo schema e il campo descrittivo della
  /// tabella collegata.
  Future<void> _caricaRelazione(CampoDatabase campo) async {
    final relazione = campo.relazione;
    if (relazione == null) return;

    _relazioniInCaricamento.add(campo.nome);

    try {
      final schema = await SchemaDatabase.carica(database: _database);
      final tabellaCollegata = schema.tabella(relazione.tabella);
      final campoEtichetta = _campoDescrittivo(
        tabellaCollegata,
        relazione.colonna,
      );

      final selezione = campoEtichetta == relazione.colonna
          ? relazione.colonna
          : '${relazione.colonna}, $campoEtichetta';

      final righe = await _database
          .tabella(relazione.tabella)
          .elenco(
            colonne: selezione,
            limite: 1000,
          );

      final opzioni = righe.map((riga) {
        final valoreRaw = riga[relazione.colonna];
        final valore = valoreRaw?.toString() ?? '';
        final descrizione = riga[campoEtichetta]?.toString().trim() ?? '';

        return _OpzioneRelazione(
          valore: valore,
          etichetta: descrizione.isEmpty ? valore : descrizione,
        );
      }).where((opzione) => opzione.valore.isNotEmpty).toList(growable: true)
        ..sort(
          (a, b) => a.etichetta.toLowerCase().compareTo(
                b.etichetta.toLowerCase(),
              ),
        );

      _opzioniRelazione[campo.nome] = opzioni;
    } catch (_) {
      _opzioniRelazione[campo.nome] = const <_OpzioneRelazione>[];
    } finally {
      _relazioniInCaricamento.remove(campo.nome);
      if (mounted) setState(() {});
    }
  }

  void _salva() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final risultato = <String, dynamic>{};
    for (final campo in _campiOrdinati.where(_modificabile)) {
      if (_usaController(campo.tipo)) {
        final originale = _controller[campo.nome]!.text;
        final multilinea = campo.tipo == TipoCampoDinamico.testoMultiriga ||
            campo.tipo == TipoCampoDinamico.testoFormattato;
        final testo = multilinea
            ? (originale.trim().isEmpty ? '' : originale)
            : originale.trim();
        risultato[campo.nome] = _convertiTesto(campo, testo);
      } else {
        final valore = _valori[campo.nome];
        risultato[campo.nome] = valore is DateTime
            ? campo.tipo == TipoCampoDinamico.data
                  ? valore.toIso8601String().split('T').first
                  : valore.toIso8601String()
            : _convertiRelazione(campo, valore);
      }
    }
    Navigator.pop(context, risultato);
  }

  String? _validaTesto(CampoDatabase campo, String? value) {
    final testo = value?.trim() ?? '';
    if (campo.obbligatorio && testo.isEmpty) return 'Campo obbligatorio';
    if (testo.isEmpty) return null;
    if (campo.tipo == TipoCampoDinamico.numeroIntero &&
        int.tryParse(testo) == null) {
      return 'Inserire un numero intero';
    }
    if (campo.tipo == TipoCampoDinamico.numeroDecimale &&
        double.tryParse(testo.replaceAll(',', '.')) == null) {
      return 'Inserire un numero';
    }
    if (campo.tipo == TipoCampoDinamico.json) {
      try {
        jsonDecode(testo);
      } catch (_) {
        return 'JSON non valido';
      }
    }
    return null;
  }
}

/// Componente `CampoData`: incapsula responsabilità specifiche del relativo modulo.
class _CampoData extends StatelessWidget {
  const _CampoData({
    required this.campo,
    required this.valore,
    required this.conOra,
    required this.onChanged,
  });

  final CampoDatabase campo;
  final DateTime? valore;
  final bool conOra;
  final ValueChanged<DateTime?>? onChanged;

  @override
  Widget build(BuildContext context) => FormField<DateTime>(
    initialValue: valore,
    validator: (value) =>
        campo.obbligatorio && value == null ? 'Campo obbligatorio' : null,
    builder: (state) => InputDecorator(
      decoration: InputDecoration(
        labelText: campo.obbligatorio && onChanged != null
            ? '${campo.etichetta} *'
            : campo.etichetta,
        border: const OutlineInputBorder(),
        errorText: state.errorText,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              conOra
                  ? formattaDataOra(valore, valoreAssente: 'Nessuna data')
                  : formattaData(valore, valoreAssente: 'Nessuna data'),
            ),
          ),
          if (valore != null && campo.nullable)
            IconButton(
              tooltip: 'Rimuovi',
              onPressed: onChanged == null
                  ? null
                  : () {
                      state.didChange(null);
                      onChanged!(null);
                    },
              icon: const Icon(Icons.clear),
            ),
          IconButton(
            tooltip: 'Scegli data',
            onPressed: onChanged == null
                ? null
                : () async {
              final data = await showDatePicker(
                context: context,
                initialDate: valore ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(2200),
              );
              if (data == null || !context.mounted) return;
              DateTime risultato = data;
              if (conOra) {
                final ora = await showTimePicker(
                  context: context,
                  initialTime: valore == null
                      ? TimeOfDay.now()
                      : TimeOfDay.fromDateTime(valore!),
                );
                if (ora == null) return;
                risultato = DateTime(
                  data.year,
                  data.month,
                  data.day,
                  ora.hour,
                  ora.minute,
                );
              }
              state.didChange(risultato);
              onChanged!(risultato);
            },
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
    ),
  );
}

/// Componente `OpzioneRelazione`: incapsula responsabilità specifiche del relativo modulo.
class _OpzioneRelazione {
  const _OpzioneRelazione({required this.valore, required this.etichetta});
  final String valore;
  final String etichetta;
}

bool _usaController(TipoCampoDinamico tipo) => switch (tipo) {
  TipoCampoDinamico.testoBreve ||
  TipoCampoDinamico.testoMultiriga ||
  TipoCampoDinamico.testoFormattato ||
  TipoCampoDinamico.numeroIntero ||
  TipoCampoDinamico.numeroDecimale ||
  TipoCampoDinamico.json => true,
  _ => false,
};

String _testoIniziale(CampoDatabase campo, Object? valore) {
  if (valore == null) return '';
  if (campo.tipo == TipoCampoDinamico.json && valore is! String) {
    return const JsonEncoder.withIndent('  ').convert(valore);
  }
  return valore.toString();
}

Object? _convertiTesto(CampoDatabase campo, String testo) {
  if (testo.isEmpty) return null;
  return switch (campo.tipo) {
    TipoCampoDinamico.numeroIntero => int.parse(testo),
    TipoCampoDinamico.numeroDecimale => double.parse(
      testo.replaceAll(',', '.'),
    ),
    TipoCampoDinamico.json => jsonDecode(testo),
    _ => testo,
  };
}

Object? _convertiRelazione(CampoDatabase campo, Object? valore) {
  if (campo.tipo != TipoCampoDinamico.relazione || valore == null) {
    return valore;
  }
  final testo = valore.toString();
  final tipo = campo.tipoDatabase.toLowerCase();
  if (<String>{'smallint', 'integer', 'bigint'}.contains(tipo)) {
    return int.tryParse(testo) ?? testo;
  }
  return testo;
}


/// Applica alla sola maschera di modifica l'ordine dichiarato dalla pagina.
///
/// La definizione dello schema non viene alterata globalmente: viene creata
/// una copia della tabella con i campi nell'ordine richiesto.
TabellaDatabase _ordinaDefinizione(
  TabellaDatabase tabella,
  List<String> ordineCampi,
) {
  if (ordineCampi.isEmpty) return tabella;

  final posizione = <String, int>{
    for (var i = 0; i < ordineCampi.length; i++) ordineCampi[i]: i,
  };

  final campi = tabella.campi.toList(growable: false);
  final ordinati = campi.toList(growable: true)
    ..sort((a, b) {
      final posizioneA = posizione[a.nome];
      final posizioneB = posizione[b.nome];

      if (posizioneA != null && posizioneB != null) {
        return posizioneA.compareTo(posizioneB);
      }
      if (posizioneA != null) return -1;
      if (posizioneB != null) return 1;

      return a.posizione.compareTo(b.posizione);
    });

  return TabellaDatabase(
    nome: tabella.nome,
    commento: tabella.commento,
    tipoOggetto: tabella.tipoOggetto,
    campi: ordinati,
  );
}

String _campoDescrittivo(TabellaDatabase? tabella, String chiave) =>
    tabella?.nomeCampoDescrittivo ?? chiave;

/// Componente `EditorTestoFormattato`: incapsula responsabilità specifiche del relativo modulo.
class EditorTestoFormattato extends StatelessWidget {
  const EditorTestoFormattato({
    super.key,
    required this.controller,
    required this.etichetta,
    this.minLines = 8,
    this.maxLines = 14,
    this.validator,
  });

  final TextEditingController controller;
  final String etichetta;
  final int minLines;
  final int maxLines;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Formattazione', style: Theme.of(context).textTheme.labelLarge),
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
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            labelText: etichetta,
            hintText: 'Puoi usare <b>, <i>, <small>, <big> e <br>.',
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  void _inserisciTag(String apertura, String chiusura) {
    final TextSelection selezione = controller.selection;
    final int inizio = selezione.isValid ? selezione.start : 0;
    final int fine = selezione.isValid ? selezione.end : inizio;
    final String testo = controller.text;
    final String selezionato = testo.substring(inizio, fine);
    final String inserimento = '$apertura$selezionato$chiusura';

    controller.value = TextEditingValue(
      text: testo.replaceRange(inizio, fine, inserimento),
      selection: TextSelection(
        baseOffset: inizio + apertura.length,
        extentOffset: inizio + apertura.length + selezionato.length,
      ),
    );
  }

  void _inserisciTesto(String inserimento) {
    final TextSelection selezione = controller.selection;
    final int posizione = selezione.isValid ? selezione.start : 0;
    final String testo = controller.text;
    controller.value = TextEditingValue(
      text: testo.replaceRange(posizione, posizione, inserimento),
      selection: TextSelection.collapsed(
        offset: posizione + inserimento.length,
      ),
    );
  }
}

/// Componente `TestoHtmlMinimo`: incapsula responsabilità specifiche del relativo modulo.
class TestoHtmlMinimo extends StatelessWidget {
  const TestoHtmlMinimo({super.key, required this.testo});

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
      if (valore.isEmpty) return;
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
          if (dimensioni.length > 1) dimensioni.removeLast();
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

/// Componente `PulsanteTag`: incapsula responsabilità specifiche del relativo modulo.
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

String _decodificaHtml(String valore) {
  return valore
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}
