import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/providers.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Sent':
        return Colors.blue;
      case 'Overdue':
        return Colors.red;
      case 'Draft':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _sendByEmail(
      BuildContext context, WidgetRef ref, invoice) async {
    final repo = ref.read(invoiceRepositoryProvider);
    final portalLink =
        'https://app.quoteonthego.co.uk/portal/invoices/${invoice.id}';
    final subject = Uri.encodeComponent(
        'Invoice ${invoice.invoiceNumber} from ${invoice.company?.name ?? 'Us'}');
    final body = Uri.encodeComponent(
        'Dear ${invoice.customerName},\n\nPlease find your invoice attached.\n\nView it online: $portalLink\n\nTotal: £${invoice.total.toStringAsFixed(2)}\nDue: ${invoice.dueDate}\n\nKind regards');
    final mailUri = Uri.parse(
        'mailto:${invoice.customerEmail}?subject=$subject&body=$body');

    await repo.updateInvoiceStatus(invoice.id, 'Sent');
    try {
      await launchUrl(mailUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(mailUri);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated to Sent')),
      );
    }
  }

  Future<void> _deleteInvoice(
      BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(invoiceRepositoryProvider).deleteInvoice(id);
      if (context.mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(invoiceProvider(invoiceId));

    if (invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Invoice Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility),
            tooltip: 'View as Client',
            onPressed: () => context.push('/invoices/${invoice.id}/portal'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                context.push('/invoices/${invoice.id}/edit', extra: invoice);
              } else if (value == 'send') {
                await _sendByEmail(context, ref, invoice);
              } else if (value == 'mark_paid') {
                await ref
                    .read(invoiceRepositoryProvider)
                    .updateInvoiceStatus(invoice.id, 'Paid');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invoice marked as paid')),
                  );
                }
              } else if (value == 'delete') {
                await _deleteInvoice(context, ref, invoice.id);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined),
                  SizedBox(width: 8),
                  Text('Edit')
                ]),
              ),
              const PopupMenuItem(
                value: 'send',
                child: Row(children: [
                  Icon(Icons.email_outlined, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Send by Email')
                ]),
              ),
              const PopupMenuItem(
                value: 'mark_paid',
                child: Row(children: [
                  Icon(Icons.check_circle_outline, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Mark as Paid')
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red))
                ]),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and Number
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(invoice.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    invoice.status,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(invoice.status),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  invoice.invoiceNumber,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Customer Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      invoice.customerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(invoice.customerEmail),
                    if (invoice.customerPhone != null) ...[
                      const SizedBox(height: 4),
                      Text(invoice.customerPhone!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Invoice Details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoice Details',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Issue Date', value: invoice.date),
                    const SizedBox(height: 8),
                    _DetailRow(label: 'Due Date', value: invoice.dueDate),
                    if (invoice.quotationNumber != null) ...[
                      const SizedBox(height: 8),
                      _DetailRow(
                        label: 'From Quotation',
                        value: invoice.quotationNumber!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Items
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Items',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...invoice.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(item.description),
                              ),
                              Expanded(
                                child: Text(
                                  '${item.quantity}x',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  NumberFormat.currency(symbol: '£')
                                      .format(item.total),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text(
                          NumberFormat.currency(symbol: '£')
                              .format(invoice.subtotal),
                        ),
                      ],
                    ),
                    if (invoice.taxAmount != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tax (${invoice.taxRate}%)'),
                          Text(
                            NumberFormat.currency(symbol: '£')
                                .format(invoice.taxAmount),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          NumberFormat.currency(symbol: '£')
                              .format(invoice.total),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
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
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
