import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../theme/semantic_colors.dart';
import '../../components/curved_header.dart';
import '../../components/mesh_background.dart';
import '../../components/glass_card.dart';
import '../../components/custom_date_time_picker.dart';
import '../../utils/feedback_controller.dart';
import '../../models/feedback_type.dart';

const _webAppBaseUrl = 'https://app.quoteonthego.co.uk';

class InvoiceDetailScreen extends ConsumerWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  Color _getStatusColor(String status, SemanticColors semanticColors) {
    switch (status) {
      case 'Paid':
        return semanticColors.success;
      case 'Sent':
        return semanticColors.info;
      case 'Overdue':
        return semanticColors.error;
      case 'Draft':
        return semanticColors.accentOrange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _sendByEmail(
      BuildContext context, WidgetRef ref, invoice, {DateTime? sendAt}) async {
    try {
      final body = {
        'invoiceId': invoice.id,
        'customerEmail': invoice.customerEmail,
        'customerName': invoice.customerName,
      };
      if (sendAt != null) {
        body['sendAt'] = sendAt.toUtc().toIso8601String();
      }

      final response = await http.post(
        Uri.parse('$_webAppBaseUrl/api/send-invoice'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (context.mounted) {
        if (response.statusCode == 200) {
          final isScheduled = sendAt != null;
          await ref.read(feedbackControllerProvider).showCelebration(
            context: context,
            type: CelebrationType.send,
            title: isScheduled ? 'Email Scheduled' : 'Email Sent',
            subtitle: isScheduled
                ? 'Your invoice will be sent at the scheduled time'
                : 'Your invoice has been sent to the customer',
          );
        } else {
          String err = 'Send failed (${response.statusCode})';
          try {
            err = jsonDecode(response.body)['error'] ?? err;
          } catch (_) {}
          ref.read(feedbackControllerProvider).error(context, 'Error: $err');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Error: $e');
      }
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
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
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

  Future<void> _showSendOptions(
      BuildContext context, WidgetRef ref, invoice) async {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Send Invoice',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Select how you want to send this invoice to ${invoice.customerName}.',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Icon(Icons.send, color: colorScheme.primary),
              title: const Text('Send Immediately', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Deliver the email to the customer right now'),
              onTap: () {
                Navigator.pop(ctx);
                _sendByEmail(context, ref, invoice);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.calendar_month, color: colorScheme.primary),
              title: const Text('Schedule for Later', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Select a date and time to deliver the email'),
              onTap: () async {
                Navigator.pop(ctx);
                final scheduledDateTime = await showModalBottomSheet<DateTime>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => CustomDateTimePickerSheet(
                    initialDateTime: DateTime.now().add(const Duration(minutes: 5)),
                    title: 'Schedule for Later',
                  ),
                );
                if (scheduledDateTime != null && context.mounted) {
                  if (scheduledDateTime.isBefore(DateTime.now())) {
                    ref.read(feedbackControllerProvider).error(context, 'Scheduled time must be in the future.');
                    return;
                  }
                  _sendByEmail(context, ref, invoice, sendAt: scheduledDateTime);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _markPaid(
      BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref
          .read(invoiceRepositoryProvider)
          .updateInvoiceStatus(id, 'Paid');
      if (context.mounted) {
        ref.read(feedbackControllerProvider).success(context, 'Invoice marked as paid.');
      }
    } catch (e) {
      if (context.mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Failed to update status: $e');
      }
    }
  }

  Future<void> _sendReminder(
      BuildContext context, WidgetRef ref, invoice) async {
    // Send email reminder
    await _sendByEmail(context, ref, invoice);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(invoiceProvider(invoiceId));
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (invoice == null) {
      return const MeshBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              CurvedHeader(title: 'Invoice Details'),
              Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      );
    }

    final statusColor = _getStatusColor(invoice.status, semanticColors);

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            CurvedHeader(
              title: 'Invoice #${invoice.invoiceNumber.replaceFirst('INV-', '')}',
              actions: [
                IconButton(
                  icon: const Icon(Icons.forum_outlined, color: Colors.white),
                  tooltip: 'Collaboration & History',
                  onPressed: () =>
                      context.push('/collaboration/invoice/${invoice.id}'),
                ),
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.white),
                  tooltip: 'View as Client',
                  onPressed: () =>
                      context.push('/invoices/${invoice.id}/portal'),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      context.push('/invoices/${invoice.id}/edit',
                          extra: invoice);
                    } else if (value == 'send') {
                      await _showSendOptions(context, ref, invoice);
                    } else if (value == 'mark_paid') {
                      await _markPaid(context, ref, invoice.id);
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
                    PopupMenuItem(
                      value: 'send',
                      child: Row(children: [
                        Icon(Icons.email_outlined, color: semanticColors.info),
                        const SizedBox(width: 8),
                        const Text('Send by Email')
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'mark_paid',
                      child: Row(children: [
                        Icon(Icons.check_circle_outline,
                            color: semanticColors.success),
                        const SizedBox(width: 8),
                        const Text('Mark as Paid')
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, color: semanticColors.error),
                        const SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(color: semanticColors.error))
                      ]),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Summary Section
                    Center(
                      child: Column(
                        children: [
                          Text(
                            NumberFormat.currency(symbol: '£')
                                .format(invoice.total),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.24),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  invoice.status == 'Paid'
                                      ? Icons.check_circle
                                      : (invoice.status == 'Overdue'
                                          ? Icons.warning
                                          : Icons.info_outline),
                                  size: 14,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  invoice.status,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Client Info Card
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.customerName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (invoice.customerAddress != null &&
                              invoice.customerAddress!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: colorScheme.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    invoice.customerAddress!,
                                    style: TextStyle(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.65),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Invoice Schedule Card
                    GlassCard(
                      child: Column(
                        children: [
                          _DetailRow(
                            label: 'Issue Date',
                            value: invoice.date,
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            label: 'Due Date',
                            value: invoice.dueDate,
                            valueColor: invoice.status == 'Overdue'
                                ? semanticColors.error
                                : (invoice.status == 'Paid'
                                    ? semanticColors.success
                                    : semanticColors.accentOrange),
                          ),
                          const SizedBox(height: 12),
                          const _DetailRow(
                            label: 'Payment Terms',
                            value: 'Net 14',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Items List Card
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...invoice.items.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.description,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Qty ${item.quantity} × ${NumberFormat.currency(symbol: '£').format(item.unitPrice)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      NumberFormat.currency(symbol: '£')
                                          .format(item.total),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 8),
                          Divider(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal',
                                style: TextStyle(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.65),
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                NumberFormat.currency(symbol: '£')
                                    .format(invoice.subtotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          if (invoice.taxAmount != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Taxes (${invoice.taxRate}%)',
                                  style: TextStyle(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.65),
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  NumberFormat.currency(symbol: '£')
                                      .format(invoice.taxAmount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                NumberFormat.currency(symbol: '£')
                                    .format(invoice.total),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // PDF Card
                    GlassCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: semanticColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.picture_as_pdf,
                              color: semanticColors.error,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Invoice_${invoice.invoiceNumber.replaceFirst('INV-', '')}_Final.pdf',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: const StadiumBorder(),
                              side: BorderSide(color: colorScheme.outline),
                            ),
                            onPressed: () async {
                              final uri = Uri.parse('$_webAppBaseUrl/api/invoices/${invoice.id}/pdf');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else if (context.mounted) {
                                ref.read(feedbackControllerProvider).error(context, 'Could not open PDF.');
                              }
                            },
                            child: Text(
                              'View PDF',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bottom Actions
                    if (invoice.status != 'Paid') ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () => _markPaid(context, ref, invoice.id),
                          child: const Text(
                            'Mark as Paid',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: const StadiumBorder(),
                            side: BorderSide(
                              color: colorScheme.outline,
                              width: 1.5,
                            ),
                          ),
                          onPressed: () =>
                              _sendReminder(context, ref, invoice),
                          child: Text(
                            'Send Reminder',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
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
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
