import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_exception.dart';
import '../../sessione_controller.dart';
import '../../supabase_config.dart';

class InsegnamentoController extends ChangeNotifier {
  InsegnamentoController({required this.sessione, SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  static const String colonne =
      'id, docente_id, insegnamento, semestre, cfu, ore, cds, '
      'anno_erogazione, data_inizio, data_fine, anno_accademico, '
      'numero_studenti, sede, note, svolgimento, giorni_orari_lezioni, '
      'gia_mentorato, created_at';

  final SessioneController sessione;
  final SupabaseClient _client;
  Map<String, dynamic>? _insegnamento;
  String? _annoCorrente;
  bool _puoModificare = false;
  bool _caricamento = false;
  bool _salvataggio = false;
  String? _errore;

  Map<String, dynamic>? get insegnamento => _insegnamento;
  String? get annoCorrente => _annoCorrente;
  bool get puoModificare => _puoModificare;
  bool get caricamento => _caricamento;
  bool get salvataggio => _salvataggio;
  String? get errore => _errore;

  Future<void> carica() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      _errore = 'Sessione assente.';
      notifyListeners();
      return;
    }
    _caricamento = true;
    _errore = null;
    notifyListeners();
    try {
      final Map<String, dynamic>? anno = await _client
          .from('anni_accademici')
          .select('codice')
          .eq('corrente', true)
          .maybeSingle();
      _annoCorrente = anno?['codice']?.toString();
      if (_annoCorrente == null) {
        throw const AppException('Nessun anno accademico corrente impostato.');
      }
      _insegnamento = await _client
          .from('insegnamenti')
          .select(colonne)
          .eq('docente_id', userId)
          .eq('anno_accademico', _annoCorrente!)
          .maybeSingle();
      // Ogni partecipante può mantenere aggiornato il proprio insegnamento.
      // Nome e semestre vengono bloccati nell'interfaccia quando il record esiste.
      _puoModificare = true;
    } catch (errore) {
      _errore = AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile caricare l’insegnamento.',
      ).messaggio;
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  Future<void> salva(Map<String, dynamic> valori) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null || _annoCorrente == null || !_puoModificare) {
      throw const AppException('Modifica dell’insegnamento non autorizzata.');
    }
    _salvataggio = true;
    notifyListeners();
    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        ...valori,
        'docente_id': userId,
        'anno_accademico': _annoCorrente,
      };
      _insegnamento = _insegnamento == null
          ? await _client
                .from('insegnamenti')
                .insert(payload)
                .select(colonne)
                .maybeSingle()
          : await _client
                .from('insegnamenti')
                .update(payload)
                .eq('id', _insegnamento!['id'])
                .select(colonne)
                .maybeSingle();
    } catch (errore) {
      throw AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile salvare l’insegnamento.',
      );
    } finally {
      _salvataggio = false;
      notifyListeners();
    }
  }
}
