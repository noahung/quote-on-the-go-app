import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../components/pill_button.dart';
import '../../providers/providers.dart';
import '../../utils/feedback_controller.dart';

class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  ConsumerState<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends ConsumerState<ReminderSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _enabled = false;
  List<int> _triggerDays = [];
  late TextEditingController _templateCtrl;
  late TextEditingController _newDayCtrl;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _templateCtrl = TextEditingController();
    _newDayCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _templateCtrl.dispose();
    _newDayCtrl.dispose();
    super.dispose();
  }

  void _populateFromSettings(ReminderSettings settings) {
    if (_initialised) return;
    _initialised = true;
    _enabled = settings.enabled;
    _triggerDays = List<int>.from(settings.triggerDays)..sort();
    _templateCtrl.text = settings.emailTemplate;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final companyIdVal = ref.read(companyIdProvider);
    if (companyIdVal == null) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(reminderRepositoryProvider);
      final newSettings = ReminderSettings(
        enabled: _enabled,
        triggerDays: _triggerDays,
        emailTemplate: _templateCtrl.text.trim(),
      );

      await repo.updateReminderSettings(companyIdVal, newSettings);

      if (mounted) {
        ref.read(feedbackControllerProvider).success(context, 'Reminder settings saved successfully');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Failed to save settings: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addTriggerDay() {
    final text = _newDayCtrl.text.trim();
    if (text.isEmpty) return;

    final day = int.tryParse(text);
    if (day == null || day <= 0) {
      ref.read(feedbackControllerProvider).error(context, 'Please enter a valid number of days (> 0)');
      return;
    }

    if (_triggerDays.contains(day)) {
      ref.read(feedbackControllerProvider).warning(context, 'This trigger day already exists');
      return;
    }

    setState(() {
      _triggerDays.add(day);
      _triggerDays.sort();
      _newDayCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userProfile = ref.watch(userProfileProvider);
    final isOwnerOrAdmin = userProfile?.role.toLowerCase() == 'owner' ||
        userProfile?.role.toLowerCase() == 'admin';

    final settingsAsync = ref.watch(reminderSettingsStreamProvider);

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'Payment Reminders',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (settings) {
            _populateFromSettings(settings);

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Automated Reminders Switch Card
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Automated Reminders',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Send email reminders automatically when invoices are overdue.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _enabled,
                          onChanged: isOwnerOrAdmin
                              ? (value) => setState(() => _enabled = value)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Trigger Schedule Editor Card
                  _SectionCard(
                    title: 'Schedule Triggers',
                    icon: LucideIcons.calendarClock,
                    children: [
                      Text(
                        'Configure how many days past the due date reminders should be sent.',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_triggerDays.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'No triggers configured. Reminders will not be sent.',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _triggerDays.length,
                          itemBuilder: (context, index) {
                            final day = _triggerDays[index];
                            return Column(
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  leading: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      LucideIcons.bellRing,
                                      size: 14,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  title: Text(
                                    '$day ${day == 1 ? 'day' : 'days'} overdue',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  trailing: isOwnerOrAdmin
                                      ? IconButton(
                                          icon: Icon(
                                            LucideIcons.x,
                                            size: 16,
                                            color: colorScheme.error,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _triggerDays.removeAt(index);
                                            });
                                          },
                                        )
                                      : null,
                                ),
                                if (index < _triggerDays.length - 1)
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: colorScheme.onSurface.withValues(alpha: 0.05),
                                  ),
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                      if (isOwnerOrAdmin)
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _newDayCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Days overdue',
                                  hintText: 'e.g. 7',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: PillButton(
                                text: 'Add Trigger',
                                icon: LucideIcons.plus,
                                onTap: _addTriggerDay,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Email Template Text Editor Card
                  _SectionCard(
                    title: 'Email Template',
                    icon: LucideIcons.fileText,
                    children: [
                      Text(
                        'Customise the text sent in payment reminder emails.',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _templateCtrl,
                        maxLines: 8,
                        enabled: isOwnerOrAdmin,
                        decoration: const InputDecoration(
                          hintText: 'Enter your reminder template here...',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email template cannot be empty';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available placeholders:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _PlaceholderItem(token: '{{customer_name}}', desc: "Client's name"),
                            _PlaceholderItem(token: '{{invoice_number}}', desc: "Invoice reference"),
                            _PlaceholderItem(token: '{{invoice_total}}', desc: "Invoice total (e.g. £120.00)"),
                            _PlaceholderItem(token: '{{due_date}}', desc: "Due date"),
                            _PlaceholderItem(token: '{{portal_url}}', desc: "Client portal link"),
                            _PlaceholderItem(token: '{{company_name}}', desc: "Your business name"),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (isOwnerOrAdmin)
                    PillButton(
                      text: _isSaving ? 'Saving...' : 'Save Settings',
                      icon: LucideIcons.save,
                      isLoading: _isSaving,
                      onTap: _isSaving ? null : _save,
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PlaceholderItem extends StatelessWidget {
  final String token;
  final String desc;

  const _PlaceholderItem({required this.token, required this.desc});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            token,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              desc,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassCard(
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
