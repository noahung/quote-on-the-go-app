import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/providers.dart';
import '../../providers/auth_provider.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../models/models.dart';

const List<String> _kTriggers = [
  'quotation_created',
  'quotation_sent',
  'quotation_accepted',
  'quotation_declined',
  'invoice_created',
  'invoice_sent',
  'invoice_paid',
  'job_status_changed',
  'customer_created',
];

const List<String> _kTriggerLabels = [
  'Quotation Created',
  'Quotation Sent',
  'Quotation Accepted',
  'Quotation Declined',
  'Invoice Created',
  'Invoice Sent',
  'Invoice Paid',
  'Job Status Changed',
  'Customer Created',
];

const List<String> _kActions = [
  'send_email',
  'send_sms',
  'wait',
];

const List<String> _kActionLabels = [
  'Send Email',
  'Send SMS',
  'Wait',
];

class _WorkflowStep {
  String actionType;
  String subject;
  String body;
  int waitValue;
  String waitUnit; // 'hours', 'days', 'business_days'

  _WorkflowStep({
    this.actionType = 'send_email',
  })  : subject = '',
        body = '',
        waitValue = 1,
        waitUnit = 'days';
}

class CreateWorkflowScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? prefillTemplate;

  const CreateWorkflowScreen({super.key, this.prefillTemplate});

  @override
  ConsumerState<CreateWorkflowScreen> createState() =>
      _CreateWorkflowScreenState();
}

