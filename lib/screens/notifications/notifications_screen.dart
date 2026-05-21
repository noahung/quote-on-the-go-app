import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Text('Notifications',
                style: textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Consumer(builder: (context, ref, _) {
              final unread = ref.watch(unreadNotificationCountProvider);
              if (unread == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$unread',
                    style: textTheme.labelSmall
                        ?.copyWith(color: colorScheme.onPrimary),
                  ),
                ),
              );
            }),
          ],
        ),
        actions: [
          Consumer(builder: (context, ref, _) {
            final unread = ref.watch(unreadNotificationCountProvider);
            if (unread == 0) return const SizedBox.shrink();
            return TextButton(
              onPressed: () async {
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                final repo = ref.read(notificationRepositoryProvider);
                await repo.markAllAsRead(user.uid);
              },
              child: const Text('Mark all read'),
            );
          }),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined,
                      size: 64, color: colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  Text('No notifications yet',
                      style: textTheme.titleMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(
                    'You\'re all caught up!',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          final today = notifications
              .where((n) => DateTime.now().difference(n.createdAt).inHours < 24)
              .toList();
          final earlier = notifications
              .where(
                  (n) => DateTime.now().difference(n.createdAt).inHours >= 24)
              .toList();

          return ListView(
            children: [
              if (today.isNotEmpty) ...[
                const _SectionLabel(label: 'Today'),
                ...today.map((n) => _NotificationTile(
                      item: n,
                      onTap: () {
                        if (!n.isRead) {
                          ref
                              .read(notificationRepositoryProvider)
                              .markAsRead(n.id);
                        }
                        _handleNavigation(context, n);
                      },
                    )),
              ],
              if (earlier.isNotEmpty) ...[
                const _SectionLabel(label: 'Earlier'),
                ...earlier.map((n) => _NotificationTile(
                      item: n,
                      onTap: () {
                        if (!n.isRead) {
                          ref
                              .read(notificationRepositoryProvider)
                              .markAsRead(n.id);
                        }
                        _handleNavigation(context, n);
                      },
                    )),
              ],
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  void _handleNavigation(BuildContext context, UserNotification n) {
    if (n.link != null && n.link!.isNotEmpty) {
      // Web links like /quotations/xxx - reuse as mobile routes
      context.push(n.link!);
    } else if (n.relatedDocumentId != null) {
      switch (n.type) {
        case 'quotation_accepted':
        case 'quotation_declined':
        case 'quotation_amended':
          context.push('/quotations/${n.relatedDocumentId}');
        case 'invoice_paid':
        case 'invoice_reminder':
          context.push('/invoices/${n.relatedDocumentId}');
        case 'team_invitation':
          context.push('/team');
        default:
          break;
      }
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final UserNotification item;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  IconData get _icon {
    switch (item.type) {
      case 'quotation_accepted':
        return Icons.check_circle_outlined;
      case 'quotation_declined':
        return Icons.cancel_outlined;
      case 'quotation_amended':
        return Icons.edit_note_outlined;
      case 'invoice_paid':
        return Icons.payments_outlined;
      case 'invoice_reminder':
        return Icons.alarm_outlined;
      case 'team_invitation':
        return Icons.person_add_outlined;
      default:
        return Icons.info_outlined;
    }
  }

  Color _iconBg(ColorScheme cs) {
    switch (item.type) {
      case 'quotation_accepted':
        return cs.tertiaryContainer;
      case 'quotation_declined':
        return cs.errorContainer;
      case 'quotation_amended':
        return cs.secondaryContainer;
      case 'invoice_paid':
        return cs.tertiaryContainer;
      case 'invoice_reminder':
        return cs.errorContainer;
      case 'team_invitation':
        return cs.primaryContainer;
      default:
        return cs.surfaceContainerHighest;
    }
  }

  Color _iconColor(ColorScheme cs) {
    switch (item.type) {
      case 'quotation_accepted':
        return cs.tertiary;
      case 'quotation_declined':
        return cs.error;
      case 'quotation_amended':
        return cs.secondary;
      case 'invoice_paid':
        return cs.tertiary;
      case 'invoice_reminder':
        return cs.error;
      case 'team_invitation':
        return cs.primary;
      default:
        return cs.onSurfaceVariant;
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

    return InkWell(
      onTap: onTap,
      child: Container(
        color: item.isRead
            ? Colors.transparent
            : colorScheme.primaryContainer.withOpacity(0.15),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _iconBg(colorScheme),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: _iconColor(colorScheme), size: 22),
            ),
            const SizedBox(width: 12),
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
                            fontWeight: item.isRead
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _relativeTime(item.createdAt),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.message,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
