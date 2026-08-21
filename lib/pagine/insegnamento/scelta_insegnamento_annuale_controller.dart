import '../../supabase_config.dart';

class StatoInsegnamentoAnnuale {
  const StatoInsegnamentoAnnuale({
    required this.annoAccademico,
    required this.annoCorrente,
    required this.nonRichiesto,
    required this.puoSelezionare,
    required this.puoCreare,
    required this.puoModificare,
    this.partecipazioneStato,
    this.soloMentore = false,
    this.mentoraggioId,
    this.insegnamentoId,
  });

  factory StatoInsegnamentoAnnuale.daMap(Map<String, dynamic> map) {
    return StatoInsegnamentoAnnuale(
      annoAccademico: map['anno_accademico']?.toString() ?? '',
      annoCorrente: map['anno_corrente'] == true,
      nonRichiesto: map['non_richiesto'] == true,
      puoSelezionare: map['puo_selezionare'] == true,
      puoCreare: map['puo_creare'] == true,
      puoModificare: map['puo_modificare'] == true,
      partecipazioneStato: map['partecipazione_stato']?.toString(),
      soloMentore: map['solo_mentore'] == true,
      mentoraggioId: map['mentoraggio_id']?.toString(),
      insegnamentoId: map['insegnamento_id']?.toString(),
    );
  }

  final String annoAccademico;
  final bool annoCorrente;
  final bool nonRichiesto;
  final bool puoSelezionare;
  final bool puoCreare;
  final bool puoModificare;
  final String? partecipazioneStato;
  final bool soloMentore;
  final String? mentoraggioId;
  final String? insegnamentoId;

  bool get haMentoraggio => mentoraggioId != null;
  bool get partecipazioneConfermata =>
      partecipazioneStato == null ||
      partecipazioneStato == 'confermato' ||
      partecipazioneStato == 'nuovo';
}

class SceltaInsegnamentoAnnualeController {
  String? _annoGestione;

  Future<String?> annoGestione() async {
    if (_annoGestione != null && _annoGestione!.isNotEmpty) {
      return _annoGestione;
    }
    final raw = await SupabaseConfig.client.rpc(
      'anno_accademico_gestione_insegnamenti',
    );
    _annoGestione = raw?.toString();
    return _annoGestione;
  }

  Future<StatoInsegnamentoAnnuale> caricaStato() async {
    final anno = await annoGestione();

    final raw = await SupabaseConfig.client.rpc(
      'insegnamento_stato_annuale',
      params: <String, dynamic>{'p_anno_accademico': anno},
    );

    final mappa = Map<String, dynamic>.from(raw as Map);

    // solo_mentore appartiene alla partecipazione annuale, non
    // all'insegnamento. Lo leggiamo direttamente dalla tabella così
    // non è necessario modificare la RPC insegnamento_stato_annuale.
    if (anno != null && anno.isNotEmpty) {
      final userId = SupabaseConfig.client.auth.currentUser?.id;

      if (userId != null) {
        final partecipazione = await SupabaseConfig.client
            .from('partecipazioni_annuali')
            .select('stato, solo_mentore')
            .eq('user_id', userId)
            .eq('anno_accademico', anno)
            .maybeSingle();

        if (partecipazione != null) {
          mappa['partecipazione_stato'] =
              partecipazione['stato']?.toString();
          mappa['solo_mentore'] =
              partecipazione['solo_mentore'] == true;
        }
      }
    }

    return StatoInsegnamentoAnnuale.daMap(mappa);
  }

  Future<List<Map<String, dynamic>>> caricaInsegnamenti() async {
    final raw = await SupabaseConfig.client.rpc('insegnamenti_miei');

    return (raw as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<void> seleziona(String insegnamentoId) async {
    final anno = await annoGestione();
    await SupabaseConfig.client.rpc(
      'insegnamento_seleziona_per_anno',
      params: <String, dynamic>{
        'p_insegnamento_id': insegnamentoId,
        'p_anno_accademico': anno,
      },
    );
  }

  Future<void> crea(Map<String, dynamic> valori) async {
    final anno = await annoGestione();
    await SupabaseConfig.client.rpc(
      'insegnamento_crea_per_anno',
      params: <String, dynamic>{
        'p_valori': valori,
        'p_anno_accademico': anno,
      },
    );
  }

  Future<void> modifica(
    String insegnamentoId,
    Map<String, dynamic> valori,
  ) async {
    final anno = await annoGestione();
    await SupabaseConfig.client.rpc(
      'insegnamento_modifica_autorizzata',
      params: <String, dynamic>{
        'p_insegnamento_id': insegnamentoId,
        'p_valori': valori,
        'p_anno_accademico': anno,
      },
    );
  }

  void invalidaAnno() {
    _annoGestione = null;
  }
}
