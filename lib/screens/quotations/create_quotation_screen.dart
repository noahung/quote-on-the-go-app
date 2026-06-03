import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../components/mesh_background.dart';
import '../../components/glass_card.dart';
import '../../components/pill_button.dart';

class CreateQuotationScreen extends ConsumerStatefulWidget {
  final Quotation? existingQuotation;
  final Customer? prefilledCustomer;

  const CreateQuotationScreen({
    super.key,
    this.existingQuotation,
    this.prefilledCustomer,
  });

  @override
  ConsumerState<CreateQuotationScreen> createState() =>
      _CreateQuotationScreenState();
}

class _CreateQuotationScreenState extends ConsumerState<CreateQuotationScreen> {
  int _currentStep = 0;
  bool _showPreviewInReview = false;
  bool _isLoading = false;

  // Step 1: Customer
  Customer? _selectedCustomer;
  final _customerNameController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();

  // Step 2: Line Items
  final List<LineItem> _lineItems = [];

  // Step 3: Review
  final _notesController = TextEditingController();
  final _taxRateController = TextEditingController(text: '0.0');
  double _taxRate = 0.0;

  // Dates
  String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _expiryDate = DateFormat(
    'yyyy-MM-dd',
  ).format(DateTime.now().add(const Duration(days: 30)));

  bool get _isEditing => widget.existingQuotation != null;

