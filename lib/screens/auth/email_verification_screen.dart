import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isSending = false;
  bool _isVerifying = false;
  String? _errorMessage;
  bool _codeSent = false;

  // Resend cooldown
  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() => _resendCountdown = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendCountdown = 0);
      } else {
        if (mounted) setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _sendCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    final result = await emailVerificationService.sendCode(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? 'New User',
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _codeSent = true;
        _isSending = false;
      });
      _startResendCooldown();
    } else {
      setState(() {
        _errorMessage = result.error;
        _isSending = false;
      });
    }
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();

  Future<void> _verifyCode() async {
    final code = _enteredCode;
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the full 6-digit code.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final result = await emailVerificationService.verifyCode(
      uid: user.uid,
      code: code,
    );

    if (!mounted) return;

    if (result.success) {
      // Navigate to onboarding — router will redirect based on profile existence
      context.go('/onboarding');
    } else {
      setState(() {
        _isVerifying = false;
        _errorMessage = result.error;
      });
      // Clear the entered code on failure
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes.first.requestFocus();
    }
  }

  Future<void> _signOut() async {
    final authService = ref.read(authServiceProvider);
    await authService.signOut();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1) {
      // Move forward
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyCode();
      }
    } else if (value.isEmpty && index > 0) {
      // Move back on delete
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _signOut,
          tooltip: 'Sign out',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_unread_outlined,
                  size: 40,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Heading
              Text(
                'Check your inbox',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? "We've sent a 6-digit verification code to"
                    : 'Sending your verification code to',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),

              // Sending indicator
              if (_isSending)
                const CircularProgressIndicator()
              else ...[
                // OTP boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:
                      List.generate(6, (i) => _buildDigitBox(i, colorScheme)),
                ),
                const SizedBox(height: 24),

                // Error
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                                color: colorScheme.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_errorMessage != null) const SizedBox(height: 16),

                // Verify button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: (_isVerifying || _enteredCode.length != 6)
                        ? null
                        : _verifyCode,
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify Code'),
                  ),
                ),
                const SizedBox(height: 16),

                // Resend
                TextButton(
                  onPressed: _resendCountdown > 0 ? null : _sendCode,
                  child: Text(
                    _resendCountdown > 0
                        ? 'Resend code in ${_resendCountdown}s'
                        : 'Resend code',
                  ),
                ),
              ],

              const SizedBox(height: 32),
              Text(
                "Wrong account? Tap the back arrow to sign out.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDigitBox(int index, ColorScheme colorScheme) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
        onChanged: (value) => _onDigitChanged(index, value),
      ),
    );
  }
}
