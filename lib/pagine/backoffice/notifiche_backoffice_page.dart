import 'dart:convert';

import 'package:flutter/material.dart';

import '../../dinamico/maschera_dinamica_controller.dart';
import '../../supabase_config.dart';

/// Gestione notifiche riservata a owner e organizer.
///
/// Il router/menu applicano il controllo di ruolo; le RLS DB devono mantenere
/// lo stesso vincolo lato server.
class NotificheBackofficePage extends StatelessWidget {
  const NotificheBackofficePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          minimum: EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              TabBar(
                tabs: <Widget>[
                  Tab(icon: Icon(Icons.notifications_outlined), text: 'Messaggi'),
                  Tab(icon: Icon(Icons.rule_outlined), text: 'Regole'),
                ],
              ),
              SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    NotificheMessaggiBackofficePage(),
                    NotificheRegoleBackofficePage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MESSAGGI
// ============================================================================

class NotificheMessaggiBackofficePage extends StatefulWidget {
  const NotificheMessaggiBackofficePage({super.key});

  @override
  State<NotificheMessaggiBackofficePage> createState() =>
      _NotificheMessaggiBackofficePageState();
}

class _NotificheMessaggiBackofficePageState
    extends State<NotificheMessaggiBackofficePage> {
  SchemaDatabase? _schema;
  List<Map<String, dynamic>> _messaggi = const [];
  bool _caricamento = true;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final risultati = await Future.wait<dynamic>([
        SupabaseConfig.caricaSchemaDatabase(),
        SupabaseConfig.client
            .from('notifiche_messaggi')
            .select()
            .order('created_at', ascending: false)
            .limit(200),
      ]);
      if (!mounted) return;
      setState(() {
        _schema = risultati[0] as SchemaDatabase;
        _messaggi = (risultati[1] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errore = 'Impossibile caricare i messaggi.\n$e');
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  bool _programmatoModificabile(Map<String, dynamic> messaggio) {
    return messaggio['stato']?.toString() == 'programmato' &&
        messaggio['inviata_at'] == null;
  }

  bool _ritentabile(Map<String, dynamic> messaggio) {
    final stato = messaggio['stato']?.toString();
    return stato == 'errore' || stato == 'parziale';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Messaggi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Aggiorna',
              onPressed: _caricamento ? null : _carica,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _schema == null ? null : _nuovoMessaggio,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Nuova notifica'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_caricamento) const LinearProgressIndicator(),
        if (_errore != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_errore!),
          ),
        Expanded(
          child: _messaggi.isEmpty && !_caricamento
              ? const Center(child: Text('Nessun messaggio.'))
              : ListView.separated(
                  itemCount: _messaggi.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final m = _messaggi[index];
                    final modificabile = _programmatoModificabile(m);
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.notifications_outlined),
                        title: Text(m['titolo']?.toString() ?? 'Notifica'),
                        subtitle: Text(
                          '${m['anno_accademico'] ?? ''} · ${m['destinatari'] ?? ''} · '
                          '${m['stato'] ?? ''}${m['programmata_per'] == null ? '' : ' · ${_formattaValoreData(m['programmata_per'])}'}',
                        ),
                        trailing: Wrap(
                          spacing: 2,
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Stato destinatari',
                              onPressed: () => _mostraDestinatari(m),
                              icon: const Icon(Icons.people_outline),
                            ),
                            if (_ritentabile(m))
                              IconButton(
                                tooltip: 'Riprova invio',
                                onPressed: () => _ritentaInvio(m),
                                icon: const Icon(Icons.refresh_outlined),
                              ),
                            if (modificabile)
                              IconButton(
                                tooltip: 'Modifica notifica programmata',
                                onPressed: () => _modificaMessaggio(m),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            if (modificabile)
                              IconButton(
                                tooltip: 'Elimina notifica programmata',
                                onPressed: () => _eliminaMessaggio(m),
                                icon: const Icon(Icons.delete_outline),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _ritentaInvio(Map<String, dynamic> messaggio) async {
    final id = messaggio['id']?.toString();
    if (id == null || id.isEmpty) return;

    try {
      final risposta = await SupabaseConfig.client.functions.invoke(
        'notifiche-invia',
        body: <String, dynamic>{'messaggio_id': id},
      );
      if (risposta.status < 200 || risposta.status >= 300) {
        throw StateError(
          'Invio push non riuscito (HTTP ${risposta.status}): ${risposta.data}',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nuovo tentativo di invio completato.')),
      );
      await _carica();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nuovo tentativo non riuscito: $e')),
      );
    }
  }

  Future<void> _nuovoMessaggio() async {
    final schema = _schema;
    if (schema == null) return;
    final salvato = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MessaggioManualeDialog(schema: schema),
    );
    if (salvato == true) await _carica();
  }

  Future<void> _modificaMessaggio(Map<String, dynamic> messaggio) async {
    final schema = _schema;
    if (schema == null || !_programmatoModificabile(messaggio)) return;
    final salvato = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MessaggioManualeDialog(
        schema: schema,
        messaggioEsistente: messaggio,
      ),
    );
    if (salvato == true) await _carica();
  }

  Future<void> _eliminaMessaggio(Map<String, dynamic> messaggio) async {
    if (!_programmatoModificabile(messaggio)) return;
    final id = messaggio['id']?.toString();
    if (id == null || id.isEmpty) return;

    final conferma = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Elimina notifica programmata'),
            content: Text(
              'Vuoi eliminare definitivamente "${messaggio['titolo'] ?? 'questa notifica'}"?\n\n'
              'Saranno eliminati anche i destinatari già associati alla notifica.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Elimina'),
              ),
            ],
          ),
        ) ??
        false;
    if (!conferma) return;

    try {
      await SupabaseConfig.client
          .from('notifiche_messaggi')
          .delete()
          .eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifica programmata eliminata.')),
      );
      await _carica();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eliminazione non riuscita: $e')),
      );
    }
  }

  Future<void> _mostraDestinatari(Map<String, dynamic> messaggio) async {
    final id = messaggio['id']?.toString();
    if (id == null || id.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _DestinatariMessaggioDialog(
        messaggioId: id,
        titolo: messaggio['titolo']?.toString() ?? 'Notifica',
      ),
    );
  }

  String _formattaValoreData(Object? valore) {
    if (valore == null) return '';
    final data = DateTime.tryParse(valore.toString());
    if (data == null) return valore.toString();
    return _formattaDataOra(data.toLocal());
  }
}

