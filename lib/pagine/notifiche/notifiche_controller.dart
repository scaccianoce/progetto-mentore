import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_exception.dart';
import '../../supabase_config.dart';

class NotificaRicevuta {
  const NotificaRicevuta({
    required this.destinatarioId,
    required this.messaggioId,
    required this.titolo,
    required this.messaggio,
    required this.stato,
    required this.createdAt,
    this.annoAccademico,
    this.origineTabella,
    this.origineId,
    this.inviataAt,
    this.lettaAt,
  });

  final String destinatarioId;
  final String messaggioId;
  final String titolo;
  final String messaggio;
  final String stato;
  final String? annoAccademico;
  final String? origineTabella;
  final String? origineId;
  final DateTime createdAt;
  final DateTime? inviataAt;
  final DateTime? lettaAt;

  bool get letta => stato == 'letto' || lettaAt != null;
}

class NotificheController extends ChangeNotifier {
  NotificheController({SupabaseClient? client, this.limite = 20})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;
  final int limite;

  List<NotificaRicevuta> _notifiche = const <NotificaRicevuta>[];
  bool _caricamento = false;
  String? _errore;

  List<NotificaRicevuta> get notifiche => _notifiche;
  bool get caricamento => _caricamento;
  String? get errore => _errore;
  int get nonLette => _notifiche.where((n) => !n.letta).length;

  Future<void> carica() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      _notifiche = const <NotificaRicevuta>[];
      _errore = 'Utente non autenticato.';
      notifyListeners();
      return;
    }

    _caricamento = true;
    _errore = null;
    notifyListeners();

    try {
      final destinatariRaw = await _client
          .from('notifiche_destinatari')
          .select('id, messaggio_id, stato, inviato_at, letto_at, created_at')
          .eq('user_id', userId)
          .inFilter('stato', const <String>['inviato', 'letto'])
          .order('created_at', ascending: false)
          .limit(limite);

      final destinatari = (destinatariRaw as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

      final ids = destinatari
          .map((r) => r['messaggio_id']?.toString())
          .whereType<String>()
          .where((v) => v.isNotEmpty)
          .toList(growable: false);

      final messaggiPerId = <String, Map<String, dynamic>>{};
      if (ids.isNotEmpty) {
        final messaggiRaw = await _client
            .from('notifiche_messaggi')
            .select(
              'id, titolo, messaggio, anno_accademico, origine_tabella, '
              'origine_id, inviata_at, created_at',
            )
            .inFilter('id', ids);
        for (final raw in messaggiRaw as List) {
          final m = Map<String, dynamic>.from(raw as Map);
          final id = m['id']?.toString();
          if (id != null) messaggiPerId[id] = m;
        }
      }

      final risultato = <NotificaRicevuta>[];
      for (final d in destinatari) {
        final messaggioId = d['messaggio_id']?.toString();
        if (messaggioId == null) continue;
        final m = messaggiPerId[messaggioId];
        if (m == null) continue;

        risultato.add(
          NotificaRicevuta(
            destinatarioId: d['id'].toString(),
            messaggioId: messaggioId,
            titolo: m['titolo']?.toString() ?? 'Notifica',
            messaggio: m['messaggio']?.toString() ?? '',
            stato: d['stato']?.toString() ?? 'da_inviare',
            annoAccademico: m['anno_accademico']?.toString(),
            origineTabella: m['origine_tabella']?.toString(),
            origineId: m['origine_id']?.toString(),
            createdAt: _data(m['created_at']) ?? _data(d['created_at']) ?? DateTime.now(),
            inviataAt: _data(d['inviato_at']) ?? _data(m['inviata_at']),
            lettaAt: _data(d['letto_at']),
          ),
        );
      }

      risultato.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _notifiche = risultato;
    } catch (errore) {
      _errore = AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile caricare le notifiche.',
      ).messaggio;
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  Future<String?> segnaComeLetta(NotificaRicevuta notifica) async {
    if (notifica.letta) return null;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 'Utente non autenticato.';

    try {
      await _client.rpc(
        'notifiche_segna_letta',
        params: <String, dynamic>{'p_destinatario_id': notifica.destinatarioId},
      );
      await carica();
      return null;
    } catch (errore) {
      return AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile segnare la notifica come letta.',
      ).messaggio;
    }
  }

  static DateTime? _data(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}
