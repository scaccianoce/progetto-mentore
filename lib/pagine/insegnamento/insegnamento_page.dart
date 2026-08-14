import 'package:flutter/material.dart';

import '../../app_exception.dart';
import '../../dinamico/maschera_dinamica_controller.dart';
import '../../dinamico/maschera_dinamica_widget.dart';
import '../../sessione_controller.dart';
import '../template/pagina_scheda_dinamica.dart';
import 'insegnamento_controller.dart';

class InsegnamentoPage extends StatefulWidget {
  const InsegnamentoPage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<InsegnamentoPage> createState() => _InsegnamentoPageState();
}

class _InsegnamentoPageState extends State<InsegnamentoPage> {
  late final InsegnamentoController _controller;

  bool get _partecipante => widget.sessione.ruolo == AppRole.participant;

  /// PERSONALIZZAZIONE INSEGNAMENTO:
  /// vengono dichiarati solo campi nascosti, scelte e label non deducibili.
  ConfigurazionePaginaDinamica get _configurazione {
    final nuovo = _controller.insegnamento == null;
    return ConfigurazionePaginaDinamica(
      tabella: 'insegnamenti',
      campi: <String, PersonalizzazioneCampo>{
        'docente_id': const PersonalizzazioneCampo(nascosto: true),
        'anno_accademico': const PersonalizzazioneCampo(nascosto: true),
        'insegnamento': PersonalizzazioneCampo(
          modificabilePartecipante: nuovo,
        ),
        'semestre': PersonalizzazioneCampo(
          // Le opzioni arrivano dal PostgreSQL ENUM del DB.
          modificabilePartecipante: nuovo,
        ),
        'cfu': const PersonalizzazioneCampo(etichetta: 'CFU'),
        'cds': const PersonalizzazioneCampo(etichetta: 'Corso di studi'),
        // `anno_erogazione` viene trattato automaticamente come scelta
        // quando la colonna usa un PostgreSQL ENUM.
        // `svolgimento` non viene configurato qui: se la colonna e un
        // PostgreSQL ENUM, TipoCampoDinamico.scelta e i relativi valori
        // vengono ricavati automaticamente da Database Enumerated Types
        // tramite app_database_schema.
        // `gia_mentorato`: opzioni lette dal PostgreSQL ENUM del DB.
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = InsegnamentoController(sessione: widget.sessione)..carica();
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
      final insegnamento = _controller.insegnamento;
      return PaginaSchedaDinamica(
        titolo: 'Il mio insegnamento — ${_controller.annoCorrente ?? ''}',
        configurazione: _configurazione,
        valori: insegnamento,
        partecipante: _partecipante,
        caricamento: _controller.caricamento,
        errore: _controller.errore,
        azioni: <Widget>[
          if (_controller.puoModificare)
            FilledButton.icon(
              onPressed: _controller.salvataggio ? null : _apriEditor,
              icon: Icon(
                insegnamento == null ? Icons.add : Icons.edit_outlined,
              ),
              label: Text(insegnamento == null ? 'Inserisci' : 'Modifica'),
            ),
        ],
        vuoto: insegnamento == null,
        messaggioVuoto: 'Nessun insegnamento per l’anno corrente.',
      );
    },
  );

  Future<void> _apriEditor() async {
    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: _configurazione,
      valoriIniziali:
          _controller.insegnamento ??
          <String, dynamic>{
            'insegnamento': '',
          },
      partecipante: _partecipante,
      titolo: 'Dati dell’insegnamento ${_controller.insegnamento?['insegnamento'] ?? ''}',
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