class _DestinatariMessaggioDialog extends StatefulWidget {
  const _DestinatariMessaggioDialog({
    required this.messaggioId,
    required this.titolo,
  });

  final String messaggioId;
  final String titolo;

  @override
  State<_DestinatariMessaggioDialog> createState() =>
      _DestinatariMessaggioDialogState();
}

class _DestinatariMessaggioDialogState
    extends State<_DestinatariMessaggioDialog> {
  bool _caricamento = true;
  String? _errore;
  List<Map<String, dynamic>> _destinatari = const [];

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final raw = await SupabaseConfig.client.rpc(
        'notifiche_dettaglio_destinatari',
        params: <String, dynamic>{'p_messaggio_id': widget.messaggioId},
      );
      if (!mounted) return;
      setState(() {
        _destinatari = (raw as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errore = 'Impossibile caricare i destinatari.\n$e');
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Destinatari · ${widget.titolo}'),
      content: SizedBox(
        width: 850,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_caricamento) const LinearProgressIndicator(),
            if (_errore != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_errore!),
              ),
            if (!_caricamento && _errore == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${_destinatari.length} destinatari'),
              ),
            Expanded(
              child: _destinatari.isEmpty && !_caricamento
                  ? const Center(child: Text('Nessun destinatario.'))
                  : ListView.separated(
                      itemCount: _destinatari.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final d = _destinatari[index];
                        final nome = '${d['cognome'] ?? ''} ${d['nome'] ?? ''}'.trim();
                        final errore = d['errore']?.toString().trim();
                        return ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(nome.isEmpty ? d['user_id']?.toString() ?? 'Utente' : nome),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if ((d['email_unipa']?.toString() ?? '').isNotEmpty)
                                Text(d['email_unipa'].toString()),
                              Text(
                                'Stato: ${d['stato'] ?? ''}'
                                '${d['inviato_at'] == null ? '' : ' · inviato ${_formattaDataDb(d['inviato_at'])}'}'
                                '${d['letto_at'] == null ? '' : ' · letto ${_formattaDataDb(d['letto_at'])}'}',
                              ),
                              if (errore != null && errore.isNotEmpty)
                                Text('Errore: $errore'),
                            ],
                          ),
                          trailing: _iconaStato(d['stato']?.toString()),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        IconButton(
          tooltip: 'Aggiorna',
          onPressed: _caricamento ? null : _carica,
          icon: const Icon(Icons.refresh),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Chiudi'),
        ),
      ],
    );
  }

  Widget _iconaStato(String? stato) {
    return switch (stato) {
      'inviato' => const Icon(Icons.check_circle_outline),
      'letto' => const Icon(Icons.mark_email_read_outlined),
      'errore' => const Icon(Icons.error_outline),
      'escluso_inattivo' => const Icon(Icons.person_off_outlined),
      'senza_dispositivo' => const Icon(Icons.phonelink_erase_outlined),
      _ => const Icon(Icons.schedule_outlined),
    };
  }
}

class _MessaggioManualeDialog extends StatefulWidget {
  const _MessaggioManualeDialog({
    required this.schema,
    this.messaggioEsistente,
  });

  final SchemaDatabase schema;
  final Map<String, dynamic>? messaggioEsistente;

  @override
  State<_MessaggioManualeDialog> createState() => _MessaggioManualeDialogState();
}

class _MessaggioManualeDialogState extends State<_MessaggioManualeDialog> {
  final _titolo = TextEditingController();
  final _messaggio = TextEditingController();
  String? _destinatari;
  String? _riferimentoId;
  String? _anno;
  DateTime? _programmataPer;
  List<Map<String, dynamic>> _opzioni = const [];
  final Set<String> _utentiManuali = <String>{};
  bool _caricamentoOpzioni = false;
  bool _salvataggio = false;
  String? _errore;

  bool get _modifica => widget.messaggioEsistente != null;

  List<String> get _tipiDestinatari => widget.schema
          .tabella('notifiche_messaggi')
          ?.campo('destinatari')
          ?.valoriScelta ??
      const <String>[];

