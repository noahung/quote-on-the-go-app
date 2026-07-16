import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _webAppBaseUrl = 'https://app.quoteonthego.co.uk';

class PdfService {
  /// Fetches PDF bytes from the server for a quotation.
  static Future<Uint8List> fetchQuotationPdf(String quotationId) async {
    final url = Uri.parse('$_webAppBaseUrl/api/quotations/$quotationId/pdf');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception('Failed to fetch PDF (${response.statusCode})');
  }

  /// Fetches PDF bytes from the server for an invoice.
  static Future<Uint8List> fetchInvoicePdf(String invoiceId) async {
    final url = Uri.parse('$_webAppBaseUrl/api/invoices/$invoiceId/pdf');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception('Failed to fetch PDF (${response.statusCode})');
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

  /// Opens the PDF in the device's default browser.
  static Future<void> viewQuotationPdfInBrowser(String quotationId) async {
    final url = Uri.parse('$_webAppBaseUrl/api/quotations/$quotationId/pdf');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens the invoice PDF in the device's default browser.
  static Future<void> viewInvoicePdfInBrowser(String invoiceId) async {
    final url = Uri.parse('$_webAppBaseUrl/api/invoices/$invoiceId/pdf');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
