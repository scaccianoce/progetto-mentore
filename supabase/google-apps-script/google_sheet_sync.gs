/**
 * Web App Google Apps Script per la sincronizzazione configurabile.
 *
 * Configurare nelle Proprietà script:
 *   GOOGLE_SCRIPT_SECRET = la stessa stringa inserita nell'app
 *
 * Il foglio deve avere una colonna "email" oppure una corrispondenza del campo
 * email verso un'altra intestazione, oltre alle intestazioni configurate.
 */
function doPost(e) {
  try {
    const payload = JSON.parse(e.postData.contents || '{}');
    const secretAtteso = PropertiesService.getScriptProperties()
      .getProperty('GOOGLE_SCRIPT_SECRET');

    if (!secretAtteso || payload.secret !== secretAtteso) {
      return risposta({ ok: false, error: 'Chiamata non autorizzata' });
    }

    const email = String(payload.email || '').trim().toLowerCase();
    const intestazioneEmail = String(payload.colonna_email || 'email').trim();
    const valori = payload.valori || {};
    if (!email) throw new Error('Email mancante');

    const foglio = apriFoglio(payload.sheet_url);
    const dati = foglio.getDataRange().getDisplayValues();
    if (dati.length === 0) throw new Error('Foglio vuoto');

    const intestazioni = dati[0].map(v => String(v).trim());
    const indiceEmail = intestazioni.findIndex(
      v => v.toLowerCase() === intestazioneEmail.toLowerCase()
    );
    if (indiceEmail < 0) {
      throw new Error(`Colonna email "${intestazioneEmail}" non trovata`);
    }

    const righe = [];
    for (let i = 1; i < dati.length; i++) {
      if (String(dati[i][indiceEmail]).trim().toLowerCase() === email) {
        righe.push(i + 1);
      }
    }
    if (righe.length === 0) throw new Error(`Email ${email} non trovata`);
    if (righe.length > 1) throw new Error(`Email ${email} presente più volte`);

    const numeroRiga = righe[0];
    Object.entries(valori).forEach(([colonna, valore]) => {
      const indice = intestazioni.findIndex(
        v => v.toLowerCase() === String(colonna).trim().toLowerCase()
      );
      if (indice < 0) throw new Error(`Colonna "${colonna}" non trovata`);
      foglio.getRange(numeroRiga, indice + 1).setValue(valore ?? '');
    });

    return risposta({ ok: true, riga: numeroRiga });
  } catch (errore) {
    return risposta({
      ok: false,
      error: errore instanceof Error ? errore.message : String(errore),
    });
  }
}

function apriFoglio(sheetUrl) {
  const url = String(sheetUrl || '').trim();
  if (!url) {
    return SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  }

  const spreadsheet = SpreadsheetApp.openByUrl(url);
  const gid = url.match(/[?#&]gid=(\d+)/);
  if (!gid) return spreadsheet.getSheets()[0];

  const foglio = spreadsheet.getSheets().find(
    candidato => String(candidato.getSheetId()) === gid[1]
  );
  if (!foglio) throw new Error(`Foglio con gid ${gid[1]} non trovato`);
  return foglio;
}

function risposta(payload) {
  return ContentService
    .createTextOutput(JSON.stringify(payload))
    .setMimeType(ContentService.MimeType.JSON);
}