  @override
  void initState() {
    super.initState();
    final esistente = widget.messaggioEsistente;
    if (esistente != null) {
      _titolo.text = esistente['titolo']?.toString() ?? '';
      _messaggio.text = esistente['messaggio']?.toString() ?? '';
      _destinatari = esistente['destinatari']?.toString();
      _programmataPer = DateTime.tryParse(
        esistente['programmata_per']?.toString() ?? '',
      )?.toLocal();

      final config = _configurazione(esistente['destinatari_configurazione']);
      _riferimentoId =
          config['evento_id']?.toString() ?? config['house_of_mentore_id']?.toString();
      _anno = config['anno_accademico']?.toString();
      final utenti = config['user_ids'];
      if (utenti is List) {
        _utentiManuali.addAll(utenti.map((e) => e.toString()));
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _caricaOpzioni(_destinatari);
      });
    }
  }

  Map<String, dynamic> _configurazione(Object? valore) {
    if (valore is Map) return Map<String, dynamic>.from(valore);
    if (valore is String && valore.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(valore);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  @override
  void dispose() {
    _titolo.dispose();
    _messaggio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_modifica ? 'Modifica notifica programmata' : 'Nuova notifica manuale'),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _titolo,
                decoration: const InputDecoration(labelText: 'Titolo'),
              ),
              TextField(
                controller: _messaggio,
                minLines: 4,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(labelText: 'Messaggio'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _tipiDestinatari.contains(_destinatari) ? _destinatari : null,
                decoration: const InputDecoration(labelText: 'Destinatari'),
                items: _tipiDestinatari
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) async {
                  setState(() {
                    _destinatari = v;
                    _riferimentoId = null;
                    _anno = null;
                    _utentiManuali.clear();
                    _opzioni = const [];
                  });
                  await _caricaOpzioni(v);
                },
              ),
              if (_caricamentoOpzioni) const LinearProgressIndicator(),
              if (_destinatari == 'iscritti_evento') _dropdownRiferimento('Evento'),
              if (_destinatari == 'iscritti_house_of_mentore')
                _dropdownRiferimento('House of Mentore'),
              if (_destinatari == 'anno_accademico') _dropdownAnno(),
              if (_destinatari == 'manuale') _selezioneManuale(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Invio'),
                subtitle: Text(
                  _programmataPer == null
                      ? 'Immediato'
                      : 'Programmato: ${_formattaDataOra(_programmataPer!)}',
                ),
                trailing: Wrap(
                  children: <Widget>[
                    if (_programmataPer != null)
                      IconButton(
                        tooltip: 'Invio immediato',
                        onPressed: () => setState(() => _programmataPer = null),
                        icon: const Icon(Icons.clear),
                      ),
                    IconButton(
                      tooltip: 'Programma data e ora',
                      onPressed: _scegliDataOra,
                      icon: const Icon(Icons.schedule),
                    ),
                  ],
                ),
              ),
              if (_errore != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_errore!),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _salvataggio ? null : () => Navigator.pop(context, false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _salvataggio ? null : _salva,
          child: Text(
            _modifica
                ? (_programmataPer == null ? 'Salva e invia' : 'Salva modifiche')
                : (_programmataPer == null ? 'Crea e invia' : 'Programma'),
          ),
        ),
      ],
    );
  }

  Widget _dropdownRiferimento(String label) {
    return DropdownButtonFormField<String>(
      initialValue: _opzioni.any((r) => r['id']?.toString() == _riferimentoId)
          ? _riferimentoId
          : null,
      decoration: InputDecoration(labelText: label),
      items: _opzioni
          .map(
            (r) => DropdownMenuItem<String>(
              value: r['id'].toString(),
              child: Text(_etichettaRecord(r)),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _riferimentoId = v),
    );
  }

  Widget _dropdownAnno() {
    return DropdownButtonFormField<String>(
      initialValue: _opzioni.any((r) => r['codice']?.toString() == _anno) ? _anno : null,
      decoration: const InputDecoration(labelText: 'Anno accademico'),
      items: _opzioni
          .map(
            (r) => DropdownMenuItem<String>(
              value: r['codice'].toString(),
              child: Text(r['codice'].toString()),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _anno = v),
    );
  }

  Widget _selezioneManuale() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Persone selezionate'),
      subtitle: Text('${_utentiManuali.length} selezionate'),
      children: _opzioni
          .map(
            (r) => CheckboxListTile(
              dense: true,
              value: _utentiManuali.contains(r['user_id']?.toString()),
              title: Text('${r['cognome'] ?? ''} ${r['nome'] ?? ''}'.trim()),
              subtitle: Text(r['email_unipa']?.toString() ?? ''),
              onChanged: (v) {
                final id = r['user_id']?.toString();
                if (id == null) return;
                setState(() {
                  if (v == true) {
                    _utentiManuali.add(id);
                  } else {
                    _utentiManuali.remove(id);
                  }
                });
              },
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _caricaOpzioni(String? tipo) async {
    if (tipo == null) return;
    setState(() => _caricamentoOpzioni = true);
    try {
      dynamic raw;
      switch (tipo) {
        case 'iscritti_evento':
          raw = await SupabaseConfig.client
              .from('eventi')
              .select()
              .order('created_at', ascending: false);
          break;
        case 'iscritti_house_of_mentore':
          raw = await SupabaseConfig.client
              .from('house_of_mentore')
              .select()
              .order('created_at', ascending: false);
          break;
        case 'anno_accademico':
          raw = await SupabaseConfig.client
              .from('anni_accademici')
              .select('codice, corrente')
              .order('codice', ascending: false);
          break;
        case 'manuale':
          raw = await SupabaseConfig.client.rpc(
            'notifiche_elenco_utenti_attivi',
          );
          break;
        default:
          raw = const <dynamic>[];
      }
      if (!mounted) return;
      setState(() {
        _opzioni = (raw as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errore = 'Impossibile caricare le opzioni: $e');
    } finally {
      if (mounted) setState(() => _caricamentoOpzioni = false);
    }
  }

  Future<void> _scegliDataOra() async {
    final now = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: _programmataPer ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (data == null || !mounted) return;
    final ora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_programmataPer ?? now),
    );
    if (ora == null) return;
    setState(() {
      _programmataPer = DateTime(data.year, data.month, data.day, ora.hour, ora.minute);
    });
  }

  Future<void> _salva() async {
    final titolo = _titolo.text.trim();
    final messaggio = _messaggio.text.trim();
    if (titolo.isEmpty || messaggio.isEmpty || _destinatari == null) {
      setState(() => _errore = 'Titolo, messaggio e destinatari sono obbligatori.');
      return;
    }
    if ((_destinatari == 'iscritti_evento' ||
            _destinatari == 'iscritti_house_of_mentore') &&
        _riferimentoId == null) {
      setState(() => _errore = 'Seleziona il riferimento.');
      return;
    }
    if (_destinatari == 'anno_accademico' && _anno == null) {
      setState(() => _errore = 'Seleziona l’anno accademico.');
      return;
    }
    if (_destinatari == 'manuale' && _utentiManuali.isEmpty) {
      setState(() => _errore = 'Seleziona almeno una persona attiva.');
      return;
    }

    final config = <String, dynamic>{};
    switch (_destinatari) {
      case 'iscritti_evento':
        config['evento_id'] = _riferimentoId;
        break;
      case 'iscritti_house_of_mentore':
        config['house_of_mentore_id'] = _riferimentoId;
        break;
      case 'anno_accademico':
        config['anno_accademico'] = _anno;
        break;
      case 'manuale':
        config['user_ids'] = _utentiManuali.toList();
        break;
    }

    setState(() {
      _salvataggio = true;
      _errore = null;
    });
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      final payload = <String, dynamic>{
        'titolo': titolo,
        'messaggio': messaggio,
        'destinatari': _destinatari,
        'destinatari_configurazione': jsonDecode(jsonEncode(config)),
        'programmata_per': _programmataPer?.toUtc().toIso8601String(),
        'stato': _programmataPer == null ? 'da_inviare' : 'programmato',
      };

      String messaggioId;
      if (_modifica) {
        final esistente = widget.messaggioEsistente!;
        messaggioId = esistente['id']?.toString() ?? '';
        if (messaggioId.isEmpty) {
          throw StateError('ID della notifica programmata non disponibile.');
        }

        await SupabaseConfig.client
            .from('notifiche_messaggi')
            .update(payload)
            .eq('id', messaggioId);

        // I destinatari possono essere cambiati durante la modifica.
        // Li rigeneriamo integralmente a partire dalla nuova configurazione.
        await SupabaseConfig.client
            .from('notifiche_destinatari')
            .delete()
            .eq('messaggio_id', messaggioId);
      } else {
        final record = await SupabaseConfig.client
            .from('notifiche_messaggi')
            .insert({
              'regola_id': null,
              ...payload,
              'creata_da': userId,
            })
            .select('id')
            .single();

        messaggioId = record['id']?.toString() ?? '';
        if (messaggioId.isEmpty) {
          throw StateError('Il database non ha restituito l’ID della notifica.');
        }
      }

      final numeroDestinatari = await SupabaseConfig.client.rpc(
        'notifiche_genera_destinatari',
        params: <String, dynamic>{'p_messaggio_id': messaggioId},
      );

      String dettaglioInvio = '';
      if (_programmataPer == null) {
        final risposta = await SupabaseConfig.client.functions.invoke(
          'notifiche-invia',
          body: <String, dynamic>{'messaggio_id': messaggioId},
        );
        if (risposta.status < 200 || risposta.status >= 300) {
          throw StateError(
            'Invio push non riuscito (HTTP ${risposta.status}): ${risposta.data}',
          );
        }
        dettaglioInvio = ' · invio push avviato';
      } else {
        dettaglioInvio = ' · invio programmato';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_modifica ? 'Notifica aggiornata' : 'Notifica creata'} · '
            '${numeroDestinatari ?? 0} destinatari attivi$dettaglioInvio.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errore = _modifica
            ? 'Modifica della notifica non riuscita.\n$e'
            : 'Creazione della notifica non riuscita.\n$e',
      );
    } finally {
      if (mounted) setState(() => _salvataggio = false);
    }
  }

  String _etichettaRecord(Map<String, dynamic> r) {
    final nomeTabella = switch (_destinatari) {
      'iscritti_evento' => 'eventi',
      'iscritti_house_of_mentore' => 'house_of_mentore',
      _ => null,
    };
    if (nomeTabella != null) {
      final tabella = widget.schema.tabella(nomeTabella);
      final campoDescrittivo = tabella?.nomeCampoDescrittivo;
      if (campoDescrittivo != null) {
        final valore = r[campoDescrittivo]?.toString().trim();
        if (valore != null && valore.isNotEmpty) return valore;
      }
    }
    return r['id']?.toString() ?? 'Record';
  }
}

String _formattaDataOra(DateTime d) {
  final g = d.day.toString().padLeft(2, '0');
  final m = d.month.toString().padLeft(2, '0');
  final h = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return '$g/$m/${d.year} $h:$min';
}

String _formattaDataDb(Object? valore) {
  if (valore == null) return '';
  final data = DateTime.tryParse(valore.toString());
  if (data == null) return valore.toString();
  return _formattaDataOra(data.toLocal());
}

// ============================================================================
// REGOLE
// ============================================================================

class NotificheRegoleBackofficePage extends StatefulWidget {
  const NotificheRegoleBackofficePage({super.key});

  @override
  State<NotificheRegoleBackofficePage> createState() =>
      _NotificheRegoleBackofficePageState();
}

class _NotificheRegoleBackofficePageState
    extends State<NotificheRegoleBackofficePage> {
  SchemaDatabase? _schema;
  List<Map<String, dynamic>> _regole = const [];
  bool _caricamento = true;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final risultati = await Future.wait<dynamic>([
        SupabaseConfig.caricaSchemaDatabase(),
        SupabaseConfig.client
            .from('notifiche_regole')
            .select()
            .order('codice'),
      ]);
      if (!mounted) return;
      setState(() {
        _schema = risultati[0] as SchemaDatabase;
        _regole = (risultati[1] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errore = 'Impossibile caricare le regole.\n$e');
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Regole automatiche',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Aggiorna',
              onPressed: _caricamento ? null : _carica,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _schema == null ? null : () => _modifica(),
              icon: const Icon(Icons.add),
              label: const Text('Nuova regola'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_caricamento) const LinearProgressIndicator(),
        if (_errore != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_errore!),
          ),
        Expanded(
          child: _regole.isEmpty && !_caricamento
              ? const Center(child: Text('Nessuna regola configurata.'))
              : ListView.separated(
                  itemCount: _regole.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final r = _regole[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          r['attiva'] == true
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_off_outlined,
                        ),
                        title: Text(r['descrizione']?.toString() ?? r['codice'].toString()),
                        subtitle: Text(_descrizioneRegola(r)),
                        trailing: Wrap(
                          spacing: 4,
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Modifica',
                              onPressed: () => _modifica(r),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Elimina',
                              onPressed: () => _elimina(r),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _descrizioneRegola(Map<String, dynamic> r) {
    final parti = <String>[
      r['tipo_attivazione']?.toString() ?? '',
      r['tabella']?.toString() ?? '',
    ];
    final campo = r['campo_data']?.toString();
    if (campo != null && campo.isNotEmpty) {
      final offset = (r['offset_giorni'] as num?)?.toInt() ?? 0;
      parti.add('$campo · ${offset >= 0 ? '+' : ''}$offset giorni');
    }
    final dataProgrammata = r['data_programmata']?.toString();
    if (dataProgrammata != null && dataProgrammata.isNotEmpty) {
      parti.add('invio $dataProgrammata');
    }
    parti.add('→ ${r['destinatari'] ?? ''}');
    return parti.where((v) => v.isNotEmpty).join(' · ');
  }

  Future<void> _modifica([Map<String, dynamic>? regola]) async {
    final schema = _schema;
    if (schema == null) return;
    final salvata = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RegolaDialog(schema: schema, regola: regola),
    );
    if (salvata == true) await _carica();
  }

  Future<void> _elimina(Map<String, dynamic> regola) async {
    final conferma = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Elimina regola'),
            content: Text('Eliminare “${regola['descrizione'] ?? regola['codice']}”?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Elimina'),
              ),
            ],
          ),
        ) ??
        false;
    if (!conferma) return;
    try {
      await SupabaseConfig.client
          .from('notifiche_regole')
          .delete()
          .eq('id', regola['id']);
      await _carica();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile eliminare la regola: $e')),
      );
    }
  }
}

