import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/providers.dart';
import '../../providers/collaboration_provider.dart';
import '../../theme/semantic_colors.dart';
import '../../components/curved_header.dart';
import '../../components/mesh_background.dart';
import '../../components/glass_card.dart';
import '../../components/custom_date_time_picker.dart';
import '../../utils/feedback_controller.dart';
import '../../models/feedback_type.dart';
import '../../models/models.dart';
import '../client_responses/client_activity_card.dart';

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
        return semanticColors.warning;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy').format(parsed);
    } catch (_) {
      return dateStr;
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
    try {
      final reminderRepo = ReminderRepository(FirebaseFirestore.instance);
      await reminderRepo.sendManualReminderEmail(invoice.id, invoice.customerEmail);
      if (context.mounted) {
        ref.read(feedbackControllerProvider).success(context, 'Payment reminder sent!');
      }
    } catch (e) {
      if (context.mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Failed to send reminder: $e');
      }
    }
  }

  void _copyPortalLink(BuildContext context, WidgetRef ref, invoice) {
    final link = '$_webAppBaseUrl/portal/invoices/${invoice.id}';
    Clipboard.setData(ClipboardData(text: link));
    ref.read(feedbackControllerProvider).success(context, 'Client portal link copied to clipboard!');
  }

  void _sharePdf(BuildContext context, invoice) {
    final link = '$_webAppBaseUrl/portal/invoices/${invoice.id}';
    Share.share(
      'View your invoice here: $link',
      subject: 'Invoice #${invoice.invoiceNumber.replaceFirst('INV-', '')}',
    );
  }

  Future<void> _duplicateInvoice(
      BuildContext context, WidgetRef ref, Invoice invoice) async {
    final companyId = ref.read(companyIdProvider);
    final userProfile = ref.read(userProfileProvider);
    if (companyId == null || userProfile == null) return;

    try {
      final newInvoice = Invoice(
        id: '',
        companyId: companyId,
        createdBy: userProfile.uid,
        invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch}',
        customerName: invoice.customerName,
        customerEmail: invoice.customerEmail,
        customerPhone: invoice.customerPhone,
        customerAddress: invoice.customerAddress,
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        dueDate: DateFormat('yyyy-MM-dd')
            .format(DateTime.now().add(const Duration(days: 14))),
        items: invoice.items,
        subtotal: invoice.subtotal,
        taxRate: invoice.taxRate,
        taxAmount: invoice.taxAmount,
        total: invoice.total,
        status: 'Draft',
        notes: invoice.notes,
        discount: invoice.discount,
        discountType: invoice.discountType,
        discountAmount: invoice.discountAmount,
        jobId: invoice.jobId,
      );
      final newId = await ref.read(invoiceRepositoryProvider).createInvoice(newInvoice);
      if (context.mounted) {
        ref.read(feedbackControllerProvider).success(context, 'Invoice duplicated successfully!');
        context.push('/invoices/$newId');
      }
    } catch (e) {
      if (context.mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Failed to duplicate: $e');
      }
    }
  }

  Future<void> _markAsSent(
      BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref
          .read(invoiceRepositoryProvider)
          .updateInvoiceStatus(id, 'Sent');
      if (context.mounted) {
        ref.read(feedbackControllerProvider).success(context, 'Invoice marked as Sent.');
      }
    } catch (e) {
      if (context.mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Failed: $e');
      }
    }
  }

  Future<void> _showSaveAsTemplateDialog(
      BuildContext context, WidgetRef ref, Invoice invoice) async {
    final nameCtrl = TextEditingController(
        text: 'Template for Invoice ${invoice.invoiceNumber}');
    final descCtrl = TextEditingController(
        text: 'Preset items and terms from invoice ${invoice.invoiceNumber}');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final companyId = ref.read(companyIdProvider);
    if (companyId == null) return;

    try {
      await ref.read(documentTemplateRepositoryProvider).createTemplate(
        companyId: companyId,
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim(),
        type: 'invoice',
        items: invoice.items,
        notes: invoice.notes,
        taxRate: invoice.taxRate,
        discount: invoice.discount,
        discountType: invoice.discountType,
        discountAmount: invoice.discountAmount,
      );
      if (context.mounted) {
        ref.read(feedbackControllerProvider).success(context, 'Template saved successfully!');
      }
    } catch (e) {
      if (context.mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Failed to save template: $e');
      }
    }
  }

  Future<bool> _showLockWarningDialog(BuildContext context, String lockedBy) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Document Locked'),
          ],
        ),
        content: Text('This document is currently being edited by another user (ID: $lockedBy). Editing it simultaneously might overwrite changes. Do you want to proceed anyway?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _showRenameDialog(
      BuildContext context, WidgetRef ref, Invoice invoice) async {
    final titleCtrl = TextEditingController(text: invoice.title ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Invoice'),
        content: TextField(
          controller: titleCtrl,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Title / Project Reference',
            hintText: 'e.g. Kitchen Renovation Phase 2',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final newTitle = titleCtrl.text.trim();
      await ref
          .read(invoiceRepositoryProvider)
          .updateInvoice(invoice.id, {'title': newTitle});
      if (context.mounted) {
        ref.read(feedbackControllerProvider).success(context, 'Invoice renamed.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(invoiceProvider(invoiceId));
    final lockAsync = ref.watch(documentLockProvider((documentId: invoiceId, documentType: 'invoice')));
    final lockInfo = lockAsync.valueOrNull;
    final userProfile = ref.watch(userProfileProvider);
    final currentUserId = userProfile?.uid;
    final canDelete = userProfile?.role == 'owner' || userProfile?.role == 'admin';
    final isPendingApproval = invoice?.requiresApproval == true && invoice?.approvalStatus == 'pending';
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
                  icon: const Icon(LucideIcons.messageSquare),
                  tooltip: 'Collaboration & History',
                  onPressed: () =>
                      context.push('/collaboration/invoice/${invoice.id}'),
                ),
                IconButton(
                  icon: Icon(
                    invoice.isStarred ? Icons.star : Icons.star_border,
                    color: invoice.isStarred ? Colors.amber : null,
                  ),
                  tooltip: invoice.isStarred ? 'Remove Star' : 'Star Invoice',
                  onPressed: () async {
                    final companyId = ref.read(companyIdProvider);
                    if (companyId != null) {
                      await ref
                          .read(invoiceRepositoryProvider)
                          .updateInvoice(invoice.id, {'isStarred': !invoice.isStarred});
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(LucideIcons.eye),
                  tooltip: 'View as Client',
                  onPressed: () =>
                      context.push('/invoices/${invoice.id}/portal'),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(LucideIcons.moreVertical),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      final isLocked = lockInfo != null && lockInfo.isLocked && lockInfo.lockedBy != currentUserId;
                      if (isLocked) {
                        final proceed = await _showLockWarningDialog(context, lockInfo.lockedBy!);
                        if (!proceed) return;
                      }
                      if (context.mounted) {
                        context.push('/invoices/${invoice.id}/edit',
                            extra: invoice);
                      }
                    } else if (value == 'send') {
                      if (isPendingApproval) {
                        ref.read(feedbackControllerProvider).error(context, 'This document must be approved first.');
                        return;
                      }
                      await _showSendOptions(context, ref, invoice);
                    } else if (value == 'mark_paid') {
                      if (isPendingApproval) {
                        ref.read(feedbackControllerProvider).error(context, 'This document must be approved first.');
                        return;
                      }
                      await _markPaid(context, ref, invoice.id);
                    } else if (value == 'mark_sent') {
                      if (isPendingApproval) {
                        ref.read(feedbackControllerProvider).error(context, 'This document must be approved first.');
                        return;
                      }
                      await _markAsSent(context, ref, invoice.id);
                    } else if (value == 'send_reminder') {
                      if (isPendingApproval) {
                        ref.read(feedbackControllerProvider).error(context, 'This document must be approved first.');
                        return;
                      }
                      await _sendReminder(context, ref, invoice);
                    } else if (value == 'copy_link') {
                      _copyPortalLink(context, ref, invoice);
                    } else if (value == 'share_pdf') {
                      _sharePdf(context, invoice);
                    } else if (value == 'duplicate') {
                      await _duplicateInvoice(context, ref, invoice);
                    } else if (value == 'save_template') {
                      await _showSaveAsTemplateDialog(context, ref, invoice);
                    } else if (value == 'rename') {
                      await _showRenameDialog(context, ref, invoice);
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
                      value: 'rename',
                      child: Row(children: [
                        Icon(Icons.edit_note_outlined),
                        SizedBox(width: 8),
                        Text('Rename')
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
                      value: 'mark_sent',
                      child: Row(children: [
                        Icon(Icons.send_outlined, color: semanticColors.info),
                        const SizedBox(width: 8),
                        const Text('Mark as Sent'),
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
                      value: 'send_reminder',
                      child: Row(children: [
                        Icon(Icons.notifications_active_outlined,
                            color: semanticColors.warning),
                        const SizedBox(width: 8),
                        const Text('Send Reminder'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'copy_link',
                      child: Row(children: [
                        Icon(Icons.link, color: semanticColors.info),
                        const SizedBox(width: 8),
                        const Text('Copy Portal Link'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'share_pdf',
                      child: Row(children: [
                        Icon(Icons.share_outlined, color: semanticColors.info),
                        const SizedBox(width: 8),
                        const Text('Share PDF Link'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Row(children: [
                        Icon(Icons.copy_outlined, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text('Duplicate'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'save_template',
                      child: Row(children: [
                        Icon(Icons.bookmark_add_outlined, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text('Save as Template'),
                      ]),
                    ),
                    if (canDelete)
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
            if (isPendingApproval)
              Container(
                width: double.infinity,
                color: Colors.orange.shade800,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Row(
                  children: [
                    Icon(Icons.lock_clock, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Approval Pending: This document requires approval from an Admin or Owner before it can be sent or paid.',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            if (lockInfo != null && lockInfo.isLocked && lockInfo.lockedBy != currentUserId)
              Container(
                width: double.infinity,
                color: Colors.amber.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Warning: This document is currently locked/edited by another user.',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
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
                          if (invoice.title != null && invoice.title!.isNotEmpty) ...[
                            Text(
                              invoice.title!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                          ],
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
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  invoice.status == 'Paid'
                                      ? LucideIcons.checkCircle
                                      : (invoice.status == 'Overdue'
                                          ? LucideIcons.triangleAlert
                                          : LucideIcons.info),
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
                                  LucideIcons.mapPin,
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
                            value: _formatDate(invoice.date),
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            label: 'Due Date',
                            value: _formatDate(invoice.dueDate),
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
                              LucideIcons.fileText,
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
                              side: BorderSide(color: colorScheme.outlineVariant),
                              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.05),
                            ),
                            onPressed: () {
                              context.push('/pdf-preview/invoice/${invoice.id}');
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
                    const SizedBox(height: 16),
                    _ReminderHistorySection(invoice: invoice),
                    const SizedBox(height: 16),

                    // Client Activity (portal responses)
                    ClientActivityCard(
                      documentId: invoice.id,
                      documentType: 'invoice',
                      customerName: invoice.customerName,
                    ),
                    const SizedBox(height: 24),

                    // Bottom Actions
                    if (invoice.status != 'Paid') ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF004A77) : const Color(0xFFC2E7FF),
                            foregroundColor: isDark ? const Color(0xFFC2E7FF) : const Color(0xFF001D35),
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
                              color: colorScheme.outlineVariant,
                              width: 1.2,
                            ),
                            backgroundColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF0F4F9),
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

class _ReminderHistorySection extends StatefulWidget {
  final Invoice invoice;

  const _ReminderHistorySection({required this.invoice});

  @override
  State<_ReminderHistorySection> createState() => _ReminderHistorySectionState();
}

class _ReminderHistorySectionState extends State<_ReminderHistorySection> {
  bool _isExpanded = false;
  bool _isSending = false;

  Future<void> _triggerManualReminder(BuildContext context, WidgetRef ref) async {
    setState(() => _isSending = true);
    try {
      final repo = ref.read(reminderRepositoryProvider);
      await repo.sendManualReminderEmail(widget.invoice.id, widget.invoice.customerEmail);
      if (context.mounted) {
        ref.read(feedbackControllerProvider).success(
          context,
          'Manual payment reminder sent to ${widget.invoice.customerEmail}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ref.read(feedbackControllerProvider).error(
          context,
          'Failed to send reminder: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: Icon(LucideIcons.history, color: colorScheme.primary, size: 20),
            title: const Text(
              'Reminder History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            trailing: Icon(
              _isExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
              size: 18,
            ),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1, thickness: 1),
            Consumer(
              builder: (context, ref, child) {
                final historyAsync = ref.watch(reminderHistoryStreamProvider(widget.invoice.id));
                return historyAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, stack) => Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Error loading history: $err'),
                  ),
                  data: (history) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Send History Log',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: const StadiumBorder(),
                                  minimumSize: const Size(0, 32),
                                ),
                                onPressed: _isSending ? null : () => _triggerManualReminder(context, ref),
                                icon: _isSending
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(LucideIcons.mail, size: 12),
                                label: const Text('Send Reminder Now', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (history.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              child: Text(
                                'No reminders sent yet.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: history.length,
                              itemBuilder: (context, index) {
                                final entry = history[index];
                                final isSent = entry.status == 'Sent';
                                final formattedDate = DateFormat('d MMM yyyy, HH:mm').format(entry.sentAt);

                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Timeline column
                                      Column(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: isSent ? semanticColors.success : semanticColors.error,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          if (index < history.length - 1)
                                            Expanded(
                                              child: Container(
                                                width: 2,
                                                color: colorScheme.outline.withValues(alpha: 0.2),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      // Log Details column
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    '${entry.triggerType} Reminder',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: (isSent ? semanticColors.success : semanticColors.error)
                                                          .withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      entry.status,
                                                      style: TextStyle(
                                                        color: isSent ? semanticColors.success : semanticColors.error,
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'To: ${entry.recipientEmail}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                formattedDate,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                                ),
                                              ),
                                              if (entry.error != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Error: ${entry.error}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: semanticColors.error,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ],
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
