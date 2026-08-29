// ============================================================================
// DATE
// ============================================================================

/// Converte un valore generico in [DateTime], se possibile.
///
/// Accetta direttamente un [DateTime] oppure una stringa compatibile con
/// [DateTime.parse]. Restituisce `null` per valori assenti o non validi.
DateTime? dataDa(Object? valore) {
  if (valore is DateTime) return valore;

  final testo = valore?.toString().trim() ?? '';
  return testo.isEmpty ? null : DateTime.tryParse(testo);
}

/// Formatta una data nel formato `gg/mm/aaaa`.
///
/// Se il valore non e' interpretabile come data, restituisce [valoreAssente]
/// oppure il valore originale quando [mantieniValoreNonValido] e' `true`.
String formattaData(
  Object? valore, {
  String valoreAssente = '—',
  bool mantieniValoreNonValido = false,
  bool locale = false,
}) {
  var data = dataDa(valore);

  if (data == null) {
    final originale = valore?.toString().trim() ?? '';
    return mantieniValoreNonValido && originale.isNotEmpty
        ? originale
        : valoreAssente;
  }

  if (locale) data = data.toLocal();

  return '${_dueCifre(data.day)}/${_dueCifre(data.month)}/${data.year}';
}

/// Formatta una data e ora nel formato `gg/mm/aaaa HH:mm`.
///
/// Se [locale] e' `true`, il valore viene convertito nel fuso orario locale
/// prima della formattazione.
String formattaDataOra(
  Object? valore, {
  String valoreAssente = '—',
  bool mantieniValoreNonValido = false,
  bool locale = false,
}) {
  var data = dataDa(valore);

  if (data == null) {
    final originale = valore?.toString().trim() ?? '';
    return mantieniValoreNonValido && originale.isNotEmpty
        ? originale
        : valoreAssente;
  }

  if (locale) data = data.toLocal();

  return '${formattaData(data)} '
      '${_dueCifre(data.hour)}:${_dueCifre(data.minute)}';
}

/// Restituisce la sola parte di data di un [DateTime] in formato ISO `aaaa-mm-gg`.
String? dataIso(DateTime? data) => data?.toIso8601String().split('T').first;

String _dueCifre(int valore) => valore.toString().padLeft(2, '0');

// ============================================================================
// DATI
// ============================================================================

/// Converte una lista generica in una lista di mappe stringa/dinamico.
///
/// Gli elementi che non sono mappe vengono ignorati.
List<Map<String, dynamic>> mappeDa(Object? valore) {
  if (valore is! List) return const <Map<String, dynamic>>[];

  return valore
      .whereType<Map>()
      .map((riga) => Map<String, dynamic>.from(riga))
      .toList(growable: false);
}

/// Estrae i valori univoci di [campo] dalle righe indicate.
///
/// I valori nulli, vuoti o uguali alla stringa `null` vengono esclusi.
List<String> idsUnivoci(
  List<Map<String, dynamic>> righe,
  String campo,
) =>
    righe
        .map((riga) => riga[campo]?.toString())
        .whereType<String>()
        .where((valore) => valore.isNotEmpty && valore != 'null')
        .toSet()
        .toList(growable: false);

/// Restituisce la rappresentazione testuale ripulita di un valore generico.
String testoDa(Object? valore) => valore?.toString().trim() ?? '';

// ============================================================================
// CSV
// ============================================================================

/// Converte un valore in un campo CSV correttamente racchiuso tra virgolette.
///
/// Le virgolette presenti nel testo vengono raddoppiate secondo la sintassi CSV.
String campoCsv(Object? valore) {
  final testo = valore?.toString() ?? '';
  return '"${testo.replaceAll('"', '""')}"';
}

// ============================================================================
// NOMI FILE
// ============================================================================

/// Rende una stringa adatta a essere usata come nome file.
///
/// I caratteri non alfanumerici ammessi vengono sostituiti con `_`.
/// Quando [consentiPunto] e' `true`, il punto viene preservato.
String nomeFileSicuro(String valore, {bool consentiPunto = true}) {
  final espressione = consentiPunto
      ? RegExp(r'[^A-Za-z0-9._-]+')
      : RegExp(r'[^A-Za-z0-9_-]+');

  return valore.replaceAll(espressione, '_');
}
