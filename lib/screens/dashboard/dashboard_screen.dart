import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../theme/semantic_colors.dart';
import '../../components/glass_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _formatCurrency(double value) {
    return NumberFormat.currency(symbol: '£', decimalDigits: 2).format(value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    
    final totalRevenue = ref.watch(totalRevenueProvider);
    final outstandingRevenue = ref.watch(outstandingRevenueProvider);
    final activeInvoicesCount = ref.watch(activeInvoicesCountProvider);
    final overdueInvoicesCount = ref.watch(overdueInvoicesCountProvider);
    final pendingQuotationsCount = ref.watch(pendingQuotationsCountProvider);
    final acceptedQuotationsCount = ref.watch(acceptedQuotationsCountProvider);

    return Scaffold(
      backgroundColor: Colors.transparent, // Transparent to let the mesh background shine through
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(quotationsStreamProvider);
          ref.invalidate(invoicesStreamProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              Text(
                'Welcome back!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Here\'s an overview of your business',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 24),

              // KPI Cards Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  _KpiCard(
                    title: 'Total Revenue',
                    value: _formatCurrency(totalRevenue),
                    icon: Icons.paid,
                    color: semanticColors.accentPrimary,
                    subtitle: 'All time paid',
                  ),
                  _KpiCard(
                    title: 'Outstanding',
                    value: _formatCurrency(outstandingRevenue),
                    icon: Icons.pending_actions,
                    color: semanticColors.accentOrange,
                    subtitle: 'Unpaid invoices',
                  ),
                  _KpiCard(
                    title: 'Active Invoices',
                    value: activeInvoicesCount.toString(),
                    icon: Icons.receipt_long,
                    color: semanticColors.accentBlue,
                    subtitle: 'Sent/Overdue',
                  ),
                  _KpiCard(
                    title: 'Pending Quotes',
                    value: pendingQuotationsCount.toString(),
                    icon: Icons.description,
                    color: semanticColors.accentPurple,
                    subtitle: 'Draft/Sent',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),


              Column(
                children: [
                  // Row 1: Create Quotation & Create Invoice
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _BentoActionCard(
                          title: 'Create Quotation',
                          subtitle: 'New quote for customer pricing',
                          icon: Icons.add_circle_outline,
                          color: semanticColors.accentPrimary,
                          actionText: 'NEW QUOTE',
                          onTap: () => context.push('/quotations/new'),
                          height: 160,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BentoActionCard(
                          title: 'Create Invoice',
                          subtitle: 'Generate invoice from quote',
                          icon: Icons.receipt,
                          color: semanticColors.accentGreen,
                          actionText: 'GENERATE',
                          onTap: () => context.push('/invoices/new'),
                          height: 160,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 2: Add Customer & Expenses
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _BentoActionCard(
                          title: 'Add Customer',
                          subtitle: 'Add a new client to database',
                          icon: Icons.person_add,
                          color: semanticColors.accentBlue,
                          actionText: 'ADD CLIENT',
                          onTap: () => context.push('/customers/new'),
                          height: 160,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BentoActionCard(
                          title: 'Expenses',
                          subtitle: 'Track spending and logs',
                          icon: Icons.receipt_long,
                          color: semanticColors.accentDeepOrange,
                          actionText: 'LOG COST',
                          onTap: () => context.push('/expenses'),
                          height: 160,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 3: Services & Schedule
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _BentoActionCard(
                          title: 'Services',
                          subtitle: 'Manage items catalog',
                          icon: Icons.construction,
                          color: semanticColors.accentTeal,
                          actionText: 'MANAGE',
                          onTap: () => context.push('/services'),
                          height: 160,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BentoActionCard(
                          title: 'Schedule',
                          subtitle: 'View calendar schedules',
                          icon: Icons.calendar_month,
                          color: semanticColors.accentIndigo,
                          actionText: 'VIEW CALENDAR',
                          onTap: () => context.push('/schedule'),
                          height: 160,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 4: Workflows & Branding
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _BentoActionCard(
                          title: 'Workflows',
                          subtitle: 'Automation tasks active',
                          icon: Icons.auto_fix_high,
                          color: semanticColors.accentPurple,
                          actionText: 'RUN',
                          onTap: () => context.push('/workflows'),
                          height: 160,
                          hasStatusDot: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BentoActionCard(
                          title: 'Branding',
                          subtitle: 'Customize company assets',
                          icon: Icons.palette,
                          color: semanticColors.accentOrange,
                          actionText: 'BRANDING',
                          onTap: () => context.push('/company-branding'),
                          height: 160,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Activity Summary
              const Text(
                'Status Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Column(
                    children: [
                      _StatusRow(
                        label: 'Overdue Invoices',
                        value: overdueInvoicesCount.toString(),
                        color: semanticColors.error,
                      ),
                      const Divider(),
                      _StatusRow(
                        label: 'Accepted Quotations',
                        value: acceptedQuotationsCount.toString(),
                        color: semanticColors.success,
                      ),
                      const Divider(),
                      _StatusRow(
                        label: 'Active Quotes',
                        value: pendingQuotationsCount.toString(),
                        color: semanticColors.warning,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}


class _BentoActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String actionText;
  final VoidCallback onTap;
  final double height;
  final bool hasStatusDot;

  const _BentoActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.actionText,
    required this.onTap,
    required this.height,
    this.hasStatusDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (hasStatusDot)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  )
                else
                  Icon(
                    Icons.more_vert,
                    size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  actionText,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right,
                  size: 12,
                  color: color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatusRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
