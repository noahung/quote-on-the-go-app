import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'quotation_provider.dart';
import 'invoice_provider.dart';
import 'customer_provider.dart';
import 'schedule_provider.dart';

class SearchResult {
  final String id;
  final String title;
  final String subtitle;
  final String type; // 'quotation', 'invoice', 'customer', 'job'
  final String route;

  SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.route,
  });
}

final dashboardSearchProvider =
    StateProvider<String>((ref) => '');

final searchResultsProvider = Provider<List<SearchResult>>((ref) {
  final query = ref.watch(dashboardSearchProvider).trim().toLowerCase();
  if (query.isEmpty) return [];

  final quotations = ref.watch(quotationsProvider);
  final invoices = ref.watch(invoicesProvider);
  final customers = ref.watch(customersProvider);
  final jobs = ref.watch(scheduleStreamProvider).valueOrNull ?? [];

  final results = <SearchResult>[];

  for (final q in quotations) {
    if (q.quotationNumber.toLowerCase().contains(query) ||
        q.customerName.toLowerCase().contains(query) ||
        q.status.toLowerCase().contains(query)) {
      results.add(SearchResult(
        id: q.id,
        title: q.quotationNumber,
        subtitle: '${q.customerName} • ${q.status}',
        type: 'quotation',
        route: '/quotations/${q.id}',
      ));
    }
  }

  for (final i in invoices) {
    if (i.invoiceNumber.toLowerCase().contains(query) ||
        i.customerName.toLowerCase().contains(query) ||
        i.status.toLowerCase().contains(query)) {
      results.add(SearchResult(
        id: i.id,
        title: i.invoiceNumber,
        subtitle: '${i.customerName} • ${i.status}',
        type: 'invoice',
        route: '/invoices/${i.id}',
      ));
    }
  }

  for (final c in customers) {
    if (c.name.toLowerCase().contains(query) ||
        c.email.toLowerCase().contains(query) ||
        (c.phone?.toLowerCase().contains(query) ?? false) ||
        c.tags.any((t) => t.toLowerCase().contains(query))) {
      results.add(SearchResult(
        id: c.id,
        title: c.name,
        subtitle: c.email,
        type: 'customer',
        route: '/customers/${c.id}',
      ));
    }
  }

  for (final j in jobs) {
    if (j.title.toLowerCase().contains(query) ||
        (j.customerName?.toLowerCase().contains(query) ?? false) ||
        (j.status?.toLowerCase().contains(query) ?? false)) {
      results.add(SearchResult(
        id: j.id,
        title: j.title,
        subtitle: '${j.customerName ?? ''} • ${j.status ?? 'Scheduled'}',
        type: 'job',
        route: '/schedule/${j.id}',
      ));
    }
  }

  return results.take(20).toList();
});
