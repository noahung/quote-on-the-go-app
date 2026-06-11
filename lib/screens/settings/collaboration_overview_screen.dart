import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../providers/providers.dart';
import '../../theme/semantic_colors.dart';

// Helper to safely parse Firestore timestamps
DateTime _parseTimestamp(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is String) {
    // Try to parse ISO 8601 string
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.now();
    }
  }
  return DateTime.now();
}

// Models for collaboration data
class ApprovalWorkflow {
  final String id;
  final String documentId;
  final String documentType;
  final String status;
  final String initiatedByName;
  final DateTime initiatedAt;

  ApprovalWorkflow({
    required this.id,
    required this.documentId,
    required this.documentType,
    required this.status,
    required this.initiatedByName,
    required this.initiatedAt,
  });

  factory ApprovalWorkflow.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ApprovalWorkflow(
      id: doc.id,
      documentId: data['documentId'] ?? '',
      documentType: data['documentType'] ?? 'quotation',
      status: data['status'] ?? 'pending',
      initiatedByName: data['initiatedBy']?['userName'] ?? 'Unknown',
      initiatedAt: _parseTimestamp(data['initiatedAt']),
    );
  }
}

class InternalComment {
  final String id;
  final String documentId;
  final String documentType;
  final String content;
  final String authorName;
  final DateTime createdAt;
  final bool isResolved;

  InternalComment({
    required this.id,
    required this.documentId,
    required this.documentType,
    required this.content,
    required this.authorName,
    required this.createdAt,
    this.isResolved = false,
  });

  factory InternalComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InternalComment(
      id: doc.id,
      documentId: data['documentId'] ?? '',
      documentType: data['documentType'] ?? 'quotation',
      content: data['content'] ?? '',
      authorName: data['author']?['userName'] ?? 'Unknown',
      createdAt: _parseTimestamp(data['createdAt']),
      isResolved: data['isResolved'] ?? false,
    );
  }
}

class ActivityTimeline {
  final String id;
  final String description;
  final String actorName;
  final String documentId;
  final String documentType;
  final DateTime timestamp;

  ActivityTimeline({
    required this.id,
    required this.description,
    required this.actorName,
    required this.documentId,
    required this.documentType,
    required this.timestamp,
  });

  factory ActivityTimeline.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityTimeline(
      id: doc.id,
      description: data['description'] ?? 'Activity occurred',
      actorName: data['actor']?['userName'] ?? 'Unknown',
      documentId: data['documentId'] ?? '',
      documentType: data['documentType'] ?? 'quotation',
      timestamp: _parseTimestamp(data['timestamp']),
    );
  }
}

// Providers
final approvalWorkflowsProvider = StreamProvider.autoDispose<List<ApprovalWorkflow>>((ref) {
  final companyId = ref.watch(companyIdProvider);
  if (companyId == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('approval_workflows')
      .where('companyId', isEqualTo: companyId)
      .limit(20)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map((d) => ApprovalWorkflow.fromFirestore(d)).toList();
        list.sort((a, b) => b.initiatedAt.compareTo(a.initiatedAt));
        return list;
      });
});

final internalCommentsProvider = StreamProvider.autoDispose<List<InternalComment>>((ref) {
  final companyId = ref.watch(companyIdProvider);
  if (companyId == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('internal_comments')
      .where('companyId', isEqualTo: companyId)
      .limit(10)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map((d) => InternalComment.fromFirestore(d)).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
});

final activityTimelineProvider = StreamProvider.autoDispose<List<ActivityTimeline>>((ref) {
  final companyId = ref.watch(companyIdProvider);
  if (companyId == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('activity_timeline')
      .where('companyId', isEqualTo: companyId)
      .limit(15)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map((d) => ActivityTimeline.fromFirestore(d)).toList();
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return list;
      });
});

class CollaborationOverviewScreen extends ConsumerWidget {
  const CollaborationOverviewScreen({super.key});

