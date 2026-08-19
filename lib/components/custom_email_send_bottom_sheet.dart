import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/custom_email_template.dart';
import '../providers/custom_email_template_provider.dart';
import 'custom_date_time_picker.dart';

class CustomEmailSendBottomSheet extends ConsumerStatefulWidget {
  final String docType; // 'quotation' | 'invoice'
  final String docNumber;
  final String customerName;
  final String customerEmail;
  final String totalAmount;
  final String companyId;
  final bool isPremiumUser;
  final Function(Map<String, dynamic> payload) onSendNow;
  final Function(DateTime sendAt, Map<String, dynamic> payload) onScheduleSend;

  const CustomEmailSendBottomSheet({
    super.key,
    required this.docType,
    required this.docNumber,
    required this.customerName,
    required this.customerEmail,
    required this.totalAmount,
    required this.companyId,
    required this.isPremiumUser,
    required this.onSendNow,
    required this.onScheduleSend,
  });

  @override
  ConsumerState<CustomEmailSendBottomSheet> createState() => _CustomEmailSendBottomSheetState();
}

class _CustomEmailSendBottomSheetState extends ConsumerState<CustomEmailSendBottomSheet> {
  late TextEditingController _subjectController;
  late TextEditingController _bodyController;
  late TextEditingController _newTemplateNameController;
  
  String? _selectedTemplateId = 'default';
  String _headerColor = '#f47421';
  bool _showAdvancedOptions = false;
  bool _showSaveInput = false;
  bool _isSavingTemplate = false;
  DateTime? _scheduledDateTime;

  final List<Map<String, String>> _mergeTags = [
    {'tag': '{customer_name}', 'label': 'Customer'},
    {'tag': '{document_number}', 'label': 'Doc #'},
    {'tag': '{total_amount}', 'label': 'Total'},
    {'tag': '{due_date_or_expiry}', 'label': 'Expiry/Due'},
    {'tag': '{portal_link}', 'label': 'Portal Link'},
    {'tag': '{company_name}', 'label': 'Company'},
  ];

  final List<Map<String, String>> _colorSwatches = [
    {'name': 'Brand Orange', 'hex': '#f47421'},
    {'name': 'Dark Slate', 'hex': '#0f172a'},
    {'name': 'Ocean Blue', 'hex': '#2563eb'},
    {'name': 'Forest Green', 'hex': '#059669'},
    {'name': 'Royal Purple', 'hex': '#7c3aed'},
    {'name': 'Crimson Red', 'hex': '#dc2626'},
  ];

  @override
  void initState() {
    super.initState();
    final docTitle = widget.docType == 'quotation' ? 'Quotation' : 'Invoice';
    _subjectController = TextEditingController(
      text: '$docTitle {document_number} from {company_name}',
    );
    _bodyController = TextEditingController(
      text: 'Hello {customer_name},\n\nPlease find attached your ${widget.docType} {document_number} for {total_amount}.\n\nYou can view and manage your document online using the link below.\n\nRegards,\n{company_name}',
    );
    _newTemplateNameController = TextEditingController();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _newTemplateNameController.dispose();
    super.dispose();
  }

