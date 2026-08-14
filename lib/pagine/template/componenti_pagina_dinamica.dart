import 'package:flutter/material.dart';

import '../../dinamico/maschera_dinamica_controller.dart';
import '../../dinamico/maschera_dinamica_widget.dart';

/// MODIFICA ARCHITETTURALE:
/// intestazione riutilizzabile per le pagine a elenco/dettaglio.
/// Le singole pagine dichiarano solo titolo e azioni realmente disponibili.
class IntestazionePaginaDinamica extends StatelessWidget {
  const IntestazionePaginaDinamica({
    super.key,
    required this.titolo,
    this.onAggiorna,
    this.onNuovo,
    this.etichettaNuovo = 'Nuovo',
    this.azioni = const <Widget>[],
  });

  final String titolo;
  final VoidCallback? onAggiorna;
  final VoidCallback? onNuovo;
  final String etichettaNuovo;
  final List<Widget> azioni;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: Text(titolo, style: Theme.of(context).textTheme.headlineSmall),
      ),
      ...azioni,
      if (onAggiorna != null)
        IconButton(
          tooltip: 'Aggiorna',
          onPressed: onAggiorna,
          icon: const Icon(Icons.refresh),
        ),
      if (onNuovo != null)
        FilledButton.icon(
          onPressed: onNuovo,
          icon: const Icon(Icons.add),
          label: Text(etichettaNuovo),
        ),
    ],
  );
}

/// Elenco standard basato su record Map. Riduce il boilerplate delle pagine
/// News/Eventi/House of Mentore e delle future pagine dello stesso tipo.
class ElencoRecordDinamico<T> extends StatelessWidget {
  const ElencoRecordDinamico({
    super.key,
    required this.elementi,
    required this.idSelezionato,
    required this.id,
    required this.titolo,
    required this.onSeleziona,
    this.sottotitolo,
    this.leading,
    this.trailing,
    this.separatore = true,
  });

  final List<T> elementi;
  final String? idSelezionato;
  final String Function(T) id;
  final String Function(T) titolo;
  final String Function(T)? sottotitolo;
  final Widget Function(T)? leading;
  final Widget? Function(T)? trailing;
  final ValueChanged<T> onSeleziona;
  final bool separatore;

  @override
  Widget build(BuildContext context) {
    Widget elemento(BuildContext context, int indice) {
      final record = elementi[indice];
      return ListTile(
        selected: id(record) == idSelezionato,
        leading: leading?.call(record),
        title: Text(
          titolo(record),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: sottotitolo == null ? null : Text(sottotitolo!(record)),
        trailing: trailing?.call(record),
        onTap: () => onSeleziona(record),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: separatore
          ? ListView.separated(
              itemCount: elementi.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: elemento,
            )
          : ListView.builder(itemCount: elementi.length, itemBuilder: elemento),
    );
  }
}

/// Dettaglio standard di un record. I contenuti specifici vengono inseriti
/// prima/dopo i campi automatici senza duplicare la visualizzazione dinamica.
class DettaglioRecordDinamico extends StatelessWidget {
  const DettaglioRecordDinamico({
    super.key,
    required this.configurazione,
    required this.valori,
    this.partecipante = false,
    this.prima = const <Widget>[],
    this.dopo = const <Widget>[],
    this.padding = const EdgeInsets.all(20),
  });

  final ConfigurazionePaginaDinamica configurazione;
  final Map<String, dynamic> valori;
  final bool partecipante;
  final List<Widget> prima;
  final List<Widget> dopo;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ListView(
    padding: padding,
    children: <Widget>[
      ...prima,
      CampiTabellaDinamici(
        configurazione: configurazione,
        valori: valori,
        partecipante: partecipante,
      ),
      ...dopo,
    ],
  );
}
