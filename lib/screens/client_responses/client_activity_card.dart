import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../components/glass_card.dart';
import '../../providers/collaboration_provider.dart';
import '../../theme/semantic_colors.dart';
import 'client_responses_screen.dart' show ClientReplySheet;

/// Inline card for a quotation/invoice detail screen that surfaces what the
/// customer has done in the web portal (viewed, commented, accepted, declined,
/// paid) and lets the business user reply without leaving the document.
class ClientActivityCard extends ConsumerWidget {
  final String documentId;
  final String documentType; // 'quotation' | 'invoice'
  final String customerName;

  const ClientActivityCard({
    super.key,
    required this.documentId,
    required this.documentType,
    required this.customerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(documentTimelineProvider(
        (documentId: documentId, documentType: documentType)));
    final colors = Theme.of(context).extension<SemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.messageCircle,
                  size: 18, color: colors.accentPrimary),
              const SizedBox(width: 8),
              const Text('Client Activity',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: () => context
                    .push('/collaboration/$documentType/$documentId'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          timelineAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Could not load activity: $e',
                  style: TextStyle(fontSize: 12, color: colors.error)),
            ),
            data: (items) {
              final customerItems =
                  items.where((i) => i.actor['userId'] == 'customer').toList();
              if (customerItems.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No client activity yet. When $customerName interacts with this $documentType in the portal, it appears here.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                );
              }
              final recent = customerItems.take(4).toList();
              return Column(
                children: [
                  ...recent.map((item) => _ActivityRow(
                        item: item,
                        colors: colors,
                        isDark: isDark,
                      )),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showReplySheet(context),
                      icon: const Icon(LucideIcons.messageSquare, size: 16),
                      label: const Text('Reply to client'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.accentPrimary,
                        side: BorderSide(
                            color:
                                colors.accentPrimary.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showReplySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClientReplySheet(
        documentId: documentId,
        documentType: documentType,
        customerName: customerName,
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityTimelineItem item;
  final SemanticColors colors;
  final bool isDark;

  const _ActivityRow({
    required this.item,
    required this.colors,
    required this.isDark,
  });

  ({IconData icon, Color color}) get _visuals {
    final type = item.activityType;
    final desc = item.description.toLowerCase();
    if (type == 'commented') return (icon: LucideIcons.messageCircle, color: Colors.blue);
    if (type == 'approved' || desc.contains('accept')) {
      return (icon: LucideIcons.checkCircle, color: colors.success);
    }
    if (desc.contains('declin') || desc.contains('reject')) {
      return (icon: LucideIcons.xCircle, color: colors.error);
    }
    if (desc.contains('paid') || desc.contains('payment')) {
      return (icon: LucideIcons.creditCard, color: colors.success);
    }
    if (type == 'viewed') return (icon: LucideIcons.eye, color: Colors.grey);
    return (icon: LucideIcons.activity, color: colors.accentPrimary);
  }

  @override
  Widget build(BuildContext context) {
    final v = _visuals;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: v.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(v.icon, size: 14, color: v.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: const TextStyle(fontSize: 13, height: 1.3),
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
        ],
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
