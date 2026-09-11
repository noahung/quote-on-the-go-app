import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qotg_mobile/models/models.dart';
import 'package:qotg_mobile/services/document_copy.dart';
import 'package:qotg_mobile/services/document_outbox.dart';

const item = LineItem(
    id: 'line',
    description: 'Repair',
    itemDetails: 'Keep these details',
    quantity: 2,
    unitPrice: 50,
    total: 90,
    discount: 10,
    discountType: 'fixed',
    discountAmount: 10);
const quote = Quotation(
    id: 'quote-a',
    companyId: 'company-a',
    createdBy: 'member',
    quotationNumber: 'Q-1',
    customerName: 'Alex',
    customerEmail: 'alex@example.test',
    customerId: 'customer-a',
    customerPhone: '123',
    customerAddress: 'London',
    title: 'Kitchen repair',
    date: '2026-01-01',
    expiryDate: '2026-01-30',
    items: [item],
    subtotal: 90,
    taxRate: 20,
    taxAmount: 16,
    total: 96,
    discount: 10,
    discountType: 'fixed',
    discountAmount: 10,
    notes: 'Bring tools',
    jobId: 'job-a',
    pdfTemplateId: 'minimal',
    pdfThemeColor: '#F4781F',
    status: 'Accepted',
    approvalStatus: 'approved',
    mondayItemId: 'remote-a',
    isStarred: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'quote copies and conversion retain editable content, reset dates and omit workflow state',
      () {
    final copy = DocumentCopy.quotation(quote, now: DateTime(2026, 10, 24));
    final conversion = DocumentCopy.quotation(quote,
        toInvoice: true, now: DateTime(2026, 10, 24));
    for (final request in [copy, conversion]) {
      final fields = request.fields;
      expect(fields['customerId'], 'customer-a');
      expect(fields['jobId'], 'job-a');
      expect(fields['title'], 'Kitchen repair');
      expect(fields['pdfTemplateId'], 'minimal');
      expect(fields['pdfThemeColor'], '#F4781F');
      expect(fields['discountAmount'], 10);
      expect(fields['total'], 96);
      expect(fields['items'], [item.toJson()]);
      expect(fields['notes'], 'Bring tools');
      for (final key in [
        'status',
        'approvalStatus',
        'mondayItemId',
        'isStarred',
        'createdBy',
        'quotationNumber'
      ]) {
        expect(fields.containsKey(key), false, reason: key);
      }
      expect(() => jsonEncode(fields), returnsNormally);
    }
    expect(copy.fields['date'], '2026-10-24');
    expect(copy.fields['expiryDate'], '2026-11-23');
    expect(copy.fields.containsKey('quotationId'), false);
    expect(conversion.fields['dueDate'], '2026-11-07');
    expect(conversion.fields['quotationId'], 'quote-a');
    expect(conversion.fields.containsKey('expiryDate'), false);
  });

  test(
      'invoice copies retain customer and template choices without copying paid state',
      () {
    final invoice = Invoice.fromJson({
      ...quote.toJson(),
      'invoiceNumber': 'INV-1',
      'dueDate': '2026-01-30',
      'items': [item.toJson()],
      'status': 'Paid',
      'stripePaymentIntentId': 'pi-original',
      'paidAt': '2026-01-02T00:00:00Z',
      'quotationId': 'source-quote',
    });
    final fields =
        DocumentCopy.invoice(invoice, now: DateTime(2026, 12, 25)).fields;
    expect(fields['customerId'], 'customer-a');
    expect(fields['pdfTemplateId'], 'minimal');
    expect(fields['quotationId'], 'source-quote');
    expect(fields['dueDate'], '2027-01-08');
    expect(fields.containsKey('paidAt'), false);
    expect(fields.containsKey('stripePaymentIntentId'), false);
    expect(() => jsonEncode(fields), returnsNormally);
  });

  test('concurrent duplicate requests share one durable ID', () async {
    final queue =
        DocumentOutbox(userId: 'user', companyId: 'company-a', autoSync: false);
    addTearDown(queue.dispose);
    final result = await Future.wait(
        List.generate(3, (_) => DocumentCopy.quotation(quote).enqueue(queue)));
    expect(queue.entries.length, 1);
    expect(result.map((entry) => entry['requestId']).toSet().length, 1);
  });

  test(
      'conversion retry after a lost response and restart reuses the original content and ID',
      () async {
    final received = <Map<String, dynamic>>[];
    final serverIds = <String>{};
    Future<Map<String, dynamic>> send(Map<String, dynamic> request) async {
      received.add(request);
      serverIds.add(request['documentId']);
      if (received.length == 1) throw TimeoutException('Lost acknowledgement');
      return {'success': true, 'documentId': request['documentId']};
    }

    var queue = DocumentOutbox(
        userId: 'user', companyId: 'company-a', autoSync: false, send: send);
    final original =
        await DocumentCopy.quotation(quote, toInvoice: true).enqueue(queue);
    await queue.sync();
    queue.dispose();
    queue = DocumentOutbox(
        userId: 'user', companyId: 'company-a', autoSync: false, send: send);
    addTearDown(queue.dispose);
    final retry = await DocumentCopy.quotation(
            quote.copyWith(notes: 'Later changes'),
            toInvoice: true)
        .enqueue(queue);
    expect(retry['requestId'], original['requestId']);
    expect(retry['request']['fields']['notes'], 'Bring tools');
    await queue.sync();
    expect(serverIds.length, 1);
    expect(received[0], received[1]);
    // A deliberate new action after confirmation may create another draft.
    final another =
        await DocumentCopy.quotation(quote, toInvoice: true).enqueue(queue);
    expect(another['requestId'], isNot(original['requestId']));
  });

  test(
      'different actions remain separate and another company cannot receive the copy',
      () async {
    final queue =
        DocumentOutbox(userId: 'user', companyId: 'company-a', autoSync: false);
    final other =
        DocumentOutbox(userId: 'user', companyId: 'company-b', autoSync: false);
    addTearDown(queue.dispose);
    addTearDown(other.dispose);
    await DocumentCopy.quotation(quote).enqueue(queue);
    await DocumentCopy.quotation(quote, toInvoice: true).enqueue(queue);
    expect(queue.entries.length, 2);
    expect(
        () => DocumentCopy.quotation(quote).enqueue(other), throwsStateError);
    expect(other.entries, isEmpty);
  });
}
