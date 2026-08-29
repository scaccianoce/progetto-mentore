import 'package:flutter/foundation.dart';
import '../../app/app_core.dart';
import '../../dati/repository.dart';
import '../../supporto/notifiche_push_service.dart';

/// Notifica ricevuta dall'utente corrente, pronta per la visualizzazione.
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

/// Controller della pagina personale Notifiche.
///
/// Mantiene stato e composizione dei messaggi ricevuti. Le operazioni remote
/// restano volutamente delegate a [NotificheRepository], che costituisce il
/// sottosistema notifiche separato dal repository CRUD generico.
class NotificheController extends ChangeNotifier {
  NotificheController({NotificheRepository? repository, this.limite = 20})
      : repository = repository ?? NotificheRepository();

  final NotificheRepository repository;
  final int limite;

  List<NotificaRicevuta> _notifiche = const <NotificaRicevuta>[];
  bool _caricamento = false;
  String? _errore;

  List<NotificaRicevuta> get notifiche => _notifiche;
  bool get caricamento => _caricamento;
  String? get errore => _errore;
  int get nonLette => _notifiche.where((n) => !n.letta).length;

  /// Carica i dati necessari e aggiorna lo stato esposto alla pagina.
  Future<void> carica() async {
    final userId = repository.userIdCorrente;
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
      final destinatariRaw = await repository.notificheRicevute(limite: limite);

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
        final messaggiRaw = await repository.messaggiPerIds(ids);
        for (final raw in messaggiRaw) {
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
      await NotifichePushService.instance.aggiornaNonLette();
    }
  }

  /// Aggiorna l’operazione `segnaComeLetta` mantenendo separata la logica dalla UI.
  Future<String?> segnaComeLetta(NotificaRicevuta notifica) async {
    if (notifica.letta) return null;
    final userId = repository.userIdCorrente;
    if (userId == null) return 'Utente non autenticato.';

    try {
      await repository.segnaDestinatarioLetto(notifica.destinatarioId);
      await carica();
      return null;
    } catch (errore) {
      return AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile segnare la notifica come letta.',
      ).messaggio;
    }
  }

  /// Gestisce l’operazione interna “data” della pagina.
  static DateTime? _data(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}
