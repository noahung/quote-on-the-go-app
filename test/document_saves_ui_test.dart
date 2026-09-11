import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qotg_mobile/models/models.dart';
import 'package:qotg_mobile/providers/providers.dart';
import 'package:qotg_mobile/providers/document_outbox_provider.dart';
import 'package:qotg_mobile/services/document_outbox.dart';
import 'package:qotg_mobile/services/local_draft_store.dart';
import 'package:qotg_mobile/screens/settings/document_saves_screen.dart';
import 'package:qotg_mobile/screens/invoices/create_invoice_screen.dart';
import 'package:qotg_mobile/screens/quotations/create_quotation_screen.dart';
import 'package:qotg_mobile/theme/app_theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    for (final entry
        in jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });
  final fixture = <Map<String, dynamic>>[
    for (final status in ['synced', 'failed', 'pending'])
      {
        'requestId': status,
        'status': status,
        'retryable': false,
        if (status == 'failed')
          'error':
              'This document changed on another device. Your changes are kept here.',
        'request': {
          'documentType': 'invoice',
          'mode': 'update',
          'documentId': 'invoice-one',
          'fields': {
            'customerName': 'Alexandra Montgomery',
            'customerEmail': 'alex@example.test',
            'date': '2026-09-10',
            'dueDate': '2026-09-30',
            'items': [],
            'total': 120,
            'subtotal': 100,
            'taxAmount': 20,
            'taxRate': 20,
            'notes': 'Repair the kitchen cabinets and drawer runners.',
          }
        },
      },
  ];
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('saved requests ${dark ? 'dark' : 'light'} at scale $scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final retries = <String>[];
        await tester.pumpWidget(MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: RepaintBoundary(
                key: const Key('capture'),
                child: Scaffold(
                    appBar: AppBar(title: const Text('Saved requests')),
                    body: DocumentSavesContent(
                        entries: fixture,
                        onRetry: retries.add,
                        onOpen: (_) {})))));
        await tester.pumpAndSettle();
        if (scale == 1)
          await expectLater(
              find.byKey(const Key('capture')),
              matchesGoldenFile(
                  'goldens/document-saves_${dark ? 'dark' : 'light'}.png'));
        await tester.scrollUntilVisible(
            find.text('Retry save').hitTestable(), 250,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Retry save'));
        expect(retries, ['failed']);
        await tester.scrollUntilVisible(
            find.text('View saved changes').last.hitTestable(), 250,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('View saved changes').last);
        await tester.pumpAndSettle();
        expect(find.text('Your saved changes'), findsOneWidget);
        expect(find.textContaining('Repair the kitchen'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      });
    }
  }
  for (final type in ['invoice', 'quotation']) {
    testWidgets(
        '$type editor queues a durable save and opens status without a network connection',
        (tester) async {
      final queue = DocumentOutbox(
          userId: 'test-user', companyId: 'company-a', autoSync: false);
      const customer = Customer(
          id: 'customer-a',
          companyId: 'company-a',
          name: 'Alex',
          email: 'alex@example.test');
      final router = GoRouter(initialLocation: '/editor', routes: [
        GoRoute(
            path: '/editor',
            builder: (_, __) => type == 'invoice'
                ? const CreateInvoiceScreen(prefilledCustomer: customer)
                : const CreateQuotationScreen(prefilledCustomer: customer)),
        GoRoute(
            path: '/settings/saves',
            builder: (_, __) => const Scaffold(body: Text('Request queued'))),
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
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(find.text('Request queued'), findsOneWidget);
      expect(queue.entries, hasLength(1));
      final request = queue.entries.single['request'];
      expect(request['documentType'], type);
      expect(request['fields']['customerName'], 'Alex');
      expect(request['mode'], 'create');
      expect(queue.entries.single['status'], 'pending');
      final disk = await const LocalDraftStore().read(queue.key);
      expect(disk!['entries'], hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
