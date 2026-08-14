import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../supabase_config.dart';
import 'backoffice_controller.dart';

/// Sintesi annuale calcolata direttamente dalle tabelle reali del DB.
/// Non richiede view/materialized view/RPC di riepilogo.
class AnniAccademiciBackofficePage extends StatefulWidget {
  const AnniAccademiciBackofficePage({super.key, required this.controller});

  final BackofficeController controller;
    

  @override
  State<AnniAccademiciBackofficePage> createState() =>
      _AnniAccademiciBackofficePageState();
}

class _AnniAccademiciBackofficePageState
    extends State<AnniAccademiciBackofficePage> {
  
  final ScrollController _scrollOrizzontale = ScrollController();
  Map<String, _RiepilogoAnno> _riepiloghi = const {};
  bool _caricamento = true;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _caricaSintesi();
  }

  @override
  void dispose() {
    _scrollOrizzontale.dispose();
    super.dispose();
  }

  Future<void> _caricaSintesi() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final db = SupabaseConfig.client;
      final risultati = await Future.wait<dynamic>([
        db.from('insegnamenti').select(),
        db.from('mentoraggi').select(),
        db.from('mentoraggio_mentori').select(),
        db.from('eventi').select(),
        db.from('partecipazioni_eventi').select(),
        db.from('house_of_mentore').select(),
        db.from('partecipazioni_house_of_mentore').select(),
      ]);
      final insegnamenti = _mappe(risultati[0]);
      final mentoraggi = _mappe(risultati[1]);
      final assegnazioni = _mappe(risultati[2]);
      final eventi = _mappe(risultati[3]);
      final partecipazioniEventi = _mappe(risultati[4]);
      final hom = _mappe(risultati[5]);
      final partecipazioniHom = _mappe(risultati[6]);

      final risultato = <String, _RiepilogoAnno>{};
      for (final anno in widget.controller.anni) {
        final codice = anno['codice']?.toString() ?? '';
        if (codice.isEmpty) continue;
        risultato[codice] = _calcola(
          codice,
          insegnamenti: insegnamenti,
          mentoraggi: mentoraggi,
          assegnazioni: assegnazioni,
          eventi: eventi,
          partecipazioniEventi: partecipazioniEventi,
          hom: hom,
          partecipazioniHom: partecipazioniHom,
        );
      }
      if (!mounted) return;
      setState(() => _riepiloghi = risultato);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errore =
          'Impossibile calcolare la sintesi direttamente dalle tabelle DB.\n$e');
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
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
                onPressed: _caricamento
                    ? null
                    : () async {
                        await widget.controller.carica();
                        await _caricaSintesi();
                      },
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
          if (_caricamento) const LinearProgressIndicator(),
          if (_errore != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_errore!),
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
                        DataColumn(label: Text('Partecipanti'), numeric: true),
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
                        for (final anno in widget.controller.anni)
                          _rigaAnno(context, anno),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );

  DataRow _rigaAnno(BuildContext context, Map<String, dynamic> anno) {
    final codice = anno['codice']?.toString() ?? '';
    final r = _riepiloghi[codice] ?? _RiepilogoAnno.vuoto(codice);
    return DataRow(cells: [
      DataCell(Row(children: [
        if (_annoCorrente(anno))
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.check_circle, size: 18),
          ),
        Text(codice),
      ])),
      DataCell(Text('${r.partecipanti}')),
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
      DataCell(Row(mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Esporta tabelle CSV',
              onPressed: () => _esportaAnno(context, codice),
              icon: const Icon(Icons.download_outlined),
            ),
            if (!_annoCorrente(anno))
              IconButton(
                tooltip: 'Rendi $codice anno accademico corrente',
                onPressed: () async {
                  final errore = await widget.controller.impostaAnnoCorrente(codice);
                  if (!context.mounted) return;
                  if (errore == null) {
                    // Ricarica gli anni dal DB, altrimenti la tabella
                    // continua a mostrare il vecchio valore di "corrente".
                    await widget.controller.carica();
                    if (!context.mounted) return;
                    await _caricaSintesi();
                    if (!context.mounted) return;
                  }
                  _messaggio(context, errore);
                },
                icon: const Icon(Icons.check_circle_outline),
              ),
          ],
        ),
      ),
    ]);
  }

  _RiepilogoAnno _calcola(
    String anno, {
    required List<Map<String, dynamic>> insegnamenti,
    required List<Map<String, dynamic>> mentoraggi,
    required List<Map<String, dynamic>> assegnazioni,
    required List<Map<String, dynamic>> eventi,
    required List<Map<String, dynamic>> partecipazioniEventi,
    required List<Map<String, dynamic>> hom,
    required List<Map<String, dynamic>> partecipazioniHom,
  }) {
    final insAnno = insegnamenti
        .where((r) => r['anno_accademico']?.toString() == anno)
        .toList();
    final insIds = insAnno.map((r) => r['id']?.toString()).whereType<String>().toSet();
    final mentAnno = mentoraggi
        .where((r) => insIds.contains(r['insegnamento_id']?.toString()))
        .toList();
    final mentIds = mentAnno.map((r) => r['id']?.toString()).whereType<String>().toSet();
    final mentoriIds = assegnazioni
        .where((r) => mentIds.contains(r['mentoraggio_id']?.toString()))
        .map((r) => r['mentore_id']?.toString())
        .whereType<String>();
    final insegnamentiMentoratiIds = mentAnno
        .map((r) => r['insegnamento_id']?.toString())
        .whereType<String>()
        .toSet();
    final menteeIds = insAnno
        .where((r) => insegnamentiMentoratiIds.contains(r['id']?.toString()))
        .map((r) => r['docente_id']?.toString())
        .whereType<String>();
    // Un partecipante dell'anno e chi ha effettivamente svolto almeno uno dei
    // due ruoli: mentee in un mentoraggio e/o mentore assegnato a un mentoraggio.
    final partecipanti = <String>{...menteeIds, ...mentoriIds}
      ..removeWhere((v) => v.isEmpty || v == 'null');

    final eventiAnno = eventi.where((r) => r['anno_accademico']?.toString() == anno).toList();
    final eventoIds = eventiAnno.map((r) => r['id']?.toString()).whereType<String>().toSet();
    final pe = partecipazioniEventi
        .where((r) => eventoIds.contains(r['evento_id']?.toString()))
        .toList();
    final presenzeEventi = pe.where((r) => r['presente'] == true).length;

    final homAnno = hom.where((r) => r['anno_accademico']?.toString() == anno).toList();
    final homIds = homAnno.map((r) => r['id']?.toString()).whereType<String>().toSet();
    final ph = partecipazioniHom
        .where((r) => homIds.contains(r['evento_id']?.toString()))
        .toList();
    final presenzeHom = ph.where((r) => r['presente'] == true).length;

    return _RiepilogoAnno(
      anno: anno,
      partecipanti: partecipanti.length,
      insegnamenti: insAnno.length,
      insegnamentiMentorati: insegnamentiMentoratiIds.length,
      mentoraggiConclusi: mentAnno.where(_mentoraggioConcluso).length,
      eventi: eventiAnno.length,
      iscrizioniEventi: pe.length,
      presenzeEventi: presenzeEventi,
      mediaPresenzeEventi: eventiAnno.isEmpty ? 0 : presenzeEventi / eventiAnno.length,
      houseOfMentore: homAnno.length,
      iscrizioniHom: ph.length,
      presenzeHom: presenzeHom,
      mediaPresenzeHom: homAnno.isEmpty ? 0 : presenzeHom / homAnno.length,
    );
  }

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
      _messaggio(context, 'Impossibile esportare i dati: $e');
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> _datiGrezziAnno(String anno) async {
    final db = SupabaseConfig.client;
    final anni = _mappe(await db.from('anni_accademici').select().eq('codice', anno));
    final insegnamenti = _mappe(await db.from('insegnamenti').select().eq('anno_accademico', anno));
    final insIds = insegnamenti.map((r) => r['id']?.toString()).whereType<String>().toList();
    final mentoraggi = insIds.isEmpty
        ? <Map<String, dynamic>>[]
        : _mappe(await db.from('mentoraggi').select().inFilter('insegnamento_id', insIds));
    final mentoraggioIds = mentoraggi.map((r) => r['id']?.toString()).whereType<String>().toList();
    final assegnazioni = mentoraggioIds.isEmpty
        ? <Map<String, dynamic>>[]
        : _mappe(await db.from('mentoraggio_mentori').select().inFilter('mentoraggio_id', mentoraggioIds));

    final eventi = _mappe(await db.from('eventi').select().eq('anno_accademico', anno));
    final eventoIds = eventi.map((r) => r['id']?.toString()).whereType<String>().toList();
    final partecipazioniEventi = eventoIds.isEmpty
        ? <Map<String, dynamic>>[]
        : _mappe(await db.from('partecipazioni_eventi').select().inFilter('evento_id', eventoIds));

    final hom = _mappe(await db.from('house_of_mentore').select().eq('anno_accademico', anno));
    final homIds = hom.map((r) => r['id']?.toString()).whereType<String>().toList();
    final opzioniHom = homIds.isEmpty
        ? <Map<String, dynamic>>[]
        : _mappe(await db.from('house_of_mentore_opzioni').select().inFilter('evento_id', homIds));
    final partecipazioniHom = homIds.isEmpty
        ? <Map<String, dynamic>>[]
        : _mappe(await db.from('partecipazioni_house_of_mentore').select().inFilter('evento_id', homIds));

    final partecipanteIds = <String>{
      ...insegnamenti.map((r) => r['docente_id']?.toString()).whereType<String>(),
      ...assegnazioni.map((r) => r['mentore_id']?.toString()).whereType<String>(),
    }..removeWhere((v) => v.isEmpty || v == 'null');
    final ids = partecipanteIds.toList();
    final anagrafica = ids.isEmpty
        ? <Map<String, dynamic>>[]
        : _mappe(await db.from('anagrafica').select().inFilter('user_id', ids));
    final riservata = ids.isEmpty
        ? <Map<String, dynamic>>[]
        : _mappe(await db.from('anagrafica_riservata').select().inFilter('user_id', ids));
    final ruoli = ids.isEmpty
        ? <Map<String, dynamic>>[]
        : _mappe(await db.from('user_roles').select().inFilter('user_id', ids));

    return {
      'anni_accademici': anni,
      'anagrafica': anagrafica,
      'anagrafica_riservata': riservata,
      'user_roles': ruoli,
      'insegnamenti': insegnamenti,
      'mentoraggi': mentoraggi,
      'mentoraggio_mentori': assegnazioni,
      'eventi': eventi,
      'partecipazioni_eventi': partecipazioniEventi,
      'house_of_mentore': hom,
      'house_of_mentore_opzioni': opzioniHom,
      'partecipazioni_house_of_mentore': partecipazioniHom,
    };
  }

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
      final errore = await widget.controller.aggiungiAnno(
        codice.text,
        _isoData(inizio),
        _isoData(fine),
      );
      await _caricaSintesi();
      if (!context.mounted) {
        codice.dispose();
        return;
      }
      _messaggio(context, errore);
    }
    codice.dispose();
  }

  Widget _rigaData(
    BuildContext context, {
    required String etichetta,
    required DateTime? valore,
    required ValueChanged<DateTime?> onChanged,
  }) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(valore == null ? etichetta : '$etichetta: ${_formattaData(valore)}'),
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

