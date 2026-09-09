import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A read-only business document, with internal IDs and integration fields omitted.
class DocumentSnapshotView extends StatelessWidget {
  final Map<String, dynamic> snapshot;
  final int version;
  const DocumentSnapshotView(
      {super.key, required this.snapshot, required this.version});
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final money = NumberFormat.currency(locale: 'en_GB', symbol: '£');
    final items = (snapshot['items'] as List? ?? []).whereType<Map>();
    Widget field(String label, Object? value) => value == null ||
            value.toString().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: text.labelLarge),
              const SizedBox(height: 4),
              SelectableText(value.toString()),
            ]));
    return Scaffold(
        appBar: AppBar(title: Text('Version $version')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          field('Document',
              snapshot['invoiceNumber'] ?? snapshot['quotationNumber']),
          field('Customer', snapshot['customerName']),
          field('Email', snapshot['customerEmail']),
          field('Date', snapshot['date']),
          field('Status', snapshot['status']),
          field(snapshot.containsKey('dueDate') ? 'Due date' : 'Valid until',
              snapshot['dueDate'] ?? snapshot['expiryDate']),
          const Divider(),
          Text('Items', style: text.titleLarge),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          (item['description'] ?? item['name'] ?? 'Item')
                              .toString(),
                          style: text.titleMedium),
                      Text(
                          '${item['quantity'] ?? 0} × ${money.format(item['unitPrice'] is num ? item['unitPrice'] : item['price'] is num ? item['price'] : 0)}'),
                    ])),
          const Divider(),
          for (final entry in {
            'Subtotal': 'subtotal',
            'Discount': 'discountAmount',
            'Tax': 'taxAmount',
            'Total': 'total'
          }.entries)
            if (snapshot[entry.value] is num)
              field(entry.key, money.format(snapshot[entry.value])),
          field('Notes', snapshot['notes']),
        ]));
  }
}
