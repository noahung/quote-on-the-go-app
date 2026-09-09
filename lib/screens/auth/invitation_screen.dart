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
  Future<Map<String, dynamic>> _load() => ApiClient.post('/api/mobile/invitation', {'invitationId': widget.id});
  @override
  void initState() { super.initState(); _details = _load(); }
  Future<void> _leave() async {
    await (await SharedPreferences.getInstance()).remove('pendingInvitationId');
    if (mounted) context.go('/');
  }
  Future<void> _join() async {
    if (_joining) return;
    setState(() { _joining = true; _error = null; });
    try {
      await ApiClient.post('/api/mobile/invitation', {'invitationId': widget.id, 'accept': true});
      await (await SharedPreferences.getInstance()).remove('pendingInvitationId');
      ref.invalidate(userProfileStreamProvider);
      if (mounted) context.go('/');
    } catch (error) { if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _joining = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Team invitation')),
    body: FutureBuilder<Map<String, dynamic>>(future: _details, builder: (context, state) {
      if (state.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      return ListView(padding: const EdgeInsets.all(24), children: [
        if (state.hasError) ...[
          Text(state.error.toString().replaceFirst('Exception: ', '')),
          const SizedBox(height: 16), OutlinedButton(onPressed: () => setState(() => _details = _load()), child: const Text('Try again')),
          TextButton(onPressed: () async { await ref.read(authServiceProvider).signOut(); if (context.mounted) context.go('/login'); },
            child: const Text('Sign in with another email')),
        ] else ...[
          Text('Join ${state.data?['companyName'] ?? 'your team'}', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16), Text('Your team role: ${state.data?['role'] ?? 'member'}'),
          const SizedBox(height: 24), FilledButton(onPressed: _joining ? null : _join,
            child: Text(_joining ? 'Joining…' : 'Join team')),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!)),
        ],
        TextButton(onPressed: _joining ? null : _leave, child: const Text('Not now')),
      ]);
    }));
}
