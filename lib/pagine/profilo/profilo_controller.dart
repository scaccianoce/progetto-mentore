import 'package:flutter/foundation.dart';

import '../../app/app_core.dart';
import '../../app/app_session_controller.dart';
import '../../dati/repository.dart';
import '../../ui/dinamico_schema.dart';

/// Stato annuale della partecipazione dell'utente al Progetto Mentore.
class PartecipazioneAnnualeProfilo {
  const PartecipazioneAnnualeProfilo({
    required this.disponibile,
    required this.annoAccademico,
    required this.stato,
    this.richiestaAt,
    this.rispostaAt,
    this.preferenzaPeriodoMentore,
    this.noteAttivitaMentore,
    this.soloMentore,
    this.valutazioneMentoriPrecedenti,
    this.cambiareMentore,
    this.noteSuiMentori,
    this.cambiareMenteeSeguiti,
    this.disponibileMentoringEsami,
    this.segnalazioniSuggerimenti,
  });

  factory PartecipazioneAnnualeProfilo.daMap(Map<String, dynamic> map) {
    return PartecipazioneAnnualeProfilo(
      disponibile: map['disponibile'] == true,
      annoAccademico: map['anno_accademico']?.toString(),
      stato: map['stato']?.toString(),
      richiestaAt: DateTime.tryParse(map['richiesta_at']?.toString() ?? ''),
      rispostaAt: DateTime.tryParse(map['risposta_at']?.toString() ?? ''),
      preferenzaPeriodoMentore: map['preferenza_periodo_mentore']?.toString(),
      noteAttivitaMentore: map['note_attivita_mentore']?.toString(),
      soloMentore: map['solo_mentore'] as bool?,
      valutazioneMentoriPrecedenti:
          _intNull(map['valutazione_mentori_precedenti']),
      cambiareMentore: map['cambiare_mentore'] as bool?,
      noteSuiMentori: map['note_sui_mentori']?.toString(),
      cambiareMenteeSeguiti: map['cambiare_mentee_seguiti']?.toString(),
      disponibileMentoringEsami:
          map['disponibile_mentoring_esami'] as bool?,
      segnalazioniSuggerimenti:
          map['segnalazioni_suggerimenti']?.toString(),
    );
  }

  final bool disponibile;
  final String? annoAccademico;
  final String? stato;
  final DateTime? richiestaAt;
  final DateTime? rispostaAt;

  final String? preferenzaPeriodoMentore;
  final String? noteAttivitaMentore;
  final bool? soloMentore;
  final int? valutazioneMentoriPrecedenti;
  final bool? cambiareMentore;
  final String? noteSuiMentori;
  final String? cambiareMenteeSeguiti;
  final bool? disponibileMentoringEsami;
  final String? segnalazioniSuggerimenti;

  bool get daConfermare => disponibile && stato == 'da_contattare';
  bool get confermata => disponibile && stato == 'confermato';
  bool get rinuncia => disponibile && stato == 'rinuncia';
  bool get nuovo => disponibile && stato == 'nuovo';
}

/// Controller della pagina Profilo.
///
/// La pagina utilizza piu' tabelle ma non necessita di un repository specifico:
/// ogni accesso ai dati passa dal [DatabaseRepository], indicando esplicitamente
/// la tabella interessata. Le operazioni di autenticazione restano invece
/// delegate a [SessioneController].
class ProfiloController extends ChangeNotifier {
  ProfiloController({
    required this.sessione,
    DatabaseRepository? database,
  }) : db = database ?? DatabaseRepository();

  final SessioneController sessione;
  final DatabaseRepository db;

  Map<String, dynamic>? _profilo;
  final List<Map<String, dynamic>> _ssd = <Map<String, dynamic>>[];
  final List<String> _anniAccademici = <String>[];
  final List<PartecipazioneAnnualeProfilo> _partecipazioniAnnuali =
      <PartecipazioneAnnualeProfilo>[];

  PartecipazioneAnnualeProfilo? _partecipazioneAnnuale;

  bool _caricamento = false;
  bool _salvataggio = false;
  bool _salvataggioPartecipazione = false;
  bool _salvataggioPassword = false;
  bool _puoModificare = false;
  String? _errore;

  Map<String, dynamic>? get profilo => _profilo;
  List<Map<String, dynamic>> get ssd => List.unmodifiable(_ssd);
  List<String> get anniAccademici => List.unmodifiable(_anniAccademici);
  List<PartecipazioneAnnualeProfilo> get partecipazioniAnnuali =>
      List.unmodifiable(_partecipazioniAnnuali);
  PartecipazioneAnnualeProfilo? get partecipazioneAnnuale =>
      _partecipazioneAnnuale;

  bool get caricamento => _caricamento;
  bool get salvataggio => _salvataggio;
  bool get salvataggioPartecipazione => _salvataggioPartecipazione;
  bool get salvataggioPassword => _salvataggioPassword;
  bool get puoModificare => _puoModificare;
  String? get errore => _errore;

