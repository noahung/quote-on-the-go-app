import '../../utils/recorded_profit.dart';
import '../../components/analytics_metric.dart';
import '../../components/glass_card.dart';
import 'dart:io';
import 'document_trends.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../components/curved_header.dart';
import '../../theme/semantic_colors.dart';
import '../../providers/providers.dart';
import '../../utils/feedback_controller.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDateRange = '90 Days';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime _cutoff(DateTime now) => RecordedProfit.periodStart(
      switch (_selectedDateRange) {
        '30 Days' => 30,
        '6 Months' => 180,
        '1 Year' => 365,
        _ => 90,
      },
      now);

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: '£', decimalDigits: 0);

    // Real data from Firestore
    final allQuotations = ref.watch(quotationsProvider);
    final allInvoices = ref.watch(invoicesProvider);
    final allCustomers = ref.watch(customersProvider);

    final now = RecordedProfit.periodEnd(DateTime.now());
    final cutoff = _cutoff(now);
    final expenses = ref.watch(expensesStreamProvider);
    final profit = expenses.hasError || expenses.valueOrNull == null
        ? null
        : RecordedProfit.calculate(
            allInvoices, expenses.valueOrNull!, cutoff, now);

    // Filter to selected date range
    final quotations = allQuotations
        .where((q) => RecordedProfit.inRange(q.date, cutoff, now))
        .toList();
    final invoices = allInvoices
        .where((i) => RecordedProfit.inRange(i.date, cutoff, now))
        .toList();

    // ── Metric computations ──────────────────────────────────────────────────
    final paidInvoices = invoices.where((i) => i.status == 'Paid').toList();
    final totalRevenue = paidInvoices.fold(0.0, (s, i) => s + i.total);
    final pipelineQuotes = quotations
        .where((q) =>
            q.status == 'Draft' || q.status == 'Sent' || q.status == 'Amended')
        .toList();
    final pipelineValue = pipelineQuotes.fold(0.0, (s, q) => s + q.total);

    final customerCount = allCustomers.length;
    final avgLtv = customerCount > 0 ? totalRevenue / customerCount : 0.0;

    final sentCount = quotations
        .where((q) =>
            q.status == 'Sent' ||
            q.status == 'Accepted' ||
            q.status == 'Declined' ||
            q.status == 'Amended')
        .length;
    final acceptedCount =
        quotations.where((q) => q.status == 'Accepted').length;
    final conversionRate =
        sentCount > 0 ? acceptedCount / sentCount * 100 : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          CurvedHeader(
            title: 'Analytics',
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.download),
                tooltip: 'Export report',
                onPressed: () => _exportReport(
                  context,
                  quotations: quotations,
                  invoices: invoices,
                  customers: allCustomers,
                  allInvoices: allInvoices,
                  profit: profit,
                  start: cutoff,
                  end: now,
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ExpansionTile(title: const Text('Six-month trends'), children: [
                  MonthlyRevenueChart(invoices: allInvoices),
                  const SizedBox(height: 16),
                  QuoteActivityChart(quotations: allQuotations),
                  const SizedBox(height: 24),
                ]),
// Date Range Selection Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['30 Days', '90 Days', '6 Months', '1 Year']
                        .map((range) {
                      final isSelected = _selectedDateRange == range;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(
                            range,
                            style: TextStyle(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFFF4781F),
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.04),
                          shape: const StadiumBorder(),
                          side: BorderSide.none,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedDateRange = range);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                GlassCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      AnalyticsMetric(
                          title: 'Recorded margin',
                          value: profit?.margin == null
                              ? '—'
                              : '${profit!.margin!.toStringAsFixed(1)}%',
                          subtitle: profit == null
                              ? 'Expenses unavailable; retry below'
                              : 'Paid revenue less recorded GBP expenses'),
                      const Divider(),
                      AnalyticsMetric(
                          title: 'Pipeline value',
                          value: currency.format(pipelineValue),
                          subtitle: '${pipelineQuotes.length} open quotes'),
                      const Divider(),
                      AnalyticsMetric(
                          title: 'Average customer revenue',
                          value: currency.format(avgLtv),
                          subtitle:
                              '$customerCount customers in this calculation'),
                      const Divider(),
                      AnalyticsMetric(
                          title: 'Quote conversion',
                          value: '${conversionRate.toStringAsFixed(1)}%',
                          subtitle:
                              '$acceptedCount accepted of $sentCount sent quotes'),
                    ])),
                const SizedBox(height: 24),

                // Segmented Tabs
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFF4781F),
                    labelColor: Theme.of(context).colorScheme.onSurface,
                    unselectedLabelColor:
                        isDark ? Colors.white54 : Colors.black54,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      Tab(text: 'Profit'),
                      Tab(text: 'Pipeline'),
                      Tab(text: 'LTV'),
                      Tab(text: 'Trends'),
                      Tab(text: 'Insights'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) => switch (_tabController.index) {
                    0 => _buildProfitTab(context, profit, expenses.isLoading),
                    1 =>
                      _buildPipelineTab(context, quotations, isDark, currency),
                    2 => _buildLtvTab(
                        context, allCustomers, allInvoices, isDark, currency),
                    3 => _buildTrendsTab(
                        context, allInvoices, semanticColors, isDark, currency),
                    _ => _buildInsightsTab(
                        context, quotations, invoices, semanticColors, isDark),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Profit Tab ───────────────────────────────────────────────────────────
  Widget _buildProfitTab(
      BuildContext context, RecordedProfit? profit, bool loading) {
    final currency = NumberFormat.currency(symbol: '£');
    return GlassCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Revenue and expenses',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      if (profit == null) ...[
        Text(loading
            ? 'Loading recorded expenses…'
            : 'Could not load expenses. Your margin is unavailable until they can be checked.'),
        if (!loading)
          TextButton(
              onPressed: () => ref.invalidate(expensesStreamProvider),
              child: const Text('Retry expenses')),
      ] else ...[
        AnalyticsMetric(
            title: 'Paid revenue',
            value: currency.format(profit.revenue),
            subtitle: 'Paid invoices dated within this period (UTC)'),
        const Divider(),
        AnalyticsMetric(
            title: 'Recorded expenses',
            value: currency.format(profit.expenses),
            subtitle: 'GBP expenses, excluding rejected or cancelled records'),
        const Divider(),
        AnalyticsMetric(
            title: 'Revenue less expenses',
            value: currency.format(profit.balance),
            subtitle: 'Includes tax. This is not accounting net profit.'),
        if (profit.excludedCurrencyCount > 0)
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                  '${profit.excludedCurrencyCount} expenses in other currencies excluded. No exchange-rate conversion applied.')),
      ],
    ]));
  }

  // ── Pipeline Tab ─────────────────────────────────────────────────────────
  Widget _buildPipelineTab(BuildContext context, List<dynamic> quotations,
      bool isDark, NumberFormat currency) {
    final stages = ['Draft', 'Sent', 'Amended', 'Accepted', 'Declined'];
    final maxValue = stages
        .map((s) => quotations
            .where((q) => q.status == s)
            .fold(0.0, (a, q) => a + (q.total as num).toDouble()))
        .reduce((a, b) => a > b ? a : b);
    final sentCount = quotations
        .where((q) =>
            q.status == 'Sent' ||
            q.status == 'Accepted' ||
            q.status == 'Declined' ||
            q.status == 'Amended')
        .length;
    final acceptedCount =
        quotations.where((q) => q.status == 'Accepted').length;
    final rate = sentCount > 0 ? (acceptedCount / sentCount * 100) : 0.0;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales Funnel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...stages.map((stage) {
              final count = quotations.where((q) => q.status == stage).length;
              final value = quotations
                  .where((q) => q.status == stage)
                  .fold(0.0, (a, q) => a + (q.total as num).toDouble());
              final pct = maxValue > 0 ? value / maxValue : 0.0;
              return _buildPipelineItem(
                  stage, '$count quotes', currency.format(value), pct);
            }),
            const SizedBox(height: 20),
            const Divider(),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                const Text('Conversion Rate',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${rate.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: rate > 50 ? Colors.green : Colors.orange)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineItem(
          String stage, String count, String value, double percent) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AnalyticsMetric(title: stage, value: value, subtitle: count),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: percent.clamp(0.0, 1.0), minHeight: 6),
        ]),
      );

  // ── LTV Tab ───────────────────────────────────────────────────────────────
  Widget _buildLtvTab(BuildContext context, List<dynamic> customers,
      List<dynamic> allInvoices, bool isDark, NumberFormat currency) {
    // Compute per-customer revenue from all paid invoices
    final revenueByCustomer = <String, double>{};
    for (final inv in allInvoices.where((i) => i.status == 'Paid')) {
      revenueByCustomer[inv.customerId ?? inv.customerName] =
          (revenueByCustomer[inv.customerId ?? inv.customerName] ?? 0) +
              (inv.total as num).toDouble();
    }
    final values = revenueByCustomer.values.toList()
      ..sort((a, b) => b.compareTo(a));
    final high = values.where((v) => v >= 5000).length;
    final mid = values.where((v) => v >= 1000 && v < 5000).length;
    final low = values.where((v) => v > 0 && v < 1000).length;
    final zero = customers.length - revenueByCustomer.length;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Client Segments by LTV',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _buildLtvRow(
                'High-Value (£5k+)',
                '$high clients',
                currency.format(
                    values.where((v) => v >= 5000).fold(0.0, (a, b) => a + b)),
                Colors.orange),
            _buildLtvRow(
                'Mid-Value (£1k–5k)',
                '$mid clients',
                currency.format(values
                    .where((v) => v >= 1000 && v < 5000)
                    .fold(0.0, (a, b) => a + b)),
                Colors.blue),
            _buildLtvRow(
                'Low-Value (<£1k)',
                '$low clients',
                currency.format(values
                    .where((v) => v > 0 && v < 1000)
                    .fold(0.0, (a, b) => a + b)),
                Colors.grey),
            _buildLtvRow('No Revenue Yet', '${zero > 0 ? zero : 0} clients',
                '£0', Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildLtvRow(String name, String count, String value, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: AnalyticsMetric(title: name, value: value, subtitle: count),
      );

  // ── Insights Tab ──────────────────────────────────────────────────────────
  Widget _buildInsightsTab(BuildContext context, List<dynamic> quotations,
      List<dynamic> invoices, SemanticColors colors, bool isDark) {
    final total = quotations.length;
    final amended = quotations.where((q) => q.status == 'Amended').length;
    final amendRate = total > 0 ? (amended / total * 100) : 0.0;
    final accepted = quotations.where((q) => q.status == 'Accepted').length;
    final sent = quotations
        .where((q) =>
            q.status == 'Sent' ||
            q.status == 'Accepted' ||
            q.status == 'Declined' ||
            q.status == 'Amended')
        .length;
    final conv = sent > 0 ? (accepted / sent * 100) : 0.0;
    final overdue = invoices.where((i) => i.status == 'Overdue').length;
    final avgVal = total > 0
        ? quotations.fold(0.0, (s, q) => s + (q.total as num).toDouble()) /
            total
        : 0.0;
    final currency = NumberFormat.currency(symbol: '£', decimalDigits: 0);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Performance Insights',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _buildInsightListItem(
                'Amendment rate: ${amendRate.toStringAsFixed(1)}% of ${total} quotes'),
            _buildInsightListItem(
                'Quote conversion: ${conv.toStringAsFixed(1)}% (${accepted} accepted / ${sent} sent)'),
            _buildInsightListItem(
                'Avg. quotation value: ${currency.format(avgVal)}'),
            _buildInsightListItem('Overdue invoices right now: $overdue'),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightListItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  // ── Trends Tab (seasonal + forecast) ──────────────────────────────────────
  List<({DateTime month, double revenue})> _monthlyRevenue(
      List<dynamic> allInvoices, int months) {
    final now = RecordedProfit.periodEnd(DateTime.now());
    final series = <({DateTime month, double revenue})>[];
    final paid = allInvoices.where((i) => i.status == 'Paid').toList();
    for (int i = months - 1; i >= 0; i--) {
      final m = DateTime.utc(now.year, now.month - i);
      final monthEnd = DateTime.utc(m.year, m.month + 1)
          .subtract(const Duration(milliseconds: 1));
      final revenue = paid.where((inv) {
        return RecordedProfit.inRange(
            inv.date, m, monthEnd.isAfter(now) ? now : monthEnd);
      }).fold(0.0, (s, inv) => s + (inv.total as num).toDouble());
      series.add((month: m, revenue: revenue));
    }
    return series;
  }

  Widget _buildTrendsTab(BuildContext context, List<dynamic> allInvoices,
      SemanticColors colors, bool isDark, NumberFormat currency) {
    final series = _monthlyRevenue(allInvoices, 12);
    final hasData = series.any((e) => e.revenue > 0);
    if (!hasData) {
      return _emptyCard('No paid revenue yet to chart trends.', isDark);
    }

    final ranked = [...series]..sort((a, b) => b.revenue.compareTo(a.revenue));
    final recent = series.sublist(series.length - 3);
    final preceding = series.sublist(series.length - 6, series.length - 3);
    final recentAverage =
        recent.fold(0.0, (sum, month) => sum + month.revenue) / 3;
    final precedingAverage =
        preceding.fold(0.0, (sum, month) => sum + month.revenue) / 3;
    final growth = precedingAverage > 0
        ? (recentAverage - precedingAverage) / precedingAverage
        : 0.0;
    final forecast = (recentAverage * (1 + growth)).clamp(0, double.infinity);

    return GlassCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Revenue trends', style: Theme.of(context).textTheme.titleLarge),
      const Text(
          'Paid invoice totals by invoice date, over the last 12 months.'),
      const SizedBox(height: 16),
      AnalyticsMetric(
          title: 'Peak month',
          value: currency.format(ranked.first.revenue),
          subtitle: DateFormat('MMM yyyy').format(ranked.first.month)),
      const Divider(),
      AnalyticsMetric(
          title: 'Slowest month',
          value: currency.format(ranked.last.revenue),
          subtitle: DateFormat('MMM yyyy').format(ranked.last.month)),
      const Divider(),
      AnalyticsMetric(
          title: 'Next month forecast',
          value: currency.format(forecast),
          subtitle:
              'Estimate from the last three months and their growth over the preceding three. Not guaranteed revenue.'),
      const SizedBox(height: 24),
      for (final entry in series) ...[
        AnalyticsMetric(
            title: DateFormat('MMM yyyy').format(entry.month),
            value: currency.format(entry.revenue),
            subtitle: 'Paid revenue'),
        const Divider(),
      ],
    ]));
  }

  // ── Export ────────────────────────────────────────────────────────────────
  Future<void> _exportReport(
    BuildContext context, {
    required List<dynamic> quotations,
    required List<dynamic> invoices,
    required List<dynamic> customers,
    required List<dynamic> allInvoices,
    required RecordedProfit? profit,
    required DateTime start,
    required DateTime end,
  }) async {
    final paid = invoices.where((i) => i.status == 'Paid').toList();
    final totalRevenue =
        paid.fold(0.0, (s, i) => s + (i.total as num).toDouble());
    final pipeline = quotations
        .where((q) =>
            q.status == 'Draft' || q.status == 'Sent' || q.status == 'Amended')
        .fold(0.0, (s, q) => s + (q.total as num).toDouble());
    final sent = quotations
        .where((q) =>
            q.status == 'Sent' ||
            q.status == 'Accepted' ||
            q.status == 'Declined' ||
            q.status == 'Amended')
        .length;
    final accepted = quotations.where((q) => q.status == 'Accepted').length;
    final conv = sent > 0 ? accepted / sent * 100 : 0.0;
    final series = _monthlyRevenue(allInvoices, 12);

    final buffer = StringBuffer()
      ..writeln('Quote On The Go — Analytics Report')
      ..writeln('Range,$_selectedDateRange')
      ..writeln('Generated (UTC),${DateTime.now().toUtc().toIso8601String()}')
      ..writeln('')
      ..writeln('Metric,Value')
      ..writeln(profit?.csvRows(start, end) ??
          'Paid invoices (GBP),${totalRevenue.toStringAsFixed(2)}\nRecorded expenses,Unavailable\nRecorded balance,Unavailable\nRecorded margin,Unavailable\nExpense status,Could not load recorded expenses')
      ..writeln('Pipeline Value,${pipeline.toStringAsFixed(2)}')
      ..writeln('Customers,${customers.length}')
      ..writeln('Quotes Sent,$sent')
      ..writeln('Quotes Accepted,$accepted')
      ..writeln('Conversion Rate,${conv.toStringAsFixed(1)}%')
      ..writeln('')
      ..writeln('Month,Revenue');
    for (final e in series) {
      buffer.writeln(
          '${DateFormat('MMM yyyy').format(e.month)},${e.revenue.toStringAsFixed(2)}');
    }

    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/analytics-report.csv');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')],
          subject: 'Analytics Report');
    } catch (_) {
      if (context.mounted) {
        ref
            .read(feedbackControllerProvider)
            .error(context, 'Could not export the report. Please try again.');
      }
    }
  }

  Widget _emptyCard(String message, bool isDark) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Center(
          child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message,
            style: const TextStyle(color: Colors.grey, fontSize: 14)),
      )),
    );
  }
}
