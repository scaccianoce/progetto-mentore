import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_exception.dart';
import '../../supabase_config.dart';

class ContattiController extends ChangeNotifier {
  ContattiController({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  /// PROIEZIONE CONTATTI:
  /// a differenza del Profilo non usiamo select() sull'intera Anagrafica.
  /// Questa pagina e di consultazione e deve esporre soltanto dati di contatto.
  /// Per aggiungere un nuovo dato pubblico basta inserirlo qui: il dettaglio lo
  /// renderizzera automaticamente salvo eventuali eccezioni nella pagina.
  static const String colonnePubbliche =
      'user_id, nome, cognome, email_unipa, cod_ssd, dipartimento, ufficio, '
      'ruolo_accademico, cellulare, pagina_personale_unipa';

  final SupabaseClient _client;
  List<Map<String, dynamic>> _contatti = const <Map<String, dynamic>>[];
  Map<String, dynamic>? _selezionato;
  String _ricerca = '';
  bool _caricamento = false;
  String? _errore;

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

  Future<void> carica() async {
    _caricamento = true;
    _errore = null;
    notifyListeners();
    try {
      final List<dynamic> righe = await _client
          .from('anagrafica')
          .select(colonnePubbliche)
          .order('cognome', ascending: true)
          .order('nome', ascending: true);
      _contatti = righe.cast<Map<String, dynamic>>();
      if (_selezionato == null ||
          !_contatti.any(
            (contatto) => contatto['user_id'] == _selezionato?['user_id'],
          )) {
        _selezionato = _contatti.isEmpty ? null : _contatti.first;
      }
    } catch (errore) {
      _errore = AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile caricare i contatti.',
      ).messaggio;
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  void cerca(String valore) {
    _ricerca = valore.trim().toLowerCase();
    notifyListeners();
  }

  void seleziona(Map<String, dynamic> contatto) {
    _selezionato = contatto;
    notifyListeners();
  }
}
