import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_config.dart';
import 'supabase_config.dart';

/// Gestisce il canale push dell'app.
///
/// Firebase viene inizializzato nel main.dart tramite firebase_options.dart.
/// Supabase resta il backend applicativo; FCM viene usato solo per la consegna
/// push ai dispositivi.
class NotifichePushService {
  NotifichePushService._();

  static final NotifichePushService instance = NotifichePushService._();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  final ValueNotifier<int> aggiornamenti = ValueNotifier<int>(0);
  final StreamController<RemoteMessage> _apertureController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> _foregroundController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get apertureNotifiche => _apertureController.stream;
  Stream<RemoteMessage> get notificheForeground => _foregroundController.stream;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  bool _inizializzato = false;
  String? _ultimoToken;
  String? _errore;

  String? get errore => _errore;
  bool get inizializzato => _inizializzato;

  Future<void> inizializza() async {
    if (_inizializzato) return;

    try {
      if (Firebase.apps.isEmpty) {
        throw StateError(
          'Firebase non è inizializzato. Eseguire Firebase.initializeApp() nel main.dart.',
        );
      }

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
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
        },
      );

      _authSubscription ??= SupabaseConfig.client.auth.onAuthStateChange.listen(
        (stato) {
          if (stato.session?.user != null) {
            unawaited(sincronizzaDispositivo());
          }
        },
      );

      _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
        (messaggio) {
          debugPrint(
            'Notifica FCM ricevuta in foreground: ${messaggio.messageId}',
          );
          aggiornamenti.value++;
          _foregroundController.add(messaggio);
        },
      );

      _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
        (messaggio) {
          aggiornamenti.value++;
          _apertureController.add(messaggio);
        },
      );

      _inizializzato = true;

      await sincronizzaDispositivo();

      final iniziale = await _messaging.getInitialMessage();
      if (iniziale != null) {
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          _apertureController.add(iniziale);
        });
      }
    } catch (errore) {
      _errore = 'Notifiche push non inizializzate: $errore';
      _inizializzato = false;
    }
  }

  Future<void> sincronizzaDispositivo() async {
    if (!_inizializzato || Firebase.apps.isEmpty) return;
    if (SupabaseConfig.client.auth.currentUser == null) return;

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
    }
  }

  Future<void> _registraToken(String token) async {
    if (SupabaseConfig.client.auth.currentUser == null) return;

    final piattaforma = _piattaformaCorrente();
    if (piattaforma == null) return;

    try {
      await SupabaseConfig.client.rpc(
        'notifiche_registra_dispositivo',
        params: <String, dynamic>{
          'p_token': token,
          'p_piattaforma': piattaforma,
        },
      );
      _ultimoToken = token;
      _errore = null;
    } catch (errore) {
      _errore = 'Impossibile registrare il token in Supabase: $errore';
    }
  }

  Future<void> disattivaDispositivoCorrente() async {
    if (SupabaseConfig.client.auth.currentUser == null) return;

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
      await SupabaseConfig.client.rpc(
        'notifiche_disattiva_dispositivo',
        params: <String, dynamic>{'p_token': token},
      );
      _ultimoToken = null;
    } catch (_) {
      // Il logout non deve essere bloccato dal canale push.
    }
  }

  /// Restituisce la sezione dell'app associata alla push.
  ///
  /// Il record specifico resta identificato in origine_id; le pagine possono
  /// in seguito usare questo ID per preselezionare l'elemento.
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

    await _apertureController.close();
    await _foregroundController.close();
  }
}
