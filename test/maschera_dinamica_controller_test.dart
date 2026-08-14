import 'package:flutter_test/flutter_test.dart';
import 'package:prog_mentore/dinamico/maschera_dinamica_controller.dart';

void main() {
  test('interpreta tipi, enum, relazioni e direttive UI', () {
    final schema = SchemaDatabase.fromJson({
      'tables': [
        {
          'name': 'articoli',
          'primary_key': ['id'],
          'columns': [
            {
              'name': 'id',
              'position': 1,
              'data_type': 'bigint',
              'nullable': false,
              'identity': true,
            },
            {
              'name': 'contenuto',
              'position': 2,
              'data_type': 'text',
              'nullable': false,
              'comment': '@app:label=Testo articolo @app:formatted',
            },
            {
              'name': 'stato',
              'position': 3,
              'data_type': 'stato_articolo',
              'nullable': false,
              'enum_values': ['bozza', 'pubblicato'],
            },
            {
              'name': 'autore_id',
              'position': 4,
              'data_type': 'uuid',
              'nullable': true,
              'foreign_key': {'table': 'utenti', 'column': 'id'},
            },
          ],
        },
      ],
    });

    final tabella = schema.tabella('articoli')!;
    expect(tabella.campo('id')!.chiavePrimaria, isTrue);
    expect(tabella.campo('id')!.modificabile, isFalse);
    expect(tabella.campo('contenuto')!.tipo, TipoCampoDinamico.testoFormattato);
    expect(tabella.campo('contenuto')!.etichetta, 'Testo articolo');
    expect(tabella.campo('stato')!.tipo, TipoCampoDinamico.scelta);
    expect(tabella.campo('autore_id')!.tipo, TipoCampoDinamico.relazione);
    expect(tabella.campo('autore_id')!.relazione!.tabella, 'utenti');
  });

  test('crea una definizione provvisoria da una riga', () {
    final tabella = TabellaDatabase.daRiga('prova', {
      'id': 1,
      'attivo': true,
      'data_inizio': '2026-08-12',
      'note': 'testo',
    });

    expect(tabella.campo('id')!.tipo, TipoCampoDinamico.numeroIntero);
    expect(tabella.campo('attivo')!.tipo, TipoCampoDinamico.booleano);
    expect(tabella.campo('data_inizio')!.tipo, TipoCampoDinamico.data);
  });

  test('applica visibilità e modifica specifiche per il partecipante', () {
    final tabella = TabellaDatabase.daRiga('profili', <String, dynamic>{
      'nome': 'Ada',
      'email': 'ada@example.test',
      'note_interne': 'riservato',
    });
    const pagina = ConfigurazionePaginaDinamica(
      tabella: 'profili',
      campi: <String, PersonalizzazioneCampo>{
        'email': PersonalizzazioneCampo(modificabilePartecipante: false),
        'note_interne': PersonalizzazioneCampo(visibilePartecipante: false),
      },
    );

    final configurata = ConfigurazioneMaschere.applica(tabella, pagina: pagina);
    final nome = configurata.campo('nome')!;
    final email = configurata.campo('email')!;
    final note = configurata.campo('note_interne')!;

    expect(nome.visibilePer(partecipante: true), isTrue);
    expect(nome.modificabilePer(partecipante: true), isTrue);
    expect(email.visibilePer(partecipante: true), isTrue);
    expect(email.modificabilePer(partecipante: true), isFalse);
    expect(note.visibilePer(partecipante: true), isFalse);
    expect(note.modificabilePer(partecipante: true), isFalse);
    expect(note.visibilePer(partecipante: false), isTrue);
    expect(note.modificabilePer(partecipante: false), isTrue);
  });
}
