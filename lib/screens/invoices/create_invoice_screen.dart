import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  final Invoice? existingInvoice;

  const CreateInvoiceScreen({super.key, this.existingInvoice});

  @override
  ConsumerState<CreateInvoiceScreen> createState() =>
      _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  int _currentStep = 0;
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
  String _dueDate = DateFormat('yyyy-MM-dd')
      .format(DateTime.now().add(const Duration(days: 14)));

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
        await repository.createInvoice(invoice);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice created successfully')),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save invoice: $e')),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Invoice' : 'New Invoice',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
            _saveInvoice();
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
                  child: FilledButton(
                    onPressed: _isLoading ? null : details.onStepContinue,
                    child: _isLoading && _currentStep == 2
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_currentStep == 2
                            ? (_isEditing ? 'Save Changes' : 'Create Invoice')
                            : 'Next'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
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
    );
  }

  Widget _buildCustomerStep() {
    final customers = ref.watch(customersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (customers.isNotEmpty) ...[
          DropdownButtonFormField<Customer?>(
            value: _selectedCustomer,
            decoration: const InputDecoration(
              labelText: 'Select Existing Customer',
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
          decoration: const InputDecoration(
            labelText: 'Customer Name *',
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _customerEmailController,
          decoration: const InputDecoration(
            labelText: 'Email *',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _customerPhoneController,
          decoration: const InputDecoration(
            labelText: 'Phone',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _customerAddressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                label: 'Invoice Date',
                value: _date,
                onTap: () => _pickDate(context, true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDateField(
                label: 'Due Date',
                value: _dueDate,
                onTap: () => _pickDate(context, false),
              ),
            ),
          ],
        ),
      ],
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
          prefixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(value),
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

  Widget _buildLineItemsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_lineItems.isEmpty)
          const AppEmptyState(
            icon: Icons.shopping_cart_outlined,
            title: 'No Items Added',
            subtitle: 'Add line items to build your invoice',
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _lineItems.length,
            itemBuilder: (context, index) {
              final item = _lineItems[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    item.description,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${item.quantity} x ${NumberFormat.currency(symbol: '\u00A3').format(item.unitPrice)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        NumberFormat.currency(symbol: '\u00A3')
                            .format(item.total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removeLineItem(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 12),
        Center(
          child: FilledButton.icon(
            onPressed: () => _showAddLineItemSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
        ),
      ],
    );
  }

  void _showAddLineItemSheet(BuildContext context) {
    final descriptionController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Line Item',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
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
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Qty *',
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
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Unit Price *',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  final description = descriptionController.text.trim();
                  final quantity =
                      double.tryParse(quantityController.text) ?? 1;
                  final price = double.tryParse(priceController.text) ?? 0;

                  if (description.isEmpty || price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Please enter a valid description and price'),
                      ),
                    );
                    return;
                  }

                  final item = LineItem(
                    id: const Uuid().v4(),
                    description: description,
                    quantity: quantity,
                    unitPrice: price,
                    total: quantity * price,
                  );

                  _addLineItem(item);
                  Navigator.pop(context);
                },
                child: const Text('Add Item'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewStep() {
    final currencyFormat = NumberFormat.currency(symbol: '\u00A3');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Customer Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_customerNameController.text),
                Text(
                  _customerEmailController.text,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Items Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Items',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ..._lineItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity}x ${item.description}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          currencyFormat.format(item.total),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal'),
                    Text(currencyFormat.format(_subtotal)),
                  ],
                ),
                if (_taxRate > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tax (${_taxRate.toStringAsFixed(1)}%)'),
                      Text(currencyFormat.format(_taxAmount)),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      currencyFormat.format(_total),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Tax Rate
        TextFormField(
          controller: _taxRateController,
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
        const SizedBox(height: 12),

        // Notes
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Notes',
            prefixIcon: Icon(Icons.notes),
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}
