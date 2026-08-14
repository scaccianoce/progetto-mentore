import 'package:flutter/material.dart';

import '../../dinamico/maschera_dinamica_controller.dart';
import '../../dinamico/maschera_dinamica_widget.dart';
import '../../sessione_controller.dart';
import '../../supabase_config.dart';

/// Accesso diretto alle tabelle del database. RISERVATO A OWNER.
///
/// Le tab vengono create dallo schema restituito da `app_database_schema`:
/// nessun nome di tabella e codificato nel frontend.
class DatabaseBackofficePage extends StatefulWidget {
  const DatabaseBackofficePage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<DatabaseBackofficePage> createState() => _DatabaseBackofficePageState();
}

class _DatabaseBackofficePageState extends State<DatabaseBackofficePage> {
  SchemaDatabase? _schema;
  String? _errore;
  bool _caricamento = true;
  Set<String>? _tabelleBase;

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
      final schema = await SupabaseConfig.caricaSchemaDatabase(
        forzaAggiornamento: true,
      );
      Set<String>? tabelleBase;
      try {
        final risposta = await SupabaseConfig.client.rpc(
          'app_database_base_tables',
        );
        if (risposta is List) {
          tabelleBase = risposta
              .map((e) => e is Map ? e['name'] : e)
              .where((e) => e != null)
              .map((e) => e.toString())
              .toSet();
        }
      } catch (_) {
        // Compatibilita con installazioni precedenti: se la RPC dedicata non
        // e ancora installata usiamo il tipo eventualmente esposto dallo schema.
      }
      if (!mounted) return;
      setState(() {
        _schema = schema;
        _tabelleBase = tabelleBase;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errore = e.toString());
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessione.ruolo != AppRole.owner) {
      return const SizedBox.shrink();
    }
    if (_caricamento) return const Center(child: CircularProgressIndicator());
    if (_errore != null) {
      return Center(child: Text('Impossibile leggere lo schema DB.\n$_errore'));
    }
    final tabelle = [...?_schema?.tabelle]
        .where((tabella) {
          final nomi = _tabelleBase;
          if (nomi != null) return nomi.contains(tabella.nome);
          return tabella.eTabellaBase != false;
        })
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
    if (tabelle.isEmpty) return const Center(child: Text('Nessuna tabella.'));

    // `Users` e una tab virtuale: proviene da auth.users tramite Edge Function,
    // non dallo schema public/PostgREST. E visibile solo all'owner.
    final numeroTab = tabelle.length + 1;

