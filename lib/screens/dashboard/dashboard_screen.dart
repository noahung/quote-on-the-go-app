import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/providers.dart';
import '../../providers/drawer_controller_provider.dart';
import '../../theme/semantic_colors.dart';
import '../../components/mesh_background.dart';
import '../../models/models.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;

    final totalRevenue = ref.watch(totalRevenueProvider);
    final outstandingRevenue = ref.watch(outstandingRevenueProvider);
    final overdueInvoicesCount = ref.watch(overdueInvoicesCountProvider);
    final pendingQuotationsCount = ref.watch(pendingQuotationsCountProvider);
    final acceptedQuotationsCount = ref.watch(acceptedQuotationsCountProvider);
    final recentQuotations = ref.watch(quotationsProvider).take(3).toList();
    final recentInvoices = ref.watch(invoicesProvider).take(3).toList();

    final allInvoices = ref.watch(invoicesProvider);
    final paidCount = allInvoices.where((i) => i.status == 'Paid').length;
    final unpaidCount = allInvoices.where((i) => i.status == 'Sent').length;
    final draftCount = allInvoices.where((i) => i.status == 'Draft').length;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(quotationsStreamProvider);
              ref.invalidate(invoicesStreamProvider);
            },
            child: CustomScrollView(
              slivers: [
                // ── App Bar ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(LucideIcons.menu),
                            onPressed: () => openDrawer(ref),
                          ),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Quote On The Go',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(LucideIcons.bell),
                            onPressed: () => context.push('/notifications'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── Stat Summary Card ────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _StatSummaryCard(
                      totalRevenue: totalRevenue,
                      outstandingRevenue: outstandingRevenue,
                      paidCount: paidCount,
                      unpaidCount: unpaidCount,
                      overdueCount: overdueInvoicesCount,
                      draftCount: draftCount,
                      onTap: () => context.push('/invoices'),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── Quick KPI chips ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _KpiChip(
                            label: 'Pending Quotes',
                            value: pendingQuotationsCount.toString(),
                            onTap: () => context.push('/quotations'),
                            isOrange: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KpiChip(
                            label: 'Accepted Quotes',
                            value: acceptedQuotationsCount.toString(),
                            onTap: () => context.push('/quotations?tab=accepted'),
                            isOrange: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Charts ───────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _MonthlyRevenueChart(
                      invoices: ref.watch(invoicesProvider),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _QuoteActivityChart(
                      quotations: ref.watch(quotationsProvider),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 28)),

                // ── Recent Invoices section ──────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionHeader(
                      title: 'Recent Invoices',
                      actionLabel: 'See All',
                      onAction: () => context.push('/invoices'),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                if (recentInvoices.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildEmptyCard('No invoices yet'),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final inv = recentInvoices[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                          child: _InvoiceCardRow(
                            invoice: inv,
                            semanticColors: semanticColors,
                            onTap: () => context.push('/invoices/${inv.id}'),
                          ),
                        );
                      },
                      childCount: recentInvoices.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── Recent Quotations section ────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionHeader(
                      title: 'Recent Quotations',
                      actionLabel: 'See All',
                      onAction: () => context.push('/quotations'),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                if (recentQuotations.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildEmptyCard('No quotations yet'),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final q = recentQuotations[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                          child: _QuoteCardRow(
                            quotation: q,
                            semanticColors: semanticColors,
                            onTap: () => context.push('/quotations/${q.id}'),
                          ),
                        );
                      },
                      childCount: recentQuotations.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── Status Overview ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionHeader(title: 'Status Overview'),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _StatusOverviewCard(semanticColors: semanticColors),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── CTA Card ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _FeaturedCtaCard(
                      title: 'Create a New Quotation',
                      subtitle: 'Generate a professional quote for your next job in seconds.',
                      onTap: () => context.push('/quotations/new'),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Summary Card  (minimal, adaptive, no icons)
// ─────────────────────────────────────────────────────────────────────────────
class _StatSummaryCard extends StatelessWidget {
  final double totalRevenue;
  final double outstandingRevenue;
  final int paidCount;
  final int unpaidCount;
  final int overdueCount;
  final int draftCount;
  final VoidCallback onTap;

  const _StatSummaryCard({
    required this.totalRevenue,
    required this.outstandingRevenue,
    required this.paidCount,
    required this.unpaidCount,
    required this.overdueCount,
    required this.draftCount,
    required this.onTap,
  });

  String _fmt(double v) => NumberFormat.currency(symbol: '£', decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06);
    final subtleText = isDark ? Colors.white38 : Colors.black38;
    final bodyText = isDark ? Colors.white70 : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Revenue + label row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmt(totalRevenue),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total collected',
                      style: TextStyle(fontSize: 12, color: subtleText),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _fmt(outstandingRevenue),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF4781F),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Outstanding',
                      style: TextStyle(fontSize: 11, color: subtleText),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 18),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 16),

            // 4-counter row
            Row(
              children: [
                _StatCell(value: paidCount.toString(), label: 'Paid', valueColor: isDark ? Colors.white : Colors.black87, labelColor: bodyText),
                _StatDivider(color: borderColor),
                _StatCell(value: unpaidCount.toString(), label: 'Unpaid', valueColor: isDark ? Colors.white : Colors.black87, labelColor: bodyText),
                _StatDivider(color: borderColor),
                _StatCell(value: overdueCount.toString(), label: 'Overdue', valueColor: const Color(0xFFFF3B30), labelColor: bodyText),
                _StatDivider(color: borderColor),
                _StatCell(value: draftCount.toString(), label: 'Draft', valueColor: isDark ? Colors.white : Colors.black87, labelColor: bodyText),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  final Color labelColor;

  const _StatCell({required this.value, required this.label, required this.valueColor, required this.labelColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: valueColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: labelColor),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  final Color color;
  const _StatDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: color);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Monthly Revenue Bar Chart  (last 6 months of paid invoices)
// ─────────────────────────────────────────────────────────────────────────────
class _MonthlyRevenueChart extends StatelessWidget {
  final List<Invoice> invoices;

  const _MonthlyRevenueChart({required this.invoices});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06);
    final subtleText = isDark ? Colors.white38 : Colors.black38;
    final now = DateTime.now();

    // Build last-6-months buckets
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - 5 + i, 1);
      return d;
    });

    final data = months.map((m) {
      final total = invoices
          .where((inv) =>
              inv.status == 'Paid' &&
              inv.createdAt != null &&
              inv.createdAt!.year == m.year &&
              inv.createdAt!.month == m.month)
          .fold(0.0, (acc, inv) => acc + inv.total);
      return total;
    }).toList();

    final maxY = data.reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxY < 1 ? 1000.0 : maxY * 1.25;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Revenue',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last 6 months · paid invoices',
            style: TextStyle(fontSize: 11, color: subtleText),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                maxY: effectiveMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: effectiveMax / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('MMM').format(months[idx]),
                            style: TextStyle(fontSize: 10, color: subtleText, fontWeight: FontWeight.w500),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(6, (i) {
                  final isLast = i == 5;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: data[i],
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        color: isLast
                            ? const Color(0xFFF4781F)
                            : (isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.12)),
                      ),
                    ],
                  );
                }),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        NumberFormat.currency(symbol: '£', decimalDigits: 0).format(rod.toY),
                        TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quote Activity Line Chart  (sent vs accepted, last 6 months)
