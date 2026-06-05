import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../components/mesh_background.dart';
import '../../components/glass_card.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return MeshBackground(
      child: Scaffold(
        backgroundColor:
            Colors.transparent, // Transparent to show MeshBackground
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
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
                style:
                    textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
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
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
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
                    Icon(
                      Icons.notifications_none_outlined,
                      size: 64,
                      color: colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'re all caught up!',
                      style: textTheme.bodyMedium?.copyWith(
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              );
            }

            final today = notifications
                .where(
                    (n) => DateTime.now().difference(n.createdAt).inHours < 24)
                .toList();
            final earlier = notifications
                .where(
                    (n) => DateTime.now().difference(n.createdAt).inHours >= 24)
                .toList();

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (today.isNotEmpty) ...[
                  const _SectionLabel(label: 'Today'),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (int i = 0; i < today.length; i++) ...[
                          _NotificationTile(
                            item: today[i],
                            onTap: () {
                              if (!today[i].isRead) {
                                ref
                                    .read(notificationRepositoryProvider)
                                    .markAsRead(today[i].id);
                              }
                              _handleNavigation(context, today[i]);
                            },
                          ),
                          if (i < today.length - 1)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.05),
                              indent: 72,
                              endIndent: 16,
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (earlier.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const _SectionLabel(label: 'Earlier'),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (int i = 0; i < earlier.length; i++) ...[
                          _NotificationTile(
                            item: earlier[i],
                            onTap: () {
                              if (!earlier[i].isRead) {
                                ref
                                    .read(notificationRepositoryProvider)
                                    .markAsRead(earlier[i].id);
                              }
                              _handleNavigation(context, earlier[i]);
                            },
                          ),
                          if (i < earlier.length - 1)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.05),
                              indent: 72,
                              endIndent: 16,
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, UserNotification n) {
    if (n.link != null && n.link!.isNotEmpty) {
      // Use declarative navigation to avoid shell route duplicate key collisions
      context.go(n.link!);
    } else if (n.relatedDocumentId != null) {
      switch (n.type) {
        case 'quotation_accepted':
        case 'quotation_declined':
        case 'quotation_amended':
        case 'quotation':
          context.go('/quotations/${n.relatedDocumentId}');
          break;
        case 'invoice_paid':
        case 'invoice_reminder':
        case 'invoice':
          context.go('/invoices/${n.relatedDocumentId}');
          break;
        case 'team_invitation':
        case 'team':
          context.go('/team');
          break;
        case 'job_assigned':
        case 'job_updated':
        case 'job_reminder':
        case 'job':
        case 'schedule':
          context.go('/schedule/${n.relatedDocumentId}');
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

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
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
      case 'job_assigned':
      case 'job_updated':
      case 'job_reminder':
      case 'job':
      case 'schedule':
        return Icons.calendar_today_outlined;
      case 'customer_created':
      case 'customer_updated':
      case 'customer':
        return Icons.people_outline;
      default:
        return Icons.info_outlined;
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
      case 'job_assigned':
      case 'job_updated':
      case 'job_reminder':
      case 'job':
      case 'schedule':
        return cs.primary;
      case 'customer_created':
      case 'customer_updated':
      case 'customer':
        return cs.secondary;
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: item.isRead
              ? Colors.transparent
              : colorScheme.primary.withValues(alpha: 0.06),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _iconColor(colorScheme).withValues(alpha: 0.12),
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
                            fontWeight:
                                item.isRead ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _relativeTime(item.createdAt),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: textTheme.bodySmall?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      height: 1.3,
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
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
