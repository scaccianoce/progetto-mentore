import 'package:flutter/material.dart';

import '../../supabase_config.dart';

/// Controllo operativo per anno accademico costruito direttamente dalle
/// tabelle reali del database, senza view di riepilogo.
class ControlloPartecipantiBackofficePage extends StatefulWidget {
  const ControlloPartecipantiBackofficePage({super.key});

  @override
  State<ControlloPartecipantiBackofficePage> createState() =>
      _ControlloPartecipantiBackofficePageState();
}

class _ControlloPartecipantiBackofficePageState
    extends State<ControlloPartecipantiBackofficePage> {
  List<String> _anni = const [];
  String? _anno;
  List<_PartecipanteAnno> _partecipanti = const [];
  bool _caricamento = true;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _inizializza();
  }

  Future<void> _inizializza() async {
    try {
      final anni = await SupabaseConfig.client
          .from('anni_accademici')
          .select('codice, corrente')
          .order('codice', ascending: false);
      final lista = anni.map((e) => e['codice'].toString()).toList();
      final corrente = anni
          .where((e) => e['corrente'] == true)
          .map((e) => e['codice'].toString())
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        _anni = lista;
        _anno = corrente ?? lista.firstOrNull;
      });
      await _carica();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = e.toString();
        _caricamento = false;
      });
    }
  }

  Future<void> _carica() async {
    final anno = _anno;
    if (anno == null) return;
    setState(() {
      _caricamento = true;
      _errore = null;
    });

    try {
      final db = SupabaseConfig.client;
      final insegnamenti = _mappe(
        await db.from('insegnamenti').select().eq('anno_accademico', anno),
      );
      final insegnamentoIds = _ids(insegnamenti, 'id');
      final mentoraggi = insegnamentoIds.isEmpty
          ? <Map<String, dynamic>>[]
          : _mappe(
              await db
                  .from('mentoraggi')
                  .select()
                  .inFilter('insegnamento_id', insegnamentoIds),
            );
      final mentoraggioIds = _ids(mentoraggi, 'id');
      final assegnazioni = mentoraggioIds.isEmpty
          ? <Map<String, dynamic>>[]
          : _mappe(
              await db
                  .from('mentoraggio_mentori')
                  .select()
                  .inFilter('mentoraggio_id', mentoraggioIds),
            );

      final eventi = _mappe(
        await db.from('eventi').select().eq('anno_accademico', anno),
      );
      final eventoIds = _ids(eventi, 'id');
      final partecipazioniEventi = eventoIds.isEmpty
          ? <Map<String, dynamic>>[]
          : _mappe(
              await db
                  .from('partecipazioni_eventi')
                  .select()
                  .inFilter('evento_id', eventoIds),
            );

      final hom = _mappe(
        await db.from('house_of_mentore').select().eq('anno_accademico', anno),
      );
      final homIds = _ids(hom, 'id');
      final partecipazioniHom = homIds.isEmpty
          ? <Map<String, dynamic>>[]
          : _mappe(
              await db
                  .from('partecipazioni_house_of_mentore')
                  .select()
                  .inFilter('evento_id', homIds),
            );

      final insegnamentiPerId = <String, Map<String, dynamic>>{
        for (final r in insegnamenti) r['id'].toString(): r,
      };
      final eventiPerId = <String, Map<String, dynamic>>{
        for (final r in eventi) r['id'].toString(): r,
      };
      final homPerId = <String, Map<String, dynamic>>{
        for (final r in hom) r['id'].toString(): r,
      };

      final partecipanteIds = <String>{};
      for (final m in mentoraggi) {
        final ins = insegnamentiPerId[m['insegnamento_id']?.toString()];
        final id = ins?['docente_id']?.toString();
        if (_valido(id)) partecipanteIds.add(id!);
      }
      for (final a in assegnazioni) {
        final id = a['mentore_id']?.toString();
        if (_valido(id)) partecipanteIds.add(id!);
      }
      for (final p in partecipazioniEventi) {
        final id = p['partecipante_id']?.toString();
        if (_valido(id)) partecipanteIds.add(id!);
      }
      for (final p in partecipazioniHom) {
        final id = p['partecipante_id']?.toString();
        if (_valido(id)) partecipanteIds.add(id!);
      }

      final anagrafiche = partecipanteIds.isEmpty
          ? <Map<String, dynamic>>[]
          : _mappe(
              await db
                  .from('anagrafica')
                  .select()
                  .inFilter('user_id', partecipanteIds.toList()),
            );
      final persone = <String, Map<String, dynamic>>{
        for (final p in anagrafiche) p['user_id'].toString(): p,
      };

      String nomePersona(String? id) {
        if (!_valido(id)) return '—';
        final p = persone[id];
        if (p == null) return id!;
        final nome = '${p['cognome'] ?? ''} ${p['nome'] ?? ''}'.trim();
        if (nome.isNotEmpty) return nome;
        return p['email_unipa']?.toString() ?? id!;
      }

      final risultato = <_PartecipanteAnno>[];
      for (final partecipanteId in partecipanteIds) {
        final mentee = <_PercorsoMentee>[];
        final mentore = <_PercorsoMentore>[];

        for (final m in mentoraggi) {
          final insegnamento = insegnamentiPerId[m['insegnamento_id']?.toString()];
          if (insegnamento == null) continue;
          final assegnati = assegnazioni
              .where((a) => a['mentoraggio_id']?.toString() == m['id']?.toString())
              .toList();
          final docenteId = insegnamento['docente_id']?.toString();

          if (docenteId == partecipanteId) {
            mentee.add(
              _PercorsoMentee(
                insegnamento: _nomeInsegnamento(insegnamento),
                team: assegnati
                    .map(
                      (a) => _MembroTeam(
                        nome: nomePersona(a['mentore_id']?.toString()),
                        tipo: a['tipo']?.toString() ?? '—',
                      ),
                    )
                    .toList(),
                mentoraggio: m,
              ),
            );
          }

          final miaAssegnazione = assegnati
              .where((a) => a['mentore_id']?.toString() == partecipanteId)
              .firstOrNull;
          if (miaAssegnazione != null) {
            mentore.add(
              _PercorsoMentore(
                insegnamento: _nomeInsegnamento(insegnamento),
                mentee: nomePersona(docenteId),
                mioTipo: miaAssegnazione['tipo']?.toString() ?? '—',
                altriTeam: assegnati
                    .where((a) => a['mentore_id']?.toString() != partecipanteId)
                    .map(
                      (a) => _MembroTeam(
                        nome: nomePersona(a['mentore_id']?.toString()),
                        tipo: a['tipo']?.toString() ?? '—',
                      ),
                    )
                    .toList(),
                mentoraggio: m,
              ),
            );
          }
        }

        final partecipazioni = partecipazioniEventi
            .where((p) => p['partecipante_id']?.toString() == partecipanteId)
            .map(
              (p) => _PartecipazioneEvento(
                titolo: eventiPerId[p['evento_id']?.toString()]?['titolo']
                        ?.toString() ??
                    p['evento_id']?.toString() ??
                    '—',
                presente: p['presente'] == true,
              ),
            )
            .toList();

        final house = partecipazioniHom
            .where((p) => p['partecipante_id']?.toString() == partecipanteId)
            .map(
              (p) => homPerId[p['evento_id']?.toString()]?['titolo']
                      ?.toString() ??
                  p['evento_id']?.toString() ??
                  '—',
            )
            .toList();

        risultato.add(
          _PartecipanteAnno(
            persona: persone[partecipanteId] ??
                <String, dynamic>{'user_id': partecipanteId},
            mentee: mentee,
            mentore: mentore,
            eventi: partecipazioni,
            houseOfMentore: house,
          ),
        );
      }

      risultato.sort((a, b) {
        final cognomeA = a.persona['cognome']?.toString().toLowerCase() ?? '';
        final cognomeB = b.persona['cognome']?.toString().toLowerCase() ?? '';
        final confronto = cognomeA.compareTo(cognomeB);
        if (confronto != 0) return confronto;
        final nomeA = a.persona['nome']?.toString().toLowerCase() ?? '';
        final nomeB = b.persona['nome']?.toString().toLowerCase() ?? '';
        return nomeA.compareTo(nomeB);
      });

      if (!mounted) return;
      setState(() => _partecipanti = risultato);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errore = 'Impossibile costruire il controllo partecipanti.\n$e',
      );
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _anno,
                  decoration:
                      const InputDecoration(labelText: 'Anno accademico'),
                  items: [
                    for (final anno in _anni)
                      DropdownMenuItem(value: anno, child: Text(anno)),
                  ],
                  onChanged: (v) async {
                    setState(() => _anno = v);
                    await _carica();
                  },
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Aggiorna',
                onPressed: _carica,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _contenuto()),
        ],
      );

  Widget _contenuto() {
    if (_caricamento) return const Center(child: CircularProgressIndicator());
    if (_errore != null) return Center(child: Text(_errore!));
    if (_partecipanti.isEmpty) {
      return const Center(child: Text('Nessun partecipante per questo anno.'));
    }

    return ListView.builder(
      itemCount: _partecipanti.length,
      itemBuilder: (context, index) {
        final r = _partecipanti[index];
        final nome =
            '${r.persona['cognome'] ?? ''} ${r.persona['nome'] ?? ''}'.trim();
        return Card(
          child: ExpansionTile(
            title: Text(
              nome.isEmpty ? r.persona['user_id'].toString() : nome,
            ),
            subtitle: Text(r.persona['email_unipa']?.toString() ?? ''),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _titolo('Ruolo da mentee'),
              if (r.mentee.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Nessun insegnamento mentorato.'),
                ),
              for (final percorso in r.mentee) _schedaMentee(percorso),
              const SizedBox(height: 12),
              _titolo('Ruolo da mentore'),
              if (r.mentore.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Nessun incarico come mentore.'),
                ),
              for (final percorso in r.mentore) _schedaMentore(percorso),
              const SizedBox(height: 12),
              _titolo('Eventi'),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Partecipati: ${r.eventi.where((e) => e.presente).length} '
                  'su ${r.eventi.length} iscrizioni',
                ),
              ),
              for (final evento in r.eventi)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    evento.presente
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                  ),
                  title: Text(evento.titolo),
                  trailing:
                      Text(evento.presente ? 'Presente' : 'Non presente'),
                ),
              const SizedBox(height: 12),
              _titolo('House of Mentore'),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Partecipazioni registrate: ${r.houseOfMentore.length}',
                ),
              ),
              for (final titolo in r.houseOfMentore)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.home_outlined),
                  title: Text(titolo),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _schedaMentee(_PercorsoMentee p) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                p.insegnamento,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Mentori / senior: ${_team(p.team)}'),
              _statoMentoraggio(p.mentoraggio),
            ],
          ),
        ),
      );

  Widget _schedaMentore(_PercorsoMentore p) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                p.insegnamento,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Mentee: ${p.mentee}'),
              Text('Ruolo: ${p.mioTipo}'),
              Text('Co-mentore / senior: ${_team(p.altriTeam)}'),
              _statoMentoraggio(p.mentoraggio),
            ],
          ),
        ),
      );

  Widget _statoMentoraggio(Map<String, dynamic> m) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            Text('Stato: ${m['stato'] ?? '—'}'),
            Text('Visita 1: ${m['data_visita_1'] ?? '—'}'),
            Text('Visita 2: ${m['data_visita_2'] ?? '—'}'),
            if (m['data_visita_3'] != null)
              Text('Visita 3: ${m['data_visita_3']}'),
            if (m['data_visita_4'] != null)
              Text('Visita 4: ${m['data_visita_4']}'),
            Text('Focus group: ${m['data_focus_group'] ?? '—'}'),
            Text('Incontro finale: ${m['data_incontro_finale'] ?? '—'}'),
          ],
        ),
      );

  Widget _titolo(String testo) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          testo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );

  String _team(List<_MembroTeam> team) => team.isEmpty
      ? '—'
      : team.map((m) => '${m.nome} (${m.tipo})').join(', ');
}

