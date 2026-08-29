import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_core.dart';
import 'configurazione/firebase_options.dart';
import 'dati/repository.dart';
import 'supporto/notifiche_push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? erroreAvvio;

  try {
    // Supabase e' il servizio necessario al funzionamento dell'applicazione.
    await SupabaseConfig.inizializza();

    // Firebase e le push sono opzionali sulle piattaforme non ancora
    // configurate (ad esempio macOS). L'app continua a funzionare senza push.
    if (DefaultFirebaseOptions.supportaPiattaformaCorrente) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await NotifichePushService.instance.inizializza();
    }
  } on StateError catch (errore) {
    erroreAvvio = errore.message.toString();
  } catch (errore) {
    erroreAvvio = AppErrorMapper.converti(
      errore,
      messaggioGenerico:
          'Impossibile inizializzare i servizi dell’applicazione.',
    ).messaggio;
  }

  runApp(MentoreApp(erroreAvvio: erroreAvvio));
}
