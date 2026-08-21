import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_exception.dart';
import '../../supabase_config.dart';

class PercorsoMentore {
  const PercorsoMentore({
    required this.mentoraggio,
    required this.insegnamento,
    required this.docente,
    required this.team,
    required this.annoCorrente,
    required this.mioRuolo,
  });

  final Map<String, dynamic> mentoraggio;
  final Map<String, dynamic> insegnamento;
  final Map<String, dynamic> docente;
  final List<Map<String, dynamic>> team;
  final bool annoCorrente;
  final String mioRuolo;
}

class MentoreController extends ChangeNotifier {
  MentoreController({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;
  List<PercorsoMentore> percorsi = const <PercorsoMentore>[];
  PercorsoMentore? selezionato;
  String? annoCorrente;
  bool caricamento = false;
  bool salvataggio = false;
  String? errore;

  Future<void> carica() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    caricamento = true;
    errore = null;
    notifyListeners();

    try {
      final anno = await _client
          .from('anni_accademici')
          .select('codice')
          .eq('corrente', true)
          .maybeSingle();
      annoCorrente = anno?['codice']?.toString();

      final mieAssegnazioni = (await _client
              .from('mentoraggio_mentori')
              .select('mentoraggio_id, mentore_id, tipo')
              .eq('mentore_id', userId))
          .cast<Map<String, dynamic>>();
      if (mieAssegnazioni.isEmpty) {
        percorsi = const [];
        selezionato = null;
        return;
      }

      final rawMentoraggi = await _client.rpc('mentoraggi_del_mentore');
      final mentoraggi = (rawMentoraggi as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
      final insegnamentoIds = mentoraggi
          .map((m) => m['insegnamento_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList(growable: false);
      final insegnamenti = insegnamentoIds.isEmpty
          ? <Map<String, dynamic>>[]
          : (await _client
                  .from('insegnamenti')
                  .select()
                  .inFilter('id', insegnamentoIds))
              .cast<Map<String, dynamic>>();
      final insegnamentiPerId = <String, Map<String, dynamic>>{
        for (final i in insegnamenti) i['id'].toString(): i,
      };

      final docentiIds = insegnamenti
          .map((i) => i['docente_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList(growable: false);
      final docenti = docentiIds.isEmpty
          ? <Map<String, dynamic>>[]
          : (await _client
                  .from('anagrafica')
                  .select('user_id, nome, cognome, email_unipa, cellulare')
                  .inFilter('user_id', docentiIds))
              .cast<Map<String, dynamic>>();
      final docentiPerId = <String, Map<String, dynamic>>{
        for (final d in docenti) d['user_id'].toString(): d,
      };

      final mentoraggioIds = mentoraggi
          .map((m) => m['id']?.toString())
          .whereType<String>()
          .toList(growable: false);
      final assegnazioni = mentoraggioIds.isEmpty
          ? <Map<String, dynamic>>[]
          : (await _client
                  .from('mentoraggio_mentori')
                  .select('mentoraggio_id, mentore_id, tipo')
                  .inFilter('mentoraggio_id', mentoraggioIds))
              .cast<Map<String, dynamic>>();
      final teamIds = assegnazioni
          .map((a) => a['mentore_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList(growable: false);
      final persone = teamIds.isEmpty
          ? <Map<String, dynamic>>[]
          : (await _client
                  .from('anagrafica')
                  .select('user_id, nome, cognome, email_unipa')
                  .inFilter('user_id', teamIds))
              .cast<Map<String, dynamic>>();
      final personePerId = <String, Map<String, dynamic>>{
        for (final p in persone) p['user_id'].toString(): p,
      };

      final risultato = <PercorsoMentore>[];
      for (final m in mentoraggi) {
        final ins = insegnamentiPerId[m['insegnamento_id']?.toString()];
        if (ins == null) continue;
        final id = m['id']?.toString();
        final assegnati = assegnazioni
            .where((a) => a['mentoraggio_id']?.toString() == id)
            .toList(growable: false);
        final mia = assegnati.firstWhere(
          (a) => a['mentore_id']?.toString() == userId,
          orElse: () => <String, dynamic>{},
        );
        final team = assegnati.map((a) {
          final persona = personePerId[a['mentore_id']?.toString()] ??
              <String, dynamic>{};
          return <String, dynamic>{...persona, 'tipo': a['tipo']};
        }).toList(growable: false)
          ..sort((a, b) {
            final seniorA = a['tipo']?.toString().toLowerCase() == 'senior';
            final seniorB = b['tipo']?.toString().toLowerCase() == 'senior';
            if (seniorA != seniorB) return seniorA ? 1 : -1;
            return '${a['cognome'] ?? ''} ${a['nome'] ?? ''}'
                .compareTo('${b['cognome'] ?? ''} ${b['nome'] ?? ''}');
          });

        risultato.add(
          PercorsoMentore(
            mentoraggio: m,
            insegnamento: ins,
            docente: docentiPerId[ins['docente_id']?.toString()] ??
                <String, dynamic>{},
            team: team,
            annoCorrente: m['anno_accademico']?.toString() == annoCorrente,
            mioRuolo: mia['tipo']?.toString() ?? '',
          ),
        );
      }

      risultato.sort((a, b) {
        final anno = (b.mentoraggio['anno_accademico']?.toString() ?? '')
            .compareTo(a.mentoraggio['anno_accademico']?.toString() ?? '');
        if (anno != 0) return anno;
        return (a.insegnamento['insegnamento']?.toString() ?? '')
            .compareTo(b.insegnamento['insegnamento']?.toString() ?? '');
      });

      percorsi = risultato;
      if (selezionato == null ||
          !percorsi.any((p) => p.mentoraggio['id'] == selezionato!.mentoraggio['id'])) {
        selezionato = percorsi.isEmpty ? null : percorsi.first;
      } else {
        selezionato = percorsi.firstWhere(
          (p) => p.mentoraggio['id'] == selezionato!.mentoraggio['id'],
        );
      }
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile caricare i mentoraggi assegnati.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  void seleziona(PercorsoMentore valore) {
    selezionato = valore;
    notifyListeners();
  }

  Future<void> salvaMentoraggio(Map<String, dynamic> valori) async {
    final percorso = selezionato;
    if (percorso == null || !percorso.annoCorrente) {
      throw const AppException('Questo mentoraggio e in sola lettura.');
    }

    salvataggio = true;
    notifyListeners();
    try {
      final esclusi = <String>{
        'id',
        'insegnamento_id',
        'anno_accademico',
        'data_inizio',
        'data_fine',
        'numero_studenti',
        'sede',
        'note',
        'svolgimento',
        'giorni_orari_lezioni',
        'scheda_sintesi_pdf_url',
        'created_at',
        'updated_at',
      };
      final patch = <String, dynamic>{
        for (final entry in valori.entries)
          if (!esclusi.contains(entry.key)) entry.key: entry.value,
      };
      await _client.rpc(
        'mentoraggio_aggiorna_mentore',
        params: <String, dynamic>{
          'p_mentoraggio_id': percorso.mentoraggio['id'],
          'p_valori': patch,
        },
      );
      await carica();
    } catch (e) {
      throw AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile salvare il mentoraggio.',
      );
    } finally {
      salvataggio = false;
      notifyListeners();
    }
  }
}
