import 'package:supabase_flutter/supabase_flutter.dart';

import 'repository_database.dart';

/// Repository separato dedicato al sottosistema notifiche.
///
/// Resta volutamente autonomo dal resto dell'accesso dati perché coordina
/// anche autenticazione, RPC dedicate ed Edge Function. Le normali operazioni
/// sulle tabelle vengono comunque delegate a [DatabaseRepository], evitando
/// di duplicare il CRUD generico.
class NotificheRepository {
  NotificheRepository({
    DatabaseRepository? database,
    SupabaseClient? client,
  })  : _client = client ?? SupabaseConfig.client,
        _database = database ??
            DatabaseRepository(client: client ?? SupabaseConfig.client);

  final SupabaseClient _client;
  final DatabaseRepository _database;

  String? get userIdCorrente => _client.auth.currentUser?.id;

  bool get utenteAutenticato => userIdCorrente != null;

  /// Espone al servizio push l'utente della sessione corrente senza propagare
  /// tipi Supabase al livello `supporto`.
  ///
  /// L'ID, invece di un semplice booleano, permette di rilevare anche un
  /// eventuale cambio diretto di account sullo stesso dispositivo.
  Stream<String?> get cambiUtenteAutenticato => _client.auth.onAuthStateChange
      .map((stato) => stato.session?.user.id)
      .distinct();

  /// Conta le notifiche inviate ma non ancora lette dall'utente corrente.
  Future<int> contaNotificheNonLette() async {
    final userId = userIdCorrente;
    if (userId == null) return 0;

    final righe = await _database.tabella('notifiche_destinatari').elenco(
      colonne: 'id',
      filtri: <FiltroDb>[
        FiltroDb.uguale('user_id', userId),
        const FiltroDb.uguale('stato', 'inviato'),
      ],
    );

    return righe.length;
  }

  Future<void> registraDispositivo({
    required String token,
    required String piattaforma,
  }) async {
    await _database.rpc(
      'notifiche_registra_dispositivo',
      parametri: <String, dynamic>{
        'p_token': token,
        'p_piattaforma': piattaforma,
      },
    );
  }

  Future<void> disattivaDispositivo(String token) async {
    await _database.rpc(
      'notifiche_disattiva_dispositivo',
      parametri: <String, dynamic>{
        'p_token': token,
      },
    );
  }

  Future<List<Map<String, dynamic>>> messaggi({
    int limite = 200,
  }) =>
      _database.tabella('notifiche_messaggi').elenco(
        colonne:
            'id, regola_id, anno_accademico, titolo, messaggio, destinatari, '
            'destinatari_configurazione, origine_tabella, origine_id, '
            'programmata_per, inviata_at, stato, created_at, '
            'invia_push, invia_email, tipo_messaggio, tipo_evento_utente',
        ordinamenti: const <OrdineDb>[
          OrdineDb('created_at', crescente: false),
        ],
        limite: limite,
      );

