import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_event.dart';
import '../../models/customer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../components/mesh_background.dart';
import '../../components/glass_card.dart';
import '../../components/custom_date_time_picker.dart';
import '../../utils/feedback_controller.dart';
import '../../models/feedback_type.dart';

const List<String> _jobStatuses = [
  'Draft',
  'Scheduled',
  'In Progress',
  'Completed',
  'Cancelled',
];

class CreateJobScreen extends ConsumerStatefulWidget {
  final CalendarEvent? event;
  const CreateJobScreen({super.key, this.event});

  @override
  ConsumerState<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends ConsumerState<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _customerSearchController = TextEditingController();

  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _endTime = TimeOfDay(
    hour: TimeOfDay.now().hour + 1,
    minute: TimeOfDay.now().minute,
  );
  bool _allDay = false;
  bool _isLoading = false;
  String _selectedColor = '#4285F4';
  String _selectedStatus = 'Draft';
  Customer? _selectedCustomer;
  CalendarEvent? _editingEvent;

  final List<Map<String, String>> _colorOptions = const [
    {'label': 'Blue', 'value': '#4A8CA8'}, // Desaturated blue
    {'label': 'Red', 'value': '#B94A4A'}, // Desaturated red
    {'label': 'Green', 'value': '#2D7D5E'}, // Desaturated green
    {'label': 'Orange', 'value': '#BA6935'}, // Desaturated orange
    {'label': 'Purple', 'value': '#6A579B'}, // Desaturated purple
    {'label': 'Teal', 'value': '#3B7A75'}, // Desaturated teal
  ];

  @override
  void initState() {
    super.initState();
    _editingEvent = widget.event;
    if (_editingEvent != null) {
      _titleController.text = _editingEvent!.title;
      _descriptionController.text = _editingEvent!.description ?? '';
      _addressController.text = _editingEvent!.customerAddress ?? '';
      _allDay = _editingEvent!.allDay ?? false;
      _selectedColor = _editingEvent!.color ?? '#4A8CA8';
      _selectedStatus = _editingEvent!.status ?? 'Draft';
      final start = DateTime.tryParse(_editingEvent!.start);
      final end = DateTime.tryParse(_editingEvent!.end);
      if (start != null) {
        _startDate = start;
        _startTime = TimeOfDay(hour: start.hour, minute: start.minute);
      }
      if (end != null) {
        _endDate = end;
        _endTime = TimeOfDay(hour: end.hour, minute: end.minute);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDateTime(bool isStart) async {
    final initial = isStart 
        ? _combineDateAndTime(_startDate, _startTime)
        : _combineDateAndTime(_endDate, _endTime);
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomDateTimePickerSheet(
        initialDateTime: initial,
        title: isStart ? 'Select Start Date & Time' : 'Select End Date & Time',
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          _startTime = TimeOfDay.fromDateTime(picked);
          // Auto-adjust end date if start date moves past it
          final end = _combineDateAndTime(_endDate, _endTime);
          if (end.isBefore(picked)) {
            _endDate = picked.add(const Duration(hours: 1));
            _endTime = TimeOfDay.fromDateTime(_endDate);
          }
        } else {
          _endDate = picked;
          _endTime = TimeOfDay.fromDateTime(picked);
        }
      });
    }
  }

