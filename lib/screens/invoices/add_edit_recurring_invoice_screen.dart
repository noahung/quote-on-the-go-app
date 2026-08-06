import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../components/pill_button.dart';
import '../../utils/feedback_controller.dart';
import '../../models/feedback_type.dart';


class AddEditRecurringInvoiceScreen extends ConsumerStatefulWidget {
  final RecurringInvoice? existingRecurringInvoice;
  final String? recurringInvoiceId;

  const AddEditRecurringInvoiceScreen({
    super.key,
    this.existingRecurringInvoice,
    this.recurringInvoiceId,
  });

  @override
  ConsumerState<AddEditRecurringInvoiceScreen> createState() =>
      _AddEditRecurringInvoiceScreenState();
}

class _AddEditRecurringInvoiceScreenState
    extends ConsumerState<AddEditRecurringInvoiceScreen> {
  bool _isLoading = false;

  // Step 1: Customer
  Customer? _selectedCustomer;
  final _customerNameController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();

  // Step 2: Recurring Settings
  String _frequency = 'monthly'; // 'weekly' | 'monthly' | 'quarterly' | 'yearly'
  String _startDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String? _endDate;
  String _nextRunDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool _isActive = true;

  // Step 3: Line Items
  final List<LineItem> _lineItems = [];

  // Step 4: Summary / Rates
  final _notesController = TextEditingController();
  final _taxRateController = TextEditingController(text: '0.0');
  double _taxRate = 0.0;

  final _discountController = TextEditingController(text: '0.0');
  double _discount = 0.0;
  String _discountType = 'percentage'; // 'percentage' | 'fixed'

  bool get _isEditing => widget.existingRecurringInvoice != null || widget.recurringInvoiceId != null;

  String _normalizeDate(String dateStr) {
    if (dateStr.isEmpty) return DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      final parsed = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  void initState() {
    super.initState();
    // Prefill data if editing
    final rec = widget.existingRecurringInvoice;
    if (rec != null) {
      _prefillForm(rec);
    } else if (widget.recurringInvoiceId != null) {
      // Fetch via firestore if ID is provided but object is null (though normally extra is passed)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final doc = await ref.read(firestoreProvider)
            .collection('recurringInvoices')
            .doc(widget.recurringInvoiceId)
            .get();
        if (doc.exists && mounted) {
          final fetched = RecurringInvoice.fromFirestore(doc);
          _prefillForm(fetched);
        }
      });
    }
  }

  void _prefillForm(RecurringInvoice rec) {
    setState(() {
      _customerNameController.text = rec.customerName;
      _customerEmailController.text = rec.customerEmail;
      _customerPhoneController.text = rec.customerPhone ?? '';
      _customerAddressController.text = rec.customerAddress ?? '';
      _frequency = rec.frequency;
      _startDate = _normalizeDate(rec.startDate);
      _endDate = rec.endDate != null ? _normalizeDate(rec.endDate!) : null;
      _nextRunDate = _normalizeDate(rec.nextRunDate);
      _isActive = rec.isActive;
      _lineItems.addAll(rec.items);
      _notesController.text = rec.notes ?? '';
      _taxRate = rec.taxRate ?? 0.0;
      _taxRateController.text = _taxRate.toStringAsFixed(1);
      _discount = rec.discount ?? 0.0;
      _discountController.text = _discount.toStringAsFixed(1);
      _discountType = rec.discountType ?? 'percentage';
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerEmailController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _notesController.dispose();
    _taxRateController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _lineItems.fold(0.0, (acc, item) => acc + item.total);
  }


  double get _discountAmount {
    if (_discount <= 0.0) return 0.0;
    if (_discountType == 'percentage') {
      return _subtotal * (_discount / 100);
    } else {
      return _discount;
    }
  }

  double get _taxAmount {
    final discountedSubtotal = _subtotal - _discountAmount;
    return discountedSubtotal * (_taxRate / 100);
  }

  double get _total {
    final t = _subtotal - _discountAmount + _taxAmount;
    return t < 0 ? 0.0 : t;
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

  Future<void> _pickDate(BuildContext context, String fieldType) async {
    DateTime initial = DateTime.now();
    if (fieldType == 'start') {
      initial = DateTime.tryParse(_startDate) ?? DateTime.now();
    } else if (fieldType == 'end') {
      initial = _endDate != null ? DateTime.tryParse(_endDate!) ?? DateTime.now() : DateTime.now().add(const Duration(days: 365));
    } else if (fieldType == 'next') {
      initial = DateTime.tryParse(_nextRunDate) ?? DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        final formatted = DateFormat('yyyy-MM-dd').format(picked);
        if (fieldType == 'start') {
          _startDate = formatted;
          // By default, next run date can align with start date unless edited
          _nextRunDate = formatted;
        } else if (fieldType == 'end') {
          _endDate = formatted;
        } else if (fieldType == 'next') {
          _nextRunDate = formatted;
        }
      });
    }
  }

  bool _validateFields() {
    if (_customerNameController.text.trim().isEmpty) {
      ref.read(feedbackControllerProvider).warning(context, 'Recipient Name is required');
      return false;
    }
    if (_customerEmailController.text.trim().isEmpty) {
      ref.read(feedbackControllerProvider).warning(context, 'Recipient Email is required');
      return false;
    }
    if (_lineItems.isEmpty) {
      ref.read(feedbackControllerProvider).warning(context, 'Please add at least one line item');
      return false;
    }
    return true;
  }

  Future<void> _saveSetup() async {
    final companyId = ref.read(companyIdProvider);
    final userProfile = ref.read(userProfileProvider);

    if (companyId == null || userProfile == null) {
      ref.read(feedbackControllerProvider).error(context, 'Authentication error. Please login again.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(recurringInvoiceRepositoryProvider);

      if (_isEditing) {
        final id = widget.recurringInvoiceId ?? widget.existingRecurringInvoice!.id;
        await repository.updateRecurringInvoice(id, {
          'customerId': _selectedCustomer?.id ?? widget.existingRecurringInvoice?.customerId ?? '',
          'customerName': _customerNameController.text.trim(),
          'customerEmail': _customerEmailController.text.trim(),
          'customerPhone': _customerPhoneController.text.trim().isEmpty ? null : _customerPhoneController.text.trim(),
          'customerAddress': _customerAddressController.text.trim().isEmpty ? null : _customerAddressController.text.trim(),
          'frequency': _frequency,
          'startDate': _startDate,
          'endDate': _endDate,
          'nextRunDate': _nextRunDate,
          'isActive': _isActive,
          'items': _lineItems.map((i) => i.toJson()).toList(),
          'subtotal': _subtotal,
          'taxRate': _taxRate,
          'taxAmount': _taxAmount,
          'discount': _discount,
          'discountType': _discountType,
          'discountAmount': _discountAmount,
          'total': _total,
          'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ref.read(feedbackControllerProvider).success(context, 'Recurring setup updated');
          context.pop();
        }
      } else {
        final setup = RecurringInvoice(
          id: '',
          companyId: companyId,
          customerId: _selectedCustomer?.id ?? '',
          customerName: _customerNameController.text.trim(),
          customerEmail: _customerEmailController.text.trim(),
          customerPhone: _customerPhoneController.text.trim().isEmpty ? null : _customerPhoneController.text.trim(),
          customerAddress: _customerAddressController.text.trim().isEmpty ? null : _customerAddressController.text.trim(),
          frequency: _frequency,
          startDate: _startDate,
          endDate: _endDate,
          nextRunDate: _nextRunDate,
          isActive: true,
          items: _lineItems,
          subtotal: _subtotal,
          taxRate: _taxRate,
          taxAmount: _taxAmount,
          discount: _discount,
          discountType: _discountType,
          discountAmount: _discountAmount,
          total: _total,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          generatedInvoiceIds: [],
        );
        await repository.createRecurringInvoice(setup);

        if (mounted) {
          await ref.read(feedbackControllerProvider).showCelebration(
            context: context,
            type: CelebrationType.checkmark,
            title: 'Setup Created',
            subtitle: 'Your recurring invoice setup has been saved successfully',
            onDone: () => context.pop(),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Failed to save: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            _buildAppBar(context, isDark),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderRow(context),
                    const SizedBox(height: 16),
                    _buildCustomerCard(),
                    const SizedBox(height: 16),
                    _buildScheduleCard(),
                    const SizedBox(height: 16),
                    _buildLineItemsCard(),
                    const SizedBox(height: 16),
                    _buildSummarySection(),
                    const SizedBox(height: 16),
                    _buildNotesCard(),
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

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(LucideIcons.chevronLeft, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Text(
              _isEditing ? 'Edit Recurring Setup' : 'Create Recurring Setup',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Row(
      children: [
        Text(
          'Recurring Invoice  ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          _isEditing ? 'Active Setup' : 'New Setup',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF4781F),
          ),
        ),
        if (_isEditing) ...[
          const Spacer(),
          Row(
            children: [
              const Text('Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Switch(
                value: _isActive,
                activeThumbColor: const Color(0xFFF4781F),
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ],
          ),
        ],
      ],
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
          _buildSectionLabel('RECIPIENT'),
          const SizedBox(height: 12),
          if (customers.isNotEmpty) ...[
            DropdownButtonFormField<Customer?>(
              initialValue: _selectedCustomer,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              borderRadius: BorderRadius.circular(20),
              dropdownColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E2C)
                  : const Color(0xFFF0F4F9),
              decoration: const InputDecoration(
                prefixIcon: Icon(LucideIcons.userSearch, color: Color(0xFFF4781F)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            decoration: _fieldDeco('Customer Name', 'e.g. Acme Corp'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerEmailController,
            style: const TextStyle(fontSize: 14),
            keyboardType: TextInputType.emailAddress,
            decoration: _fieldDeco('Customer Email', 'name@domain.com'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerPhoneController,
            style: const TextStyle(fontSize: 14),
            keyboardType: TextInputType.phone,
            decoration: _fieldDeco('Customer Phone (Optional)', 'e.g. +44 7123 456789'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerAddressController,
            style: const TextStyle(fontSize: 14),
            maxLines: 3,
            textCapitalization: TextCapitalization.words,
            decoration: _fieldDeco('Billing Address (Optional)', 'e.g. 123 High Street, London'),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('SCHEDULE & FREQUENCY'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _frequency,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            borderRadius: BorderRadius.circular(20),
            dropdownColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E2C)
                : const Color(0xFFF0F4F9),
            decoration: const InputDecoration(
              labelText: 'Frequency',
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
              DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _frequency = val);
              }
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildDateChip(
                label: 'Start Date',
                value: DateFormat('MMM d, yyyy').format(DateTime.parse(_startDate)),
                onTap: () => _pickDate(context, 'start'),
              ),
              const SizedBox(width: 12),
              _buildDateChip(
                label: 'End Date (Optional)',
                value: _endDate != null
                    ? DateFormat('MMM d, yyyy').format(DateTime.parse(_endDate!))
                    : 'No End Date',
                onTap: () => _pickDate(context, 'end'),
                onClear: _endDate != null
                    ? () => setState(() => _endDate = null)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDateChipSingle(
            label: 'Next Scheduled Run',
            value: DateFormat('MMM d, yyyy').format(DateTime.parse(_nextRunDate)),
            onTap: () => _pickDate(context, 'next'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip({
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: Colors.grey,
                    ),
                  ),
                  if (onClear != null)
                    GestureDetector(
                      onTap: onClear,
                      child: const Icon(LucideIcons.x, size: 12, color: Colors.grey),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(LucideIcons.calendar, size: 14, color: Color(0xFFF4781F)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateChipSingle({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(LucideIcons.calendarClock, size: 15, color: Color(0xFFF4781F)),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItemsCard() {
    final currencyFormat = NumberFormat.currency(symbol: '£');
    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('INVOICE ITEMS'),
          const SizedBox(height: 14),
          if (_lineItems.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: const [
                  Expanded(
                    flex: 5,
                    child: Text('Item', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5)),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text('Price', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5), textAlign: TextAlign.right),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text('Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5), textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text('Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5), textAlign: TextAlign.right),
                  ),
                  SizedBox(width: 28),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
            const SizedBox(height: 4),
            ...List.generate(_lineItems.length, (index) {
              final item = _lineItems[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        item.description,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        currencyFormat.format(item.unitPrice),
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString(),
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        currencyFormat.format(item.total),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: PopupMenuButton<String>(
                        icon: const Icon(LucideIcons.ellipsisVertical, size: 18, color: Colors.grey),
                        padding: EdgeInsets.zero,
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                        onSelected: (val) {
                          if (val == 'edit') _showEditLineItemSheet(context, index, item);
                          if (val == 'delete') _removeLineItem(index);
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
            const SizedBox(height: 8),
          ],
          if (_lineItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  children: [
                    Icon(LucideIcons.receipt, size: 44, color: Colors.grey.withValues(alpha: 0.4)),
                    const SizedBox(height: 10),
                    const Text('No items added yet', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: const Color(0xFFF4781F).withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              foregroundColor: const Color(0xFFF4781F),
            ),
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('Add Line Item', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            onPressed: () => _showAddItemSheet(context),
          ),
        ],
      ),
    );
  }

  void _showAddItemSheet(BuildContext context) {
    showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddItemBottomSheet(),
    ).then((result) {
      if (result != null) {
        if (result is LineItem) {
          _addLineItem(result);
        } else if (result is List<LineItem>) {
          for (final item in result) {
            _addLineItem(item);
          }
        }
      }
    });
  }

  void _showEditLineItemSheet(BuildContext context, int index, LineItem item) {
    showModalBottomSheet<LineItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddItemBottomSheet(existingItem: item),
    ).then((result) {
      if (result != null) {
        _editLineItem(index, result);
      }
    });
  }

  Widget _buildSummarySection() {
    final currencyFormat = NumberFormat.currency(symbol: '£');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
              Text(currencyFormat.format(_subtotal), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          
          // Discount fields
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Discount', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    height: 32,
                    child: TextFormField(
                      controller: _discountController,
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        suffixText: _discountType == 'percentage' ? '%' : '£',
                        suffixStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFF4781F)),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        setState(() {
                          _discount = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _discountType = _discountType == 'percentage' ? 'fixed' : 'percentage';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _discountType == 'percentage' ? LucideIcons.percent : Icons.currency_pound,
                        size: 14,
                        color: Colors.grey,
                      ),

                    ),
                  ),
                ],
              ),
              Text('-${currencyFormat.format(_discountAmount)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 8),

          // Tax fields
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Tax', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    height: 32,
                    child: TextFormField(
                      controller: _taxRateController,
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        suffixText: '%',
                        suffixStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFF4781F)),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        setState(() {
                          _taxRate = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ),
                ],
              ),
              Text(currencyFormat.format(_taxAmount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey)),
              Text(
                currencyFormat.format(_total),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFFF4781F)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('NOTES / PAYMENT TERMS'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            style: const TextStyle(fontSize: 14),
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: _fieldDeco('Notes to display on generated invoice', 'Payment is due within 30 days of generation...'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStickyAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.97),
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: SafeArea(
        top: false,
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: Color(0xFFF4781F))),
              )
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF4781F),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  icon: Icon(_isEditing ? LucideIcons.save : LucideIcons.calendarCheck, color: Colors.white, size: 18),
                  label: Text(
                    _isEditing ? 'Save Setup Changes' : 'Create Recurring Setup',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  onPressed: () {
                    if (_validateFields()) _saveSetup();
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: Colors.grey,
      ),
    );
  }

  InputDecoration _fieldDeco(String label, String hint, {String? prefixText, String? suffixText}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey.withValues(alpha: 0.8),
        letterSpacing: 0.3,
      ),
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13,
        color: Colors.grey.withValues(alpha: 0.45),
      ),
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      suffixText: suffixText,
      suffixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
        borderSide: const BorderSide(color: Color(0xFFF4781F), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
  late final TextEditingController _discountController;
  String _discountType = 'percentage';

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
    _discountController = TextEditingController(
      text: existing?.discount != null ? existing!.discount.toString() : '',
    );
    _discountType = existing?.discountType ?? 'percentage';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _aiPromptController.dispose();
    super.dispose();
  }

  void _addManualItem() {
    final description = _descriptionController.text.trim();
    final quantity = double.tryParse(_quantityController.text) ?? 1;
    final price = double.tryParse(_priceController.text) ?? 0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;

    if (description.isEmpty || price <= 0) {
      ref.read(feedbackControllerProvider).warning(context, 'Please enter a valid description and price');
      return;
    }

    double discountAmount = 0.0;
    if (discount > 0) {
      if (_discountType == 'percentage') {
        discountAmount = (quantity * price) * (discount / 100);
      } else {
        discountAmount = discount;
      }
    }

    final total = (quantity * price) - discountAmount;

    final item = LineItem(
      id: widget.existingItem?.id ?? const Uuid().v4(),
      description: description,
      quantity: quantity,
      unitPrice: price,
      discount: discount > 0 ? discount : null,
      discountType: discount > 0 ? _discountType : null,
      discountAmount: discount > 0 ? discountAmount : null,
      total: total,
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

    final isDarkSheet = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDarkSheet ? const Color(0xFF1C1C1E) : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 12,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
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

              // Title row
              Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    widget.existingItem != null ? 'Edit Item' : 'Add Items',
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
                          color: Colors.grey.withValues(alpha: isDarkSheet ? 0.25 : 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.x,
                          size: 16,
                          color: isDarkSheet ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Pill-shaped mode toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: isDarkSheet ? 0.4 : 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        icon: LucideIcons.pencil,
                        label: 'Manual',
                        isSelected: _mode == _ItemAddMode.manual,
                        onTap: () => setState(() => _mode = _ItemAddMode.manual),
                      ),
                    ),
                    Expanded(
                      child: _ModeButton(
                        icon: isPremium ? LucideIcons.zap : LucideIcons.lock,
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
              const SizedBox(height: 24),

              if (_mode == _ItemAddMode.manual)
                _buildManualEntryForm()
              else
                _buildAIGenerationForm(aiState, colorScheme),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(String label, String hint, {String? prefixText, String? suffixText}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey.withValues(alpha: 0.8),
        letterSpacing: 0.3,
      ),
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 14,
        color: Colors.grey.withValues(alpha: 0.45),
      ),
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      suffixText: suffixText,
      suffixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
        borderSide: const BorderSide(color: Color(0xFFF4781F), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );
  }

  Widget _buildManualEntryForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _descriptionController,
          style: const TextStyle(fontSize: 14),
          decoration: _fieldDeco('Description', 'e.g. Logo Design'),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _quantityController,
                style: const TextStyle(fontSize: 14),
                decoration: _fieldDeco('Quantity', '1'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _priceController,
                style: const TextStyle(fontSize: 14),
                decoration: _fieldDeco('Unit Price', '0.00', prefixText: '£ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _discountController,
                style: const TextStyle(fontSize: 14),
                decoration: _fieldDeco(
                  'Item Discount',
                  '0.00',
                  suffixText: _discountType == 'percentage' ? '%' : '£',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.07)
                    : const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _DiscountTypeButton(
                    label: '%',
                    isSelected: _discountType == 'percentage',
                    onTap: () => setState(() => _discountType = 'percentage'),
                  ),
                  _DiscountTypeButton(
                    label: '£',
                    isSelected: _discountType == 'fixed',
                    onTap: () => setState(() => _discountType = 'fixed'),
                  ),
                ],
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

  Widget _buildAIGenerationForm(dynamic aiState, ColorScheme colorScheme) {
    if (aiState.generatedItems != null && aiState.generatedItems!.isNotEmpty) {
      final items = aiState.generatedItems as List<LineItem>;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI generated ${items.length} items successfully!',
                    style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            if (item.itemDetails != null && item.itemDetails!.isNotEmpty)
                              Text(item.itemDetails!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '£${item.unitPrice.toStringAsFixed(0)} x ${item.quantity.toInt()}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(aiGenerationStateProvider.notifier).clear();
                  },
                  child: const Text('Try Again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF4781F)),
                  onPressed: () => _addGeneratedItems(items),
                  child: const Text('Add All Items'),
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
          icon: LucideIcons.sparkles,
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

class _DiscountTypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DiscountTypeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF4781F) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = !isPremium
        ? Colors.grey.withValues(alpha: 0.5)
        : isDark
            ? Colors.white.withValues(alpha: 0.6)
            : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF4781F) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFFF4781F).withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : unselectedColor,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : unselectedColor,
              ),
            ),
            if (!isPremium) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : Colors.amber,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
