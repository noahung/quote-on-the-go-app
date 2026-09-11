import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qotg_mobile/models/models.dart';
import 'package:qotg_mobile/providers/providers.dart';
import 'package:qotg_mobile/screens/analytics/analytics_screen.dart';
import 'package:qotg_mobile/theme/app_theme.dart';
import 'package:qotg_mobile/utils/recorded_profit.dart';

Invoice invoice(String date, {String status = 'Paid', double total = 120}) =>
    Invoice(
        id: 'invoice',
        companyId: 'demo',
        createdBy: 'demo',
        invoiceNumber: 'INV-001',
        customerName: 'Long customer business name',
        customerEmail: 'test@example.test',
        date: date,
        dueDate: date,
        items: [],
        subtotal: 100,
        total: total,
        status: status);
Expense expense(String date,
        {String currency = 'GBP',
        String status = 'pending',
        double amount = 60}) =>
    Expense(
        id: 'expense',
        companyId: 'demo',
        date: date,
        merchant: 'Supplier',
        category: 'Materials',
        amount: amount,
        currency: currency,
        status: status);
void main() {
  test(
      'report uses complete UTC days and exports recorded balance and exclusions',
      () {
    final now = DateTime.parse('2026-09-09T13:24:00Z');
    final start = RecordedProfit.periodStart(30, now);
    final end = RecordedProfit.periodEnd(now);
    expect(start, DateTime.utc(2026, 8, 11));
    expect(end, DateTime.utc(2026, 9, 9, 23, 59, 59, 999));
    final result = RecordedProfit.calculate([
      invoice('2026-08-11'),
      invoice('2026-09-09'),
      invoice('2026-09-10'),
      invoice('2026-08-10')
    ], [
      expense('2026-09-09', amount: 300, currency: ' gbp '),
      expense('2026-09-09', currency: 'USD'),
      expense('2026-09-09', status: ' Cancelled ')
    ], start, end);
    expect(result.revenue, 240);
    expect(result.expenses, 300);
    expect(result.margin, -25);
    expect(
        result.csvRows(start, end), contains('Recorded balance (GBP),-60.00'));
    expect(result.csvRows(start, end),
        contains('Other currency expenses excluded,1'));
    expect(result.csvRows(start, end), contains('not accounting net profit'));
  });
  test(
      'recorded margin uses dated paid invoices and eligible expenses, including losses',
      () {
    final result = RecordedProfit.calculate([
      invoice('2026-09-01'),
      invoice('2026-09-10'),
      invoice('2026-09-05', status: 'Draft')
    ], [
      expense('2026-09-03', amount: 180),
      expense('2026-09-03', currency: 'USD'),
      expense('2026-09-03', status: 'Rejected'),
      expense('2026-08-01')
    ], DateTime(2026, 9), DateTime(2026, 9, 9));
    expect(result.revenue, 120);
    expect(result.expenses, 180);
    expect(result.balance, -60);
    expect(result.margin, -50);
    expect(result.excludedCurrencyCount, 1);
    expect(
        RecordedProfit.calculate([], [], DateTime(2026), DateTime(2027)).margin,
        isNull);
  });
  for (final dark in [false, true]) {
    testWidgets('every analytics tab wraps at 320px and 200% text, dark=$dark',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final date =
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      await tester.pumpWidget(ProviderScope(
          overrides: [
            quotationsProvider.overrideWith((ref) => []),
            invoicesProvider
                .overrideWith((ref) => [invoice(date, total: 123456.78)]),
            customersProvider.overrideWith((ref) => []),
            expensesStreamProvider
                .overrideWith((ref) => Stream.value([expense(date)])),
          ],
          child: MaterialApp(
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: const AnalyticsScreen())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in ['Profit', 'Pipeline', 'LTV', 'Trends', 'Insights']) {
        await tester.drag(find.byType(ListView).first, const Offset(0, 10000));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.byType(TabBar), 300,
            scrollable: find.byType(Scrollable).first);
        final tab = find.widgetWithText(Tab, label);
        await tester.ensureVisible(tab);
        await tester.pumpAndSettle();
        await tester.tap(tab);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
    });
  }
}
