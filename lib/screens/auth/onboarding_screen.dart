import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../components/mesh_background.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  bool _initialized = false;

  // Step form keys
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  // Controllers
  final _displayNameCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();
  final _companyEmailCtrl = TextEditingController();
  final _companyPhoneCtrl = TextEditingController();
  final _companyAddressCtrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final user = ref.read(currentUserProvider);
      if (user != null) {
        _displayNameCtrl.text = user.displayName ?? '';
        _companyEmailCtrl.text = user.email ?? '';
        // Schedule after build to avoid "modified provider during build" error
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(onboardingNotifierProvider.notifier).init(
                  displayName: user.displayName ?? '',
                  email: user.email ?? '',
                );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _displayNameCtrl.dispose();
    _companyNameCtrl.dispose();
    _companyEmailCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _companyAddressCtrl.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
    );
    if (picked != null) {
      ref
          .read(onboardingNotifierProvider.notifier)
          .updateLogoFile(File(picked.path));
    }
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final success =
        await ref.read(onboardingNotifierProvider.notifier).submit(user.uid);
    if (success && mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(onboardingNotifierProvider);

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // ── Gradient header ──────────────────────────────────────────
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
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Quote On The Go',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'Step ${formState.currentStep + 1} of 3',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _StepProgressBar(
                        currentStep: formState.currentStep,
                        totalSteps: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Pages ────────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _Step1PersonalInfo(
                    formKey: _step1Key,
                    displayNameCtrl: _displayNameCtrl,
                    onNext: () {
                      if (_step1Key.currentState!.validate()) {
                        ref
                            .read(onboardingNotifierProvider.notifier)
                            .updateDisplayName(_displayNameCtrl.text.trim());
                        ref
                            .read(onboardingNotifierProvider.notifier)
                            .nextStep();
                        _goToPage(1);
                      }
                    },
                  ),
                  _Step2CompanyInfo(
                    formKey: _step2Key,
                    companyNameCtrl: _companyNameCtrl,
                    companyEmailCtrl: _companyEmailCtrl,
                    companyPhoneCtrl: _companyPhoneCtrl,
                    companyAddressCtrl: _companyAddressCtrl,
                    onBack: () {
                      ref
                          .read(onboardingNotifierProvider.notifier)
                          .previousStep();
                      _goToPage(0);
                    },
                    onNext: () {
                      if (_step2Key.currentState!.validate()) {
                        final notifier =
                            ref.read(onboardingNotifierProvider.notifier);
                        notifier
                            .updateCompanyName(_companyNameCtrl.text.trim());
                        notifier
                            .updateCompanyEmail(_companyEmailCtrl.text.trim());
                        notifier
                            .updateCompanyPhone(_companyPhoneCtrl.text.trim());
                        notifier.updateCompanyAddress(
                            _companyAddressCtrl.text.trim());
                        notifier.nextStep();
                        _goToPage(2);
                      }
                    },
                  ),
                  _Step3Branding(
                    formState: formState,
                    onPickLogo: _pickLogo,
                    onRemoveLogo: () => ref
                        .read(onboardingNotifierProvider.notifier)
                        .updateLogoFile(null),
                    onBack: () {
                      ref
                          .read(onboardingNotifierProvider.notifier)
                          .previousStep();
                      _goToPage(1);
                    },
                    onSubmit: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress bar
// ─────────────────────────────────────────────────────────────────────────────

class _StepProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepProgressBar({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final active = i <= currentStep;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            margin: EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 – Personal Info
// ─────────────────────────────────────────────────────────────────────────────

class _Step1PersonalInfo extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController displayNameCtrl;
  final VoidCallback onNext;

  const _Step1PersonalInfo({
    required this.formKey,
    required this.displayNameCtrl,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome aboard!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Let's start with your name so we can personalise your experience.",
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
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
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        )
                      ],
              ),
              child: TextFormField(
                controller: displayNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Your Full Name',
                  hintText: 'e.g. Jane Smith',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                onPressed: onNext,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text(
                  'Continue',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 – Company Info
// ─────────────────────────────────────────────────────────────────────────────

class _Step2CompanyInfo extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController companyNameCtrl;
  final TextEditingController companyEmailCtrl;
  final TextEditingController companyPhoneCtrl;
  final TextEditingController companyAddressCtrl;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _Step2CompanyInfo({
    required this.formKey,
    required this.companyNameCtrl,
    required this.companyEmailCtrl,
    required this.companyPhoneCtrl,
    required this.companyAddressCtrl,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set up your company',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This information will appear on your quotes and invoices.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
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
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        )
                      ],
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: companyNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Company Name *',
                      hintText: 'e.g. Smith Electrical Ltd.',
                      prefixIcon: const Icon(Icons.business_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'Company name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: companyEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Company Contact Email *',
                      hintText: 'contact@yourcompany.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || !v.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: companyPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Company Phone (optional)',
                      hintText: '+44 7700 900000',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: companyAddressCtrl,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Company Address (optional)',
                      hintText: '123 High Street, London, EC1A 1BB',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white24
                            : Colors.black.withValues(alpha: 0.12),
                      ),
                    ),
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: onNext,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text(
                        'Continue',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 – Branding & Submit
// ─────────────────────────────────────────────────────────────────────────────

class _Step3Branding extends StatelessWidget {
  final OnboardingFormState formState;
  final VoidCallback onPickLogo;
  final VoidCallback onRemoveLogo;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const _Step3Branding({
    required this.formState,
    required this.onPickLogo,
    required this.onRemoveLogo,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoFile = formState.logoFile;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add your logo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your logo will appear on quotes and invoices. Optional — you can add it later in Settings.',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Logo picker
          Center(
            child: GestureDetector(
              onTap: onPickLogo,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: logoFile != null
                        ? const Color(0xFFFF6B00)
                        : (isDark ? Colors.white24 : Colors.black12),
                    width: 2,
                  ),
                ),
                child: logoFile != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(logoFile, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: onRemoveLogo,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colorScheme.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close,
                                    size: 14, color: colorScheme.onError),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 40, color: colorScheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to add logo',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          if (logoFile == null) ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: onSubmit,
                child: Text(
                  'Skip, I\'ll add it later',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Summary',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 12),
                _SummaryRow(
                  icon: Icons.person_outline,
                  label: 'Name',
                  value: formState.displayName,
                ),
                _SummaryRow(
                  icon: Icons.business_outlined,
                  label: 'Company',
                  value: formState.companyName,
                ),
                _SummaryRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: formState.companyEmail,
                ),
                if (formState.companyPhone.isNotEmpty)
                  _SummaryRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: formState.companyPhone,
                  ),
                if (formState.companyAddress.isNotEmpty)
                  _SummaryRow(
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: formState.companyAddress,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Error message
          if (formState.errorMessage != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: colorScheme.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: colorScheme.error, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      formState.errorMessage!,
                      style:
                          TextStyle(color: colorScheme.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white24
                          : Colors.black.withValues(alpha: 0.12),
                    ),
                  ),
                  onPressed: formState.isSubmitting ? null : onBack,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: formState.isSubmitting ? null : onSubmit,
                    icon: formState.isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(
                      formState.isSubmitting ? 'Setting up...' : 'Complete Setup',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
