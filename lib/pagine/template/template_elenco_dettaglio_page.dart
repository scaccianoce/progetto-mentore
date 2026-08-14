import 'package:flutter/material.dart';

/// TEMPLATE 2 - ELENCO + DETTAGLIO
///
/// Usato per: News, Eventi, House of Mentore, Ruolo Mentore e Contatti.
///
/// Questo file gestisce solo il layout responsivo. Le differenze fra tabelle
/// vanno espresse tramite ConfigurazionePaginaDinamica e i componenti comuni
/// in componenti_pagina_dinamica.dart; la logica di dominio resta nei controller.
class TemplatePaginaElencoDettaglio extends StatelessWidget {
  const TemplatePaginaElencoDettaglio({
    super.key,
    required this.elenco,
    required this.dettaglio,
    this.intestazione,
    this.caricamento = false,
    this.errore,
    this.vuoto = false,
    this.messaggioVuoto = 'Nessun elemento disponibile.',
    this.larghezzaElenco = 360,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget elenco;
  final Widget dettaglio;
  final Widget? intestazione;
  final bool caricamento;
  final String? errore;
  final bool vuoto;
  final String messaggioVuoto;
  final double larghezzaElenco;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (caricamento) {
      return const Center(child: CircularProgressIndicator());
    }
    final contenuto = vuoto
        ? Center(child: Text(errore ?? messaggioVuoto))
        : LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 800) {
                return Row(
                  children: <Widget>[
                    SizedBox(width: larghezzaElenco, child: elenco),
                    const VerticalDivider(width: 24),
                    Expanded(child: dettaglio),
                  ],
                );
              }
              return Column(
                children: <Widget>[
                  Expanded(child: elenco),
                  const Divider(height: 20),
                  Expanded(child: dettaglio),
                ],
              );
            },
          );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (intestazione != null) ...<Widget>[
            intestazione!,
            const SizedBox(height: 12),
          ],
          if (errore != null && !vuoto) ...<Widget>[
            Text(
              errore!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(child: contenuto),
        ],
      ),
    );
  }
}