class _RegolaDialog extends StatefulWidget {
  const _RegolaDialog({required this.schema, this.regola});

  final SchemaDatabase schema;
  final Map<String, dynamic>? regola;

  @override
  State<_RegolaDialog> createState() => _RegolaDialogState();
}

class _RegolaDialogState extends State<_RegolaDialog> {
  late final TextEditingController _codice;
  late final TextEditingController _descrizione;
  late final TextEditingController _offset;
  late final TextEditingController _titolo;
  late final TextEditingController _messaggio;
  late bool _attiva;
  String? _tipo;
  String? _tabella;
  String? _campoData;
  String? _destinatari;
  DateTime? _dataProgrammata;
  Set<String> _campiMonitorati = <String>{};
  final List<_CondizioneRegola> _condizioni = <_CondizioneRegola>[];
  bool _richiedeAttiva = false;
  bool _soloAnnoCorrente = true;
  String? _campoRiferimentoDestinatari;
  String? _tabellaDestinatariRelazionale;
  String? _campoUserIdDestinatariRelazionale;
  bool _salvataggio = false;
  String? _errore;

  CampoDatabase? get _campoTipo =>
      widget.schema.tabella('notifiche_regole')?.campo('tipo_attivazione');
  CampoDatabase? get _campoDestinatari =>
      widget.schema.tabella('notifiche_regole')?.campo('destinatari');

