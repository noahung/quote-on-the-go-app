import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/premium_empty_state.dart';

class QuotationsScreen extends ConsumerStatefulWidget {
  const QuotationsScreen({super.key});

  @override
  ConsumerState<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends ConsumerState<QuotationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_StatusTab> _tabs = const [
    _StatusTab(label: 'All', status: null),
    _StatusTab(label: 'Draft', status: 'Draft'),
    _StatusTab(label: 'Sent', status: 'Sent'),
    _StatusTab(label: 'Accepted', status: 'Accepted'),
    _StatusTab(label: 'Declined', status: 'Declined'),
    _StatusTab(label: 'Amended', status: 'Amended'),
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

  List<Quotation> _filterByStatus(List<Quotation> quotations, String? status) {
    if (status == null) return quotations;
    return quotations.where((q) => q.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final quotationsAsync = ref.watch(quotationsStreamProvider);
    final company = ref.watch(companyProvider);
    final isPremium = company?.tier == 'premium';
    final activeCount = quotationsAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Quotations',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/quotations/new'),
          ),
        ],
        bottom: quotationsAsync.when(
          loading: () => null,
          error: (_, __) => null,
          data: (quotations) => TabBar(
            controller: _tabController,
            isScrollable: true,
            labelStyle: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
            tabs: _tabs.map((tab) {
              final count = tab.status == null
                  ? quotations.length
                  : quotations.where((q) => q.status == tab.status).length;
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
      body: quotationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Failed to load quotations',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(quotationsStreamProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (quotations) {
          if (quotations.isEmpty) {
            return _EmptyState(
              isPremium: isPremium,
              currentCount: activeCount,
            );
          }
          return TabBarView(
            controller: _tabController,
            children: _tabs.map((tab) {
              final filtered = _filterByStatus(quotations, tab.status);
              return _QuotationList(
                quotations: filtered,
                emptyTitle: tab.status == null
                    ? 'No Quotations Yet'
                    : 'No ${tab.label} Quotations',
                emptySubtitle: tab.status == null
                    ? 'Create your first quotation to get started'
                    : 'Quotations with ${tab.label.toLowerCase()} status will appear here',
                onAddTap: () => context.push('/quotations/new'),
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
      icon: Icons.description_outlined,
      title: 'No Quotations Yet',
      subtitle: 'Create your first quotation to get started',
      actionLabel: 'Create Quotation',
      onAction: () => context.push('/quotations/new'),
      isPremium: isPremium,
      currentCount: currentCount,
      limit: 10,
      itemName: 'quotations',
      showUpgradeCta: !isPremium,
      onUpgrade: () => context.push('/settings'),
    );
  }
}

class _QuotationList extends StatelessWidget {
  final List<Quotation> quotations;
  final String emptyTitle;
  final String emptySubtitle;
  final VoidCallback onAddTap;
  final bool isPremium;
  final int currentCount;

  const _QuotationList({
    required this.quotations,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onAddTap,
    required this.isPremium,
    required this.currentCount,
  });

  @override
  Widget build(BuildContext context) {
    if (quotations.isEmpty) {
      return PremiumEmptyState(
        icon: Icons.description_outlined,
        title: emptyTitle,
        subtitle: emptySubtitle,
        actionLabel: 'Create Quotation',
        onAction: onAddTap,
        isPremium: isPremium,
        currentCount: currentCount,
        limit: 10,
        itemName: 'quotations',
        showUpgradeCta: !isPremium,
        onUpgrade: () => context.push('/settings'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: quotations.length,
      itemBuilder: (context, index) {
        final quotation = quotations[index];
        return _QuotationCard(quotation: quotation);
      },
    );
  }
}

class _QuotationCard extends StatelessWidget {
  final Quotation quotation;

  const _QuotationCard({required this.quotation});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Accepted':
        return Colors.green;
      case 'Sent':
        return Colors.blue;
      case 'Declined':
        return Colors.red;
      case 'Amended':
        return Colors.purple;
      case 'Draft':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/quotations/${quotation.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(quotation.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      quotation.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(quotation.status),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    NumberFormat.currency(symbol: '£').format(quotation.total),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                quotation.quotationNumber,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                quotation.customerName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                quotation.customerEmail,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${quotation.date}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
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
        color: color.withOpacity(0.15),
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
