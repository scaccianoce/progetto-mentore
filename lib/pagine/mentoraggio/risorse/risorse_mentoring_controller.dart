
import 'package:flutter/foundation.dart';

import '../../../app/app_core.dart';
import '../../../app/app_session_controller.dart';
import '../../../dati/repository.dart';
import '../../../supporto/utilita.dart';

/// Controller della pagina Risorse per il mentoring.
///
/// Coordina metadati DB e file Storage senza un repository specifico.
/// Le tabelle sono indicate direttamente dal controller; lo Storage e'
/// utilizzato tramite le primitive generiche di [DatabaseRepository].
class RisorseMentoringController extends ChangeNotifier {
  RisorseMentoringController(
    this.sessione, {
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  static const String bucket = 'risorse-mentoring';
  static const int dimensioneMassima = 20 * 1024 * 1024;

  static const List<String> categorie = <String>[
    'Materiale di presentazione',
    "Materiale per l'attività di mentoraggio",
    'Materiale burocratico/amministrativo',
    'Altro',
  ];

  final SessioneController sessione;
  final DatabaseRepository db;

  final List<Map<String, dynamic>> risorse = <Map<String, dynamic>>[];
  final List<String> anniAccademici = <String>[];

  bool caricamento = false;
  bool salvataggio = false;
  String? errore;

  bool get puoGestire => sessione.ruolo?.puoAmministrare ?? false;

  /// Carica risorse attive e anni accademici.
  Future<void> carica() async {
    caricamento = true;
    errore = null;
    notifyListeners();

    try {
      final risultati = await Future.wait<List<Map<String, dynamic>>>([
        db.tabella('risorse_mentoring').elenco(
          filtri: const <FiltroDb>[
            FiltroDb.uguale('attivo', true),
          ],
          ordinamenti: const <OrdineDb>[
            OrdineDb('categoria'),
            OrdineDb('ordine'),
            OrdineDb('titolo'),
          ],
        ),
        db.tabella('anni_accademici').elenco(
          colonne: 'codice',
          ordinamenti: const <OrdineDb>[
            OrdineDb('codice', crescente: false),
          ],
        ),
      ]);

      risorse
        ..clear()
        ..addAll(risultati[0]);

      anniAccademici
        ..clear()
        ..addAll(
          risultati[1]
              .map((riga) => riga['codice']?.toString() ?? '')
              .where((codice) => codice.isNotEmpty),
        );
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile caricare le risorse per il mentoring.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> perCategoria(String categoria) =>
      risorse
          .where((riga) => riga['categoria']?.toString() == categoria)
          .toList(growable: false);

  /// Carica il file nel bucket privato e crea il record dei metadati.
  Future<String?> caricaRisorsa({
    required Uint8List bytes,
    required String nomeFile,
    required String titolo,
    required String categoria,
    String? descrizione,
    String? annoAccademico,
  }) async {
    salvataggio = true;
    notifyListeners();

    String? percorsoCaricato;

    try {
      if (!puoGestire) {
        throw const AppException('Operazione non autorizzata.');
      }

      final titoloPulito = titolo.trim();
      if (titoloPulito.isEmpty) {
        throw const AppException('Titolo obbligatorio.');
      }

      if (!categorie.contains(categoria)) {
        throw const AppException('Categoria non valida.');
      }

      if (bytes.lengthInBytes > dimensioneMassima) {
        throw const AppException(
          'Il file supera il limite massimo di 20 MB.',
        );
      }

      final userId = db.userIdCorrente;
      if (userId == null) {
        throw const AppException('Sessione non valida.');
      }

      final nomeSicuro = nomeFileSicuro(nomeFile);
      final categoriaSicura = nomeFileSicuro(
        categoria,
        consentiPunto: false,
      );
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final percorso =
          '$categoriaSicura/$timestamp-$userId-$nomeSicuro';

      await db.caricaFileStorage(
        bucket: bucket,
        percorso: percorso,
        bytes: bytes,
        sovrascrivi: false,
      );
      percorsoCaricato = percorso;

      try {
        await db.tabella('risorse_mentoring').inserisci(
          <String, dynamic>{
            'titolo': titoloPulito,
            'descrizione': _testoNull(descrizione),
            'categoria': categoria,
            'anno_accademico': _testoNull(annoAccademico),
            'storage_path': percorso,
            'nome_file': nomeFile,
            'dimensione_bytes': bytes.lengthInBytes,
            'uploaded_by': userId,
            'attivo': true,
          },
          colonne: 'id',
        );
      } catch (_) {
        try {
          await db.rimuoviFileStorage(
            bucket: bucket,
            percorsi: <String>[percorso],
          );
        } catch (_) {
          // Pulizia best effort: non maschera l'errore DB originario.
        }
        rethrow;
      }

      await carica();
      return null;
    } catch (e) {
      // Se l'errore avviene dopo l'upload ma prima della registrazione, prova
      // comunque a rimuovere il file eventualmente rimasto orfano.
      if (percorsoCaricato != null) {
        final registrata = risorse.any(
          (riga) => riga['storage_path']?.toString() == percorsoCaricato,
        );
        if (!registrata) {
          try {
            await db.rimuoviFileStorage(
              bucket: bucket,
              percorsi: <String>[percorsoCaricato],
            );
          } catch (_) {}
        }
      }

      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile caricare la risorsa.',
      ).messaggio;
    } finally {
      salvataggio = false;
      notifyListeners();
    }
  }

  /// Crea un URL firmato temporaneo per aprire o scaricare il file.
  Future<Uri> urlDownload(Map<String, dynamic> risorsa) async {
    final percorso = risorsa['storage_path']?.toString() ?? '';
    if (percorso.isEmpty) {
      throw const AppException(
        'Percorso del file non disponibile.',
      );
    }

    final url = await db.creaUrlFirmato(
      bucket: bucket,
      percorso: percorso,
      durata: const Duration(minutes: 30),
    );

    return Uri.parse(url);
  }

  /// Elimina prima il record e poi il file associato.
  ///
  /// Se la pulizia Storage fallisce il record rimane comunque eliminato;
  /// l'errore di cleanup non deve ripristinare dati gia' rimossi dal DB.
  Future<String?> elimina(Map<String, dynamic> risorsa) async {
    salvataggio = true;
    notifyListeners();

    try {
      if (!puoGestire) {
        throw const AppException('Operazione non autorizzata.');
      }

      final id = risorsa['id']?.toString() ?? '';
      final percorso = risorsa['storage_path']?.toString();

      if (id.isEmpty) {
        throw const AppException('Risorsa non valida.');
      }

      await db.tabella('risorse_mentoring').elimina(
        filtri: <FiltroDb>[
          FiltroDb.uguale('id', id),
        ],
      );

      if (percorso != null && percorso.isNotEmpty) {
        try {
          await db.rimuoviFileStorage(
            bucket: bucket,
            percorsi: <String>[percorso],
          );
        } catch (e) {
          debugPrint(
            'Pulizia file Storage non riuscita per $percorso: $e',
          );
        }
      }

      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile eliminare la risorsa.',
      ).messaggio;
    } finally {
      salvataggio = false;
      notifyListeners();
    }
  }
}

String? _testoNull(Object? valore) {
  final testo = valore?.toString().trim() ?? '';
  return testo.isEmpty ? null : testo;
}
