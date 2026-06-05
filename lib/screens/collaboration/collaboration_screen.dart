import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/mesh_background.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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

    final commentCount = commentsAsync.valueOrNull?.length ?? 0;
    final versionCount = versionsAsync.valueOrNull?.length ?? 0;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF6B00), Color(0xFFF4781F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
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
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.documentType == 'quotation' ? 'Quote Collaboration' : 'Invoice Collaboration',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Card(
                            elevation: 0,
                            color: Colors.white24,
                            shape: const StadiumBorder(),
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              child: Text(
                                '#$docNumber',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 16),
            // Segmented Toggles
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicatorColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: isDark ? const Color(0xFFF4781F).withValues(alpha: 0.15) : const Color(0xFFF4781F).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: const Color(0xFFF4781F),
                  unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: [
                    Tab(text: 'Versions ($versionCount)'),
                    Tab(text: 'Team Comments ($commentCount)'),
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
                  _buildCommentsTab(context, commentsAsync, semanticColors, isDark),
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
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Comparing versions - coming soon')),
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

  Widget _buildCommentsTab(BuildContext context, AsyncValue<List<InternalComment>> commentsAsync, SemanticColors colors, bool isDark) {
    return Column(
      children: [
        Expanded(
          child: commentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (comments) {
              if (comments.isEmpty) {
                return const Center(child: Text('No comments posted yet.', style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  // Compute initials
                  final String initials = comment.authorName.isNotEmpty
                      ? comment.authorName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                      : 'AN';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFF4781F).withValues(alpha: 0.12),
                          radius: 18,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Color(0xFFF4781F),
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    comment.authorName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    _formatTimeAgo(comment.createdAt),
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
                                  comment.content,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
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
}
