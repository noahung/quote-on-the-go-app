import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/premium_empty_state.dart';
import '../../theme/semantic_colors.dart';
import '../../components/glass_card.dart';
import '../../components/curved_header.dart';

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
    _tabController.addListener(() {
      setState(() {});
    });
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
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final quotationsAsync = ref.watch(quotationsStreamProvider);
    final company = ref.watch(companyProvider);
    final isPremium = company?.tier == 'premium';
    final activeCount = quotationsAsync.valueOrNull?.length ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent, // Let global mesh gradient flow underneath
      body: Column(
        children: [
          CurvedHeader(
            title: 'Quotations',
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () => context.push('/quotations/new'),
              ),
            ],
          ),
          
          // Horizontal Tab Bar Filter List (Stitch style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: quotationsAsync.when(
              loading: () => const SizedBox(height: 48),
              error: (_, __) => const SizedBox(height: 48),
              data: (quotations) => Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: EdgeInsets.zero,
                  dividerColor: Colors.transparent,
                  indicatorColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark ? Colors.white70 : Colors.black87,
                  indicator: BoxDecoration(
                    color: const Color(0xFFF4781F),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: _tabs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final tab = entry.value;
                    final isSelected = _tabController.index == index;
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
                            _CountBadge(
                              count: count,
                              isSelected: isSelected,
                              activeColor: const Color(0xFFF4781F),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Tab Bar View content
          Expanded(
            child: quotationsAsync.when(
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
                        'Failed to load quotations',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
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
          ),
        ],
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
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 80),
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

  Color _getStatusColor(String status, SemanticColors semanticColors) {
    switch (status) {
      case 'Accepted':
        return semanticColors.success;
      case 'Sent':
        return semanticColors.info;
      case 'Declined':
        return semanticColors.error;
      case 'Amended':
        return semanticColors.accentPurple;
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
    final statusColor = _getStatusColor(quotation.status, semanticColors);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Map status to appropriate Icon
    IconData statusIcon;
    switch (quotation.status) {
      case 'Accepted':
        statusIcon = Icons.description;
        break;
      case 'Sent':
        statusIcon = Icons.calendar_month;
        break;
      case 'Declined':
        statusIcon = Icons.cancel_outlined;
        break;
      case 'Draft':
        statusIcon = Icons.edit_document;
        break;
      default:
        statusIcon = Icons.description;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push('/quotations/${quotation.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular avatar icon container on the left
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF4781F).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusIcon,
                  color: const Color(0xFFF4781F),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Details in the middle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quotation.customerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      NumberFormat.currency(symbol: '£').format(quotation.total),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${quotation.quotationNumber} • ${quotation.date}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Status Badge on the right
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      quotation.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
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
  final bool isSelected;
  final Color activeColor;

  const _CountBadge({
    required this.count,
    required this.isSelected,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : activeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: activeColor,
        ),
      ),
    );
  }
}
