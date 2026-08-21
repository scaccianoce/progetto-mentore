import 'package:flutter/foundation.dart';

import '../../app_exception.dart';
import '../../sessione_controller.dart';
import '../../supabase_config.dart';

class QuestionariController extends ChangeNotifier {
  QuestionariController(this.sessione);

  final SessioneController sessione;

  final List<Map<String, dynamic>> template = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> domande = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> questionari = <Map<String, dynamic>>[];

  bool caricamento = false;
  String? errore;

  bool get puoGestire => sessione.ruolo?.puoAmministrare ?? false;

  Future<void> carica() async {
    caricamento = true;
    errore = null;
    notifyListeners();

    try {
      final risultati = await Future.wait<dynamic>([
        SupabaseConfig.client
            .from('questionari_template')
            .select()
            .order('destinatario')
            .order('titolo'),
        SupabaseConfig.client
            .from('questionari_domande')
            .select()
            .order('template_id')
            .order('ordine'),
        SupabaseConfig.client
            .from('questionari')
            .select()
            .order('created_at', ascending: false),
      ]);

      template
        ..clear()
        ..addAll((risultati[0] as List).cast<Map<String, dynamic>>());

      domande
        ..clear()
        ..addAll((risultati[1] as List).cast<Map<String, dynamic>>());

      questionari
        ..clear()
        ..addAll((risultati[2] as List).cast<Map<String, dynamic>>());
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile caricare i questionari.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> domandeTemplate(String templateId) =>
      domande
          .where((d) => d['template_id']?.toString() == templateId)
          .toList(growable: false);

  List<Map<String, dynamic>> templatePer(String destinatario) => template
      .where(
        (t) =>
            t['destinatario']?.toString() == destinatario &&
            t['attivo'] != false,
      )
      .toList(growable: false);

  Map<String, dynamic>? questionarioEvento(String eventoId) {
    for (final q in questionari) {
      if (q['provider']?.toString() == 'interno' &&
          q['evento_id']?.toString() == eventoId) {
        return q;
      }
    }
    return null;
  }

  Map<String, dynamic>? questionarioMentoraggio(String mentoraggioId) {
    for (final q in questionari) {
      if (q['provider']?.toString() == 'google_form' &&
          q['mentoraggio_id']?.toString() == mentoraggioId) {
        return q;
      }
    }
    return null;
  }

  Future<String?> salvaTemplate({
    String? id,
    required String titolo,
    required String destinatario,
    String? descrizione,
    bool attivo = true,
  }) =>
      _esegui(() async {
        if (!puoGestire) {
          throw const AppException('Operazione non autorizzata.');
        }

        final dati = <String, dynamic>{
          'titolo': titolo.trim(),
          'destinatario': destinatario,
          'descrizione':
              descrizione == null || descrizione.trim().isEmpty
                  ? null
                  : descrizione.trim(),
          'attivo': attivo,
          'created_by': SupabaseConfig.client.auth.currentUser?.id,
        };

        if (dati['titolo'].toString().isEmpty) {
          throw const AppException('Titolo obbligatorio.');
        }

        if (id == null) {
          await SupabaseConfig.client.from('questionari_template').insert(dati);
        } else {
          dati.remove('created_by');
          await SupabaseConfig.client
              .from('questionari_template')
              .update(dati)
              .eq('id', id);
        }
      });

  Future<String?> aggiungiDomanda({
    required String templateId,
    required int ordine,
    required String testo,
    required String tipo,
    required bool obbligatoria,
    Object? opzioni,
  }) =>
      _esegui(() async {
        if (!puoGestire) {
          throw const AppException('Operazione non autorizzata.');
        }

        if (testo.trim().isEmpty) {
          throw const AppException('Testo della domanda obbligatorio.');
        }

        await SupabaseConfig.client.from('questionari_domande').insert({
          'template_id': templateId,
          'ordine': ordine,
          'testo': testo.trim(),
          'tipo': tipo,
          'obbligatoria': obbligatoria,
          'opzioni': opzioni,
        });
      });

  Future<String?> eliminaDomanda(String domandaId) =>
      _esegui(() async {
        if (!puoGestire) {
          throw const AppException('Operazione non autorizzata.');
        }

        await SupabaseConfig.client
            .from('questionari_domande')
            .delete()
            .eq('id', domandaId);
      });

  Future<String?> creaQuestionarioEvento({
    required String eventoId,
    required String templateId,
    required String titolo,
  }) =>
      _esegui(() async {
        if (!puoGestire) {
          throw const AppException('Operazione non autorizzata.');
        }

        await SupabaseConfig.client.from('questionari').insert({
          'template_id': templateId,
          'titolo': titolo.trim(),
          'provider': 'interno',
          'evento_id': eventoId,
          'aperto': true,
          'created_by': SupabaseConfig.client.auth.currentUser?.id,
        });
      });

  Future<String?> creaQuestionarioMentoraggio({
    required String mentoraggioId,
    required String templateId,
    required String titolo,
    String? urlGoogleForm,
  }) =>
      _esegui(() async {
        final url = urlGoogleForm?.trim();

        await SupabaseConfig.client.from('questionari').insert({
          'template_id': templateId,
          'titolo': titolo.trim(),
          'provider': 'google_form',
          'mentoraggio_id': mentoraggioId,
          'url_esterno': url == null || url.isEmpty ? null : url,
          'aperto': true,
          'created_by': SupabaseConfig.client.auth.currentUser?.id,
        });
      });

  Future<String?> salvaUrlGoogleForm(
    String questionarioId,
    String url,
  ) =>
      _esegui(() async {
        final valore = url.trim();

        if (valore.isEmpty ||
            !(valore.startsWith('https://') || valore.startsWith('http://'))) {
          throw const AppException(
            'Inserire un URL valido del Google Form.',
          );
        }

        await SupabaseConfig.client
            .from('questionari')
            .update({'url_esterno': valore})
            .eq('id', questionarioId);
      });

  Future<String?> eliminaQuestionario(String id) =>
      _esegui(() async {
        if (!puoGestire) {
          throw const AppException('Operazione non autorizzata.');
        }

        await SupabaseConfig.client.from('questionari').delete().eq('id', id);
      });

  Future<Map<String, dynamic>?> caricaQuestionarioEvento(
    String eventoId,
  ) async {
    final q = await SupabaseConfig.client
        .from('questionari')
        .select()
        .eq('provider', 'interno')
        .eq('evento_id', eventoId)
        .eq('aperto', true)
        .maybeSingle();

    if (q == null) return null;

    final templateId = q['template_id'].toString();

    final d = await SupabaseConfig.client
        .from('questionari_domande')
        .select()
        .eq('template_id', templateId)
        .order('ordine');

    return <String, dynamic>{
      'questionario': Map<String, dynamic>.from(q),
      'domande': (d as List).cast<Map<String, dynamic>>(),
    };
  }

  Future<bool> giaCompilato(String questionarioId) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return false;

    final riga = await SupabaseConfig.client
        .from('questionari_compilazioni')
        .select('id')
        .eq('questionario_id', questionarioId)
        .eq('user_id', userId)
        .maybeSingle();

    return riga != null;
  }

  Future<String?> inviaQuestionarioInterno({
    required String questionarioId,
    required Map<String, dynamic> risposte,
  }) async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;

      if (userId == null) {
        throw const AppException('Sessione non valida.');
      }

      if (await giaCompilato(questionarioId)) {
        throw const AppException(
          'Hai già compilato questo questionario.',
        );
      }

      final compilazione = await SupabaseConfig.client
          .from('questionari_compilazioni')
          .insert({
            'questionario_id': questionarioId,
            'user_id': userId,
          })
          .select('id')
          .single();

      final compilazioneId = compilazione['id'].toString();

      try {
        final righe = risposte.entries
            .map(
              (entry) => <String, dynamic>{
                'compilazione_id': compilazioneId,
                'domanda_id': entry.key,
                'valore': entry.value,
              },
            )
            .toList(growable: false);

        if (righe.isNotEmpty) {
          await SupabaseConfig.client.from('questionari_risposte').insert(righe);
        }
      } catch (_) {
        await SupabaseConfig.client
            .from('questionari_compilazioni')
            .delete()
            .eq('id', compilazioneId);
        rethrow;
      }

      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile inviare il questionario.',
      ).messaggio;
    }
  }

  Future<String?> _esegui(Future<void> Function() azione) async {
    try {
      await azione();
      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Operazione sui questionari non riuscita.',
      ).messaggio;
    }
  }
}
