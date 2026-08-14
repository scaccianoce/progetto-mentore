import 'package:flutter/material.dart';

import '../../app_exception.dart';
import '../../dinamico/maschera_dinamica_controller.dart';
import '../../dinamico/maschera_dinamica_widget.dart';
import '../../sessione_controller.dart';
import '../template/pagina_scheda_dinamica.dart';
import 'profilo_controller.dart';

class ProfiloPage extends StatefulWidget {
  const ProfiloPage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<ProfiloPage> createState() => _ProfiloPageState();
}

class _ProfiloPageState extends State<ProfiloPage> {
  late final ProfiloController _controller;

  bool get _partecipante => widget.sessione.ruolo == AppRole.participant;

  /// PERSONALIZZAZIONE PROFILO - tabella di riferimento: Anagrafica
  /// I campi non elencati sono visualizzati automaticamente.
  /// Le etichette derivano dal nome colonna: "_" -> spazio e sola iniziale
  /// maiuscola. Qui restano solo vincoli/tipi realmente speciali.
  ConfigurazionePaginaDinamica get _configurazione =>
      ConfigurazionePaginaDinamica(
        tabella: 'anagrafica',
        campi: <String, PersonalizzazioneCampo>{
          'user_id': const PersonalizzazioneCampo(nascosto: true),
          'email_unipa': const PersonalizzazioneCampo(solaLettura: true),
          'cod_ssd': PersonalizzazioneCampo(
            tipo: TipoCampoDinamico.scelta,
            valoriScelta: _controller.ssd
                .map((riga) => riga['cod_ssd'].toString())
                .toList(growable: false),
          ),
          // `ruolo_accademico` e `fascia_eta`: nessuna lista in Dart.
          // Se sono campi a scelta, le opzioni devono essere definite nel DB
          // come PostgreSQL ENUM e vengono caricate da app_database_schema.
          'anno_prima_partecipazione': PersonalizzazioneCampo(
            tipo: TipoCampoDinamico.scelta,
            valoriScelta: _controller.anniAccademici,
          ),
        },
      );

  @override
  void initState() {
    super.initState();
    _controller = ProfiloController(sessione: widget.sessione)..carica();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final profilo = _controller.profilo;
      return PaginaSchedaDinamica(
        titolo: 'Il mio profilo',
        configurazione: _configurazione,
        valori: profilo,
        partecipante: _partecipante,
        caricamento: _controller.caricamento && profilo == null,
        errore: _controller.errore,
        vuoto: profilo == null,
        messaggioVuoto: 'Profilo non trovato.',
        azioni: <Widget>[
          if (_controller.puoModificare)
            FilledButton.icon(
              onPressed: _controller.salvataggio ? null : _apriEditor,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifica'),
            )
          else
            OutlinedButton.icon(
              onPressed: _controller.richiediModifica,
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Richiedi modifica'),
            ),
        ],
      );
    },
  );

  Future<void> _apriEditor() async {
    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: _configurazione,
      valoriIniziali: _controller.profilo!,
      partecipante: _partecipante,
      titolo: 'Modifica profilo',
    );
    if (valori == null) return;
    try {
      await _controller.salva(valori);
    } on AppException catch (errore) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errore.messaggio)));
      }
    }
  }
}