  Color _parseHexColor(String hexString) {
    try {
      final hex = hexString.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFFF47421);
    }
  }

  void _insertMergeTag(String tag) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    if (selection.start >= 0 && selection.end >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, tag);
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + tag.length),
      );
    } else {
      _bodyController.text += tag;
    }
    setState(() {});
  }

  Future<void> _handleSaveTemplate(List<CustomEmailTemplate> existingTemplates) async {
    final name = _newTemplateNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a template name.')),
      );
      return;
    }

    setState(() => _isSavingTemplate = true);
    try {
      final repo = ref.read(customEmailTemplateRepositoryProvider);
      final newTpl = CustomEmailTemplate(
        id: '',
        companyId: widget.companyId,
        name: name,
        subject: _subjectController.text.trim(),
        body: _bodyController.text.trim(),
        type: widget.docType,
        headerColor: _headerColor,
      );

      final id = await repo.createTemplate(newTpl);
      if (id != null && mounted) {
        ref.invalidate(customEmailTemplatesProvider(widget.docType));
        setState(() {
          _selectedTemplateId = id;
          _showSaveInput = false;
          _newTemplateNameController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template "$name" saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving template: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingTemplate = false);
    }
  }

  Map<String, dynamic> _buildPayload() {
    final isCustom = _selectedTemplateId != 'default';
    if (isCustom) {
      return {
        'templateMode': 'custom',
        'customSubject': _subjectController.text.trim(),
        'customBody': _bodyController.text.trim(),
        'headerColor': _headerColor,
      };
    }
    return {'templateMode': 'default'};
  }

  String _renderPreviewSubject() {
    return _subjectController.text
        .replaceAll('{document_number}', widget.docNumber)
        .replaceAll('{company_name}', 'Your Company');
  }

  String _renderPreviewText() {
    return _bodyController.text
        .replaceAll('{customer_name}', widget.customerName)
        .replaceAll('{document_number}', widget.docNumber)
        .replaceAll('{total_amount}', widget.totalAmount)
        .replaceAll('{due_date_or_expiry}', DateFormat('d MMM yyyy').format(DateTime.now()))
        .replaceAll('{portal_link}', '#online-portal')
        .replaceAll('{company_name}', 'Your Company');
  }

  Future<void> _launchNativeEmailApp() async {
    final subject = _renderPreviewSubject();
    final body = _renderPreviewText();

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: widget.customerEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
        if (mounted) Navigator.pop(context);
      } else {
        await Share.share('$subject\n\n$body', subject: subject);
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      await Share.share('$subject\n\n$body', subject: subject);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final templatesAsync = ref.watch(customEmailTemplatesProvider(widget.docType));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grab handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Title & Recipient Badge Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send ${widget.docType == 'quotation' ? 'Quotation' : 'Invoice'} ${widget.docNumber}',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.mark_email_read_outlined,
                          size: 13, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'To: ${widget.customerEmail.isNotEmpty ? widget.customerEmail : widget.customerName}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Scrollable Editor Body
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Unified Template Selector Dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Email Template',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      if (!widget.isPremiumUser)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, size: 10, color: Colors.amber),
                              SizedBox(width: 3),
                              Text(
                                'PRO FEATURE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedTemplateId,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'default',
                        child: Text(
                          'Default Brand Template',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const DropdownMenuItem(
                        value: 'custom',
                        child: Text(
                          'Custom Email Body',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...templatesAsync.maybeWhen(
                        data: (templates) => templates.map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(
                              t.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        orElse: () => [],
                      ),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      if (val != 'default' && !widget.isPremiumUser) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Custom email templates are a Premium feature.'),
                          ),
                        );
                        return;
                      }
                      setState(() => _selectedTemplateId = val);
                      if (val != 'default' && val != 'custom') {
                        final list = templatesAsync.value ?? [];
                        final match = list.firstWhere((t) => t.id == val, orElse: () => list.first);
                        _subjectController.text = match.subject;
                        _bodyController.text = match.body;
                        if (match.headerColor != null) {
                          _headerColor = match.headerColor!;
                        }
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  if (_selectedTemplateId == 'default') ...[
                    // Uneditable Default Template Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.mark_email_read_rounded, color: colorScheme.primary, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Standard QOTG Template',
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Includes company branding, logo, summary table, total amount, and interactive online approval button.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Editable Subject Line
                    Text(
                      'Subject Line',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _subjectController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Enter subject line...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Editable Message Body
                    Text(
                      'Message Body',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _bodyController,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                      decoration: InputDecoration(
                        hintText: 'Write message...',
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Collapsible Advanced Styling & Tag Options Toggle
                    GestureDetector(
                      onTap: () => setState(() => _showAdvancedOptions = !_showAdvancedOptions),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              _showAdvancedOptions ? Icons.tune_rounded : Icons.tune_outlined,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showAdvancedOptions ? 'Hide Styling & Preview Options' : 'Styling, Tags & Live Preview',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              _showAdvancedOptions ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expanded Advanced Section
                    if (_showAdvancedOptions) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Merge Tag Chips
                            Text(
                              'Click tag to insert dynamic variable:',
                              style: textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _mergeTags.map((item) {
                                return ActionChip(
                                  label: Text(
                                    item['tag']!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  backgroundColor: colorScheme.primary.withValues(alpha: 0.08),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _insertMergeTag(item['tag']!),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),

                            // Header Banner Color Swatches
                            Text(
                              'Header Banner Color',
                              style: textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: _colorSwatches.map((swatch) {
                                final isSelected = _headerColor == swatch['hex'];
                                final color = _parseHexColor(swatch['hex']!);
                                return GestureDetector(
                                  onTap: () => setState(() => _headerColor = swatch['hex']!),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? colorScheme.primary : Colors.transparent,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),

                            // Save Template Action
                            if (!_showSaveInput)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => setState(() => _showSaveInput = true),
                                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                                  label: const Text('Save as Reusable Template', style: TextStyle(fontSize: 12)),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _newTemplateNameController,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: const InputDecoration(
                                        hintText: 'Template Name...',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _isSavingTemplate
                                        ? null
                                        : () => _handleSaveTemplate(templatesAsync.value ?? []),
                                    child: _isSavingTemplate
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('Save', style: TextStyle(fontSize: 12)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () => setState(() => _showSaveInput = false),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),

                            // Live Preview Container
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    color: _parseHexColor(_headerColor),
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Your Company',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          '${widget.docType == 'quotation' ? 'Quotation' : 'Invoice'} ${widget.docNumber}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    color: isDark ? const Color(0xFF1F1F24) : Colors.white,
                                    child: Text(
                                      _renderPreviewText(),
                                      style: textTheme.bodySmall?.copyWith(fontSize: 11, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  // Scheduled Date Badge Indicator
                  if (_scheduledDateTime != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, color: Colors.blue, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Scheduled: ${DateFormat('d MMM, HH:mm').format(_scheduledDateTime!)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _scheduledDateTime = null),
                            child: const Icon(Icons.close, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Streamlined 3-Button Footer Action Bar
          Row(
            children: [
              // Schedule Button
              IconButton.outlined(
                onPressed: () async {
                  final selected = await showModalBottomSheet<DateTime>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => CustomDateTimePickerSheet(
                      initialDateTime: DateTime.now().add(const Duration(minutes: 10)),
                      title: 'Schedule Delivery',
                    ),
                  );
                  if (selected != null) {
                    if (selected.isBefore(DateTime.now())) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Scheduled date must be in the future.')),
                        );
                      }
                      return;
                    }
                    setState(() => _scheduledDateTime = selected);
                    widget.onScheduleSend(selected, _buildPayload());
                  }
                },
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                tooltip: 'Schedule for Later',
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(width: 8),

              // Open in Native Email App Button
              IconButton.outlined(
                onPressed: _launchNativeEmailApp,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                tooltip: 'Open in Email App',
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(width: 10),

              // Send Email Primary Button
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    if (_scheduledDateTime != null) {
                      widget.onScheduleSend(_scheduledDateTime!, _buildPayload());
                    } else {
                      widget.onSendNow(_buildPayload());
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _scheduledDateTime != null ? 'Confirm Schedule' : 'Send Email',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
