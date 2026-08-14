import 'package:flutter/material.dart';

/// TEMPLATE 1 - SCHEDA SINGOLA
///
/// Usato per: Profilo, Insegnamento, Ruolo Mentee e per future pagine che
/// rappresentano un singolo record.
///
/// NON personalizzare questo file per una tabella specifica: titolo, azioni,
/// campi visibili/modificabili e tipi speciali vanno dichiarati nella pagina
/// tramite ConfigurazionePaginaDinamica. Il template deve restare generico.
class TemplatePaginaScheda extends StatelessWidget {
  const TemplatePaginaScheda({
    super.key,
    required this.titolo,
    required this.contenuto,
    this.azioni = const <Widget>[],
    this.caricamento = false,
    this.errore,
    this.vuoto = false,
    this.messaggioVuoto = 'Nessun dato disponibile.',
    this.larghezzaMassima = 900,
  });

  final String titolo;
  final Widget contenuto;
  final List<Widget> azioni;
  final bool caricamento;
  final String? errore;
  final bool vuoto;
  final String messaggioVuoto;
  final double larghezzaMassima;

  @override
  Widget build(BuildContext context) {
    if (caricamento) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: larghezzaMassima),
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
                          titolo,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      ...azioni,
                    ],
                  ),
                  if (errore != null && !vuoto) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      errore!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const Divider(height: 32),
                  if (vuoto)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(errore ?? messaggioVuoto),
                    )
                  else
                    contenuto,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
