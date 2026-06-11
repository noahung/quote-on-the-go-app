import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../components/mesh_background.dart';
import '../../components/curved_header.dart';
import '../../providers/quotation_provider.dart';

// ── Column definitions ───────────────────────────────────────────
class _PipelineColumn {
  final String title;
  final List<String> statuses;
  final Color color;
  final IconData icon;

  const _PipelineColumn({
    required this.title,
    required this.statuses,
    required this.color,
    required this.icon,
  });
}

const _columns = [
  _PipelineColumn(
    title: 'Draft',
    statuses: ['Draft', 'Amended'],
    color: Color(0xFFF57F17),
    icon: LucideIcons.pencil,
  ),
  _PipelineColumn(
    title: 'Sent',
    statuses: ['Sent'],
    color: Color(0xFF1976D2),
    icon: LucideIcons.send,
  ),
  _PipelineColumn(
    title: 'Won',
    statuses: ['Accepted'],
    color: Color(0xFF2E7D32),
    icon: LucideIcons.trophy,
  ),
  _PipelineColumn(
    title: 'Lost',
    statuses: ['Declined'],
    color: Color(0xFFC62828),
    icon: LucideIcons.xCircle,
  ),
];

class KanbanBoardScreen extends ConsumerWidget {
  const KanbanBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotationsAsync = ref.watch(quotationsStreamProvider);

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const CurvedHeader(
              title: 'Sales Pipeline',
            ),
            Expanded(
              child: quotationsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (quotations) => _KanbanBody(quotations: quotations),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KanbanBody extends StatefulWidget {
  final List<Quotation> quotations;
  const _KanbanBody({required this.quotations});

  @override
  State<_KanbanBody> createState() => _KanbanBodyState();
}

class _KanbanBodyState extends State<_KanbanBody> {
  String? _draggingId;
  String? _hoverColTitle;

  void _onDragStarted(String id) => setState(() => _draggingId = id);
  void _onDragEnd() => setState(() {
        _draggingId = null;
        _hoverColTitle = null;
      });
  void _onHover(String? colTitle) {
    if (_hoverColTitle != colTitle) setState(() => _hoverColTitle = colTitle);
  }

  Future<void> _moveCard(
      BuildContext context, Quotation quotation, String newStatus) async {
    if (quotation.status == newStatus) return;
    try {
      await FirebaseFirestore.instance
          .collection('quotations')
          .doc(quotation.id)
          .update({'status': newStatus});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _columns.length,
      itemBuilder: (context, colIndex) {
        final col = _columns[colIndex];
        final cards = widget.quotations
            .where((q) => col.statuses.contains(q.status))
            .toList();
        final isHovered = _hoverColTitle == col.title;

        return DragTarget<Quotation>(
          onWillAcceptWithDetails: (details) {
            _onHover(col.title);
            return !col.statuses.contains(details.data.status);
          },
          onLeave: (_) => _onHover(null),
          onAcceptWithDetails: (details) {
            _onHover(null);
            _moveCard(context, details.data, col.statuses.first);
          },
          builder: (context, candidateData, rejectedData) {
            return _KanbanColumn(
              column: col,
              cards: cards,
              isHovered: isHovered,
              draggingId: _draggingId,
              onDragStarted: _onDragStarted,
              onDragEnd: _onDragEnd,
              onMove: (q, status) => _moveCard(context, q, status),
            );
          },
        );
      },
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final _PipelineColumn column;
  final List<Quotation> cards;
  final bool isHovered;
  final String? draggingId;
  final void Function(String id) onDragStarted;
  final void Function() onDragEnd;
  final void Function(Quotation q, String status) onMove;

  const _KanbanColumn({
    required this.column,
    required this.cards,
    required this.isHovered,
    required this.draggingId,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFF1F2F4);
    final currFmt = NumberFormat.currency(symbol: '£');
    final total = cards.fold(0.0, (acc, q) => acc + q.total);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 256,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: isHovered
            ? column.color.withValues(alpha: isDark ? 0.15 : 0.08)
            : colBg,
        borderRadius: BorderRadius.circular(16),
        border: isHovered
            ? Border.all(color: column.color.withValues(alpha: 0.5), width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
            child: Row(
              children: [
                // Colored dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: column.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  column.title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.75)
                        : const Color(0xFF44546F),
                  ),
                ),
                const SizedBox(width: 6),
                // Count badge — plain text like Trello
                Text(
                  '${cards.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? Colors.white38
                        : const Color(0xFF44546F).withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
                // Total value chip
                if (cards.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: column.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      currFmt.format(total),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: column.color,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── Cards list ──
          Expanded(
            child: cards.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(column.icon,
                              size: 28,
                              color: isDark
                                  ? Colors.white12
                                  : Colors.black.withValues(alpha: 0.12)),
                          const SizedBox(height: 8),
                          Text(
                            'No quotes',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white24
                                  : Colors.black.withValues(alpha: 0.25),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final q = cards[index];
                      final isDragging = draggingId == q.id;
                      return LongPressDraggable<Quotation>(
                        data: q,
                        delay: const Duration(milliseconds: 300),
                        onDragStarted: () => onDragStarted(q.id),
                        onDragEnd: (_) => onDragEnd(),
                        onDraggableCanceled: (_, __) => onDragEnd(),
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: 230,
                            child: Opacity(
                              opacity: 0.9,
                              child: _KanbanCard(
                                quotation: q,
                                accentColor: column.color,
                                isDragging: false,
                                onMove: onMove,
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _KanbanCard(
                            quotation: q,
                            accentColor: column.color,
                            isDragging: true,
                            onMove: onMove,
                          ),
                        ),
                        child: _KanbanCard(
                          quotation: q,
                          accentColor: column.color,
                          isDragging: isDragging,
                          onMove: onMove,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _KanbanCard extends StatelessWidget {
  final Quotation quotation;
  final Color accentColor;
  final bool isDragging;
  final void Function(Quotation q, String status) onMove;

  const _KanbanCard({
    required this.quotation,
    required this.accentColor,
    required this.isDragging,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF22272B) : Colors.white;
    final onCard = isDark ? Colors.white : const Color(0xFF172B4D);
    final subtle = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFF44546F);
    final currFmt = NumberFormat.currency(symbol: '£');
    final dateFmt = DateFormat('d MMM');
    final date = quotation.createdAt ?? DateTime.tryParse(quotation.date);

    const allStatuses = ['Draft', 'Sent', 'Accepted', 'Declined', 'Amended'];
    final otherStatuses =
        allStatuses.where((s) => s != quotation.status).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
            blurRadius: isDragging ? 0 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/quotations/${quotation.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer name + menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        quotation.customerName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: onCard,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // ⋯ Move popup
                    PopupMenuButton<String>(
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      tooltip: 'Move',
                      icon: Icon(Icons.more_horiz,
                          size: 18, color: subtle),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          enabled: false,
                          height: 30,
                          child: Text('Move to…',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey)),
                        ),
                        ...otherStatuses.map((s) => PopupMenuItem(
                              value: s,
                              child: Text(s,
                                  style: const TextStyle(fontSize: 13)),
                            )),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: '__view',
                          child: Text('View Details',
                              style: TextStyle(fontSize: 13)),
                        ),
                      ],
                      onSelected: (val) {
                        if (val == '__view') {
                          context.push('/quotations/${quotation.id}');
                        } else {
                          onMove(quotation, val);
                        }
                      },
                    ),
                  ],
                ),
                  const SizedBox(height: 8),
                  // Meta row: ref number + date
                  Row(
                    children: [
                      Icon(Icons.tag, size: 11, color: subtle),
                      const SizedBox(width: 3),
                      Text(
                        quotation.quotationNumber,
                        style: TextStyle(
                          fontSize: 11,
                          color: subtle,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (date != null) ...[
                        Icon(Icons.calendar_today_outlined,
                            size: 11, color: subtle),
                        const SizedBox(width: 3),
                        Text(
                          dateFmt.format(date),
                          style: TextStyle(fontSize: 11, color: subtle),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Value pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      currFmt.format(quotation.total),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}

