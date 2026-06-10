import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../theme/semantic_colors.dart';
import '../../components/curved_header.dart';
import '../../components/mesh_background.dart';
import '../../components/glass_card.dart';
import '../../components/custom_date_time_picker.dart';

const _webAppBaseUrl = 'https://app.quoteonthego.co.uk';

class QuotationDetailScreen extends ConsumerWidget {
  final String quotationId;

  const QuotationDetailScreen({super.key, required this.quotationId});

  Color _getStatusColor(SemanticColors colors, String status) {
    switch (status) {
      case 'Accepted':
        return colors.success;
      case 'Sent':
        return colors.info;
      case 'Declined':
        return colors.error;
      case 'Draft':
        return colors.warning;
      default:
        return Colors.grey;
    }
  }

  Future<void> _sendByEmail(
      BuildContext context, WidgetRef ref, quotation, {DateTime? sendAt}) async {
    try {
      final body = {
        'quotationId': quotation.id,
        'customerEmail': quotation.customerEmail,
        'customerName': quotation.customerName,
      };
      if (sendAt != null) {
        body['sendAt'] = sendAt.toUtc().toIso8601String();
      }

      final response = await http.post(
        Uri.parse('$_webAppBaseUrl/api/send-quotation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (context.mounted) {
        if (response.statusCode == 200) {
          final isScheduled = sendAt != null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(isScheduled
                    ? 'Quotation scheduled successfully via email'
                    : 'Quotation sent successfully via email')),
          );
        } else {
          String err = 'Send failed (${response.statusCode})';
          try {
            err = jsonDecode(response.body)['error'] ?? err;
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $err'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showSendOptions(
      BuildContext context, WidgetRef ref, quotation) async {
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
              'Send Quotation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Select how you want to send this quotation to ${quotation.customerName}.',
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
                _sendByEmail(context, ref, quotation);
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Scheduled time must be in the future.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }
                  _sendByEmail(context, ref, quotation, sendAt: scheduledDateTime);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteQuotation(
      BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quotation'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(quotationRepositoryProvider).deleteQuotation(id);
      if (context.mounted) context.pop();
    }
  }

  Future<void> _convertToInvoice(
      BuildContext context, WidgetRef ref, Quotation quotation) async {
    final companyId = ref.read(companyIdProvider);
    final userProfile = ref.read(userProfileProvider);
    if (companyId == null || userProfile == null) return;

    try {
      final invoiceRepository = ref.read(invoiceRepositoryProvider);
      final invoice = Invoice(
        id: '',
        companyId: companyId,
        createdBy: userProfile.uid,
        invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch}',
        customerName: quotation.customerName,
        customerEmail: quotation.customerEmail,
        customerPhone: quotation.customerPhone,
        customerAddress: quotation.customerAddress,
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        dueDate: DateFormat('yyyy-MM-dd')
            .format(DateTime.now().add(const Duration(days: 14))),
        items: quotation.items,
        subtotal: quotation.subtotal,
        taxRate: quotation.taxRate,
        taxAmount: quotation.taxAmount,
        total: quotation.total,
        status: 'Draft',
        notes: quotation.notes,
        jobId: quotation.jobId,
      );
      final invoiceId = await invoiceRepository.createInvoice(invoice);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Converted to Invoice successfully!')),
        );
        context.push('/invoices/$invoiceId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to convert to invoice: $e')),
        );
      }
    }
  }

  Future<void> _declineQuote(
      BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref
          .read(quotationRepositoryProvider)
          .updateQuotationStatus(id, 'Declined');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quotation declined.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _archiveQuotation(
      BuildContext context, WidgetRef ref, Quotation quotation) async {
    final isArchived = quotation.status == 'Archived';
    try {
      await ref
          .read(quotationRepositoryProvider)
          .updateQuotationStatus(quotation.id, isArchived ? 'Draft' : 'Archived');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  isArchived ? 'Quotation unarchived.' : 'Quotation archived.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  void _copyPortalLink(BuildContext context, Quotation quotation) {
    final link = '$_webAppBaseUrl/portal/quotations/${quotation.id}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Client portal link copied to clipboard!')),
    );
  }

  void _sharePdf(BuildContext context, Quotation quotation) {
    final link = '$_webAppBaseUrl/portal/quotations/${quotation.id}';
    Share.share(
      'View your quotation here: $link',
      subject:
          'Quotation #${quotation.quotationNumber.replaceFirst('Q-', '')}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quotation = ref.watch(quotationProvider(quotationId));

    if (quotation == null) {
      return const MeshBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              CurvedHeader(title: 'Quotation Details'),
              Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      );
    }

    final statusColor = _getStatusColor(semanticColors, quotation.status);

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            CurvedHeader(
              title: 'Quotation #${quotation.quotationNumber.replaceFirst('Q-', '')}',
              actions: [
                IconButton(
                  icon: const Icon(Icons.forum_outlined, color: Colors.white),
                  tooltip: 'Collaboration & History',
                  onPressed: () =>
                      context.push('/collaboration/quotation/${quotation.id}'),
                ),
                IconButton(
                  icon: const Icon(Icons.visibility_outlined,
                      color: Colors.white),
                  tooltip: 'View as Client',
                  onPressed: () =>
                      context.push('/quotations/${quotation.id}/portal'),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      context.push('/quotations/${quotation.id}/edit',
                          extra: quotation);
                    } else if (value == 'send') {
                      await _showSendOptions(context, ref, quotation);
                    } else if (value == 'copy_link') {
                      _copyPortalLink(context, quotation);
                    } else if (value == 'share_pdf') {
                      _sharePdf(context, quotation);
                    } else if (value == 'archive') {
                      await _archiveQuotation(context, ref, quotation);
                    } else if (value == 'delete') {
                      await _deleteQuotation(context, ref, quotation.id);
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
                      value: 'copy_link',
                      child: Row(children: [
                        Icon(Icons.link, color: semanticColors.info),
                        const SizedBox(width: 8),
                        const Text('Copy Portal Link')
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'share_pdf',
                      child: Row(children: [
                        Icon(Icons.share_outlined, color: semanticColors.info),
                        const SizedBox(width: 8),
                        const Text('Share PDF Link')
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'archive',
                      child: Row(children: [
                        Icon(
                          quotation.status == 'Archived'
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          color: semanticColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          quotation.status == 'Archived'
                              ? 'Unarchive'
                              : 'Archive',
                          style: TextStyle(color: semanticColors.warning),
                        ),
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
                                .format(quotation.total),
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
                                  quotation.status == 'Accepted'
                                      ? Icons.check_circle
                                      : (quotation.status == 'Declined'
                                          ? Icons.cancel
                                          : Icons.info_outline),
                                  size: 14,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  quotation.status,
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

                    // Client Card
                    GlassCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.corporate_fare,
                              color: colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  quotation.customerName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (quotation.customerAddress != null &&
                                    quotation.customerAddress!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          quotation.customerAddress!,
                                          style: TextStyle(
                                            fontSize: 14,
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Line Items Card
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Line Items',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Divider(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                          const SizedBox(height: 8),
                          ...quotation.items.map((item) => Padding(
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
                                    .format(quotation.subtotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          if (quotation.taxAmount != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Taxes (${quotation.taxRate}%)',
                                  style: TextStyle(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.65),
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  NumberFormat.currency(symbol: '£')
                                      .format(quotation.taxAmount),
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
                                    .format(quotation.total),
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
                              'Quote_${quotation.quotationNumber.replaceFirst('Q-', '')}_Final.pdf',
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
                              final uri = Uri.parse('$_webAppBaseUrl/api/quotations/${quotation.id}/pdf');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not open PDF.')),
                                );
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
                    if (quotation.status != 'Declined') ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () =>
                              _convertToInvoice(context, ref, quotation),
                          child: const Text(
                            'Convert to Invoice',
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            side: BorderSide(
                              color: colorScheme.outline,
                              width: 1.5,
                            ),
                          ),
                          onPressed: () =>
                              _declineQuote(context, ref, quotation.id),
                          child: Text(
                            'Decline Quote',
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

