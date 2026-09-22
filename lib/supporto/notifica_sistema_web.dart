import 'dart:js_interop';

@JS('mentoreMostraNotifica')
external JSPromise<JSAny?> _mentoreMostraNotifica(
  JSString titolo,
  JSString messaggio,
  JSString link,
);

/// Mostra una notifica tramite il service worker anche con la PWA in primo piano.
Future<void> mostraNotificaSistema({
  required String titolo,
  required String messaggio,
  required String link,
}) async {
  await _mentoreMostraNotifica(titolo.toJS, messaggio.toJS, link.toJS).toDart;
}
