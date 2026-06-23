import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../components/curved_header.dart';

// ─── Sort options ──────────────────────────────────────────────
enum _SortBy { name, revenue, lastActivity }

// ─── CRM status derived from invoice data ─────────────────────
enum _CrmStatus { active, overdue, inactive }

_CrmStatus _deriveStatus(Customer c, List<dynamic> invoices) {
  final ci = invoices.where((i) =>
      i.customerEmail == c.email || i.customerName == c.name).toList();
  if (ci.any((i) => i.status == 'Overdue')) return _CrmStatus.overdue;
  if (ci.any((i) =>
      i.status == 'Paid' || i.status == 'Sent' || i.status == 'Pending')) {
    return _CrmStatus.active;
  }
  return _CrmStatus.inactive;
}

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _SortBy _sortBy = _SortBy.name;
  String? _selectedTag;

  static const _brandOrange = Color(0xFFF4781F);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Customer> _applyFiltersAndSort(
      List<Customer> all, List<dynamic> invoices) {
    var list = all.where((c) {
      final matchesSearch = _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery) ||
          c.email.toLowerCase().contains(_searchQuery) ||
          (c.phone ?? '').toLowerCase().contains(_searchQuery);
      final matchesTag =
          _selectedTag == null || c.tags.contains(_selectedTag);
      return matchesSearch && matchesTag;
    }).toList();

    switch (_sortBy) {
      case _SortBy.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _SortBy.revenue:
        list.sort((a, b) =>
            (b.totalSpent ?? 0.0).compareTo(a.totalSpent ?? 0.0));
        break;
      case _SortBy.lastActivity:
        list.sort((a, b) {
          final aT = a.lastSeenAt ?? '';
          final bT = b.lastSeenAt ?? '';
          return bT.compareTo(aT);
        });
        break;
    }
    return list;
  }

  Set<String> _allTags(List<Customer> customers) {
    final tags = <String>{};
    for (final c in customers) {
      tags.addAll(c.tags);
    }
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    final allCustomers = ref.watch(customersProvider);
    final invoices = ref.watch(invoicesProvider);
    final isLoading = ref.watch(customersStreamProvider).isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final customers = _applyFiltersAndSort(allCustomers, invoices);
    final allTags = _allTags(allCustomers);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          CurvedHeader(
            title: 'Customers',
            onMenuPressed: () => openDrawer(ref),
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () => context.push('/customers/new'),
              ),
            ],
          ),

          // Search + Sort row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search customers…',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(LucideIcons.search,
                          size: 20,
                          color: colorScheme.onSurface.withValues(alpha: 0.4)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
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
                const SizedBox(width: 8),
                _SortButton(
                  current: _sortBy,
                  onChanged: (v) => setState(() => _sortBy = v),
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Tag filter chips
          if (allTags.isNotEmpty)
            _TagFilterRow(
              tags: allTags,
              selected: _selectedTag,
              onSelected: (t) =>
                  setState(() => _selectedTag = _selectedTag == t ? null : t),
              brandColor: _brandOrange,
            ),

          // Summary strip
          if (!isLoading && allCustomers.isNotEmpty)
            _SummaryStrip(
              total: allCustomers.length,
              filtered: customers.length,
              invoices: invoices,
              customers: allCustomers,
            ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : customers.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(
                            left: 16, right: 16, top: 4, bottom: 80),
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final c = customers[index];
                          final status = _deriveStatus(c, invoices);
                          return _CustomerCard(
                            customer: c,
                            crmStatus: status,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Sort button ───────────────────────────────────────────────
class _SortButton extends StatelessWidget {
  final _SortBy current;
  final ValueChanged<_SortBy> onChanged;
  final bool isDark;

  const _SortButton(
      {required this.current,
      required this.onChanged,
      required this.isDark});

  String get _label {
    switch (current) {
      case _SortBy.name:
        return 'A–Z';
      case _SortBy.revenue:
        return '£';
      case _SortBy.lastActivity:
        return 'Recent';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortBy>(
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1E24)
              : const Color(0xFFF0F4F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.arrowUpDown,
                size: 15,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5)),
            const SizedBox(width: 6),
            Text(
              _label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: _SortBy.name, child: Text('Name (A–Z)')),
        const PopupMenuItem(
            value: _SortBy.revenue, child: Text('Revenue (High–Low)')),
        const PopupMenuItem(
            value: _SortBy.lastActivity, child: Text('Last Activity')),
      ],
    );
  }
}

// ─── Tag filter chips ─────────────────────────────────────────
class _TagFilterRow extends StatelessWidget {
  final Set<String> tags;
  final String? selected;
  final ValueChanged<String> onSelected;
  final Color brandColor;

  const _TagFilterRow(
      {required this.tags,
      required this.selected,
      required this.onSelected,
      required this.brandColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: tags.map((tag) {
          final isSelected = selected == tag;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(tag),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? brandColor
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.06)),
                  borderRadius: BorderRadius.circular(99),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08)),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Summary strip ────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final int total;
  final int filtered;
  final List<dynamic> invoices;
  final List<Customer> customers;

  const _SummaryStrip(
      {required this.total,
      required this.filtered,
      required this.invoices,
      required this.customers});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overdue = customers.where((c) {
      return invoices.any((i) =>
          (i.customerEmail == c.email || i.customerName == c.name) &&
          i.status == 'Overdue');
    }).length;

    final totalRevenue = customers.fold<double>(0.0, (sum, c) {
      return sum + (c.totalSpent ?? 0.0);
    });

    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06);
    final labelColor = isDark ? Colors.white38 : Colors.black38;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            _StatCell(
              value: filtered == total ? '$total' : '$filtered/$total',
              label: 'Total',
              valueColor: isDark ? Colors.white : Colors.black87,
              labelColor: labelColor,
            ),
            _StatDivider(color: borderColor),
            _StatCell(
              value: '$overdue',
              label: 'Overdue',
              valueColor: overdue > 0 ? const Color(0xFFFF3B30) : (isDark ? Colors.white : Colors.black87),
              labelColor: labelColor,
            ),
            _StatDivider(color: borderColor),
            _StatCell(
              value: NumberFormat.compactCurrency(symbol: '£').format(totalRevenue),
              label: 'Revenue',
              valueColor: isDark ? Colors.white : Colors.black87,
              labelColor: labelColor,
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

  const _StatCell({
    required this.value,
    required this.label,
    required this.valueColor,
    required this.labelColor,
  });

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
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: labelColor,
            ),
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

// ─── Empty state ──────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.users,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          Text(
            'No Customers Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first customer to get started',
            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

// ─── Customer card with swipe gestures ────────────────────────
class _CustomerCard extends ConsumerWidget {
  final Customer customer;
  final _CrmStatus crmStatus;

  const _CustomerCard(
      {required this.customer, required this.crmStatus});

  Color _statusColor(BuildContext context) {
    switch (crmStatus) {
      case _CrmStatus.active:
        return const Color(0xFF137333);
      case _CrmStatus.overdue:
        return const Color(0xFFC5221F);
      case _CrmStatus.inactive:
        return Colors.grey;
    }
  }

  String _statusLabel() {
    switch (crmStatus) {
      case _CrmStatus.active:
        return 'Active';
      case _CrmStatus.overdue:
        return 'Overdue';
      case _CrmStatus.inactive:
        return 'Inactive';
    }
  }

  Color _statusBg() {
    switch (crmStatus) {
      case _CrmStatus.active:
        return const Color(0xFFE6F4EA);
      case _CrmStatus.overdue:
        return const Color(0xFFFCE8E6);
      case _CrmStatus.inactive:
        return const Color(0xFFF5F5F5);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final avatarColor = _getAvatarColor(customer.name, isDark);
    final avatarTextColor = _getAvatarTextColor(customer.name, isDark);
    
    final initials = customer.name.trim().isEmpty
        ? '?'
        : customer.name.trim().split(' ').length > 1
            ? '${customer.name.trim().split(' ').first[0]}${customer.name.trim().split(' ').last[0]}'.toUpperCase()
            : customer.name.trim()[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Dismissible(
        key: ValueKey(customer.id),
        background: _SwipeBackground(
          alignment: Alignment.centerLeft,
          color: const Color(0xFF137333),
          icon: LucideIcons.phoneCall,
          label: 'Call',
        ),
        secondaryBackground: _SwipeBackground(
          alignment: Alignment.centerRight,
          color: const Color(0xFFF4781F),
          icon: LucideIcons.fileText,
          label: 'Quote',
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            // Call action
            final phone = customer.phone;
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(phone != null && phone.isNotEmpty
                      ? 'Calling ${customer.name} ($phone)…'
                      : 'No phone number for ${customer.name}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else {
            // New quote pre-filled with this customer
            if (context.mounted) {
              context.push('/quotations/new',
                  extra: {'prefilledCustomer': customer});
            }
          }
          return false; // never actually dismiss
        },
        child: InkWell(
          onTap: () => context.push('/customers/${customer.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                // Avatar
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: avatarTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Main info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              customer.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? _statusColor(context).withValues(alpha: 0.15)
                                  : _statusBg(),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              _statusLabel(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _statusColor(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        customer.email,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (customer.phone != null &&
                          customer.phone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          customer.phone!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                      // Tags row
                      if (customer.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          children: customer.tags
                              .take(3)
                              .map((tag) => _MiniTag(tag: tag, isDark: isDark))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Revenue + chevron
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (customer.totalSpent != null &&
                        customer.totalSpent! > 0)
                      Text(
                        NumberFormat.compactCurrency(symbol: '£')
                            .format(customer.totalSpent),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String tag;
  final bool isDark;
  const _MiniTag({required this.tag, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
