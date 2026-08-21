import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_exception.dart';
import '../../sessione_controller.dart';
import '../../supabase_config.dart';

class RisorseMentoringController extends ChangeNotifier {
  RisorseMentoringController(this.sessione);

  final SessioneController sessione;

  static const String bucket = 'risorse-mentoring';
  static const int dimensioneMassima = 20 * 1024 * 1024;

  static const List<String> categorie = <String>[
    'Materiale di presentazione',
    "Materiale per l'attività di mentoraggio",
    'Materiale burocratico/amministrativo',
    'Altro',
  ];

  final List<Map<String, dynamic>> risorse = <Map<String, dynamic>>[];
  final List<String> anniAccademici = <String>[];

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
            .from('risorse_mentoring')
            .select()
            .eq('attivo', true)
            .order('categoria')
            .order('ordine')
            .order('titolo'),
        SupabaseConfig.client
            .from('anni_accademici')
            .select('codice')
            .order('codice', ascending: false),
      ]);

      risorse
        ..clear()
        ..addAll((risultati[0] as List).cast<Map<String, dynamic>>());

      anniAccademici
        ..clear()
        ..addAll(
          (risultati[1] as List)
              .cast<Map<String, dynamic>>()
              .map((riga) => riga['codice'].toString()),
        );
    } catch (e) {
      errore = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile caricare le risorse per il mentoring.',
      ).messaggio;
    } finally {
      caricamento = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> perCategoria(String categoria) => risorse
      .where((riga) => riga['categoria']?.toString() == categoria)
      .toList(growable: false);

  Future<String?> caricaRisorsa({
    required Uint8List bytes,
    required String nomeFile,
    required String titolo,
    required String categoria,
    String? descrizione,
    String? annoAccademico,
  }) async {
    String? pathCaricato;
    try {
      if (!puoGestire) {
        throw const AppException('Operazione non autorizzata.');
      }
      if (titolo.trim().isEmpty) {
        throw const AppException('Titolo obbligatorio.');
      }
      if (!categorie.contains(categoria)) {
        throw const AppException('Categoria non valida.');
      }
      if (bytes.lengthInBytes > dimensioneMassima) {
        throw const AppException('Il file supera il limite massimo di 20 MB.');
      }

      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) {
        throw const AppException('Sessione non valida.');
      }

      final nomeSicuro = nomeFile.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final categoriaSicura =
          categoria.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final path = '$categoriaSicura/$timestamp-$userId-$nomeSicuro';
      pathCaricato = path;

      await SupabaseConfig.client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: false),
          );

      await SupabaseConfig.client.from('risorse_mentoring').insert({
        'titolo': titolo.trim(),
        'descrizione': descrizione == null || descrizione.trim().isEmpty
            ? null
            : descrizione.trim(),
        'categoria': categoria,
        'anno_accademico':
            annoAccademico == null || annoAccademico.isEmpty ? null : annoAccademico,
        'storage_path': path,
        'nome_file': nomeFile,
        'dimensione_bytes': bytes.lengthInBytes,
        'uploaded_by': userId,
        'attivo': true,
      });

      await carica();
      return null;
    } catch (e) {
      if (pathCaricato != null) {
        try {
          await SupabaseConfig.client.storage.from(bucket).remove([pathCaricato]);
        } catch (_) {}
      }
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile caricare la risorsa.',
      ).messaggio;
    }
  }

  Future<Uri> urlDownload(Map<String, dynamic> risorsa) async {
    final path = risorsa['storage_path']?.toString() ?? '';
    if (path.isEmpty) {
      throw const AppException('Percorso del file non disponibile.');
    }
    final url = await SupabaseConfig.client.storage
        .from(bucket)
        .createSignedUrl(path, 60 * 30);
    return Uri.parse(url);
  }

  Future<String?> elimina(Map<String, dynamic> risorsa) async {
    try {
      if (!puoGestire) {
        throw const AppException('Operazione non autorizzata.');
      }
      final id = risorsa['id']?.toString();
      final path = risorsa['storage_path']?.toString();
      if (id == null || id.isEmpty) {
        throw const AppException('Risorsa non valida.');
      }

      await SupabaseConfig.client.from('risorse_mentoring').delete().eq('id', id);
      if (path != null && path.isNotEmpty) {
        try {
          await SupabaseConfig.client.storage.from(bucket).remove([path]);
        } catch (_) {}
      }
      await carica();
      return null;
    } catch (e) {
      return AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile eliminare la risorsa.',
      ).messaggio;
    }
  }
}
