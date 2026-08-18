/// Configurazioni Firebase che possono stare nel client.
///
/// La chiave VAPID qui sotto e PUBBLICA e puo essere inclusa nell'app.
/// Non inserire mai service account, private key o Supabase Secret Key.
class FirebaseConfig {
  FirebaseConfig._();

  static const String webVapidKey =
      'INCOLLA_QUI_LA_TUA_CHIAVE_VAPID_PUBBLICA';
}
