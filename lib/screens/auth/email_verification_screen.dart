import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/auth_page.dart';
import '../../providers/auth_provider.dart';
import '../../services/email_verification_service.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});
  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  final _code = TextEditingController();
  bool _sending = false, _verifying = false, _sent = false;
  int _countdown = 0;
  String? _error;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _send();
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _cooldown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) timer.cancel();
    });
  }

  Future<void> _send() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _sending || _verifying || _countdown > 0) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await emailVerificationService.sendCode(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'New user');
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result.success) {
        _sent = true;
        _cooldown();
      } else {
        _error = result.error;
      }
    });
  }

  Future<void> _verify() async {
    if (_sending || _verifying) return;
    if (_code.text.length != 6) {
      setState(() => _error = 'Enter the full 6-digit code.');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    final result = await emailVerificationService.verifyCode(
        uid: user.uid, code: _code.text);
    if (!mounted) return;
    if (result.success) {
      context.go('/onboarding');
    } else {
      setState(() {
        _verifying = false;
        _error = result.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AuthPage(
        title: 'Check your email',
        description: _sent
            ? 'Enter the 6-digit code sent to ${FirebaseAuth.instance.currentUser?.email ?? 'your email'}.'
            : 'We’ll send a code to verify your email address.',
        error: _error,
        children: [
          TextField(
              controller: _code,
              enabled: !_sending && !_verifying,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6)
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verify(),
              decoration: const InputDecoration(
                  labelText: 'Verification code', hintText: '6 digits')),
          const SizedBox(height: 24),
          FilledButton(
              onPressed: _sending || _verifying ? null : _verify,
              child: Text(_verifying ? 'Checking…' : 'Verify email')),
          const SizedBox(height: 16),
          TextButton(
              onPressed:
                  _countdown > 0 || _sending || _verifying ? null : _send,
              child: Text(_sending
                  ? 'Sending code…'
                  : _countdown > 0
                      ? 'Resend in ${_countdown}s'
                      : 'Resend code')),
          TextButton(
              onPressed: _sending || _verifying
                  ? null
                  : () async {
                      try {
                        await ref.read(authServiceProvider).signOut();
                      } catch (_) {
                        if (mounted)
                          setState(() =>
                              _error = 'Could not sign out. Please try again.');
                      }
                    },
              child: const Text('Use another account')),
        ],
      );
}
