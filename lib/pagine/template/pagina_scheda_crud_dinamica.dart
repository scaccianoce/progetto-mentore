import 'package:flutter/material.dart';

import '../../app_exception.dart';
import '../../dinamico/controller_crud_dinamico.dart';
import '../../dinamico/maschera_dinamica_controller.dart';
import '../../dinamico/maschera_dinamica_widget.dart';
import '../../dinamico/repository_dinamico.dart';
import 'pagina_scheda_dinamica.dart';

/// Pagina CRUD standard per una scheda singola.
///
/// Esempio minimo:
/// PaginaSchedaCrudDinamica(
///   titolo: 'Pubblicazione',
///   configurazione: ConfigurazionePaginaDinamica(tabella: 'pubblicazioni'),
///   filtri: [FiltroDinamico('user_id', userId)],
/// )
///
/// Tutto il CRUD standard resta qui. Una pagina specifica deve esistere solo
/// se aggiunge logica di dominio, liste collegate, permessi speciali o workflow.
class PaginaSchedaCrudDinamica extends StatefulWidget {
  const PaginaSchedaCrudDinamica({
    super.key,
    required this.titolo,
    required this.configurazione,
    required this.filtri,
    this.campoId = 'id',
    this.valoriNuovo = const <String, dynamic>{},
    this.partecipante = false,
    this.puoGestire = true,
    this.normalizzaValori,
    this.messaggioVuoto = 'Nessun dato disponibile.',
    this.titoloEditor,
    this.messaggioSalvato = 'Dati salvati.',
    this.primaDeiCampi = const <Widget>[],
    this.dopoICampi = const <Widget>[],
  });

  final String titolo;
  final ConfigurazionePaginaDinamica configurazione;
  final List<FiltroDinamico> filtri;
  final String campoId;
  final Map<String, dynamic> valoriNuovo;
  final bool partecipante;
  final bool puoGestire;
  final NormalizzaValoriDinamici? normalizzaValori;
  final String messaggioVuoto;
  final String? titoloEditor;
  final String messaggioSalvato;
  final List<Widget> primaDeiCampi;
  final List<Widget> dopoICampi;

  @override
  State<PaginaSchedaCrudDinamica> createState() =>
      _PaginaSchedaCrudDinamicaState();
}

class _PaginaSchedaCrudDinamicaState extends State<PaginaSchedaCrudDinamica> {
  late final ControllerSchedaCrudDinamico _controller;

  @override
  void initState() {
    super.initState();
    _controller = ControllerSchedaCrudDinamico(
      tabella: widget.configurazione.tabella,
      campoId: widget.campoId,
      puoGestire: widget.puoGestire,
      normalizzaValori: widget.normalizzaValori,
      messaggioErroreCaricamento:
          'Impossibile caricare ${widget.titolo.toLowerCase()}.',
      messaggioErroreSalvataggio:
          'Impossibile salvare ${widget.titolo.toLowerCase()}.',
    )..carica(filtri: widget.filtri);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => PaginaSchedaDinamica(
      titolo: widget.titolo,
      configurazione: widget.configurazione,
      valori: _controller.record,
      partecipante: widget.partecipante,
      caricamento: _controller.caricamento,
      errore: _controller.errore,
      vuoto: _controller.record == null,
      messaggioVuoto: widget.messaggioVuoto,
      primaDeiCampi: widget.primaDeiCampi,
      dopoICampi: widget.dopoICampi,
      azioni: <Widget>[
        if (widget.puoGestire)
          FilledButton.icon(
            onPressed: _controller.salvataggio ? null : _apriEditor,
            icon: Icon(
              _controller.record == null ? Icons.add : Icons.edit_outlined,
            ),
            label: Text(_controller.record == null ? 'Inserisci' : 'Modifica'),
          ),
      ],
    ),
  );

  Future<void> _apriEditor() async {
    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: widget.configurazione,
      valoriIniziali:
          _controller.record ?? Map<String, dynamic>.from(widget.valoriNuovo),
      partecipante: widget.partecipante,
      titolo: widget.titoloEditor ?? widget.titolo,
    );
    if (valori == null) return;
    try {
      await _controller.salva(valori);
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
}
