import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../components/pill_button.dart';
import '../../utils/feedback_controller.dart';
import '../../utils/navigation_fallbacks.dart';
import '../../models/feedback_type.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  final Invoice? existingInvoice;
  final Customer? prefilledCustomer;
  final String? fromJobId;
  final String? fromQuotationId;

  const CreateInvoiceScreen({
    super.key,
    this.existingInvoice,
    this.prefilledCustomer,
    this.fromJobId,
    this.fromQuotationId,
  });

  @override
  ConsumerState<CreateInvoiceScreen> createState() =>
      _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  bool _isLoading = false;

  // Step 1: Customer
  Customer? _selectedCustomer;
  final _titleController = TextEditingController();
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

  // Normalize date strings to yyyy-MM-dd format (handles ISO 8601)
  String _normalizeDate(String dateStr) {
    if (dateStr.isEmpty) return DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      final parsed = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(parsed);
    } catch (_) {
      return dateStr; // Return as-is if parsing fails
    }
  }

  @override
  void initState() {
    super.initState();
    final inv = widget.existingInvoice;
    if (inv != null) {
      _titleController.text = inv.title ?? '';
      _customerNameController.text = inv.customerName;
      _customerEmailController.text = inv.customerEmail;
      _customerPhoneController.text = inv.customerPhone ?? '';
      _customerAddressController.text = inv.customerAddress ?? '';
      _lineItems.addAll(inv.items);
      _notesController.text = inv.notes ?? '';
      _taxRate = inv.taxRate ?? 0.0;
      _taxRateController.text = _taxRate.toStringAsFixed(1);
      _date = _normalizeDate(inv.date);
      _dueDate = _normalizeDate(inv.dueDate);
    } else if (widget.prefilledCustomer != null) {
      final c = widget.prefilledCustomer!;
      _customerNameController.text = c.name;
      _customerEmailController.text = c.email;
      _customerPhoneController.text = c.phone ?? '';
      _customerAddressController.text = c.address ?? '';
    } else if (widget.fromQuotationId != null || widget.fromJobId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPrefillData();
      });
    }
  }

  Future<void> _loadPrefillData() async {
    final firestore = FirebaseFirestore.instance;

    // Load from Quotation
    if (widget.fromQuotationId != null) {
      try {
        final doc = await firestore.collection('quotations').doc(widget.fromQuotationId).get();
        if (doc.exists && mounted) {
          final quote = Quotation.fromFirestore(doc);
          setState(() {
            _titleController.text = quote.title ?? 'Invoice for ${quote.quotationNumber}';
            _customerNameController.text = quote.customerName;
            _customerEmailController.text = quote.customerEmail;
            _customerPhoneController.text = quote.customerPhone ?? '';
            _customerAddressController.text = quote.customerAddress ?? '';
            _lineItems.addAll(quote.items);
            _taxRate = quote.taxRate ?? 0.0;
            _taxRateController.text = _taxRate.toStringAsFixed(1);
            _notesController.text = 'Converted from Quotation ${quote.quotationNumber}.\n${quote.notes ?? ''}'.trim();
          });
        }
      } catch (e) {
        debugPrint('Error loading quotation: $e');
      }
    }

    // Load from Job
    if (widget.fromJobId != null) {
      try {
        final jobDoc = await firestore.collection('events').doc(widget.fromJobId).get();
        if (jobDoc.exists && mounted) {
          final job = CalendarEvent.fromFirestore(jobDoc);
          setState(() {
            _titleController.text = 'Final Invoice - ${job.title}';
            _customerNameController.text = job.customerName ?? '';
            _customerAddressController.text = job.customerAddress ?? '';
          });

          // Fetch Customer email/phone if customerId exists
          if (job.customerId != null && job.customerId!.isNotEmpty) {
            final custDoc = await firestore.collection('customers').doc(job.customerId).get();
            if (custDoc.exists && mounted) {
              final custData = custDoc.data() as Map<String, dynamic>;
              setState(() {
                _customerEmailController.text = custData['email'] ?? '';
                _customerPhoneController.text = custData['phone'] ?? '';
              });
            }
          }

          // Fetch originating quotation items
          final quoteSnap = await firestore.collection('quotations')
              .where('jobId', isEqualTo: widget.fromJobId)
              .get();
          if (quoteSnap.docs.isNotEmpty && mounted) {
            final q = Quotation.fromFirestore(quoteSnap.docs.first);
            setState(() {
              _lineItems.addAll(q.items);
              if (_notesController.text.isEmpty) {
                _notesController.text = 'Job: ${job.title}\nRef: Quote ${q.quotationNumber}';
              }
            });
          }

          // Fetch tracked job materials
          final matSnap = await firestore.collection('job_materials')
              .where('jobId', isEqualTo: widget.fromJobId)
              .get();
          if (matSnap.docs.isNotEmpty && mounted) {
            for (final doc in matSnap.docs) {
              final m = doc.data();
              final desc = m['description'] as String? ?? 'Material Item';
              final qty = (m['quantity'] as num?)?.toDouble() ?? 1.0;
              final unitCost = (m['unitCost'] as num?)?.toDouble() ?? 0.0;
              setState(() {
                _lineItems.add(LineItem(
                  id: const Uuid().v4(),
                  description: '[Material] $desc',
                  quantity: qty,
                  unitPrice: unitCost,
                  total: qty * unitCost,
                ));
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading job for invoice: $e');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
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
        ref.read(feedbackControllerProvider).error(context, 'User or company not found');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(invoiceRepositoryProvider);

      if (_isEditing) {
        await repository.updateInvoice(widget.existingInvoice!.id, {
          'title': _titleController.text.trim().isEmpty
              ? null
              : _titleController.text.trim(),
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
          ref.read(feedbackControllerProvider).success(context, 'Invoice updated successfully');
          popOrGo(context, '/invoices');
        }
      } else {
        final invoice = Invoice(
          id: '',
          companyId: companyId,
          createdBy: userProfile.uid,
          invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch}',
          title: _titleController.text.trim().isEmpty
              ? null
              : _titleController.text.trim(),
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
          await ref.read(feedbackControllerProvider).showCelebration(
            context: context,
            type: CelebrationType.checkmark,
            title: 'Invoice Created',
            subtitle: 'Your invoice has been saved successfully',
            onDone: () => context.go('/pdf-preview/invoice/$newId'),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Failed to save invoice: $e');
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
                    _buildDocNumberRow(context),
                    const SizedBox(height: 16),
                    _buildTitleCard(),
                    const SizedBox(height: 16),
                    _buildTemplateSelectorCard(),
                    _buildCustomerCard(),
                    const SizedBox(height: 16),
                    _buildDatesCard(context),
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

  Widget _buildTitleCard() {
    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('TITLE / PROJECT REFERENCE'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _titleController,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
              prefixIcon: Icon(LucideIcons.fileText),
              hintText: 'e.g. Kitchen Renovation Phase 2',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
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
              onPressed: () => popOrGo(context, '/invoices'),
            ),
            Text(
              _isEditing ? 'Edit Invoice' : 'Create New Invoice',
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

  Widget _buildDocNumberRow(BuildContext context) {
    final number = _isEditing
        ? widget.existingInvoice!.invoiceNumber
        : 'Auto-generated';
    return Row(
      children: [
        Text(
          'Invoice  ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          '#$number',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF4781F),
          ),
        ),
        const Spacer(),
        if (_isEditing)
          GestureDetector(
            onTap: () {
              // TODO: copy portal link
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.link, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('COPY LINK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.5)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTemplateSelectorCard() {
    final templates = ref.watch(documentTemplatesProvider)
        .where((t) => t.type == 'invoice')
        .toList();

    if (templates.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.fileSpreadsheet, size: 20, color: Color(0xFFF4781F)),
                  const SizedBox(width: 8),
                  Text(
                    'Apply Template',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  hintText: 'Select an invoice template...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                items: templates.map((t) {
                  return DropdownMenuItem<String>(
                    value: t.id,
                    child: Text(t.name),
                  );
                }).toList(),
                onChanged: (templateId) {
                  if (templateId == null) return;
                  final template = templates.firstWhere((t) => t.id == templateId);
                  
                  // Confirm to overwrite items if there are already items
                  if (_lineItems.isNotEmpty) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Overwrite Items?'),
                        content: const Text('Applying this template will replace your current line items, notes, and tax rate. Do you want to proceed?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF4781F)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _applyTemplate(template);
                            },
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    _applyTemplate(template);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyTemplate(DocumentTemplate template) {
    setState(() {
      _lineItems.clear();
      _lineItems.addAll(template.items);
      _notesController.text = template.notes ?? '';
      _taxRate = template.taxRate ?? 0.0;
      _taxRateController.text = _taxRate.toStringAsFixed(1);
    });
    ref.read(feedbackControllerProvider).success(context, 'Template applied: ${template.name}');
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
            decoration: const InputDecoration(
              labelText: 'Customer Name *',
              prefixIcon: Icon(LucideIcons.user),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerEmailController,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Email *',
              prefixIcon: Icon(LucideIcons.mail),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerPhoneController,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(LucideIcons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerAddressController,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(LucideIcons.mapPin),
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(LucideIcons.calendar, size: 14, color: Color(0xFFF4781F)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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

  Widget _buildDatesCard(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('DATES'),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildDateChip(
                label: 'Issued On',
                value: DateFormat('MMM d, yyyy').format(DateTime.parse(_date)),
                onTap: () => _pickDate(context, true),
              ),
              const SizedBox(width: 12),
              _buildDateChip(
                label: 'Due On',
                value: DateFormat('MMM d, yyyy').format(DateTime.parse(_dueDate)),
                onTap: () => _pickDate(context, false),
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
    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('INVOICE ITEMS'),
          const SizedBox(height: 14),
          if (_lineItems.isNotEmpty) ...
            [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 5,
                      child: Text('Item', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5)),
                    ),
                    const SizedBox(
                      width: 52,
                      child: Text('Price', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5), textAlign: TextAlign.right),
                    ),
                    const SizedBox(
                      width: 30,
                      child: Text('Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5), textAlign: TextAlign.center),
                    ),
                    const SizedBox(
                      width: 60,
                      child: Text('Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5), textAlign: TextAlign.right),
                    ),
                    const SizedBox(width: 28),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
              const SizedBox(height: 4),
              ...List.generate(_lineItems.length, (index) {
                final item = _lineItems[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
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
                          NumberFormat.currency(symbol: '£', decimalDigits: 0).format(item.unitPrice),
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
                          NumberFormat.currency(symbol: '£', decimalDigits: 0).format(item.total),
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
                    const Text('No items added yet', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF4781F),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
            icon: const Icon(LucideIcons.plusCircle, size: 18),
            label: const Text('+ Add Item', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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

  Widget _buildNotesCard() {
    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('ADDITIONAL NOTES'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Add any notes for the client...',
              hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.6), fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFF4781F), width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final currencyFormat = NumberFormat.currency(symbol: '£', decimalDigits: 2);

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
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Tax', style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
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
                          _taxRate = double.tryParse(value) ?? 0;
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
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFFF4781F)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _validateFields() {
    if (_customerNameController.text.trim().isEmpty) {
      ref.read(feedbackControllerProvider).warning(context, 'Customer Name is required');
      return false;
    }
    if (_customerEmailController.text.trim().isEmpty) {
      ref.read(feedbackControllerProvider).warning(context, 'Customer Email is required');
      return false;
    }
    return true;
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
            : Row(
                children: [
                  if (!_isEditing) ...
                    [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFF4781F), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          foregroundColor: const Color(0xFFF4781F),
                        ),
                        onPressed: () {
                          if (_validateFields()) _saveInvoice();
                        },
                        child: const Text('Save as Draft', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                      const SizedBox(width: 10),
                    ],
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF4781F),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      icon: Icon(_isEditing ? LucideIcons.save : LucideIcons.send, color: Colors.white, size: 18),
                      label: Text(
                        _isEditing ? 'Save Changes' : 'Send Invoice',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      onPressed: () {
                        if (_validateFields()) _saveInvoice();
                      },
                    ),
                  ),
                ],
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
              flex: 2,
              child: TextFormField(
                controller: _quantityController,
                style: const TextStyle(fontSize: 14),
                decoration: _fieldDeco('Qty', '1'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _priceController,
                style: const TextStyle(fontSize: 14),
                decoration: _fieldDeco('Unit Price', '0.00', prefixText: '£ '),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _discountController,
                style: const TextStyle(fontSize: 14),
                decoration: _fieldDeco(
                  'Discount',
                  '0.00',
                  prefixText: _discountType == 'fixed' ? '£ ' : null,
                  suffixText: _discountType == 'percentage' ? '%' : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _discountType,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: _fieldDeco('Type', ''),
                dropdownColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1C1C1E)
                    : Colors.white,
                items: const [
                  DropdownMenuItem(value: 'percentage', child: Text('%')),
                  DropdownMenuItem(value: 'fixed', child: Text('£')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _discountType = val;
                    });
                  }
                },
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
                  icon: LucideIcons.plus,
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