class _CreateWorkflowScreenState extends ConsumerState<CreateWorkflowScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedTrigger = _kTriggers.first;
  List<_WorkflowStep> _steps = [];
  bool _isActive = true;
  bool _isSaving = false;

  int? _maxRetries;
  int? _retryDelaySeconds;
  String? _onFailureAction;
  final List<TriggerCondition> _conditions = [];

  @override
  void initState() {
    super.initState();
    final t = widget.prefillTemplate;
    if (t != null) {
      _nameController.text = t['title'] as String? ?? t['name'] as String? ?? '';
      _descriptionController.text = t['desc'] as String? ?? t['description'] as String? ?? '';
      final type = t['type'] as String?;
      if (type != null && _kTriggers.contains(type)) {
        _selectedTrigger = type;
      }
      _maxRetries = t['maxRetries'] as int?;
      _retryDelaySeconds = t['retryDelaySeconds'] as int?;
      _onFailureAction = t['onFailureAction'] as String?;

      final rawConditions = t['conditions'] as List?;
      if (rawConditions != null) {
        for (final rc in rawConditions) {
          if (rc is Map) {
            _conditions.add(TriggerCondition(
              field: rc['field'] as String? ?? '',
              operator: rc['operator'] as String? ?? 'equals',
              value: rc['value'] as String? ?? '',
            ));
          }
        }
      }

      final rawSteps = t['steps'] as List?;
      if (rawSteps != null && rawSteps.isNotEmpty) {
        _steps = rawSteps.map((s) {
          final m = s as Map;
          final step = _WorkflowStep(actionType: m['type'] as String? ?? 'send_email');
          step.subject = m['subject'] as String? ?? '';
          step.body = m['body'] as String? ?? '';
          if (m['delay'] is Map) {
            final delayMap = m['delay'] as Map;
            step.waitValue = delayMap['value'] as int? ?? 1;
            step.waitUnit = delayMap['type'] as String? ?? 'days';
          } else {
            step.waitValue = m['waitDays'] as int? ?? 1;
            step.waitUnit = 'days';
          }
          return step;
        }).toList();
      }
    }
    if (_steps.isEmpty) _steps = [_WorkflowStep()];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addStep() {
    setState(() => _steps.add(_WorkflowStep()));
  }

  void _removeStep(int index) {
    if (_steps.length > 1) {
      setState(() => _steps.removeAt(index));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final companyId = ref.read(companyIdProvider);
    final userProfile = ref.read(userProfileProvider);
    if (companyId == null || userProfile == null) return;

    setState(() => _isSaving = true);

    try {
      final stepsData = _steps.asMap().entries.map((entry) {
        final step = entry.value;
        return {
          'order': entry.key,
          'type': step.actionType,
          if (step.actionType == 'wait') ...{
            'delay': {
              'type': step.waitUnit,
              'value': step.waitValue,
            },
            'waitDays': step.waitUnit == 'hours' ? 0 : step.waitValue,
          } else ...{
            'subject': step.subject,
            'body': step.body,
          },
        };
      }).toList();

      await FirebaseFirestore.instance.collection('workflow_templates').add({
        'companyId': companyId,
        'createdBy': userProfile.uid,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'type': _selectedTrigger,
        'trigger': {
          'event': _selectedTrigger,
        },
        'steps': stepsData,
        'isActive': _isActive,
        'maxRetries': _maxRetries,
        'retryDelaySeconds': _retryDelaySeconds,
        'onFailureAction': _onFailureAction,
        'conditions': _conditions.map((c) => c.toJson()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workflow created successfully!')),
        );
        Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Create Workflow',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          actions: [
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Workflow Name',
                  hintText: 'e.g. Quote Follow-Up Sequence',
                  prefixIcon: const Icon(Icons.auto_mode),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: const Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),

              // Trigger
              DropdownButtonFormField<String>(
                value: _selectedTrigger,
                decoration: InputDecoration(
                  labelText: 'Trigger Event',
                  prefixIcon: const Icon(Icons.bolt_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: List.generate(
                  _kTriggers.length,
                  (i) => DropdownMenuItem(
                    value: _kTriggers[i],
                    child: Text(_kTriggerLabels[i]),
                  ),
                ),
                onChanged: (v) =>
                    setState(() => _selectedTrigger = v ?? _kTriggers.first),
              ),
              const SizedBox(height: 12),

              // Active toggle
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.power_settings_new,
                        color: _isActive ? Colors.green : colorScheme.outline),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Activate immediately',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Switch(
                      value: _isActive,
                      activeColor: const Color(0xFFF4781F),
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Trigger Conditions Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Trigger Conditions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _conditions.add(const TriggerCondition(
                          field: '',
                          operator: 'equals',
                          value: '',
                        ));
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Condition', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_conditions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No conditions defined. Trigger runs on every event.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ..._conditions.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final cond = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: cond.field,
                                  decoration: InputDecoration(
                                    labelText: 'Field Path',
                                    hintText: 'e.g. total, status',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    isDense: true,
                                  ),
                                  onChanged: (v) {
                                    _conditions[idx] = cond.copyWith(field: v.trim());
                                  },
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: colorScheme.error),
                                onPressed: () {
                                  setState(() {
                                    _conditions.removeAt(idx);
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: cond.operator,
                                  decoration: InputDecoration(
                                    labelText: 'Operator',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    isDense: true,
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'equals', child: Text('Equals (==)')),
                                    DropdownMenuItem(value: 'not_equals', child: Text('Not Equals (!=)')),
                                    DropdownMenuItem(value: 'greater_than', child: Text('Greater Than (>)')),
                                    DropdownMenuItem(value: 'less_than', child: Text('Less Than (<)')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      _conditions[idx] = cond.copyWith(operator: v);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: cond.value,
                                  decoration: InputDecoration(
                                    labelText: 'Value',
                                    hintText: 'e.g. 1000, paid',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    isDense: true,
                                  ),
                                  onChanged: (v) {
                                    _conditions[idx] = cond.copyWith(value: v.trim());
                                  },
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),

              // Retry Settings
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Retry Settings (Optional)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _maxRetries != null ? '$_maxRetries' : '',
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Max Retries',
                              hintText: 'e.g. 3',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                            onChanged: (v) => _maxRetries = int.tryParse(v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: _retryDelaySeconds != null ? '$_retryDelaySeconds' : '',
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Retry Delay (s)',
                              hintText: 'e.g. 60',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                            onChanged: (v) => _retryDelaySeconds = int.tryParse(v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _onFailureAction,
                      decoration: InputDecoration(
                        labelText: 'On Failure Action',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('None (Default)')),
                        DropdownMenuItem(value: 'none', child: Text('None (Do nothing)')),
                        DropdownMenuItem(value: 'notify_owner', child: Text('Notify Owner')),
                        DropdownMenuItem(value: 'stop', child: Text('Stop Execution')),
                      ],
                      onChanged: (v) => setState(() => _onFailureAction = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Steps
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Automation Steps',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  TextButton.icon(
                    onPressed: _addStep,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Step',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ...List.generate(_steps.length, (index) {
                return _buildStepCard(index, isDark, colorScheme);
              }),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF4781F),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Create Workflow',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard(int index, bool isDark, ColorScheme colorScheme) {
    final step = _steps[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFF4781F).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                          color: Color(0xFFF4781F),
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Step',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const Spacer(),
                if (_steps.length > 1)
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 18, color: colorScheme.outline),
                    onPressed: () => _removeStep(index),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: step.actionType,
              decoration: InputDecoration(
                labelText: 'Action Type',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              items: List.generate(
                _kActions.length,
                (i) => DropdownMenuItem(
                  value: _kActions[i],
                  child: Text(_kActionLabels[i]),
                ),
              ),
              onChanged: (v) => setState(
                  () => step.actionType = v ?? _kActions.first),
            ),
            const SizedBox(height: 10),
            if (step.actionType == 'wait') ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: '${step.waitValue}',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Duration',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                      onChanged: (v) =>
                          step.waitValue = int.tryParse(v) ?? 1,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (int.tryParse(v.trim()) == null || int.parse(v.trim()) < 1) {
                          return 'Must be at least 1';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: step.waitUnit,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'hours', child: Text('Hours')),
                        DropdownMenuItem(value: 'days', child: Text('Calendar Days')),
                        DropdownMenuItem(value: 'business_days', child: Text('Business Days')),
                      ],
                      onChanged: (v) => setState(() => step.waitUnit = v ?? 'days'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              TextFormField(
                key: ValueKey('subject_${step.actionType}_$index'),
                initialValue: step.subject.isEmpty ? null : step.subject,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: step.actionType == 'send_sms'
                      ? 'SMS Message'
                      : 'Email Subject',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
                onChanged: (v) => step.subject = v,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              if (step.actionType == 'send_email') ...[
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: step.body,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Email Body',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                    alignLabelWithHint: true,
                  ),
                  onChanged: (v) => step.body = v,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
