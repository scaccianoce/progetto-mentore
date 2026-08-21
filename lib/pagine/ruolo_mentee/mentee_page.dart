import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_exception.dart';
import '../../dinamico/maschera_dinamica_controller.dart';
import '../../dinamico/maschera_dinamica_widget.dart';
import '../../sessione_controller.dart';
import '../../supabase_config.dart';
import '../template/componenti_pagina_dinamica.dart';
import '../template/template_elenco_dettaglio_page.dart';
import 'mentee_controller.dart';

class MenteePage extends StatefulWidget {
  const MenteePage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<MenteePage> createState() => _MenteePageState();
}

class _MenteePageState extends State<MenteePage> {
  static const _campiMentee = <String>{
    'data_inizio',
    'data_fine',
    'numero_studenti',
    'sede',
    'note',
    'svolgimento',
    'giorni_orari_lezioni',
  };

  static const configurazione = ConfigurazionePaginaDinamica(
    tabella: 'mentoraggi',
    prefissiNascostiPartecipante: <String>['osservazioni'],
    campiModificabiliPartecipante: _campiMentee,
    campi: <String, PersonalizzazioneCampo>{
      'insegnamento_id': PersonalizzazioneCampo(nascosto: true),
      'anno_accademico': PersonalizzazioneCampo(modificabilePartecipante: false),
      'scheda_sintesi_pdf_url': PersonalizzazioneCampo(nascosto: true),
    },
  );

  late final MenteeController controller;

  @override
  void initState() {
    super.initState();
    controller = MenteeController()..carica();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => TemplatePaginaElencoDettaglio(
          caricamento: controller.caricamento && controller.percorsi.isEmpty,
          errore: controller.errore,
          vuoto: controller.percorsi.isEmpty,
          messaggioVuoto: 'Nessun mentoraggio disponibile nel ruolo mentee.',
          larghezzaElenco: 350,
          elenco: ElencoRecordDinamico<PercorsoMentee>(
            elementi: controller.percorsi,
            idSelezionato: controller.selezionato?.mentoraggio['id']?.toString(),
            id: (p) => p.mentoraggio['id']?.toString() ?? '',
            titolo: (p) => p.insegnamento['insegnamento']?.toString() ?? '',
            sottotitolo: (p) =>
                '${p.mentoraggio['anno_accademico'] ?? ''}${p.annoCorrente ? ' · corrente' : ' · storico'}',
            onSeleziona: controller.seleziona,
          ),
          dettaglio: Card(margin: EdgeInsets.zero, child: _dettaglio()),
        ),
      );

  Widget _dettaglio() {
    final percorso = controller.selezionato;
    if (percorso == null) {
      return const Center(child: Text('Seleziona un mentoraggio.'));
    }

    return DettaglioRecordDinamico(
      configurazione: configurazione,
      valori: percorso.mentoraggio,
      partecipante: true,
      prima: <Widget>[
        Row(
          children: [
            Expanded(
              child: Text(
                'Ruolo mentee · ${percorso.mentoraggio['anno_accademico'] ?? ''}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (percorso.annoCorrente)
              FilledButton.icon(
                onPressed: controller.salvataggio ? null : _modifica,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modifica dati annuali'),
              ),
          ],
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Insegnamento'),
          subtitle: Text(percorso.insegnamento['insegnamento']?.toString() ?? ''),
        ),
        if (!percorso.annoCorrente)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.lock_outline),
            title: Text('Mentoraggio storico'),
            subtitle: Text('I dati degli anni accademici precedenti sono in sola lettura.'),
          ),
        const Divider(),
        Text('Team di mentoraggio', style: Theme.of(context).textTheme.titleMedium),
        ...percorso.mentori.map(
          (mentore) => ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text('${mentore['nome'] ?? ''} ${mentore['cognome'] ?? ''}'.trim()),
            subtitle: Text('${mentore['tipo'] ?? ''} · ${mentore['email_unipa'] ?? ''}'),
          ),
        ),
        const Divider(),
      ],
      dopo: <Widget>[
        ..._linkPdf(percorso.mentoraggio),
      ],
    );
  }


  List<Widget> _linkPdf(
    Map<String, dynamic> mentoraggio,
  ) {
    final valore =
        mentoraggio['scheda_sintesi_pdf_url']?.toString().trim() ?? '';

    if (valore.isEmpty) {
      return const <Widget>[];
    }

    final nomeFile = valore.split('/').last;

    return <Widget>[
      Card(
        margin: const EdgeInsets.only(top: 12),
        child: ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Scheda di sintesi'),
          subtitle: Text(
            nomeFile.isEmpty ? 'Documento disponibile' : nomeFile,
          ),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => _apriPdf(valore),
        ),
      ),
    ];
  }

  Future<void> _apriPdf(String valore) async {
    try {
      final url = valore.startsWith('http://') || valore.startsWith('https://')
          ? valore
          : await SupabaseConfig.client.storage
              .from('schede-sintesi')
              .createSignedUrl(valore, 3600);
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('URL non apribile');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire la scheda di sintesi.')),
      );
    }
  }

  Future<void> _modifica() async {
    final percorso = controller.selezionato;
    if (percorso == null || !percorso.annoCorrente) return;
    final valori = await mostraMascheraDinamica(
      context: context,
      configurazione: configurazione,
      valoriIniziali: percorso.mentoraggio,
      partecipante: true,
      titolo:
          'Dati ${percorso.insegnamento['insegnamento'] ?? ''} · ${percorso.mentoraggio['anno_accademico'] ?? ''}',
    );
    if (valori == null) return;
    try {
      await controller.salva(valori);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.messaggio)));
    }
  }
}
