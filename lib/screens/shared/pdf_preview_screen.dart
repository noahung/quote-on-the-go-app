import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../providers/providers.dart';
import '../../utils/feedback_controller.dart';
import '../../models/feedback_type.dart';

const _webAppBaseUrl = 'https://app.quoteonthego.co.uk';

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
  int _loadingProgress = 0;
  bool _hasError = false;
  bool _isSending = false;
  bool _isLoadingPdf = false;

  String get _pdfUrl => '$_webAppBaseUrl/api/${widget.type}s/${widget.id}/pdf';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onWebResourceError: (error) {
              if (mounted) {
                setState(() => _hasError = true);
              }
            },
          ),
        );
      _loadPdf();
    } else {
      _openWebPdf();
    }
  }

  Future<void> _loadPdf() async {
    if (kIsWeb) return;
    
    setState(() {
      _isLoadingPdf = true;
      _hasError = false;
      _loadingProgress = 10;
    });

    try {
      final response = await http.get(Uri.parse(_pdfUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final base64String = base64Encode(bytes);
        
        if (mounted) {
          setState(() {
            _loadingProgress = 50;
          });
          
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final htmlContent = _buildPdfHtml(base64String, isDark);
          await _webViewController?.loadHtmlString(htmlContent);
          
          if (mounted) {
            setState(() {
              _isLoadingPdf = false;
              _loadingProgress = 100;
            });
          }
        }
      } else {
        throw Exception('Failed to load PDF (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error loading PDF: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoadingPdf = false;
        });
      }
    }
  }

  String _buildPdfHtml(String base64String, bool isDark) {
    final bgColor = isDark ? '#0C0C0E' : '#FBFBFD';
    final pageBgColor = isDark ? '#1E1E24' : '#FFFFFF';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>
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
    pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
    
    const base64Data = "$base64String";
    
    async function renderPdf() {
      try {
        const binaryString = atob(base64Data);
        const len = binaryString.length;
        const bytes = new Uint8Array(len);
        for (let i = 0; i < len; i++) {
          bytes[i] = binaryString.charCodeAt(i);
        }
        
        const loadingTask = pdfjsLib.getDocument({ data: bytes.buffer });
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
      } catch (e) {
        console.error('PDF render error:', e);
        document.body.innerHTML = '<div style="color: red; padding: 20px; text-align: center; font-weight: bold;">Error rendering PDF preview: ' + e.message + '</div>';
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
    setState(() => _isSending = true);
    try {
      final String customerEmail;
      final String customerName;

      if (widget.type == 'invoice') {
        final invoice = ref.read(invoiceProvider(widget.id));
        if (invoice == null) throw Exception('Invoice not found');
        customerEmail = invoice.customerEmail;
        customerName = invoice.customerName;
      } else {
        final quotation = ref.read(quotationProvider(widget.id));
        if (quotation == null) throw Exception('Quotation not found');
        customerEmail = quotation.customerEmail;
        customerName = quotation.customerName;
      }

      final body = {
        '${widget.type}Id': widget.id,
        'customerEmail': customerEmail,
        'customerName': customerName,
      };

      final endpoint = widget.type == 'invoice' ? 'send-invoice' : 'send-quotation';
      final response = await http.post(
        Uri.parse('$_webAppBaseUrl/api/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          // If quotation, update status to Sent locally
          if (widget.type == 'quotation') {
            await ref
                .read(quotationRepositoryProvider)
                .updateQuotationStatus(widget.id, 'Sent');
          } else {
            await ref
                .read(invoiceRepositoryProvider)
                .updateInvoiceStatus(widget.id, 'Sent');
          }

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
        } else {
          String err = 'Failed to send email (${response.statusCode})';
          try {
            err = jsonDecode(response.body)['error'] ?? err;
          } catch (_) {}
          ref.read(feedbackControllerProvider).error(context, err);
        }
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              onPressed: _loadPdf,
            ),
        ],
      ),
      body: kIsWeb
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.fileText, size: 64, color: Colors.grey),
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
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.alertTriangle,
                            size: 60, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'Failed to load document preview',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadPdf,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  )
                else if (_webViewController != null)
                  WebViewWidget(controller: _webViewController!),
                if ((_loadingProgress < 100 || _isLoadingPdf) && !_hasError)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: _loadingProgress / 100.0,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Generating PDF Preview... $_loadingProgress%',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.97),
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: _isSending
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Sending Email...',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        shape: const StadiumBorder(),
                        side: BorderSide(color: colorScheme.outlineVariant),
                        backgroundColor: isDark
                            ? const Color(0xFF1E1E24)
                            : const Color(0xFFF0F4F9),
                      ),
                      onPressed: () {
                        // Go to the detail screen directly as a draft
                        context.go('/${widget.type}s/${widget.id}');
                      },
                      child: Text(
                        'Keep as Draft',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF004A77)
                              : const Color(0xFFC2E7FF),
                          foregroundColor: isDark
                              ? const Color(0xFFC2E7FF)
                              : const Color(0xFF001D35),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(LucideIcons.send, size: 16),
                        label: const Text(
                          'Send to Client',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: _sendByEmail,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
