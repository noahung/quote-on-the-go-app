import '../../components/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';

class InvitationScreen extends ConsumerStatefulWidget {
  final String id;
  const InvitationScreen({super.key, required this.id});
  @override
  ConsumerState<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends ConsumerState<InvitationScreen> {
  late Future<Map<String, dynamic>> _details;
  bool _joining = false;
  String? _error;
  Future<Map<String, dynamic>> _load() =>
      ApiClient.post('/api/mobile/invitation', {'invitationId': widget.id});
  @override
  void initState() {
    super.initState();
    _details = _load();
  }

  Future<void> _leave() async {
    await (await SharedPreferences.getInstance()).remove('pendingInvitationId');
    if (mounted) context.go('/');
  }

  Future<void> _join() async {
    if (_joining) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      await ApiClient.post('/api/mobile/invitation',
          {'invitationId': widget.id, 'accept': true});
      await (await SharedPreferences.getInstance())
          .remove('pendingInvitationId');
      ref.invalidate(userProfileStreamProvider);
      if (mounted) context.go('/');
    } catch (error) {
      if (mounted)
        setState(
            () => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _details,
        builder: (context, state) => AuthPage(
          title: state.hasData
              ? 'Join ${state.data?['companyName'] ?? 'your team'}'
              : 'Your team invitation',
          description: 'Use your invited email address to join the workspace.',
          error: _error ??
              (state.hasError
                  ? state.error.toString().replaceFirst('Exception: ', '')
                  : null),
          children: [
            if (state.connectionState != ConnectionState.done)
              const Center(child: CircularProgressIndicator())
            else if (state.hasError) ...[
              FilledButton(
                  onPressed: () => setState(() => _details = _load()),
                  child: const Text('Try again')),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: _joining
                      ? null
                      : () async {
                          try {
                            await ref.read(authServiceProvider).signOut();
                            if (context.mounted) context.go('/login');
                          } catch (_) {
                            if (mounted)
                              setState(() => _error =
                                  'Could not sign out. Please try again.');
                          }
                        },
                  child: const Text('Use another email')),
            ] else ...[
              Text('Your role: ${state.data?['role'] ?? 'member'}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: _joining ? null : _join,
                  child: Text(_joining ? 'Joining…' : 'Join team')),
            ],
            const SizedBox(height: 12),
            TextButton(
                onPressed: _joining ? null : _leave,
                child: const Text('Not now')),
          ],
        ),
      );
}