class _RiepilogoAnno {
  const _RiepilogoAnno({
    required this.anno,
    required this.partecipanti,
    required this.insegnamenti,
    required this.insegnamentiMentorati,
    required this.mentoraggiConclusi,
    required this.eventi,
    required this.iscrizioniEventi,
    required this.presenzeEventi,
    required this.mediaPresenzeEventi,
    required this.houseOfMentore,
    required this.iscrizioniHom,
    required this.presenzeHom,
    required this.mediaPresenzeHom,
  });

  factory _RiepilogoAnno.vuoto(String anno) => _RiepilogoAnno(
        anno: anno,
        partecipanti: 0,
        insegnamenti: 0,
        insegnamentiMentorati: 0,
        mentoraggiConclusi: 0,
        eventi: 0,
        iscrizioniEventi: 0,
        presenzeEventi: 0,
        mediaPresenzeEventi: 0,
        houseOfMentore: 0,
        iscrizioniHom: 0,
        presenzeHom: 0,
        mediaPresenzeHom: 0,
      );

  final String anno;
  final int partecipanti;
  final int insegnamenti;
  final int insegnamentiMentorati;
  final int mentoraggiConclusi;
  final int eventi;
  final int iscrizioniEventi;
  final int presenzeEventi;
  final double mediaPresenzeEventi;
  final int houseOfMentore;
  final int iscrizioniHom;
  final int presenzeHom;
  final double mediaPresenzeHom;
}

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

