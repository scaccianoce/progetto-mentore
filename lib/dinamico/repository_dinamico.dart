import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_config.dart';

class FiltroDinamico {
  const FiltroDinamico(this.campo, this.valore);

  final String campo;
  final Object valore;
}

class OrdinamentoDinamico {
  const OrdinamentoDinamico(
    this.campo, {
    this.crescente = true,
    this.nullPrima = false,
  });

  final String campo;
  final bool crescente;
  final bool nullPrima;
}

/// Accesso Supabase centralizzato per le operazioni CRUD standard.
///
/// Non contiene logica di dominio: le pagine che coordinano piu tabelle,
/// workflow o regole applicative mantengono un controller specifico.
class RepositoryDinamico {
  RepositoryDinamico({SupabaseClient? client})
    : client = client ?? SupabaseConfig.client;

  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> elenco({
    required String tabella,
    String colonne = '*',
    List<FiltroDinamico> filtri = const <FiltroDinamico>[],
    List<OrdinamentoDinamico> ordinamenti = const <OrdinamentoDinamico>[],
  }) async {
    dynamic query = client.from(tabella).select(colonne);
    for (final filtro in filtri) {
      query = query.eq(filtro.campo, filtro.valore);
    }
    for (final ordinamento in ordinamenti) {
      query = query.order(
        ordinamento.campo,
        ascending: ordinamento.crescente,
        nullsFirst: ordinamento.nullPrima,
      );
    }
    final List<dynamic> righe = await query;
    return righe.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> singolo({
    required String tabella,
    String colonne = '*',
    List<FiltroDinamico> filtri = const <FiltroDinamico>[],
  }) async {
    dynamic query = client.from(tabella).select(colonne);
    for (final filtro in filtri) {
      query = query.eq(filtro.campo, filtro.valore);
    }
    final dynamic riga = await query.maybeSingle();
    return riga as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> inserisci({
    required String tabella,
    required Map<String, dynamic> valori,
    String colonne = '*',
  }) async => client.from(tabella).insert(valori).select(colonne).maybeSingle();

  Future<Map<String, dynamic>?> aggiorna({
    required String tabella,
    required String campoFiltro,
    required Object valoreFiltro,
    required Map<String, dynamic> valori,
    String colonne = '*',
  }) async => client
      .from(tabella)
      .update(valori)
      .eq(campoFiltro, valoreFiltro)
      .select(colonne)
      .maybeSingle();

  Future<void> elimina({
    required String tabella,
    required String campoFiltro,
    required Object valoreFiltro,
  }) async {
    await client.from(tabella).delete().eq(campoFiltro, valoreFiltro);
  }
}
