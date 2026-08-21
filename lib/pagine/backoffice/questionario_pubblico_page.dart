import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_config.dart';

class QuestionarioPubblicoPage extends StatefulWidget {
  const QuestionarioPubblicoPage({super.key, required this.token});

  final String token;

  @override
  State<QuestionarioPubblicoPage> createState() => _QuestionarioPubblicoPageState();
}

class _QuestionarioPubblicoPageState extends State<QuestionarioPubblicoPage> {
  late final SupabaseClient _clientAnonimo;

  Map<String, dynamic>? dati;
  final Map<String, dynamic> risposte = <String, dynamic>{};
  bool caricamento = true;
  bool invio = false;
  bool completato = false;
  String? errore;

  @override
  void initState() {
    super.initState();

    // Client separato senza persistenza della sessione: questa pagina deve
    // funzionare anche in una finestra anonima e non dipende dal login.
    _clientAnonimo = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabasePublishableKey,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
      ),
    );

    _carica();
  }

  Future<void> _carica() async {
    try {
      final raw = await _clientAnonimo.rpc(
        'questionario_pubblico_carica',
        params: {'p_token': widget.token},
      );
      if (!mounted) return;
      setState(() {
        dati = raw == null ? null : Map<String, dynamic>.from(raw as Map);
        caricamento = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errore = e.toString();
        caricamento = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (caricamento) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (completato) {
      return const Scaffold(
        body: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 52),
                  SizedBox(height: 12),
                  Text('Grazie. Il questionario è stato inviato.'),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (errore != null || dati == null) {
      return Scaffold(
        body: Center(
          child: Text(errore ?? 'Questionario non disponibile.'),
        ),
      );
    }

    final questionario = Map<String, dynamic>.from(dati!['questionario'] as Map);
    final domande = (dati!['domande'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(questionario['titolo']?.toString() ?? 'Questionario')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if ((questionario['descrizione']?.toString() ?? '').isNotEmpty) ...[
                Text(questionario['descrizione'].toString()),
                const SizedBox(height: 20),
              ],
              for (final domanda in domande) ...[
                _campo(domanda),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: invio ? null : () => _invia(domande),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Invia questionario'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo(Map<String, dynamic> domanda) {
    final id = domanda['id'].toString();
    final testo = domanda['testo']?.toString() ?? '';
    final tipo = domanda['tipo']?.toString() ?? 'testo_breve';
    final obbligatoria = domanda['obbligatoria'] == true;
    final etichetta = obbligatoria ? '$testo *' : testo;

    if (tipo == 'booleano') {
      final valore = risposte[id] as bool?;
      return InputDecorator(
        decoration: InputDecoration(labelText: etichetta, border: const OutlineInputBorder()),
        child: Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Sì'),
              selected: valore == true,
              onSelected: (_) => setState(() => risposte[id] = true),
            ),
            ChoiceChip(
              label: const Text('No'),
              selected: valore == false,
              onSelected: (_) => setState(() => risposte[id] = false),
            ),
          ],
        ),
      );
    }

    if (tipo == 'scala') {
      final opzioni = Map<String, dynamic>.from(domanda['opzioni'] as Map? ?? const {});
      final min = int.tryParse(opzioni['min']?.toString() ?? '') ?? 1;
      final max = int.tryParse(opzioni['max']?.toString() ?? '') ?? 5;
      return DropdownButtonFormField<int>(
        initialValue: risposte[id] as int?,
        decoration: InputDecoration(labelText: etichetta, border: const OutlineInputBorder()),
        items: [
          for (var valore = min; valore <= max; valore++)
            DropdownMenuItem(value: valore, child: Text(valore.toString())),
        ],
        onChanged: (value) => risposte[id] = value,
      );
    }

    if (tipo == 'scelta_singola') {
      final opzioni = (domanda['opzioni'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false);
      return DropdownButtonFormField<String>(
        initialValue: risposte[id]?.toString(),
        isExpanded: true,
        decoration: InputDecoration(labelText: etichetta, border: const OutlineInputBorder()),
        items: [for (final valore in opzioni) DropdownMenuItem(value: valore, child: Text(valore))],
        onChanged: (value) => risposte[id] = value,
      );
    }

    return TextFormField(
      minLines: tipo == 'testo_lungo' ? 4 : 1,
      maxLines: tipo == 'testo_lungo' ? 8 : 1,
      decoration: InputDecoration(
        labelText: etichetta,
        border: const OutlineInputBorder(),
        alignLabelWithHint: tipo == 'testo_lungo',
      ),
      onChanged: (value) => risposte[id] = value,
    );
  }

  Future<void> _invia(List<Map<String, dynamic>> domande) async {
    for (final domanda in domande) {
      if (domanda['obbligatoria'] != true) continue;
      final valore = risposte[domanda['id'].toString()];
      if (valore == null || (valore is String && valore.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Risposta obbligatoria: ${domanda['testo'] ?? ''}')),
        );
        return;
      }
    }

    setState(() => invio = true);
    try {
      await _clientAnonimo.rpc(
        'questionario_pubblico_invia',
        params: {
          'p_token': widget.token,
          'p_risposte': risposte,
        },
      );
      if (!mounted) return;
      setState(() {
        invio = false;
        completato = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => invio = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invio non riuscito: $e')),
      );
    }
  }
}
