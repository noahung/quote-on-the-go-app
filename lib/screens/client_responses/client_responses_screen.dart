import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../components/curved_header.dart';
import '../../components/mesh_background.dart';
import '../../providers/providers.dart';
import '../../theme/semantic_colors.dart';
import '../../utils/feedback_controller.dart';

/// Inbox of everything customers do in the web client portal: views, comments,
/// acceptances, declines and payments. Lets the business user respond without
/// leaving the app. The customer portal itself stays web-only.
class ClientResponsesScreen extends ConsumerStatefulWidget {
  const ClientResponsesScreen({super.key});

  @override
  ConsumerState<ClientResponsesScreen> createState() =>
      _ClientResponsesScreenState();
}

class _ClientResponsesScreenState
    extends ConsumerState<ClientResponsesScreen> {
  String _filter = 'all';

  static const _filters = <String, String>{
    'all': 'All',
    'commented': 'Comments',
    'approved': 'Accepted',
    'declined': 'Declined',
    'viewed': 'Viewed',
    'paid': 'Paid',
  };

  @override
  void initState() {
    super.initState();
    // Mark the inbox as seen once it has been opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clientActivitySeenProvider.notifier).markAllSeen();
    });
  }

  bool _matchesFilter(ClientActivityItem item) {
    if (_filter == 'all') return true;
    final type = item.activityType;
    final desc = item.description.toLowerCase();
    switch (_filter) {
      case 'commented':
        return type == 'commented';
      case 'approved':
        return type == 'approved' || desc.contains('accept');
      case 'declined':
        return desc.contains('declin') || desc.contains('reject');
      case 'viewed':
        return type == 'viewed';
      case 'paid':
        return desc.contains('paid') || desc.contains('payment');
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(companyCustomerActivityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const CurvedHeader(
              title: 'Client Responses',
              showBackButton: true,
            ),
            _buildFilterChips(isDark),
            Expanded(
              child: activityAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _buildError(context, e),
                data: (items) {
                  final filtered = items.where(_matchesFilter).toList();
                  if (filtered.isEmpty) return _buildEmpty(context);
                  return RefreshIndicator(
                    onRefresh: () async => ref
                        .refresh(companyCustomerActivityProvider.future),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) =>
                          _ActivityCard(item: filtered[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _filters.entries.map((entry) {
          final selected = _filter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              labelStyle: TextStyle(
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              selected: selected,
              selectedColor: const Color(0xFFF4781F),
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              shape: const StadiumBorder(),
              side: BorderSide.none,
              showCheckmark: false,
              onSelected: (_) => setState(() => _filter = entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(LucideIcons.messageSquare,
            size: 64, color: Colors.grey.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        const Center(
          child: Text('No client responses yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            'When customers view, comment on, accept, decline or pay documents in the portal, it shows up here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.triangleAlert,
                size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('Failed to load responses: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () =>
                  ref.invalidate(companyCustomerActivityProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends ConsumerWidget {
  final ClientActivityItem item;
  const _ActivityCard({required this.item});

  ({IconData icon, Color color, String label}) _visuals(
      SemanticColors colors) {
    final type = item.activityType;
    final desc = item.description.toLowerCase();
    if (type == 'commented') {
      return (icon: LucideIcons.messageCircle, color: Colors.blue, label: 'Comment');
    }
    if (type == 'approved' || desc.contains('accept')) {
      return (icon: LucideIcons.checkCircle, color: colors.success, label: 'Accepted');
    }
    if (desc.contains('declin') || desc.contains('reject')) {
      return (icon: LucideIcons.xCircle, color: colors.error, label: 'Declined');
    }
    if (desc.contains('paid') || desc.contains('payment')) {
      return (icon: LucideIcons.creditCard, color: colors.success, label: 'Paid');
    }
    if (type == 'viewed') {
      return (icon: LucideIcons.eye, color: Colors.grey, label: 'Viewed');
    }
    return (icon: LucideIcons.activity, color: const Color(0xFFF4781F), label: 'Update');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).extension<SemanticColors>()!;
    final v = _visuals(colors);
    final isComment = item.activityType == 'commented';
    final docPath =
        '/${item.documentType == 'invoice' ? 'invoices' : 'quotations'}/${item.documentId}';

    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(docPath),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: v.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(v.icon, size: 18, color: v.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.actorName,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _relativeTime(item.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: v.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      v.label,
                      style: TextStyle(
                          color: v.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.description,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    item.documentType == 'invoice'
                        ? LucideIcons.receipt
                        : LucideIcons.fileText,
                    size: 14,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.documentType == 'invoice' ? 'Invoice' : 'Quotation',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const Spacer(),
                  if (isComment)
                    TextButton.icon(
                      onPressed: () => _showReplySheet(context, ref),
                      icon: const Icon(LucideIcons.messageSquare, size: 16),
                      label: const Text('Reply'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFF4781F),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => context.push(docPath),
                    icon: const Icon(LucideIcons.arrowRight, size: 16),
                    label: const Text('Open'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          isDark ? Colors.white70 : Colors.black54,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReplySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClientReplySheet(
        documentId: item.documentId,
        documentType: item.documentType,
        customerName: item.actorName,
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM yyyy').format(time);
  }
}

/// Bottom sheet for composing a customer-visible reply.
class ClientReplySheet extends ConsumerStatefulWidget {
  final String documentId;
  final String documentType;
  final String customerName;

  const ClientReplySheet({
    super.key,
    required this.documentId,
    required this.documentType,
    required this.customerName,
  });

  @override
  ConsumerState<ClientReplySheet> createState() => _ClientReplySheetState();
}

class _ClientReplySheetState extends ConsumerState<ClientReplySheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final companyId = ref.read(companyIdProvider);
    final user = ref.read(currentUserProvider);
    if (companyId == null || user == null) {
      ref.read(feedbackControllerProvider).error(context, 'Not signed in.');
      return;
    }

    setState(() => _sending = true);
    try {
      await ref.read(portalActivityRepositoryProvider).addPublicReply(
            documentId: widget.documentId,
            documentType: widget.documentType,
            content: text,
            userId: user.uid,
            userName: user.displayName ?? user.email ?? 'Team',
            userEmail: user.email ?? '',
            companyId: companyId,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ref
          .read(feedbackControllerProvider)
          .success(context, 'Reply sent to ${widget.customerName}');
    } catch (e) {
      if (mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Failed: $e');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white30 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Reply to ${widget.customerName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Your reply will be visible to the customer in their portal.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type your reply…',
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF4781F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.send, size: 18),
                label: Text(_sending ? 'Sending…' : 'Send Reply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
