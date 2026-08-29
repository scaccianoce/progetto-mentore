import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/app_core.dart';

// ============================================================================
// ACCESSO GENERICO AL DATABASE
// ============================================================================
//
// Questo file non conosce News, Eventi, Contatti, Mentoraggi o altre funzioni
// dell'applicazione. Il controller della pagina sceglie la tabella da usare:
//
//   final news = db.tabella('news');
//   final righe = await news.elenco(...);
//
// Sicurezza, RLS, foreign key, UNIQUE, CHECK e NOT NULL restano responsabilita'
// del database. Questo livello si limita a eseguire l'operazione e a tradurre
// gli errori tecnici in AppException.
// ============================================================================

/// Configurazione e inizializzazione del client Supabase.
///
/// Rimane nel livello dati per evitare che pagine e controller conoscano
/// direttamente il client Supabase.
abstract final class SupabaseConfig {
  static const String url = AppConfig.supabaseUrl;
  static const String publishableKey = AppConfig.supabasePublishableKey;

  /// Inizializza Supabase prima dell'avvio dell'applicazione.
  static Future<void> inizializza() async {
    if (url.trim().isEmpty || publishableKey.trim().isEmpty) {
      throw StateError(
        'Configurazione Supabase mancante. Avvia l\'app passando '
        'SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY con --dart-define.',
      );
    }

    final indirizzo = Uri.tryParse(url);
    if (indirizzo == null || !indirizzo.hasScheme || !indirizzo.hasAuthority) {
      throw StateError('SUPABASE_URL non contiene un indirizzo valido.');
    }

    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  /// Client Supabase condiviso dal solo livello dati.
  static SupabaseClient get client => Supabase.instance.client;
}

/// Operatori supportati dai filtri generici sulle tabelle.
enum OperatoreFiltroDb {
  uguale,
  diverso,
  maggiore,
  maggioreUguale,
  minore,
  minoreUguale,
  like,
  ilike,
  inLista,
  nullo,
  nonNullo,
}

/// Filtro generico applicabile a qualsiasi tabella.
///
/// I costruttori nominati rendono leggibile il codice dei controller senza
/// esporre direttamente l'API Supabase.
class FiltroDb {
  const FiltroDb._(this.campo, this.operatore, this.valore);

  const FiltroDb.uguale(String campo, Object valore)
      : this._(campo, OperatoreFiltroDb.uguale, valore);

  const FiltroDb.diverso(String campo, Object valore)
      : this._(campo, OperatoreFiltroDb.diverso, valore);

  const FiltroDb.maggiore(String campo, Object valore)
      : this._(campo, OperatoreFiltroDb.maggiore, valore);

  const FiltroDb.maggioreUguale(String campo, Object valore)
      : this._(campo, OperatoreFiltroDb.maggioreUguale, valore);

  const FiltroDb.minore(String campo, Object valore)
      : this._(campo, OperatoreFiltroDb.minore, valore);

  const FiltroDb.minoreUguale(String campo, Object valore)
      : this._(campo, OperatoreFiltroDb.minoreUguale, valore);

  const FiltroDb.like(String campo, String valore)
      : this._(campo, OperatoreFiltroDb.like, valore);

  const FiltroDb.ilike(String campo, String valore)
      : this._(campo, OperatoreFiltroDb.ilike, valore);

  const FiltroDb.inLista(String campo, List<Object> valori)
      : this._(campo, OperatoreFiltroDb.inLista, valori);

  const FiltroDb.nullo(String campo)
      : this._(campo, OperatoreFiltroDb.nullo, true);

  const FiltroDb.nonNullo(String campo)
      : this._(campo, OperatoreFiltroDb.nonNullo, true);

  final String campo;
  final OperatoreFiltroDb operatore;
  final Object valore;
}

/// Ordinamento generico applicabile a qualsiasi tabella.
class OrdineDb {
  const OrdineDb(
    this.campo, {
    this.crescente = true,
    this.nullPrima = false,
  });