  Future<List<Map<String, dynamic>>> destinatariMessaggio(
    String messaggioId,
  ) async {
    final destinatari = await _database.tabella('notifiche_destinatari').elenco(
      colonne:
          'id, user_id, stato, inviato_at, letto_at, errore, created_at, '
          'push_stato, push_tentativi, push_inviata_at, push_errore, '
          'email_stato, email_tentativi, email_programmata_per, '
          'email_inviata_at, email_errore',
      filtri: <FiltroDb>[
        FiltroDb.uguale('messaggio_id', messaggioId),
      ],
      ordinamenti: const <OrdineDb>[
        OrdineDb('created_at', crescente: true),
      ],
    );

    final userIds = destinatari
        .map((r) => r['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final anagrafica = userIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _database.tabella('anagrafica').elenco(
            colonne: 'user_id, nome, cognome, email_unipa',
            filtri: <FiltroDb>[
              FiltroDb.inLista('user_id', userIds.cast<Object>()),
            ],
          );

    final perUserId = <String, Map<String, dynamic>>{
      for (final r in anagrafica)
        (r['user_id']?.toString() ?? ''): Map<String, dynamic>.from(r),
    };

    return destinatari.map((r) {
      final userId = r['user_id']?.toString() ?? '';
      final persona = perUserId[userId] ?? const <String, dynamic>{};
      return <String, dynamic>{
        ...Map<String, dynamic>.from(r),
        'nome': persona['nome'],
        'cognome': persona['cognome'],
        'email_unipa': persona['email_unipa'],
      };
    }).toList(growable: false);
  }

  /// Restituisce le scelte necessarie al dialog di creazione manuale.
  Future<List<Map<String, dynamic>>> opzioniDestinatari(String tipo) {
    return switch (tipo) {
      'iscritti_evento' => _database.tabella('eventi').elenco(
          ordinamenti: const <OrdineDb>[
            OrdineDb('created_at', crescente: false),
          ],
        ),
      'iscritti_house_of_mentore' =>
        _database.tabella('house_of_mentore').elenco(
          ordinamenti: const <OrdineDb>[
            OrdineDb('created_at', crescente: false),
          ],
        ),
      'anno_accademico' => _database.tabella('anni_accademici').elenco(
          colonne: 'codice, corrente',
          ordinamenti: const <OrdineDb>[
            OrdineDb('codice', crescente: false),
          ],
        ),
      'manuale' => _database.rpcElenco('notifiche_elenco_utenti_attivi'),
      _ => Future<List<Map<String, dynamic>>>.value(
          const <Map<String, dynamic>>[],
        ),
    };
  }

  /// Crea un messaggio e restituisce il relativo ID.
  Future<String> creaMessaggio(Map<String, dynamic> valori) async {
    final riga = await _database
        .tabella('notifiche_messaggi')
        .inserisci(valori, colonne: 'id');

    final id = riga['id']?.toString() ?? '';
    if (id.isEmpty) {
      throw StateError('Il database non ha restituito l’ID della notifica.');
    }
    return id;
  }

  Future<void> aggiornaMessaggio(
    String messaggioId,
    Map<String, dynamic> valori,
  ) async {
    await _database.tabella('notifiche_messaggi').aggiorna(
      valori,
      filtri: <FiltroDb>[
        FiltroDb.uguale('id', messaggioId),
      ],
      colonne: 'id',
    );
  }

  Future<void> eliminaMessaggio(String messaggioId) =>
      _database.tabella('notifiche_messaggi').elimina(
        filtri: <FiltroDb>[
          FiltroDb.uguale('id', messaggioId),
        ],
      );

  Future<void> eliminaDestinatari(String messaggioId) =>
      _database.tabella('notifiche_destinatari').elimina(
        filtri: <FiltroDb>[
          FiltroDb.uguale('messaggio_id', messaggioId),
        ],
      );

  /// Genera i destinatari e restituisce il numero calcolato dalla RPC.
  Future<int> generaDestinatari(String messaggioId) async {
    final raw = await _database
        .rpc(
          'notifiche_genera_destinatari',
          parametri: <String, dynamic>{
            'p_messaggio_id': messaggioId,
          },
        )
        .timeout(const Duration(seconds: 30));

    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  /// Invoca la Edge Function che effettua l'invio push.
  ///
  /// La chiamata rimane qui perché non è un'operazione CRUD di tabella.
  Future<void> inviaMessaggio(String messaggioId) async {
    try {
      final session = _client.auth.currentSession;
      if (session == null || session.accessToken.isEmpty) {
        throw StateError('Sessione Supabase non disponibile per l’invio.');
      }

      final risposta = await _client.functions
          .invoke(
            'notifiche-invia',
            headers: <String, String>{
              'apikey': SupabaseConfig.publishableKey,
              'Authorization': 'Bearer ${session.accessToken}',
            },
            body: <String, dynamic>{
              'messaggio_id': messaggioId,
            },
          )
          .timeout(const Duration(seconds: 30));

      if (risposta.status < 200 || risposta.status >= 300) {
        throw StateError(
          'Invio push non riuscito '
          '(HTTP ${risposta.status}): ${risposta.data}',
        );
      }
    } catch (_) {
      try {
        await aggiornaMessaggio(
          messaggioId,
          <String, dynamic>{
            'stato': 'errore',
          },
        );
      } catch (_) {
        // Non maschera l'errore originario dell'Edge Function.
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> notificheRicevute({
    int limite = 20,
  }) async {
    final userId = userIdCorrente;
    if (userId == null) return const <Map<String, dynamic>>[];

    return _database.tabella('notifiche_destinatari').elenco(
      colonne:
          'id, messaggio_id, stato, inviato_at, letto_at, created_at',
      filtri: <FiltroDb>[
        FiltroDb.uguale('user_id', userId),
        const FiltroDb.inLista(
          'stato',
          <Object>['inviato', 'letto'],
        ),
      ],
      ordinamenti: const <OrdineDb>[
        OrdineDb('created_at', crescente: false),
      ],
      limite: limite,
    );
  }

  Future<List<Map<String, dynamic>>> messaggiPerIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const <Map<String, dynamic>>[];

    return _database.tabella('notifiche_messaggi').elenco(
      colonne:
          'id, titolo, messaggio, anno_accademico, origine_tabella, '
          'origine_id, inviata_at, created_at',
      filtri: <FiltroDb>[
        FiltroDb.inLista('id', ids.cast<Object>()),
      ],
    );
  }

  Future<void> segnaDestinatarioLetto(String destinatarioId) async {
    await _database.rpc(
      'notifiche_segna_letta',
      parametri: <String, dynamic>{
        'p_destinatario_id': destinatarioId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> regole() =>
      _database.tabella('notifiche_regole').elenco(
        ordinamenti: const <OrdineDb>[
          OrdineDb('codice'),
        ],
      );

  Future<void> impostaRegolaAttiva(String id, bool attiva) async {
    await _database.tabella('notifiche_regole').aggiorna(
      <String, dynamic>{'attiva': attiva},
      filtri: <FiltroDb>[
        FiltroDb.uguale('id', id),
      ],
      colonne: 'id',
    );
  }

  Future<void> eliminaRegola(Object id) =>
      _database.tabella('notifiche_regole').elimina(
        filtri: <FiltroDb>[
          FiltroDb.uguale('id', id),
        ],
      );

  Future<void> salvaRegola({
    Object? id,
    required Map<String, dynamic> valori,
  }) async {
    final tabella = _database.tabella('notifiche_regole');

    if (id == null) {
      await tabella.inserisci(valori, colonne: 'id');
      return;
    }

    await tabella.aggiorna(
      valori,
      filtri: <FiltroDb>[
        FiltroDb.uguale('id', id),
      ],
      colonne: 'id',
    );
  }
}
