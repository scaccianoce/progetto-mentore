import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../configurazione/firebase_config.dart';
import '../dati/repository.dart';
import 'notifica_sistema_stub.dart'
    if (dart.library.js_interop) 'notifica_sistema_web.dart';

/// Gestisce esclusivamente il canale push FCM del dispositivo.
///
/// Questo servizio non accede direttamente al database e non conosce Supabase.
/// Registrazione del dispositivo, badge e stato di autenticazione vengono
/// richiesti a [NotificheRepository].
class NotifichePushService {
  NotifichePushService._();

  static final NotifichePushService instance = NotifichePushService._();
  static const _chiaveDeviceId = 'notifiche_device_id_v1';
  static const _chiaveTokenDisattivato = 'notifiche_token_disattivato_v1';

  final NotificheRepository _repository = NotificheRepository();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  Future<String?> _recuperaToken() => _messaging.getToken(
    vapidKey: kIsWeb ? FirebaseConfig.webVapidKey : null,
    // Il worker FCM deve avere uno scope distinto dal worker PWA di Flutter.
    // Se entrambi sono nella root, il browser li considera la stessa
    // registrazione e l'ultimo aggiornamento sostituisce l'altro.
    serviceWorkerScriptPath: kIsWeb
        ? 'firebase-cloud-messaging-push-scope/firebase-messaging-sw.js'
        : null,
  );

  /// Incrementato quando arriva o viene aperta una notifica.
  final ValueNotifier<int> aggiornamenti = ValueNotifier<int>(0);

  /// Numero di notifiche non lette dell'utente corrente.
  final ValueNotifier<int> nonLette = ValueNotifier<int>(0);

  final StreamController<RemoteMessage> _apertureController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get apertureNotifiche => _apertureController.stream;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<String?>? _authSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  bool _inizializzato = false;
  bool _registrazioneConsentita = false;
  int _versioneSessionePush = 0;
  Future<void> _codaOperazioniPush = Future<void>.value();
  Future<String>? _deviceIdFuture;

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

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _tokenSubscription ??= _messaging.onTokenRefresh.listen(
        (token) => unawaited(_accodaRegistrazioneToken(token)),
        onError: (Object errore) {
          debugPrint(
            '[PushService] Aggiornamento token FCM non riuscito: $errore',
          );
        },
      );

      _authSubscription ??= _repository.cambiUtenteAutenticato.listen(
        (userId) => unawaited(_accodaCambioUtente(userId)),
        onError: (Object errore) {
          debugPrint(
            '[PushService] Aggiornamento sessione push non riuscito: $errore',
          );
        },
      );

      _foregroundSubscription ??= FirebaseMessaging.onMessage.listen((
        messaggio,
      ) {
        if (!_repository.utenteAutenticato) return;
        aggiornamenti.value++;
        unawaited(aggiornaNonLette());
        unawaited(
          mostraNotificaSistema(
            titolo:
                messaggio.notification?.title ??
                messaggio.data['titolo']?.toString() ??
                'Progetto Mentore',
            messaggio:
                messaggio.notification?.body ??
                messaggio.data['messaggio']?.toString() ??
                'Hai ricevuto una nuova notifica.',
            link: messaggio.data['link']?.toString() ?? './#/notifiche',
          ).catchError((Object errore) {
            debugPrint(
              '[PushService] Notifica di sistema in primo piano non riuscita: '
              '$errore',
            );
          }),
        );
      });

      _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen((
        messaggio,
      ) {
        if (!_repository.utenteAutenticato) return;
        aggiornamenti.value++;
        unawaited(aggiornaNonLette());
        _apertureController.add(messaggio);
      });

      _inizializzato = true;

      await _accodaCambioUtente(_repository.userIdCorrente);

