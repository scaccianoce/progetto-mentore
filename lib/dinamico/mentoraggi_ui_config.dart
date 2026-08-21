class MentoraggiUiConfig {
  MentoraggiUiConfig._();

  static const String datiMentee = 'dati_mentee';
  static const String attivitaMentoraggio = 'attivita_mentoraggio';
  static const String osservazioniMentori = 'osservazioni_mentori';
  static const String documenti = 'documenti';
  static const String sistema = 'sistema';

  /// Campi annuali compilati/modificati dal mentee.
  static const Set<String> campiMentee = {
    'data_inizio',
    'data_fine',
    'numero_studenti',
    'sede',
    'svolgimento',
    'giorni_orari_lezioni',
    'note',
  };

  /// Campi strutturali/tecnici.
  static const Set<String> campiSistema = {
    'id',
    'insegnamento_id',
    'anno_accademico',
    'created_at',
    'updated_at',
  };

  /// Campi documentali.
  static const Set<String> campiDocumenti = {
    'scheda_sintesi_pdf_url',
  };

  /// Ordine esplicito dei campi del mentee.
  static const Map<String, int> ordineCampi = {
    'data_inizio': 10,
    'data_fine': 20,
    'numero_studenti': 30,
    'sede': 40,
    'svolgimento': 50,
    'giorni_orari_lezioni': 60,
    'note': 70,

    'scheda_sintesi_pdf_url': 900,
  };

  static const List<String> ordineSezioni = [
    datiMentee,
    attivitaMentoraggio,
    osservazioniMentori,
    documenti,
    sistema,
  ];

  static String sezione(String campo) {
    if (campiMentee.contains(campo)) {
      return datiMentee;
    }

    if (campo.startsWith('osservazioni')) {
      return osservazioniMentori;
    }

    if (campiDocumenti.contains(campo)) {
      return documenti;
    }

    if (campiSistema.contains(campo)) {
      return sistema;
    }

    /// Tutti gli altri campi di mentoraggi vengono considerati
    /// automaticamente campi operativi dei mentori.
    return attivitaMentoraggio;
  }

  static String titoloSezione(String sezione) => switch (sezione) {
    datiMentee => 'Dati dell’insegnamento',
    attivitaMentoraggio => 'Attività di mentoraggio',
    osservazioniMentori => 'Osservazioni dei mentori',
    documenti => 'Documenti',
    sistema => 'Dati di sistema',
    _ => sezione,
  };

  static int ordine(String campo) {
    final ordineEsplicito = ordineCampi[campo];
    if (ordineEsplicito != null) {
      return ordineEsplicito;
    }

    return switch (sezione(campo)) {
      datiMentee => 99,
      attivitaMentoraggio => 200,
      osservazioniMentori => 500,
      documenti => 900,
      sistema => 1000,
      _ => 9999,
    };
  }

  static int ordineSezione(String campo) {
    final indice = ordineSezioni.indexOf(
      sezione(campo),
    );

    return indice < 0 ? 999 : indice;
  }
}