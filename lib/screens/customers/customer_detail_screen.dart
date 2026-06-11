import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/interaction_log.dart';
import '../../providers/providers.dart';
import '../../components/glass_card.dart';
import '../../components/curved_header.dart';
import '../../components/mesh_background.dart';
import '../../utils/feedback_controller.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  String get customerId => widget.customerId;

  void _action(BuildContext context, String message) {
    ref.read(feedbackControllerProvider).success(context, message);
  }

  void _showLogInteractionSheet() {
    final typeOptions = [
      ('call', Icons.phone_outlined, 'Call'),
      ('email', Icons.mail_outline, 'Email'),
      ('meeting', Icons.handshake_outlined, 'Meeting'),
      ('job_log', Icons.work_outline, 'Job Note'),
    ];
    String selectedType = 'call';
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx2, setModal) {
            final isDark = Theme.of(ctx2).brightness == Brightness.dark;
            final fill = isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.04);
            final border = OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            );
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Log Interaction',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  // Type selector chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: typeOptions.map((opt) {
                        final isSelected = selectedType == opt.$1;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setModal(() => selectedType = opt.$1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFF4781F)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.06)),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(opt.$2,
                                      size: 14,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white70
                                              : const Color(0xFF44546F))),
                                  const SizedBox(width: 6),
                                  Text(
                                    opt.$3,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white70
                                              : const Color(0xFF44546F)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'Summary (e.g. Discussed quote revision)',
                      filled: true, fillColor: fill,
                      border: border, enabledBorder: border,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFF4781F), width: 1.5),
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Notes (optional)',
                      filled: true, fillColor: fill,
                      border: border, enabledBorder: border,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFF4781F), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF4781F),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () async {
                        if (titleCtrl.text.trim().isEmpty) return;
                        final companyId = ref.read(companyIdProvider) ?? '';
                        final user = ref.read(currentUserProvider);
                        final customer = ref.read(customerProvider(customerId));
                        final cid = customer?.id ?? customerId;
                        await ref.read(interactionLogRepositoryProvider).addLog(
                          companyId: companyId,
                          customerId: cid,
                          type: selectedType,
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                          createdBy: user?.displayName ?? user?.email ?? 'User',
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save Log',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = ref.watch(customerProvider(customerId));
    if (customer == null) {
      return const MeshBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Fetch actual quotations and invoices
    final quotations = ref.watch(quotationsProvider);
    final invoices = ref.watch(invoicesProvider);
    final jobs = ref.watch(scheduleStreamProvider).valueOrNull ?? [];
    final AsyncValue<List<InteractionLog>> interactionLogsAsync =
        ref.watch(customerInteractionLogsProvider(customer.id));

    final customerQuotations = quotations
        .where((q) => q.customerEmail == customer.email || q.customerName == customer.name)
        .toList();
    final customerInvoices = invoices
        .where((i) => i.customerEmail == customer.email || i.customerName == customer.name)
        .toList();
    final customerJobs = jobs
        .where((j) => j.customerId == customer.id || j.customerName == customer.name)
        .toList();

    // Calculate balances
    final outstandingBalance = customerInvoices
        .where((i) => i.status == 'Pending' || i.status == 'Overdue' || i.status == 'Sent')
        .fold(0.0, (sum, i) => sum + i.total);
    final totalPaid = customerInvoices
        .where((i) => i.status == 'Paid')
        .fold(0.0, (sum, i) => sum + i.total);

    // Build activities list
    final List<_ActivityItem> activities = [];

    for (final j in customerJobs) {
      activities.add(_ActivityItem(
        title: j.title,
        subtitle: 'Job #${j.id.substring(0, j.id.length > 6 ? 6 : j.id.length)}',
        status: j.status ?? 'Scheduled',
        icon: Icons.construction,
        date: DateTime.tryParse(j.start) ?? DateTime.now(),
        route: '/schedule/job/${j.id}',
      ));
    }

    for (final q in customerQuotations) {
      activities.add(_ActivityItem(
        title: q.customerName,
        subtitle: q.quotationNumber,
        status: q.status,
        icon: Icons.description,
        date: DateTime.tryParse(q.date) ?? q.createdAt ?? DateTime.now(),
        route: '/quotations/${q.id}',
      ));
    }

    for (final i in customerInvoices) {
      activities.add(_ActivityItem(
        title: i.customerName,
        subtitle: i.invoiceNumber,
        status: i.status,
        icon: Icons.receipt,
        date: DateTime.tryParse(i.date) ?? i.createdAt ?? DateTime.now(),
        route: '/invoices/${i.id}',
      ));
    }

    // Sort descending by date
    activities.sort((a, b) => b.date.compareTo(a.date));

    // Get initials
    String initials = '';
    if (customer.name.trim().isNotEmpty) {
      final parts = customer.name.trim().split(' ');
      if (parts.length > 1) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = parts[0].substring(0, parts[0].length > 1 ? 2 : 1).toUpperCase();
      }
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showLogInteractionSheet,
          backgroundColor: const Color(0xFFF4781F),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_comment_outlined),
          label: const Text('Log', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: Column(
          children: [
            CurvedHeader(
              title: 'Customer Details',
              actions: [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      context.push('/customers/$customerId/edit');
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 40),
                child: Column(
                  children: [
                    // Profile Card
                    GlassCard(
                      borderRadius: BorderRadius.circular(24),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFE8D6),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFF4781F),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            customer.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            customer.createdAt != null
                                ? 'Client since ${DateFormat('MMMM yyyy').format(customer.createdAt!)}'
                                : 'Client Contact',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildCircularAction(
                                icon: Icons.call,
                                label: 'Call',
                                onTap: () {
                                  if (customer.phone != null) {
                                    _action(context, 'Calling ${customer.name} (${customer.phone})...');
                                  } else {
                                    _action(context, 'No phone number available.');
                                  }
                                },
                              ),
                              _buildCircularAction(
                                icon: Icons.mail,
                                label: 'Email',
                                onTap: () => _action(context, 'Emailing ${customer.email}...'),
                              ),
                              _buildCircularAction(
                                icon: Icons.chat,
                                label: 'Message',
                                onTap: () {
                                  if (customer.phone != null) {
                                    _action(context, 'Messaging ${customer.name} (${customer.phone})...');
                                  } else {
                                    _action(context, 'No phone number available.');
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Contact Info Card
                    GlassCard(
                      borderRadius: BorderRadius.circular(24),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildContactRow(
                            icon: Icons.call,
                            label: 'PHONE',
                            value: customer.phone ?? 'N/A',
                          ),
                          _buildDivider(isDark),
                          _buildContactRow(
                            icon: Icons.mail,
                            label: 'EMAIL',
                            value: customer.email,
                          ),
                          _buildDivider(isDark),
                          _buildContactRow(
                            icon: Icons.location_on,
                            label: 'ADDRESS',
                            value: customer.address ?? 'N/A',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Financial Summary Card
                    GlassCard(
                      borderRadius: BorderRadius.circular(24),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Financial Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE8E6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Outstanding Balance',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFC5221F),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  NumberFormat.currency(symbol: '£').format(outstandingBalance),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFFC5221F),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F4EA),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Paid',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF137333),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  NumberFormat.currency(symbol: '£').format(totalPaid),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF137333),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // CRM Interaction Timeline
                    _CrmTimelineCard(
                      logsAsync: interactionLogsAsync,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 20),

                    // Recent Activity Card
                    GlassCard(
                      borderRadius: BorderRadius.circular(24),
                      padding: const EdgeInsets.all(20),
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
                          const SizedBox(height: 16),
                          if (activities.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Text(
                                  'No recent activity found.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: activities.length > 5 ? 5 : activities.length,
                              itemBuilder: (context, index) {
                                final act = activities[index];
                                return InkWell(
                                  onTap: () => context.push(act.route),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(act.icon, color: Colors.grey, size: 20),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                act.title,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                act.subtitle,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _ActivityStatusBadge(status: act.status),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE8D6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFF4781F), size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.grey, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 16,
      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
    );
  }
}

class _ActivityItem {
  final String title;
  final String subtitle;
  final String status;
  final IconData icon;
  final DateTime date;
  final String route;

  _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.icon,
    required this.date,
    required this.route,
  });
}

// ─────────────────────────────────────────────────────────────────
// CRM Interaction Timeline Card
// ─────────────────────────────────────────────────────────────────
class _CrmTimelineCard extends StatelessWidget {
  final AsyncValue<List<InteractionLog>> logsAsync;
  final bool isDark;
  const _CrmTimelineCard({required this.logsAsync, required this.isDark});

  IconData _iconForType(String type) {
    switch (type) {
      case 'call': return Icons.phone_outlined;
      case 'email': return Icons.mail_outline;
      case 'meeting': return Icons.handshake_outlined;
      case 'job_log': return Icons.work_outline;
      case 'portal_view': return Icons.visibility_outlined;
      default: return Icons.chat_bubble_outline;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'call': return Colors.green;
      case 'email': return Colors.blue;
      case 'meeting': return Colors.purple;
      case 'job_log': return const Color(0xFFF4781F);
      case 'portal_view': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Interaction Timeline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e',
                style: const TextStyle(color: Colors.red, fontSize: 12)),
            data: (logs) {
              if (logs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No interactions logged yet.\nTap "Log" to record a call, email, or meeting.',
                    style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final type = log.type;
                  final ts = log.timestamp;
                  final timeStr = ts != null
                      ? DateFormat('d MMM, HH:mm').format(ts.toLocal())
                      : '';
                  final isLast = index == logs.length - 1;
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeline spine
                        SizedBox(
                          width: 32,
                          child: Column(
                            children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: _colorForType(type).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_iconForType(type),
                                    size: 14, color: _colorForType(type)),
                              ),
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: colorScheme.outline.withValues(alpha: 0.15),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Content
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        log.title,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(timeStr,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.45))),
                                  ],
                                ),
                                if ((log.description)?.isNotEmpty ?? false) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    log.description!,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.6)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 3),
                                Text(
                                  'by ${log.createdBy}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.4)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityStatusBadge extends StatelessWidget {
  final String status;

  const _ActivityStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color textColor;

    switch (status) {
      case 'Accepted':
      case 'Paid':
        color = const Color(0xFFE6F4EA);
        textColor = const Color(0xFF137333);
        break;
      case 'Sent':
      case 'In Progress':
        color = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1976D2);
        break;
      case 'Declined':
      case 'Overdue':
        color = const Color(0xFFFCE8E6);
        textColor = const Color(0xFFC5221F);
        break;
      case 'Draft':
      default:
        color = const Color(0xFFFFF8E1);
        textColor = const Color(0xFFF57F17);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
