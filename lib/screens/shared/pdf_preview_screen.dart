import '../../services/api_client.dart';
import '../../services/pdf_service.dart';
import '../../services/pdf_transport.dart';
import 'dart:convert';
import 'dart:async';
import '../../components/preview_status_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../providers/providers.dart';
import '../../utils/feedback_controller.dart';
import '../../models/feedback_type.dart';

String get _webAppBaseUrl => ApiClient.baseUrl;

class PdfPreviewScreen extends ConsumerStatefulWidget {
  final String type; // 'invoice' or 'quotation'
  final String id;

  const PdfPreviewScreen({
    super.key,
    required this.type,
    required this.id,
  });

  @override
  ConsumerState<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends ConsumerState<PdfPreviewScreen> {
  WebViewController? _webViewController;
  int _renderAttempt = 0;
  Timer? _renderTimeout;
  bool _hasError = false;
  String _errorMessage =
      'Could not load the PDF. Check your connection and try again.';
  bool _isSending = false;
  bool _isLoadingPdf = false;

  String get _pdfUrl => '$_webAppBaseUrl/api/${widget.type}s/${widget.id}/pdf';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel('PdfPreview', onMessageReceived: (message) {
          if (!mounted || !message.message.startsWith('$_renderAttempt:')) {
            return;
          }
          _renderTimeout?.cancel();
          setState(() {
            _isLoadingPdf = false;
            _hasError = message.message != '$_renderAttempt:ready';
            if (_hasError) {
              _errorMessage =
                  'The PDF could not be displayed. Check your connection and try again.';
            }
          });
        })
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) => request.url == 'about:blank' ||
                    request.url.startsWith('data:text/html')
                ? NavigationDecision.navigate
                : NavigationDecision.prevent,
            onWebResourceError: (error) {
              if (mounted) {
                _renderTimeout?.cancel();
                setState(() {
                  _hasError = true;
                  _isLoadingPdf = false;
                });
              }
            },
          ),
        );
      _loadPdf();
    } else {
      _openWebPdf();
    }
  }

  @override
  void dispose() {
    _renderTimeout?.cancel();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    if (kIsWeb || _isLoadingPdf) return;

    setState(() {
      _isLoadingPdf = true;
      _hasError = false;
      _errorMessage =
          'Could not load the PDF. Check your connection and try again.';
    });

    final attempt = ++_renderAttempt;
    try {
      final bytes = widget.type == 'invoice'
          ? await PdfService.fetchInvoicePdf(widget.id)
          : await PdfService.fetchQuotationPdf(widget.id);
      if (!mounted || attempt != _renderAttempt) return;
      final html = _buildPdfHtml(base64Encode(bytes),
          Theme.of(context).brightness == Brightness.dark, attempt);
      _renderTimeout?.cancel();
      _renderTimeout = Timer(const Duration(seconds: 30), () {
        if (!mounted || attempt != _renderAttempt) return;
        setState(() {
          _hasError = true;
          _isLoadingPdf = false;
          _errorMessage =
              'The PDF preview is taking too long. Check your connection and try again.';
        });
      });
      await _webViewController?.loadHtmlString(html);
    } catch (e) {
      debugPrint('Error loading PDF: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e is PdfDownloadException
              ? e.message
              : 'Could not load the PDF. Check your connection and try again.';
          _isLoadingPdf = false;
        });
      }
    }
  }

  String _buildPdfHtml(String base64String, bool isDark, int attempt) {
    final bgColor = isDark ? '#1D1E19' : '#FBF8F2';
    final pageBgColor = '#FFFFFF';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js" onerror="PdfPreview.postMessage('$attempt:error')"></script>
  <style>
    body { 
      margin: 0; 
      padding: 10px 0; 
      background-color: $bgColor; 
      display: flex; 
      flex-direction: column; 
      align-items: center; 
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }
    .page-container { 
      margin: 8px 0; 
      box-shadow: 0 2px 8px rgba(0,0,0,0.15); 
      background-color: $pageBgColor; 
      width: calc(100% - 32px);
      max-width: 600px;
      border-radius: 12px;
      overflow: hidden;
    }
    canvas { 
      display: block; 
      width: 100% !important; 
      height: auto !important; 
    }
  </style>
</head>
<body>
  <div id="pdf-container" style="width: 100%; display: flex; flex-direction: column; align-items: center;"></div>
  <script>

    
    const base64Data = "$base64String";
    
    async function renderPdf() {
      try {
        pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
        const binaryString = atob(base64Data);
        const len = binaryString.length;
        const bytes = new Uint8Array(len);
        for (let i = 0; i < len; i++) {
          bytes[i] = binaryString.charCodeAt(i);
        }
        
        const loadingTask = pdfjsLib.getDocument({ data: bytes.buffer, isEvalSupported: false });
        const pdf = await loadingTask.promise;
        const container = document.getElementById('pdf-container');
        
        for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
          const page = await pdf.getPage(pageNum);
          
          // Render at high resolution for crisp text, CSS handles scale
          const viewport = page.getViewport({ scale: 2.0 });
          const pageDiv = document.createElement('div');
          pageDiv.className = 'page-container';
          
          const canvas = document.createElement('canvas');
          const context = canvas.getContext('2d');
          canvas.height = viewport.height;
          canvas.width = viewport.width;
          
          pageDiv.appendChild(canvas);
          container.appendChild(pageDiv);
          
          await page.render({ canvasContext: context, viewport: viewport }).promise;
        }
        PdfPreview.postMessage('$attempt:ready');
      } catch (e) {
        PdfPreview.postMessage('$attempt:error');
        console.error('PDF render error:', e);
        document.body.textContent = 'The PDF could not be displayed. Return to the document and try again.';
      }
    }
    
    renderPdf();
  </script>
