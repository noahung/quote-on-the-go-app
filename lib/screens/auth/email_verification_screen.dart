import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/mesh_background.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // ── Gradient header ───────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6B00), Color(0xFFF4781F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _signOut,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Verify your email',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _codeSent
                            ? 'Enter the 6-digit code we sent you'
                            : 'Sending your verification code…',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Column(
                  children: [
                    // Email indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.email_outlined,
                              size: 16, color: Color(0xFFFF6B00)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              email,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF6B00),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    if (_isSending)
                      const CircularProgressIndicator()
                    else ...[
                      // OTP card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                          boxShadow: isDark
                              ? []
                              : [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                              6, (i) => _buildDigitBox(i, colorScheme, isDark)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Error banner
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: colorScheme.error
                                    .withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: colorScheme.error, size: 18),
                              const SizedBox(width: 10),
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
                        const SizedBox(height: 20),
                      ],

                      // Verify pill button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B00),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          onPressed:
                              (_isVerifying || _enteredCode.length != 6)
                                  ? null
                                  : _verifyCode,
                          child: _isVerifying
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Verify Code',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Resend
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white24
                                  : Colors.black.withValues(alpha: 0.12),
                            ),
                          ),
                          onPressed:
                              _resendCountdown > 0 ? null : _sendCode,
                          child: Text(
                            _resendCountdown > 0
                                ? 'Resend code in ${_resendCountdown}s'
                                : 'Resend code',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),
                    Text(
                      'Tap the back arrow to sign out if this is the wrong account.',
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
          ],
        ),
      ),
    );
  }

  Widget _buildDigitBox(int index, ColorScheme colorScheme, bool isDark) {
    return SizedBox(
      width: 44,
      height: 54,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFFF6B00),
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFFFF6B00), width: 2),
          ),
        ),
        onChanged: (value) => _onDigitChanged(index, value),
      ),
    );
  }
}