  final String campo;
  final bool crescente;
  final bool nullPrima;
}

/// Punto di ingresso unico al database PostgreSQL/Supabase.
///
/// [DatabaseRepository] non rappresenta una tabella. Fornisce servizi che
/// riguardano il database nel suo complesso: selezione di una tabella, RPC,
/// schema e gestione uniforme degli errori.
class DatabaseRepository {
  DatabaseRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  /// Crea un accesso senza sessione utente, destinato alle sole RPC/tabelle
  /// che il database espone pubblicamente tramite le proprie policy.
  ///
  /// I controller non devono conoscere URL, chiavi o tipi Supabase.
  factory DatabaseRepository.pubblico() => DatabaseRepository(
        client: SupabaseClient(
          SupabaseConfig.url,
          SupabaseConfig.publishableKey,
          authOptions: const AuthClientOptions(
            autoRefreshToken: false,
          ),
        ),
      );

  final SupabaseClient _client;

  static Map<String, dynamic>? _schema;
  static Future<Map<String, dynamic>>? _caricamentoSchema;

  /// ID dell'utente autenticato, quando disponibile.
  String? get userIdCorrente => _client.auth.currentUser?.id;

  /// Segnala i cambiamenti dell'utente autenticato senza esporre tipi Supabase
  /// ai controller applicativi.
  Stream<String?> get cambiUtente => _client.auth.onAuthStateChange
      .map((stato) => stato.session?.user.id)
      .distinct();

  /// Effettua il login e restituisce l'ID dell'utente autenticato.
  Future<String?> accedi({
    required String email,
    required String password,
  }) {
    return _esegui<String?>(
      () async {
        final risposta = await _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        return risposta.user?.id;
      },
      messaggioGenerico:
          'Accesso non riuscito. Controlla email e password.',
    );
  }

  /// Termina la sessione corrente.
  Future<void> esci() {
    return _esegui<void>(
      () => _client.auth.signOut(),
      messaggioGenerico: 'Disconnessione non riuscita.',
    );
  }

  /// Modifica la password dell'utente autenticato.
  Future<void> cambiaPassword(String nuovaPassword) {
    return _esegui<void>(
      () async {
        await _client.auth.updateUser(
          UserAttributes(password: nuovaPassword),
        );
      },
      messaggioGenerico: 'Impossibile modificare la password.',
    );
  }

  /// Restituisce l'accesso generico alla tabella indicata dal controller.
  ///
  /// Esempio:
  ///
  ///   final tabella = db.tabella('news');
  ///   final righe = await tabella.elenco();
  TabellaRepository tabella(String nome) {
    final nomePulito = nome.trim();
    if (nomePulito.isEmpty) {
      throw ArgumentError.value(nome, 'nome', 'Nome tabella non valido.');
    }
    return TabellaRepository._(this, nomePulito);
  }

  /// Invoca una Edge Function e restituisce il payload grezzo.
  ///
  /// Serve per operazioni server-side che non possono essere espresse come
  /// CRUD/RPC del client (per esempio amministrazione di Supabase Auth).
  Future<dynamic> invocaFunzione(
    String nome, {
    Map<String, dynamic> corpo = const <String, dynamic>{},
  }) {
    return _esegui<dynamic>(
      () async {
        final risposta = await _client.functions.invoke(
          nome,
          body: corpo,
        );

        if (risposta.status < 200 || risposta.status >= 300) {
          final dettaglio = risposta.data is Map
              ? (risposta.data as Map)['error']?.toString()
              : risposta.data?.toString();

          throw AppException(
            dettaglio == null || dettaglio.trim().isEmpty
                ? 'La funzione $nome ha restituito HTTP ${risposta.status}.'
                : dettaglio,
          );
        }

        return risposta.data;
      },
      messaggioGenerico: 'Operazione server non riuscita.',
    );
  }

  /// Carica i metadati grezzi dello schema pubblico tramite la RPC applicativa.
  ///
  /// Il livello dati non conosce i modelli della UI. Restituisce quindi la
  /// mappa prodotta dal database; l'interpretazione dello schema appartiene
  /// al sottosistema dinamico.
  Future<Map<String, dynamic>> caricaSchema({
    bool forzaAggiornamento = false,
  }) {
    if (!forzaAggiornamento && _schema != null) {
      return Future<Map<String, dynamic>>.value(_schema);
    }
    if (!forzaAggiornamento && _caricamentoSchema != null) {
      return _caricamentoSchema!;
    }

    final caricamento = _esegui<Map<String, dynamic>>(
      () async {
        final raw = await _client.rpc('app_database_schema');
        if (raw is! Map) {
          throw const FormatException(
            'La funzione app_database_schema ha restituito dati non validi.',
          );
        }
        final risultato = Map<String, dynamic>.from(raw);
        _schema = risultato;
        return risultato;
      },
      messaggioGenerico: 'Impossibile leggere lo schema del database.',
    );

    _caricamentoSchema = caricamento;
    return caricamento.whenComplete(() {
      if (identical(_caricamentoSchema, caricamento)) {
        _caricamentoSchema = null;
      }
    });
  }