  /// Carica lo schema DB utilizzato dalla visualizzazione e dall'editor.
  Future<SchemaDatabase> caricaSchemaDatabase() =>
      SchemaDatabase.carica(database: db);

  /// Carica profilo, lookup e partecipazioni annuali.
  Future<void> carica() async {
    final userId = db.userIdCorrente;

    if (userId == null) {
      _errore = 'Sessione assente.';
      notifyListeners();
      return;
    }

    _caricamento = true;
    _errore = null;
    notifyListeners();

    try {
      final risultati = await Future.wait<dynamic>([
        db.tabella('anagrafica').singolo(
          filtri: <FiltroDb>[
            FiltroDb.uguale('user_id', userId),
          ],
        ),
        db.tabella('ssd').elenco(
          colonne: 'cod_ssd, gsd, area',
          ordinamenti: const <OrdineDb>[
            OrdineDb('cod_ssd'),
          ],
        ),
        db.tabella('anni_accademici').elenco(
          colonne: 'codice',
          ordinamenti: const <OrdineDb>[
            OrdineDb('codice', crescente: false),
          ],
        ),
        db.rpcMappa('partecipazione_annuale_stato'),
        db.rpcElenco('partecipazioni_annuali_proprie'),
      ]);

      _profilo = risultati[0] as Map<String, dynamic>?;

      _ssd
        ..clear()
        ..addAll(
          (risultati[1] as List)
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );

      _anniAccademici
        ..clear()
        ..addAll(
          (risultati[2] as List)
              .map((e) => (e as Map)['codice']?.toString())
              .whereType<String>()
              .where((e) => e.isNotEmpty),
        );

      final righeAnnuali = (risultati[4] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

      _partecipazioniAnnuali
        ..clear()
        ..addAll(
          righeAnnuali.map(
            (riga) => PartecipazioneAnnualeProfilo.daMap(
              <String, dynamic>{
                ...riga,
                'disponibile': true,
              },
            ),
          ),
        );

      final partecipazioneRaw = risultati[3];
      if (partecipazioneRaw is Map<String, dynamic>) {
        final statoBase =
            Map<String, dynamic>.from(partecipazioneRaw);
        final anno = statoBase['anno_accademico']?.toString();

        if (statoBase['disponibile'] == true &&
            anno != null &&
            anno.isNotEmpty) {
          for (final riga in righeAnnuali) {
            if (riga['anno_accademico']?.toString() == anno) {
              statoBase.addAll(riga);
              statoBase['disponibile'] = true;
              statoBase['anno_accademico'] = anno;
              break;
            }
          }
        }

        _partecipazioneAnnuale =
            PartecipazioneAnnualeProfilo.daMap(statoBase);
      } else {
        _partecipazioneAnnuale = null;
      }

      final annoProfilo =
          _profilo?['anno_prima_partecipazione']?.toString().trim();

      if (annoProfilo != null &&
          annoProfilo.isNotEmpty &&
          !_anniAccademici.contains(annoProfilo)) {
        _anniAccademici.add(annoProfilo);
      }

      _puoModificare = sessione.ruolo == AppRole.participant
          ? true
          : sessione.ruolo?.puoAmministrare ?? false;

      if (!_puoModificare) {
        final risposta = await db.rpc(
          'puo_modificare_corrente',
          parametri: const <String, dynamic>{
            'p_ambito': 'anagrafica',
          },
        );
        _puoModificare = risposta == true;
      }
    } catch (e) {
      _errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile caricare il profilo.',
      ).messaggio;
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  /// Registra la risposta sintetica alla richiesta annuale.
  Future<void> rispondiPartecipazione(bool partecipa) async {
    if (_partecipazioneAnnuale?.daConfermare != true) {
      throw const AppException(
        'Non è presente una richiesta di partecipazione da confermare.',
      );
    }

    _salvataggioPartecipazione = true;
    _errore = null;
    notifyListeners();

    try {
      final raw = await db.rpcMappa(
        'partecipazione_annuale_rispondi',
        parametri: <String, dynamic>{
          'p_partecipa': partecipa,
        },
      );

      if (raw != null) {
        _partecipazioneAnnuale =
            PartecipazioneAnnualeProfilo.daMap(raw);
      }

      await carica();
    } catch (e) {
      final eccezione = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile registrare la conferma di partecipazione.',
      );
      _errore = eccezione.messaggio;
      throw eccezione;
    } finally {
      _salvataggioPartecipazione = false;
      notifyListeners();
    }
  }

  /// Salva la ricognizione annuale nelle partecipazioni dell'utente corrente.
  Future<void> salvaRicognizioneAnnuale(
    Map<String, dynamic> valori,
  ) async {
    final userId = db.userIdCorrente;
    final anno = _partecipazioneAnnuale?.annoAccademico;

    if (userId == null || anno == null || anno.isEmpty) {
      throw const AppException(
        'Partecipazione annuale non disponibile.',
      );
    }

    if (_partecipazioneAnnuale?.daConfermare != true) {
      throw const AppException(
        'La richiesta di partecipazione non è più in attesa di conferma.',
      );
    }

    _salvataggioPartecipazione = true;
    _errore = null;
    notifyListeners();

    try {
      await db.tabella('partecipazioni_annuali').aggiorna(
        <String, dynamic>{
          'preferenza_periodo_mentore':
              valori['preferenza_periodo_mentore'],
          'note_attivita_mentore':
              _testoNull(valori['note_attivita_mentore']),
          'solo_mentore': valori['solo_mentore'] == true,
          'valutazione_mentori_precedenti':
              valori['valutazione_mentori_precedenti'],
          'cambiare_mentore': valori['cambiare_mentore'],
          'note_sui_mentori':
              _testoNull(valori['note_sui_mentori']),
          'cambiare_mentee_seguiti':
              _testoNull(valori['cambiare_mentee_seguiti']),
          'disponibile_mentoring_esami':
              valori['disponibile_mentoring_esami'],
          'segnalazioni_suggerimenti':
              _testoNull(valori['segnalazioni_suggerimenti']),
        },
        filtri: <FiltroDb>[
          FiltroDb.uguale('user_id', userId),
          FiltroDb.uguale('anno_accademico', anno),
        ],
        colonne: 'user_id',
      );

      await db.rpc(
        'partecipazione_annuale_rispondi',
        parametri: const <String, dynamic>{
          'p_partecipa': true,
        },
      );

      await carica();
    } catch (e) {
      final eccezione = AppErrorMapper.converti(
        e,
        messaggioGenerico:
            'Impossibile salvare la ricognizione annuale.',
      );
      _errore = eccezione.messaggio;
      throw eccezione;
    } finally {
      _salvataggioPartecipazione = false;
      notifyListeners();
    }
  }

  /// Modifica la password dell'utente corrente.
  ///
  /// L'autenticazione non appartiene a [DatabaseRepository] e viene quindi
  /// delegata al controller di sessione.
  Future<void> cambiaPassword(String nuovaPassword) async {
    if (nuovaPassword.length < 8) {
      throw const AppException(
        'La nuova password deve avere almeno 8 caratteri.',
      );
    }

    _salvataggioPassword = true;
    _errore = null;
    notifyListeners();

    try {
      await sessione.cambiaPassword(nuovaPassword);
    } catch (e) {
      final eccezione = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile modificare la password.',
      );
      _errore = eccezione.messaggio;
      throw eccezione;
    } finally {
      _salvataggioPassword = false;
      notifyListeners();
    }
  }