// ─────────────────────────────────────────────────────────────────────────────
class _QuoteActivityChart extends StatelessWidget {
  final List<Quotation> quotations;

  const _QuoteActivityChart({required this.quotations});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06);
    final subtleText = isDark ? Colors.white38 : Colors.black38;
    final now = DateTime.now();

    final months = List.generate(6, (i) => DateTime(now.year, now.month - 5 + i, 1));

    List<FlSpot> buildSpots(String status) {
      return List.generate(6, (i) {
        final m = months[i];
        final count = quotations
            .where((q) =>
                q.status == status &&
                q.createdAt != null &&
                q.createdAt!.year == m.year &&
                q.createdAt!.month == m.month)
            .length
            .toDouble();
        return FlSpot(i.toDouble(), count);
      });
    }

    final sentSpots = buildSpots('Sent');
    final acceptedSpots = buildSpots('Accepted');
    final allY = [...sentSpots, ...acceptedSpots].map((s) => s.y).toList();
    final maxY = allY.isEmpty ? 1.0 : allY.reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxY < 1 ? 4.0 : maxY * 1.4;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quote Activity',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last 6 months',
                    style: TextStyle(fontSize: 11, color: subtleText),
                  ),
                ],
              ),
              const Spacer(),
              // Legend
              Row(
                children: [
                  _ChartLegendDot(color: isDark ? Colors.white54 : Colors.black38),
                  const SizedBox(width: 4),
                  Text('Sent', style: TextStyle(fontSize: 10, color: subtleText)),
                  const SizedBox(width: 10),
                  const _ChartLegendDot(color: Color(0xFFF4781F)),
                  const SizedBox(width: 4),
                  Text('Accepted', style: TextStyle(fontSize: 10, color: subtleText)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                maxY: effectiveMax,
                minY: 0,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: effectiveMax / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('MMM').format(months[idx]),
                            style: TextStyle(fontSize: 10, color: subtleText, fontWeight: FontWeight.w500),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: sentSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: isDark ? Colors.white38 : Colors.black26,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: acceptedSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFFF4781F),
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 3,
                        color: const Color(0xFFF4781F),
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFF4781F).withValues(alpha: 0.06),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    getTooltipItems: (spots) => spots.map((s) {
                      return LineTooltipItem(
                        s.y.toInt().toString(),
                        TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: s.bar.color,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  const _ChartLegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI Chip (compact split cards)
// ─────────────────────────────────────────────────────────────────────────────
class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isOrange;

  const _KpiChip({
    required this.label,
    required this.value,
    required this.onTap,
    required this.isOrange,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isOrange
              ? const Color(0xFFF4781F)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: isOrange
              ? null
              : Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isOrange ? Colors.white : (isDark ? Colors.white : Colors.black87),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isOrange ? Colors.white70 : (isDark ? Colors.white54 : Colors.black54),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF4781F),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: Color(0xFFF4781F),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invoice Card Row  (rich: avatar initials + name/email + badge + amount/no/date)
// ─────────────────────────────────────────────────────────────────────────────
class _InvoiceCardRow extends StatelessWidget {
  final Invoice invoice;
  final SemanticColors semanticColors;
  final VoidCallback onTap;

  const _InvoiceCardRow({
    required this.invoice,
    required this.semanticColors,
    required this.onTap,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':
        return semanticColors.success;
      case 'Sent':
        return semanticColors.info;
      case 'Overdue':
        return semanticColors.error;
      case 'Draft':
        return semanticColors.warning;
      default:
        return semanticColors.accentBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor(invoice.status);
    final dateStr = invoice.dueDate.isNotEmpty
        ? DateFormat('d MMM yyyy').format(DateTime.tryParse(invoice.dueDate) ?? DateTime.now())
        : '—';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: name/email + status badge
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.customerName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          invoice.customerEmail,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(label: invoice.status, color: statusColor),
                ],
              ),

              const SizedBox(height: 12),
              Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
              const SizedBox(height: 12),

              // Bottom row: amount + number + date
              Row(
                children: [
                  _MetaCell(
                    label: 'Amount',
                    value: NumberFormat.currency(symbol: '£', decimalDigits: 0).format(invoice.total),
                    valueStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  _MetaCell(
                    label: 'No.',
                    value: '#${invoice.invoiceNumber}',
                    valueStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  _MetaCell(
                    label: 'Due',
                    value: dateStr,
                    valueStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    isLast: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quote Card Row  (rich: avatar initials + name + badge + amount/no/date)
// ─────────────────────────────────────────────────────────────────────────────
class _QuoteCardRow extends StatelessWidget {
  final Quotation quotation;
  final SemanticColors semanticColors;
  final VoidCallback onTap;

  const _QuoteCardRow({
    required this.quotation,
    required this.semanticColors,
    required this.onTap,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'Accepted':
        return semanticColors.success;
      case 'Sent':
        return semanticColors.info;
      case 'Declined':
        return semanticColors.error;
      case 'Draft':
        return semanticColors.warning;
      default:
        return semanticColors.accentPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor(quotation.status);
    final dateStr = quotation.date.isNotEmpty
        ? DateFormat('d MMM yyyy').format(DateTime.tryParse(quotation.date) ?? DateTime.now())
        : '—';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: name/email + status badge
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quotation.customerName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          quotation.customerEmail,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(label: quotation.status, color: statusColor),
                ],
              ),

              const SizedBox(height: 12),
              Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
              const SizedBox(height: 12),

              // Bottom row: amount + number + date
              Row(
                children: [
                  _MetaCell(
                    label: 'Amount',
                    value: NumberFormat.currency(symbol: '£', decimalDigits: 0).format(quotation.total),
                    valueStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  _MetaCell(
                    label: 'No.',
                    value: '#${quotation.quotationNumber}',
                    valueStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  _MetaCell(
                    label: 'Date',
                    value: dateStr,
                    valueStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    isLast: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle valueStyle;
  final bool isLast;

  const _MetaCell({
    required this.label,
    required this.value,
    required this.valueStyle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        crossAxisAlignment: isLast ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Overview Card
// ─────────────────────────────────────────────────────────────────────────────
class _StatusOverviewCard extends ConsumerWidget {
  final SemanticColors semanticColors;

  const _StatusOverviewCard({required this.semanticColors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overdueInvoicesCount = ref.watch(overdueInvoicesCountProvider);
    final acceptedQuotationsCount = ref.watch(acceptedQuotationsCountProvider);
    final pendingQuotationsCount = ref.watch(pendingQuotationsCountProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          _StatusListRow(
            label: 'Overdue Invoices',
            value: overdueInvoicesCount.toString(),
            color: semanticColors.error,
            icon: LucideIcons.triangleAlert,
            showDivider: true,
            onTap: () => GoRouter.of(context).push('/invoices?tab=overdue'),
          ),
          _StatusListRow(
            label: 'Accepted Quotes',
            value: acceptedQuotationsCount.toString(),
            color: semanticColors.success,
            icon: LucideIcons.checkCircle,
            showDivider: true,
            onTap: () => GoRouter.of(context).push('/quotations?tab=accepted'),
          ),
          _StatusListRow(
            label: 'Pending Quotes',
            value: pendingQuotationsCount.toString(),
            color: semanticColors.warning,
            icon: LucideIcons.clock,
            showDivider: false,
            onTap: () => GoRouter.of(context).push('/quotations?tab=sent'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status List Row
// ─────────────────────────────────────────────────────────────────────────────
class _StatusListRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool showDivider;
  final VoidCallback? onTap;

  const _StatusListRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.showDivider,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 66,
            endIndent: 16,
            color: isDark ? Colors.white10 : Colors.black12,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Featured CTA Card
// ─────────────────────────────────────────────────────────────────────────────
class _FeaturedCtaCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeaturedCtaCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF4781F).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.plusCircle,
              color: Color(0xFFF4781F),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF4781F),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('New Quote', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
