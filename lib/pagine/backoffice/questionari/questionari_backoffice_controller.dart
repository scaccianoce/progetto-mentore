import 'package:flutter/foundation.dart';

import '../../../app/app_core.dart';
import '../../../app/app_session_controller.dart';
import '../../../dati/repository.dart';

/// Controller del backoffice Questionari.
///
/// Amministra esclusivamente il catalogo dei template e delle domande.
/// Non gestisce la compilazione dei questionari e non utilizza repository
/// specifici: accede direttamente alle tabelle tramite [DatabaseRepository].
class QuestionariBackofficeController extends ChangeNotifier {
  QuestionariBackofficeController(
    this.sessione, {
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  final SessioneController sessione;
  final DatabaseRepository db;

  final List<Map<String, dynamic>> template = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> domande = <Map<String, dynamic>>[];

  bool caricamento = false;
  bool salvataggio = false;
  String? errore;

  bool get puoGestire => sessione.ruolo?.puoAmministrare ?? false;

  /// Carica template e relative domande.
  Future<void> carica() async {
    caricamento = true;
    errore = null;
    notifyListeners();

    try {
      final risultati = await Future.wait<List<Map<String, dynamic>>>([
        db.tabella('questionari_template').elenco(
          ordinamenti: const <OrdineDb>[
            OrdineDb('destinatario'),
            OrdineDb('titolo'),
          ],
        ),
        db.tabella('questionari_domande').elenco(
          ordinamenti: const <OrdineDb>[
            OrdineDb('template_id'),
            OrdineDb('ordine'),
          ],
        ),
      ]);

      template
        ..clear()
        ..addAll(risultati[0]);

      domande
        ..clear()
        ..addAll(risultati[1]);
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile caricare i template dei questionari.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> domandeTemplate(String templateId) => domande
      .where(
        (riga) => riga['template_id']?.toString() == templateId,
      )
      .toList(growable: false);

  Future<String?> salvaTemplate({
    String? id,
    required String titolo,
    required String destinatario,
    String? descrizione,
    bool attivo = true,
  }) =>
      _esegui(
        messaggio: 'Salvataggio del template non riuscito.',
        azione: () async {
          _verificaGestore();

          final titoloPulito = titolo.trim();
          if (titoloPulito.isEmpty) {
            throw const AppException('Titolo obbligatorio.');
          }

          final dati = <String, dynamic>{
            'titolo': titoloPulito,
            'destinatario': destinatario,
            'descrizione':
                descrizione == null || descrizione.trim().isEmpty
                    ? null
                    : descrizione.trim(),
            'attivo': attivo,
          };

          final tabella = db.tabella('questionari_template');

          if (id == null) {
            dati['created_by'] = db.userIdCorrente;
            await tabella.inserisci(dati, colonne: 'id');
          } else {
            await tabella.aggiorna(
              dati,
              filtri: <FiltroDb>[
                FiltroDb.uguale('id', id),
              ],
              colonne: 'id',
            );
          }
        },
      );

  Future<String?> aggiungiDomanda({
    required String templateId,
    required int ordine,
    required String testo,
    required String tipo,
    required bool obbligatoria,
    Object? opzioni,
  }) =>
      _esegui(
        messaggio: 'Inserimento della domanda non riuscito.',
        azione: () async {
          _verificaGestore();

          final testoPulito = testo.trim();
          if (testoPulito.isEmpty) {
            throw const AppException(
              'Testo della domanda obbligatorio.',
            );
          }

          await db.tabella('questionari_domande').inserisci(
            <String, dynamic>{
              'template_id': templateId,
              'ordine': ordine,
              'testo': testoPulito,
              'tipo': tipo,
              'obbligatoria': obbligatoria,
              'opzioni': opzioni,
            },
            colonne: 'id',
          );
        },
      );

  Future<String?> eliminaDomanda(String domandaId) =>
      _esegui(
        messaggio: 'Eliminazione della domanda non riuscita.',
        azione: () async {
          _verificaGestore();

          await db.tabella('questionari_domande').elimina(
            filtri: <FiltroDb>[
              FiltroDb.uguale('id', domandaId),
            ],
          );
        },
      );

  /// Scambia l'ordine della domanda con quella precedente o successiva.
  Future<String?> spostaDomanda({
    required String templateId,
    required String domandaId,
    required bool versoAlto,
  }) =>
      _esegui(
        messaggio: 'Riordinamento delle domande non riuscito.',
        azione: () async {
          _verificaGestore();

          final tabella = db.tabella('questionari_domande');
          final elenco = await tabella.elenco(
            colonne: 'id, ordine',
            filtri: <FiltroDb>[
              FiltroDb.uguale('template_id', templateId),
            ],
            ordinamenti: const <OrdineDb>[
              OrdineDb('ordine'),
            ],
          );

          final indice = elenco.indexWhere(
            (riga) => riga['id']?.toString() == domandaId,
          );

          if (indice < 0) {
            throw const AppException('Domanda non trovata.');
          }

          final destinazione =
              versoAlto ? indice - 1 : indice + 1;

          if (destinazione < 0 || destinazione >= elenco.length) {
            return;
          }

          final corrente = elenco[indice];
          final altra = elenco[destinazione];

          final ordineCorrente =
              int.tryParse(corrente['ordine']?.toString() ?? '');
          final ordineAltra =
              int.tryParse(altra['ordine']?.toString() ?? '');

          if (ordineCorrente == null || ordineAltra == null) {
            throw const AppException(
              'Impossibile determinare l’ordine delle domande.',
            );
          }

          final ordineTemporaneo = elenco
                  .map(
                    (riga) =>
                        int.tryParse(riga['ordine']?.toString() ?? '') ??
                        0,
                  )
                  .reduce((a, b) => a < b ? a : b) -
              1000;

          await _aggiornaOrdine(
            domandaId,
            ordineTemporaneo,
          );

          try {
            await _aggiornaOrdine(
              altra['id'].toString(),
              ordineCorrente,
            );
            await _aggiornaOrdine(
              domandaId,
              ordineAltra,
            );
          } catch (_) {
            await _aggiornaOrdine(
              altra['id'].toString(),
              ordineAltra,
            );
            await _aggiornaOrdine(
              domandaId,
              ordineCorrente,
            );
            rethrow;
          }
        },
      );

  Future<void> _aggiornaOrdine(
    String domandaId,
    int ordine,
  ) {
    return db.tabella('questionari_domande').aggiorna(
      <String, dynamic>{'ordine': ordine},
      filtri: <FiltroDb>[
        FiltroDb.uguale('id', domandaId),
      ],
      colonne: 'id',
    );
  }

  Future<String?> _esegui({
    required Future<void> Function() azione,
    required String messaggio,
  }) async {
    salvataggio = true;
    notifyListeners();

    try {
      await azione();
      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: messaggio,
      ).messaggio;
    } finally {
      salvataggio = false;
      notifyListeners();
    }
  }

  void _verificaGestore() {
    if (!puoGestire) {
      throw const AppException('Operazione non autorizzata.');
    }
  }
}
