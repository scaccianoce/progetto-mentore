import 'package:flutter/foundation.dart';

import '../../app/app_core.dart';
import '../../dati/repository.dart';
import '../../ui/dinamico_schema.dart';

/// Controller della pagina Contatti.
///
/// Carica esclusivamente i dati pubblici necessari alla consultazione.
/// La tabella utilizzata e' `anagrafica`; non esiste un repository specifico
/// per la pagina Contatti.
class ContattiController extends ChangeNotifier {
  ContattiController({
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  /// Proiezione pubblica della tabella `anagrafica`.
  ///
  /// Per aggiungere un nuovo dato pubblico alla pagina e' sufficiente
  /// inserirlo qui e configurarne la visualizzazione nella page.
  static const String colonnePubbliche =
      'user_id, nome, cognome, email_unipa, cod_ssd, dipartimento, ufficio, '
      'ruolo_accademico, cellulare, pagina_personale_unipa';

  final DatabaseRepository db;

  List<Map<String, dynamic>> _contatti = const <Map<String, dynamic>>[];
  Map<String, dynamic>? _selezionato;
  String _ricerca = '';
  bool _caricamento = false;
  String? _errore;

  /// Restituisce i contatti filtrati dalla ricerca corrente.
  List<Map<String, dynamic>> get contatti {
    if (_ricerca.isEmpty) return _contatti;

    return _contatti.where((contatto) {
      final testo = <Object?>[
        contatto['cognome'],
        contatto['nome'],
        contatto['email_unipa'],
        contatto['cod_ssd'],
      ].join(' ').toLowerCase();

      return testo.contains(_ricerca);
    }).toList(growable: false);
  }

  Map<String, dynamic>? get selezionato => _selezionato;
  bool get caricamento => _caricamento;
  String? get errore => _errore;

  /// Carica lo schema DB necessario alla visualizzazione dinamica dei campi.
  Future<SchemaDatabase> caricaSchemaDatabase() =>
      SchemaDatabase.carica(database: db);

  /// Carica i contatti pubblici dalla tabella `anagrafica`.
  Future<void> carica() async {
    _caricamento = true;
    _errore = null;
    notifyListeners();

    try {
      _contatti = await db.tabella('anagrafica').elenco(
        colonne: colonnePubbliche,
        ordinamenti: const <OrdineDb>[
          OrdineDb('cognome'),
          OrdineDb('nome'),
        ],
      );

      if (_selezionato == null ||
          !_contatti.any(
            (contatto) =>
                contatto['user_id']?.toString() ==
                _selezionato?['user_id']?.toString(),
          )) {
        _selezionato = _contatti.isEmpty ? null : _contatti.first;
      }
    } catch (e) {
      _errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile caricare i contatti.',
      ).messaggio;
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  /// Aggiorna il filtro di ricerca applicato all'elenco.
  void cerca(String valore) {
    _ricerca = valore.trim().toLowerCase();
    notifyListeners();
  }

  /// Aggiorna il contatto selezionato.
  void seleziona(Map<String, dynamic> contatto) {
    _selezionato = contatto;
    notifyListeners();
  }
}