  /// Richiede l'abilitazione temporanea alla modifica dell'anagrafica.
  Future<void> richiediModifica() async {
    try {
      await db.rpc(
        'richiedi_abilitazione',
        parametri: const <String, dynamic>{
          'p_ambito': 'anagrafica',
        },
      );
      _errore = null;
      await carica();
    } catch (e) {
      _errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile inviare la richiesta.',
      ).messaggio;
      notifyListeners();
      rethrow;
    }
  }

  /// Salva soltanto i campi effettivamente modificati e scrivibili.
  Future<void> salva(Map<String, dynamic> valori) async {
    final userId = db.userIdCorrente;

    if (userId == null || !_puoModificare) {
      throw const AppException(
        'Modifica del profilo non autorizzata.',
      );
    }

    _salvataggio = true;
    _errore = null;
    notifyListeners();

    try {
      final schema = await caricaSchemaDatabase();
      final tabella = schema.tabella('anagrafica');
      final valoriDatabase = <String, dynamic>{};

      for (final voce in valori.entries) {
        if (_profilo?[voce.key] == voce.value) continue;

        final campo = tabella?.campo(voce.key);

        if (campo != null &&
            (campo.chiavePrimaria ||
                campo.identita ||
                campo.generato ||
                campo.solaLettura)) {
          continue;
        }

        valoriDatabase[voce.key] = voce.value;
      }

      if (valoriDatabase.isEmpty) return;

      final aggiornata = await db.tabella('anagrafica').aggiornaSingolo(
        valoriDatabase,
        filtri: <FiltroDb>[
          FiltroDb.uguale('user_id', userId),
        ],
      );

      if (aggiornata == null) {
        throw const AppException(
          'Salvataggio del profilo non riuscito.',
        );
      }

      _profilo = aggiornata;
    } catch (e) {
      final eccezione = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile salvare il profilo.',
      );
      _errore = eccezione.messaggio;
      throw eccezione;
    } finally {
      _salvataggio = false;
      notifyListeners();
    }
  }
}

String? _testoNull(Object? valore) {
  final testo = valore?.toString().trim() ?? '';
  return testo.isEmpty ? null : testo;
}

int? _intNull(Object? valore) {
  if (valore is int) return valore;
  return int.tryParse(valore?.toString() ?? '');
}
