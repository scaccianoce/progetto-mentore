/// Configurazioni Firebase che possono essere incluse nel client.
///
/// La VAPID Web Push key e' una chiave pubblica. Viene letta tramite
/// `--dart-define` per evitare placeholder o valori specifici dell'ambiente
/// direttamente nel sorgente.
///
/// Esempio:
///
/// flutter run -d chrome \
///   --dart-define=FIREBASE_WEB_VAPID_KEY=chiave_pubblica
abstract final class FirebaseConfig {
  /// Chiave pubblica VAPID usata soltanto sul Web.
  static const String webVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_VAPID_KEY',
    defaultValue: 'BOUW99eiUV3qRX6rBp3rzgNKYnHeFRp1t7Lgtph0sldi695LleW5IA8wV1GYHnsrHkIhrj6OH4UQRs70d_HekzA',
  );

  static const bool webVapidConfigurata = webVapidKey != '';
}
