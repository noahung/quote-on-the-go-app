import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/expense.dart';
import '../../providers/providers.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../theme/semantic_colors.dart';

const List<String> _kCategories = [
  'Materials',
  'Labour',
  'Tools & Equipment',
  'Transport',
  'Fuel',
  'Subcontractors',
  'Office & Admin',
  'Marketing',
  'Software',
  'Insurance',
  'Utilities',
  'Other',
];

final expenseDetailProvider =
    StreamProvider.autoDispose.family<Expense?, String>((ref, id) {
  final companyId = ref.watch(companyIdProvider);
  if (companyId == null) return const Stream.empty();
  return ref
      .watch(firestoreProvider)
      .collection('expenses')
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? Expense.fromFirestore(doc) : null);
});

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  final String expenseId;
  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  bool _isEditMode = false;
  bool _isSaving = false;
  bool _isUploadingReceipt = false;

  final _formKey = GlobalKey<FormState>();
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = _kCategories.first;
  DateTime _selectedDate = DateTime.now();
  String? _currentReceiptUrl;

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _populateForm(Expense expense) {
    _merchantController.text = expense.merchant;
    _amountController.text = expense.amount.toStringAsFixed(2);
    _descriptionController.text = expense.description ?? '';
    _selectedCategory = expense.category;
    _selectedDate = DateTime.tryParse(expense.date) ?? DateTime.now();
    _currentReceiptUrl = expense.receiptUrl;
  }

  Future<void> _pickAndUploadReceipt(Expense expense) async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _isUploadingReceipt = true);
    try {
      final file = File(picked.path);
      final ext = picked.path.split('.').last;
      final ref = FirebaseStorage.instance
          .ref('receipts/${expense.companyId}/${expense.id}.$ext');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await this.ref.read(expenseRepositoryProvider).updateExpense(
            expense.copyWith(receiptUrl: url),
          );
      if (mounted) {
        setState(() => _currentReceiptUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingReceipt = false);
    }
  }

  Future<void> _saveEdit(Expense expense) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final updated = expense.copyWith(
        merchant: _merchantController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        category: _selectedCategory,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );
      await ref.read(expenseRepositoryProvider).updateExpense(updated);
      if (mounted) {
        setState(() => _isEditMode = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text(
            'Are you sure you want to delete this expense? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(expenseRepositoryProvider).deleteExpense(expense.id);
      if (mounted) context.pop();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final expenseAsync =
        ref.watch(expenseDetailProvider(widget.expenseId));

    return expenseAsync.when(
      loading: () => const MeshBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => MeshBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: Text('Error: $e')),
        ),
      ),
      data: (expense) {
        if (expense == null) {
          return const MeshBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(child: Text('Expense not found')),
            ),
          );
        }
        if (!_isEditMode) {
          _currentReceiptUrl = expense.receiptUrl;
        }
        return _buildView(expense);
      },
    );
  }

  Widget _buildView(Expense expense) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    switch (expense.status.toLowerCase()) {
      case 'approved':
        statusColor = semanticColors.success;
        break;
      case 'rejected':
        statusColor = semanticColors.error;
        break;
      default:
        statusColor = semanticColors.warning;
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/expenses');
              }
            },
          ),
          title: Text(
            _isEditMode ? 'Edit Expense' : 'Expense Details',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          actions: [
            if (!_isEditMode) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: () {
                  _populateForm(expense);
                  setState(() => _isEditMode = true);
                },
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: semanticColors.error),
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(expense),
              ),
            ] else ...[
              TextButton(
                onPressed: () => setState(() => _isEditMode = false),
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
        body: _isEditMode
            ? _buildEditForm(expense, colorScheme, isDark)
            : _buildDetailView(
                expense, colorScheme, semanticColors, statusColor, isDark),
      ),
    );
  }

  Widget _buildDetailView(
    Expense expense,
    ColorScheme colorScheme,
    SemanticColors semanticColors,
    Color statusColor,
    bool isDark,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero amount card
        GlassCard(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                '-${NumberFormat.currency(symbol: expense.currency ?? '£').format(expense.amount)}',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.error,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: statusColor.withValues(alpha: 0.24)),
                ),
                child: Text(
                  expense.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Details card
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Expense Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                  Icons.store_outlined, 'Merchant', expense.merchant,
                  colorScheme: colorScheme),
              const Divider(height: 24),
              _buildDetailRow(Icons.category_outlined, 'Category',
                  expense.category,
                  colorScheme: colorScheme),
              const Divider(height: 24),
              _buildDetailRow(
                  Icons.calendar_today_outlined, 'Date', expense.date,
                  colorScheme: colorScheme),
              if (expense.description != null &&
                  expense.description!.isNotEmpty) ...[
                const Divider(height: 24),
                _buildDetailRow(Icons.notes_outlined, 'Notes',
                    expense.description!,
                    colorScheme: colorScheme),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Receipt card
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Receipt',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (!_isUploadingReceipt)
                    TextButton.icon(
                      onPressed: () => _pickAndUploadReceipt(expense),
                      icon: const Icon(Icons.upload_outlined, size: 16),
                      label: Text(
                          _currentReceiptUrl != null ? 'Replace' : 'Upload'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isUploadingReceipt)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_currentReceiptUrl != null &&
                  _currentReceiptUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: _currentReceiptUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 180,
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined,
                                color: colorScheme.outline),
                            const SizedBox(height: 4),
                            Text('Could not load receipt',
                                style:
                                    TextStyle(color: colorScheme.outline, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                InkWell(
                  onTap: () => _pickAndUploadReceipt(expense),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                          style: BorderStyle.solid),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.upload_file_outlined,
                            size: 36, color: colorScheme.outline),
                        const SizedBox(height: 8),
                        Text('Tap to attach receipt',
                            style: TextStyle(color: colorScheme.outline)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Delete button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: semanticColors.error),
              foregroundColor: semanticColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _confirmDelete(expense),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete Expense',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    required ColorScheme colorScheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.outline),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm(
      Expense expense, ColorScheme colorScheme, bool isDark) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    prefixText: '£ ',
                    prefixStyle: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface.withValues(alpha: 0.6)),
                    hintText: '0.00',
                    border: InputBorder.none,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.trim()) == null) return 'Invalid number';
                    if (double.parse(v.trim()) <= 0) return 'Must be > 0';
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _merchantController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Merchant / Supplier',
              prefixIcon: const Icon(Icons.store_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: 'Category',
              prefixIcon: const Icon(Icons.category_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _kCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) =>
                setState(() => _selectedCategory = v ?? _kCategories.first),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date',
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              child: Text(
                DateFormat('EEE, d MMMM yyyy').format(_selectedDate),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: const Icon(Icons.notes_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed:
                  _isSaving ? null : () => _saveEdit(expense),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save Changes'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
