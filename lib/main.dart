import 'package:flutter/material.dart';

import 'app.dart';
import 'app_exception.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? erroreAvvio;

  try {
    await SupabaseConfig.inizializza();
  } on StateError catch (errore) {
    erroreAvvio = errore.message.toString();
  } catch (errore) {
    erroreAvvio = AppErrorMapper.converti(
      errore,
      messaggioGenerico: 'Impossibile collegarsi a Supabase.',
    ).messaggio;
  }

  runApp(MentoreApp(erroreAvvio: erroreAvvio));
}
