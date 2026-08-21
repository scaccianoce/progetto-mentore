import 'dart:convert';

import 'package:flutter/material.dart';

import '../supabase_config.dart';
import 'maschera_dinamica_controller.dart';
import 'mentoraggi_ui_config.dart';


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
    final schema = await SupabaseConfig.caricaSchemaDatabase();
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

/// Visualizza i campi di una riga secondo SchemaDatabase e la configurazione
/// specifica della pagina.
class CampiTabellaDinamici extends StatelessWidget {
  const CampiTabellaDinamici({
    super.key,
    required this.configurazione,
    required this.valori,
    this.partecipante = false,
  });

  final ConfigurazionePaginaDinamica configurazione;
  final Map<String, dynamic> valori;
  final bool partecipante;

  @override
  Widget build(BuildContext context) => FutureBuilder<SchemaDatabase>(
    future: SupabaseConfig.caricaSchemaDatabase(),
    builder: (context, snapshot) {
      final tabella = ConfigurazioneMaschere.applica(
        snapshot.data?.tabella(configurazione.tabella) ??
            TabellaDatabase.daRiga(
              configurazione.tabella,
              valori,
            ),
        pagina: configurazione,
      );

      final campi = tabella.campi
          .where(
            (campo) =>
                campo.visibilePer(
                  partecipante: partecipante,
                ) &&
                valori.containsKey(campo.nome),
          )
          .toList();

      // ----------------------------------------------------------
      // PER TUTTE LE TABELLE DIVERSE DA mentoraggi
      // manteniamo il comportamento standard.
      // ----------------------------------------------------------

      if (configurazione.tabella != 'mentoraggi') {
        return Column(
          children: campi
              .map(
                (campo) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    campo.etichetta,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: _valoreDinamico(
                    campo,
                    valori[campo.nome],
                  ),
                ),
              )
              .toList(growable: false),
        );
      }

      // ----------------------------------------------------------
      // MENTORAGGI
      //
      // Ordiniamo prima per sezione e poi per ordine del campo.
      // ----------------------------------------------------------

      campi.sort((a, b) {
        final confrontoSezione =
            MentoraggiUiConfig
                .ordineSezione(a.nome)
                .compareTo(
                  MentoraggiUiConfig
                      .ordineSezione(b.nome),
                );

        if (confrontoSezione != 0) {
          return confrontoSezione;
        }

        final confrontoCampo =
            MentoraggiUiConfig
                .ordine(a.nome)
                .compareTo(
                  MentoraggiUiConfig
                      .ordine(b.nome),
                );

        if (confrontoCampo != 0) {
          return confrontoCampo;
        }

        return a.etichetta.compareTo(
          b.etichetta,
        );
      });

      final widgets = <Widget>[];

      String? sezionePrecedente;

      for (final campo in campi) {
        final sezione =
            MentoraggiUiConfig.sezione(
          campo.nome,
        );

        // --------------------------------------------------------
        // NUOVA SEZIONE
        // --------------------------------------------------------

        if (sezione != sezionePrecedente) {
          if (widgets.isNotEmpty) {
            widgets.add(
              const SizedBox(height: 16),
            );
          }

          widgets.add(
            Padding(
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 4,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  MentoraggiUiConfig
                      .titoloSezione(sezione),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            ),
          );

          widgets.add(
            const Divider(),
          );

          sezionePrecedente = sezione;
        }

        // --------------------------------------------------------
        // CAMPO
        // --------------------------------------------------------

        widgets.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              campo.etichetta,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: _valoreDinamico(
              campo,
              valori[campo.nome],
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: widgets,
      );
    },
  );
}


