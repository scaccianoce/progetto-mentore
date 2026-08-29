import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_core.dart';
import '../../../app/app_session_controller.dart';
import '../../../supporto/utilita.dart';
import 'anni_accademici_backoffice_controller.dart';

/// Sintesi annuale calcolata direttamente dalle tabelle reali del DB.
/// Non richiede view/materialized view/RPC di riepilogo.
class AnniAccademiciBackofficePage extends StatefulWidget {
  const AnniAccademiciBackofficePage({super.key, required this.sessione});

  final SessioneController sessione;
    

  @override
  State<AnniAccademiciBackofficePage> createState() =>
      _AnniAccademiciBackofficePageState();
}

/// Stato interno della pagina; coordina rendering e interazioni della UI.
class _AnniAccademiciBackofficePageState
    extends State<AnniAccademiciBackofficePage> {
  late final AnniAccademiciBackofficeController controller;
  
  final ScrollController _scrollOrizzontale = ScrollController();

  /// Inizializza lo stato della pagina e avvia le operazioni iniziali necessarie.
  @override
  void initState() {
    super.initState();
    controller = AnniAccademiciBackofficeController(widget.sessione)
      ..carica();
  }

  /// Rilascia listener e controller associati allo stato della pagina.
  @override
  void dispose() {
    controller.dispose();
    _scrollOrizzontale.dispose();
    super.dispose();
  }

  /// Costruisce l’interfaccia grafica di questo componente.
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sintesi anni accademici',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Aggiorna',
                onPressed: controller.caricamento
                    ? null
                    : controller.carica,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _nuovoAnno(context),
                icon: const Icon(Icons.add),
                label: const Text('Nuovo anno'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (controller.caricamento) const LinearProgressIndicator(),
          if (controller.errore != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(controller.errore!),
            ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Scrollbar(
                controller: _scrollOrizzontale,
                thumbVisibility: true,
                trackVisibility: true,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  controller: _scrollOrizzontale,
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Anno')),
                        DataColumn(label: Text('Stato')),
                        DataColumn(label: Text('Partecipanti'), numeric: true),
                        DataColumn(label: Text('Da confermare'), numeric: true),
                        DataColumn(label: Text('Confermati'), numeric: true),
                        DataColumn(label: Text('Rinunce'), numeric: true),
                        DataColumn(label: Text('Insegnamenti'), numeric: true),
                        DataColumn(
                          label: Text('Insegnamenti mentorati'),
                          numeric: true,
                        ),
                        DataColumn(label: Text('Conclusi'), numeric: true),
                        DataColumn(label: Text('Eventi'), numeric: true),
                        DataColumn(label: Text('Iscrizioni eventi'), numeric: true),
                        DataColumn(label: Text('Presenze eventi'), numeric: true),
                        DataColumn(
                          label: Text('Media presenze/evento'),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('House of Mentore'),
                          numeric: true,
                        ),
                        DataColumn(label: Text('Iscrizioni HoM'), numeric: true),
                        DataColumn(label: Text('Presenze HoM'), numeric: true),
                        DataColumn(
                          label: Text('Media presenze/HoM'),
                          numeric: true,
                        ),
                        DataColumn(label: Text('Azioni'),numeric: false),
                      ],
                      rows: [
                        for (final anno in controller.anni)
                          _rigaAnno(context, anno),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      );

  /// Costruisce la riga relativa a anno.
  DataRow _rigaAnno(BuildContext context, Map<String, dynamic> anno) {
    final codice = anno['codice']?.toString() ?? '';
    final r = controller.riepiloghi[codice] ?? RiepilogoAnnoAccademico.vuoto(codice);
    return DataRow(cells: [
      DataCell(Row(children: [
        if (_annoCorrente(anno))
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.check_circle, size: 18),
          ),
        Text(codice),
      ])),
      DataCell(_chipStatoAnno(anno)),
      DataCell(Text('${r.partecipanti}')),
      DataCell(Text('${r.daConfermare}')),
      DataCell(Text('${r.confermati}')),
      DataCell(Text('${r.rinunce}')),
      DataCell(Text('${r.insegnamenti}')),
      DataCell(Text('${r.insegnamentiMentorati}')),
      DataCell(Text('${r.mentoraggiConclusi}')),
      DataCell(Text('${r.eventi}')),
      DataCell(Text('${r.iscrizioniEventi}')),
      DataCell(Text('${r.presenzeEventi}')),
      DataCell(Text(r.mediaPresenzeEventi.toStringAsFixed(1))),
      DataCell(Text('${r.houseOfMentore}')),
      DataCell(Text('${r.iscrizioniHom}')),
      DataCell(Text('${r.presenzeHom}')),
      DataCell(Text(r.mediaPresenzeHom.toStringAsFixed(1))),
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Esporta tabelle CSV',
              onPressed: () => _esportaAnno(context, codice),
              icon: const Icon(Icons.download_outlined),
            ),
            if (_statoAnno(anno) == 'preparazione')
              IconButton(
                tooltip: 'Genera richieste di conferma dai partecipanti dell’anno attivo',
                onPressed: () => _generaRichieste(context, codice),
                icon: const Icon(Icons.how_to_reg_outlined),
              ),
            PopupMenuButton<String>(
              tooltip: 'Cambia stato anno',
              onSelected: (stato) => _impostaStatoAnno(context, codice, stato),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'preparazione',
                  child: Text('Imposta in preparazione'),
                ),
                PopupMenuItem(
                  value: 'attivo',
                  child: Text('Imposta attivo'),
                ),
                PopupMenuItem(
                  value: 'chiuso',
                  child: Text('Chiudi anno'),
                ),
              ],
            ),
          ],
        ),
      ),

    ]);
  }

  /// Esporta anno.
  Future<void> _esportaAnno(BuildContext context, String anno) async {
    try {
      final tabelle = await _datiGrezziAnno(anno);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('CSV · $anno'),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ogni esportazione contiene i valori grezzi letti direttamente dalla tabella DB. '
                    'Il pulsante copia il CSV negli appunti; il salvataggio file multipiattaforma verra collegato al progetto completo/pubspec.',
                  ),
                  const SizedBox(height: 12),
                  for (final voce in tabelle.entries)
                    ListTile(
                      title: Text('${voce.key}.csv'),
                      subtitle: Text('${voce.value.length} righe'),
                      trailing: IconButton(
                        tooltip: 'Copia CSV',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _csv(voce.value)),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${voce.key}.csv copiato negli appunti.')),
                          );
                        },
                        icon: const Icon(Icons.copy_outlined),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      final eccezione = AppErrorMapper.converti(
        e,
        messaggioGenerico: 'Impossibile esportare i dati.',
      );
      _messaggio(context, eccezione.messaggio);
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> _datiGrezziAnno(
    String anno,
  ) async {
    final rigaAnno = await controller.caricaRigaAnno(anno);

    // Tutte le relazioni annuali partono da mentoraggi.anno_accademico.
    // Non viene mai interrogato insegnamenti.anno_accademico, colonna che
    // nella nuova struttura non esiste piu.
    final dati = await controller.caricaDatiAnno(anno);

    return dati.esportazione(rigaAnno: rigaAnno);
  }

  /// Imposta stato anno.
  Future<void> _impostaStatoAnno(
    BuildContext context,
    String codice,
    String stato,
  ) async {
    final errore = await controller.impostaStatoAnno(codice, stato);
    if (!context.mounted) return;
    _messaggio(context, errore);
  }

  /// Genera richieste.
  Future<void> _generaRichieste(
    BuildContext context,
    String annoDestinazione,
  ) async {
    final annoSorgente = controller.annoAttivo;
    final conferma = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Generare le richieste di partecipazione?'),
            content: Text(
              'Verranno predisposte le richieste per $annoDestinazione '
              'partendo dai partecipanti dell’anno '
              '${annoSorgente ?? 'attivo'}. Le righe già presenti non verranno duplicate.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Genera'),
              ),
            ],
          ),
        ) ??
        false;
    if (!conferma) return;

    final errore = await controller.generaRichiestePartecipazione(
      annoDestinazione,
      annoSorgente: annoSorgente,
    );
    if (!context.mounted) return;
    _messaggio(context, errore);
  }

  /// Avvia la creazione di anno.
  Future<void> _nuovoAnno(BuildContext context) async {
    final codice = TextEditingController();
    DateTime? inizio;
    DateTime? fine;
    final salva = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Nuovo anno accademico'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codice,
                      decoration: const InputDecoration(labelText: 'Codice (es. 2026-27)'),
                    ),
                    _rigaData(context, etichetta: 'Data inizio', valore: inizio,
                        onChanged: (v) => setDialogState(() => inizio = v)),
                    _rigaData(context, etichetta: 'Data fine', valore: fine,
                        onChanged: (v) => setDialogState(() => fine = v)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crea')),
              ],
            ),
          ),
        ) ??
        false;
    if (salva) {
      final errore = await controller.aggiungiAnno(
        codice.text,
        dataIso(inizio),
        dataIso(fine),
      );
      if (!context.mounted) {
        codice.dispose();
        return;
      }
      _messaggio(context, errore);
    }
    codice.dispose();
  }

  /// Costruisce la riga relativa a data.
  Widget _rigaData(
    BuildContext context, {
    required String etichetta,
    required DateTime? valore,
    required ValueChanged<DateTime?> onChanged,
  }) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          valore == null ? etichetta : '$etichetta: ${formattaData(valore)}',
        ),
        trailing: IconButton(
          tooltip: 'Scegli data',
          onPressed: () async {
            final scelta = await showDatePicker(
              context: context,
              initialDate: valore ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2200),
            );
            if (scelta != null) onChanged(scelta);
          },
          icon: const Icon(Icons.calendar_month_outlined),
        ),
      );
}

