import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'app_exception.dart';
import 'firebase_options.dart';
import 'notifiche_push_service.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? erroreAvvio;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await SupabaseConfig.inizializza();
    await NotifichePushService.instance.inizializza();
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
