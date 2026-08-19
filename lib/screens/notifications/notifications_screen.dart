import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../components/mesh_background.dart';
import '../../components/glass_card.dart';

enum NotificationCategory {
  all,
  unread,
  quotes,
  invoices,
  jobs,
  expenses,
  system,
  archived,
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationCategory _selectedCategory = NotificationCategory.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, size: 20),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          title: Row(
            children: [
              Text(
                'Notifications',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              Consumer(builder: (context, ref, _) {
                final unread = ref.watch(unreadNotificationCountProvider);
                if (unread == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF47421), // Primary Orange
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unread new',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            Consumer(builder: (context, ref, _) {
              final unread = ref.watch(unreadNotificationCountProvider);
              final user = ref.watch(currentUserProvider);

              return PopupMenuButton<String>(
                icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (value) async {
                  if (user == null) return;
                  final repo = ref.read(notificationRepositoryProvider);
                  if (value == 'mark_all_read') {
                    await repo.markAllAsRead(user.uid);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Marked all as read')),
                      );
                    }
                  } else if (value == 'archive_all') {
                    await repo.archiveAll(user.uid);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All notifications archived')),
                      );
                    }
                  } else if (value == 'delete_all_archived') {
                    await repo.deleteAllArchived(user.uid);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Archived notifications cleared')),
                      );
                    }
                  }
                },
                itemBuilder: (context) => [
                  if (unread > 0)
                    const PopupMenuItem(
                      value: 'mark_all_read',
                      child: Row(
                        children: [
                          Icon(LucideIcons.checkCheck, size: 16),
                          SizedBox(width: 8),
                          Text('Mark all as read', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'archive_all',
                    child: Row(
                      children: [
                        Icon(LucideIcons.archive, size: 16),
                        SizedBox(width: 8),
                        Text('Archive all active', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  if (_selectedCategory == NotificationCategory.archived)
                    const PopupMenuItem(
                      value: 'delete_all_archived',
                      child: Row(
                        children: [
                          Icon(LucideIcons.trash2, size: 16, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Clear archived', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                        ],
                      ),
                    ),
                ],
              );
            }),
          ],
        ),
        body: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (allNotifications) {
            // Count badges
            final activeList = allNotifications.where((n) => !n.isArchived).toList();
            final unreadCount = activeList.where((n) => !n.isRead).length;
            final quotesCount = activeList.where((n) => n.type.startsWith('quotation')).length;
            final invoicesCount = activeList.where((n) => n.type.startsWith('invoice')).length;
            final jobsCount = activeList.where((n) => n.type.startsWith('job') || n.type == 'schedule').length;
            final expensesCount = activeList.where((n) => n.type.startsWith('expense')).length;
            final systemCount = activeList.where((n) => ['generic', 'workflow_triggered', 'comment_added', 'team'].contains(n.type)).length;
            final archivedCount = allNotifications.where((n) => n.isArchived).length;

            // Filter by category
            List<UserNotification> filtered = allNotifications.where((n) {
              if (_selectedCategory == NotificationCategory.archived) {
                if (!n.isArchived) return false;
              } else {
                if (n.isArchived) return false;
                switch (_selectedCategory) {
                  case NotificationCategory.unread:
                    if (n.isRead) return false;
                    break;
                  case NotificationCategory.quotes:
                    if (!n.type.startsWith('quotation')) return false;
                    break;
                  case NotificationCategory.invoices:
                    if (!n.type.startsWith('invoice')) return false;
                    break;
                  case NotificationCategory.jobs:
                    if (!n.type.startsWith('job') && n.type != 'schedule') return false;
                    break;
                  case NotificationCategory.expenses:
                    if (!n.type.startsWith('expense')) return false;
                    break;
                  case NotificationCategory.system:
                    if (!['generic', 'workflow_triggered', 'comment_added', 'team'].contains(n.type)) return false;
                    break;
                  case NotificationCategory.all:
                  default:
                    break;
                }
              }

              // Search filter
              if (_searchQuery.isNotEmpty) {
                final query = _searchQuery.toLowerCase();
                final titleMatch = n.title.toLowerCase().contains(query);
                final msgMatch = n.message.toLowerCase().contains(query);
                if (!titleMatch && !msgMatch) return false;
              }

              return true;
            }).toList();

            // Date Grouping
            final now = DateTime.now();
            final today = filtered.where((n) => now.difference(n.createdAt).inHours < 24).toList();
            final yesterday = filtered.where((n) {
              final hours = now.difference(n.createdAt).inHours;
              return hours >= 24 && hours < 48;
            }).toList();
            final thisWeek = filtered.where((n) {
              final hours = now.difference(n.createdAt).inHours;
              return hours >= 48 && hours < 168;
            }).toList();
            final older = filtered.where((n) => now.difference(n.createdAt).inHours >= 168).toList();

            return Column(
              children: [
                // Category Pills Bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      _CategoryChip(
                        label: 'All',
                        count: activeList.length,
                        isSelected: _selectedCategory == NotificationCategory.all,
                        onTap: () => setState(() => _selectedCategory = NotificationCategory.all),
                      ),
                      const SizedBox(width: 6),
                      _CategoryChip(
                        label: 'Unread',
                        count: unreadCount,
                        isSelected: _selectedCategory == NotificationCategory.unread,
                        onTap: () => setState(() => _selectedCategory = NotificationCategory.unread),
                      ),
                      const SizedBox(width: 6),
                      _CategoryChip(
                        label: 'Quotes',
                        count: quotesCount,
                        isSelected: _selectedCategory == NotificationCategory.quotes,
                        onTap: () => setState(() => _selectedCategory = NotificationCategory.quotes),
                      ),
                      const SizedBox(width: 6),
                      _CategoryChip(
                        label: 'Invoices',
                        count: invoicesCount,
                        isSelected: _selectedCategory == NotificationCategory.invoices,
                        onTap: () => setState(() => _selectedCategory = NotificationCategory.invoices),
                      ),
                      const SizedBox(width: 6),
                      _CategoryChip(
                        label: 'Jobs',
                        count: jobsCount,
                        isSelected: _selectedCategory == NotificationCategory.jobs,
                        onTap: () => setState(() => _selectedCategory = NotificationCategory.jobs),
                      ),
                      const SizedBox(width: 6),
                      _CategoryChip(
                        label: 'Expenses',
                        count: expensesCount,
                        isSelected: _selectedCategory == NotificationCategory.expenses,
                        onTap: () => setState(() => _selectedCategory = NotificationCategory.expenses),
                      ),
                      const SizedBox(width: 6),
                      _CategoryChip(
                        label: 'System',
                        count: systemCount,
                        isSelected: _selectedCategory == NotificationCategory.system,
                        onTap: () => setState(() => _selectedCategory = NotificationCategory.system),
                      ),
                      const SizedBox(width: 6),
                      _CategoryChip(
                        label: 'Archived',
                        count: archivedCount,
                        isSelected: _selectedCategory == NotificationCategory.archived,
                        onTap: () => setState(() => _selectedCategory = NotificationCategory.archived),
                      ),
                    ],
                  ),
                ),

                // Perfectly Padded Search Bar (Zero Overlap)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: textTheme.bodySmall?.copyWith(fontSize: 13),
                      textAlignVertical: TextAlignVertical.center,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: InputBorder.none,
                        hintText: 'Search notifications...',
                        hintStyle: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                        prefixIcon: Icon(
                          LucideIcons.search,
                          size: 15,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 38),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(LucideIcons.x, size: 14),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 38),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),

                // Notifications Feed
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selectedCategory == NotificationCategory.archived
                                    ? LucideIcons.archive
                                    : LucideIcons.bell,
                                size: 48,
                                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No matching notifications'
                                    : _selectedCategory == NotificationCategory.archived
                                        ? 'Archive is empty'
                                        : _selectedCategory == NotificationCategory.unread
                                            ? 'All caught up!'
                                            : 'No notifications yet',
                                style: textTheme.titleSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          children: [
                            if (today.isNotEmpty) ...[
                              _SectionLabel(label: 'Today', count: today.length),
                              const SizedBox(height: 4),
                              _buildGroupCard(today),
                            ],
                            if (yesterday.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _SectionLabel(label: 'Yesterday', count: yesterday.length),
                              const SizedBox(height: 4),
                              _buildGroupCard(yesterday),
                            ],
                            if (thisWeek.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _SectionLabel(label: 'This Week', count: thisWeek.length),
                              const SizedBox(height: 4),
                              _buildGroupCard(thisWeek),
                            ],
                            if (older.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _SectionLabel(label: 'Older', count: older.length),
                              const SizedBox(height: 4),
                              _buildGroupCard(older),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGroupCard(List<UserNotification> items) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _NotificationTile(
              item: items[i],
              onTap: () {
                if (!items[i].isRead && !items[i].isArchived) {
                  ref.read(notificationRepositoryProvider).markAsRead(items[i].id);
                }
                _handleNavigation(context, items[i]);
              },
              onArchive: () {
                ref.read(notificationRepositoryProvider).archive(items[i].id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification archived'), duration: Duration(seconds: 2)),
                );
              },
              onUnarchive: () {
                ref.read(notificationRepositoryProvider).unarchive(items[i].id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Restored to inbox'), duration: Duration(seconds: 2)),
                );
              },
              onDelete: () {
                ref.read(notificationRepositoryProvider).deleteNotification(items[i].id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification deleted'), duration: Duration(seconds: 2)),
                );
              },
            ),
            if (i < items.length - 1)
              Divider(
                height: 1,
                thickness: 0.6,
                color: colorScheme.onSurface.withValues(alpha: 0.06),
                indent: 56,
                endIndent: 12,
              ),
          ],
        ],
      ),
    );
  }

  void _handleNavigation(BuildContext context, UserNotification n) {
    if (n.link != null && n.link!.isNotEmpty) {
      context.go(n.link!);
    } else if (n.relatedDocumentId != null) {
      switch (n.type) {
        case 'quotation_accepted':
        case 'quotation_declined':
        case 'quotation_amended':
        case 'quotation_viewed':
        case 'quotation':
          context.go('/quotations/${n.relatedDocumentId}');
          break;
        case 'comment_added':
        case 'comment':
          context.go('/client-responses');
          break;
        case 'invoice_paid':
        case 'invoice_created':
        case 'invoice_reminder':
        case 'invoice':
          context.go('/invoices/${n.relatedDocumentId}');
          break;
        case 'team_invitation':
        case 'team':
          context.go('/team');
          break;
        case 'job_scheduled':
        case 'job_completed':
        case 'job_assigned':
        case 'job_updated':
        case 'job_reminder':
        case 'job':
        case 'schedule':
          context.go('/schedule/${n.relatedDocumentId}');
          break;
        case 'expense_added':
        case 'expense':
          context.go('/expenses');
          break;
        case 'customer_created':
        case 'customer_updated':
        case 'customer':
          context.go('/customers/${n.relatedDocumentId}');
          break;
        default:
          break;
      }
    }
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.onSurface
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: isSelected ? colorScheme.surface : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 11,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.surface.withValues(alpha: 0.2)
                      : colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: textTheme.labelSmall?.copyWith(
                    color: isSelected ? colorScheme.surface : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  const _SectionLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  fontSize: 10,
                ),
          ),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final UserNotification item;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final VoidCallback onUnarchive;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.onArchive,
    required this.onUnarchive,
    required this.onDelete,
  });

  IconData get _icon {
    switch (item.type) {
      case 'quotation_accepted':
        return LucideIcons.checkCircle2;
      case 'quotation_declined':
        return LucideIcons.xCircle;
      case 'quotation_amended':
        return LucideIcons.messageSquare;
      case 'quotation_viewed':
        return LucideIcons.eye;
      case 'invoice_paid':
        return LucideIcons.shieldCheck;
      case 'invoice_created':
        return LucideIcons.briefcase;
      case 'job_completed':
        return LucideIcons.checkCheck;
      case 'job_scheduled':
      case 'job':
      case 'schedule':
        return LucideIcons.hammer;
      case 'expense_added':
      case 'expense':
        return LucideIcons.receipt;
      case 'workflow_triggered':
        return LucideIcons.zap;
      default:
        return LucideIcons.bell;
    }
  }

  Color _iconColor(ColorScheme cs) {
    switch (item.type) {
      case 'quotation_accepted':
      case 'invoice_paid':
      case 'job_completed':
        return const Color(0xFF10B981); // Emerald
      case 'quotation_declined':
        return const Color(0xFFEF4444); // Rose
      case 'quotation_amended':
        return const Color(0xFFF59E0B); // Amber
      case 'quotation_viewed':
        return const Color(0xFF06B6D4); // Cyan
      case 'job_scheduled':
      case 'job':
      case 'schedule':
        return const Color(0xFF0284C7); // Sky
      case 'expense_added':
      case 'expense':
        return const Color(0xFF8B5CF6); // Purple
      case 'workflow_triggered':
        return const Color(0xFF6366F1); // Indigo
      default:
        return cs.onSurfaceVariant;
    }
  }

  String _tagLabel() {
    switch (item.type) {
      case 'quotation_accepted':
        return 'Accepted';
      case 'quotation_declined':
        return 'Declined';
      case 'quotation_amended':
        return 'Changes';
      case 'quotation_viewed':
        return 'Viewed';
      case 'invoice_paid':
        return 'Paid';
      case 'invoice_created':
        return 'Invoiced';
      case 'job_completed':
        return 'Job Done';
      case 'job_scheduled':
        return 'Job Booked';
      case 'expense_added':
        return 'Expense';
      case 'workflow_triggered':
        return 'Automation';
      default:
        return 'Alert';
    }
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: item.isArchived ? Colors.redAccent.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
        child: Icon(
          item.isArchived ? LucideIcons.trash2 : LucideIcons.archive,
          size: 18,
          color: item.isArchived ? Colors.redAccent : Colors.amber,
        ),
      ),
      onDismissed: (_) {
        if (item.isArchived) {
          onDelete();
        } else {
          onArchive();
        }
      },
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: item.isArchived
                ? Colors.transparent
                : item.isRead
                    ? Colors.transparent
                    : colorScheme.primary.withValues(alpha: 0.04),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _iconColor(colorScheme).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: _iconColor(colorScheme), size: 18),
              ),
              const SizedBox(width: 10),

              // Title, Message, & Badge Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: textTheme.titleSmall?.copyWith(
                              fontSize: 13,
                              fontWeight: item.isRead || item.isArchived ? FontWeight.w500 : FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _relativeTime(item.createdAt),
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 10.5,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Bottom Tag and Link Hints
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: _iconColor(colorScheme).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _iconColor(colorScheme).withValues(alpha: 0.2), width: 0.5),
                          ),
                          child: Text(
                            _tagLabel(),
                            style: textTheme.labelSmall?.copyWith(
                              color: _iconColor(colorScheme),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (item.isArchived)
                          GestureDetector(
                            onTap: onUnarchive,
                            child: Row(
                              children: [
                                Icon(LucideIcons.rotateCcw, size: 11, color: colorScheme.primary),
                                const SizedBox(width: 3),
                                Text(
                                  'Restore',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            children: [
                              Text(
                                'Open',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 1),
                              Icon(LucideIcons.chevronRight, size: 12, color: colorScheme.primary),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Unread Accent Dot
              if (!item.isRead && !item.isArchived) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF47421),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