bool _mentoraggioConcluso(Map<String, dynamic> riga) {
  final invio = riga['data_invio_scheda'];
  if (invio != null && invio.toString().trim().isNotEmpty) return true;
  final stato = riga['stato']?.toString().toLowerCase() ?? '';
  return stato.contains('conclus') || stato.contains('complet') || stato.contains('termin');
}

List<Map<String, dynamic>> _mappe(dynamic valore) =>
    (valore as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

String _csv(List<Map<String, dynamic>> righe) {
  if (righe.isEmpty) return '';
  final intestazioni = <String>[];
  for (final riga in righe) {
    for (final chiave in riga.keys) {
      if (!intestazioni.contains(chiave)) intestazioni.add(chiave);
    }
  }
  final buffer = StringBuffer()..writeln(intestazioni.map(_csvValore).join(','));
  for (final riga in righe) {
    buffer.writeln(intestazioni.map((c) => _csvValore(riga[c])).join(','));
  }
  return buffer.toString();
}

String _csvValore(Object? valore) {
  final testo = valore?.toString() ?? '';
  return '"${testo.replaceAll('"', '""')}"';
}

String _formattaData(DateTime data) =>
    '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
String? _isoData(DateTime? data) => data?.toIso8601String().split('T').first;

void _messaggio(BuildContext context, String? messaggio) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(messaggio ?? 'Operazione completata.')),
  );
}
