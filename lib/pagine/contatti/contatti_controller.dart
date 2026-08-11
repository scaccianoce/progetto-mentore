import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_exception.dart';
import '../../supabase_config.dart';

class ContattiController extends ChangeNotifier {
  ContattiController({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;
  List<Map<String, dynamic>> _contatti = const <Map<String, dynamic>>[];
  Map<String, dynamic>? _selezionato;
  String _ricerca = '';
  bool _caricamento = false;
  String? _errore;

  List<Map<String, dynamic>> get contatti {
    if (_ricerca.isEmpty) {
      return _contatti;
    }
    return _contatti
        .where((Map<String, dynamic> contatto) {
          final String testo = <Object?>[
            contatto['cognome'],
            contatto['nome'],
            contatto['email_unipa'],
            contatto['cod_ssd'],
          ].join(' ').toLowerCase();
          return testo.contains(_ricerca);
        })
        .toList(growable: false);
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
          .select(
            'user_id, nome, cognome, email_unipa, cod_ssd, dipartimento, '
            'ufficio, ruolo_accademico, cellulare, pagina_personale_unipa',
          )
          .order('cognome')
          .order('nome');
      _contatti = righe.cast<Map<String, dynamic>>();
      _selezionato ??= _contatti.isEmpty ? null : _contatti.first;
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
