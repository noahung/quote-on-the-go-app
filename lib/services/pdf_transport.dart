import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Shared authenticated PDF transport. Injectable transport keeps both document
/// types covered without requiring a signed-in device in unit tests.
class PdfTransport {
  PdfTransport(
      {required this.baseUrl, required this.headers, http.Client? client})
      : _client = client ?? http.Client();
  final String baseUrl;
  final Future<Map<String, String>> Function() headers;
  final http.Client _client;

  Future<Uint8List> fetch(String collection, String documentId) async {
    if (!['quotations', 'invoices'].contains(collection)) {
      throw ArgumentError.value(collection, 'collection');
    }
    final response = await _client.get(
      Uri.parse(
          '$baseUrl/api/$collection/${Uri.encodeComponent(documentId)}/pdf'),
      headers: {...await headers(), 'Accept': 'application/pdf'},
    ).timeout(const Duration(seconds: 60));
    if (response.statusCode == 401) {
      throw const PdfDownloadException(
          'Your session has expired. Sign in again to download this PDF.');
    }
    if (response.statusCode == 403) {
      throw const PdfDownloadException(
          'This PDF is not available to your account. Check your company access or approval status.');
    }
    if (response.statusCode == 404) {
      throw const PdfDownloadException(
          'This document could not be found. Refresh the document list and try again.');
    }
    if (response.statusCode != 200) {
      throw const PdfDownloadException(
          'The PDF could not be prepared. Please try again.');
    }
    final bytes = response.bodyBytes;
    if (!response.headers['content-type']
            .toString()
            .toLowerCase()
            .contains('application/pdf') ||
        bytes.length < 5 ||
        ascii.decode(bytes.take(5).toList(), allowInvalid: true) != '%PDF-') {
      throw const PdfDownloadException(
          'The service returned an invalid PDF. Please try again.');
    }
    return bytes;
  }

  void close() => _client.close();
}

class PdfDownloadException implements Exception {
  const PdfDownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}
