import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('il service worker Firebase usa uno scope distinto da Flutter', () {
    final servizioPush = File(
      'lib/supporto/notifiche_push_service.dart',
    ).readAsStringSync();
    final workerFirebase = File(
      'web/firebase-cloud-messaging-push-scope/firebase-messaging-sw.js',
    );

    expect(
      servizioPush,
      contains('firebase-cloud-messaging-push-scope/firebase-messaging-sw.js'),
    );
    expect(workerFirebase.existsSync(), isTrue);
    expect(File('web/firebase-messaging-sw.js').existsSync(), isFalse);
    expect(
      workerFirebase.readAsStringSync(),
      contains("new URL('../', self.registration.scope)"),
    );
  });
}
