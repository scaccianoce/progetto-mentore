import 'package:flutter/material.dart';

import '../../dinamico/maschera_dinamica_controller.dart';
import '../template/pagina_elenco_dettaglio_crud_dinamica.dart';

/// Centro notifiche owner/organizer.
///
/// Le scelte (tipo, stato, trigger) sono ENUM del database e vengono quindi
/// caricate automaticamente dal motore dinamico. Nessun elenco e hard-coded.
class NotificheBackofficePage extends StatelessWidget {
  const NotificheBackofficePage({super.key});

  @override
  Widget build(BuildContext context) => const PaginaElencoDettaglioCrudDinamica(
        titolo: 'Notifiche',
        configurazione: ConfigurazionePaginaDinamica(tabella: 'notifiche'),
        campoTitolo: 'titolo',
        campoSottotitolo: 'programmata_per',
        puoGestire: true,
        ordinamenti: [],
        messaggioVuoto:
            'Nessuna notifica. Installa le tabelle indicate in BACKOFFICE_DATABASE.sql.',
      );
}
