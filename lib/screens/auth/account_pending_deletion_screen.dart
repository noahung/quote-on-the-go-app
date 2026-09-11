import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../components/auth_page.dart';
import '../../providers/auth_provider.dart';

class AccountPendingDeletionScreen extends ConsumerStatefulWidget {
  const AccountPendingDeletionScreen({super.key});

  @override
  ConsumerState<AccountPendingDeletionScreen> createState() =>
      _AccountPendingDeletionScreenState();
}

class _AccountPendingDeletionScreenState
    extends ConsumerState<AccountPendingDeletionScreen> {
  bool _isCancelling = false;
  bool _isSigningOut = false;

  Future<void> _cancelDeletion() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isCancelling = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.cancelAccountDeletion(user.uid);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account restored successfully! Welcome back.'),
          backgroundColor: Colors.green,
        ),
      );

      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling deletion: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        setState(() => _isSigningOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final scheduledDate = DateTime.tryParse(profile?.deletionScheduledAt ?? '');
    final busy = _isCancelling || _isSigningOut;
    return AuthPage(
      title: 'Account deletion scheduled',
      description:
          'You can cancel deletion during the grace period to keep your account.',
      children: [
        Text('Scheduled deletion',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(scheduledDate == null
            ? 'The deletion date is unavailable. Refresh your account details before continuing.'
            : DateFormat('d MMMM yyyy').format(scheduledDate)),
        if (profile?.deletionReason?.isNotEmpty == true) ...[
          const SizedBox(height: 16),
          Text('Reason: ${profile!.deletionReason}')
        ],
        const SizedBox(height: 24),
        const Text(
            'After the grace period, your account and associated data are scheduled for permanent removal.'),
        const SizedBox(height: 32),
        FilledButton(
            onPressed: busy ? null : _cancelDeletion,
            child:
                Text(_isCancelling ? 'Restoring account…' : 'Keep my account')),
        const SizedBox(height: 12),
        OutlinedButton(
            onPressed: busy ? null : _signOut,
            child: Text(_isSigningOut ? 'Signing out…' : 'Sign out')),
      ],
    );
  }
}
