import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qotg_mobile/services/pdf_transport.dart';

void main() {
  for (final collection in ['invoices', 'quotations']) {
    test('$collection PDFs carry bearer auth and preserve bytes', () async {
      final transport = PdfTransport(
          baseUrl: 'https://example.test',
          headers: () async => {'Authorization': 'Bearer test-token'},
          client: MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer test-token');
            expect(
                request.url.pathSegments, ['api', collection, 'doc 1', 'pdf']);
            return http.Response('%PDF-1.7\nfixture', 200,
                headers: {'content-type': 'application/pdf'});
          }));
      addTearDown(transport.close);
      expect(ascii.decode(await transport.fetch(collection, 'doc 1')),
          '%PDF-1.7\nfixture');
    });
  }
  test(
      'expired session gives an actionable error instead of sharing response bytes',
      () async {
    final transport = PdfTransport(
        baseUrl: 'https://example.test',
        headers: () async => {},
        client: MockClient((_) async => http.Response('Unauthorized', 401)));
    addTearDown(transport.close);
    await expectLater(
        transport.fetch('invoices', 'draft'),
        throwsA(isA<PdfDownloadException>()
            .having((e) => e.message, 'message', contains('Sign in again'))));
  });
  test('HTML and mislabeled non-PDF responses are rejected', () async {
    for (final type in ['text/html', 'application/pdf']) {
      final transport = PdfTransport(
          baseUrl: 'https://example.test',
          headers: () async => {},
          client: MockClient((_) async => http.Response(
              '<html>Error</html>', 200,
              headers: {'content-type': type})));
      await expectLater(transport.fetch('invoices', 'draft'),
          throwsA(isA<PdfDownloadException>()));
      transport.close();
    }
  });
}