  /// Carica un file in un bucket Storage.
  ///
  /// Il metodo e' generico e non presume che il bucket sia pubblico.
  Future<void> caricaFileStorage({
    required String bucket,
    required String percorso,
    required Uint8List bytes,
    String? contentType,
    bool sovrascrivi = false,
    String cacheControl = '3600',
  }) {
    return _esegui<void>(
      () async {
        await _client.storage.from(bucket).uploadBinary(
          percorso,
          bytes,
          fileOptions: FileOptions(
            cacheControl: cacheControl,
            upsert: sovrascrivi,
            contentType: contentType,
          ),
        );
      },
      messaggioGenerico: 'Impossibile caricare il file.',
    );
  }

  /// Crea un URL temporaneo firmato per un file di Storage.
  Future<String> creaUrlFirmato({
    required String bucket,
    required String percorso,
    Duration durata = const Duration(minutes: 30),
  }) {
    return _esegui<String>(
      () => _client.storage.from(bucket).createSignedUrl(
            percorso,
            durata.inSeconds,
          ),
      messaggioGenerico: 'Impossibile creare il link al file.',
    );
  }

  /// Carica o sostituisce un file in un bucket Storage pubblico.
  ///
  /// Il metodo e' generico: non conosce Eventi, locandine o altri domini.
  Future<String> caricaFilePubblico({
    required String bucket,
    required String percorso,
    required Uint8List bytes,
    required String contentType,
    String cacheControl = '3600',
  }) {
    return _esegui<String>(
      () async {
        await _client.storage.from(bucket).uploadBinary(
          percorso,
          bytes,
          fileOptions: FileOptions(
            cacheControl: cacheControl,
            upsert: true,
            contentType: contentType,
          ),
        );
        return _client.storage.from(bucket).getPublicUrl(percorso);
      },
      messaggioGenerico: 'Impossibile caricare il file.',
    );
  }

  /// Rimuove uno o piu' file da un bucket Storage.
  Future<void> rimuoviFileStorage({
    required String bucket,
    required List<String> percorsi,
  }) {
    if (percorsi.isEmpty) return Future<void>.value();

    return _esegui<void>(
      () async {
        await _client.storage.from(bucket).remove(percorsi);
      },
      messaggioGenerico: 'Impossibile rimuovere il file.',
    );
  }

  /// Esegue una funzione PostgreSQL e restituisce il risultato grezzo.
  Future<dynamic> rpc(
    String nome, {
    Map<String, dynamic> parametri = const <String, dynamic>{},
  }) {
    return _esegui<dynamic>(
      () => _client.rpc(nome, params: parametri),
      messaggioGenerico: 'Operazione sul database non riuscita.',
    );
  }

  /// Esegue una RPC che deve restituire un elenco di record.
  Future<List<Map<String, dynamic>>> rpcElenco(
    String nome, {
    Map<String, dynamic> parametri = const <String, dynamic>{},
  }) async {
    final raw = await rpc(nome, parametri: parametri);
    if (raw == null) return const <Map<String, dynamic>>[];
    if (raw is! List) {
      throw const AppException('Il database ha restituito dati non validi.');
    }
    return raw
        .map((riga) => Map<String, dynamic>.from(riga as Map))
        .toList(growable: false);
  }

  /// Esegue una RPC che deve restituire un singolo record o null.
  Future<Map<String, dynamic>?> rpcMappa(
    String nome, {
    Map<String, dynamic> parametri = const <String, dynamic>{},
  }) async {
    final raw = await rpc(nome, parametri: parametri);
    if (raw == null) return null;
    if (raw is! Map) {
      throw const AppException('Il database ha restituito dati non validi.');
    }
    return Map<String, dynamic>.from(raw);
  }

