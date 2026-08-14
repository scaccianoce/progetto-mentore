import 'package:flutter/material.dart';

import '../../app_exception.dart';
import '../../dinamico/controller_crud_dinamico.dart';
import '../../dinamico/maschera_dinamica_controller.dart';
import '../../dinamico/maschera_dinamica_widget.dart';
import '../../dinamico/repository_dinamico.dart';
import 'componenti_pagina_dinamica.dart';
import 'template_elenco_dettaglio_page.dart';

typedef TestoRecordDinamico = String Function(Map<String, dynamic> record);
typedef WidgetRecordDinamico = Widget? Function(Map<String, dynamic> record);

/// Pagina CRUD standard elenco + dettaglio.
///
/// Per una nuova pagina ordinaria sono normalmente sufficienti:
/// - titolo;
/// - ConfigurazionePaginaDinamica(tabella: ...);
/// - campo usato come titolo nell'elenco;
/// - eventuali filtri/ordinamenti/eccezioni.
///
/// Eventi, House of Mentore e altri workflow complessi NON devono essere
/// forzati dentro questo widget: mantengono i loro controller specifici.
class PaginaElencoDettaglioCrudDinamica extends StatefulWidget {
  const PaginaElencoDettaglioCrudDinamica({
    super.key,
    required this.titolo,
    required this.configurazione,
    required this.campoTitolo,
    this.campoId = 'id',
    this.campoSottotitolo,
    this.formattaSottotitolo,
    this.trailing,
    this.valoriNuovo = const <String, dynamic>{},
    this.filtri = const <FiltroDinamico>[],
    this.ordinamenti = const <OrdinamentoDinamico>[],
    this.partecipante = false,
    this.puoGestire = false,
    this.normalizzaValori,
    this.messaggioVuoto = 'Nessun elemento disponibile.',
    this.etichettaNuovo = 'Nuovo',
    this.titoloNuovo,
    this.titoloModifica,
    this.messaggioSalvato = 'Dato salvato.',
    this.messaggioEliminato = 'Dato eliminato.',
    this.larghezzaElenco = 360,
  });

  final String titolo;
  final ConfigurazionePaginaDinamica configurazione;
  final String campoTitolo;
  final String campoId;
  final String? campoSottotitolo;
  final TestoRecordDinamico? formattaSottotitolo;
  final WidgetRecordDinamico? trailing;
  final Map<String, dynamic> valoriNuovo;
  final List<FiltroDinamico> filtri;
  final List<OrdinamentoDinamico> ordinamenti;
  final bool partecipante;
  final bool puoGestire;
  final NormalizzaValoriDinamici? normalizzaValori;
  final String messaggioVuoto;
  final String etichettaNuovo;
  final String? titoloNuovo;
  final String? titoloModifica;
  final String messaggioSalvato;
  final String messaggioEliminato;
  final double larghezzaElenco;

  @override
  State<PaginaElencoDettaglioCrudDinamica> createState() =>
      _PaginaElencoDettaglioCrudDinamicaState();
}

class _PaginaElencoDettaglioCrudDinamicaState
    extends State<PaginaElencoDettaglioCrudDinamica> {
  late final ControllerElencoCrudDinamico _controller;

  @override
  void initState() {
    super.initState();
    _controller = ControllerElencoCrudDinamico(
      tabella: widget.configurazione.tabella,
      campoId: widget.campoId,
      filtri: widget.filtri,
      ordinamenti: widget.ordinamenti,
      puoGestire: widget.puoGestire,
      normalizzaValori: widget.normalizzaValori,
      messaggioErroreCaricamento:
          'Impossibile caricare ${widget.titolo.toLowerCase()}.',
      messaggioErroreSalvataggio:
          'Impossibile salvare ${widget.titolo.toLowerCase()}.',
      messaggioErroreEliminazione:
          'Impossibile eliminare ${widget.titolo.toLowerCase()}.',
    )..carica();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => TemplatePaginaElencoDettaglio(
      caricamento: _controller.caricamento && _controller.record.isEmpty,
      errore: _controller.errore,
      vuoto: _controller.record.isEmpty,
      messaggioVuoto: widget.messaggioVuoto,
      larghezzaElenco: widget.larghezzaElenco,
      intestazione: IntestazionePaginaDinamica(
        titolo: widget.titolo,
        onAggiorna: _controller.caricamento ? null : _controller.carica,
        onNuovo: widget.puoGestire && !_controller.caricamento
            ? () => _apriEditor()
            : null,
        etichettaNuovo: widget.etichettaNuovo,
      ),
      elenco: ElencoRecordDinamico<Map<String, dynamic>>(
        elementi: _controller.record,
        idSelezionato: _controller.selezionato?[widget.campoId]?.toString(),
        id: (record) => record[widget.campoId]?.toString() ?? '',
        titolo: (record) => record[widget.campoTitolo]?.toString() ?? '—',
        sottotitolo: widget.formattaSottotitolo ??
            (widget.campoSottotitolo == null
                ? null
                : (record) =>
                      record[widget.campoSottotitolo]?.toString() ?? ''),
        trailing: widget.trailing,
        onSeleziona: _controller.seleziona,
      ),
      dettaglio: _dettaglio(),
    ),
  );

  Widget _dettaglio() {
    final record = _controller.selezionato;
    if (record == null) {
      return Center(child: Text('Seleziona ${widget.titolo.toLowerCase()}.'));
    }

    return Card(
      margin: EdgeInsets.zero,
      child: DettaglioRecordDinamico(
        configurazione: widget.configurazione,
        valori: record,
        partecipante: widget.partecipante,
        prima: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.titolo,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (widget.puoGestire) ...<Widget>[
                IconButton(
                  tooltip: 'Modifica',
                  onPressed: _controller.salvataggio
                      ? null
                      : () => _apriEditor(esistente: record),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Elimina',
                  onPressed: _controller.salvataggio
                      ? null
                      : () => _confermaEliminazione(record),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
          const Divider(height: 32),
        ],
      ),
    );
  }

  Future<void> _apriEditor({Map<String, dynamic>? esistente}) async {
    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: widget.configurazione,
      partecipante: widget.partecipante,
      valoriIniziali: esistente ?? Map<String, dynamic>.from(widget.valoriNuovo),
      titolo: esistente == null
          ? (widget.titoloNuovo ?? 'Nuovo ${widget.titolo}')
          : (widget.titoloModifica ?? 'Modifica ${widget.titolo}'),
    );
    if (valori == null) return;
    try {
      await _controller.salva(esistente: esistente, valori: valori);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.messaggioSalvato)),
      );
    } on AppException catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errore.messaggio)),
      );
    }
  }

  Future<void> _confermaEliminazione(Map<String, dynamic> record) async {
    final titoloRecord = record[widget.campoTitolo]?.toString() ?? '';
    final confermata = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminare ${widget.titolo.toLowerCase()}?'),
        content: Text(
          titoloRecord.isEmpty
              ? 'Il record verra eliminato.'
              : '“$titoloRecord” verra eliminato.',
        ),
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
      await _controller.elimina(record);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.messaggioEliminato)),
      );
    } on AppException catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errore.messaggio)),
      );
    }
  }
}
