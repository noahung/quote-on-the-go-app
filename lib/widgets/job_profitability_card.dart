import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../components/glass_card.dart';

class JobProfitabilityCard extends StatelessWidget {
  final CalendarEvent job;
  final String companyId;

  const JobProfitabilityCard({
    super.key,
    required this.job,
    required this.companyId,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('expenses')
          .where('companyId', isEqualTo: companyId)
          .where('jobId', isEqualTo: job.id)
          .snapshots(),
      builder: (context, expenseSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('quotations')
              .where('companyId', isEqualTo: companyId)
              .where('jobId', isEqualTo: job.id)
              .snapshots(),
          builder: (context, quoteSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('job_materials')
                  .where('companyId', isEqualTo: companyId)
                  .where('jobId', isEqualTo: job.id)
                  .snapshots(),
              builder: (context, matSnap) {
                // 1. Calculate Expenses Total
                double directExpenses = 0;
                if (expenseSnap.hasData) {
                  for (final doc in expenseSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    directExpenses += (data['amount'] as num?)?.toDouble() ?? 0;
                  }
                }

                // 2. Calculate Materials Cost Total
                double materialsCost = 0;
                if (matSnap.hasData) {
                  for (final doc in matSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final qty = (data['quantity'] as num?)?.toDouble() ?? 1;
                    final unitCost = (data['unitCost'] as num?)?.toDouble() ?? 0;
                    materialsCost += (qty * unitCost);
                  }
                }

                // 3. Calculate Quoted / Revenue Total
                double revenue = 0;
                if (quoteSnap.hasData && quoteSnap.data!.docs.isNotEmpty) {
                  for (final doc in quoteSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    revenue += (data['total'] as num?)?.toDouble() ?? 0;
                  }
                }

                final totalDirectCosts = directExpenses + materialsCost;
                final netProfit = revenue - totalDirectCosts;
                final margin = revenue > 0 ? (netProfit / revenue) * 100 : 0.0;
                final costBurnRatio = revenue > 0 ? (totalDirectCosts / revenue).clamp(0.0, 1.0) : 0.0;

                // Health indicators
                Color healthColor;
                String healthLabel;
                if (revenue == 0 && totalDirectCosts == 0) {
                  healthColor = colorScheme.onSurfaceVariant;
                  healthLabel = 'Pending Costs';
                } else if (margin >= 40) {
                  healthColor = const Color(0xFF10B981); // Emerald
                  healthLabel = 'Healthy Margin';
                } else if (margin >= 20) {
                  healthColor = const Color(0xFFF59E0B); // Amber
                  healthLabel = 'Moderate';
                } else {
                  healthColor = const Color(0xFFEF4444); // Rose
                  healthLabel = 'Low Margin / Loss';
                }

                return GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(LucideIcons.trendingUp, size: 16, color: colorScheme.primary),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Live Job Profitability',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: healthColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: healthColor.withValues(alpha: 0.3), width: 0.6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: healthColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  healthLabel,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: healthColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Metrics 3-Column Row
                      Row(
                        children: [
                          Expanded(
                            child: _MetricTile(
                              label: 'Quoted Revenue',
                              value: '£${revenue.toStringAsFixed(2)}',
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Container(width: 1, height: 28, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                          Expanded(
                            child: _MetricTile(
                              label: 'Direct Costs',
                              value: '£${totalDirectCosts.toStringAsFixed(2)}',
                              color: directExpenses > 0 ? Colors.redAccent : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Container(width: 1, height: 28, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                          Expanded(
                            child: _MetricTile(
                              label: 'Gross Margin',
                              value: '${margin.toStringAsFixed(1)}%',
                              color: healthColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Cost Burn Bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Budget Burn',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                revenue > 0
                                    ? '${(costBurnRatio * 100).toStringAsFixed(0)}% consumed'
                                    : 'No quote linked',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: revenue > 0 ? costBurnRatio : 0,
                              minHeight: 5,
                              backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                costBurnRatio > 0.8 ? const Color(0xFFEF4444) : colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 9.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
