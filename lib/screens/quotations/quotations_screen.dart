import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/premium_empty_state.dart';
import '../../theme/semantic_colors.dart';
import '../../components/curved_header.dart';

class QuotationsScreen extends ConsumerStatefulWidget {
  final String? initialTab;

  const QuotationsScreen({super.key, this.initialTab});

  @override
  ConsumerState<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends ConsumerState<QuotationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showStarredOnly = false;

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
    // Calculate initial tab index based on the initialTab parameter
    final initialTabLabel = (widget.initialTab ?? '').toLowerCase();
    int initialIndex = 0;
    for (int i = 0; i < _tabs.length; i++) {
      if (_tabs[i].label.toLowerCase() == initialTabLabel ||
          (_tabs[i].status?.toLowerCase() == initialTabLabel)) {
        initialIndex = i;
        break;
      }
    }
    _tabController = TabController(length: _tabs.length, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() => setState(() {}));
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Quotation> _filterByStatus(List<Quotation> quotations, String? status) {
    var list = status == null ? quotations : quotations.where((q) => q.status == status).toList();
    if (_showStarredOnly) {
      list = list.where((q) => q.isStarred).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((q) =>
        q.customerName.toLowerCase().contains(_searchQuery) ||
        q.quotationNumber.toLowerCase().contains(_searchQuery) ||
        (q.title ?? '').toLowerCase().contains(_searchQuery)
      ).toList();
    }
    return list;
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
                icon: Icon(
                  _showStarredOnly ? Icons.star : Icons.star_border,
                  color: _showStarredOnly ? Colors.amber : null,
                ),
                tooltip: 'Starred Only',
                onPressed: () => setState(() => _showStarredOnly = !_showStarredOnly),
              ),
              IconButton(
                icon: const Icon(LucideIcons.plus),
                onPressed: () => context.push('/quotations/new'),
              ),
            ],
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search quotations…',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
                prefixIcon: Icon(LucideIcons.search,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E24)
                    : const Color(0xFFF0F4F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
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
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: EdgeInsets.zero,
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
                              activeColor: Theme.of(context).colorScheme.primary,
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
                if (quotations.isEmpty && _searchQuery.isEmpty) {
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
                      emptyTitle: _searchQuery.isNotEmpty
                          ? 'No results for "$_searchQuery"'
                          : tab.status == null
                              ? 'No Quotations Yet'
                              : 'No ${tab.label} Quotations',
                      emptySubtitle: _searchQuery.isNotEmpty
                          ? 'Try a different name or reference number'
                          : tab.status == null
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
      icon: LucideIcons.fileText,
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
        icon: LucideIcons.fileText,
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

class _QuotationCard extends ConsumerWidget {
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

  Color _getAvatarColor(String name, bool isDark) {
    final int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    final List<Color> lightColors = [
      const Color(0xFFC2E7FF),
      const Color(0xFFC4EED0),
      const Color(0xFFFEEFC3),
      const Color(0xFFFAD2E1),
      const Color(0xFFE8EAED),
      const Color(0xFFD7C4F2),
    ];
    final List<Color> darkColors = [
      const Color(0xFF004A77),
      const Color(0xFF07522C),
      const Color(0xFF7A5C00),
      const Color(0xFF7D1B46),
      const Color(0xFF3C4043),
      const Color(0xFF532E7E),
    ];
    final list = isDark ? darkColors : lightColors;
    return list[hash % list.length];
  }

  Color _getAvatarTextColor(String name, bool isDark) {
    final int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    final List<Color> lightTextColors = [
      const Color(0xFF001D35),
      const Color(0xFF072711),
      const Color(0xFF553D00),
      const Color(0xFF4B0024),
      const Color(0xFF202124),
      const Color(0xFF2C0A5E),
    ];
    final List<Color> darkTextColors = [
      const Color(0xFFC2E7FF),
      const Color(0xFFC4EED0),
      const Color(0xFFFEEFC3),
      const Color(0xFFFAD2E1),
      const Color(0xFFE8EAED),
      const Color(0xFFD7C4F2),
    ];
    final list = isDark ? darkTextColors : lightTextColors;
    return list[hash % list.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final statusColor = _getStatusColor(quotation.status, semanticColors);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final avatarColor = _getAvatarColor(quotation.customerName, isDark);
    final avatarTextColor = _getAvatarTextColor(quotation.customerName, isDark);
    final initials = quotation.customerName.isNotEmpty
        ? quotation.customerName.substring(0, 1).toUpperCase()
        : 'Q';

    return InkWell(
      onTap: () => context.push('/quotations/${quotation.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () async {
                final companyId = ref.read(companyIdProvider);
                if (companyId != null) {
                  await ref
                      .read(quotationRepositoryProvider)
                      .updateQuotation(quotation.id, {'isStarred': !quotation.isStarred});
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(
                  quotation.isStarred ? Icons.star : Icons.star_border,
                  color: quotation.isStarred ? Colors.amber : Colors.grey.withValues(alpha: 0.4),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                  color: avatarTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quotation.customerName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    quotation.title != null && quotation.title!.isNotEmpty
                        ? '${quotation.quotationNumber} • ${quotation.title}'
                        : '${quotation.quotationNumber} • ${quotation.date}',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormat.currency(symbol: '£').format(quotation.total),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    quotation.status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color textColor;
    Color bgColor;

    if (isSelected) {
      if (isDark) {
        textColor = theme.colorScheme.onPrimary;
        bgColor = theme.colorScheme.onPrimary.withValues(alpha: 0.15);
      } else {
        textColor = Colors.white;
        bgColor = Colors.white.withValues(alpha: 0.25);
      }
    } else {
      textColor = activeColor;
      bgColor = activeColor.withValues(alpha: 0.1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
