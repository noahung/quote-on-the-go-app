import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../components/curved_header.dart';
import '../../components/pill_button.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  final Invoice? existingInvoice;
  final Customer? prefilledCustomer;

  const CreateInvoiceScreen({
    super.key,
    this.existingInvoice,
    this.prefilledCustomer,
  });

  @override
  ConsumerState<CreateInvoiceScreen> createState() =>
      _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
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
  String _dueDate = DateFormat(
    'yyyy-MM-dd',
  ).format(DateTime.now().add(const Duration(days: 14)));

  bool get _isEditing => widget.existingInvoice != null;

  @override
  void initState() {
    super.initState();
    final inv = widget.existingInvoice;
    if (inv != null) {
      _customerNameController.text = inv.customerName;
      _customerEmailController.text = inv.customerEmail;
      _customerPhoneController.text = inv.customerPhone ?? '';
      _customerAddressController.text = inv.customerAddress ?? '';
      _lineItems.addAll(inv.items);
      _notesController.text = inv.notes ?? '';
      _taxRate = inv.taxRate ?? 0.0;
      _taxRateController.text = _taxRate.toStringAsFixed(1);
      _date = inv.date;
      _dueDate = inv.dueDate;
    } else if (widget.prefilledCustomer != null) {
      final c = widget.prefilledCustomer!;
      // Don't set _selectedCustomer — it may not be in the dropdown list
      // and would cause a value mismatch assertion. Just prefill the text fields.
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

  Future<void> _saveInvoice() async {
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
      final repository = ref.read(invoiceRepositoryProvider);

      if (_isEditing) {
        await repository.updateInvoice(widget.existingInvoice!.id, {
          'customerName': _customerNameController.text.trim(),
          'customerEmail': _customerEmailController.text.trim(),
          'customerPhone': _customerPhoneController.text.trim().isEmpty
              ? null
              : _customerPhoneController.text.trim(),
          'customerAddress': _customerAddressController.text.trim().isEmpty
              ? null
              : _customerAddressController.text.trim(),
          'date': _date,
          'dueDate': _dueDate,
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
            const SnackBar(content: Text('Invoice updated successfully')),
          );
          context.pop();
        }
      } else {
        final invoice = Invoice(
          id: '',
          companyId: companyId,
          createdBy: userProfile.uid,
          invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch}',
          customerName: _customerNameController.text.trim(),
          customerEmail: _customerEmailController.text.trim(),
          customerPhone: _customerPhoneController.text.trim().isEmpty
              ? null
              : _customerPhoneController.text.trim(),
          customerAddress: _customerAddressController.text.trim().isEmpty
              ? null
              : _customerAddressController.text.trim(),
          date: _date,
          dueDate: _dueDate,
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
        final newId = await repository.createInvoice(invoice);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice created successfully')),
          );
          context.go('/invoices/$newId');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save invoice: $e')));
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
    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            CurvedHeader(
              title: _isEditing ? 'Edit Invoice' : 'New Invoice',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCustomerCard(),
                    const SizedBox(height: 20),
                    _buildSettingsCard(),
                    const SizedBox(height: 20),
                    _buildLineItemsCard(),
                    const SizedBox(height: 20),
                    _buildNotesAndTaxCard(),
                    const SizedBox(height: 20),
                    _buildSummarySection(),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomStickyAction(),
      ),
    );
  }

  Widget _buildCustomerCard() {
    final customers = ref.watch(customersProvider);

    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECT CLIENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          if (customers.isNotEmpty) ...[
            DropdownButtonFormField<Customer?>(
              initialValue: _selectedCustomer,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_search, color: Color(0xFFF4781F)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFF4781F), width: 1.5),
                ),
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
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(icon, color: Colors.grey, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateField(
            label: 'Issue Date',
            value: DateFormat('MMMM d, yyyy').format(DateTime.parse(_date)),
            icon: Icons.calendar_today,
            onTap: () => _pickDate(context, true),
          ),
          const SizedBox(height: 12),
          _buildDateField(
            label: 'Due Date',
            value: DateFormat('MMMM d, yyyy').format(DateTime.parse(_dueDate)),
            icon: Icons.calendar_month,
            onTap: () => _pickDate(context, false),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'INVOICE REF NUMBER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isEditing
                    ? widget.existingInvoice!.invoiceNumber
                    : 'Auto-generated',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, bool isInvoiceDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isInvoiceDate ? DateTime.parse(_date) : DateTime.parse(_dueDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isInvoiceDate) {
          _date = DateFormat('yyyy-MM-dd').format(picked);
        } else {
          _dueDate = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }

  Widget _buildLineItemsCard() {
    final currencyFormat = NumberFormat.currency(symbol: '£');

    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Line Items',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_lineItems.isNotEmpty)
                Text(
                  '${_lineItems.length} ${_lineItems.length == 1 ? 'item' : 'items'}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_lineItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'No items added yet',
                      style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lineItems.length,
              itemBuilder: (context, index) {
                final item = _lineItems[index];
                return InkWell(
                  onTap: () => _showEditLineItemSheet(context, index, item),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.description,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Qty: ${item.quantity}  •  Rate: ${currencyFormat.format(item.unitPrice)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () => _removeLineItem(index),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  currencyFormat.format(item.total),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              side: const BorderSide(color: Color(0xFFF4781F), width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              foregroundColor: const Color(0xFFF4781F),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text(
              'Add Line Item',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            onPressed: () => _showAddLineItemSheet(context),
          ),
        ],
      ),
    );
  }

  void _showEditLineItemSheet(
      BuildContext context, int index, LineItem item) async {
    final result = await showModalBottomSheet<LineItem>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _AddItemBottomSheet(existingItem: item);
      },
    );
    if (result != null) {
      _editLineItem(index, result);
    }
  }

  void _showAddLineItemSheet(BuildContext context) async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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

  Widget _buildNotesAndTaxCard() {
    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextFormField(
            controller: _taxRateController,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Tax Rate (%)',
              prefixIcon: Icon(Icons.percent),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              setState(() {
                _taxRate = double.tryParse(value) ?? 0;
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Notes',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final currencyFormat = NumberFormat.currency(symbol: '£');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal',
                style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              Text(
                currencyFormat.format(_subtotal),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tax (${_taxRate.toStringAsFixed(1)}%)',
                style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              Text(
                currencyFormat.format(_taxAmount),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              Text(
                currencyFormat.format(_total),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF4781F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStickyAction() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFF4781F)))
            : FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF4781F),
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                label: Text(
                  _isEditing ? 'Save Changes' : 'Generate & Send Invoice',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                onPressed: () {
                  if (_customerNameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Customer Name is required')),
                    );
                    return;
                  }
                  if (_customerEmailController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Customer Email is required')),
                    );
                    return;
                  }
                  _saveInvoice();
                },
              ),
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
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                      icon:
                          isPremium ? Icons.auto_fix_high : Icons.lock_outline,
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

            // Content based on mode
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
    // Show generated items if available
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

    // Show generation form
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
          onTap:
              _aiPromptController.text.trim().isEmpty ? null : _generateAIItems,
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
          color: isSelected ? colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(10),
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
                      : null,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? colorScheme.primary
                    : !isPremium
                        ? Colors.grey
                        : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