Widget _valoreDinamico(CampoDatabase campo, Object? valore) {
  // Per i campi testuali non eliminiamo gli a capo inseriti dall'utente.
  // Usiamo trim() solo per stabilire se il contenuto e vuoto, non per
  // costruire il testo visualizzato.
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

class _MascheraDinamicaState extends State<MascheraDinamica> {
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

  bool get _eMentoraggi =>
    widget.tabella.nome == 'mentoraggi';

  List<CampoDatabase> get _campiOrdinati {
    final campi = _campi.toList();

    if (!_eMentoraggi) {
      return campi;
    }

    campi.sort((a, b) {
      final confrontoSezione =
          MentoraggiUiConfig
              .ordineSezione(a.nome)
              .compareTo(
                MentoraggiUiConfig
                    .ordineSezione(b.nome),
              );

      if (confrontoSezione != 0) {
        return confrontoSezione;
      }

      final confrontoOrdine =
          MentoraggiUiConfig
              .ordine(a.nome)
              .compareTo(
                MentoraggiUiConfig
                    .ordine(b.nome),
              );

      if (confrontoOrdine != 0) {
        return confrontoOrdine;
      }

      // Per i campi senza ordine esplicito
      // manteniamo comunque un risultato stabile.
      return a.etichetta.compareTo(b.etichetta);
    });

    return campi;
  }

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
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
      FilledButton(onPressed: _salva, child: const Text('Salva')),
    ],
  );


  List<Widget> _costruisciCampi() {
    final campi = _campiOrdinati;

    if (!_eMentoraggi) {
      return campi
          .map(
            (campo) => Padding(
              padding: const EdgeInsets.only(
                bottom: 12,
              ),
              child: _costruisciCampo(campo),
            ),
          )
          .toList(growable: false);
    }

    final widgets = <Widget>[];

    String? sezionePrecedente;

    for (final campo in campi) {
      final sezione =
          MentoraggiUiConfig.sezione(campo.nome);

      if (sezione != sezionePrecedente) {
        if (widgets.isNotEmpty) {
          widgets.add(
            const SizedBox(height: 12),
          );
        }

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(
              top: 8,
              bottom: 6,
            ),
            child: Text(
              MentoraggiUiConfig
                  .titoloSezione(sezione),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        );

        widgets.add(
          const Divider(height: 12),
        );

        sezionePrecedente = sezione;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(
            bottom: 12,
          ),
          child: _costruisciCampo(campo),
        ),
      );
    }

    return widgets;
  }

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
      valore: _data(_valori[campo.nome]),
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

  Future<void> _caricaRelazione(CampoDatabase campo) async {
    final relazione = campo.relazione;
    if (relazione == null) return;
    _relazioniInCaricamento.add(campo.nome);

    try {
      // -------------------------------------------------------------------
      // ANAGRAFICA
      // Valore tecnico: user_id (o la colonna FK richiesta dallo schema).
      // Etichetta mostrata: email_unipa, che deve essere univoca.
      // -------------------------------------------------------------------
      if (relazione.tabella == 'anagrafica') {
        final List<dynamic> righe = await SupabaseConfig.client
            .from('anagrafica')
            .select('${relazione.colonna}, email_unipa, cognome, nome')
            .order('email_unipa')
            .limit(1000);

        _opzioniRelazione[campo.nome] = righe.map((riga) {
          final mappa = Map<String, dynamic>.from(riga as Map);
          final valore = mappa[relazione.colonna].toString();
          final email = mappa['email_unipa']?.toString().trim() ?? '';
          return _OpzioneRelazione(
            valore: valore,
            etichetta: email.isEmpty ? valore : email,
          );
        }).toList(growable: false);
        return;
      }

      // -------------------------------------------------------------------
      // INSEGNAMENTI
      // Valore tecnico: id (o colonna FK).
      // Etichetta mostrata: "insegnamento — email docente".
      // -------------------------------------------------------------------
      if (relazione.tabella == 'insegnamenti') {
        final List<dynamic> righe = await SupabaseConfig.client
            .from('insegnamenti')
            .select('${relazione.colonna}, insegnamento, docente_id')
            .limit(1000);

        final docenteIds = righe
            .map((r) => (r as Map)['docente_id']?.toString())
            .whereType<String>()
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList();

        final emailPerDocente = <String, String>{};
        if (docenteIds.isNotEmpty) {
          final List<dynamic> docenti = await SupabaseConfig.client
              .from('anagrafica')
              .select('user_id, email_unipa')
              .inFilter('user_id', docenteIds);
          for (final riga in docenti) {
            final mappa = Map<String, dynamic>.from(riga as Map);
            final id = mappa['user_id']?.toString();
            final email = mappa['email_unipa']?.toString().trim();
            if (id != null && email != null && email.isNotEmpty) {
              emailPerDocente[id] = email;
            }
          }
        }

        final opzioni = righe.map((riga) {
          final mappa = Map<String, dynamic>.from(riga as Map);
          final valore = mappa[relazione.colonna].toString();
          final nome = mappa['insegnamento']?.toString().trim() ?? '';
          final docenteId = mappa['docente_id']?.toString();
          final email = docenteId == null ? null : emailPerDocente[docenteId];
          final etichetta = [
            if (nome.isNotEmpty) nome,
            if (email != null && email.isNotEmpty) email,
          ].join(' — ');
          return _OpzioneRelazione(
            valore: valore,
            etichetta: etichetta.isEmpty ? valore : etichetta,
          );
        }).toList(growable: true)
          ..sort((a, b) => a.etichetta.toLowerCase().compareTo(
                b.etichetta.toLowerCase(),
              ));

        _opzioniRelazione[campo.nome] = opzioni;
        return;
      }

      // -------------------------------------------------------------------
      // Comportamento generico per tutte le altre relazioni.
      // -------------------------------------------------------------------
      final tabellaCollegata = SupabaseConfig.schemaDatabase?.tabella(
        relazione.tabella,
      );
      final campoEtichetta = _campoDescrittivo(
        tabellaCollegata,
        relazione.colonna,
      );
      final selezione = campoEtichetta == relazione.colonna
          ? relazione.colonna
          : '${relazione.colonna}, $campoEtichetta';
      final List<dynamic> righe = await SupabaseConfig.client
          .from(relazione.tabella)
          .select(selezione)
          .limit(500);
      _opzioniRelazione[campo.nome] = righe
          .map((riga) {
            final mappa = Map<String, dynamic>.from(riga as Map);
            final valore = mappa[relazione.colonna].toString();
            final descrizione = mappa[campoEtichetta]?.toString();
            return _OpzioneRelazione(
              valore: valore,
              etichetta: descrizione == null || descrizione.isEmpty
                  ? valore
                  : descrizione,
            );
          })
          .toList(growable: false);
    } catch (_) {
      _opzioniRelazione[campo.nome] = const [];
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
          Expanded(child: Text(_formattaData(valore, conOra: conOra))),
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

DateTime? _data(Object? valore) =>
    valore is DateTime ? valore : DateTime.tryParse(valore?.toString() ?? '');

String _formattaData(DateTime? data, {required bool conOra}) {
  if (data == null) return 'Nessuna data';
  final giorno = data.day.toString().padLeft(2, '0');
  final mese = data.month.toString().padLeft(2, '0');
  final base = '$giorno/$mese/${data.year}';
  if (!conOra) return base;
  final ora = data.hour.toString().padLeft(2, '0');
  final minuti = data.minute.toString().padLeft(2, '0');
  return '$base $ora:$minuti';
}

String _campoDescrittivo(TabellaDatabase? tabella, String chiave) =>
    tabella?.nomeCampoDescrittivo ?? chiave;

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
