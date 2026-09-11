import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/document_email_preview.dart';
import '../../components/preview_status_panel.dart';
import '../../components/settings_action_row.dart';
import '../../providers/providers.dart';
import '../../utils/feedback_controller.dart';

class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});
  @override
  ConsumerState<ReminderSettingsScreen> createState() =>
      _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState
    extends ConsumerState<ReminderSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _templateCtrl = TextEditingController();
  final _newDayCtrl = TextEditingController();
  final Map<int, bool> _rules = {};
  bool _initialised = false, _enabled = false, _isSaving = false;
  String? _dayError;
  String? _loadedCompanyId;

  @override
  void dispose() {
    _templateCtrl.dispose();
    _newDayCtrl.dispose();
    super.dispose();
  }

  void _populate(ReminderSettings settings) {
    if (_initialised) return;
    _initialised = true;
    _enabled = settings.enabled;
    _templateCtrl.text = settings.emailTemplate;
    for (final day in settings.disabledTriggerDays) {
      _rules[day] = false;
    }
    for (final day in settings.triggerDays) {
      _rules[day] = true;
    }
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    final companyId = ref.read(companyIdProvider);
    if (companyId == null) {
      ref
          .read(feedbackControllerProvider)
          .error(context, 'Your company is unavailable. Please sign in again.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(reminderRepositoryProvider).updateReminderSettings(
          companyId,
          ReminderSettings(
            enabled: _enabled,
            triggerDays: _rules.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList(),
            disabledTriggerDays: _rules.entries
                .where((entry) => !entry.value)
                .map((entry) => entry.key)
                .toList(),
            emailTemplate: _templateCtrl.text.trim(),
          ));
      if (mounted) {
        ref
            .read(feedbackControllerProvider)
            .success(context, 'Reminder settings saved');
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ref.read(feedbackControllerProvider).error(context,
            'Could not save reminders. Your changes are still here. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addRule() {
    final day = int.tryParse(_newDayCtrl.text.trim());
    setState(() {
      if (day == null || day <= 0 || day > 365) {
        _dayError = 'Enter a whole number between 1 and 365.';
      } else if (_rules.length >= 12) {
        _dayError = 'You can add up to 12 reminder days.';
      } else if (_rules.containsKey(day)) {
        _dayError = 'A reminder for this day already exists.';
      } else {
        _rules[day] = true;
        _dayError = null;
        _newDayCtrl.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final companyId = ref.watch(companyIdProvider);
    if (_loadedCompanyId != companyId) {
      _loadedCompanyId = companyId;
      _initialised = false;
      _rules.clear();
      _newDayCtrl.clear();
      _dayError = null;
    }
    final role = ref.watch(userProfileProvider)?.role.toLowerCase();
    final canEdit = ['owner', 'admin'].contains(role) && !_isSaving;
    final settings = ref.watch(reminderSettingsStreamProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Payment reminders')),
      body: settings.when(
        loading: () => const PreviewStatusPanel(
            message: 'Loading reminder settings…', loading: true),
        error: (_, __) => PreviewStatusPanel(
            message:
                'Could not load reminder settings. Check your connection and try again.',
            onRetry: () => ref.invalidate(reminderSettingsStreamProvider)),
        data: (value) {
          _populate(value);
          final days = _rules.keys.toList()..sort();
          return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Form(
                    key: _formKey,
                    child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                        children: [
                          const SettingsSectionHeading('Reminders',
                              first: true),
                          _Panel(
                              child: SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Automatic reminders'),
                                  subtitle: const Text(
                                      'Follow up on overdue invoices using the schedule below.'),
                                  value: _enabled,
                                  onChanged: canEdit
                                      ? (value) =>
                                          setState(() => _enabled = value)
                                      : null)),
                          const SettingsSectionHeading('Schedule'),
                          Text(
                              'Choose when to follow up after the due date. Disabled rules stay saved.',
                              style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 16),
                          if (days.isEmpty)
                            const Text(
                                'No reminder days yet. Add a day to get started.'),
                          for (final day in days)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _Panel(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                      SwitchListTile.adaptive(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(
                                              '$day ${day == 1 ? 'day' : 'days'} overdue'),
                                          value: _rules[day]!,
                                          onChanged: canEdit
                                              ? (value) => setState(
                                                  () => _rules[day] = value)
                                              : null),
                                      if (canEdit)
                                        Align(
                                            alignment: Alignment.centerLeft,
                                            child: TextButton.icon(
                                                onPressed: () => setState(
                                                    () => _rules.remove(day)),
                                                icon: const Icon(
                                                    Icons.delete_outline),
                                                label:
                                                    Text('Remove day $day'))),
                                    ]))),
                          if (canEdit) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                                controller: _newDayCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    labelText: 'Days overdue',
                                    hintText: 'For example, 7',
                                    errorText: _dayError),
                                onFieldSubmitted: (_) => _addRule()),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                                onPressed: _addRule,
                                icon: const Icon(Icons.add),
                                label: const Text('Add reminder day')),
                          ],
                          const SettingsSectionHeading('Email message'),
                          const Text(
                              'Write the full reminder message, or leave it blank to use the default. Automatic reminders link to the invoice; manual reminders also attach the PDF.'),
                          const SizedBox(height: 16),
                          TextFormField(
                              controller: _templateCtrl,
                              readOnly: !canEdit,
                              minLines: 5,
                              maxLines: 12,
                              decoration: const InputDecoration(
                                  labelText: 'Reminder message',
                                  hintText:
                                      'Leave blank for the default message',
                                  alignLabelWithHint: true),
                              validator: (value) => (value?.length ?? 0) > 10000
                                  ? 'Use 10,000 characters or fewer.'
                                  : null),
                          const SizedBox(height: 12),
                          ExpansionTile(
                              title: const Text('Personalise your message'),
                              tilePadding: EdgeInsets.zero,
                              children: [
                                for (final item in const {
                                  '{{customer_name}}': 'Customer name',
                                  '{{invoice_number}}': 'Invoice number',
                                  '{{invoice_total}}': 'Invoice total',
                                  '{{due_date}}': 'Due date',
                                  '{{portal_url}}': 'Invoice portal link',
                                  '{{company_name}}': 'Your company name',
                                }.entries)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                SelectableText(item.key,
                                                    style: theme
                                                        .textTheme.bodyLarge
                                                        ?.copyWith(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600)),
                                                Text(item.value,
                                                    style: theme
                                                        .textTheme.bodyMedium),
                                              ])))
                              ]),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('Preview sample email'),
                              onPressed: _isSaving
                                  ? null
                                  : () {
                                      if (!_formKey.currentState!.validate()) {
                                        return;
                                      }
                                      final companyId =
                                          ref.read(companyIdProvider);
                                      if (companyId == null) return;
                                      FocusScope.of(context).unfocus();
                                      Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  DocumentEmailPreview.reminder(
                                                      companyId: companyId,
                                                      template:
                                                          _templateCtrl.text)));
                                    }),
                          const SizedBox(height: 16),
                          if (['owner', 'admin'].contains(role))
                            FilledButton(
                                onPressed: _isSaving ? null : _save,
                                child: Text(_isSaving
                                    ? 'Saving…'
                                    : 'Save reminder settings')),
                        ])),
              ));
        },
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: child,
      ));
}
