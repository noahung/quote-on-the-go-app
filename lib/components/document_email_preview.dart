import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/api_client.dart';
import 'preview_status_panel.dart';

/// Uses exactly the HTML renderer used by immediate and scheduled server sends.
class DocumentEmailPreview extends StatefulWidget {
  const DocumentEmailPreview(
      {super.key,
      required this.documentId,
      required this.documentType,
      required this.options})
      : _reminderCompanyId = null,
        _reminderTemplate = null;
  const DocumentEmailPreview.reminder(
      {super.key, required String companyId, required String template})
      : _reminderCompanyId = companyId,
        _reminderTemplate = template,
        documentId = '',
        documentType = '',
        options = const {};
  final String? _reminderCompanyId, _reminderTemplate;
  final String documentId, documentType;
  final Map<String, dynamic> options;
  @override
  State<DocumentEmailPreview> createState() => _DocumentEmailPreviewState();
}

class _DocumentEmailPreviewState extends State<DocumentEmailPreview> {
  WebViewController? _controller;
  String? _error, _subject;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reminder = widget._reminderCompanyId != null;
      final result = await ApiClient.post(
          reminder ? '/api/reminder-preview' : '/api/email-preview',
          reminder
              ? {
                  'companyId': widget._reminderCompanyId,
                  'template': widget._reminderTemplate
                }
              : {
                  'documentId': widget.documentId,
                  'documentType': widget.documentType,
                  'options': widget.options
                });
      if (!mounted) return;
      final html = result['htmlContent'];
      if (html is! String || html.isEmpty) throw const FormatException();
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.disabled)
        ..setNavigationDelegate(NavigationDelegate(
            onNavigationRequest: (request) => request.url == 'about:blank' ||
                    request.url.startsWith('data:text/html')
                ? NavigationDecision.navigate
                : NavigationDecision.prevent));
      await controller.loadHtmlString(html);
      if (mounted) {
        setState(() {
          _controller = controller;
          _subject = result['subject'] as String?;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not load the email preview. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Email preview')),
        body: SafeArea(
            child: _loading
                ? const PreviewStatusPanel(
                    message: 'Loading email preview…', loading: true)
                : _error != null
                    ? PreviewStatusPanel(message: _error!, onRetry: _load)
                    : LayoutBuilder(
                        builder: (context, constraints) => ListView(children: [
                              Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (widget._reminderCompanyId !=
                                            null) ...[
                                          Text('Sample reminder',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall),
                                          const SizedBox(height: 12),
                                          const Text(
                                              'Your current message and company branding, with a sample customer, invoice and date. Nothing is sent from this preview.'),
                                          const SizedBox(height: 12),
                                        ],
                                        if (_subject != null)
                                          Text('Subject: $_subject',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium),
                                        const SizedBox(height: 12),
                                        const Text(
                                            'Your customer’s email app may adjust fonts and colours. Preview links are disabled.'),
                                      ])),
                              SizedBox(
                                  height: constraints.maxHeight < 480
                                      ? 360
                                      : constraints.maxHeight * .75,
                                  child:
                                      WebViewWidget(controller: _controller!)),
                            ]))),
      );
}
