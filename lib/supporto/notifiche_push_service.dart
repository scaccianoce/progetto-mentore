import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../configurazione/firebase_config.dart';
import '../dati/repository.dart';

/// Gestisce esclusivamente il canale push FCM del dispositivo.
///
/// Questo servizio non accede direttamente al database e non conosce Supabase.
/// Registrazione del dispositivo, badge e stato di autenticazione vengono
/// richiesti a [NotificheRepository].
class NotifichePushService {
  NotifichePushService._();

  static final NotifichePushService instance = NotifichePushService._();

  final NotificheRepository _repository = NotificheRepository();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  /// Incrementato quando arriva o viene aperta una notifica.
  final ValueNotifier<int> aggiornamenti = ValueNotifier<int>(0);

  /// Numero di notifiche non lette dell'utente corrente.
  final ValueNotifier<int> nonLette = ValueNotifier<int>(0);

  final StreamController<RemoteMessage> _apertureController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> _foregroundController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get apertureNotifiche => _apertureController.stream;
  Stream<RemoteMessage> get notificheForeground => _foregroundController.stream;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<bool>? _authSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  bool _inizializzato = false;
  String? _ultimoToken;
  String? _errore;

  String? get errore => _errore;
  bool get inizializzato => _inizializzato;

  /// Inizializza il canale FCM e collega i listener del dispositivo.
  Future<void> inizializza() async {
    if (_inizializzato) return;

    try {
      if (Firebase.apps.isEmpty) {
        throw StateError(
          'Firebase non è inizializzato. '
          'Eseguire Firebase.initializeApp() nel main.dart.',
        );
      }

      final impostazioni = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (impostazioni.authorizationStatus == AuthorizationStatus.denied) {
        _errore = 'Permesso notifiche non concesso.';
        _inizializzato = true;
        return;
      }

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _tokenSubscription ??= _messaging.onTokenRefresh.listen(
        (token) => unawaited(_registraToken(token)),
        onError: (Object errore) {
          _errore = 'Aggiornamento token FCM non riuscito: $errore';
          debugPrint('[PushService] $_errore');
        },
      );

      _authSubscription ??= _repository.cambiStatoAutenticazione.listen(
        (autenticato) {
          if (autenticato) {
            unawaited(sincronizzaDispositivo());
            unawaited(aggiornaNonLette());
          } else {
            nonLette.value = 0;
          }
        },
      );

      _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
        (messaggio) {
          aggiornamenti.value++;
          unawaited(aggiornaNonLette());
          _foregroundController.add(messaggio);
        },
      );

      _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
        (messaggio) {
          aggiornamenti.value++;
          unawaited(aggiornaNonLette());
          _apertureController.add(messaggio);
        },
      );

      _inizializzato = true;

      await sincronizzaDispositivo();
      await aggiornaNonLette();

      final iniziale = await _messaging.getInitialMessage();
      if (iniziale != null) {
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          if (!_apertureController.isClosed) {
            _apertureController.add(iniziale);
          }
        });
      }
    } catch (errore) {
      _errore = 'Notifiche push non inizializzate: $errore';
      debugPrint('[PushService] $_errore');
      _inizializzato = false;
    }
  }

  /// Aggiorna il badge delle notifiche senza bloccare l'app in caso di errore.
  Future<void> aggiornaNonLette() async {
    if (!_repository.utenteAutenticato) {
      nonLette.value = 0;
      return;
    }

    try {
      nonLette.value = await _repository.contaNotificheNonLette();
    } catch (_) {
      // Il badge è informativo e non deve interrompere il flusso dell'app.
    }
  }

  /// Recupera il token FCM corrente e lo sincronizza con il backend.
  Future<void> sincronizzaDispositivo() async {
    if (!_inizializzato || Firebase.apps.isEmpty) return;
    if (!_repository.utenteAutenticato) return;

    try {
      final token = await _messaging.getToken(
        vapidKey: kIsWeb ? FirebaseConfig.webVapidKey : null,
      );

      if (token == null || token.trim().isEmpty) {
        _errore = 'Firebase non ha restituito un token FCM.';
        return;
      }

      await _registraToken(token);
    } catch (errore) {
      _errore = 'Registrazione dispositivo non riuscita: $errore';
      debugPrint('[PushService] $_errore');
    }
  }

  /// Registra nel backend il token del dispositivo corrente.
  Future<void> _registraToken(String token) async {
    if (!_repository.utenteAutenticato) return;

    final piattaforma = _piattaformaCorrente();
    if (piattaforma == null) {
      debugPrint(
        '[PushService] Registrazione saltata: piattaforma non supportata per push.',
      );
      return;
    }

    try {
      await _repository.registraDispositivo(
        token: token,
        piattaforma: piattaforma,
      );
      _ultimoToken = token;
      _errore = null;
    } catch (errore) {
      _errore = 'Impossibile registrare il dispositivo: $errore';
      debugPrint('[PushService] $_errore');
    }
  }

  /// Disattiva il token corrente prima del logout.
  Future<void> disattivaDispositivoCorrente() async {
    if (!_repository.utenteAutenticato) return;

    String? token = _ultimoToken;

    if (token == null || token.isEmpty) {
      try {
        token = await _messaging.getToken(
          vapidKey: kIsWeb ? FirebaseConfig.webVapidKey : null,
        );
      } catch (_) {
        return;
      }
    }

    if (token == null || token.isEmpty) return;

    try {
      await _repository.disattivaDispositivo(token);
      _ultimoToken = null;
    } catch (_) {
      // Il logout non deve essere bloccato dalla disattivazione del push.
    }
  }

  /// Restituisce la rotta applicativa associata alla notifica ricevuta.
  String percorsoPer(RemoteMessage messaggio) {
    final origine = messaggio.data['origine_tabella']?.toString();

    return switch (origine) {
      'news' => '/news',
      'eventi' => '/eventi',
      'house_of_mentore' => '/house-of-mentore',
      'mentoraggi' => '/mentore',
      'insegnamenti' => '/insegnamento',
      _ => '/notifiche',
    };
  }

  String? _piattaformaCorrente() {
    if (kIsWeb) return 'web';

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }

  /// Rilascia i listener associati al canale push.
  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _authSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();

    _tokenSubscription = null;
    _authSubscription = null;
    _foregroundSubscription = null;
    _openedSubscription = null;
    _inizializzato = false;

    if (!_apertureController.isClosed) {
      await _apertureController.close();
    }
    if (!_foregroundController.isClosed) {
      await _foregroundController.close();
    }
  }
}
