import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_exception.dart';
import '../../supabase_config.dart';

class PercorsoMentee {
  const PercorsoMentee({
    required this.insegnamento,
    required this.mentoraggio,
    required this.mentori,
    required this.annoCorrente,
    required this.sintesiQuestionario,
  });

  final Map<String, dynamic> insegnamento;
  final Map<String, dynamic> mentoraggio;
  final List<Map<String, dynamic>> mentori;
  final bool annoCorrente;
  final Map<String, dynamic>? sintesiQuestionario;
}

class MenteeController extends ChangeNotifier {
  MenteeController({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  List<PercorsoMentee> percorsi = const <PercorsoMentee>[];
  PercorsoMentee? selezionato;
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

      final List<Map<String, dynamic>> insegnamenti =
          (await _client
                  .from('insegnamenti')
                  .select()
                  .eq('docente_id', userId))
              .cast<Map<String, dynamic>>();
      final insegnamentiPerId = <String, Map<String, dynamic>>{
        for (final i in insegnamenti) i['id'].toString(): i,
      };

      final rawMentoraggi = await _client.rpc('mentoraggi_del_mentee');
      final mentoraggi = (rawMentoraggi as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

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

      final personeIds = assegnazioni
          .map((a) => a['mentore_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList(growable: false);
      final persone = personeIds.isEmpty
          ? <Map<String, dynamic>>[]
          : (await _client
                  .from('anagrafica')
                  .select('user_id, nome, cognome, email_unipa, cellulare')
                  .inFilter('user_id', personeIds))
              .cast<Map<String, dynamic>>();
      final personePerId = <String, Map<String, dynamic>>{
        for (final p in persone) p['user_id'].toString(): p,
      };

      final risultato = <PercorsoMentee>[];
      for (final mentoraggio in mentoraggi) {
        final insegnamento =
            insegnamentiPerId[mentoraggio['insegnamento_id']?.toString()];
        if (insegnamento == null) continue;
        final id = mentoraggio['id']?.toString();
        final team = assegnazioni
            .where((a) => a['mentoraggio_id']?.toString() == id)
            .map((a) {
              final persona = personePerId[a['mentore_id']?.toString()] ??
                  <String, dynamic>{};
              return <String, dynamic>{...persona, 'tipo': a['tipo']};
            })
            .toList(growable: false)
          ..sort((a, b) {
            final seniorA = a['tipo']?.toString().toLowerCase() == 'senior';
            final seniorB = b['tipo']?.toString().toLowerCase() == 'senior';
            if (seniorA != seniorB) return seniorA ? 1 : -1;
            return '${a['cognome'] ?? ''} ${a['nome'] ?? ''}'
                .compareTo('${b['cognome'] ?? ''} ${b['nome'] ?? ''}');
          });

        Map<String, dynamic>? sintesiQuestionario;
        try {
          final rawSintesi = await _client.rpc(
            'questionario_sintesi_mentoraggio',
            params: <String, dynamic>{
              'p_mentoraggio_id': mentoraggio['id'],
            },
          );
          if (rawSintesi is Map) {
            sintesiQuestionario = Map<String, dynamic>.from(rawSintesi);
          }
        } catch (_) {
          // La timeline resta disponibile anche se non esiste un questionario.
        }

        risultato.add(
          PercorsoMentee(
            insegnamento: insegnamento,
            mentoraggio: mentoraggio,
            mentori: team,
            annoCorrente:
                mentoraggio['anno_accademico']?.toString() == annoCorrente,
            sintesiQuestionario: sintesiQuestionario,
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
        messaggioGenerico: 'Impossibile caricare i mentoraggi da mentee.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  void seleziona(PercorsoMentee percorso) {
    selezionato = percorso;
    notifyListeners();
  }

  Future<void> salva(Map<String, dynamic> valori) async {
    final percorso = selezionato;
    if (percorso == null || !percorso.annoCorrente) {
      throw const AppException('Questo mentoraggio e in sola lettura.');
    }

    salvataggio = true;
    notifyListeners();
    try {
      final consentiti = <String>{
        'data_inizio',
        'data_fine',
        'numero_studenti',
        'sede',
        'note',
        'svolgimento',
        'giorni_orari_lezioni',
      };
      final patch = <String, dynamic>{
        for (final entry in valori.entries)
          if (consentiti.contains(entry.key)) entry.key: entry.value,
      };
      await _client.rpc(
        'mentoraggio_aggiorna_mentee',
        params: <String, dynamic>{
          'p_mentoraggio_id': percorso.mentoraggio['id'],
          'p_valori': patch,
        },
      );
      await carica();
    } catch (e) {
      throw AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile aggiornare il mentoraggio.',
      );
    } finally {
      salvataggio = false;
      notifyListeners();
    }
  }
}
