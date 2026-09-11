import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/auth_page.dart';
import '../../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false, _sent = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .sendPasswordResetEmail(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'Could not send the reset link. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthPage(
        title: _sent ? 'Check your inbox' : 'Forgot your password?',
        description: _sent
            ? 'If an account uses ${_email.text.trim()}, you’ll receive a password reset link. Check your spam folder too.'
            : 'Enter your account email and we’ll send you a reset link.',
        error: _error,
        onBack: () => context.go('/login'),
        children: [
          if (!_sent)
            Form(
                key: _form,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                          controller: _email,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _send(),
                          decoration:
                              const InputDecoration(labelText: 'Email address'),
                          validator: validateAuthEmail),
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: _busy ? null : _send,
                          child: Text(_busy ? 'Sending…' : 'Send reset link')),
                    ])),
          if (_sent)
            FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to sign in')),
          if (_sent)
            TextButton(
                onPressed: () => setState(() {
                      _sent = false;
                      _error = null;
                    }),
                child: const Text('Use another email')),
        ],
      );
}
