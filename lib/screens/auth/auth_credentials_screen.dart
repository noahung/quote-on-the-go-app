import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/auth_page.dart';
import '../../providers/auth_provider.dart';

class AuthCredentialsScreen extends ConsumerStatefulWidget {
  const AuthCredentialsScreen({super.key, this.register = false});
  final bool register;
  @override
  ConsumerState<AuthCredentialsScreen> createState() =>
      _AuthCredentialsScreenState();
}

class _AuthCredentialsScreenState extends ConsumerState<AuthCredentialsScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false, _hidden = true, _confirmationHidden = true;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit({bool google = false}) async {
    if (_busy || (!google && !_form.currentState!.validate())) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      if (google) {
        await auth.signInWithGoogle();
      } else if (widget.register) {
        final result = await auth.createUserWithEmailAndPassword(
            _email.text.trim(), _password.text);
        await result.user?.updateDisplayName(_name.text.trim());
        TextInput.finishAutofillContext();
      } else {
        await auth.signInWithEmailAndPassword(
            _email.text.trim(), _password.text);
        TextInput.finishAutofillContext();
      }
    } on FirebaseAuthException catch (error) {
      if (mounted)
        setState(() => _error = switch (error.code) {
              'email-already-in-use' =>
                'An account already uses this email. Sign in to continue.',
              'network-request-failed' =>
                'Check your internet connection and try again.',
              'too-many-requests' =>
                'Too many attempts. Wait a moment before trying again.',
              'weak-password' =>
                'Choose a stronger password with at least 6 characters.',
              'invalid-email' => 'Check your email address and try again.',
              'user-disabled' =>
                'This account is disabled. Contact support for help.',
              _ => 'We could not sign you in. Check your email and password.',
            });
    } catch (_) {
      if (mounted)
        setState(() => _error = google
            ? 'Google sign-in could not finish. Please try again.'
            : 'Could not connect. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final register = widget.register;
    return AuthPage(
        title: register ? 'Let’s get you started' : 'Good to see you',
        description: register
            ? 'Create your account, then set up your business.'
            : 'Sign in to pick up where you left off.',
        error: _error,
        onBack: register ? () => context.go('/login') : null,
        children: [
          AutofillGroup(
              child: Form(
                  key: _form,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (register) ...[
                          TextFormField(
                              controller: _name,
                              enabled: !_busy,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              textInputAction: TextInputAction.next,
                              decoration:
                                  const InputDecoration(labelText: 'Your name'),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Enter your name.'
                                      : null),
                          const SizedBox(height: 20),
                        ],
                        TextFormField(
                            controller: _email,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                                labelText: 'Email address'),
                            validator: validateAuthEmail),
                        const SizedBox(height: 20),
                        TextFormField(
                            controller: _password,
                            enabled: !_busy,
                            obscureText: _hidden,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: [
                              register
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password
                            ],
                            textInputAction: register
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onFieldSubmitted:
                                register ? null : (_) => _submit(),
                            decoration: InputDecoration(
                                labelText: 'Password',
                                helperText:
                                    register ? 'At least 6 characters' : null,
                                suffixIcon: IconButton(
                                    tooltip: _hidden
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () =>
                                        setState(() => _hidden = !_hidden),
                                    icon: Icon(_hidden
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined))),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Enter your password.'
                                : register && value.length < 6
                                    ? 'Use at least 6 characters.'
                                    : null),
                        if (register) ...[
                          const SizedBox(height: 20),
                          TextFormField(
                              controller: _confirmation,
                              enabled: !_busy,
                              obscureText: _confirmationHidden,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                  labelText: 'Confirm password',
                                  suffixIcon: IconButton(
                                      tooltip: _confirmationHidden
                                          ? 'Show confirmation'
                                          : 'Hide confirmation',
                                      onPressed: () => setState(() =>
                                          _confirmationHidden =
                                              !_confirmationHidden),
                                      icon: Icon(_confirmationHidden
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined))),
                              validator: (value) => value != _password.text ||
                                      value == null ||
                                      value.isEmpty
                                  ? 'Passwords need to match.'
                                  : null),
                        ] else
                          Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => context.push('/reset-password'),
                                  child: const Text('Forgot password?'))),
                        const SizedBox(height: 24),
                        FilledButton(
                            onPressed: _busy ? null : () => _submit(),
                            child: Text(_busy
                                ? 'Please wait…'
                                : register
                                    ? 'Create account'
                                    : 'Sign in')),
                      ]))),
          const SizedBox(height: 24),
          Row(children: [
            const Expanded(child: Divider()),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child:
                    Text('or', style: Theme.of(context).textTheme.bodyMedium)),
            const Expanded(child: Divider())
          ]),
          const SizedBox(height: 24),
          OutlinedButton(
              onPressed: _busy ? null : () => _submit(google: true),
              child: const Text('Continue with Google')),
          const SizedBox(height: 16),
          TextButton(
              onPressed: _busy
                  ? null
                  : () => context.go(register ? '/login' : '/register'),
              child: Text(register
                  ? 'Already have an account? Sign in'
                  : 'New here? Create an account')),
        ]);
  }
}
