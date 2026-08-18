import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../notifiche_push_service.dart';

import 'notifiche_controller.dart';

class NotifichePage extends StatefulWidget {
  const NotifichePage({super.key});

  @override
  State<NotifichePage> createState() => _NotifichePageState();
}

class _NotifichePageState extends State<NotifichePage> {
  late final NotificheController _controller;

  @override
  void initState() {
    super.initState();
    _controller = NotificheController()..addListener(_aggiorna);
    NotifichePushService.instance.aggiornamenti.addListener(_pushRicevuta);
    _controller.carica();
  }

  @override
  void dispose() {
    NotifichePushService.instance.aggiornamenti.removeListener(_pushRicevuta);
    _controller
      ..removeListener(_aggiorna)
      ..dispose();
    super.dispose();
  }

  void _aggiorna() {
    if (mounted) setState(() {});
  }

  void _pushRicevuta() {
    _controller.carica();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Notifiche recenti',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (_controller.nonLette > 0)
                  Badge(label: Text('${_controller.nonLette}')),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Aggiorna',
                  onPressed: _controller.caricamento ? null : _controller.carica,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Qui trovi le ultime ${_controller.limite} notifiche destinate al tuo account.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_controller.caricamento) const LinearProgressIndicator(),
            if (_controller.errore != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_controller.errore!),
              ),
            Expanded(
              child: _controller.notifiche.isEmpty && !_controller.caricamento
                  ? const Center(child: Text('Nessuna notifica recente.'))
                  : ListView.separated(
                      itemCount: _controller.notifiche.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final notifica = _controller.notifiche[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              notifica.letta
                                  ? Icons.notifications_none
                                  : Icons.notifications_active,
                            ),
                            title: Text(
                              notifica.titolo,
                              style: TextStyle(
                                fontWeight: notifica.letta
                                    ? FontWeight.normal
                                    : FontWeight.w700,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(notifica.messaggio),
                                  const SizedBox(height: 6),
                                  Text(
                                    _sottotitolo(notifica),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            trailing: notifica.letta
                                ? null
                                : const Icon(Icons.circle, size: 10),
                            onTap: () => _apri(notifica),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _apri(NotificaRicevuta notifica) async {
    final errore = await _controller.segnaComeLetta(notifica);
    if (!mounted) return;
    if (errore != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errore)),
      );
      return;
    }
    NotifichePushService.instance.aggiornamenti.value++;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notifica.titolo),
        content: SelectableText(notifica.messaggio),
        actions: <Widget>[
          if (_percorsoOrigine(notifica) != null)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.go(_percorsoOrigine(notifica)!);
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Apri contenuto'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  String? _percorsoOrigine(NotificaRicevuta notifica) {
    return switch (notifica.origineTabella) {
      'news' => '/news',
      'eventi' => '/eventi',
      'house_of_mentore' => '/house-of-mentore',
      'mentoraggi' => '/mentore',
      'insegnamenti' => '/insegnamento',
      _ => null,
    };
  }

  String _sottotitolo(NotificaRicevuta notifica) {
    final data = notifica.inviataAt ?? notifica.createdAt;
    final giorno = data.day.toString().padLeft(2, '0');
    final mese = data.month.toString().padLeft(2, '0');
    final ora = data.hour.toString().padLeft(2, '0');
    final minuti = data.minute.toString().padLeft(2, '0');
    final anno = notifica.annoAccademico;
    return '${giorno}/${mese}/${data.year} $ora:$minuti${anno == null ? '' : ' · $anno'}';
  }
}
