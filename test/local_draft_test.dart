import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qotg_mobile/services/local_draft_store.dart';
import 'package:qotg_mobile/services/draft_session.dart';
import 'package:qotg_mobile/models/models.dart';
import 'package:qotg_mobile/providers/providers.dart';
import 'package:qotg_mobile/screens/invoices/create_invoice_screen.dart';
import 'package:qotg_mobile/screens/quotations/create_quotation_screen.dart';
import 'package:qotg_mobile/theme/app_theme.dart';

class DelayedStore extends LocalDraftStore {
  final gate = Completer<void>();
  Map<String, dynamic>? data;
  @override
  Future<Map<String, dynamic>?> read(String key) async => data;
  @override
  Future<void> write(String key, Map<String, dynamic> fields) async {
    await gate.future;
    data = fields;
  }

  @override
  Future<void> remove(String key) async {
    data = null;
  }
}

class FailedStore extends LocalDraftStore {
  @override
  Future<Map<String, dynamic>?> read(String key) async => null;
  @override
  Future<void> write(String key, Map<String, dynamic> fields) async =>
      throw StateError('Disk full');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'draft round trip preserves document fields and isolates user and company',
      () async {
    const store = LocalDraftStore();
    final key = store.key('user-a', 'company-a', 'invoice:new');
    final fields = {
      'title': 'Kitchen',
      'notes': 'first\nsecond',
      'taxRate': '20.',
      'discount': 12.5,
      'discountType': 'percentage',
      'customerId': 'c1',
      'jobId': 'j1',
      'quotationId': 'q1',
      'items': [
        {
          'id': 'line',
          'description': 'Work',
          'quantity': 2.5,
          'unitPrice': 100.0,
          'total': 250.0
        }
      ]
    };
    await store.write(key, fields);
    expect(await const LocalDraftStore().read(key), fields);
    expect(await store.read(store.key('user-b', 'company-a', 'invoice:new')),
        isNull);
    expect(await store.read(store.key('user-a', 'company-b', 'invoice:new')),
        isNull);
    expect(store.key('a:b', 'c', 'd'), isNot(store.key('a', 'b:c', 'd')));
  });
  test('completion waits for an older save before clearing recovery', () async {
    final store = DelayedStore();
    final session =
        DraftSession(store: store, key: 'draft', initial: {'title': ''});
    await session.load();
    session.changed({'title': 'Work'});
    final save = session.flush();
    final complete = session.complete();
    store.gate.complete();
    await Future.wait([save, complete]);
    expect(store.data, isNull);
    expect(session.hasChanges, isFalse);
    session.dispose();
  });
  test('local failure stays visible and does not report saved', () async {
    final session = DraftSession(
        store: FailedStore(), key: 'draft', initial: {'title': ''});
    await session.load();
    session.changed({'title': 'Important work'});
    expect(await session.flush(), isFalse);
    expect(session.saved, isFalse);
    expect(session.error, contains('Free up storage'));
    expect(session.hasChanges, isTrue);
    session.dispose();
  });
  test(
      'recovery needs an explicit choice and blank unchanged forms leave no record',
      () async {
    const store = LocalDraftStore();
    final session =
        DraftSession(store: store, key: 'draft', initial: {'title': ''});
    await session.load();
    await session.flush();
    expect(await store.read('draft'), isNull);
    session.changed({'title': 'Keep me'});
    await session.flush();
    session.dispose();
    final reopened =
        DraftSession(store: store, key: 'draft', initial: {'title': ''});
    await reopened.load();
    expect(reopened.locked, isTrue);
    reopened.changed({'title': 'Must not overwrite pending recovery'});
    expect(reopened.restore(), {'title': 'Keep me'});
    await reopened.complete();
    expect(await store.read('draft'), isNull);
    reopened.dispose();
  });

  for (final type in ['quotation', 'invoice']) {
    testWidgets('$type editor restores unsaved title after being closed',
        (tester) async {
      final user = UserProfile(
          uid: 'test-user',
          createdAt: DateTime(2026),
          companyId: 'company',
          role: 'owner');
      Widget editor() => ProviderScope(
              overrides: [
                userProfileProvider.overrideWith((ref) => user),
                companyProvider.overrideWith((ref) => null),
                customersProvider.overrideWith((ref) => []),
                documentTemplatesProvider.overrideWith((ref) => []),
              ],
              child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  home: type == 'quotation'
                      ? const CreateQuotationScreen()
                      : const CreateInvoiceScreen()));
      await tester.pumpWidget(editor());
      await tester.pumpAndSettle();
      final title = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Title (optional)');
      await tester.enterText(title, 'Kitchen renovation, phase 2');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(editor());
      await tester.pumpAndSettle();
      expect(find.text('Restore draft'), findsOneWidget);
      await tester.tap(find.text('Restore draft'));
      await tester.pumpAndSettle();
      expect(find.text('Kitchen renovation, phase 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