  /// Esegue un'operazione remota traducendo gli errori tecnici in AppException.
  ///
  /// Tutti gli accessi di [TabellaRepository] passano da questo metodo; in
  /// questo modo il trattamento degli errori e' identico per tutte le tabelle.
  Future<T> _esegui<T>(
    Future<T> Function() operazione, {
    required String messaggioGenerico,
  }) async {
    try {
      return await operazione();
    } catch (errore) {
      throw AppErrorMapper.converti(
        errore,
        messaggioGenerico: messaggioGenerico,
      );
    }
  }

  SupabaseClient get _supabase => _client;
}

/// Accesso CRUD a una singola tabella scelta dal controller.
///
/// La classe non contiene regole di business e non conosce il significato
/// della tabella. RLS e constraint sono applicati direttamente dal database.
class TabellaRepository {
  TabellaRepository._(this._db, this.nome);

  final DatabaseRepository _db;

  /// Nome della tabella PostgreSQL su cui operano i metodi di questa istanza.
  final String nome;

  /// Legge un elenco di record applicando filtri, ordinamenti e limite.
  Future<List<Map<String, dynamic>>> elenco({
    String colonne = '*',
    List<FiltroDb> filtri = const <FiltroDb>[],
    List<OrdineDb> ordinamenti = const <OrdineDb>[],
    int? limite,
  }) {
    return _db._esegui<List<Map<String, dynamic>>>(
      () async {
        dynamic query = _db._supabase.from(nome).select(colonne);
        query = _applicaFiltri(query, filtri);

        for (final ordine in ordinamenti) {
          query = query.order(
            ordine.campo,
            ascending: ordine.crescente,
            nullsFirst: ordine.nullPrima,
          );
        }
        if (limite != null) query = query.limit(limite);

        final List<dynamic> raw = await query;
        return raw
            .map((riga) => Map<String, dynamic>.from(riga as Map))
            .toList(growable: false);
      },
      messaggioGenerico: 'Impossibile leggere i dati da $nome.',
    );
  }

  /// Legge un singolo record; restituisce null se nessun record corrisponde.
  Future<Map<String, dynamic>?> singolo({
    String colonne = '*',
    List<FiltroDb> filtri = const <FiltroDb>[],
  }) {
    return _db._esegui<Map<String, dynamic>?>(
      () async {
        dynamic query = _db._supabase.from(nome).select(colonne);
        query = _applicaFiltri(query, filtri);
        final raw = await query.maybeSingle();
        return raw == null ? null : Map<String, dynamic>.from(raw as Map);
      },
      messaggioGenerico: 'Impossibile leggere il dato da $nome.',
    );
  }

  /// Inserisce un singolo record e restituisce la riga salvata.
  Future<Map<String, dynamic>> inserisci(
    Map<String, dynamic> valori, {
    String colonne = '*',
  }) {
    return _db._esegui<Map<String, dynamic>>(
      () async {
        final raw = await _db._supabase
            .from(nome)
            .insert(valori)
            .select(colonne)
            .single();
        return Map<String, dynamic>.from(raw as Map);
      },
      messaggioGenerico: 'Impossibile inserire il dato in $nome.',
    );
  }

  /// Inserisce piu' record con un'unica operazione.
  ///
  /// Se l'elenco e' vuoto non viene eseguita alcuna query.
  Future<List<Map<String, dynamic>>> inserisciMolti(
    List<Map<String, dynamic>> valori, {
    String colonne = '*',
  }) {
    if (valori.isEmpty) {
      return Future<List<Map<String, dynamic>>>.value(
        const <Map<String, dynamic>>[],
      );
    }

    return _db._esegui<List<Map<String, dynamic>>>(
      () async {
        final List<dynamic> raw = await _db._supabase
            .from(nome)
            .insert(valori)
            .select(colonne);

        return raw
            .map((riga) => Map<String, dynamic>.from(riga as Map))
            .toList(growable: false);
      },
      messaggioGenerico: 'Impossibile inserire i dati in $nome.',
    );
  }