/// Gestisce l’operazione interna “stato anno” della pagina.
String _statoAnno(Map<String, dynamic> anno) {
  final stato = anno['stato']?.toString();
  if (stato != null && stato.isNotEmpty) return stato;
  return _annoCorrente(anno) ? 'attivo' : 'chiuso';
}

/// Gestisce l’operazione interna “chip stato anno” della pagina.
Widget _chipStatoAnno(Map<String, dynamic> anno) {
  final stato = _statoAnno(anno);
  final etichetta = switch (stato) {
    'preparazione' => 'Preparazione',
    'attivo' => 'Attivo',
    'chiuso' => 'Chiuso',
    _ => stato,
  };
  return Chip(label: Text(etichetta));
}

/// Gestisce l’operazione interna “anno corrente” della pagina.
bool _annoCorrente(Map<String, dynamic> anno) {
  final valore = anno['corrente'];

  if (valore == true) return true;
  if (valore == false || valore == null) return false;

  final testo = valore.toString().trim().toLowerCase();

  return testo == 'true' ||
      testo == 't' ||
      testo == '1' ||
      testo == 'yes';
}

/// Gestisce l’operazione interna “csv” della pagina.
String _csv(List<Map<String, dynamic>> righe) {
  if (righe.isEmpty) return '';
  final intestazioni = <String>[];
  for (final riga in righe) {
    for (final chiave in riga.keys) {
      if (!intestazioni.contains(chiave)) intestazioni.add(chiave);
    }
  }
  final buffer = StringBuffer()..writeln(intestazioni.map(campoCsv).join(','));
  for (final riga in righe) {
    buffer.writeln(intestazioni.map((c) => campoCsv(riga[c])).join(','));
  }
  return buffer.toString();
}

/// Gestisce l’operazione interna “messaggio” della pagina.
void _messaggio(BuildContext context, String? messaggio) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(messaggio ?? 'Operazione completata.')),
  );
}
