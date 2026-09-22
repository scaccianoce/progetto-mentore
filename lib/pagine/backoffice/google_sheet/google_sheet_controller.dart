import 'package:flutter/foundation.dart';

import '../../../app/app_core.dart';
import '../../../app/app_session_controller.dart';
import '../../../dati/repository.dart';

class GoogleSheetController extends ChangeNotifier {
  GoogleSheetController(this.sessione, {DatabaseRepository? database})
    : db = database ?? DatabaseRepository();

  final SessioneController sessione;
  final DatabaseRepository db;

  List<Map<String, dynamic>> sorgenti = const [];
  List<Map<String, dynamic>> configurazioni = const [];
  bool caricamento = false;
  bool salvataggio = false;
  String? errore;

  bool get puoGestire => sessione.ruolo == AppRole.owner;

  Future<void> carica() async {
    if (!puoGestire) return;
    caricamento = true;
    errore = null;
    notifyListeners();
    try {
      final risultati = await Future.wait<dynamic>([
        db.rpc('google_sheet_sorgenti_elenco'),
        db.rpc('google_sheet_configurazioni_elenco'),
      ]);
      sorgenti = _listaMappe(risultati[0]);
      configurazioni = _listaMappe(risultati[1]);
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile caricare le configurazioni Google Sheet.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  Future<String?> salva(Map<String, dynamic> valori) async {
    if (!puoGestire) return 'Operazione riservata al proprietario.';
    salvataggio = true;
    errore = null;
    notifyListeners();
    try {
      await db.rpc(
        'google_sheet_configurazione_salva',
        parametri: <String, dynamic>{
          'p_id': valori['id'],
          'p_nome': valori['nome'],
          'p_script_url': valori['script_url'],
          'p_sheet_url': valori['sheet_url'],
          'p_secret': valori['secret'],
          'p_sorgente_view': valori['sorgente_view'],
          'p_campo_id': valori['campo_id'],
          'p_campo_email': valori['campo_email'],
          'p_attiva': valori['attiva'],
          'p_mappature': valori['mappature'],
        },
      );
      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Salvataggio della configurazione non riuscito.',
      ).messaggio;
    } finally {
      salvataggio = false;
      notifyListeners();
    }
  }

  Future<String?> elimina(String id) async {
    if (!puoGestire) return 'Operazione riservata al proprietario.';
    salvataggio = true;
    notifyListeners();
    try {
      await db.rpc(
        'google_sheet_configurazione_elimina',
        parametri: <String, dynamic>{'p_id': id},
      );
      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Eliminazione della configurazione non riuscita.',
      ).messaggio;
    } finally {
      salvataggio = false;
      notifyListeners();
    }
  }

  static List<Map<String, dynamic>> _listaMappe(dynamic valore) {
    if (valore is! List) return const [];
    return valore
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }
}
