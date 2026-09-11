import 'api_client.dart';
import 'dart:io';
import 'dart:typed_data';
import 'pdf_transport.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

String get _webAppBaseUrl => ApiClient.baseUrl;

class PdfService {
  /// Fetches PDF bytes from the server for a quotation.
  static Future<Uint8List> fetchQuotationPdf(String quotationId) async {
    return _fetch('quotations', quotationId);
  }

  /// Fetches PDF bytes from the server for an invoice.
  static Future<Uint8List> fetchInvoicePdf(String invoiceId) async {
    return _fetch('invoices', invoiceId);
  }

  static Future<Uint8List> _fetch(String collection, String id) async {
    final transport =
        PdfTransport(baseUrl: _webAppBaseUrl, headers: ApiClient.headers);
    try {
      return await transport.fetch(collection, id);
    } finally {
      transport.close();
    }
  }

  /// Downloads and shares a quotation PDF via the native share sheet.
  static Future<void> shareQuotationPdf(
    String quotationId, {
    String? quotationNumber,
  }) async {
    final bytes = await fetchQuotationPdf(quotationId);
    final dir = await getTemporaryDirectory();
    final filename =
        'Quotation_${(quotationNumber ?? quotationId).replaceAll('Q-', '')}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Quotation ${quotationNumber ?? ''}',
      subject: 'Quotation $quotationNumber',
    );
  }

  /// Downloads and shares an invoice PDF via the native share sheet.
  static Future<void> shareInvoicePdf(
    String invoiceId, {
    String? invoiceNumber,
  }) async {
    final bytes = await fetchInvoicePdf(invoiceId);
    final dir = await getTemporaryDirectory();
    final filename =
        'Invoice_${(invoiceNumber ?? invoiceId).replaceAll('INV-', '')}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Invoice ${invoiceNumber ?? ''}',
      subject: 'Invoice $invoiceNumber',
    );
  }
}
