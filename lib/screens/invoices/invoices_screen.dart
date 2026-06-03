import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/premium_empty_state.dart';
import '../../theme/semantic_colors.dart';
import '../../components/glass_card.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_StatusTab> _tabs = const [
    _StatusTab(label: 'All', status: null),
    _StatusTab(label: 'Draft', status: 'Draft'),
    _StatusTab(label: 'Sent', status: 'Sent'),
    _StatusTab(label: 'Paid', status: 'Paid'),
    _StatusTab(label: 'Overdue', status: 'Overdue'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Invoice> _filterByStatus(List<Invoice> invoices, String? status) {
    if (status == null) return invoices;
    return invoices.where((i) => i.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final invoicesAsync = ref.watch(invoicesStreamProvider);
    final company = ref.watch(companyProvider);
    final isPremium = company?.tier == 'premium';
    final activeCount = invoicesAsync.valueOrNull
            ?.where((i) => i.status != 'Paid' && i.status != 'Void')
            .length ??
        0;

    return Scaffold(
      backgroundColor: Colors.transparent, // Let global mesh gradient flow underneath
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Invoices',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/invoices/new'),
          ),
        ],
        bottom: invoicesAsync.when(
          loading: () => null,
          error: (_, __) => null,
          data: (invoices) => TabBar(
            controller: _tabController,
            isScrollable: true,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: _tabs.map((tab) {
              final count = tab.status == null
                  ? invoices.length
                  : invoices.where((i) => i.status == tab.status).length;
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tab.label),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      _CountBadge(count: count, color: colorScheme.primary),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: semanticColors.error),
                const SizedBox(height: 16),
                const Text(
                  'Failed to load invoices',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(invoicesStreamProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (invoices) {
          if (invoices.isEmpty) {
            return _EmptyState(
              isPremium: isPremium,
              currentCount: activeCount,
            );
          }
          return TabBarView(
            controller: _tabController,
            children: _tabs.map((tab) {
              final filtered = _filterByStatus(invoices, tab.status);
              return _InvoiceList(
                invoices: filtered,
                emptyTitle: tab.status == null
                    ? 'No Invoices Yet'
                    : 'No ${tab.label} Invoices',
                emptySubtitle: tab.status == null
                    ? 'Create your first invoice to get started'
                    : 'Invoices with ${tab.label.toLowerCase()} status will appear here',
                onAddTap: () => context.push('/invoices/new'),
                isPremium: isPremium,
                currentCount: activeCount,
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _StatusTab {
  final String label;
  final String? status;

  const _StatusTab({required this.label, this.status});
}

class _EmptyState extends StatelessWidget {
  final bool isPremium;
  final int currentCount;

  const _EmptyState({
    required this.isPremium,
    required this.currentCount,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumEmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No Invoices Yet',
      subtitle: 'Create your first invoice to get started',
      actionLabel: 'Create Invoice',
      onAction: () => context.push('/invoices/new'),
      isPremium: isPremium,
      currentCount: currentCount,
      limit: 5,
      itemName: 'invoices',
      showUpgradeCta: !isPremium,
      onUpgrade: () => context.push('/settings'),
    );
  }
}

class _InvoiceList extends StatelessWidget {
  final List<Invoice> invoices;
  final String emptyTitle;
  final String emptySubtitle;
  final VoidCallback onAddTap;
  final bool isPremium;
  final int currentCount;

  const _InvoiceList({
    required this.invoices,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onAddTap,
    required this.isPremium,
    required this.currentCount,
  });

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return PremiumEmptyState(
        icon: Icons.receipt_long_outlined,
        title: emptyTitle,
        subtitle: emptySubtitle,
        actionLabel: 'Create Invoice',
        onAction: onAddTap,
        isPremium: isPremium,
        currentCount: currentCount,
        limit: 5,
        itemName: 'invoices',
        showUpgradeCta: !isPremium,
        onUpgrade: () => context.push('/settings'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        return _InvoiceCard(invoice: invoice);
      },
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;

  const _InvoiceCard({required this.invoice});

  Color _getStatusColor(String status, SemanticColors semanticColors) {
    switch (status) {
      case 'Paid':
        return semanticColors.success;
      case 'Sent':
        return semanticColors.info;
      case 'Overdue':
        return semanticColors.error;
      case 'Draft':
        return semanticColors.accentOrange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final statusColor = _getStatusColor(invoice.status, semanticColors);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: EdgeInsets.zero,
        onTap: () => context.push('/invoices/${invoice.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      invoice.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    NumberFormat.currency(symbol: '£').format(invoice.total),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                invoice.invoiceNumber,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                invoice.customerName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                invoice.customerEmail,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 13, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 6),
                  Text(
                    'Due: ${invoice.dueDate}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
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

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
