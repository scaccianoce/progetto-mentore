import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_exception.dart';
import '../../sessione_controller.dart';
import '../../supabase_config.dart';

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
      valutazioneMentoriPrecedenti: _intNull(map['valutazione_mentori_precedenti']),
      cambiareMentore: map['cambiare_mentore'] as bool?,
      noteSuiMentori: map['note_sui_mentori']?.toString(),
      cambiareMenteeSeguiti: map['cambiare_mentee_seguiti']?.toString(),
      disponibileMentoringEsami: map['disponibile_mentoring_esami'] as bool?,
      segnalazioniSuggerimenti: map['segnalazioni_suggerimenti']?.toString(),
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

class ProfiloController extends ChangeNotifier {
  ProfiloController({required this.sessione, SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  final SessioneController sessione;
  final SupabaseClient _client;

  Map<String, dynamic>? _profilo;
  final List<Map<String, dynamic>> _ssd = <Map<String, dynamic>>[];
  final List<String> _anniAccademici = <String>[];
  PartecipazioneAnnualeProfilo? _partecipazioneAnnuale;
  bool _caricamento = false;
  bool _salvataggio = false;
  bool _salvataggioPartecipazione = false;
  bool _puoModificare = false;
  String? _errore;

  Map<String, dynamic>? get profilo => _profilo;
  List<Map<String, dynamic>> get ssd => List.unmodifiable(_ssd);
  List<String> get anniAccademici => List.unmodifiable(_anniAccademici);
  PartecipazioneAnnualeProfilo? get partecipazioneAnnuale =>
      _partecipazioneAnnuale;
  bool get caricamento => _caricamento;
  bool get salvataggio => _salvataggio;
  bool get salvataggioPartecipazione => _salvataggioPartecipazione;
  bool get puoModificare => _puoModificare;
  String? get errore => _errore;

  Future<void> carica() async {
    final User? utente = _client.auth.currentUser;
    if (utente == null) {
      _errore = 'Sessione assente.';
      notifyListeners();
      return;
    }

    _caricamento = true;
    _errore = null;
    notifyListeners();

    try {
      final risultati = await Future.wait<dynamic>([
        _client
            .from('anagrafica')
            .select()
            .eq('user_id', utente.id)
            .maybeSingle(),
        _client.from('ssd').select('cod_ssd, gsd, area').order('cod_ssd'),
        _client
            .from('anni_accademici')
            .select('codice')
            .order('codice', ascending: false),
        _client.rpc('partecipazione_annuale_stato'),
      ]);

      _profilo = risultati[0] as Map<String, dynamic>?;
      _ssd
        ..clear()
        ..addAll((risultati[1] as List).cast<Map<String, dynamic>>())
        ..sort(
          (prima, seconda) => prima['cod_ssd']
              .toString()
              .toLowerCase()
              .compareTo(seconda['cod_ssd'].toString().toLowerCase()),
        );
      _anniAccademici
        ..clear()
        ..addAll(
          (risultati[2] as List)
              .cast<Map<String, dynamic>>()
              .map((riga) => riga['codice'].toString())
              .toSet(),
        );

      final partecipazioneRaw = risultati[3];
      if (partecipazioneRaw is Map) {
        final statoBase = Map<String, dynamic>.from(partecipazioneRaw);
        final anno = statoBase['anno_accademico']?.toString();

        if (statoBase['disponibile'] == true && anno != null && anno.isNotEmpty) {
          final rigaAnnuale = await _client
              .from('partecipazioni_annuali')
              .select()
              .eq('user_id', utente.id)
              .eq('anno_accademico', anno)
              .maybeSingle();

          if (rigaAnnuale != null) {
            statoBase.addAll(rigaAnnuale);
            statoBase['disponibile'] = true;
            statoBase['anno_accademico'] = anno;
          }
        }

        _partecipazioneAnnuale = PartecipazioneAnnualeProfilo.daMap(statoBase);
      } else {
        _partecipazioneAnnuale = null;
      }

      final annoProfilo = _profilo?['anno_prima_partecipazione']
          ?.toString()
          .trim();
      if (annoProfilo != null &&
          annoProfilo.isNotEmpty &&
          !_anniAccademici.contains(annoProfilo)) {
        _anniAccademici.add(annoProfilo);
      }

      _puoModificare = sessione.ruolo == AppRole.participant
          ? true
          : sessione.ruolo?.puoAmministrare ?? false;

      if (!_puoModificare) {
        final dynamic risultato = await _client.rpc(
          'puo_modificare_corrente',
          params: const <String, dynamic>{'p_ambito': 'anagrafica'},
        );
        _puoModificare = risultato == true;
      }
    } catch (errore) {
      _errore = AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile caricare il profilo.',
      ).messaggio;
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

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
      final raw = await _client.rpc(
        'partecipazione_annuale_rispondi',
        params: <String, dynamic>{'p_partecipa': partecipa},
      );
      _partecipazioneAnnuale = PartecipazioneAnnualeProfilo.daMap(
        Map<String, dynamic>.from(raw as Map),
      );
      await carica();
    } catch (errore) {
      final eccezione = AppErrorMapper.converti(
        errore,
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

  Future<void> salvaRicognizioneAnnuale(Map<String, dynamic> valori) async {
    final userId = _client.auth.currentUser?.id;
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
      await _client
          .from('partecipazioni_annuali')
          .update(<String, dynamic>{
            'preferenza_periodo_mentore': valori['preferenza_periodo_mentore'],
            'note_attivita_mentore': _testoNull(
              valori['note_attivita_mentore'],
            ),
            'solo_mentore': valori['solo_mentore'] == true,
            'valutazione_mentori_precedenti':
                valori['valutazione_mentori_precedenti'],
            'cambiare_mentore': valori['cambiare_mentore'],
            'note_sui_mentori': _testoNull(valori['note_sui_mentori']),
            'cambiare_mentee_seguiti': _testoNull(
              valori['cambiare_mentee_seguiti'],
            ),
            'disponibile_mentoring_esami':
                valori['disponibile_mentoring_esami'],
            'segnalazioni_suggerimenti': _testoNull(
              valori['segnalazioni_suggerimenti'],
            ),
          })
          .eq('user_id', userId)
          .eq('anno_accademico', anno);

      await _client.rpc(
        'partecipazione_annuale_rispondi',
        params: const <String, dynamic>{'p_partecipa': true},
      );

      await carica();
    } catch (errore) {
      final eccezione = AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile salvare la ricognizione annuale.',
      );
      _errore = eccezione.messaggio;
      throw eccezione;
    } finally {
      _salvataggioPartecipazione = false;
      notifyListeners();
    }
  }

  Future<void> richiediModifica() async {
    try {
      await _client.rpc(
        'richiedi_abilitazione',
        params: const <String, dynamic>{'p_ambito': 'anagrafica'},
      );
      _errore = null;
    } catch (errore) {
      _errore = AppErrorMapper.converti(
        errore,
        messaggioGenerico: 'Impossibile inviare la richiesta.',
      ).messaggio;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> salva(Map<String, dynamic> valori) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null || !_puoModificare) {
      throw const AppException('Modifica del profilo non autorizzata.');
    }

    _salvataggio = true;
    _errore = null;
    notifyListeners();

    try {
      final schema = await SupabaseConfig.caricaSchemaDatabase();
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

      final Map<String, dynamic>? aggiornata = await _client
          .from('anagrafica')
          .update(valoriDatabase)
          .eq('user_id', userId)
          .select()
          .maybeSingle();
      if (aggiornata == null) {
        throw const AppException('Salvataggio del profilo non riuscito.');
      }
      _profilo = aggiornata;
    } catch (errore) {
      final AppException eccezione = AppErrorMapper.converti(
        errore,
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
