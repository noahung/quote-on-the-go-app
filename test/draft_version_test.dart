import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qotg_mobile/models/models.dart';
import 'package:qotg_mobile/providers/providers.dart';
import 'package:qotg_mobile/providers/document_outbox_provider.dart';
import 'package:qotg_mobile/services/document_outbox.dart';
import 'package:qotg_mobile/services/local_draft_store.dart';
import 'package:qotg_mobile/screens/invoices/create_invoice_screen.dart';
import 'package:qotg_mobile/theme/app_theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'restoring an older editor draft retains its original server version',
      (tester) async {
    final queue = DocumentOutbox(
        userId: 'test-user', companyId: 'company-a', autoSync: false);
    final invoice = Invoice(
        id: 'invoice-existing',
        companyId: 'company-a',
        createdBy: 'test-user',
        invoiceNumber: 'INV-1',
        customerName: 'Alex',
        customerEmail: 'alex@example.test',
        date: '2026-09-10',
        dueDate: '2026-09-30',
        items: [],
        subtotal: 0,
        total: 0,
        updatedAt: DateTime.utc(2026, 9, 10));
    const store = LocalDraftStore();
    await store.write(
        store.key('test-user', 'company-a',
            'invoice:invoice-existing:customer::job::quote:'),
        {
          '__baseUpdatedAt': '2026-09-09T00:00:00.000Z',
          'title': 'Offline revision',
          'customerName': 'Alex',
          'customerEmail': 'alex@example.test',
          'date': '2026-09-10',
          'dueDate': '2026-09-30',
          'items': [],
          'taxRate': '0',
        });
    final router = GoRouter(initialLocation: '/editor', routes: [
      GoRoute(
          path: '/editor',
          builder: (_, __) => CreateInvoiceScreen(existingInvoice: invoice)),
      GoRoute(
          path: '/settings/saves',
          builder: (_, __) => const Scaffold(body: Text('Queued'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) => UserProfile(
              uid: 'test-user',
              createdAt: DateTime(2026),
              companyId: 'company-a',
              role: 'owner')),
          companyProvider.overrideWith((ref) => null),
          customersProvider.overrideWith((ref) => []),
          documentTemplatesProvider.overrideWith((ref) => []),
          documentOutboxProvider.overrideWith((ref) => queue),
        ],
        child: MaterialApp.router(
            theme: AppTheme.lightTheme, routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Queued'), findsOneWidget);
    expect(queue.entries.single['request']['expectedUpdatedAt'],
        '2026-09-09T00:00:00.000Z');
    expect(
        queue.entries.single['request']['fields']['title'], 'Offline revision');
    expect(
        await store.read(store.key('test-user', 'company-a',
            'invoice:invoice-existing:customer::job::quote:')),
        isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
