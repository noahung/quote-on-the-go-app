import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../quotations/create_quotation_screen.dart';
import '../invoices/create_invoice_screen.dart';

/// Edit URLs must resolve their ID, including after a cold start or deep link.
class DocumentEditScreen extends ConsumerWidget {
  final String id;
  final bool invoice;
  const DocumentEditScreen({super.key, required this.id, this.invoice = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = ref.watch(companyIdProvider);
    Widget unavailable() => Scaffold(appBar: AppBar(title: const Text('Edit document')),
      body: const Center(child: Text('This document is unavailable.')));
    Widget failed() => Scaffold(appBar: AppBar(title: const Text('Edit document')),
      body: Center(child: FilledButton(onPressed: () {
        if (invoice) { ref.invalidate(invoiceStreamProvider(id)); }
        else { ref.invalidate(quotationStreamProvider(id)); }
      }, child: const Text('Could not load document. Retry'))));
    const loading = Scaffold(body: Center(child: CircularProgressIndicator()));
    if (invoice) {
      return ref.watch(invoiceStreamProvider(id)).when(loading: () => loading,
        error: (_, __) => failed(), data: (document) => document == null || document.companyId != companyId
          ? unavailable() : CreateInvoiceScreen(existingInvoice: document));
    }
    return ref.watch(quotationStreamProvider(id)).when(loading: () => loading,
      error: (_, __) => failed(), data: (document) => document == null || document.companyId != companyId
        ? unavailable() : CreateQuotationScreen(existingQuotation: document));
  }
}
