import 'package:flutter/material.dart';

import 'contatti_controller.dart';

class ContattiPage extends StatefulWidget {
  const ContattiPage({super.key});

  @override
  State<ContattiPage> createState() => _ContattiPageState();
}

class _ContattiPageState extends State<ContattiPage> {
  late final ContattiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ContattiController()..carica();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              TextField(
                onChanged: _controller.cerca,
                decoration: const InputDecoration(
                  labelText: 'Cerca per nome, email o SSD',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _contenuto()),
            ],
          ),
        );
      },
    );
  }

  Widget _contenuto() {
    if (_controller.caricamento && _controller.contatti.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.errore != null && _controller.contatti.isEmpty) {
      return Center(child: Text(_controller.errore!));
    }

    final Widget elenco = Card(
      margin: EdgeInsets.zero,
      child: ListView.builder(
        itemCount: _controller.contatti.length,
        itemBuilder: (BuildContext context, int index) {
          final Map<String, dynamic> contatto = _controller.contatti[index];
          final String nome =
              '${contatto['cognome'] ?? ''} ${contatto['nome'] ?? ''}'.trim();
          return ListTile(
            selected:
                contatto['user_id'] == _controller.selezionato?['user_id'],
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(nome),
            subtitle: Text(contatto['email_unipa']?.toString() ?? ''),
            onTap: () => _controller.seleziona(contatto),
          );
        },
      ),
    );
    final Widget dettaglio = _DettaglioContatto(
      contatto: _controller.selezionato,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= 800) {
          return Row(
            children: <Widget>[
              SizedBox(width: 360, child: elenco),
              const VerticalDivider(width: 24),
              Expanded(child: dettaglio),
            ],
          );
        }
        return Column(
          children: <Widget>[
            Expanded(child: elenco),
            const Divider(height: 20),
            Expanded(child: dettaglio),
          ],
        );
      },
    );
  }
}

class _DettaglioContatto extends StatelessWidget {
  const _DettaglioContatto({required this.contatto});

  final Map<String, dynamic>? contatto;

  static const Map<String, String> etichette = <String, String>{
    'email_unipa': 'Email',
    'cellulare': 'Cellulare',
    'cod_ssd': 'SSD',
    'ruolo_accademico': 'Ruolo accademico',
    'dipartimento': 'Dipartimento',
    'ufficio': 'Ufficio',
    'pagina_personale_unipa': 'Pagina personale',
  };

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? dato = contatto;
    if (dato == null) {
      return const Center(child: Text('Seleziona un contatto.'));
    }
    final String nome = '${dato['nome'] ?? ''} ${dato['cognome'] ?? ''}'.trim();
    return Card(
      margin: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(nome, style: Theme.of(context).textTheme.headlineSmall),
          const Divider(height: 28),
          ...etichette.entries.map((e) {
            final String valore = dato[e.key]?.toString().trim() ?? '';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                e.value,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: SelectableText(valore.isEmpty ? '—' : valore),
            );
          }),
        ],
      ),
    );
  }
}
