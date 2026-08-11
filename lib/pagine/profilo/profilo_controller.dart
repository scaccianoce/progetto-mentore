import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_exception.dart';
import '../../sessione_controller.dart';
import '../../supabase_config.dart';

class ProfiloController extends ChangeNotifier {
  ProfiloController({required this.sessione, SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  static const String colonne =
      'user_id, email_unipa, cognome, nome, cod_ssd, dipartimento, '
      'ufficio, ruolo_accademico, cellulare, fascia_eta, '
      'pagina_personale_unipa, anno_prima_partecipazione, created_at';

  final SessioneController sessione;
  final SupabaseClient _client;

  Map<String, dynamic>? _profilo;
  final List<Map<String, dynamic>> _ssd = <Map<String, dynamic>>[];
  final List<String> _anniAccademici = <String>[];
  bool _caricamento = false;
  bool _salvataggio = false;
  bool _puoModificare = false;
  String? _errore;

  Map<String, dynamic>? get profilo => _profilo;
  List<Map<String, dynamic>> get ssd => List.unmodifiable(_ssd);
  List<String> get anniAccademici => List.unmodifiable(_anniAccademici);
  bool get caricamento => _caricamento;
  bool get salvataggio => _salvataggio;
  bool get puoModificare => _puoModificare;
  String? get errore => _errore;

  Future<void> carica() async {
    final User? utente = _client.auth.currentUser;
    if (utente == null) {
      _errore = 'Sessione assente.';
      notifyListeners();
      return;
    }

    _caricamento = true;
    _errore = null;
    notifyListeners();

    try {
      final risultati = await Future.wait<dynamic>([
        _client
            .from('anagrafica')
            .select(colonne)
            .eq('user_id', utente.id)
            .maybeSingle(),
        _client.from('ssd').select('cod_ssd, gsd, area').order('cod_ssd'),
        _client
            .from('anni_accademici')
            .select('codice')
            .order('codice', ascending: false),
      ]);

      _profilo = risultati[0] as Map<String, dynamic>?;
      _ssd
        ..clear()
        ..addAll((risultati[1] as List).cast<Map<String, dynamic>>())
        ..sort(
          (prima, seconda) => prima['cod_ssd']
              .toString()
              .toLowerCase()
              .compareTo(seconda['cod_ssd'].toString().toLowerCase()),
        );
      _anniAccademici
        ..clear()
        ..addAll(
          (risultati[2] as List)
              .cast<Map<String, dynamic>>()
              .map((riga) => riga['codice'].toString().split('-').first)
              .toSet(),
        );
      final annoProfilo = _profilo?['anno_prima_partecipazione']
          ?.toString()
          .trim();
      if (annoProfilo != null &&
          annoProfilo.isNotEmpty &&
          !_anniAccademici.contains(annoProfilo)) {
        _anniAccademici.add(annoProfilo);
      }
      _puoModificare = sessione.ruolo == AppRole.participant
          ? true
          : sessione.ruolo?.puoAmministrare ?? false;

      if (!_puoModificare) {
        final dynamic risultato = await _client.rpc(
          'puo_modificare_corrente',
          params: const <String, dynamic>{'p_ambito': 'anagrafica'},
        );
        _puoModificare = risultato == true;
      }
    } catch (errore) {
      _errore = AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile caricare il profilo.',
      ).messaggio;
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  Future<void> richiediModifica() async {
    try {
      await _client.rpc(
        'richiedi_abilitazione',
        params: const <String, dynamic>{'p_ambito': 'anagrafica'},
      );
      _errore = null;
    } catch (errore) {
      _errore = AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile inviare la richiesta.',
      ).messaggio;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> salva(Map<String, dynamic> valori) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null || !_puoModificare) {
      throw const AppException('Modifica del profilo non autorizzata.');
    }

    _salvataggio = true;
    _errore = null;
    notifyListeners();

    try {
      final Map<String, dynamic>? aggiornata = await _client
          .from('anagrafica')
          .update(valori)
          .eq('user_id', userId)
          .select(colonne)
          .maybeSingle();
      if (aggiornata == null) {
        throw const AppException('Salvataggio del profilo non riuscito.');
      }
      _profilo = aggiornata;
    } catch (errore) {
      final AppException eccezione = AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile salvare il profilo.',
      );
      _errore = eccezione.messaggio;
      throw eccezione;
    } finally {
      _salvataggio = false;
      notifyListeners();
    }
  }
}
