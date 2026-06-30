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
import '../../utils/feedback_controller.dart';



class InvoicesScreen extends ConsumerStatefulWidget {
  final String? initialTab;

  const InvoicesScreen({super.key, this.initialTab});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _currentMainTab = 'invoices'; // 'invoices' | 'recurring'


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

  List<Invoice> _filterByStatus(List<Invoice> invoices, String? status) {
    var list = status == null ? invoices : invoices.where((i) => i.status == status).toList();
    if (_searchQuery.isNotEmpty) {
      list = list.where((i) =>
        i.customerName.toLowerCase().contains(_searchQuery) ||
        i.invoiceNumber.toLowerCase().contains(_searchQuery)
      ).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final invoicesAsync = ref.watch(invoicesStreamProvider);
    final recurringAsync = ref.watch(recurringInvoicesStreamProvider);
    final company = ref.watch(companyProvider);
    final isPremium = company?.tier == 'premium';
    final activeCount = invoicesAsync.valueOrNull
            ?.where((i) => i.status != 'Paid' && i.status != 'Void')
            .length ??
        0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent, // Let global mesh gradient flow underneath
      body: Column(
        children: [
          CurvedHeader(
            title: _currentMainTab == 'invoices' ? 'Invoices' : 'Recurring Invoices',
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.plus),
                onPressed: () {
                  if (_currentMainTab == 'invoices') {
                    context.push('/invoices/new');
                  } else {
                    context.push('/invoices/recurring/new');
                  }
                },
              ),
            ],
          ),

          // The modern, desaturated top-pill sub-tab bar toggle!
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _currentMainTab = 'invoices'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _currentMainTab == 'invoices'
                              ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Invoices',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _currentMainTab == 'invoices' ? FontWeight.w700 : FontWeight.w500,
                            color: _currentMainTab == 'invoices'
                                ? colorScheme.onSurface
                                : colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _currentMainTab = 'recurring'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _currentMainTab == 'recurring'
                              ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Recurring Invoices',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _currentMainTab == 'recurring' ? FontWeight.w700 : FontWeight.w500,
                            color: _currentMainTab == 'recurring'
                                ? colorScheme.onSurface
                                : colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _currentMainTab == 'invoices' ? 'Search invoices…' : 'Search setups…',
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

          if (_currentMainTab == 'invoices') ...[
            // Horizontal Tab Bar Filter List (Stitch style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: invoicesAsync.when(
                loading: () => const SizedBox(height: 48),
                error: (_, __) => const SizedBox(height: 48),
                data: (invoices) => Container(
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
                          ? invoices.length
                          : invoices.where((i) => i.status == tab.status).length;
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
              child: invoicesAsync.when(
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
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
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
                  if (invoices.isEmpty && _searchQuery.isEmpty) {
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
                        emptyTitle: _searchQuery.isNotEmpty
                            ? 'No results for "$_searchQuery"'
                            : tab.status == null
                                ? 'No Invoices Yet'
                                : 'No ${tab.label} Invoices',
                        emptySubtitle: _searchQuery.isNotEmpty
                            ? 'Try a different name or invoice number'
                            : tab.status == null
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
            ),
          ] else ...[
            // Recurring view content
            const SizedBox(height: 12),
            Expanded(
              child: recurringAsync.when(
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
                          'Failed to load recurring setups',
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
                          onPressed: () => ref.invalidate(recurringInvoicesStreamProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (setups) {
                  var filteredSetups = setups;
                  if (_searchQuery.isNotEmpty) {
                    filteredSetups = setups
                        .where((s) =>
                            s.customerName.toLowerCase().contains(_searchQuery))
                        .toList();
                  }

                  if (filteredSetups.isEmpty) {
                    return PremiumEmptyState(
                      icon: LucideIcons.receipt,
                      title: _searchQuery.isNotEmpty
                          ? 'No results for "$_searchQuery"'
                          : 'No Recurring Setups',
                      subtitle: _searchQuery.isNotEmpty
                          ? 'Try a different customer name'
                          : 'Create your first recurring invoice setup to get started',
                      actionLabel: 'Create Setup',
                      onAction: () => context.push('/invoices/recurring/new'),
                      isPremium: isPremium,
                      currentCount: setups.length,
                      limit: 5,
                      itemName: 'invoices',
                      showUpgradeCta: false,
                      onUpgrade: () => context.push('/settings'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 80),
                    itemCount: filteredSetups.length,
                    itemBuilder: (context, index) {
                      final setup = filteredSetups[index];
                      return _RecurringInvoiceCard(setup: setup);
                    },
                  );
                },
              ),
            ),
          ],
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
      icon: LucideIcons.receipt,
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
        icon: LucideIcons.receipt,
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
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 80),
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final statusColor = _getStatusColor(invoice.status, semanticColors);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final avatarColor = _getAvatarColor(invoice.customerName, isDark);
    final avatarTextColor = _getAvatarTextColor(invoice.customerName, isDark);
    final initials = invoice.customerName.isNotEmpty
        ? invoice.customerName.substring(0, 1).toUpperCase()
        : 'I';

    return InkWell(
      onTap: () => context.push('/invoices/${invoice.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
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
                    invoice.customerName,
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
                    '${invoice.invoiceNumber} • Due ${invoice.dueDate}',
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
                  NumberFormat.currency(symbol: '£').format(invoice.total),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: invoice.status == 'Overdue' ? semanticColors.error : colorScheme.onSurface,
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
                    invoice.status,
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

class _RecurringInvoiceCard extends ConsumerWidget {
  final RecurringInvoice setup;

  const _RecurringInvoiceCard({required this.setup});

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final avatarColor = _getAvatarColor(setup.customerName, isDark);
    final avatarTextColor = _getAvatarTextColor(setup.customerName, isDark);
    final initials = setup.customerName.isNotEmpty
        ? setup.customerName.substring(0, 1).toUpperCase()
        : 'R';

    final nextRun = DateTime.tryParse(setup.nextRunDate);
    final nextRunStr = nextRun != null ? DateFormat('MMM d, yyyy').format(nextRun) : setup.nextRunDate;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                  setup.customerName,
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
                  '${setup.frequency.toUpperCase()} • Next: $nextRunStr',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          
          // Switch Toggle
          Switch(
            value: setup.isActive,
            activeThumbColor: const Color(0xFFF4781F),
            onChanged: (val) async {
              try {
                await ref.read(recurringInvoiceRepositoryProvider)
                    .toggleRecurringInvoiceStatus(setup.id, val);
                if (!context.mounted) return;
                ref.read(feedbackControllerProvider).success(
                      context,
                      val ? 'Recurring billing enabled' : 'Recurring billing paused',
                    );
              } catch (e) {
                if (!context.mounted) return;
                ref.read(feedbackControllerProvider).error(context, 'Failed to update: $e');
              }
            },

          ),
          
          // Popup menu
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.ellipsisVertical, color: Colors.grey, size: 20),
            padding: EdgeInsets.zero,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Setup')),
              const PopupMenuItem(value: 'run', child: Text('Trigger Manual Run')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Setup', style: TextStyle(color: Colors.red)),
              ),
            ],
            onSelected: (val) async {
              if (val == 'edit') {
                context.push('/invoices/recurring/${setup.id}/edit', extra: setup);
              } else if (val == 'run') {
                _triggerRun(context, ref);
              } else if (val == 'delete') {
                _confirmDelete(context, ref);
              }
            },
          ),
        ],
      ),
    );
  }

