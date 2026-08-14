import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prog_mentore/dinamico/maschera_dinamica_controller.dart';
import 'package:prog_mentore/dinamico/maschera_dinamica_widget.dart';
import 'package:prog_mentore/pagine/template/template_elenco_dettaglio_page.dart';

void main() {
  testWidgets('mantiene intestazione e azioni quando l’elenco è vuoto', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TemplatePaginaElencoDettaglio(
            vuoto: true,
            messaggioVuoto: 'Nessun elemento',
            intestazione: Text('Nuovo elemento'),
            elenco: SizedBox.shrink(),
            dettaglio: SizedBox.shrink(),
          ),
        ),
      ),
    );

    expect(find.text('Nuovo elemento'), findsOneWidget);
    expect(find.text('Nessun elemento'), findsOneWidget);
  });

  testWidgets('maschera partecipante mostra solo i campi modificabili', (
    tester,
  ) async {
    final tabella = ConfigurazioneMaschere.applica(
      TabellaDatabase.daRiga('profilo', <String, dynamic>{
        'nome': 'Ada',
        'email': 'ada@example.test',
        'note_interne': 'riservato',
      }),
      pagina: const ConfigurazionePaginaDinamica(
        tabella: 'profilo',
        campi: <String, PersonalizzazioneCampo>{
          'email': PersonalizzazioneCampo(modificabilePartecipante: false),
          'note_interne': PersonalizzazioneCampo(visibilePartecipante: false),
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MascheraDinamica(
            tabella: tabella,
            valoriIniziali: const <String, dynamic>{
              'nome': 'Ada',
              'email': 'ada@example.test',
              'note_interne': 'riservato',
            },
            partecipante: true,
          ),
        ),
      ),
    );

    expect(find.text('Nome'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    expect(find.text('Note interne'), findsNothing);
  });
}