  @override
  void initState() {
    super.initState();
    final q = widget.existingQuotation;
    if (q != null) {
      _customerNameController.text = q.customerName;
      _customerEmailController.text = q.customerEmail;
      _customerPhoneController.text = q.customerPhone ?? '';
      _customerAddressController.text = q.customerAddress ?? '';
      _lineItems.addAll(q.items);
      _notesController.text = q.notes ?? '';
      _taxRate = q.taxRate ?? 0.0;
      _taxRateController.text = (_taxRate).toStringAsFixed(1);
      _date = q.date;
      _expiryDate = q.expiryDate;
    } else if (widget.prefilledCustomer != null) {
      final c = widget.prefilledCustomer!;
      _customerNameController.text = c.name;
      _customerEmailController.text = c.email;
      _customerPhoneController.text = c.phone ?? '';
      _customerAddressController.text = c.address ?? '';
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerEmailController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _notesController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _lineItems.fold(0.0, (sum, item) => sum + item.total);
  }

  double get _taxAmount {
    return _subtotal * (_taxRate / 100);
  }

  double get _total {
    return _subtotal + _taxAmount;
  }

  Future<void> _saveQuotation() async {
    final companyId = ref.read(companyIdProvider);
    final userProfile = ref.read(userProfileProvider);

    if (companyId == null || userProfile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User or company not found')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(quotationRepositoryProvider);

      if (_isEditing) {
        await repository.updateQuotation(widget.existingQuotation!.id, {
          'customerName': _customerNameController.text.trim(),
          'customerEmail': _customerEmailController.text.trim(),
          'customerPhone': _customerPhoneController.text.trim().isEmpty
              ? null
              : _customerPhoneController.text.trim(),
          'customerAddress': _customerAddressController.text.trim().isEmpty
              ? null
              : _customerAddressController.text.trim(),
          'date': _date,
          'expiryDate': _expiryDate,
          'items': _lineItems.map((i) => i.toJson()).toList(),
          'subtotal': _subtotal,
          'taxRate': _taxRate,
          'taxAmount': _taxAmount,
          'total': _total,
          'notes': _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quotation updated successfully')),
          );
          context.pop();
        }
      } else {
        final quotation = Quotation(
          id: '',
          companyId: companyId,
          createdBy: userProfile.uid,
          quotationNumber: 'QT-${DateTime.now().millisecondsSinceEpoch}',
          customerName: _customerNameController.text.trim(),
          customerEmail: _customerEmailController.text.trim(),
          customerPhone: _customerPhoneController.text.trim().isEmpty
              ? null
              : _customerPhoneController.text.trim(),
          customerAddress: _customerAddressController.text.trim().isEmpty
              ? null
              : _customerAddressController.text.trim(),
          date: _date,
          expiryDate: _expiryDate,
          items: _lineItems,
          subtotal: _subtotal,
          taxRate: _taxRate,
          taxAmount: _taxAmount,
          total: _total,
          status: 'Draft',
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
        final newId = await repository.createQuotation(quotation);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quotation created successfully')),
          );
          context.go('/quotations/$newId');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save quotation: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onCustomerSelected(Customer customer) {
    setState(() {
      _selectedCustomer = customer;
      _customerNameController.text = customer.name;
      _customerEmailController.text = customer.email;
      _customerPhoneController.text = customer.phone ?? '';
      _customerAddressController.text = customer.address ?? '';
    });
  }

  void _addLineItem(LineItem item) {
    setState(() {
      _lineItems.add(item);
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      _lineItems.removeAt(index);
    });
  }

  void _editLineItem(int index, LineItem updated) {
    setState(() {
      _lineItems[index] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            _isEditing ? 'Edit Quotation' : 'New Quotation',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ),
        body: Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepTapped: (step) {
            if (step < _currentStep) {
              setState(() => _currentStep = step);
            }
          },
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() => _currentStep++);
            } else {
              _saveQuotation();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _isLoading && _currentStep == 2
                        ? Center(
                            child: CircularProgressIndicator(
                              color: colorScheme.primary,
                            ),
                          )
                        : PillButton(
                            text: _currentStep == 2
                                ? (_isEditing ? 'Save Changes' : 'Create Quote')
                                : 'Next',
                            onTap: details.onStepContinue,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: details.onStepCancel,
                      child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
                    ),
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Customer'),
              content: _buildCustomerStep(),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Items'),
              content: _buildLineItemsStep(),
              isActive: _currentStep >= 1,
              state: _currentStep > 1
                  ? StepState.complete
                  : _currentStep == 1
                      ? StepState.indexed
                      : StepState.disabled,
            ),
            Step(
              title: const Text('Review'),
              content: _buildReviewStep(),
              isActive: _currentStep >= 2,
              state: _currentStep == 2 ? StepState.indexed : StepState.disabled,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerStep() {
    final customers = ref.watch(customersProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (customers.isNotEmpty) ...[
            DropdownButtonFormField<Customer?>(
              initialValue: _selectedCustomer,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: const InputDecoration(
                labelText: 'Select Existing Customer',
                labelStyle: TextStyle(fontSize: 13),
                prefixIcon: Icon(Icons.person_search),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Manual entry...'),
                ),
                ...customers.map((customer) {
                  return DropdownMenuItem(
                    value: customer,
                    child: Text(customer.name),
                  );
                }),
              ],
              onChanged: (customer) {
                if (customer != null) {
                  _onCustomerSelected(customer);
                } else {
                  setState(() {
                    _selectedCustomer = null;
                    _customerNameController.clear();
                    _customerEmailController.clear();
                    _customerPhoneController.clear();
                    _customerAddressController.clear();
                  });
                }
              },
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _customerNameController,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Customer Name *',
              labelStyle: TextStyle(fontSize: 13),
              prefixIcon: Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerEmailController,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Email *',
              labelStyle: TextStyle(fontSize: 13),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerPhoneController,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Phone',
              labelStyle: TextStyle(fontSize: 13),
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerAddressController,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Address',
              labelStyle: TextStyle(fontSize: 13),
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          _buildDateField(
            label: 'Quote Date',
            value: _date,
            onTap: () => _pickDate(context, true),
          ),
          const SizedBox(height: 12),
          _buildDateField(
            label: 'Expiry Date',
            value: _expiryDate,
            onTap: () => _pickDate(context, false),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, bool isQuoteDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isQuoteDate ? DateTime.parse(_date) : DateTime.parse(_expiryDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isQuoteDate) {
          _date = DateFormat('yyyy-MM-dd').format(picked);
        } else {
          _expiryDate = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }

  Widget _buildLineItemsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_lineItems.isEmpty)
          const AppEmptyState(
            icon: Icons.shopping_cart_outlined,
            title: 'No Items Added',
            subtitle: 'Add line items to build your quotation',
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _lineItems.length,
            itemBuilder: (context, index) {
              final item = _lineItems[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item.description,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${item.quantity} x ${NumberFormat.currency(symbol: '£').format(item.unitPrice)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          NumberFormat.currency(symbol: '£').format(item.total),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _showEditLineItemSheet(context, index, item),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () => _removeLineItem(index),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        Center(
          child: PillButton(
            onTap: () => _showAddLineItemSheet(context),
            icon: Icons.add,
            text: 'Add Item',
          ),
        ),
      ],
    );
  }

  void _showAddLineItemSheet(BuildContext context) async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return const _AddItemBottomSheet();
      },
    );

    if (result != null) {
      if (result is LineItem) {
        _addLineItem(result);
      } else if (result is List<LineItem>) {
        for (final item in result) {
          _addLineItem(item);
        }
      }
    }
  }

  void _showEditLineItemSheet(
      BuildContext context, int index, LineItem item) async {
    final result = await showModalBottomSheet<LineItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return _AddItemBottomSheet(existingItem: item);
      },
    );
    if (result != null) {
      _editLineItem(index, result);
    }
  }

  Widget _buildReviewStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: 560,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showPreviewInReview = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: !_showPreviewInReview
                                ? colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Edit',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !_showPreviewInReview
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          fontWeight: !_showPreviewInReview
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showPreviewInReview = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _showPreviewInReview
                                ? colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Preview',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _showPreviewInReview
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          fontWeight: _showPreviewInReview
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _showPreviewInReview
                ? _buildPreviewContent()
                : _buildEditReviewContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent() {
    final company = ref.watch(companyProvider);
    final companyProfile = company != null
        ? CompanyProfile(
            name: company.name,
            address: company.address,
            phone: company.phone,
            email: company.email,
            website: company.website,
            logoUrl: company.logoUrl,
            bankAccounts: company.bankAccounts,
            defaultTaxRate: company.defaultTaxRate,
          )
        : null;
    final quotation = _buildQuotationFromState(companyProfile);
    return DocumentPreview(
      document: quotation,
      company: companyProfile,
      isDraft: true,
    );
  }

  Quotation _buildQuotationFromState(CompanyProfile? company) {
    return Quotation(
      id: 'preview',
      companyId: 'preview',
      createdBy: 'preview',
      quotationNumber: 'PREVIEW-Q-001',
      customerName: _customerNameController.text,
      customerEmail: _customerEmailController.text,
      customerPhone: _customerPhoneController.text.isEmpty
          ? null
          : _customerPhoneController.text,
      customerAddress: _customerAddressController.text.isEmpty
          ? null
          : _customerAddressController.text,
      date: _date,
      expiryDate: _expiryDate,
      items: _lineItems,
      subtotal: _subtotal,
      taxRate: double.tryParse(_taxRateController.text),
      taxAmount: _taxAmount,
      total: _total,
      status: 'Draft',
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      company: company,
    );
  }

  Widget _buildEditReviewContent() {
    final currencyFormat = NumberFormat.currency(symbol: '£');
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Summary
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_customerNameController.text, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  _customerEmailController.text,
                  style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Items Summary
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Items',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                ..._lineItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity}x ${item.description}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          currencyFormat.format(item.total),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }),
                Divider(
                  height: 24,
                  thickness: 1,
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(currencyFormat.format(_subtotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                if (_taxRate > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tax (${_taxRate.toStringAsFixed(1)}%)', style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(currencyFormat.format(_taxAmount), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text(
                      currencyFormat.format(_total),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tax Rate & Notes
          GlassCard(
            child: Column(
              children: [
                TextFormField(
                  controller: _taxRateController,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Tax Rate (%)',
                    labelStyle: TextStyle(fontSize: 13),
                    prefixIcon: Icon(Icons.percent),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    setState(() {
                      _taxRate = double.tryParse(value) ?? 0;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    labelStyle: TextStyle(fontSize: 13),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ItemAddMode { manual, ai }

class _AddItemBottomSheet extends ConsumerStatefulWidget {
  final LineItem? existingItem;

  const _AddItemBottomSheet({this.existingItem});

  @override
  ConsumerState<_AddItemBottomSheet> createState() =>
      _AddItemBottomSheetState();
}

class _AddItemBottomSheetState extends ConsumerState<_AddItemBottomSheet> {
  _ItemAddMode _mode = _ItemAddMode.manual;

  // Manual entry controllers
  late final TextEditingController _descriptionController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;

  // AI prompt controller
  final _aiPromptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = widget.existingItem;
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _quantityController = TextEditingController(
      text: existing != null ? existing.quantity.toString() : '1',
    );
    _priceController = TextEditingController(
      text: existing != null ? existing.unitPrice.toString() : '',
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _aiPromptController.dispose();
    super.dispose();
  }

  void _addManualItem() {
    final description = _descriptionController.text.trim();
    final quantity = double.tryParse(_quantityController.text) ?? 1;
    final price = double.tryParse(_priceController.text) ?? 0;

    if (description.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid description and price'),
        ),
      );
      return;
    }

    final item = LineItem(
      id: widget.existingItem?.id ?? const Uuid().v4(),
      description: description,
      quantity: quantity,
      unitPrice: price,
      total: quantity * price,
    );

    Navigator.pop(context, item);
  }

  Future<void> _generateAIItems() async {
    final companyId = ref.read(companyIdProvider);
    if (companyId == null) return;

    await ref.read(aiGenerationStateProvider.notifier).generateItems(
          prompt: _aiPromptController.text.trim(),
          companyId: companyId,
        );
  }

  void _addGeneratedItems(List<LineItem> items) {
    Navigator.pop(context, items);
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);
    final aiState = ref.watch(aiGenerationStateProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return GlassCard(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Row(
            children: [
              Text(
                widget.existingItem != null ? 'Edit Item' : 'Add Items',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Mode Toggle
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    icon: Icons.edit_outlined,
                    label: 'Manual',
                    isSelected: _mode == _ItemAddMode.manual,
                    onTap: () => setState(() => _mode = _ItemAddMode.manual),
                  ),
                ),
                Expanded(
                  child: _ModeButton(
                    icon: isPremium ? Icons.auto_fix_high : Icons.lock_outline,
                    label: 'AI Generate',
                    isSelected: _mode == _ItemAddMode.ai,
                    isPremium: isPremium,
                    onTap: () {
                      if (!isPremium) {
                        _showPremiumUpgradeDialog(context);
                        return;
                      }
                      setState(() => _mode = _ItemAddMode.ai);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_mode == _ItemAddMode.manual)
            _buildManualEntryForm()
          else
            _buildAIGenerationForm(aiState, colorScheme),

          const SizedBox(height: 16),
        ],
      ),
    ),
    );
  }

  Widget _buildManualEntryForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _descriptionController,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            labelText: 'Description *',
            labelStyle: TextStyle(fontSize: 13),
            prefixIcon: Icon(Icons.description_outlined),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _quantityController,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Qty *',
                  labelStyle: TextStyle(fontSize: 13),
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _priceController,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Unit Price *',
                  labelStyle: TextStyle(fontSize: 13),
                  prefixIcon: Icon(Icons.currency_pound),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        PillButton(
          onTap: _addManualItem,
          text: widget.existingItem != null ? 'Save Changes' : 'Add Item',
        ),
      ],
    );
  }

  Widget _buildAIGenerationForm(
    AIGenerationState aiState,
    ColorScheme colorScheme,
  ) {
    if (aiState.generatedItems != null && aiState.generatedItems!.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Generated Items (${aiState.generatedItems!.length})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextButton.icon(
                onPressed: () {
                  ref.read(aiGenerationStateProvider.notifier).clear();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Start Over'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: aiState.generatedItems!.length,
              itemBuilder: (context, index) {
                final item = aiState.generatedItems![index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        item.description,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${item.quantity} x £${item.unitPrice.toStringAsFixed(2)}',
                      ),
                      trailing: Text(
                        '£${item.total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () {
                    ref.read(aiGenerationStateProvider.notifier).clear();
                  },
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: PillButton(
                  onTap: () => _addGeneratedItems(aiState.generatedItems!),
                  icon: Icons.add,
                  text: 'Add ${aiState.generatedItems!.length} Items',
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _aiPromptController,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Describe the job...',
            labelStyle: const TextStyle(fontSize: 13),
            hintText:
                'E.g., Install 5 split-system air conditioners in a 2-story office building. Include labor, copper piping, and electrical work.',
            prefixIcon: const Icon(Icons.auto_fix_high),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          enabled: !aiState.isLoading,
        ),
        if (aiState.error != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    aiState.error!,
                    style: TextStyle(color: colorScheme.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        PillButton(
          isLoading: aiState.isLoading,
          onTap: _aiPromptController.text.trim().isEmpty ? null : _generateAIItems,
          icon: Icons.auto_fix_high,
          text: aiState.isLoading ? 'Generating...' : 'Generate Items',
        ),
      ],
    );
  }

  void _showPremiumUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.auto_fix_high, color: Colors.amber, size: 48),
        title: const Text('Unlock AI Superpowers'),
        content: const Text(
          'Generate detailed quotes in seconds with AI. Save time and win more work with professional, accurate estimates.\n\nUpgrade to Premium to access this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/settings');
            },
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isPremium;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isPremium = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.7) : null,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: colorScheme.primary.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? colorScheme.primary
                  : !isPremium
                      ? Colors.grey
                      : colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? colorScheme.primary
                    : !isPremium
                        ? Colors.grey
                        : colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
