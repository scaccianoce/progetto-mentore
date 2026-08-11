import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';
import 'supabase_config.dart';

enum AppRole {
  participant,
  organizer,
  owner;

  bool get puoAmministrare => this == organizer || this == owner;

  bool get puoGestireSicurezza => this == owner;

  static AppRole daDatabase(Object? valore) {
    return switch (valore) {
      'participant' => AppRole.participant,
      'organizer' => AppRole.organizer,
      'owner' => AppRole.owner,
      _ => throw const AppException(
        'Il ruolo dell’utente non è valido o non è stato assegnato.',
      ),
    };
  }
}

class SessioneController extends ChangeNotifier {
  SessioneController({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  StreamSubscription<AuthState>? _authSubscription;
  User? _utente;
  AppRole? _ruolo;
  String? _errore;
  bool _caricamento = false;
  bool _inizializzato = false;
  int _versioneCaricamento = 0;

  User? get utente => _utente;
  AppRole? get ruolo => _ruolo;
  String? get errore => _errore;
  bool get caricamento => _caricamento;
  bool get autenticato => _utente != null;
  bool get pronto => _utente == null || _ruolo != null;

  Future<void> inizializza() async {
    if (_inizializzato) {
      return;
    }
    _inizializzato = true;

    _authSubscription = _client.auth.onAuthStateChange.listen((
      AuthState stato,
    ) {
      unawaited(_caricaUtente(stato.session?.user));
    });

    await _caricaUtente(_client.auth.currentUser);
  }

  Future<void> accedi({required String email, required String password}) async {
    _impostaCaricamento(true);
    _errore = null;

    try {
      final AuthResponse risposta = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      await _caricaUtente(risposta.user);
    } catch (errore) {
      _errore = AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Accesso non riuscito. Controlla email e password.',
      ).messaggio;
    } finally {
      _impostaCaricamento(false);
    }
  }

  Future<void> esci() async {
    _impostaCaricamento(true);
    _errore = null;

    try {
      await _client.auth.signOut();
      await _caricaUtente(null);
    } catch (errore) {
      _errore = AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Disconnessione non riuscita. Riprova.',
      ).messaggio;
    } finally {
      _impostaCaricamento(false);
    }
  }

  Future<void> ricaricaRuolo() => _caricaUtente(_client.auth.currentUser);

  void pulisciErrore() {
    if (_errore == null) {
      return;
    }
    _errore = null;
    notifyListeners();
  }

  Future<void> _caricaUtente(User? nuovoUtente) async {
    final int versione = ++_versioneCaricamento;
    _utente = nuovoUtente;
    _ruolo = null;
    _errore = null;

    if (nuovoUtente == null) {
      _caricamento = false;
      notifyListeners();
      return;
    }

    _caricamento = true;
    notifyListeners();

    try {
      final Map<String, dynamic>? riga = await _client
          .from('user_roles')
          .select('role')
          .eq('user_id', nuovoUtente.id)
          .maybeSingle();

      if (versione != _versioneCaricamento) {
        return;
      }

      if (riga == null) {
        throw const AppException(
          'A questo utente non è stato assegnato un ruolo.',
        );
      }

      _ruolo = AppRole.daDatabase(riga['role']);
    } catch (errore) {
      if (versione != _versioneCaricamento) {
        return;
      }
      _errore = AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile caricare il ruolo dell’utente.',
      ).messaggio;
    } finally {
      if (versione == _versioneCaricamento) {
        _caricamento = false;
        notifyListeners();
      }
    }
  }

  void _impostaCaricamento(bool valore) {
    if (_caricamento == valore) {
      return;
    }
    _caricamento = valore;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
