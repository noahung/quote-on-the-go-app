import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../theme/semantic_colors.dart';
import '../../components/mesh_background.dart';
import '../../models/models.dart';

// Key to access the ShellScaffold drawer from dashboard
final dashboardDrawerKey = GlobalKey<ScaffoldState>();

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalRevenue = ref.watch(totalRevenueProvider);
    final outstandingRevenue = ref.watch(outstandingRevenueProvider);
    final activeInvoicesCount = ref.watch(activeInvoicesCountProvider);
    final overdueInvoicesCount = ref.watch(overdueInvoicesCountProvider);
    final pendingQuotationsCount = ref.watch(pendingQuotationsCountProvider);
    final acceptedQuotationsCount = ref.watch(acceptedQuotationsCountProvider);
    final recentQuotations = ref.watch(quotationsProvider).take(3).toList();
    final recentInvoices = ref.watch(invoicesProvider).take(2).toList();

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF6B00), Color(0xFFF4781F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    // Hamburger menu - opens drawer
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () {
                            // Open the drawer from the parent ShellScaffold
                            final scaffoldState = Scaffold.maybeOf(context);
                            scaffoldState?.openDrawer();
                          },
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Quote On The Go',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    // Notifications
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                          onPressed: () => context.push('/notifications'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(quotationsStreamProvider);
            ref.invalidate(invoicesStreamProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Hero Revenue Card
              _HeroRevenueCard(
                totalRevenue: totalRevenue,
                outstandingRevenue: outstandingRevenue,
                acceptedCount: acceptedQuotationsCount,
                semanticColors: semanticColors,
                onTap: () => context.push('/invoices'),
              ),
              const SizedBox(height: 14),

              // Two Split Metric Cards (Orange left, White right)
              Row(
                children: [
                  Expanded(
                    child: _KpiChip(
                      label: 'Pending Quotes',
                      value: pendingQuotationsCount.toString(),
                      icon: Icons.description_outlined,
                      color: semanticColors.accentPurple,
                      onTap: () => context.push('/quotations'),
                      isOrange: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KpiChip(
                      label: 'Active Invoices',
                      value: activeInvoicesCount.toString(),
                      icon: Icons.receipt_long_outlined,
                      color: semanticColors.accentBlue,
                      onTap: () => context.push('/invoices'),
                      isOrange: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Quotations
              _SectionHeader(
                title: 'Recent Quotations',
                actionLabel: 'See All',
                onAction: () => context.push('/quotations'),
              ),
              const SizedBox(height: 10),
              if (recentQuotations.isEmpty)
                _buildEmptyCard('No quotations yet')
              else
                ...recentQuotations.map((q) => _QuoteCardRow(
                      quotation: q,
                      semanticColors: semanticColors,
                      onTap: () => context.push('/quotations/${q.id}'),
                    )),
              const SizedBox(height: 24),

              // Recent Invoices
              _SectionHeader(
                title: 'Recent Invoices',
                actionLabel: 'See All',
                onAction: () => context.push('/invoices'),
              ),
              const SizedBox(height: 10),
              if (recentInvoices.isEmpty)
                _buildEmptyCard('No invoices yet')
              else
                ...recentInvoices.map((inv) => _InvoiceCardRow(
                      invoice: inv,
                      semanticColors: semanticColors,
                      onTap: () => context.push('/invoices/${inv.id}'),
                    )),
              const SizedBox(height: 24),

              // Status Overview
              _SectionHeader(title: 'Status Overview'),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      _StatusListRow(
                        label: 'Overdue Invoices',
                        value: overdueInvoicesCount.toString(),
                        color: semanticColors.error,
                        icon: Icons.warning_amber_rounded,
                        showDivider: true,
                      ),
                      _StatusListRow(
                        label: 'Accepted Quotes',
                        value: acceptedQuotationsCount.toString(),
                        color: semanticColors.success,
                        icon: Icons.check_circle_outline,
                        showDivider: true,
                      ),
                      _StatusListRow(
                        label: 'Pending Quotes',
                        value: pendingQuotationsCount.toString(),
                        color: semanticColors.warning,
                        icon: Icons.schedule_outlined,
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Featured CTA Card
              _FeaturedCtaCard(
                title: 'Create a New Quotation',
                subtitle: 'Generate a professional quote for your next job in seconds.',
                onTap: () => context.push('/quotations/new'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Revenue Card
// ─────────────────────────────────────────────────────────────────────────────
class _HeroRevenueCard extends StatelessWidget {
  final double totalRevenue;
  final double outstandingRevenue;
  final int acceptedCount;
  final SemanticColors semanticColors;
  final VoidCallback onTap;

  const _HeroRevenueCard({
    required this.totalRevenue,
    required this.outstandingRevenue,
    required this.acceptedCount,
    required this.semanticColors,
    required this.onTap,
  });

  String _fmt(double v) => NumberFormat.currency(symbol: '£', decimalDigits: 2).format(v);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 24,
                  spreadRadius: 2,
                )
              ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label + Status badge
            Row(
              children: [
                Text(
                  'Total Revenue',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00966C).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '$acceptedCount Accepted',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF00966C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _fmt(totalRevenue),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Invoiced & paid',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _HeroStat(
                    label: 'Outstanding',
                    value: _fmt(outstandingRevenue),
                    color: const Color(0xFFFF6B00),
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
                Expanded(
                  child: _HeroStat(
                    label: 'Response',
                    value: 'Tap to view',
                    color: const Color(0xFF1A73E8),
                    alignRight: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool alignRight;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.color,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
        left: alignRight ? 16 : 0,
        right: alignRight ? 0 : 16,
      ),
      child: Column(
        crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI Chip (compact split cards)
// ─────────────────────────────────────────────────────────────────────────────
class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isOrange;

  const _KpiChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.isOrange,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isOrange ? null : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          gradient: isOrange
              ? const LinearGradient(
                  colors: [Color(0xFFFF6B00), Color(0xFFF4781F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(24),
          border: isOrange
              ? null
              : Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          boxShadow: (isOrange || isDark)
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 24,
                    spreadRadius: 2,
                  )
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isOrange ? Colors.white24 : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isOrange ? Colors.white : color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isOrange ? Colors.white : (isDark ? Colors.white : Colors.black87),
                      letterSpacing: -0.5,
                    ),
                  ),
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
                  Icons.chevron_right,
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
// Individual Quote Card Row
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
    final color = _statusColor(quotation.status);

    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quotation.customerName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          quotation.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormat.currency(symbol: '£').format(quotation.total),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
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
// Individual Invoice Card Row
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
    final color = _statusColor(invoice.status);

    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.customerName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          invoice.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormat.currency(symbol: '£').format(invoice.total),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
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
// Status List Row
// ─────────────────────────────────────────────────────────────────────────────
class _StatusListRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool showDivider;

  const _StatusListRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Padding(
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
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ],
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

    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                Icons.add_circle_outline,
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
      ),
    );
  }
}
