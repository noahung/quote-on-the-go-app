import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../components/mesh_background.dart';
import '../../components/glass_card.dart';
import '../../components/custom_date_time_picker.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  final CalendarEvent? event;
  const CreateEventScreen({super.key, this.event});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _endTime = TimeOfDay(
    hour: TimeOfDay.now().hour + 1,
    minute: TimeOfDay.now().minute,
  );
  bool _allDay = false;
  bool _isLoading = false;
  String _selectedColor = '#4A8CA8';
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
      _allDay = _editingEvent!.allDay ?? false;
      _selectedColor = _editingEvent!.color ?? '#4A8CA8';
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

  Future<void> _saveEvent() async {
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
      );

      if (isEditing) {
        await repository.updateEvent(event);
      } else {
        await repository.createEvent(event);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEditing ? 'Event updated' : 'Event created')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save event: $e')),
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

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            _editingEvent != null ? 'Edit Event' : 'New Event',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an event title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // All Day toggle
              SwitchListTile(
                title: const Text('All Day'),
                secondary: const Icon(Icons.access_time),
                value: _allDay,
                onChanged: (value) => setState(() => _allDay = value),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),

              // Start Date
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 1,
                        )),
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

              // End Date
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('End',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 1,
                        )),
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
                    letterSpacing: 1,
                  )),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colorOptions.map((opt) {
                  final isSelected = _selectedColor == opt['value'];
                  final color = Color(
                    int.parse(opt['value']!.replaceFirst('#', '0xff')),
                  );
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
                onPressed: _isLoading ? null : _saveEvent,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isLoading
                    ? (_editingEvent != null ? 'Saving...' : 'Creating...')
                    : (_editingEvent != null
                        ? 'Save Changes'
                        : 'Create Event')),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
