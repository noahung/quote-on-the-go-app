import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/providers.dart';
import '../../providers/collaboration_provider.dart';
import '../../models/models.dart';
import '../../theme/semantic_colors.dart';
import '../../components/curved_header.dart';
import '../../components/mesh_background.dart';
import '../../components/glass_card.dart';
import '../../utils/feedback_controller.dart';
import '../../models/feedback_type.dart';
import '../../services/pdf_service.dart';
import '../client_responses/client_activity_card.dart';
import '../../components/custom_email_send_bottom_sheet.dart';
import '../invoices/create_invoice_screen.dart';

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

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _sendByEmail(
      BuildContext context, WidgetRef ref, quotation,
      {DateTime? sendAt, Map<String, dynamic>? emailOptions}) async {
    try {
      final body = <String, dynamic>{
        'quotationId': quotation.id,
        'customerEmail': quotation.customerEmail,
        'customerName': quotation.customerName,
      };
      if (sendAt != null) {
        body['sendAt'] = sendAt.toUtc().toIso8601String();
      }
      if (emailOptions != null) {
        body.addAll(emailOptions);
      }

      final response = await http.post(
        Uri.parse('$_webAppBaseUrl/api/send-quotation'),
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
                ? 'Your quotation will be sent at the scheduled time'
                : 'Your quotation has been sent to the customer',
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

  Future<void> _showSendOptions(
      BuildContext context, WidgetRef ref, quotation) async {
    final companyId = ref.read(companyIdProvider) ?? '';
    final company = ref.read(companyProvider);
    final isPremium = company?.tier == 'premium' ||
        company?.tier == 'individual' ||
        company?.tier == 'organisation';

    final currencyFormat = NumberFormat.currency(symbol: '£');
    final totalFormatted = currencyFormat.format(quotation.total);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomEmailSendBottomSheet(
        docType: 'quotation',
        docNumber: quotation.quotationNumber,
        customerName: quotation.customerName,
        customerEmail: quotation.customerEmail,
        totalAmount: totalFormatted,
        companyId: companyId,
        isPremiumUser: isPremium,
        onSendNow: (payload) {
          Navigator.pop(ctx);
          _sendByEmail(context, ref, quotation, emailOptions: payload);
        },
        onScheduleSend: (sendAt, payload) {
          Navigator.pop(ctx);
          _sendByEmail(context, ref, quotation, sendAt: sendAt, emailOptions: payload);
        },
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
        ref.read(feedbackControllerProvider).success(context, 'Converted to Invoice successfully!');
        context.push('/invoices/$invoiceId');
      }
    } catch (e) {
      if (context.mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Failed to convert to invoice: $e');
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
        ref.read(feedbackControllerProvider).success(context, 'Quotation declined.');
      }
    } catch (e) {
      if (context.mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Failed to update status: $e');
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
        ref.read(feedbackControllerProvider).success(
          context,
          isArchived ? 'Quotation unarchived.' : 'Quotation archived.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Failed: $e');
      }
    }
  }

  Future<void> _duplicateQuotation(
      BuildContext context, WidgetRef ref, Quotation quotation) async {
    final companyId = ref.read(companyIdProvider);
    final userProfile = ref.read(userProfileProvider);
    if (companyId == null || userProfile == null) return;

    try {
      final newQuote = Quotation(
        id: '',
        companyId: companyId,
        createdBy: userProfile.uid,
        quotationNumber: 'Q-${DateTime.now().millisecondsSinceEpoch}',
        customerName: quotation.customerName,
        customerEmail: quotation.customerEmail,
        customerPhone: quotation.customerPhone,
        customerAddress: quotation.customerAddress,
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        expiryDate: DateFormat('yyyy-MM-dd')
            .format(DateTime.now().add(const Duration(days: 30))),
        items: quotation.items,
        subtotal: quotation.subtotal,
        taxRate: quotation.taxRate,
        taxAmount: quotation.taxAmount,
        total: quotation.total,
        status: 'Draft',
        notes: quotation.notes,
        discount: quotation.discount,
        discountType: quotation.discountType,
        discountAmount: quotation.discountAmount,
      );
      final newId = await ref.read(quotationRepositoryProvider).createQuotation(newQuote);
      if (context.mounted) {
        ref.read(feedbackControllerProvider).success(context, 'Quotation duplicated successfully!');
        context.push('/quotations/$newId');
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
          .read(quotationRepositoryProvider)
          .updateQuotationStatus(id, 'Sent');
      if (context.mounted) {
        ref.read(feedbackControllerProvider).success(context, 'Quotation marked as Sent.');
      }
    } catch (e) {
      if (context.mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Failed: $e');
      }
    }
  }

  Future<void> _showSaveAsTemplateDialog(
      BuildContext context, WidgetRef ref, Quotation quotation) async {
    final nameCtrl = TextEditingController(
        text: 'Template for Quote ${quotation.quotationNumber}');
    final descCtrl = TextEditingController(
        text: 'Preset items and terms from quotation ${quotation.quotationNumber}');

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
        type: 'quotation',
        items: quotation.items,
        notes: quotation.notes,
        taxRate: quotation.taxRate,
        discount: quotation.discount,
        discountType: quotation.discountType,
        discountAmount: quotation.discountAmount,
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

  void _copyPortalLink(BuildContext context, WidgetRef ref, Quotation quotation) {
    final link = '$_webAppBaseUrl/portal/quotations/${quotation.id}';
    Clipboard.setData(ClipboardData(text: link));
    ref.read(feedbackControllerProvider).success(context, 'Client portal link copied to clipboard!');
  }

  void _sharePdf(BuildContext context, Quotation quotation) {
    final link = '$_webAppBaseUrl/portal/quotations/${quotation.id}';
    Share.share(
      'View your quotation here: $link',
      subject:
          'Quotation #${quotation.quotationNumber.replaceFirst('Q-', '')}',
    );
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
      BuildContext context, WidgetRef ref, Quotation quotation) async {
    final titleCtrl = TextEditingController(text: quotation.title ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Quotation'),
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
          .read(quotationRepositoryProvider)
          .updateQuotation(quotation.id, {'title': newTitle});
      if (context.mounted) {
        ref.read(feedbackControllerProvider).success(context, 'Quotation renamed.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quotation = ref.watch(quotationProvider(quotationId));
    final lockAsync = ref.watch(documentLockProvider((documentId: quotationId, documentType: 'quotation')));
    final lockInfo = lockAsync.valueOrNull;
    final userProfile = ref.watch(userProfileProvider);
    final currentUserId = userProfile?.uid;
    final canDelete = userProfile?.role == 'owner' || userProfile?.role == 'admin';
    final isPendingApproval = quotation?.requiresApproval == true && quotation?.approvalStatus == 'pending';

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
                  icon: const Icon(LucideIcons.messageSquare),
                  tooltip: 'Collaboration & History',
                  onPressed: () =>
                      context.push('/collaboration/quotation/${quotation.id}'),
                ),
                IconButton(
                  icon: Icon(
                    quotation.isStarred ? Icons.star : Icons.star_border,
                    color: quotation.isStarred ? Colors.amber : null,
                  ),
                  tooltip: quotation.isStarred ? 'Remove Star' : 'Star Quotation',
                  onPressed: () async {
                    final companyId = ref.read(companyIdProvider);
                    if (companyId != null) {
                      await ref
                          .read(quotationRepositoryProvider)
                          .updateQuotation(quotation.id, {'isStarred': !quotation.isStarred});
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(LucideIcons.eye),
                  tooltip: 'View as Client',
                  onPressed: () =>
                      context.push('/quotations/${quotation.id}/portal'),
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
                        context.push('/quotations/${quotation.id}/edit',
                            extra: quotation);
                      }
                    } else if (value == 'send') {
                      if (isPendingApproval) {
                        ref.read(feedbackControllerProvider).error(context, 'This document must be approved first.');
                        return;
                      }
                      await _showSendOptions(context, ref, quotation);
                    } else if (value == 'copy_link') {
                      _copyPortalLink(context, ref, quotation);
                    } else if (value == 'share_pdf') {
                      _sharePdf(context, quotation);
                    } else if (value == 'view_pdf') {
                      await PdfService.viewQuotationPdfInBrowser(quotation.id);
                    } else if (value == 'share_pdf_file') {
                      try {
                        await PdfService.shareQuotationPdf(quotation.id,
                            quotationNumber: quotation.quotationNumber);
                      } catch (e) {
                        if (context.mounted) {
                          ref.read(feedbackControllerProvider).error(context, 'Error sharing PDF: $e');
                        }
                      }
                    } else if (value == 'mark_sent') {
                      if (isPendingApproval) {
                        ref.read(feedbackControllerProvider).error(context, 'This document must be approved first.');
                        return;
                      }
                      await _markAsSent(context, ref, quotation.id);
                    } else if (value == 'duplicate') {
                      await _duplicateQuotation(context, ref, quotation);
                    } else if (value == 'save_template') {
                      await _showSaveAsTemplateDialog(context, ref, quotation);
                    } else if (value == 'rename') {
                      await _showRenameDialog(context, ref, quotation);
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
                      value: 'view_pdf',
                      child: Row(children: [
                        Icon(Icons.picture_as_pdf_outlined, color: semanticColors.info),
                        const SizedBox(width: 8),
                        const Text('View PDF Document')
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'share_pdf_file',
                      child: Row(children: [
                        Icon(Icons.file_present_outlined, color: semanticColors.info),
                        const SizedBox(width: 8),
                        const Text('Share PDF File')
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
                    PopupMenuItem(
                      value: 'archive',
                      child: Row(children: [
                        Icon(
                          quotation.status == 'Archived'
                              ? LucideIcons.archive
                              : LucideIcons.archive,
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
                        'Approval Pending: This document requires approval from an Admin or Owner before it can be sent or converted.',
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
                          if (quotation.title != null && quotation.title!.isNotEmpty) ...[
                            Text(
                              quotation.title!,
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
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  quotation.status == 'Accepted'
                                      ? LucideIcons.checkCircle
                                      : (quotation.status == 'Declined'
                                          ? LucideIcons.xCircle
                                          : LucideIcons.info),
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

                    if (quotation.status == 'Accepted') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(LucideIcons.checkCircle2, color: Color(0xFF10B981), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Quotation Accepted! Next Step:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Book a service job in the schedule or convert straight to an invoice:',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      side: BorderSide(color: colorScheme.primary),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      context.push('/schedule/new?fromQuotation=${quotation.id}');
                                    },
                                    icon: const Icon(LucideIcons.calendar, size: 14),
                                    label: const Text('Book Job', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CreateInvoiceScreen(fromQuotationId: quotation.id),
                                        ),
                                      );
                                    },
                                    icon: const Icon(LucideIcons.briefcase, size: 14),
                                    label: const Text('Create Invoice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

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
                              LucideIcons.building,
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
                                        LucideIcons.mapPin,
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

                    // Quotation Schedule Card
                    GlassCard(
                      child: Column(
                        children: [
                          _DetailRow(
                            label: 'Issue Date',
                            value: _formatDate(quotation.date),
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            label: 'Valid Until',
                            value: _formatDate(quotation.expiryDate),
                            valueColor: quotation.status == 'Declined'
                                ? semanticColors.error
                                : (quotation.status == 'Accepted'
                                    ? semanticColors.success
                                    : semanticColors.warning),
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
                              LucideIcons.fileText,
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
                              side: BorderSide(color: colorScheme.outlineVariant),
                              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.05),
                            ),
                            onPressed: () {
                              context.push('/pdf-preview/quotation/${quotation.id}');
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

                    // Client Activity (portal responses)
                    ClientActivityCard(
                      documentId: quotation.id,
                      documentType: 'quotation',
                      customerName: quotation.customerName,
                    ),
                    const SizedBox(height: 24),

                    // Bottom Actions
                    if (quotation.status != 'Declined') ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF004A77) : const Color(0xFFC2E7FF),
                            foregroundColor: isDark ? const Color(0xFFC2E7FF) : const Color(0xFF001D35),
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
                            shape: const StadiumBorder(),
                            side: BorderSide(
                              color: colorScheme.outlineVariant,
                              width: 1.2,
                            ),
                            backgroundColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF0F4F9),
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