  String _timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()}y ago';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}mo ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final approvalsAsync = ref.watch(approvalWorkflowsProvider);
    final commentsAsync = ref.watch(internalCommentsProvider);
    final activityAsync = ref.watch(activityTimelineProvider);

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                context.go('/settings');
              }
            },
          ),
          title: const Text(
            'Collaboration',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(approvalWorkflowsProvider);
                ref.invalidate(internalCommentsProvider);
                ref.invalidate(activityTimelineProvider);
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Description
            Text(
              'Pending approvals, recent comments and document activity across your team.',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),

            // Stats Grid
            _buildStatsGrid(approvalsAsync, commentsAsync, activityAsync, colorScheme, semanticColors, isDark),
            const SizedBox(height: 20),

            // Pending Reviews
            _buildPendingReviews(approvalsAsync, colorScheme, semanticColors, isDark, context),
            const SizedBox(height: 16),

            // Recent Comments
            _buildRecentComments(commentsAsync, colorScheme, semanticColors, isDark, context),
            const SizedBox(height: 16),

            // Recent Activity
            _buildRecentActivity(activityAsync, colorScheme, isDark, context),
            const SizedBox(height: 20),

            // Approval Rules Info
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Approval Rules',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Approval workflows are triggered per-document using the Review tab inside each quotation or invoice. Choose from Custom, High Value, Client Type, or Service Type review flows.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    AsyncValue<List<ApprovalWorkflow>> approvalsAsync,
    AsyncValue<List<InternalComment>> commentsAsync,
    AsyncValue<List<ActivityTimeline>> activityAsync,
    ColorScheme colorScheme,
    SemanticColors semanticColors,
    bool isDark,
  ) {
    return approvalsAsync.when(
      loading: () => _buildStatsSkeleton(isDark),
      error: (_, __) => _buildStatsSkeleton(isDark),
      data: (approvals) {
        final pendingApprovals = approvals.where((a) => a.status == 'pending').length;
        final completedApprovals = approvals.where((a) => a.status != 'pending').length;

        return commentsAsync.when(
          loading: () => _buildStatsSkeleton(isDark),
          error: (_, __) => _buildStatsSkeleton(isDark),
          data: (comments) {
            final unresolvedComments = comments.where((c) => !c.isResolved).length;

            return activityAsync.when(
              loading: () => _buildStatsSkeleton(isDark),
              error: (_, __) => _buildStatsSkeleton(isDark),
              data: (activity) {
                return Row(
                  children: [
                    _StatCard(
                      label: 'Pending\nReviews',
                      value: pendingApprovals.toString(),
                      color: Colors.orange,
                      isDark: isDark,
                      flex: 1,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Open\nComments',
                      value: unresolvedComments.toString(),
                      color: colorScheme.primary,
                      isDark: isDark,
                      flex: 1,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Completed\nReviews',
                      value: completedApprovals.toString(),
                      color: semanticColors.success,
                      isDark: isDark,
                      flex: 1,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Recent\nEvents',
                      value: activity.length.toString(),
                      color: Colors.purple,
                      isDark: isDark,
                      flex: 1,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatsSkeleton(bool isDark) {
    return Row(
      children: List.generate(4, (index) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < 3 ? 12 : 0),
            height: 80,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPendingReviews(
    AsyncValue<List<ApprovalWorkflow>> approvalsAsync,
    ColorScheme colorScheme,
    SemanticColors semanticColors,
    bool isDark,
    BuildContext context,
  ) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pending Reviews',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Documents waiting for team approval',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                approvalsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (approvals) {
                    final pending = approvals.where((a) => a.status == 'pending').length;
                    if (pending == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '$pending pending',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          approvalsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('Error: $e')),
            ),
            data: (approvals) {
              final pending = approvals.where((a) => a.status == 'pending').toList();

              if (pending.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, size: 48, color: semanticColors.success.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      const Text(
                        'All caught up!',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No documents are waiting for review.',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: pending.map((workflow) {
                  return _PendingReviewTile(
                    workflow: workflow,
                    colorScheme: colorScheme,
                    isDark: isDark,
                    onOpen: () {
                      final route = workflow.documentType == 'quotation'
                          ? '/quotations/${workflow.documentId}'
                          : '/invoices/${workflow.documentId}';
                      context.push(route);
                    },
                    timeAgo: _timeAgo(workflow.initiatedAt),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentComments(
    AsyncValue<List<InternalComment>> commentsAsync,
    ColorScheme colorScheme,
    SemanticColors semanticColors,
    bool isDark,
    BuildContext context,
  ) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Comments',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Latest internal notes across documents',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          commentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('Error: $e')),
            ),
            data: (comments) {
              if (comments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No comments yet',
                      style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ),
                );
              }

              return Column(
                children: comments.take(5).map((comment) {
                  return _CommentTile(
                    comment: comment,
                    colorScheme: colorScheme,
                    isDark: isDark,
                    onOpen: () {
                      final route = comment.documentType == 'quotation'
                          ? '/quotations/${comment.documentId}'
                          : '/invoices/${comment.documentId}';
                      context.push(route);
                    },
                    timeAgo: _timeAgo(comment.createdAt),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(
    AsyncValue<List<ActivityTimeline>> activityAsync,
    ColorScheme colorScheme,
    bool isDark,
    BuildContext context,
  ) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'All collaboration events across documents',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          activityAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('Error: $e')),
            ),
            data: (activities) {
              if (activities.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No activity yet',
                      style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ),
                );
              }

              return Column(
                children: activities.take(8).map((activity) {
                  return _ActivityTile(
                    activity: activity,
                    colorScheme: colorScheme,
                    isDark: isDark,
                    onOpen: () {
                      final route = activity.documentType == 'quotation'
                          ? '/quotations/${activity.documentId}'
                          : '/invoices/${activity.documentId}';
                      context.push(route);
                    },
                    timeAgo: _timeAgo(activity.timestamp),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final int flex;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    required this.flex,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                height: 1.3,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingReviewTile extends StatelessWidget {
  final ApprovalWorkflow workflow;
  final ColorScheme colorScheme;
  final bool isDark;
  final VoidCallback onOpen;
  final String timeAgo;

  const _PendingReviewTile({
    required this.workflow,
    required this.colorScheme,
    required this.isDark,
    required this.onOpen,
    required this.timeAgo,
  });

  Color get _statusColor {
    switch (workflow.status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${workflow.documentType[0].toUpperCase()}${workflow.documentType.substring(1)} Review',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Requested by ${workflow.initiatedByName} \u2022 $timeAgo',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                workflow.status[0].toUpperCase() + workflow.status.substring(1),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _statusColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final InternalComment comment;
  final ColorScheme colorScheme;
  final bool isDark;
  final VoidCallback onOpen;
  final String timeAgo;

  const _CommentTile({
    required this.comment,
    required this.colorScheme,
    required this.isDark,
    required this.onOpen,
    required this.timeAgo,
  });

  String get _initials {
    final name = comment.authorName;
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                _initials,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comment.authorName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${comment.content.length > 80 ? '${comment.content.substring(0, 80)}...' : comment.content}"',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (comment.isResolved)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Resolved',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade600,
                        ),
                      ),
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

class _ActivityTile extends StatelessWidget {
  final ActivityTimeline activity;
  final ColorScheme colorScheme;
  final bool isDark;
  final VoidCallback onOpen;
  final String timeAgo;

  const _ActivityTile({
    required this.activity,
    required this.colorScheme,
    required this.isDark,
    required this.onOpen,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.circle,
              size: 8,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.description,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${activity.actorName} \u2022 $timeAgo',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
