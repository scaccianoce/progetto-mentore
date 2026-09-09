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

  /// Espone al servizio push soltanto lo stato logico di autenticazione,
  /// senza propagare tipi Supabase al livello `supporto`.
  Stream<bool> get cambiStatoAutenticazione => _client.auth.onAuthStateChange
      .map((stato) => stato.session?.user != null)
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
        ordinamenti: const <OrdineDb>[
          OrdineDb('created_at', crescente: false),
        ],
        limite: limite,
      );

  Future<List<Map<String, dynamic>>> destinatariMessaggio(
    String messaggioId,
  ) =>
      _database.rpcElenco(
        'notifiche_dettaglio_destinatari',
        parametri: <String, dynamic>{
          'p_messaggio_id': messaggioId,
        },
      );

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
