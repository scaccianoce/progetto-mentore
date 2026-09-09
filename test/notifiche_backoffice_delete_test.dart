import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prog_mentore/dati/repository_notifiche.dart';
import 'package:prog_mentore/pagine/backoffice/notifiche/notifiche_backoffice_controller.dart';
import 'package:prog_mentore/pagine/backoffice/notifiche/notifiche_backoffice_page.dart';
import 'package:prog_mentore/ui/dinamico_schema.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeNotificheRepository extends NotificheRepository {
  _FakeNotificheRepository()
      : super(
          client: SupabaseClient(
            'https://example.supabase.co',
            'anon-key',
            authOptions: const AuthClientOptions(
              autoRefreshToken: false,
            ),
          ),
        );

  @override
  Future<List<Map<String, dynamic>>> messaggi({int limite = 200}) async =>
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'msg-1',
          'titolo': 'Test notifica',
          'anno_accademico': '2024/25',
          'destinatari': 12,
          'stato': 'inviato',
        },
      ];
}

class _FakeNotificheBackofficeController extends NotificheBackofficeController {
  _FakeNotificheBackofficeController()
      : super(repository: _FakeNotificheRepository());

  @override
  Future<SchemaDatabase> caricaSchemaDatabase() async =>
      const SchemaDatabase(tabelle: <TabellaDatabase>[]);

  @override
  Future<List<Map<String, dynamic>>> caricaMessaggi() async =>
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'msg-1',
          'titolo': 'Test notifica',
          'anno_accademico': '2024/25',
          'destinatari': 12,
          'stato': 'inviato',
        },
      ];

  @override
  Future<void> eliminaMessaggio(String messaggioId) async {}
}

void main() {
  testWidgets('mostra il pulsante di eliminazione per un messaggio inviato',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificheMessaggiBackofficePage(
          controller: _FakeNotificheBackofficeController(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byTooltip('Elimina notifica'), findsOneWidget);
  });
}