      final userIdIniziale = _repository.userIdCorrente;
      final iniziale = await _messaging.getInitialMessage();
      if (iniziale != null && userIdIniziale != null) {
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          if (!_apertureController.isClosed &&
              _repository.userIdCorrente == userIdIniziale) {
            _apertureController.add(iniziale);
          }
        });
      }
    } catch (errore) {
      debugPrint('[PushService] Notifiche push non inizializzate: $errore');
      _inizializzato = false;
    }
  }

  /// Attiva o rimuove il canale push in base alla sessione applicativa.
  ///
  /// Il permesso viene richiesto soltanto dopo il login. Al logout il token
  /// viene disattivato lato backend, ma resta nell'installazione: in questo
  /// modo Firebase non ne genera inutilmente uno nuovo al login successivo.
  Future<void> _accodaCambioUtente(String? userId) {
    final versione = ++_versioneSessionePush;
    _codaOperazioniPush = _codaOperazioniPush.then<void>(
      (_) => _gestisciCambioUtente(userId, versione),
      onError: (_) => _gestisciCambioUtente(userId, versione),
    );
    return _codaOperazioniPush;
  }

  Future<void> _gestisciCambioUtente(String? userId, int versione) async {
    if (versione != _versioneSessionePush) return;

    if (userId == null) {
      _registrazioneConsentita = false;
      nonLette.value = 0;
      if (!await _tokenGiaDisattivato()) {
        await _cancellaTokenLocale();
      }
      return;
    }

    _registrazioneConsentita = true;

    try {
      final impostazioni = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (versione != _versioneSessionePush) return;

      if (impostazioni.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[PushService] Permesso notifiche non concesso.');
        return;
      }

      await _registraDispositivoCorrente();
      await aggiornaNonLette();
    } catch (errore) {
      debugPrint('[PushService] Attivazione notifiche non riuscita: $errore');
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

  /// Registra l'installazione quando si apre una sessione autenticata.
  Future<void> _registraDispositivoCorrente() async {
    if (!_inizializzato || Firebase.apps.isEmpty) return;
    if (!_registrazioneConsentita || !_repository.utenteAutenticato) return;

    try {
      final token = await _recuperaToken();

      if (token == null || token.trim().isEmpty) {
        debugPrint('[PushService] Firebase non ha restituito un token FCM.');
        return;
      }

      await _registraToken(token);
    } catch (errore) {
      debugPrint(
        '[PushService] Registrazione dispositivo non riuscita: $errore',
      );
    }
  }

  /// Registra nel backend il token del dispositivo corrente.
  Future<void> _registraToken(String token) async {
    if (!_registrazioneConsentita) return;
    if (!_repository.utenteAutenticato) return;

    final piattaforma = _piattaformaCorrente();
    if (piattaforma == null) {
      debugPrint(
        '[PushService] Registrazione saltata: piattaforma non supportata per push.',
      );
      return;
    }

    try {
      final deviceId = await _deviceIdInstallazione();
      await _repository.registraDispositivo(
        token: token,
        piattaforma: piattaforma,
        deviceId: deviceId,
      );
      await _salvaTokenDisattivato(false);
    } catch (errore) {
      debugPrint(
        '[PushService] Impossibile registrare il dispositivo: $errore',
      );
    }
  }

  Future<void> _accodaRegistrazioneToken(String token) {
    _codaOperazioniPush = _codaOperazioniPush.then<void>(
      (_) => _registraToken(token),
      onError: (_) => _registraToken(token),
    );
    return _codaOperazioniPush;
  }

  /// Disattiva l'installazione corrente prima del logout.
  Future<bool> _disattivaDispositivoCorrente() async {
    if (!_repository.utenteAutenticato) return false;

    try {
      final deviceId = await _deviceIdInstallazione();
      await _repository.disattivaDispositivo(deviceId);
      return true;
    } catch (_) {
      // Il logout non deve essere bloccato dalla disattivazione del push.
      return false;
    }
  }

  /// Disassocia il dispositivo dall'utente in fase di logout.
  ///
  /// Il token locale non viene cancellato: rimane inattivo nel backend e può
  /// essere riassociato al prossimo utente senza creare una nuova registrazione
  /// FCM. L'ID dell'installazione garantisce una sola riga nel database anche
  /// quando Firebase ruota autonomamente il token.
  Future<void> dissociaDispositivoPerLogout() async {
    if (!_inizializzato || Firebase.apps.isEmpty) return;

    _registrazioneConsentita = false;
    final versione = ++_versioneSessionePush;

    _codaOperazioniPush = _codaOperazioniPush.then<void>(
      (_) async {
        if (versione != _versioneSessionePush) return;
        final disattivato = await _disattivaDispositivoCorrente();
        await _salvaTokenDisattivato(disattivato);
      },
      onError: (_) async {
        if (versione != _versioneSessionePush) return;
        final disattivato = await _disattivaDispositivoCorrente();
        await _salvaTokenDisattivato(disattivato);
      },
    );

    await _codaOperazioniPush;
  }

  /// Riattiva il canale se il logout applicativo non e' andato a buon fine.
  Future<void> ripristinaDopoLogoutFallito() async {
    if (!_repository.utenteAutenticato) return;
    await _accodaCambioUtente(_repository.userIdCorrente);
  }

  Future<String> _deviceIdInstallazione() {
    return _deviceIdFuture ??= _caricaOCreaDeviceIdInstallazione();
  }

  Future<String> _caricaOCreaDeviceIdInstallazione() async {
    final preferenze = await SharedPreferences.getInstance();
    final esistente = preferenze.getString(_chiaveDeviceId)?.trim();
    if (esistente != null && esistente.isNotEmpty) return esistente;

    final casuale = Random.secure();
    final byte = List<int>.generate(16, (_) => casuale.nextInt(256));
    byte[6] = (byte[6] & 0x0f) | 0x40;
    byte[8] = (byte[8] & 0x3f) | 0x80;
    final hex = byte
        .map((valore) => valore.toRadixString(16).padLeft(2, '0'))
        .join();
    final deviceId =
        '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';

    await preferenze.setString(_chiaveDeviceId, deviceId);
    return deviceId;
  }

  Future<bool> _tokenGiaDisattivato() async {
    try {
      final preferenze = await SharedPreferences.getInstance();
      return preferenze.getBool(_chiaveTokenDisattivato) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _salvaTokenDisattivato(bool disattivato) async {
    try {
      final preferenze = await SharedPreferences.getInstance();
      await preferenze.setBool(_chiaveTokenDisattivato, disattivato);
    } catch (_) {
      // In caso di storage locale non disponibile prevale la sicurezza:
      // un successivo logout inatteso cancellera' il token FCM locale.
    }
  }

  Future<void> _cancellaTokenLocale() async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    try {
      await _messaging.deleteToken();
      await _salvaTokenDisattivato(true);
    } catch (errore) {
      debugPrint(
        '[PushService] Impossibile cancellare il token locale: $errore',
      );
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
    _registrazioneConsentita = false;
    _versioneSessionePush++;

    if (!_apertureController.isClosed) {
      await _apertureController.close();
    }
  }
}
