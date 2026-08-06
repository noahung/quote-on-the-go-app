import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/auth_provider.dart';

const List<String> _deletionReasons = [
  'I no longer need this service',
  'I found a better alternative',
  'The service is too expensive',
  'Privacy concerns',
  'I\'m closing my business',
  'Other',
];

class AccountDeletionCard extends ConsumerStatefulWidget {
  const AccountDeletionCard({super.key});

  @override
  ConsumerState<AccountDeletionCard> createState() =>
      _AccountDeletionCardState();
}

class _AccountDeletionCardState extends ConsumerState<AccountDeletionCard> {
  void _openDeletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _AccountDeletionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final userProfile = ref.watch(userProfileProvider);
    final isOwner = userProfile?.role == 'owner';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              LucideIcons.shieldAlert,
              color: colorScheme.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete Account ${isOwner ? "& Workspace" : ""}',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Permanently delete your account ${isOwner ? "and workspace " : ""}after a 30-day grace holding period.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _openDeletionDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(LucideIcons.trash2, size: 14),
                    label: const Text(
                      'Delete Account',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountDeletionDialog extends ConsumerStatefulWidget {
  const _AccountDeletionDialog();

  @override
  ConsumerState<_AccountDeletionDialog> createState() =>
      __AccountDeletionDialogState();
}

class __AccountDeletionDialogState extends ConsumerState<_AccountDeletionDialog> {
  int _step = 1;
  String? _selectedReason;
  bool _deleteCompanyData = true;
  final TextEditingController _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirmDeletion() async {
    final user = ref.read(currentUserProvider);
    final userProfile = ref.read(userProfileProvider);
    if (user == null) return;

    if (_confirmController.text.trim().toLowerCase() != 'delete') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please type DELETE to confirm.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final isOwner = userProfile?.role == 'owner';

      await authService.requestAccountDeletion(
        uid: user.uid,
        reason: _selectedReason,
        deleteCompanyData: isOwner && _deleteCompanyData,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Deletion requested. Your account has been scheduled for deletion.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final userProfile = ref.watch(userProfileProvider);
    final company = ref.watch(companyProvider);
    final isOwner = userProfile?.role == 'owner';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _step == 1 ? LucideIcons.alertTriangle : LucideIcons.shieldAlert,
              color: colorScheme.error,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _step == 1
                ? 'Why are you leaving?'
                : 'Confirm ${isOwner && _deleteCompanyData ? "Account & Workspace" : "Account"} Deletion',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_step == 1) ...[
              Text(
                'We\'re sorry to see you go. Please let us know your reason for deleting your account.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedReason,
                decoration: InputDecoration(
                  labelText: 'Reason for leaving',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: _deletionReasons.map((reason) {
                  return DropdownMenuItem(
                    value: reason,
                    child: Text(reason, style: textTheme.bodyMedium),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedReason = val),
              ),
              if (isOwner) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _deleteCompanyData,
                        onChanged: (val) {
                          setState(() => _deleteCompanyData = val ?? false);
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete Company Workspace & All Data',
                              style: textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Schedules ${company?.name ?? "your company"} and all invoices, quotes, and customers for 30-day deletion.',
                              style: textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What happens next:',
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _bulletPoint('Account will be immediately deactivated & signed out'),
                    if (isOwner && _deleteCompanyData)
                      _bulletPoint(
                        'Company workspace & all data (invoices, quotes) scheduled for deletion',
                        textColor: colorScheme.error,
                      ),
                    _bulletPoint('Data is securely held for 30 days'),
                    _bulletPoint('You can cancel anytime by signing back in'),
                    _bulletPoint('After 30 days, data is permanently erased'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Type DELETE to confirm:',
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmController,
                decoration: InputDecoration(
                  hintText: 'Type DELETE here',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_step == 1)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            onPressed: _selectedReason == null
                ? null
                : () => setState(() => _step = 2),
            child: const Text('Continue'),
          )
        else
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            onPressed:
                _confirmController.text.trim().toLowerCase() == 'delete' &&
                        !_isLoading
                    ? _handleConfirmDeletion
                    : null,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    isOwner && _deleteCompanyData
                        ? 'Delete Account & Workspace'
                        : 'Delete My Account',
                  ),
          ),
      ],
    );
  }

  Widget _bulletPoint(String text, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: textColor ?? Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
