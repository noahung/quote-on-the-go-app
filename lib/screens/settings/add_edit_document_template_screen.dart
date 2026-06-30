import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/feedback_controller.dart';
import '../../models/feedback_type.dart';

class AddEditDocumentTemplateScreen extends ConsumerStatefulWidget {
  final DocumentTemplate? existingTemplate;
  const AddEditDocumentTemplateScreen({super.key, this.existingTemplate});

  @override
  ConsumerState<AddEditDocumentTemplateScreen> createState() =>
      _AddEditDocumentTemplateScreenState();
}

class _AddEditDocumentTemplateScreenState
    extends ConsumerState<AddEditDocumentTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _taxRateController = TextEditingController(text: '0.0');

  String _type = 'quotation'; // 'quotation' | 'invoice'
  final List<LineItem> _lineItems = [];
  bool _isLoading = false;

  bool get _isEditing => widget.existingTemplate != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final t = widget.existingTemplate!;
      _nameController.text = t.name;
      _descriptionController.text = t.description ?? '';
      _notesController.text = t.notes ?? '';
      _taxRateController.text = (t.taxRate ?? 0.0).toStringAsFixed(1);
      _type = t.type;
      _lineItems.addAll(t.items);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _lineItems.fold(0.0, (sum, item) => sum + item.total);
  }

  double get _taxAmount {
    final taxRate = double.tryParse(_taxRateController.text.trim()) ?? 0.0;
    return _subtotal * (taxRate / 100);
  }

  double get _total {
    return _subtotal + _taxAmount;
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    if (_lineItems.isEmpty) {
      ref.read(feedbackControllerProvider).warning(context, 'Please add at least one item to the template');
      return;
    }

    final companyId = ref.read(companyIdProvider);
    if (companyId == null) {
      ref.read(feedbackControllerProvider).error(context, 'Company profile not found');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(documentTemplateRepositoryProvider);
      final taxRate = double.tryParse(_taxRateController.text.trim()) ?? 0.0;

      if (_isEditing) {
        await repository.updateTemplate(
          widget.existingTemplate!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          type: _type,
          items: _lineItems,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          taxRate: taxRate,
        );

        if (mounted) {
          ref.read(feedbackControllerProvider).success(context, 'Template updated successfully');
          context.pop();
        }
      } else {
        await repository.createTemplate(
          companyId: companyId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          type: _type,
          items: _lineItems,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          taxRate: taxRate,
        );

        if (mounted) {
          await ref.read(feedbackControllerProvider).showCelebration(
            context: context,
            type: CelebrationType.checkmark,
            title: 'Template Created',
            subtitle: 'Your new document template is ready to use',
            onDone: () => context.pop(),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Failed to save template: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddItemSheet({LineItem? existingItem, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddItemSheet(
        existingItem: existingItem,
        onSave: (newItem) {
          setState(() {
            if (index != null) {
              _lineItems[index] = newItem;
            } else {
              _lineItems.add(newItem);
            }
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _lineItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fieldFill = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.04);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            _isEditing ? 'Edit Template' : 'New Template',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Template Details',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Template Name',
                        hintText: 'e.g. Standard Boiler Service',
                        prefixIcon: const Icon(LucideIcons.tag),
                        filled: true,
                        fillColor: fieldFill,
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Template name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'Short description for internal reference',
                        prefixIcon: const Icon(LucideIcons.fileText),
                        filled: true,
                        fillColor: fieldFill,
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Template Type',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TypeToggleButton(
                              label: 'Quotation',
                              icon: LucideIcons.quote,
                              isSelected: _type == 'quotation',
                              onTap: () => setState(() => _type = 'quotation'),
                            ),
                          ),
                          Expanded(
                            child: _TypeToggleButton(
                              label: 'Invoice',
                              icon: LucideIcons.receipt,
                              isSelected: _type == 'invoice',
                              onTap: () => setState(() => _type = 'invoice'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Items Section
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Line Items',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        TextButton.icon(
                          onPressed: () => _showAddItemSheet(),
                          icon: const Icon(LucideIcons.plus, size: 18),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_lineItems.isEmpty) ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Icon(
                                LucideIcons.layers,
                                size: 36,
                                color: colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No items added yet',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _lineItems.length,
                        itemBuilder: (context, index) {
                          final item = _lineItems[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                            child: ListTile(
                              title: Text(
                                item.description,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${item.quantity.toStringAsFixed(0)} × ${NumberFormat.currency(symbol: '£').format(item.unitPrice)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    NumberFormat.currency(symbol: '£').format(item.total),
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    icon: const Icon(LucideIcons.moreVertical, size: 16),
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        _showAddItemSheet(existingItem: item, index: index);
                                      } else if (val == 'delete') {
                                        _removeItem(index);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Summary & Notes Section
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Taxes & Summary',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _taxRateController,
                      decoration: InputDecoration(
                        labelText: 'Tax Rate (%)',
                        hintText: 'e.g. 20.0',
                        prefixIcon: const Icon(LucideIcons.percent),
                        filled: true,
                        fillColor: fieldFill,
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal',
                          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                        Text(
                          NumberFormat.currency(symbol: '£').format(_subtotal),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tax Amount',
                          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                        Text(
                          NumberFormat.currency(symbol: '£').format(_taxAmount),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        Text(
                          NumberFormat.currency(symbol: '£').format(_total),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Notes Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Default Notes',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        hintText: 'Add payment terms, job notes, or messages for the customer...',
                        filled: true,
                        fillColor: fieldFill,
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                        ),
                      ),
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _saveTemplate,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(_isEditing ? LucideIcons.save : LucideIcons.check),
                  label: Text(_isEditing ? 'Save Template' : 'Create Template'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddItemSheet extends StatefulWidget {
  final LineItem? existingItem;
  final ValueChanged<LineItem> onSave;

  const _AddItemSheet({
    this.existingItem,
    required this.onSave,
  });

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _itemDetailsController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final item = widget.existingItem!;
      _descriptionController.text = item.description;
      _itemDetailsController.text = item.itemDetails ?? '';
      _quantityController.text = item.quantity.toStringAsFixed(0);
      _priceController.text = item.unitPrice.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _itemDetailsController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final quantity = double.tryParse(_quantityController.text.trim()) ?? 1.0;
    final unitPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final total = quantity * unitPrice;

    final item = LineItem(
      id: _isEditing ? widget.existingItem!.id : const Uuid().v4(),
      description: _descriptionController.text.trim(),
      itemDetails: _itemDetailsController.text.trim().isEmpty
          ? null
          : _itemDetailsController.text.trim(),
      quantity: quantity,
      unitPrice: unitPrice,
      total: total,
    );

    widget.onSave(item);
    Navigator.pop(context);
  }

  InputDecoration _fieldDeco(BuildContext context, String label, String hint, {String? prefixText}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.07)
          : const Color(0xFFF5F5F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 12,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      _isEditing ? 'Edit Item' : 'Add Item',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Positioned(
                      right: 0,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: isDark ? 0.25 : 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.x,
                            size: 16,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _descriptionController,
                  decoration: _fieldDeco(context, 'Description', 'e.g. Boiler Service'),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Description is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _itemDetailsController,
                  decoration: _fieldDeco(context, 'Detailed Description (optional)', 'Additional item specifics...'),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: _fieldDeco(context, 'Qty', '1'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (double.tryParse(v.trim()) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _priceController,
                        decoration: _fieldDeco(context, 'Unit Price', '0.00', prefixText: '£ '),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (double.tryParse(v.trim()) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(_isEditing ? 'Save Item' : 'Add Item'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