</body>
</html>
''';
  }

  Future<void> _openWebPdf() async {
    final uri = Uri.parse(_pdfUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _sendByEmail() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      final String customerEmail;
      final String customerName;

      if (widget.type == 'invoice') {
        final invoice = ref.read(invoiceProvider(widget.id));
        if (invoice == null) throw Exception('Invoice not found');
        if (invoice.requiresApproval == true ||
            ['pending', 'rejected'].contains(invoice.approvalStatus)) {
          throw Exception(
              'This document needs approval before it can be sent.');
        }
        customerEmail = invoice.customerEmail;
        customerName = invoice.customerName;
      } else {
        final quotation = ref.read(quotationProvider(widget.id));
        if (quotation == null) throw Exception('Quotation not found');
        if (quotation.requiresApproval == true ||
            ['pending', 'rejected'].contains(quotation.approvalStatus)) {
          throw Exception(
              'This document needs approval before it can be sent.');
        }
        customerEmail = quotation.customerEmail;
        customerName = quotation.customerName;
      }

      final body = {
        '${widget.type}Id': widget.id,
        'customerEmail': customerEmail,
        'customerName': customerName,
      };

      final endpoint =
          widget.type == 'invoice' ? 'send-invoice' : 'send-quotation';
      await ApiClient.post('/api/$endpoint', body);
      // The server owns document status; resending must never reset Paid/Accepted.
      if (mounted) {
        await ref.read(feedbackControllerProvider).showCelebration(
              context: context,
              type: CelebrationType.send,
              title: 'Document Sent',
              subtitle: 'Sent to $customerName successfully',
              onDone: () {
                // Redirect to the detail screen
                context.go('/${widget.type}s/${widget.id}');
              },
            );
      }
    } catch (e) {
      if (mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title =
        'Preview ${widget.type[0].toUpperCase()}${widget.type.substring(1)}';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            // If they cancel, keep it as draft and go to the details
            context.go('/${widget.type}s/${widget.id}');
          },
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(LucideIcons.refreshCw),
              onPressed: _isLoadingPdf ? null : _loadPdf,
            ),
        ],
      ),
      body: kIsWeb
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.fileText,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Preview opened in a new tab',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _openWebPdf,
                    child: const Text('Re-open Preview PDF'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                if (_hasError)
                  PreviewStatusPanel(message: _errorMessage, onRetry: _loadPdf)
                else if (_webViewController != null)
                  WebViewWidget(controller: _webViewController!),
                if (_isLoadingPdf && !_hasError)
                  const PreviewStatusPanel(
                      message: 'Preparing your PDF…', loading: true),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _isSending ? null : _sendByEmail,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.send, size: 20),
                  label: Text(_isSending ? 'Sending email…' : 'Send to client'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isSending
                      ? null
                      : () => context.go('/${widget.type}s/${widget.id}'),
                  child: const Text('Back to document'),
                ),
              ]),
        ),
      ),
    );
  }
}
