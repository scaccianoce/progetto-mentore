import 'package:flutter/material.dart';

import '../../app_exception.dart';
import '../../dinamico/maschera_dinamica_controller.dart';
import '../../dinamico/repository_dinamico.dart';
import '../../sessione_controller.dart';
import '../../notifiche_automatiche_service.dart';
import '../template/pagina_elenco_dettaglio_crud_dinamica.dart';

/// NEWS - esempio di pagina CRUD standard.
///
/// Per aggiungere una pagina analoga sono sufficienti, in genere:
/// tabella, titolo, campo titolo ed eventuali eccezioni.
class NewsPage extends StatelessWidget {
  const NewsPage({super.key, required this.sessione});

  final SessioneController sessione;

  ConfigurazionePaginaDinamica get configurazione => ConfigurazionePaginaDinamica(
    tabella: 'news',
    campi: <String, PersonalizzazioneCampo>{
      'testo': PersonalizzazioneCampo(
        tipo: TipoCampoDinamico.testoFormattato,
        modificabilePartecipante: false,
      ),
      'titolo': PersonalizzazioneCampo(modificabilePartecipante: false),
      'data_pubblicazione': PersonalizzazioneCampo(
        modificabilePartecipante: false,
      ),
      'attiva': PersonalizzazioneCampo(
        // I partecipanti non vedono il flag; owner/organizer possono
        // visualizzarlo e modificarlo per pubblicare/nascondere la news.
        nascosto: sessione.ruolo == AppRole.participant,
        modificabilePartecipante: false,
      ),
    },
  );

  @override
  Widget build(BuildContext context) {
    final ruolo = sessione.ruolo ?? AppRole.participant;
    final partecipante = ruolo == AppRole.participant;

    return PaginaElencoDettaglioCrudDinamica(
      titolo: 'News',
      configurazione: configurazione,
      campoTitolo: 'titolo',
      formattaSottotitolo: (record) => _formattaData(
        DateTime.tryParse(record['data_pubblicazione']?.toString() ?? ''),
      ),
      valoriNuovo: <String, dynamic>{
        'titolo': '',
        'testo': null,
        'data_pubblicazione': DateTime.now().toIso8601String().split('T').first,
        'attiva': true,
      },
      filtri: partecipante
          ? const <FiltroDinamico>[FiltroDinamico('attiva', true)]
          : const <FiltroDinamico>[],
      ordinamenti: const <OrdinamentoDinamico>[
        OrdinamentoDinamico('data_pubblicazione', crescente: false),
        OrdinamentoDinamico('id', crescente: false),
      ],
      partecipante: partecipante,
      puoGestire: ruolo.puoAmministrare,
      normalizzaValori: _normalizzaNews,
      messaggioVuoto: 'Nessuna news disponibile.',
      etichettaNuovo: 'Nuova',
      titoloNuovo: 'Nuova news',
      titoloModifica: 'Modifica news',
      messaggioSalvato: 'News salvata.',
      messaggioEliminato: 'News eliminata.',
      larghezzaElenco: 340,
      dopoSalvataggio: (salvato, esistente) async {
        // La notifica automatica viene inviata soltanto alla prima
        // pubblicazione della news. Le modifiche successive non generano
        // notifiche duplicate.
        if (esistente != null || salvato['attiva'] != true) return;

        final anno = salvato['anno_accademico']?.toString().trim() ?? '';
        if (anno.isEmpty) return;

        await NotificheAutomaticheService.inviaAnnoAccademico(
          annoAccademico: anno,
          titolo: 'Nuova news',
          messaggio: salvato['titolo']?.toString() ?? 'È disponibile una nuova news.',
        );
      },
    );
  }
}

Map<String, dynamic> _normalizzaNews(
  Map<String, dynamic> valori,
  Map<String, dynamic>? esistente,
) {
  final titolo = valori['titolo']?.toString().trim() ?? '';
  if (titolo.isEmpty) throw const AppException('Il titolo è obbligatorio.');

  final testo = valori['testo']?.toString().trim() ?? '';
  final data = DateTime.tryParse(valori['data_pubblicazione']?.toString() ?? '');
  return <String, dynamic>{
    ...valori,
    'titolo': titolo,
    'testo': testo.isEmpty ? null : testo,
    if (data != null) 'data_pubblicazione': data.toIso8601String().split('T').first,
    'attiva': valori['attiva'] ?? esistente?['attiva'] ?? true,
  };
}

String _formattaData(DateTime? data) {
  if (data == null) return 'Data non indicata';
  String dueCifre(int valore) => valore.toString().padLeft(2, '0');
  return '${dueCifre(data.day)}/${dueCifre(data.month)}/${data.year}';
}