  void _triggerRun(BuildContext context, WidgetRef ref) async {
    final userProfile = ref.read(userProfileProvider);
    if (userProfile == null) return;
    
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFF4781F))),
    );

    try {
      final generatedId = await ref.read(recurringInvoiceRepositoryProvider)
          .triggerManualRun(setup.id, userProfile.uid);
      
      if (!context.mounted) return;
      Navigator.pop(context); // close loader

      ref.read(feedbackControllerProvider).success(context, 'Invoice generated successfully');

      // Show success bottom sheet or dialog to view invoice
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Invoice Generated'),
          content: const Text('A new invoice has been successfully generated from this recurring setup.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF4781F)),
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/invoices/$generatedId');
              },
              child: const Text('View Invoice'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // close loader
      ref.read(feedbackControllerProvider).error(context, 'Failed to trigger manual run: $e');
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recurring Setup?'),
        content: const Text('Are you sure you want to delete this recurring invoice setup? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(recurringInvoiceRepositoryProvider).deleteRecurringInvoice(setup.id);
                if (!context.mounted) return;
                ref.read(feedbackControllerProvider).success(context, 'Recurring setup deleted');
              } catch (e) {
                if (!context.mounted) return;
                ref.read(feedbackControllerProvider).error(context, 'Failed to delete: $e');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

}