  List<String> get _tipi => _campoTipo?.valoriScelta ?? const <String>[];
  List<String> get _destinatariDisponibili =>
      _campoDestinatari?.valoriScelta ?? const <String>[];

  List<TabellaDatabase> get _tabelle {
    final result = widget.schema.tabelle
        .where((t) => t.eTabellaBase != false)
        .where((t) => !t.nome.startsWith('notifiche_'))
        .toList();
    result.sort((a, b) => a.nome.compareTo(b.nome));
    return result;
  }

  TabellaDatabase? get _tabellaSelezionata =>
      _tabella == null ? null : widget.schema.tabella(_tabella!);

  List<CampoDatabase> get _campiData => (_tabellaSelezionata?.campi ?? const [])
      .where((c) => c.tipo == TipoCampoDinamico.data || c.tipo == TipoCampoDinamico.dataOra)
      .toList(growable: false);

  String _campoIdPrincipale(TabellaDatabase tabella) {
    for (final campo in tabella.campi) {
      if (campo.chiavePrimaria) return campo.nome;
    }
    if (tabella.campo('id') != null) return 'id';
    return tabella.campi.isEmpty ? 'id' : tabella.campi.first.nome;
  }

  List<CampoDatabase> _campiDi(String? nomeTabella) =>
      nomeTabella == null
          ? const <CampoDatabase>[]
          : (widget.schema.tabella(nomeTabella)?.campi ?? const <CampoDatabase>[]);

  List<_PassoRelazione> _percorsoVerso(String? destinazione) {
    final sorgente = _tabella;
    if (sorgente == null || destinazione == null || sorgente == destinazione) {
      return const <_PassoRelazione>[];
    }
    return _trovaPercorsoRelazioni(widget.schema, sorgente, destinazione) ??
        const <_PassoRelazione>[];
  }

  String _descriviPercorso(List<_PassoRelazione> percorso) {
    if (percorso.isEmpty) {
      return _tabella == null ? 'Nessun percorso' : 'Stessa tabella principale';
    }
    return percorso
        .map((p) => '${p.daTabella}.${p.daCampo} = ${p.aTabella}.${p.aCampo}')
        .join('  →  ');
  }

  bool get _richiedeRiferimentoDestinatari => const <String>{
        'iscritti_evento',
        'iscritti_house_of_mentore',
        'mentor',
        'senior',
        'mentee',
        'mentor_senior',
        'mentor_senior_mentee',
      }.contains(_destinatari);

