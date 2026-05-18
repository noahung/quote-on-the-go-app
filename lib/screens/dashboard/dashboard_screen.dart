import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _formatCurrency(double value) {
    return NumberFormat.currency(symbol: '£', decimalDigits: 2).format(value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalRevenue = ref.watch(totalRevenueProvider);
    final outstandingRevenue = ref.watch(outstandingRevenueProvider);
    final activeInvoicesCount = ref.watch(activeInvoicesCountProvider);
    final overdueInvoicesCount = ref.watch(overdueInvoicesCountProvider);
    final pendingQuotationsCount = ref.watch(pendingQuotationsCountProvider);
    final acceptedQuotationsCount = ref.watch(acceptedQuotationsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh data by invalidating providers
          ref.invalidate(quotationsStreamProvider);
          ref.invalidate(invoicesStreamProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              Text(
                'Welcome back!',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Here\'s an overview of your business',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // KPI Cards Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  _KpiCard(
                    title: 'Total Revenue',
                    value: _formatCurrency(totalRevenue),
                    icon: Icons.paid,
                    color: colorScheme.primary,
                    subtitle: 'All time paid',
                  ),
                  _KpiCard(
                    title: 'Outstanding',
                    value: _formatCurrency(outstandingRevenue),
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                    subtitle: 'Unpaid invoices',
                  ),
                  _KpiCard(
                    title: 'Active Invoices',
                    value: activeInvoicesCount.toString(),
                    icon: Icons.receipt_long,
                    color: Colors.blue,
                    subtitle: 'Sent/Overdue',
                  ),
                  _KpiCard(
                    title: 'Pending Quotes',
                    value: pendingQuotationsCount.toString(),
                    icon: Icons.description,
                    color: Colors.purple,
                    subtitle: 'Draft/Sent',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick Actions
              Text(
                'Quick Actions',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // New Quotation Button
              _QuickActionCard(
                title: 'Create Quotation',
                subtitle: 'Create a new quote for a customer',
                icon: Icons.add_circle_outline,
                color: colorScheme.primary,
                onTap: () => context.push('/quotations/new'),
              ),
              const SizedBox(height: 8),
              _QuickActionCard(
                title: 'Create Invoice',
                subtitle: 'Generate an invoice from a quote',
                icon: Icons.receipt,
                color: Colors.green,
                onTap: () => context.push('/invoices/new'),
              ),
              const SizedBox(height: 8),
              _QuickActionCard(
                title: 'Add Customer',
                subtitle: 'Add a new customer to your list',
                icon: Icons.person_add,
                color: Colors.blue,
                onTap: () => context.push('/customers/new'),
              ),
              const SizedBox(height: 8),
              _QuickActionCard(
                title: 'Expenses',
                subtitle: 'Track business spending',
                icon: Icons.receipt_long,
                color: Colors.deepOrange,
                onTap: () => context.push('/expenses'),
              ),
              const SizedBox(height: 8),
              _QuickActionCard(
                title: 'Services',
                subtitle: 'Manage service catalog',
                icon: Icons.construction,
                color: Colors.teal,
                onTap: () => context.push('/services'),
              ),
              const SizedBox(height: 8),
              _QuickActionCard(
                title: 'Schedule',
                subtitle: 'View calendar events',
                icon: Icons.calendar_month,
                color: Colors.indigo,
                onTap: () => context.push('/schedule'),
              ),
              const SizedBox(height: 8),
              _QuickActionCard(
                title: 'Workflows',
                subtitle: 'Automate follow-ups',
                icon: Icons.auto_fix_high,
                color: Colors.purple,
                onTap: () => context.push('/workflows'),
              ),
              const SizedBox(height: 24),

              // Recent Activity Summary
              Text(
                'Status Overview',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _StatusRow(
                        label: 'Overdue Invoices',
                        value: overdueInvoicesCount.toString(),
                        color: Colors.red,
                      ),
                      const Divider(),
                      _StatusRow(
                        label: 'Accepted Quotations',
                        value: acceptedQuotationsCount.toString(),
                        color: Colors.green,
                      ),
                      const Divider(),
                      _StatusRow(
                        label: 'Active Quotes',
                        value: pendingQuotationsCount.toString(),
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatusRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
