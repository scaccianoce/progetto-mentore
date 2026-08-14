import 'package:flutter/material.dart';

import '../../dinamico/maschera_dinamica_controller.dart';
import '../../dinamico/maschera_dinamica_widget.dart';
import 'template_scheda_page.dart';

/// Livello di composizione sopra [TemplatePaginaScheda].
///
/// Il template decide il layout; questa classe collega automaticamente un
/// record Map alla configurazione dinamica. Una nuova scheda standard dovrebbe
/// normalmente usare questo widget e dichiarare soltanto tabella, titolo ed
/// eventuali eccezioni di campo.
class PaginaSchedaDinamica extends StatelessWidget {
  const PaginaSchedaDinamica({
    super.key,
    required this.titolo,
    required this.configurazione,
    required this.valori,
    this.partecipante = false,
    this.azioni = const <Widget>[],
    this.primaDeiCampi = const <Widget>[],
    this.dopoICampi = const <Widget>[],
    this.caricamento = false,
    this.errore,
    this.vuoto,
    this.messaggioVuoto = 'Nessun dato disponibile.',
    this.larghezzaMassima = 900,
  });

  final String titolo;
  final ConfigurazionePaginaDinamica configurazione;
  final Map<String, dynamic>? valori;
  final bool partecipante;
  final List<Widget> azioni;
  final List<Widget> primaDeiCampi;
  final List<Widget> dopoICampi;
  final bool caricamento;
  final String? errore;
  final bool? vuoto;
  final String messaggioVuoto;
  final double larghezzaMassima;

  @override
  Widget build(BuildContext context) {
    final record = valori;
    final nessunRecord = vuoto ?? record == null;

    return TemplatePaginaScheda(
      titolo: titolo,
      caricamento: caricamento,
      errore: errore,
      vuoto: nessunRecord,
      messaggioVuoto: messaggioVuoto,
      larghezzaMassima: larghezzaMassima,
      azioni: azioni,
      contenuto: record == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ...primaDeiCampi,
                CampiTabellaDinamici(
                  configurazione: configurazione,
                  valori: record,
                  partecipante: partecipante,
                ),
                ...dopoICampi,
              ],
            ),
    );
  }
}