    return DefaultTabController(
      length: numeroTab,
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Database diretto · solo owner',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Ricarica schema',
                onPressed: _carica,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          TabBar(
            isScrollable: true,
            tabs: [
              const Tab(text: 'Users'),
              for (final tabella in tabelle) Tab(text: tabella.nome),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _UsersAuthEditor(sessione: widget.sessione),
                for (final tabella in tabelle)
                  _TabellaDatabaseEditor(
                    tabella: tabella,
                    sessione: widget.sessione,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabellaDatabaseEditor extends StatefulWidget {
  const _TabellaDatabaseEditor({
    required this.tabella,
    required this.sessione,
  });

  final TabellaDatabase tabella;
  final SessioneController sessione;

  @override
  State<_TabellaDatabaseEditor> createState() => _TabellaDatabaseEditorState();
}

class _TabellaDatabaseEditorState extends State<_TabellaDatabaseEditor> {
  List<Map<String, dynamic>> _righe = const [];
  bool _caricamento = true;
  String? _errore;

  List<CampoDatabase> get _pk =>
      widget.tabella.campi.where((c) => c.chiavePrimaria).toList();

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
      final dati = await SupabaseConfig.client
          .from(widget.tabella.nome)
          .select()
          .limit(500);
      if (!mounted) return;
      setState(() => _righe = dati.cast<Map<String, dynamic>>());
    } catch (e) {
      if (!mounted) return;
      setState(() => _errore = e.toString());
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessione.ruolo != AppRole.owner) {
      return const SizedBox.shrink();
    }
    if (_caricamento) return const Center(child: CircularProgressIndicator());
    if (_errore != null) return Center(child: Text(_errore!));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text('${_righe.length} record (max 500)')),
              FilledButton.icon(
                onPressed: () => _editor(),
                icon: const Icon(Icons.add),
                label: const Text('Nuovo'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _righe.length,
            itemBuilder: (context, index) {
              final riga = _righe[index];
              return Card(
                child: ListTile(
                  title: Text(_titoloRiga(riga)),
                  subtitle: Text(_sottotitoloRiga(riga)),
                  onTap: () => _editor(esistente: riga),
                  trailing: _pk.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Elimina',
                          onPressed: () => _elimina(riga),
                          icon: const Icon(Icons.delete_outline),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _titoloRiga(Map<String, dynamic> riga) {
    final descrittivo = widget.tabella.nomeCampoDescrittivo;
    if (descrittivo != null) return riga[descrittivo]?.toString() ?? '—';
    if (_pk.isNotEmpty) {
      return _pk.map((c) => riga[c.nome]?.toString() ?? '—').join(' · ');
    }
    return widget.tabella.nome;
  }

  String _sottotitoloRiga(Map<String, dynamic> riga) => riga.entries
      .take(4)
      .map((e) => '${e.key}: ${e.value ?? '—'}')
      .join(' · ');

  Future<void> _editor({Map<String, dynamic>? esistente}) async {
    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: ConfigurazionePaginaDinamica(
        tabella: widget.tabella.nome,
        // Database diretto: l'owner deve vedere TUTTE le colonne, anche quelle
        // normalmente nascoste dal frontend (id, created_at, updated_at o
        // @app:hidden). Le PK restano readonly in modifica e i campi identity/
        // generated sono mostrati ma non modificabili dal motore dinamico.
        campi: <String, PersonalizzazioneCampo>{
          for (final campo in widget.tabella.campi)
            campo.nome: PersonalizzazioneCampo(
              nascosto: false,
              solaLettura: esistente != null && campo.chiavePrimaria,
            ),
        },
      ),
      partecipante: false,
      mostraCampiSolaLettura: true,
      valoriIniziali: esistente ?? const <String, dynamic>{},
      titolo: esistente == null
          ? 'Nuovo record · ${widget.tabella.nome}'
          : 'Modifica · ${widget.tabella.nome}',
    );
    if (valori == null) return;
    try {
      if (esistente == null) {
        await SupabaseConfig.client.from(widget.tabella.nome).insert(valori);
      } else {
        if (_pk.isEmpty) {
          throw StateError('La tabella non ha una chiave primaria modificabile.');
        }
        dynamic query = SupabaseConfig.client.from(widget.tabella.nome).update(valori);
        for (final campo in _pk) {
          query = query.eq(campo.nome, esistente[campo.nome]);
        }
        await query;
      }
      await _carica();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _elimina(Map<String, dynamic> riga) async {
    if (_pk.isEmpty) return;
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare il record?'),
        content: Text(_titoloRiga(riga)),
        actions: [
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
    );
    if (conferma != true) return;
    try {
      dynamic query = SupabaseConfig.client.from(widget.tabella.nome).delete();
      for (final campo in _pk) {
        query = query.eq(campo.nome, riga[campo.nome]);
      }
      await query;
      await _carica();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// Tab virtuale per `auth.users`.
/// Usa esclusivamente la Edge Function server-side: la service role non entra mai nel client.
class _UsersAuthEditor extends StatefulWidget {
  const _UsersAuthEditor({required this.sessione});

  final SessioneController sessione;

  @override
  State<_UsersAuthEditor> createState() => _UsersAuthEditorState();
}

class _UsersAuthEditorState extends State<_UsersAuthEditor> {
  List<Map<String, dynamic>> _utenti = const [];
  bool _caricamento = true;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<Map<String, dynamic>> _invoca(Map<String, dynamic> body) async {
    final risposta = await SupabaseConfig.client.functions.invoke(
      'backoffice-user-admin',
      body: body,
    );
    final data = risposta.data;
    if (data is String &&
        data.trimLeft().toLowerCase().startsWith('<!doctype html')) {
      throw StateError(
        'La chiamata a backoffice-user-admin ha ricevuto la pagina HTML di Flutter. '
        'Deploya la Edge Function su Supabase e verifica SUPABASE_URL.',
      );
    }
    if (risposta.status < 200 || risposta.status >= 300) {
      throw StateError('Edge Function (${risposta.status}): $data');
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    throw StateError('Risposta non JSON dalla Edge Function: $data');
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final data = await _invoca({
        'action': 'list_users',
        'page': 1,
        'per_page': 1000,
      });
      final raw = data['users'];
      final utenti = raw is List
          ? raw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
      utenti.sort(
        (a, b) => (a['email'] ?? '').toString().compareTo(
          (b['email'] ?? '').toString(),
        ),
      );
      if (!mounted) return;
      setState(() => _utenti = utenti);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errore = e.toString());
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessione.ruolo != AppRole.owner) {
      return const SizedBox.shrink();
    }
    if (_caricamento) return const Center(child: CircularProgressIndicator());
    if (_errore != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errore!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _carica,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text('${_utenti.length} utenti Auth (max 1000)')),
              IconButton(
                tooltip: 'Ricarica Users',
                onPressed: _carica,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _utenti.length,
            itemBuilder: (context, index) {
              final u = _utenti[index];
              final id = (u['id'] ?? '').toString();
              final email = (u['email'] ?? '—').toString();
              final confermata =
                  u['email_confirmed_at'] != null || u['confirmed_at'] != null;
              final bannato =
                  u['banned_until'] != null &&
                  u['banned_until'].toString().isNotEmpty;
              return Card(
                child: ExpansionTile(
                  title: Text(email),
                  subtitle: Text(
                    'ID: $id${confermata ? ' · email confermata' : ' · email NON confermata'}${bannato ? ' · disabilitato' : ''}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final e in u.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text('${e.key}: ${e.value ?? '—'}'),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _modificaEmail(id, email),
                                icon: const Icon(Icons.email_outlined),
                                label: const Text('Modifica email'),
                              ),
                              if (!confermata)
                                OutlinedButton.icon(
                                  onPressed: () => _azione({
                                    'action': 'confirm_email',
                                    'user_id': id,
                                  }),
                                  icon: const Icon(Icons.mark_email_read_outlined),
                                  label: const Text('Conferma email'),
                                ),
                              OutlinedButton.icon(
                                onPressed: () => _reimpostaPassword(id),
                                icon: const Icon(Icons.password),
                                label: const Text('Reimposta password'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _azione({
                                  'action': 'set_banned',
                                  'user_id': id,
                                  'banned': !bannato,
                                }),
                                icon: Icon(bannato ? Icons.lock_open : Icons.block),
                                label: Text(bannato ? 'Riabilita' : 'Disabilita'),
                              ),
                              FilledButton.icon(
                                onPressed: () => _elimina(id, email),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Elimina Auth user'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _azione(Map<String, dynamic> body) async {
    try {
      await _invoca(body);
      await _carica();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _modificaEmail(String id, String attuale) async {
    final controller = TextEditingController(text: attuale);
    final valore = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifica email Auth'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (valore == null || valore.isEmpty || !mounted) return;
    await _azione({'action': 'update_email', 'user_id': id, 'email': valore});
  }

  Future<void> _reimpostaPassword(String id) async {
    final controller = TextEditingController();
    final valore = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuova password temporanea'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password (minimo 8 caratteri)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Imposta'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (valore == null || valore.length < 8 || !mounted) return;
    await _azione({
      'action': 'reset_password',
      'user_id': id,
      'password': valore,
    });
  }

  Future<void> _elimina(String id, String email) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare l utente Auth?'),
        content: Text(
          '$email\n\nQuesta operazione elimina auth.users. Le tabelle applicative possono avere vincoli FK o storico separato.',
        ),
        actions: [
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
    );
    if (ok != true || !mounted) return;
    await _azione({'action': 'delete_user', 'user_id': id});
  }
}
