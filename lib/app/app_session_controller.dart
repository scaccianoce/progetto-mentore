import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_core.dart';
import '../dati/repository.dart';
import '../supporto/notifiche_push_service.dart';

/// Ruolo applicativo dell'utente autenticato.
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

/// Gestisce lo stato della sessione applicativa.
///
/// Il controller non conosce Supabase e non esegue query direttamente.
/// Autenticazione e accesso alla tabella `user_roles` passano attraverso
/// [DatabaseRepository].
class SessioneController extends ChangeNotifier {
  SessioneController({
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  final DatabaseRepository db;

  StreamSubscription<String?>? _authSubscription;

  String? _userId;
  AppRole? _ruolo;
  String? _errore;
  bool _caricamento = false;
  bool _inizializzato = false;
  int _versioneCaricamento = 0;

  /// ID dell'utente autenticato.
  String? get userId => _userId;

  AppRole? get ruolo => _ruolo;
  String? get errore => _errore;
  bool get caricamento => _caricamento;
  bool get autenticato => _userId != null;
  bool get pronto => _userId == null || _ruolo != null;

  /// Inizializza il controller e ascolta i cambiamenti della sessione.
  Future<void> inizializza() async {
    if (_inizializzato) return;
    _inizializzato = true;

    _authSubscription = db.cambiUtente.listen(
      (userId) => unawaited(_caricaUtente(userId)),
      onError: (Object errore) {
        _errore = AppErrorMapper.converti(
          errore,
          messaggioGenerico:
              'Impossibile aggiornare lo stato della sessione.',
        ).messaggio;
        notifyListeners();
      },
    );

    await _caricaUtente(db.userIdCorrente);
  }

  /// Effettua il login.
  Future<void> accedi({
    required String email,
    required String password,
  }) async {
    _impostaCaricamento(true);
    _errore = null;

    try {
      final userId = await db.accedi(
        email: email,
        password: password,
      );
      await _caricaUtente(userId);
    } catch (e) {
      _errore = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Accesso non riuscito. Controlla email e password.',
      ).messaggio;
    } finally {
      _impostaCaricamento(false);
    }
  }

  /// Termina la sessione corrente.
  Future<void> esci() async {
    _impostaCaricamento(true);
    _errore = null;

    try {
      await NotifichePushService.instance.dissociaDispositivoPerLogout();
      await db.esci();
      await _caricaUtente(null);
    } catch (e) {
      _errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Disconnessione non riuscita. Riprova.',
      ).messaggio;
    } finally {
      _impostaCaricamento(false);
    }
  }

  /// Modifica la password dell'utente autenticato.
  Future<void> cambiaPassword(String nuovaPassword) async {
    if (!autenticato) {
      throw const AppException('Sessione non valida.');
    }

    if (nuovaPassword.length < 8) {
      throw const AppException(
        'La nuova password deve avere almeno 8 caratteri.',
      );
    }

    await db.cambiaPassword(nuovaPassword);
  }

  /// Ricarica il ruolo dell'utente corrente.
  Future<void> ricaricaRuolo() => _caricaUtente(db.userIdCorrente);

  void pulisciErrore() {
    if (_errore == null) return;
    _errore = null;
    notifyListeners();
  }

  /// Carica il ruolo applicativo dell'utente indicato.
  Future<void> _caricaUtente(String? nuovoUserId) async {
    final versione = ++_versioneCaricamento;

    _userId = nuovoUserId;
    _ruolo = null;
    _errore = null;

    if (nuovoUserId == null) {
      _caricamento = false;
      notifyListeners();
      return;
    }

    _caricamento = true;
    notifyListeners();

    try {
      final riga = await db.tabella('user_roles').singolo(
        colonne: 'role',
        filtri: <FiltroDb>[
          FiltroDb.uguale('user_id', nuovoUserId),
        ],
      );

      if (versione != _versioneCaricamento) return;

      if (riga == null) {
        throw const AppException(
          'A questo utente non è stato assegnato un ruolo.',
        );
      }

      _ruolo = AppRole.daDatabase(riga['role']);

      // Precarica i metadati DB senza bloccare l'accesso in caso di errore.
      unawaited(_precaricaSchemaDatabase());
    } catch (e) {
      if (versione != _versioneCaricamento) return;

      _errore = AppErrorMapper.converti(
        e,
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
    if (_caricamento == valore) return;
    _caricamento = valore;
    notifyListeners();
  }

  Future<void> _precaricaSchemaDatabase() async {
    try {
      await db.caricaSchema();
    } catch (_) {
      // Lo schema verra' ricaricato dalle pagine quando necessario.
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
