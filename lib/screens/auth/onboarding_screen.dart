import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Quote On The Go',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Progress indicator
                  _StepProgressBar(
                    currentStep: formState.currentStep,
                    totalSteps: 3,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Step ${formState.currentStep + 1} of 3',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // ── Pages ────────────────────────────────────────────────────────
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
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(totalSteps, (i) {
        final active = i <= currentStep;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            margin: EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: active
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Welcome aboard!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Let's start with your name so we can personalise your experience.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: displayNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Your Full Name',
                hintText: 'e.g. Jane Smith',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Set up your company',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "This information will appear on your quotes and invoices.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: companyNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Company Name *',
                hintText: 'e.g. Smith Electrical Ltd.',
                prefixIcon: const Icon(Icons.business_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 2) {
                  return 'Company name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: companyEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Company Contact Email *',
                hintText: 'contact@yourcompany.com',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) {
                if (v == null || !v.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: companyPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Company Phone (optional)',
                hintText: '+44 7700 900000',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: companyAddressCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Company Address (optional)',
                hintText: '123 High Street, London, EC1A 1BB',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: onNext,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Continue'),
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
    final logoFile = formState.logoFile;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Add your logo',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your logo will appear on quotes and invoices. This is optional — you can add it later in Settings.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),

          // Logo picker
          Center(
            child: GestureDetector(
              onTap: onPickLogo,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: logoFile != null
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    width: 2,
                  ),
                ),
                child: logoFile != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              logoFile,
                              fit: BoxFit.cover,
                            ),
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
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: colorScheme.onError,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 40,
                            color: colorScheme.onSurfaceVariant,
                          ),
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
          const SizedBox(height: 8),

          // Skip logo hint
          if (logoFile == null)
            Center(
              child: TextButton(
                onPressed: onSubmit,
                child: Text(
                  'Skip, I\'ll add it later',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Summary',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
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
          if (formState.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      formState.errorMessage!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              OutlinedButton.icon(
                onPressed: formState.isSubmitting ? null : onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: formState.isSubmitting ? null : onSubmit,
                    icon: formState.isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      formState.isSubmitting
                          ? 'Setting up...'
                          : 'Complete Setup',
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
