import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/mesh_background.dart';
import '../../components/curved_header.dart';
import '../../theme/semantic_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/collaboration_provider.dart';
import '../../providers/quotation_provider.dart';
import '../../providers/invoice_provider.dart';

class CollaborationScreen extends ConsumerStatefulWidget {
  final String documentId;
  final String documentType; // 'quotation' | 'invoice'

  const CollaborationScreen({
    super.key,
    required this.documentId,
    required this.documentType,
  });

  @override
  ConsumerState<CollaborationScreen> createState() => _CollaborationScreenState();
}

class _CollaborationScreenState extends ConsumerState<CollaborationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();
  bool _isCreatingVersion = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final userProfile = ref.read(userProfileProvider);
    if (userProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User profile not loaded. Cannot post comment.')),
      );
      return;
    }

    try {
      await ref.read(collaborationRepositoryProvider).addComment(
            documentId: widget.documentId,
            documentType: widget.documentType,
            content: text,
            userId: userProfile.uid,
            userName: userProfile.displayName ?? userProfile.email ?? 'Anonymous',
            userEmail: userProfile.email ?? '',
            companyId: userProfile.companyId,
          );
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    }
  }

  Future<void> _showCreateVersionDialog(BuildContext context, Map<String, dynamic> docSnapshot) async {
    final textController = TextEditingController();
    final userProfile = ref.read(userProfileProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (userProfile == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('User profile not loaded.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Version'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Provide a summary of the changes made in this version:'),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Change summary',
                hintText: 'e.g., Updated quantities based on feedback',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF4781F)),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed == true && textController.text.trim().isNotEmpty) {
      setState(() => _isCreatingVersion = true);
      try {
        final changeSummary = textController.text.trim();
        await ref.read(collaborationRepositoryProvider).createVersion(
              documentId: widget.documentId,
              documentType: widget.documentType,
              title: 'Manual Revision',
              changes: [
                {
                  'field': 'manual',
                  'oldValue': '',
                  'newValue': changeSummary,
                  'changeType': 'modified',
                  'description': changeSummary,
                }
              ],
              snapshot: docSnapshot,
              userId: userProfile.uid,
              userName: userProfile.displayName ?? userProfile.email ?? 'Anonymous',
              userEmail: userProfile.email ?? '',
              companyId: userProfile.companyId,
            );
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Successfully created new version snapshot!'), backgroundColor: Colors.green),
        );
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to create version: $e'), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) {
          setState(() => _isCreatingVersion = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final commentsAsync = ref.watch(collaborationCommentsProvider((
      documentId: widget.documentId,
      documentType: widget.documentType,
    )));

    final versionsAsync = ref.watch(collaborationVersionsProvider((
      documentId: widget.documentId,
      documentType: widget.documentType,
    )));

    final activityAsync = ref.watch(unifiedActivityStreamProvider((
      documentId: widget.documentId,
      documentType: widget.documentType,
    )));

    final approvalAsync = ref.watch(activeApprovalWorkflowProvider((
      documentId: widget.documentId,
      documentType: widget.documentType,
    )));

    // Watch the actual document to display details and capture snapshot
    String docNumber = widget.documentId.substring(0, 4);
    Map<String, dynamic> docSnapshot = {};

    if (widget.documentType == 'quotation') {
      final quoteAsync = ref.watch(quotationStreamProvider(widget.documentId));
      quoteAsync.whenData((quote) {
        if (quote != null) {
          docNumber = quote.quotationNumber;
          docSnapshot = quote.toJson();
        }
      });
    } else {
      final invoiceAsync = ref.watch(invoiceStreamProvider(widget.documentId));
      invoiceAsync.whenData((invoice) {
        if (invoice != null) {
          docNumber = invoice.invoiceNumber;
          docSnapshot = invoice.toJson();
        }
      });
    }

    final versionCount = versionsAsync.valueOrNull?.length ?? 0;
    final activityCount = activityAsync.valueOrNull?.length ?? 0;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: CurvedHeader(
            title: widget.documentType == 'quotation' ? 'Quote Collaboration' : 'Invoice Collaboration',
            onBackPressed: () {
              if (GoRouter.of(context).canPop()) {
                GoRouter.of(context).pop();
              } else {
                if (widget.documentType == 'quotation') {
                  context.go('/quotations/${widget.documentId}');
                } else {
                  context.go('/invoices/${widget.documentId}');
                }
              }
            },
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Card(
                  elevation: 0,
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                  shape: const StadiumBorder(),
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                    child: Text(
                      '#$docNumber',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 16),
            // Segmented Toggles
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
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
                  tabs: [
                    Tab(text: 'Versions ($versionCount)'),
                    Tab(text: 'Activity Feed ($activityCount)'),
                    Tab(text: 'Approvals'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tab Bar Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildVersionsTab(context, versionsAsync, commentsAsync, docSnapshot, semanticColors, isDark),
                  _buildActivityFeedTab(context, activityAsync, semanticColors, isDark),
                  _buildApprovalsTab(context, approvalAsync, semanticColors, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionsTab(
    BuildContext context,
    AsyncValue<List<DocumentVersion>> versionsAsync,
    AsyncValue<List<InternalComment>> commentsAsync,
    Map<String, dynamic> docSnapshot,
    SemanticColors colors,
    bool isDark,
  ) {
    return Column(
      children: [
        Expanded(
          child: versionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (versions) {
              if (versions.isEmpty) {
                return const Center(child: Text('No version snapshots recorded yet.', style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: versions.length,
                itemBuilder: (context, index) {
                  final version = versions[index];
                  return Card(
                    elevation: 0,
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: version.isActive ? const Color(0xFFF4781F) : Colors.black12,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  version.isActive ? 'v${version.versionNumber} (Current)' : 'v${version.versionNumber}',
                                  style: TextStyle(
                                    color: version.isActive ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (version.isActive)
                                const Icon(Icons.check_circle, color: Colors.green),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Display descriptions of changes
                          Text(
                            version.changes.isNotEmpty && version.changes.first['description'] != null
                                ? version.changes.first['description'] as String
                                : 'Document version snapshot.',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          // Bullet changes
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• Total Value: £${(version.snapshot['total'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                    style: const TextStyle(fontSize: 12)),
                                if (version.changes.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('• Changes: ${version.changes.map((c) => c['description'] ?? c['field']).join(', ')}',
                                      style: const TextStyle(fontSize: 12)),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Created by ${version.createdByName}',
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatTimeAgo(version.createdAt),
                                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white38.withValues(alpha: 0.7) : Colors.grey.withValues(alpha: 0.7)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: version.isActive
                                    ? null
                                    : () => _restoreVersion(context, version.id),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(version.isActive ? 'Current' : 'Restore', style: const TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => VersionComparisonBottomSheet(
                                      selectedVersion: version,
                                      currentDocSnapshot: docSnapshot,
                                      allVersions: versions,
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Compare', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.visibility, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Viewing version snapshot - coming soon')),
                                  );
                                },
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Create new version button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: _isCreatingVersion || docSnapshot.isEmpty
                    ? null
                    : () => _showCreateVersionDialog(context, docSnapshot),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF4781F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isCreatingVersion
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Create New Version', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              // Latest comment preview
              commentsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
                data: (comments) {
                  if (comments.isEmpty) return const SizedBox.shrink();
                  final latest = comments.last;
                  return Card(
                    elevation: 0,
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.comment, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Latest from ${latest.authorName} (${_formatTimeAgo(latest.createdAt)}): "${latest.content}"',
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityFeedTab(
    BuildContext context,
    AsyncValue<List<UnifiedActivityItem>> activityAsync,
    SemanticColors colors,
    bool isDark,
  ) {
    return Column(
      children: [
        Expanded(
          child: activityAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (items) {
              if (items.isEmpty) {
                return const Center(child: Text('No activity recorded yet.', style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  
                  // Determine badge color
                  Color badgeColor = Colors.grey;
                  if (item.type == 'comment') {
                    if (item.isPrivate) {
                      badgeColor = Colors.blue;
                    } else {
                      badgeColor = Colors.green; // Customer badge
                    }
                  }

                  Color avatarBgColor = badgeColor.withValues(alpha: 0.12);
                  Color avatarTextColor = badgeColor;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: avatarBgColor,
                          radius: 18,
                          child: Text(
                            item.initials,
                            style: TextStyle(
                              color: avatarTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
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
                                    item.authorName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.badgeText,
                                      style: TextStyle(
                                        color: badgeColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatTimeAgo(item.timestamp),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                ),
                                child: Text(
                                  item.content,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              if (item.type == 'comment') ...[
                                if (item.isResolved) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Resolved',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => _resolveComment(context, item.id),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('Resolve', style: TextStyle(fontSize: 12, color: Color(0xFFF4781F))),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Text input at the bottom
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white,
            border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add an internal comment...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFFF4781F)),
                  onPressed: _submitComment,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _resolveComment(BuildContext context, String commentId) async {
    final userProfile = ref.read(userProfileProvider);
    if (userProfile == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(collaborationRepositoryProvider).resolveComment(
            commentId: commentId,
            userId: userProfile.uid,
            userName: userProfile.displayName ?? userProfile.email ?? 'Anonymous',
            userEmail: userProfile.email ?? '',
          );
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Comment resolved'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to resolve comment: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _restoreVersion(BuildContext context, String versionId) async {
    final userProfile = ref.read(userProfileProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (userProfile == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('User profile not loaded.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore version?'),
        content: const Text('This will overwrite the current document with the selected version.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(collaborationRepositoryProvider).restoreDocumentVersion(
            documentId: widget.documentId,
            documentType: widget.documentType,
            versionId: versionId,
            userId: userProfile.uid,
            userName: userProfile.displayName ?? userProfile.email ?? 'Anonymous',
            userEmail: userProfile.email ?? '',
            companyId: userProfile.companyId,
          );
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Document restored'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to restore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _initiateApproval(BuildContext context) async {
    final userProfile = ref.read(userProfileProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (userProfile == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('User profile not loaded.')),
      );
      return;
    }

    try {
      await ref.read(collaborationRepositoryProvider).initiateApprovalWorkflow(
            documentId: widget.documentId,
            documentType: widget.documentType,
            workflowType: 'custom',
            userId: userProfile.uid,
            userName: userProfile.displayName ?? userProfile.email ?? 'Anonymous',
            userEmail: userProfile.email ?? '',
            companyId: userProfile.companyId,
          );
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Approval workflow initiated'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to initiate approval: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _processApprovalDecision(
    BuildContext context,
    ApprovalWorkflow workflow,
    ApprovalWorkflowStep step,
    String decision,
  ) async {
    final userProfile = ref.read(userProfileProvider);
    if (userProfile == null) return;
    final messenger = ScaffoldMessenger.of(context);

    final commentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${decision[0].toUpperCase()}${decision.substring(1)} step ${step.stepNumber}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add an optional comment:'),
            const SizedBox(height: 8),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(hintText: 'Comment'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: decision == 'approved' ? Colors.green : Colors.red,
            ),
            child: Text(decision[0].toUpperCase() + decision.substring(1)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(collaborationRepositoryProvider).processApprovalDecision(
            workflowId: workflow.id,
            stepNumber: step.stepNumber,
            decision: decision,
            comments: commentController.text.trim(),
            userId: userProfile.uid,
            userName: userProfile.displayName ?? userProfile.email ?? 'Anonymous',
            userEmail: userProfile.email ?? '',
          );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Step ${step.stepNumber} $decision'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to process decision: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  Widget _buildApprovalsTab(
    BuildContext context,
    AsyncValue<ApprovalWorkflow?> approvalAsync,
    SemanticColors colors,
    bool isDark,
  ) {
    return approvalAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (workflow) {
        if (workflow == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No approval workflow active', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Start an approval workflow to collect sign-off on this document.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _initiateApproval(context),
                    icon: const Icon(Icons.verified),
                    label: const Text('Start Approval'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF4781F)),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _ApprovalStatusBadge(status: workflow.status),
                ),
                if (workflow.status == 'pending' || workflow.status == 'approved' || workflow.status == 'rejected')
                  TextButton.icon(
                    onPressed: () => _initiateApproval(context),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Restart', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...workflow.steps.map((step) {
              final isCurrent = step.stepNumber == workflow.currentStep && workflow.status == 'pending';
              return Card(
                elevation: 0,
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _ApprovalStatusBadge(status: step.status),
                          const Spacer(),
                          Text(
                            'Step ${step.stepNumber}',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black45, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Approver: ${step.approverRole[0].toUpperCase()}${step.approverRole.substring(1)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      if (step.comments != null && step.comments!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          step.comments!,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ],
                      if (isCurrent && step.status == 'pending') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _processApprovalDecision(context, workflow, step, 'rejected'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _processApprovalDecision(context, workflow, step, 'approved'),
                                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                child: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _ApprovalStatusBadge extends StatelessWidget {
  final String status;

  const _ApprovalStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'pending' => (Colors.orange, 'Pending'),
      'approved' => (Colors.green, 'Approved'),
      'rejected' => (Colors.red, 'Rejected'),
      _ => (Colors.grey, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class VersionComparisonBottomSheet extends StatefulWidget {
  final DocumentVersion selectedVersion;
  final Map<String, dynamic> currentDocSnapshot;
  final List<DocumentVersion> allVersions;

  const VersionComparisonBottomSheet({
    super.key,
    required this.selectedVersion,
    required this.currentDocSnapshot,
    required this.allVersions,
  });

  @override
  State<VersionComparisonBottomSheet> createState() => _VersionComparisonBottomSheetState();
}

class _VersionComparisonBottomSheetState extends State<VersionComparisonBottomSheet> {
  late Map<String, dynamic> _compareWithSnapshot;
  String _compareTargetLabel = 'Current Document';

  @override
  void initState() {
    super.initState();
    _compareWithSnapshot = widget.currentDocSnapshot;
  }

  List<Map<String, dynamic>> _computeDifferences(Map<String, dynamic> oldSnap, Map<String, dynamic> newSnap) {
    final diffs = <Map<String, dynamic>>[];
    
    final fields = {
      'total': 'Total Amount',
      'customerName': 'Client/Customer Name',
      'notes': 'Notes',
      'expiryDate': 'Expiry Date',
      'date': 'Date',
      'status': 'Status',
      'discount': 'Discount',
    };

    for (final entry in fields.entries) {
      final field = entry.key;
      final label = entry.value;
      
      final oldVal = oldSnap[field];
      final newVal = newSnap[field];

      if (oldVal != newVal) {
        String formatVal(dynamic val) {
          if (val == null) return 'N/A';
          if (val is num) return '£${val.toStringAsFixed(2)}';
          return val.toString();
        }
        diffs.add({
          'field': label,
          'oldValue': formatVal(oldVal),
          'newValue': formatVal(newVal),
        });
      }
    }

    final oldItems = oldSnap['items'] as List? ?? [];
    final newItems = newSnap['items'] as List? ?? [];
    if (oldItems.length != newItems.length) {
      diffs.add({
        'field': 'Number of Items',
        'oldValue': '${oldItems.length} items',
        'newValue': '${newItems.length} items',
      });
    } else {
      for (int i = 0; i < oldItems.length; i++) {
        final oldItem = oldItems[i] as Map? ?? {};
        final newItem = newItems[i] as Map? ?? {};
        final oldDesc = oldItem['description'] ?? oldItem['name'] ?? 'Item ${i + 1}';
        final newDesc = newItem['description'] ?? newItem['name'] ?? 'Item ${i + 1}';
        final oldPrice = oldItem['rate'] ?? oldItem['price'] ?? oldItem['unitPrice'] ?? 0.0;
        final newPrice = newItem['rate'] ?? newItem['price'] ?? newItem['unitPrice'] ?? 0.0;
        final oldQty = oldItem['quantity'] ?? 0;
        final newQty = newItem['quantity'] ?? 0;

        if (oldDesc != newDesc || oldPrice != newPrice || oldQty != newQty) {
          diffs.add({
            'field': 'Item ${i + 1} (${newDesc})',
            'oldValue': '$oldQty x £${(oldPrice as num).toStringAsFixed(2)}',
            'newValue': '$newQty x £${(newPrice as num).toStringAsFixed(2)}',
          });
        }
      }
    }

    return diffs;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final differences = _computeDifferences(widget.selectedVersion.snapshot, _compareWithSnapshot);

    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Compare Version ${widget.selectedVersion.versionNumber}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Compare with:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _compareTargetLabel,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: [
              const DropdownMenuItem(
                value: 'Current Document',
                child: Text('Current Document Snapshot'),
              ),
              ...widget.allVersions
                  .where((v) => v.id != widget.selectedVersion.id)
                  .map((v) => DropdownMenuItem(
                        value: 'Version ${v.versionNumber}',
                        child: Text('Version ${v.versionNumber} snapshot'),
                      ))
            ],
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _compareTargetLabel = val;
                if (val == 'Current Document') {
                  _compareWithSnapshot = widget.currentDocSnapshot;
                } else {
                  final selectedVerNum = int.tryParse(val.replaceAll('Version ', ''));
                  final selectedVer = widget.allVersions.firstWhere((v) => v.versionNumber == selectedVerNum);
                  _compareWithSnapshot = selectedVer.snapshot;
                }
              });
            },
          ),
          const SizedBox(height: 24),
          const Text('Differences:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (differences.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Text('No differences found. The versions are identical.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: differences.length,
                itemBuilder: (context, index) {
                  final diff = differences[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          diff['field'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Old Value (Selected Version)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    diff['oldValue'] as String,
                                    style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('New Value ($_compareTargetLabel)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    diff['newValue'] as String,
                                    style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