  /// Aggiorna i record corrispondenti ai filtri e restituisce le righe mutate.
  ///
  /// I filtri sono obbligatori per evitare aggiornamenti accidentali di tutta
  /// la tabella. Le policy RLS del database restano comunque determinanti.
  Future<List<Map<String, dynamic>>> aggiorna(
    Map<String, dynamic> valori, {
    required List<FiltroDb> filtri,
    String colonne = '*',
  }) {
    _richiediFiltri(filtri, operazione: 'aggiornamento');
    return _db._esegui<List<Map<String, dynamic>>>(
      () async {
        dynamic query = _db._supabase.from(nome).update(valori);
        query = _applicaFiltri(query, filtri);
        final List<dynamic> raw = await query.select(colonne);
        return raw
            .map((riga) => Map<String, dynamic>.from(riga as Map))
            .toList(growable: false);
      },
      messaggioGenerico: 'Impossibile aggiornare i dati di $nome.',
    );
  }

  /// Aggiorna un record che il chiamante si aspetta essere univoco.
  Future<Map<String, dynamic>?> aggiornaSingolo(
    Map<String, dynamic> valori, {
    required List<FiltroDb> filtri,
    String colonne = '*',
  }) async {
    final righe = await aggiorna(
      valori,
      filtri: filtri,
      colonne: colonne,
    );
    if (righe.isEmpty) return null;
    if (righe.length != 1) {
      throw AppException(
        'L\'aggiornamento di $nome ha interessato piu\' record del previsto.',
      );
    }
    return righe.single;
  }

  /// Inserisce o aggiorna un singolo record e restituisce la riga risultante.
  Future<Map<String, dynamic>> upsert(
    Map<String, dynamic> valori, {
    String colonne = '*',
    String? onConflict,
  }) {
    return _db._esegui<Map<String, dynamic>>(
      () async {
        final raw = await _db._supabase
            .from(nome)
            .upsert(valori, onConflict: onConflict)
            .select(colonne)
            .single();
        return Map<String, dynamic>.from(raw as Map);
      },
      messaggioGenerico: 'Impossibile salvare il dato in $nome.',
    );
  }

  /// Elimina i record corrispondenti ai filtri indicati.
  ///
  /// I filtri sono obbligatori per evitare cancellazioni accidentali complete.
  Future<void> elimina({required List<FiltroDb> filtri}) {
    _richiediFiltri(filtri, operazione: 'eliminazione');
    return _db._esegui<void>(
      () async {
        dynamic query = _db._supabase.from(nome).delete();
        query = _applicaFiltri(query, filtri);
        await query;
      },
      messaggioGenerico: 'Impossibile eliminare il dato da $nome.',
    );
  }

  /// Applica i filtri generici alla query Supabase corrente.
  dynamic _applicaFiltri(dynamic query, List<FiltroDb> filtri) {
    for (final filtro in filtri) {
      query = switch (filtro.operatore) {
        OperatoreFiltroDb.uguale => query.eq(filtro.campo, filtro.valore),
        OperatoreFiltroDb.diverso => query.neq(filtro.campo, filtro.valore),
        OperatoreFiltroDb.maggiore => query.gt(filtro.campo, filtro.valore),
        OperatoreFiltroDb.maggioreUguale =>
          query.gte(filtro.campo, filtro.valore),
        OperatoreFiltroDb.minore => query.lt(filtro.campo, filtro.valore),
        OperatoreFiltroDb.minoreUguale =>
          query.lte(filtro.campo, filtro.valore),
        OperatoreFiltroDb.like => query.like(filtro.campo, filtro.valore),
        OperatoreFiltroDb.ilike => query.ilike(filtro.campo, filtro.valore),
        OperatoreFiltroDb.inLista =>
          query.inFilter(filtro.campo, filtro.valore as List<Object>),
        OperatoreFiltroDb.nullo => query.isFilter(filtro.campo, null),
        OperatoreFiltroDb.nonNullo => query.not(filtro.campo, 'is', null),
      };
    }
    return query;
  }

  /// Impedisce scritture distruttive senza condizioni esplicite.
  void _richiediFiltri(
    List<FiltroDb> filtri, {
    required String operazione,
  }) {
    if (filtri.isEmpty) {
      throw ArgumentError(
        'L\'$operazione sulla tabella $nome richiede almeno un filtro.',
      );
    }
  }
}
