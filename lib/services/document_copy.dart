import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'document_outbox.dart';

/// Carries editable content only. Payment, approval and integration state must
/// never be inherited by a new draft.
class DocumentCopy {
  DocumentCopy._(
      this.companyId, this.documentType, this.actionKey, this.fields);

  factory DocumentCopy.invoice(Invoice source, {DateTime? now}) =>
      DocumentCopy._from(
          source.companyId,
          'invoice',
          'invoice:copy:${source.id}',
          source.toJson(),
          source.items,
          now ?? DateTime.now());

  factory DocumentCopy.quotation(Quotation source,
          {bool toInvoice = false, DateTime? now}) =>
      DocumentCopy._from(
          source.companyId,
          toInvoice ? 'invoice' : 'quotation',
          'quotation:${toInvoice ? 'convert' : 'copy'}:${source.id}',
          {...source.toJson(), if (toInvoice) 'quotationId': source.id},
          source.items,
          now ?? DateTime.now());

  factory DocumentCopy._from(String companyId, String type, String actionKey,
      Map<String, dynamic> source, List<LineItem> items, DateTime now) {
    const content = [
      'title',
      'customerName',
      'customerEmail',
      'customerPhone',
      'customerAddress',
      'customerId',
      'jobId',
      'quotationId',
      'subtotal',
      'taxRate',
      'taxAmount',
      'total',
      'discount',
      'discountType',
      'discountAmount',
      'pdfTemplateId',
      'pdfThemeColor',
      'notes',
    ];
    // Calendar days keep local due dates stable across daylight-saving changes.
    final date = DateTime(now.year, now.month, now.day);
    final due = DateTime(
        date.year, date.month, date.day + (type == 'invoice' ? 14 : 30));
    return DocumentCopy._(companyId, type, actionKey, {
      for (final key in content)
        if (source.containsKey(key)) key: source[key],
      'date': DateFormat('yyyy-MM-dd').format(date),
      type == 'invoice' ? 'dueDate' : 'expiryDate':
          DateFormat('yyyy-MM-dd').format(due),
      'items': items.map((item) => item.toJson()).toList(),
    });
  }

  final String companyId, documentType, actionKey;
  final Map<String, dynamic> fields;

  Future<Map<String, dynamic>> enqueue(DocumentOutbox queue) {
    if (queue.companyId != companyId) {
      throw StateError(
          'Open this document in its company before making a copy.');
    }
    return queue.enqueue(
        requestId: const Uuid().v4(),
        documentType: documentType,
        fields: fields,
        actionKey: actionKey);
  }
}
