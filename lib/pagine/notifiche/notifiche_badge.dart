import 'dart:async';

import 'package:flutter/material.dart';

import '../../notifiche_push_service.dart';
import '../../supabase_config.dart';

/// Badge leggero per la voce "Notifiche" del menu.
///
/// Conta le notifiche consegnate ma non ancora lette dell'utente corrente.
/// Si aggiorna:
/// - periodicamente;
/// - quando arriva una push in foreground;
/// - quando il servizio push segnala un aggiornamento.
class NotificheBadge extends StatefulWidget {
  const NotificheBadge({super.key});

  @override
  State<NotificheBadge> createState() => _NotificheBadgeState();
}

class _NotificheBadgeState extends State<NotificheBadge> {
  Timer? _timer;
  int _nonLette = 0;

  @override
  void initState() {
    super.initState();
    NotifichePushService.instance.aggiornamenti.addListener(_aggiornamentoPush);
    _carica();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _carica());
  }

  @override
  void dispose() {
    _timer?.cancel();
    NotifichePushService.instance.aggiornamenti.removeListener(_aggiornamentoPush);
    super.dispose();
  }

  void _aggiornamentoPush() => _carica();

  Future<void> _carica() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted && _nonLette != 0) setState(() => _nonLette = 0);
      return;
    }

    try {
      final raw = await SupabaseConfig.client
          .from('notifiche_destinatari')
          .select('id')
          .eq('user_id', userId)
          .eq('stato', 'inviato');

      final count = (raw as List).length;
      if (mounted && count != _nonLette) {
        setState(() => _nonLette = count);
      }
    } catch (_) {
      // Il badge non deve mai impedire la navigazione dell'app.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_nonLette <= 0) return const SizedBox.shrink();
    return Badge(
      label: Text(_nonLette > 99 ? '99+' : '$_nonLette'),
    );
  }
}