  void _showCustomerPicker(List<Customer> customers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _CustomerPickerSheet(
          customers: customers,
          selectedCustomer: _selectedCustomer,
          onSelected: (c) {
            setState(() {
              _selectedCustomer = c;
              if (c != null && _addressController.text.isEmpty) {
                _addressController.text = c.address ?? '';
              }
            });
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  Future<void> _saveJob() async {
    if (!_formKey.currentState!.validate()) return;

    final companyId = ref.read(companyIdProvider);
    final user = ref.read(currentUserProvider);
    if (companyId == null || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User or company not found')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(scheduleRepositoryProvider);
      final start = _allDay
          ? DateTime(_startDate.year, _startDate.month, _startDate.day)
          : _combineDateAndTime(_startDate, _startTime);
      final end = _allDay
          ? DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59)
          : _combineDateAndTime(_endDate, _endTime);

      if (end.isBefore(start)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final isEditing = _editingEvent != null;

      final event = CalendarEvent(
        id: isEditing ? _editingEvent!.id : '',
        companyId: companyId,
        userId: user.uid,
        title: _titleController.text.trim(),
        start: start.toIso8601String(),
        end: end.toIso8601String(),
        allDay: _allDay,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        color: _selectedColor,
        status: _selectedStatus,
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name,
        customerAddress: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      );

      if (isEditing) {
        await repository.updateEvent(event);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job updated')),
          );
          context.pop();
        }
      } else {
        final newId = await repository.createEvent(event);
        if (mounted) {
          await ref.read(feedbackControllerProvider).showCelebration(
            context: context,
            type: CelebrationType.checkmark,
            title: 'Job Created',
            subtitle: 'Your job has been scheduled successfully',
            onDone: () => context.pop(),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save job: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final timeFormat = DateFormat('HH:mm');
    final customersAsync = ref.watch(customersStreamProvider);
    final customers = customersAsync.valueOrNull ?? [];

    // Pre-fill selected customer when editing
    if (_editingEvent?.customerId != null && _selectedCustomer == null) {
      final match = customers.where((c) => c.id == _editingEvent!.customerId);
      if (match.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() => _selectedCustomer = match.first);
        });
      }
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/schedule');
              }
            },
          ),
          title: Text(
            _editingEvent != null ? 'Edit Job' : 'New Job',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Job Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Job Title',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter a job title'
                    : null,
              ),
              const SizedBox(height: 16),

              // Customer selector
              Text(
                'Customer',
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _showCustomerPicker(customers),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline,
                          color: colorScheme.onSurfaceVariant, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedCustomer?.name ??
                              'Select customer (optional)',
                          style: TextStyle(
                            color: _selectedCustomer != null
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (_selectedCustomer != null)
                        IconButton(
                          icon: Icon(Icons.clear,
                              size: 18, color: colorScheme.onSurfaceVariant),
                          onPressed: () =>
                              setState(() => _selectedCustomer = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      else
                        Icon(Icons.arrow_drop_down,
                            color: colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Status dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: _jobStatuses
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedStatus = v);
                },
              ),
              const SizedBox(height: 16),

              // Address
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Site Address (optional)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // All Day toggle
              SwitchListTile(
                title: const Text('All Day'),
                secondary: const Icon(Icons.access_time),
                value: _allDay,
                onChanged: (v) => setState(() => _allDay = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),

              // Start Date/Time
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start',
                        style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 1)),
                    const SizedBox(height: 8),
                     Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDateTime(true),
                            icon: const Icon(Icons.schedule, size: 18),
                            label: Text(
                              _allDay 
                                  ? dateFormat.format(_startDate)
                                  : '${dateFormat.format(_startDate)} at ${timeFormat.format(_combineDateAndTime(_startDate, _startTime))}'
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // End Date/Time
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('End',
                        style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDateTime(false),
                            icon: const Icon(Icons.schedule, size: 18),
                            label: Text(
                              _allDay 
                                  ? dateFormat.format(_endDate)
                                  : '${dateFormat.format(_endDate)} at ${timeFormat.format(_combineDateAndTime(_endDate, _endTime))}'
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Color picker
              Text('Color',
                  style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colorOptions.map((opt) {
                  final isSelected = _selectedColor == opt['value'];
                  final color =
                      Color(int.parse(opt['value']!.replaceFirst('#', '0xff')));
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = opt['value']!),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: colorScheme.onSurface, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _isLoading ? null : _saveJob,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_isLoading
                    ? (_editingEvent != null ? 'Saving...' : 'Creating...')
                    : (_editingEvent != null ? 'Save Changes' : 'Create Job')),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  final List<Customer> customers;
  final Customer? selectedCustomer;
  final ValueChanged<Customer?> onSelected;

  const _CustomerPickerSheet({
    required this.customers,
    required this.selectedCustomer,
    required this.onSelected,
  });

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = widget.customers
        .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search customers...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    final isSelected = widget.selectedCustomer?.id == c.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                          style:
                              TextStyle(color: colorScheme.onPrimaryContainer),
                        ),
                      ),
                      title: Text(c.name),
                      subtitle: c.email.isNotEmpty ? Text(c.email) : null,
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: colorScheme.primary)
                          : null,
                      onTap: () => widget.onSelected(c),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
