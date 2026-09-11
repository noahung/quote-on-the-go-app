import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/document_outbox_provider.dart';
import '../../components/preview_status_panel.dart';
import '../../components/settings_action_row.dart';

class DocumentSavesScreen extends ConsumerStatefulWidget {
  const DocumentSavesScreen({super.key, this.requestId, this.preview = false});
  final String? requestId;
  final bool preview;
  @override
  ConsumerState<DocumentSavesScreen> createState() =>
      _DocumentSavesScreenState();
}

class _DocumentSavesScreenState extends ConsumerState<DocumentSavesScreen> {
  bool _opened = false;
  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(documentOutboxProvider);
    final focused = queue?.find(widget.requestId);
    if (!_opened && focused?['status'] == 'synced') {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final request = focused!['request'] as Map;
        final type = request['documentType'];
        context.go(widget.preview
            ? '/pdf-preview/$type/${request['documentId']}'
            : '/${type == 'invoice' ? 'invoices' : 'quotations'}/${request['documentId']}');
      });
    }
    return Scaffold(
        appBar: AppBar(title: const Text('Saved requests')),
        body: queue == null
            ? const PreviewStatusPanel(
                message: 'Sign in to see this account’s saved requests.')
            : !queue.loaded
                ? PreviewStatusPanel(
                    message: queue.storageError ?? 'Loading saved requests…',
                    loading: queue.storageError == null,
                    onRetry: queue.storageError != null ? queue.reload : null)
                : DocumentSavesContent(
                    entries: queue.entries,
                    storageError: queue.storageError,
                    onRetry: (id) async {
                      try {
                        await queue.retry(id);
                      } catch (_) {/* Storage error remains visible. */}
                    },
                    onOpen: (entry) {
                      final request = entry['request'] as Map;
                      context.push(
                          '/${request['documentType'] == 'invoice' ? 'invoices' : 'quotations'}/${request['documentId']}');
                    }));
  }
}

class DocumentSavesContent extends StatelessWidget {
  const DocumentSavesContent(
      {super.key,
      required this.entries,
      required this.onRetry,
      required this.onOpen,
      this.storageError});
  final List<Map<String, dynamic>> entries;
  final ValueChanged<String> onRetry;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final String? storageError;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  const SettingsSectionHeading('Your saved work', first: true),
                  const Text(
                      'Requests are kept on this device until the server confirms them. Connection failures retry while the app is open. Nothing is emailed automatically.'),
                  if (storageError != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(storageError!,
                            style: TextStyle(color: theme.colorScheme.error))),
                  const SizedBox(height: 24),
                  if (entries.isEmpty)
                    const Text(
                        'No saved requests yet. Save a quote or invoice to see its progress here.'),
                  for (final entry in entries.reversed)
                    _requestCard(context, entry),
                ])));
  }

  Widget _requestCard(BuildContext context, Map<String, dynamic> entry) {
    final theme = Theme.of(context);
    final request = entry['request'] as Map;
    final fields = request['fields'] as Map;
    final status = entry['status'];
    final label = switch (status) {
      'synced' => 'Saved to your company',
      'syncing' => 'Syncing…',
      'failed' => entry['retryable'] == true
          ? 'Waiting to retry'
          : 'Needs your attention',
      _ => 'Saved on this device'
    };
    return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
              '${request['documentType'] == 'invoice' ? 'Invoice' : 'Quotation'} · ${fields['customerName'] ?? ''}',
              style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Semantics(
              liveRegion: true,
              child: Text(label, style: theme.textTheme.titleMedium)),
          if (entry['error'] != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(entry['error'] as String)),
          const SizedBox(height: 12),
          if (status == 'failed')
            OutlinedButton.icon(
                onPressed: () => onRetry(entry['requestId'] as String),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry save')),
          if (status == 'synced' || request['mode'] == 'update')
            TextButton(
                onPressed: () => onOpen(entry),
                child: Text(status == 'synced'
                    ? 'Open document'
                    : 'Open current document')),
          TextButton(
              onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                        title: const Text('Your saved changes'),
                        content: SingleChildScrollView(
                            child: SelectableText(_summary(fields))),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'))
                        ],
                      )),
              child: const Text('View saved changes')),
        ]));
  }

  String _summary(Map fields) {
    final lines = <String>[
      '${fields['customerName'] ?? ''}',
      '${fields['customerEmail'] ?? ''}',
      if (fields['customerPhone'] != null) '${fields['customerPhone']}',
      if (fields['customerAddress'] != null) '${fields['customerAddress']}',
      if (fields['title'] != null) '\n${fields['title']}',
      '\nDate: ${fields['date']}',
      'Due / expiry: ${fields['dueDate'] ?? fields['expiryDate']}',
      for (final item in fields['items'] as List? ?? [])
        '\n${item['description']}\n${item['itemDetails'] ?? ''}\n${item['quantity']} × £${item['unitPrice']} = £${item['total']}',
      '\nSubtotal: £${fields['subtotal']}',
      'Discount: £${fields['discountAmount'] ?? 0}',
      'Tax (${fields['taxRate'] ?? 0}%): £${fields['taxAmount'] ?? 0}',
      'Total: £${fields['total']}',
      if (fields['notes'] != null) '\nNotes\n${fields['notes']}',
    ];
    return lines.join('\n');
  }
}
