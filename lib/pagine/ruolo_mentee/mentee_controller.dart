import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_exception.dart';
import '../../supabase_config.dart';

class MenteeController extends ChangeNotifier {
  MenteeController({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;
  Map<String, dynamic>? insegnamento;
  Map<String, dynamic>? mentoraggio;
  List<Map<String, dynamic>> mentori = const [];
  bool caricamento = false;
  String? errore;

  Future<void> carica() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    caricamento = true;
    errore = null;
    notifyListeners();
    try {
      final Map<String, dynamic>? anno = await _client
          .from('anni_accademici')
          .select('codice')
          .eq('corrente', true)
          .maybeSingle();
      final String? codice = anno?['codice']?.toString();
      if (codice == null) {
        throw const AppException('Nessun anno accademico corrente.');
      }
      insegnamento = await _client
          .from('insegnamenti')
          .select('id, insegnamento, anno_accademico, cds')
          .eq('docente_id', userId)
          .eq('anno_accademico', codice)
          .maybeSingle();
      if (insegnamento == null) return;
      mentoraggio = await _client
          .from('mentoraggi')
          .select(
            'id, insegnamento_id, data_visita_1, data_visita_2, '
            'data_visita_3, data_visita_4, data_focus_group, '
            //'osservazioni_aula, osservazioni_focus_group, link_questionario, '
            'data_incontro_finale, scheda_sintesi, data_invio_scheda, stato',
          )
          .eq('insegnamento_id', insegnamento!['id'])
          .maybeSingle();
      if (mentoraggio == null) return;
      final List<dynamic> assegnazioni = await _client
          .from('mentoraggio_mentori')
          .select('mentore_id, tipo')
          .eq('mentoraggio_id', mentoraggio!['id']);
      final List<String> ids = assegnazioni
          .map((e) => e['mentore_id'].toString())
          .toSet()
          .toList();
      if (ids.isNotEmpty) {
        final List<dynamic> anagrafiche = await _client
            .from('anagrafica')
            .select('user_id, nome, cognome, email_unipa, cellulare')
            .inFilter('user_id', ids);
        mentori =
            assegnazioni.map<Map<String, dynamic>>((dynamic a) {
              final Map<String, dynamic> persona = anagrafiche
                  .cast<Map<String, dynamic>>()
                  .firstWhere(
                    (p) => p['user_id'] == a['mentore_id'],
                    orElse: () => <String, dynamic>{},
                  );
              return <String, dynamic>{...persona, 'tipo': a['tipo']};
            }).toList()..sort((prima, seconda) {
              final prioritaPrima =
                  prima['tipo']?.toString().toLowerCase() == 'senior' ? 1 : 0;
              final prioritaSeconda =
                  seconda['tipo']?.toString().toLowerCase() == 'senior' ? 1 : 0;
              final confrontoTipo = prioritaPrima.compareTo(prioritaSeconda);
              if (confrontoTipo != 0) {
                return confrontoTipo;
              }
              final nomePrima =
                  '${prima['cognome'] ?? ''} ${prima['nome'] ?? ''}'
                      .toLowerCase();
              final nomeSeconda =
                  '${seconda['cognome'] ?? ''} ${seconda['nome'] ?? ''}'
                      .toLowerCase();
              return nomePrima.compareTo(nomeSeconda);
            });
      }
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile caricare il mentoraggio.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }
}