String _nomeInsegnamento(Map<String, dynamic> insegnamento) {
  final valore = insegnamento['insegnamento']?.toString().trim();
  return (valore != null && valore.isNotEmpty)
      ? valore
      : insegnamento['id']?.toString() ?? '—';
}

bool _valido(String? valore) =>
    valore != null && valore.isNotEmpty && valore != 'null';

List<String> _ids(List<Map<String, dynamic>> righe, String campo) => righe
    .map((r) => r[campo]?.toString())
    .whereType<String>()
    .where((v) => v.isNotEmpty && v != 'null')
    .toList();

List<Map<String, dynamic>> _mappe(dynamic valore) =>
    (valore as List).cast<Map<String, dynamic>>();

class _MembroTeam {
  const _MembroTeam({required this.nome, required this.tipo});
  final String nome;
  final String tipo;
}

class _PercorsoMentee {
  const _PercorsoMentee({
    required this.insegnamento,
    required this.team,
    required this.mentoraggio,
  });
  final String insegnamento;
  final List<_MembroTeam> team;
  final Map<String, dynamic> mentoraggio;
}

class _PercorsoMentore {
  const _PercorsoMentore({
    required this.insegnamento,
    required this.mentee,
    required this.mioTipo,
    required this.altriTeam,
    required this.mentoraggio,
  });
  final String insegnamento;
  final String mentee;
  final String mioTipo;
  final List<_MembroTeam> altriTeam;
  final Map<String, dynamic> mentoraggio;
}

class _PartecipazioneEvento {
  const _PartecipazioneEvento({required this.titolo, required this.presente});
  final String titolo;
  final bool presente;
}

class _PartecipanteAnno {
  const _PartecipanteAnno({
    required this.persona,
    required this.mentee,
    required this.mentore,
    required this.eventi,
    required this.houseOfMentore,
  });
  final Map<String, dynamic> persona;
  final List<_PercorsoMentee> mentee;
  final List<_PercorsoMentore> mentore;
  final List<_PartecipazioneEvento> eventi;
  final List<String> houseOfMentore;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
