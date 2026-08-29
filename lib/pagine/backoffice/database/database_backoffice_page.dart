import 'package:flutter/material.dart';

import '../../../ui/dinamico_schema.dart';
import '../../../ui/dinamico_maschera.dart';
import '../../../app/app_core.dart';
import '../../../app/app_session_controller.dart';
import 'database_backoffice_controller.dart';

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

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _DatabaseBackofficePageState extends State<DatabaseBackofficePage> {
  late final DatabaseBackofficeController backofficeController;
  SchemaDatabase? _schema;
  String? _errore;
  bool _caricamento = true;
  Set<String>? _tabelleBase;

  /// Inizializza lo stato della pagina e avvia le operazioni iniziali necessarie.
  @override
  void initState() {
    super.initState();
    backofficeController = DatabaseBackofficeController(
      database: widget.sessione.db,
    );
    _carica();
  }

  /// Gestisce l’operazione interna “carica” della pagina.
  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final schema = await backofficeController.caricaSchema();
      final tabelleBase = await backofficeController.caricaTabelleBase();
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

  /// Costruisce l’interfaccia grafica di questo componente.
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
                _UsersAuthEditor(
                  sessione: widget.sessione,
                  controller: backofficeController,
                ),
                for (final tabella in tabelle)
                  _TabellaDatabaseEditor(
                    tabella: tabella,
                    sessione: widget.sessione,
                    controller: backofficeController,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Modello o componente interno “TabellaDatabaseEditor” usato esclusivamente da questo file.
class _TabellaDatabaseEditor extends StatefulWidget {
  const _TabellaDatabaseEditor({
    required this.tabella,
    required this.sessione,
    required this.controller,
  });

  final TabellaDatabase tabella;
  final SessioneController sessione;
  final DatabaseBackofficeController controller;

  @override
  State<_TabellaDatabaseEditor> createState() => _TabellaDatabaseEditorState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _TabellaDatabaseEditorState extends State<_TabellaDatabaseEditor> {
  List<Map<String, dynamic>> _righe = const [];
  bool _caricamento = true;
  String? _errore;

  List<CampoDatabase> get _pk =>
      widget.tabella.campi.where((c) => c.chiavePrimaria).toList();

  /// Inizializza lo stato della pagina e avvia le operazioni iniziali necessarie.
  @override
  void initState() {
    super.initState();
    _carica();
  }

  /// Gestisce l’operazione interna “carica” della pagina.
  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final dati = await widget.controller.caricaTabella(widget.tabella.nome);
      if (!mounted) return;
      setState(() => _righe = dati);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errore = e.toString());
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  /// Costruisce l’interfaccia grafica di questo componente.
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

  /// Costruisce il titolo relativo a riga.
  String _titoloRiga(Map<String, dynamic> riga) {
    final descrittivo = widget.tabella.nomeCampoDescrittivo;
    if (descrittivo != null) return riga[descrittivo]?.toString() ?? '—';
    if (_pk.isNotEmpty) {
      return _pk.map((c) => riga[c.nome]?.toString() ?? '—').join(' · ');
    }
    return widget.tabella.nome;
  }

  /// Costruisce il sottotitolo relativo a riga.
  String _sottotitoloRiga(Map<String, dynamic> riga) => riga.entries
      .take(4)
      .map((e) => '${e.key}: ${e.value ?? '—'}')
      .join(' · ');

  /// Apre e gestisce l’editor del record.
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
        await widget.controller.inserisci(widget.tabella.nome, valori);
      } else {
        if (_pk.isEmpty) {
          throw StateError('La tabella non ha una chiave primaria modificabile.');
        }
        await widget.controller.aggiorna(
          widget.tabella.nome,
          valori,
          <String, dynamic>{
            for (final campo in _pk) campo.nome: esistente[campo.nome],
          },
        );
      }
      await _carica();
    } catch (e) {
      if (!mounted) return;
      final eccezione = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile salvare la riga.',
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(eccezione.messaggio)));
    }
  }

  /// Gestisce l’operazione interna “elimina” della pagina.
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
      await widget.controller.elimina(
        widget.tabella.nome,
        <String, dynamic>{
          for (final campo in _pk) campo.nome: riga[campo.nome],
        },
      );
      await _carica();
    } catch (e) {
      if (!mounted) return;
      final eccezione = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile eliminare la riga.',
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(eccezione.messaggio)));
    }
  }
}

/// Tab virtuale per `auth.users`.
/// Usa esclusivamente la Edge Function server-side: la service role non entra mai nel client.
class _UsersAuthEditor extends StatefulWidget {
  const _UsersAuthEditor({
    required this.sessione,
    required this.controller,
  });

  final SessioneController sessione;
  final DatabaseBackofficeController controller;

  @override
  State<_UsersAuthEditor> createState() => _UsersAuthEditorState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _UsersAuthEditorState extends State<_UsersAuthEditor> {
  List<Map<String, dynamic>> _utenti = const [];
  bool _caricamento = true;
  String? _errore;

  /// Inizializza lo stato della pagina e avvia le operazioni iniziali necessarie.
  @override
  void initState() {
    super.initState();
    _carica();
  }

  /// Inoltra le operazioni Auth alla Edge Function tramite il controller.
  Future<Map<String, dynamic>> _invoca(Map<String, dynamic> body) =>
      widget.controller.invocaUserAdmin(body);

  /// Gestisce l’operazione interna “carica” della pagina.
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

  /// Costruisce l’interfaccia grafica di questo componente.
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

  /// Esegue l’azione richiesta dalla pagina.
  Future<void> _azione(Map<String, dynamic> body) async {
    try {
      await _invoca(body);
      await _carica();
    } catch (e) {
      if (!mounted) return;
      final eccezione = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Operazione non riuscita.',
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(eccezione.messaggio)));
    }
  }

  /// Gestisce la modifica di email.
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

  /// Gestisce l’operazione interna “reimposta password” della pagina.
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

  /// Gestisce l’operazione interna “elimina” della pagina.
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
