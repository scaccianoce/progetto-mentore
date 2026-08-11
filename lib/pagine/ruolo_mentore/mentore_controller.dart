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
  });
  final Map<String, dynamic> mentoraggio;
  final Map<String, dynamic> insegnamento;
  final Map<String, dynamic> docente;
  final List<Map<String, dynamic>> team;
}

class MentoreController extends ChangeNotifier {
  MentoreController({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;
  final SupabaseClient _client;
  List<PercorsoMentore> percorsi = const [];
  PercorsoMentore? selezionato;
  bool caricamento = false;
  bool salvataggio = false;
  String? errore;

  Future<void> carica() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    caricamento = true;
    errore = null;
    notifyListeners();
    try {
      final List<dynamic> mie = await _client
          .from('mentoraggio_mentori')
          .select('mentoraggio_id, tipo')
          .eq('mentore_id', userId);
      final List<String> mentoraggioIds = mie
          .map((e) => e['mentoraggio_id'].toString())
          .toSet()
          .toList();
      if (mentoraggioIds.isEmpty) {
        percorsi = const [];
        return;
      }
      final List<Map<String, dynamic>> mentoraggi =
          (await _client
                  .from('mentoraggi')
                  .select()
                  .inFilter('id', mentoraggioIds))
              .cast<Map<String, dynamic>>();
      final List<String> insegnamentoIds = mentoraggi
          .map((m) => m['insegnamento_id'].toString())
          .toList();
      final List<Map<String, dynamic>> insegnamenti =
          (await _client
                  .from('insegnamenti')
                  .select()
                  .inFilter('id', insegnamentoIds))
              .cast<Map<String, dynamic>>();
      final List<String> docentiIds = insegnamenti
          .map((i) => i['docente_id'].toString())
          .toSet()
          .toList();
      final List<Map<String, dynamic>> docenti =
          (await _client
                  .from('anagrafica')
                  .select('user_id, nome, cognome, email_unipa, cellulare')
                  .inFilter('user_id', docentiIds))
              .cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> assegnazioni =
          (await _client
                  .from('mentoraggio_mentori')
                  .select('mentoraggio_id, mentore_id, tipo')
                  .inFilter('mentoraggio_id', mentoraggioIds))
              .cast<Map<String, dynamic>>();
      final List<String> teamIds = assegnazioni
          .map((a) => a['mentore_id'].toString())
          .toSet()
          .toList();
      final List<Map<String, dynamic>> personeTeam = teamIds.isEmpty
          ? const []
          : (await _client
                    .from('anagrafica')
                    .select('user_id, nome, cognome, email_unipa')
                    .inFilter('user_id', teamIds))
                .cast<Map<String, dynamic>>();
      percorsi = mentoraggi
          .map((m) {
            final Map<String, dynamic> ins = insegnamenti.firstWhere(
              (i) => i['id'] == m['insegnamento_id'],
            );
            final Map<String, dynamic> docente = docenti.firstWhere(
              (d) => d['user_id'] == ins['docente_id'],
              orElse: () => <String, dynamic>{},
            );
            final List<Map<String, dynamic>> teamNonOrdinato = assegnazioni
                .where((a) => a['mentoraggio_id'] == m['id'])
                .map((a) {
                  final persona = personeTeam.firstWhere(
                    (p) => p['user_id'] == a['mentore_id'],
                    orElse: () => <String, dynamic>{},
                  );
                  return <String, dynamic>{...persona, 'tipo': a['tipo']};
                })
                .toList(growable: false);
            final List<Map<String, dynamic>> team = <Map<String, dynamic>>[
              ...teamNonOrdinato.where(
                (persona) =>
                    persona['tipo']?.toString().toLowerCase() != 'senior',
              ),
              ...teamNonOrdinato.where(
                (persona) =>
                    persona['tipo']?.toString().toLowerCase() == 'senior',
              ),
            ];
            return PercorsoMentore(
              mentoraggio: m,
              insegnamento: ins,
              docente: docente,
              team: team,
            );
          })
          .toList(growable: false);
      selezionato = percorsi.isEmpty ? null : percorsi.first;
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
    if (selezionato == null) return;
    salvataggio = true;
    notifyListeners();
    try {
      await _client
          .from('mentoraggi')
          .update(valori)
          .eq('id', selezionato!.mentoraggio['id']);
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
