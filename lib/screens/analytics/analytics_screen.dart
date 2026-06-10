import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../components/curved_header.dart';
import '../../theme/semantic_colors.dart';
import '../../providers/providers.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDateRange = '90 Days';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Compute date cutoff based on selected range
  DateTime _cutoff() {
    final now = DateTime.now();
    switch (_selectedDateRange) {
      case '30 Days':  return now.subtract(const Duration(days: 30));
      case '6 Months': return now.subtract(const Duration(days: 183));
      case '1 Year':   return now.subtract(const Duration(days: 365));
      default:         return now.subtract(const Duration(days: 90));
    }
  }

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: '£', decimalDigits: 0);

    // Real data from Firestore
    final allQuotations = ref.watch(quotationsProvider);
    final allInvoices   = ref.watch(invoicesProvider);
    final allCustomers  = ref.watch(customersProvider);

    final cutoff = _cutoff();

    // Filter to selected date range
    final quotations = allQuotations.where((q) =>
        (q.createdAt ?? DateTime(2000)).isAfter(cutoff)).toList();
    final invoices = allInvoices.where((i) =>
        (i.createdAt ?? DateTime(2000)).isAfter(cutoff)).toList();

    // ── Metric computations ──────────────────────────────────────────────────
    final paidInvoices  = invoices.where((i) => i.status == 'Paid').toList();
    final totalRevenue  = paidInvoices.fold(0.0, (s, i) => s + i.total);
    final totalCost     = paidInvoices.fold(0.0, (s, i) => s + i.subtotal * 0.4); // est 40% cost
    final avgMargin     = totalRevenue > 0
        ? ((totalRevenue - totalCost) / totalRevenue * 100).clamp(0, 100)
        : 0.0;

    final pipelineQuotes = quotations.where((q) =>
        q.status == 'Draft' || q.status == 'Sent').toList();
    final pipelineValue  = pipelineQuotes.fold(0.0, (s, q) => s + q.total);

    final customerCount  = allCustomers.length;
    final avgLtv = customerCount > 0 ? totalRevenue / customerCount : 0.0;

    final sentCount     = quotations.where((q) => q.status == 'Sent' || q.status == 'Accepted' || q.status == 'Declined').length;
    final acceptedCount = quotations.where((q) => q.status == 'Accepted').length;
    final conversionRate = sentCount > 0 ? acceptedCount / sentCount * 100 : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          CurvedHeader(title: 'Analytics'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Date Range Selection Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['30 Days', '90 Days', '6 Months', '1 Year'].map((range) {
                      final isSelected = _selectedDateRange == range;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(
                            range,
                            style: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFFF4781F),
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                          shape: const StadiumBorder(),
                          side: BorderSide.none,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedDateRange = range);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Hero Metric Cards
                SizedBox(
                  height: 130,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildMetricCard(
                        context,
                        title: 'Avg. Profit Margin',
                        value: '${avgMargin.toStringAsFixed(1)}%',
                        subtitle: 'Revenue: ${currency.format(totalRevenue)}',
                        icon: Icons.trending_up,
                        iconColor: semanticColors.success,
                        bgColor: const Color(0xFFF4781F),
                        textColor: Colors.white,
                        useGradient: true,
                      ),
                      _buildMetricCard(
                        context,
                        title: 'Pipeline Value',
                        value: currency.format(pipelineValue),
                        subtitle: '${pipelineQuotes.length} open quotes',
                        icon: Icons.track_changes,
                        iconColor: Colors.blueAccent,
                      ),
                      _buildMetricCard(
                        context,
                        title: 'Avg. Customer LTV',
                        value: currency.format(avgLtv),
                        subtitle: '$customerCount total customers',
                        icon: Icons.people,
                        iconColor: Colors.purpleAccent,
                      ),
                      _buildMetricCard(
                        context,
                        title: 'Conversion Rate',
                        value: '${conversionRate.toStringAsFixed(1)}%',
                        subtitle: '$acceptedCount / $sentCount quotes',
                        icon: Icons.check_circle_outline,
                        iconColor: Colors.orangeAccent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Segmented Tabs
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFF4781F),
                    labelColor: const Color(0xFFF4781F),
                    unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                    tabs: const [
                      Tab(text: 'Profit'),
                      Tab(text: 'Pipeline'),
                      Tab(text: 'LTV'),
                      Tab(text: 'Insights'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  height: 380,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildProfitTab(context, invoices, semanticColors, isDark, currency),
                      _buildPipelineTab(context, quotations, isDark, currency),
                      _buildLtvTab(context, allCustomers, allInvoices, isDark, currency),
                      _buildInsightsTab(context, quotations, invoices, semanticColors, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    Color? bgColor,
    Color? textColor,
    bool useGradient = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: useGradient ? Colors.white24 : iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: useGradient ? Colors.white : iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textColor ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: textColor?.withValues(alpha: 0.8) ?? (isDark ? Colors.white54 : Colors.black45),
            ),
          ),
        ],
      ),
    );

    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: useGradient ? null : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
        gradient: useGradient
            ? LinearGradient(
                colors: [bgColor ?? const Color(0xFFF4781F), const Color(0xFFFF8F00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(24),
        border: useGradient
            ? null
            : Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: content,
    );
  }

  // ── Profit Tab ───────────────────────────────────────────────────────────
  Widget _buildProfitTab(BuildContext context, List<dynamic> invoices, SemanticColors colors, bool isDark, NumberFormat currency) {
    // Group paid invoices by customer name to get per-service-type revenue
    final paid = invoices.where((i) => i.status == 'Paid').toList();
    final total = paid.fold(0.0, (s, i) => s + (i.total as num).toDouble());
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;

    if (paid.isEmpty) {
      return _emptyCard('No paid invoices yet in this period.', isDark);
    }

    // Group by month for trend
    final now = DateTime.now();
    final prevMonth = DateTime(now.year, now.month - 1);
    final prevPaid = paid.where((i) => (i.createdAt ?? DateTime(2000)).month == prevMonth.month && (i.createdAt ?? DateTime(2000)).year == prevMonth.year).fold(0.0, (s, i) => s + (i.total as num).toDouble());
    final thisPaid = paid.where((i) => (i.createdAt ?? DateTime(2000)).month == now.month && (i.createdAt ?? DateTime(2000)).year == now.year).fold(0.0, (s, i) => s + (i.total as num).toDouble());
    final trend = prevPaid > 0 ? ((thisPaid - prevPaid) / prevPaid * 100) : 0.0;

    return Card(
      elevation: 0, color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Revenue Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${paid.length} paid invoices • ${currency.format(total)} total',
                style: TextStyle(fontSize: 12, color: colors.accentPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _buildProfitItem('Total Revenue', total > 0 ? 1.0 : 0, currency.format(total), 'Paid invoices', colors.accentPrimary),
            const SizedBox(height: 12),
            _buildProfitItem('Est. Profit (60%)', total > 0 ? 0.6 : 0, currency.format(total * 0.6), '~40% costs', colors.success),
            const SizedBox(height: 12),
            _buildProfitItem('Outstanding', 0.3, currency.format(invoices.where((i) => i.status == 'Sent' || i.status == 'Overdue').fold(0.0, (s, i) => s + (i.total as num).toDouble())), 'Unpaid invoices', Colors.blue),
            const Spacer(),
            if (prevPaid > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Last month: ${currency.format(prevPaid)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (trend >= 0 ? colors.success : colors.error).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}% this month',
                      style: TextStyle(color: trend >= 0 ? colors.success : colors.error, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitItem(String name, double percent, String rev, String profit, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(rev, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.black12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(profit, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  // ── Pipeline Tab ─────────────────────────────────────────────────────────
  Widget _buildPipelineTab(BuildContext context, List<dynamic> quotations, bool isDark, NumberFormat currency) {
    final stages = ['Draft', 'Sent', 'Accepted', 'Declined'];
    final maxValue = stages.map((s) => quotations.where((q) => q.status == s).fold(0.0, (a, q) => a + (q.total as num).toDouble())).reduce((a, b) => a > b ? a : b);
    final sentCount = quotations.where((q) => q.status == 'Sent' || q.status == 'Accepted' || q.status == 'Declined').length;
    final acceptedCount = quotations.where((q) => q.status == 'Accepted').length;
    final rate = sentCount > 0 ? (acceptedCount / sentCount * 100) : 0.0;

    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales Funnel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...stages.map((stage) {
              final count = quotations.where((q) => q.status == stage).length;
              final value = quotations.where((q) => q.status == stage).fold(0.0, (a, q) => a + (q.total as num).toDouble());
              final pct = maxValue > 0 ? value / maxValue : 0.0;
              return _buildPipelineItem(stage, '$count quotes', currency.format(value), pct);
            }),
            const Spacer(),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Conversion Rate', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${rate.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: rate > 50 ? Colors.green : Colors.orange)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineItem(String stage, String count, String value, double percent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(stage, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: percent.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.black12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF4781F)),
                  ),
                ),
                const SizedBox(height: 3),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(count, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(value, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── LTV Tab ───────────────────────────────────────────────────────────────
  Widget _buildLtvTab(BuildContext context, List<dynamic> customers, List<dynamic> allInvoices, bool isDark, NumberFormat currency) {
    // Compute per-customer revenue from all paid invoices
    final revenueByCustomer = <String, double>{};
    for (final inv in allInvoices.where((i) => i.status == 'Paid')) {
      revenueByCustomer[inv.customerId ?? inv.customerName] =
          (revenueByCustomer[inv.customerId ?? inv.customerName] ?? 0) + (inv.total as num).toDouble();
    }
    final values = revenueByCustomer.values.toList()..sort((a, b) => b.compareTo(a));
    final high   = values.where((v) => v >= 5000).length;
    final mid    = values.where((v) => v >= 1000 && v < 5000).length;
    final low    = values.where((v) => v > 0 && v < 1000).length;
    final zero   = customers.length - revenueByCustomer.length;

    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Client Segments by LTV', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _buildLtvRow('High-Value (£5k+)', '$high clients', currency.format(values.where((v) => v >= 5000).fold(0.0, (a, b) => a + b)), Colors.orange),
            _buildLtvRow('Mid-Value (£1k–5k)', '$mid clients', currency.format(values.where((v) => v >= 1000 && v < 5000).fold(0.0, (a, b) => a + b)), Colors.blue),
            _buildLtvRow('Low-Value (<£1k)', '$low clients', currency.format(values.where((v) => v > 0 && v < 1000).fold(0.0, (a, b) => a + b)), Colors.grey),
            _buildLtvRow('No Revenue Yet', '${zero > 0 ? zero : 0} clients', '£0', Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildLtvRow(String name, String count, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(count, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  // ── Insights Tab ──────────────────────────────────────────────────────────
  Widget _buildInsightsTab(BuildContext context, List<dynamic> quotations, List<dynamic> invoices, SemanticColors colors, bool isDark) {
    final total = quotations.length;
    final amended = quotations.where((q) => q.status == 'Amended').length;
    final amendRate = total > 0 ? (amended / total * 100) : 0.0;
    final accepted = quotations.where((q) => q.status == 'Accepted').length;
    final sent = quotations.where((q) => q.status == 'Sent' || q.status == 'Accepted' || q.status == 'Declined').length;
    final conv = sent > 0 ? (accepted / sent * 100) : 0.0;
    final overdue = invoices.where((i) => i.status == 'Overdue').length;
    final avgVal = total > 0 ? quotations.fold(0.0, (s, q) => s + (q.total as num).toDouble()) / total : 0.0;
    final currency = NumberFormat.currency(symbol: '£', decimalDigits: 0);

    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Performance Insights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _buildInsightListItem('Amendment rate: ${amendRate.toStringAsFixed(1)}% of ${total} quotes'),
            _buildInsightListItem('Quote conversion: ${conv.toStringAsFixed(1)}% (${accepted} accepted / ${sent} sent)'),
            _buildInsightListItem('Avg. quotation value: ${currency.format(avgVal)}'),
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

  Widget _emptyCard(String message, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      )),
    );
  }
}