  @override
  void initState() {
    super.initState();
    final r = widget.regola;
    _codice = TextEditingController(text: r?['codice']?.toString() ?? '');
    _descrizione = TextEditingController(text: r?['descrizione']?.toString() ?? '');
    _offset = TextEditingController(text: (r?['offset_giorni'] ?? 0).toString());
    _titolo = TextEditingController(text: r?['titolo_template']?.toString() ?? '');
    _messaggio = TextEditingController(text: r?['messaggio_template']?.toString() ?? '');
    _attiva = r?['attiva'] != false;
    _tipo = r?['tipo_attivazione']?.toString();
    _tabella = r?['tabella']?.toString();
    _campoData = r?['campo_data']?.toString();
    _destinatari = r?['destinatari']?.toString();
    _dataProgrammata = DateTime.tryParse(r?['data_programmata']?.toString() ?? '')?.toLocal();
    final config = r?['configurazione'];
    if (config is Map) {
      if (config['campi_monitorati'] is List) {
        _campiMonitorati = (config['campi_monitorati'] as List)
            .map((e) => e.toString())
            .toSet();
      }
      _richiedeAttiva = config['richiede_attiva'] == true;
      _soloAnnoCorrente = config['solo_anno_corrente'] != false;
      _campoRiferimentoDestinatari =
          config['campo_riferimento_destinatari']?.toString();
      final destinatariRelazionali = config['destinatari_relazionali'];
      if (destinatariRelazionali is Map) {
        _tabellaDestinatariRelazionale =
            destinatariRelazionali['tabella']?.toString();
        _campoUserIdDestinatariRelazionale =
            destinatariRelazionali['campo_user_id']?.toString();
      }
      if (config['condizioni'] is List) {
        for (final raw in config['condizioni'] as List) {
          if (raw is Map) {
            _condizioni.add(
              _CondizioneRegola(
                tabella: raw['tabella']?.toString() ?? _tabella,
                campo: raw['campo']?.toString(),
                operatore: raw['operatore']?.toString() ?? 'eq',
                valore: raw['valore']?.toString(),
                percorso: (raw['percorso'] as List<dynamic>? ?? const [])
                    .whereType<Map>()
                    .map((e) => _PassoRelazione.fromJson(Map<String, dynamic>.from(e)))
                    .toList(growable: false),
              ),
            );
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _codice.dispose();
    _descrizione.dispose();
    _offset.dispose();
    _titolo.dispose();
    _messaggio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final programmata = _tipo == 'programmata';
    final temporale = _tipo == 'data';
    final update = _tipo == 'update';

    return AlertDialog(
      title: Text(widget.regola == null ? 'Nuova regola' : 'Modifica regola'),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _codice,
                decoration: const InputDecoration(labelText: 'Codice'),
              ),
              TextField(
                controller: _descrizione,
                decoration: const InputDecoration(labelText: 'Descrizione'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Regola attiva'),
                value: _attiva,
                onChanged: (v) => setState(() => _attiva = v),
              ),
              DropdownButtonFormField<String>(
                initialValue: _tipi.contains(_tipo) ? _tipo : null,
                decoration: const InputDecoration(labelText: 'Tipo attivazione'),
                items: _tipi
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _tipo = v;
                  if (v != 'data') _campoData = null;
                }),
              ),
              if (!programmata) ...<Widget>[
                DropdownButtonFormField<String>(
                  initialValue: _tabelle.any((t) => t.nome == _tabella) ? _tabella : null,
                  decoration: const InputDecoration(labelText: 'Tabella'),
                  items: _tabelle
                      .map((t) => DropdownMenuItem(value: t.nome, child: Text(t.nome)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _tabella = v;
                    _campoData = null;
                    _campiMonitorati.clear();
                    _condizioni.clear();
                    _campoRiferimentoDestinatari = null;
                    _tabellaDestinatariRelazionale = null;
                    _campoUserIdDestinatariRelazionale = null;
                  }),
                ),
              ],
              if (temporale) ...<Widget>[
                DropdownButtonFormField<String>(
                  initialValue: _campiData.any((c) => c.nome == _campoData) ? _campoData : null,
                  decoration: const InputDecoration(labelText: 'Campo data'),
                  items: _campiData
                      .map((c) => DropdownMenuItem(value: c.nome, child: Text(c.etichetta)))
                      .toList(),
                  onChanged: (v) => setState(() => _campoData = v),
                ),
                TextField(
                  controller: _offset,
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  decoration: const InputDecoration(
                    labelText: 'Offset giorni',
                    helperText: 'Valore negativo = prima; positivo = dopo; 0 = stesso giorno.',
                  ),
                ),
              ],
              if (programmata) _selettoreDataProgrammata(),
              if (update && _tabellaSelezionata != null) _selettoreCampiMonitorati(),
              if (!programmata && _tabellaSelezionata != null) ...<Widget>[
                if ((_tabellaSelezionata?.campo('attiva')) != null &&
                    (_tipo == 'insert' || _tipo == 'update'))
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Richiedi record attivo'),
                    subtitle: const Text('La regola scatta solo se il campo attiva è true.'),
                    value: _richiedeAttiva,
                    onChanged: (v) => setState(() => _richiedeAttiva = v),
                  ),
                if (temporale)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Solo anno accademico corrente'),
                    value: _soloAnnoCorrente,
                    onChanged: (v) => setState(() => _soloAnnoCorrente = v),
                  ),
                _selettoreCondizioni(),
              ],
              DropdownButtonFormField<String>(
                initialValue: _destinatariDisponibili.contains(_destinatari)
                    ? _destinatari
                    : null,
                decoration: const InputDecoration(labelText: 'Destinatari'),
                items: _destinatariDisponibili
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _destinatari = v;
                  if (v != 'relazionale') {
                    _tabellaDestinatariRelazionale = null;
                    _campoUserIdDestinatariRelazionale = null;
                  }
                }),
              ),
              if (_destinatari == 'relazionale' && _tabellaSelezionata != null)
                _selettoreDestinatariRelazionali(),
              if (_richiedeRiferimentoDestinatari && _tabellaSelezionata != null)
                DropdownButtonFormField<String>(
                  initialValue: (_tabellaSelezionata?.campi ?? const <CampoDatabase>[])
                          .any((c) => c.nome == _campoRiferimentoDestinatari)
                      ? _campoRiferimentoDestinatari
                      : ((_tabellaSelezionata?.campo('id')) != null ? 'id' : null),
                  decoration: const InputDecoration(
                    labelText: 'Campo riferimento destinatari',
                    helperText: 'Campo che contiene l’ID di evento, House of Mentore o mentoraggio.',
                  ),
                  items: (_tabellaSelezionata?.campi ?? const <CampoDatabase>[])
                      .map((c) => DropdownMenuItem(value: c.nome, child: Text(c.etichetta)))
                      .toList(growable: false),
                  onChanged: (v) => setState(() => _campoRiferimentoDestinatari = v),
                ),
              TextField(
                controller: _titolo,
                decoration: const InputDecoration(labelText: 'Titolo template'),
              ),
              TextField(
                controller: _messaggio,
                minLines: 4,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(labelText: 'Messaggio template'),
              ),
              if (_errore != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_errore!),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _salvataggio ? null : () => Navigator.pop(context, false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _salvataggio ? null : _salva,
          child: const Text('Salva'),
        ),
      ],
    );
  }

  Widget _selettoreCampiMonitorati() {
    final campi = _tabellaSelezionata!.campi;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Campi monitorati'),
      subtitle: Text(
        _campiMonitorati.isEmpty
            ? 'Qualsiasi modifica'
            : _campiMonitorati.join(', '),
      ),
      children: campi
          .map(
            (c) => CheckboxListTile(
              dense: true,
              title: Text(c.etichetta),
              subtitle: Text(c.nome),
              value: _campiMonitorati.contains(c.nome),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _campiMonitorati.add(c.nome);
                } else {
                  _campiMonitorati.remove(c.nome);
                }
              }),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _selettoreCondizioni() {
    const operatori = <String>[
      'is_null',
      'not_null',
      'eq',
      'neq',
      'true',
      'false',
    ];

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Condizioni opzionali'),
      subtitle: Text(
        _condizioni.isEmpty
            ? 'Nessuna condizione aggiuntiva'
            : '${_condizioni.length} condizioni (tutte devono essere vere)',
      ),
      children: <Widget>[
        for (var i = 0; i < _condizioni.length; i++)
          Builder(
            builder: (context) {
              final condizione = _condizioni[i];
              final tabellaCondizione = condizione.tabella ?? _tabella;
              final campi = _campiDi(tabellaCondizione);
              final percorso = _percorsoVerso(tabellaCondizione);
              final raggiungibile = tabellaCondizione == _tabella || percorso.isNotEmpty;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: _tabelle.any((t) => t.nome == tabellaCondizione)
                                  ? tabellaCondizione
                                  : null,
                              decoration: const InputDecoration(labelText: 'Tabella condizione'),
                              items: _tabelle
                                  .map((t) => DropdownMenuItem(value: t.nome, child: Text(t.nome)))
                                  .toList(growable: false),
                              onChanged: (v) => setState(() {
                                condizione.tabella = v;
                                condizione.campo = null;
                                condizione.percorso = _percorsoVerso(v);
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: campi.any((c) => c.nome == condizione.campo)
                                  ? condizione.campo
                                  : null,
                              decoration: const InputDecoration(labelText: 'Campo'),
                              items: campi
                                  .map((c) => DropdownMenuItem(value: c.nome, child: Text(c.etichetta)))
                                  .toList(growable: false),
                              onChanged: raggiungibile
                                  ? (v) => setState(() => condizione.campo = v)
                                  : null,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Rimuovi condizione',
                            onPressed: () => setState(() => _condizioni.removeAt(i)),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 8),
                          child: Text(
                            raggiungibile
                                ? 'Relazione: ${_descriviPercorso(percorso)}'
                                : 'Nessuna relazione FK trovata tra ${_tabella ?? '-'} e ${tabellaCondizione ?? '-'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: operatori.contains(condizione.operatore)
                                  ? condizione.operatore
                                  : 'eq',
                              decoration: const InputDecoration(labelText: 'Operatore'),
                              items: operatori
                                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                                  .toList(growable: false),
                              onChanged: (v) => setState(() => condizione.operatore = v ?? 'eq'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!const <String>{'is_null', 'not_null', 'true', 'false'}
                              .contains(condizione.operatore))
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: condizione.valore,
                                decoration: const InputDecoration(labelText: 'Valore'),
                                onChanged: (v) => condizione.valore = v,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _tabellaSelezionata == null
                ? null
                : () => setState(() {
                    _condizioni.add(
                      _CondizioneRegola(
                        tabella: _tabella,
                        campo: _tabellaSelezionata!.campi.isEmpty
                            ? null
                            : _tabellaSelezionata!.campi.first.nome,
                        operatore: 'eq',
                        percorso: const <_PassoRelazione>[],
                      ),
                    );
                  }),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi condizione'),
          ),
        ),
      ],
    );
  }

  Widget _selettoreDestinatariRelazionali() {
    final campi = _campiDi(_tabellaDestinatariRelazionale);
    final percorso = _percorsoVerso(_tabellaDestinatariRelazionale);
    final raggiungibile = _tabellaDestinatariRelazionale == _tabella || percorso.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Destinatari da tabella collegata', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _tabelle.any((t) => t.nome == _tabellaDestinatariRelazionale)
                  ? _tabellaDestinatariRelazionale
                  : null,
              decoration: const InputDecoration(labelText: 'Tabella destinatari'),
              items: _tabelle
                  .map((t) => DropdownMenuItem(value: t.nome, child: Text(t.nome)))
                  .toList(growable: false),
              onChanged: (v) => setState(() {
                _tabellaDestinatariRelazionale = v;
                _campoUserIdDestinatariRelazionale = null;
              }),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: campi.any((c) => c.nome == _campoUserIdDestinatariRelazionale)
                  ? _campoUserIdDestinatariRelazionale
                  : null,
              decoration: const InputDecoration(
                labelText: 'Campo user_id destinatario',
                helperText: 'Il valore del campo deve corrispondere allo user_id dell’anagrafica.',
              ),
              items: campi
                  .map((c) => DropdownMenuItem(value: c.nome, child: Text('${c.etichetta} (${c.nome})')))
                  .toList(growable: false),
              onChanged: raggiungibile
                  ? (v) => setState(() => _campoUserIdDestinatariRelazionale = v)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              raggiungibile
                  ? 'Percorso: ${_descriviPercorso(percorso)}'
                  : 'Nessun percorso FK trovato tra ${_tabella ?? '-'} e ${_tabellaDestinatariRelazionale ?? '-'}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _selettoreDataProgrammata() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Data e ora programmata'),
      subtitle: Text(
        _dataProgrammata == null ? 'Non selezionata' : _formattaDataOra(_dataProgrammata!),
      ),
      trailing: IconButton(
        tooltip: 'Seleziona',
        icon: const Icon(Icons.event_outlined),
        onPressed: () async {
          final data = await showDatePicker(
            context: context,
            initialDate: _dataProgrammata ?? DateTime.now(),
            firstDate: DateTime.now().subtract(const Duration(days: 1)),
            lastDate: DateTime.now().add(const Duration(days: 3650)),
          );
          if (data == null || !mounted) return;
          final ora = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(_dataProgrammata ?? DateTime.now()),
          );
          if (ora == null) return;
          setState(() {
            _dataProgrammata = DateTime(data.year, data.month, data.day, ora.hour, ora.minute);
          });
        },
      ),
    );
  }

  Future<void> _salva() async {
    final codice = _codice.text.trim();
    final descrizione = _descrizione.text.trim();
    final titolo = _titolo.text.trim();
    final messaggio = _messaggio.text.trim();
    if (codice.isEmpty || descrizione.isEmpty || _tipo == null ||
        _destinatari == null || titolo.isEmpty || messaggio.isEmpty) {
      setState(() => _errore = 'Compila tutti i campi obbligatori.');
      return;
    }
    if (_tipo != 'programmata' && _tabella == null) {
      setState(() => _errore = 'Seleziona una tabella.');
      return;
    }
    if (_tipo == 'data' && _campoData == null) {
      setState(() => _errore = 'Seleziona il campo data.');
      return;
    }
    if (_tipo == 'programmata' && _dataProgrammata == null) {
      setState(() => _errore = 'Seleziona data e ora programmate.');
      return;
    }
    for (final condizione in _condizioni) {
      final tabellaCondizione = condizione.tabella ?? _tabella;
      if (tabellaCondizione == null || condizione.campo == null) {
        setState(() => _errore = 'Completa tutte le condizioni opzionali.');
        return;
      }
      final percorso = _percorsoVerso(tabellaCondizione);
      if (tabellaCondizione != _tabella && percorso.isEmpty) {
        setState(() => _errore = 'La tabella $tabellaCondizione non è collegata alla tabella principale $_tabella.');
        return;
      }
      condizione.percorso = percorso;
    }
    if (_destinatari == 'relazionale') {
      if (_tabellaDestinatariRelazionale == null ||
          _campoUserIdDestinatariRelazionale == null) {
        setState(() => _errore = 'Configura tabella e campo dei destinatari relazionali.');
        return;
      }
      final percorso = _percorsoVerso(_tabellaDestinatariRelazionale);
      if (_tabellaDestinatariRelazionale != _tabella && percorso.isEmpty) {
        setState(() => _errore = 'La tabella destinatari non è collegata alla tabella principale.');
        return;
      }
    }

    final config = <String, dynamic>{};
    if (_campiMonitorati.isNotEmpty) {
      config['campi_monitorati'] = _campiMonitorati.toList()..sort();
    }
    if (_richiedeAttiva) config['richiede_attiva'] = true;
    if (_tipo == 'data') config['solo_anno_corrente'] = _soloAnnoCorrente;
    if (_tabellaSelezionata != null) {
      config['tabella_principale'] = _tabellaSelezionata!.nome;
      config['campo_id_principale'] = _campoIdPrincipale(_tabellaSelezionata!);
    }
    if (_richiedeRiferimentoDestinatari &&
        _campoRiferimentoDestinatari != null) {
      config['campo_riferimento_destinatari'] = _campoRiferimentoDestinatari;
    }
    if (_destinatari == 'relazionale') {
      final percorso = _percorsoVerso(_tabellaDestinatariRelazionale);
      config['destinatari_relazionali'] = <String, dynamic>{
        'tabella': _tabellaDestinatariRelazionale,
        'campo_user_id': _campoUserIdDestinatariRelazionale,
        'percorso': percorso.map((p) => p.toJson()).toList(growable: false),
      };
    }
    if (_condizioni.isNotEmpty) {
      config['condizioni'] = _condizioni
          .where((c) => c.campo != null && c.tabella != null)
          .map((c) => <String, dynamic>{
                'tabella': c.tabella,
                'campo': c.campo,
                'operatore': c.operatore,
                'percorso': c.percorso.map((p) => p.toJson()).toList(growable: false),
                if (c.valore != null && c.valore!.isNotEmpty) 'valore': c.valore,
              })
          .toList(growable: false);
    }

    final payload = <String, dynamic>{
      'codice': codice,
      'descrizione': descrizione,
      'attiva': _attiva,
      'tipo_attivazione': _tipo,
      'tabella': _tipo == 'programmata' ? null : _tabella,
      'campo_data': _tipo == 'data' ? _campoData : null,
      'offset_giorni': _tipo == 'data' ? (int.tryParse(_offset.text.trim()) ?? 0) : 0,
      'destinatari': _destinatari,
      'configurazione': jsonDecode(jsonEncode(config)),
      'titolo_template': titolo,
      'messaggio_template': messaggio,
    };

    final tabellaRegole = widget.schema.tabella('notifiche_regole');
    if (tabellaRegole?.campo('data_programmata') != null) {
      payload['data_programmata'] = _tipo == 'programmata'
          ? _dataProgrammata?.toUtc().toIso8601String()
          : null;
    }

    setState(() {
      _salvataggio = true;
      _errore = null;
    });
    try {
      final id = widget.regola?['id'];
      if (id == null) {
        await SupabaseConfig.client.from('notifiche_regole').insert(payload);
      } else {
        await SupabaseConfig.client.from('notifiche_regole').update(payload).eq('id', id);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errore = 'Salvataggio non riuscito.\n$e');
    } finally {
      if (mounted) setState(() => _salvataggio = false);
    }
  }

  String _formattaDataOra(DateTime d) {
    final g = d.day.toString().padLeft(2, '0');
    final m = d.month.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$g/$m/${d.year} $h:$min';
  }
}


