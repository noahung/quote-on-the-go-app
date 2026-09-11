import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qotg_mobile/models/models.dart';
import 'package:qotg_mobile/providers/providers.dart';
import 'package:qotg_mobile/providers/collaboration_provider.dart';
import 'package:qotg_mobile/providers/document_outbox_provider.dart';
import 'package:qotg_mobile/services/document_outbox.dart';
import 'package:qotg_mobile/screens/invoices/invoice_detail_screen.dart';
import 'package:qotg_mobile/screens/quotations/quotation_detail_screen.dart';
import 'package:qotg_mobile/theme/app_theme.dart';
import 'document_copy_test.dart' show quote, item;

void main() {
  setUpAll(() async {
    final entries =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in entries) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final action in [
    'invoice-copy',
    'quotation-copy',
    'quotation-convert'
  ]) {
    testWidgets('detail action $action reaches the durable save status',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final type = action.startsWith('invoice') ? 'invoice' : 'quotation';
      final queue = DocumentOutbox(
          userId: 'owner', companyId: 'company-a', autoSync: false);
      final invoice = Invoice.fromJson({
        ...quote.toJson(),
        'invoiceNumber': 'INV-1',
        'dueDate': '2026-01-30',
        'items': [item.toJson()]
      });
      final router = GoRouter(initialLocation: '/detail', routes: [
        GoRoute(
            path: '/detail',
            builder: (_, __) => type == 'invoice'
                ? const InvoiceDetailScreen(invoiceId: 'quote-a')
                : const QuotationDetailScreen(quotationId: 'quote-a')),
        GoRoute(
            path: '/settings/saves',
            builder: (_, state) => Scaffold(
                body: Text(
                    'Saved request ${state.uri.queryParameters['request']}'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            invoiceProvider('quote-a').overrideWith((ref) => invoice),
            quotationProvider('quote-a').overrideWith((ref) => quote),
            userProfileProvider.overrideWith((ref) => UserProfile(
                uid: 'owner',
                companyId: 'company-a',
                role: 'owner',
                createdAt: DateTime(2026))),
            companyProvider.overrideWith((ref) => null),
            documentOutboxProvider.overrideWith((ref) => queue),
            documentLockProvider((documentId: 'quote-a', documentType: type))
                .overrideWith((ref) => Stream.value(
                    DocumentLockInfo(lockedBy: null, lockedAt: null))),
            documentTimelineProvider(
                    (documentId: 'quote-a', documentType: type))
                .overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp.router(
              theme: AppTheme.lightTheme, routerConfig: router)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (action.endsWith('convert')) {
        final convert = find.text('Convert to Invoice');
        await tester.scrollUntilVisible(convert, 350,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(convert);
      } else {
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Duplicate'));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(queue.entries.length, 1);
      final entry = queue.entries.single;
      expect(entry['status'], 'pending');
      expect(entry['request']['documentType'],
          action == 'quotation-copy' ? 'quotation' : 'invoice');
      expect(find.text('Saved request ${entry['requestId']}'), findsOneWidget);
      expect(entry['request']['fields']['customerId'], 'customer-a');
    });
  }
}
