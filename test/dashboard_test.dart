import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qotg_mobile/models/models.dart';
import 'package:qotg_mobile/screens/dashboard/dashboard_screen.dart';
import 'package:qotg_mobile/theme/app_theme.dart';

final now = DateTime(2026, 9, 9, 9);
Quotation quote(String id, {String status = 'Draft'}) => Quotation(
    id: id,
    companyId: 'demo',
    createdBy: 'demo',
    quotationNumber: 'Q-1042',
    customerName: 'Oliver James',
    customerEmail: 'oliver@example.test',
    date: '2026-09-08',
    expiryDate: '2026-10-08',
    items: [],
    subtotal: 400,
    total: 480,
    status: status);
Invoice invoice(String id,
        {String status = 'Sent',
        String due = '2026-09-08',
        String? quoteId,
        bool archived = false}) =>
    Invoice(
        id: id,
        companyId: 'demo',
        createdBy: 'demo',
        invoiceNumber: 'INV-0086',
        customerName: 'Sarah Wilson',
        customerEmail: 'sarah@example.test',
        date: '2026-08-30',
        dueDate: due,
        items: [],
        subtotal: 300,
        total: 360,
        status: status,
        quotationId: quoteId,
        isArchived: archived);
final jobs = [
  CalendarEvent(
      id: 'job',
      companyId: 'demo',
      userId: 'demo',
      title: 'Kitchen fitting',
      customerName: 'Oliver James',
      start: '2026-09-09T10:00:00',
      end: '2026-09-09T12:00:00',
      status: 'Scheduled')
];

void main() {
  setUpAll(() async {
    final font = FontLoader('DMSans')
      ..addFont(rootBundle.load('assets/fonts/DMSans.ttf'));
    await font.load();
    final manifest = await rootBundle.loadString('FontManifest.json');
    for (final entry in (jsonDecode(manifest) as List)) {
      final family = entry['family'] as String;
      if (family == 'DMSans') continue;
      final loader = FontLoader(family);
      for (final asset in entry['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });
  test(
      'attention handles due dates, paid invoices and previously invoiced quotes',
      () {
    final items = homeAttentionItems([
      quote('accepted', status: 'Accepted')
    ], [
      invoice('late'),
      invoice('today', due: '2026-09-09'),
      invoice('paid', status: 'Paid'),
      invoice('converted', quoteId: 'accepted', archived: true),
    ], now);
    expect(items.map((i) => i.route), ['/invoices/late']);
  });
  test('ink labels meet AA on orange in both themes', () {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      double ratio(Color a, Color b) {
        final x = a.computeLuminance();
        final y = b.computeLuminance();
        return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
      }

      final c = theme.colorScheme;
      expect(ratio(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5));
      expect(ratio(c.onSurfaceVariant, c.surfaceContainerLow),
          greaterThanOrEqualTo(4.5));
    }
  });
  for (final scenario in [
    'light',
    'dark',
    'empty',
    'error',
    'large_text',
    'tablet'
  ]) {
    testWidgets('home $scenario renders and keeps actions reachable',
        (tester) async {
      final size = scenario == 'tablet'
          ? const Size(900, 1100)
          : scenario == 'large_text'
              ? const Size(320, 800)
              : const Size(390, 844);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final routes = <String>[];
      await tester.pumpWidget(MaterialApp(
          theme: scenario == 'dark' ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: MediaQuery(
              data: MediaQueryData(
                  size: size,
                  textScaler:
                      TextScaler.linear(scenario == 'large_text' ? 2 : 1)),
              child: Scaffold(
                  body: RepaintBoundary(
                      key: const Key('home'),
                      child: DashboardContent(
                        name: scenario == 'large_text'
                            ? 'Alexandertheverylongname Smith'
                            : 'Noah',
                        now: now,
                        quotations: scenario == 'empty'
                            ? []
                            : [quote('draft'), quote('sent', status: 'Sent')],
                        invoices: scenario == 'empty' ? [] : [invoice('late')],
                        events: scenario == 'empty' ? [] : jobs,
                        failed: scenario == 'error',
                        scheduleFailed: scenario == 'error',
                        onNavigate: routes.add,
                        onMenu: () {},
                        onSearch: () {},
                        onRefresh: () async {},
                      )),
                  bottomNavigationBar: NavigationBar(destinations: const [
                    NavigationDestination(
                        icon: Icon(Icons.home_outlined), label: 'Home'),
                    NavigationDestination(
                        icon: Icon(Icons.calendar_month), label: 'Schedule'),
                    NavigationDestination(
                        icon: Icon(Icons.people_outline), label: 'Customers'),
                    NavigationDestination(
                        icon: Icon(Icons.settings_outlined), label: 'Settings'),
                  ])))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (scenario != 'large_text')
        await expectLater(find.byType(Scaffold),
            matchesGoldenFile('goldens/home_$scenario.png'));
      await tester.ensureVisible(find.text('Create quote'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create quote'));
      expect(routes.last, '/quotations/new');
      await tester.scrollUntilVisible(find.text('Analytics'), 350,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analytics'));
      expect(routes.last, '/analytics');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('loading does not claim the business has no documents',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: DashboardContent(
                name: '',
                quotations: [],
                invoices: [],
                events: [],
                now: now,
                loading: true,
                scheduleLoading: true,
                onNavigate: (_) {},
                onMenu: () {},
                onSearch: () {},
                onRefresh: () async {}))));
    expect(find.text('Loading quotes and invoices'), findsOneWidget);
    expect(find.text('Your next job starts here'), findsNothing);
    expect(find.text('Needs attention'), findsNothing);
  });
}
