import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'utilita.dart';

/// Esporta su file CSV i risultati gia' preparati dal controller.
class QuestionarioCsvService {
  const QuestionarioCsvService();

  Future<void> esporta(Map<String, dynamic> dati) async {
    final domande = (dati['domande'] as List).cast<Map<String, dynamic>>();
    final compilazioni = (dati['compilazioni'] as List)
        .cast<Map<String, dynamic>>();
    final risposte = (dati['risposte'] as List).cast<Map<String, dynamic>>();
    final buffer = StringBuffer()..write('data_compilazione');

    for (final domanda in domande) {
      buffer.write(',${campoCsv(domanda['testo'])}');
    }
    buffer.writeln();

    for (final compilazione in compilazioni) {
      buffer.write(campoCsv(compilazione['inviato_at']));
      for (final domanda in domande) {
        Map<String, dynamic>? risposta;
        for (final riga in risposte) {
          if (riga['compilazione_id']?.toString() ==
                  compilazione['id'].toString() &&
              riga['domanda_id']?.toString() == domanda['id'].toString()) {
            risposta = riga;
            break;
          }
        }
        buffer.write(',${campoCsv(risposta?['valore'])}');
      }
      buffer.writeln();
    }

    final titoloRaw = (dati['questionario'] as Map)['titolo']?.toString();
    final titolo = titoloRaw == null
        ? null
        : nomeFileSicuro(titoloRaw, consentiPunto: false);
    await FilePicker.saveFile(
      dialogTitle: 'Esporta risultati questionario',
      fileName: '${titolo ?? 'questionario'}_risultati.csv',
      bytes: Uint8List.fromList(utf8.encode(buffer.toString())),
      mimeType: 'text/csv',
    );
  }

}