class _CondizioneRegola {
  _CondizioneRegola({
    this.tabella,
    this.campo,
    this.operatore = 'eq',
    this.valore,
    this.percorso = const <_PassoRelazione>[],
  });

  String? tabella;
  String? campo;
  String operatore;
  String? valore;
  List<_PassoRelazione> percorso;
}

class _PassoRelazione {
  const _PassoRelazione({
    required this.daTabella,
    required this.daCampo,
    required this.aTabella,
    required this.aCampo,
  });

  final String daTabella;
  final String daCampo;
  final String aTabella;
  final String aCampo;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'da_tabella': daTabella,
        'da_campo': daCampo,
        'a_tabella': aTabella,
        'a_campo': aCampo,
      };

  factory _PassoRelazione.fromJson(Map<String, dynamic> json) =>
      _PassoRelazione(
        daTabella: json['da_tabella']?.toString() ?? '',
        daCampo: json['da_campo']?.toString() ?? '',
        aTabella: json['a_tabella']?.toString() ?? '',
        aCampo: json['a_campo']?.toString() ?? '',
      );
}

List<_PassoRelazione>? _trovaPercorsoRelazioni(
  SchemaDatabase schema,
  String sorgente,
  String destinazione,
) {
  if (sorgente == destinazione) return const <_PassoRelazione>[];

  final adiacenze = <String, List<_PassoRelazione>>{};
  void aggiungi(_PassoRelazione passo) {
    adiacenze.putIfAbsent(passo.daTabella, () => <_PassoRelazione>[]).add(passo);
  }

  for (final tabella in schema.tabelle) {
    for (final campo in tabella.campi) {
      final relazione = campo.relazione;
      if (relazione == null) continue;
      aggiungi(
        _PassoRelazione(
          daTabella: tabella.nome,
          daCampo: campo.nome,
          aTabella: relazione.tabella,
          aCampo: relazione.colonna,
        ),
      );
      aggiungi(
        _PassoRelazione(
          daTabella: relazione.tabella,
          daCampo: relazione.colonna,
          aTabella: tabella.nome,
          aCampo: campo.nome,
        ),
      );
    }
  }

  final coda = <({String tabella, List<_PassoRelazione> percorso})>[
    (tabella: sorgente, percorso: const <_PassoRelazione>[]),
  ];
  final visitate = <String>{sorgente};

  while (coda.isNotEmpty) {
    final corrente = coda.removeAt(0);
    for (final passo in adiacenze[corrente.tabella] ?? const <_PassoRelazione>[]) {
      if (visitate.contains(passo.aTabella)) continue;
      final nuovoPercorso = <_PassoRelazione>[...corrente.percorso, passo];
      if (passo.aTabella == destinazione) return nuovoPercorso;
      visitate.add(passo.aTabella);
      coda.add((tabella: passo.aTabella, percorso: nuovoPercorso));
    }
  }

  return null;
}
