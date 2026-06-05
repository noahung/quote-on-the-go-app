import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../components/glass_card.dart';
import '../../components/curved_header.dart';
import '../../components/mesh_background.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  void _action(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
