import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../components/glass_card.dart';
import '../../models/models.dart';

class MonthlyRevenueChart extends StatelessWidget {
  final List<Invoice> invoices;

  const MonthlyRevenueChart({super.key, required this.invoices});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtleText = Theme.of(context).colorScheme.onSurfaceVariant;
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
              DateTime.tryParse(inv.date) != null &&
              DateTime.parse(inv.date).year == m.year &&
              DateTime.parse(inv.date).month == m.month)
          .fold(0.0, (acc, inv) => acc + inv.total);
      return total;
    }).toList();

    final maxY = data.reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxY < 1 ? 1000.0 : maxY * 1.25;

    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Revenue',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Paid invoices by invoice month',
            style: TextStyle(
                fontSize: 11, color: subtleText, fontWeight: FontWeight.w500),
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
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= months.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('MMM').format(months[idx]),
                            style: TextStyle(
                                fontSize: 10,
                                color: subtleText,
                                fontWeight: FontWeight.w600),
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
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        gradient: isLast
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFFF4781F), // Brand Orange
                                  Color(0xFFFF9E59), // Soft Coral
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              )
                            : null,
                        color: isLast
                            ? null
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.14)
                                : Colors.black.withValues(alpha: 0.08)),
                      ),
                    ],
                  );
                }),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        NumberFormat.currency(symbol: '£', decimalDigits: 0)
                            .format(rod.toY),
                        TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
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
class QuoteActivityChart extends StatelessWidget {
  final List<Quotation> quotations;

  const QuoteActivityChart({super.key, required this.quotations});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtleText = Theme.of(context).colorScheme.onSurfaceVariant;
    final now = DateTime.now();

    final months =
        List.generate(6, (i) => DateTime(now.year, now.month - 5 + i, 1));

    List<FlSpot> buildSpots(String status) {
      return List.generate(6, (i) {
        final m = months[i];
        final count = quotations
            .where((q) =>
                q.status == status &&
                DateTime.tryParse(q.date) != null &&
                DateTime.parse(q.date).year == m.year &&
                DateTime.parse(q.date).month == m.month)
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

    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
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
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last 6 months',
                    style: TextStyle(
                        fontSize: 11,
                        color: subtleText,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const Spacer(),
              // Legend
              Row(
                children: [
                  _ChartLegendDot(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.24)
                          : Colors.black.withValues(alpha: 0.14)),
                  const SizedBox(width: 4),
                  Text('Sent',
                      style: TextStyle(
                          fontSize: 10,
                          color: subtleText,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 12),
                  const _ChartLegendDot(color: Color(0xFFF4781F)),
                  const SizedBox(width: 4),
                  Text('Accepted',
                      style: TextStyle(
                          fontSize: 10,
                          color: subtleText,
                          fontWeight: FontWeight.w500)),
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
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= months.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('MMM').format(months[idx]),
                            style: TextStyle(
                                fontSize: 10,
                                color: subtleText,
                                fontWeight: FontWeight.w600),
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
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.24)
                        : Colors.black.withValues(alpha: 0.14),
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: acceptedSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFF4781F),
                        Color(0xFFFF8A47),
                      ],
                    ),
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color: const Color(0xFFF4781F),
                        strokeWidth: 1.2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF4781F).withValues(alpha: 0.12),
                          const Color(0xFFF4781F).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    getTooltipItems: (spots) => spots.map((s) {
                      return LineTooltipItem(
                        s.y.toInt().toString(),
                        TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: s.bar.color ??
                              s.bar.gradient?.colors.first ??
                              Colors.orange,
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
