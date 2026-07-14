import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../components/mesh_background.dart';
import '../../components/animated_celebration_icon.dart';
import '../../models/feedback_type.dart';
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
  final _step3Key = GlobalKey<FormState>();

  // Controllers
  final _displayNameCtrl = TextEditingController();
  final _userPhoneCtrl = TextEditingController();
  final _userJobTitleCtrl = TextEditingController();

  final _companyNameCtrl = TextEditingController();
  final _companyEmailCtrl = TextEditingController();
  final _companyPhoneCtrl = TextEditingController();
  final _companyWebsiteCtrl = TextEditingController();
  final _companyAddressCtrl = TextEditingController();
  final _referralCodeCtrl = TextEditingController();

  final _taxRateCtrl = TextEditingController(text: '20.0');
  final _hourlyRateCtrl = TextEditingController(text: '0.0');
  final _bankNameCtrl = TextEditingController();
  final _bankAccountNameCtrl = TextEditingController();
  final _bankAccountNumberCtrl = TextEditingController();
  final _bankSortCodeCtrl = TextEditingController();

  // Branding Lists
  final List<Map<String, dynamic>> _accentColors = [
    {'name': 'Default Orange', 'color': const Color(0xFFFF6B00), 'hex': '#FF6B00'},
    {'name': 'Sleek Charcoal', 'color': const Color(0xFF374151), 'hex': '#374151'},
    {'name': 'Royal Indigo', 'color': const Color(0xFF4F46E5), 'hex': '#4F46E5'},
    {'name': 'Ocean Blue', 'color': const Color(0xFF2563EB), 'hex': '#2563EB'},
    {'name': 'Clean Teal', 'color': const Color(0xFF0D9488), 'hex': '#0D9488'},
    {'name': 'Emerald Pro', 'color': const Color(0xFF059669), 'hex': '#059669'},
    {'name': 'Amber Gold', 'color': const Color(0xFFD97706), 'hex': '#D97706'},
    {'name': 'Rose Crimson', 'color': const Color(0xFFE11D48), 'hex': '#E11D48'},
  ];

  final List<Map<String, String>> _templates = [
    {'id': 'modern-orange', 'name': 'Modern Orange'},
    {'id': 'clean-teal', 'name': 'Clean Teal'},
    {'id': 'classic-minimal', 'name': 'Classic Minimal'},
    {'id': 'sleek-charcoal', 'name': 'Sleek Charcoal'},
    {'id': 'emerald-pro', 'name': 'Emerald Pro'},
    {'id': 'royal-elegant', 'name': 'Royal Elegant'},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final user = ref.read(currentUserProvider);
      if (user != null) {
        _displayNameCtrl.text = user.displayName ?? '';
        _companyEmailCtrl.text = user.email ?? '';
        
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
    _userPhoneCtrl.dispose();
    _userJobTitleCtrl.dispose();
    _companyNameCtrl.dispose();
    _companyEmailCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _companyWebsiteCtrl.dispose();
    _companyAddressCtrl.dispose();
    _referralCodeCtrl.dispose();
    _taxRateCtrl.dispose();
    _hourlyRateCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountNameCtrl.dispose();
    _bankAccountNumberCtrl.dispose();
    _bankSortCodeCtrl.dispose();
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
    // Premium gating (parity with web): new sign-ups are on the free tier
    // unless a referral code grants a premium trial. Logo upload is a
    // premium feature.
    final hasReferral =
        ref.read(onboardingNotifierProvider).referralCode.trim().isNotEmpty;
    if (!hasReferral) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Logo upload is available on premium plans. You can upgrade and add your logo later in Settings.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

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

  Future<void> _skipOnboarding() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final notifier = ref.read(onboardingNotifierProvider.notifier);
    notifier.updateDisplayName(_displayNameCtrl.text.trim());
    notifier.updateCompanyName(_companyNameCtrl.text.trim());
    notifier.updateCompanyEmail(_companyEmailCtrl.text.trim());
    notifier.updateCompanyPhone(_companyPhoneCtrl.text.trim());
    notifier.updateCompanyWebsite(_companyWebsiteCtrl.text.trim());
    notifier.updateCompanyAddress(_companyAddressCtrl.text.trim());
    notifier.updateReferralCode(_referralCodeCtrl.text.trim());

    final taxVal = double.tryParse(_taxRateCtrl.text.trim()) ?? 20.0;
    final hourlyVal = double.tryParse(_hourlyRateCtrl.text.trim()) ?? 0.0;
    notifier.updateDefaultTaxRate(taxVal);
    notifier.updateDefaultHourlyRate(hourlyVal);
    notifier.updateBankDetails(
      bankName: _bankNameCtrl.text.trim(),
      bankAccountName: _bankAccountNameCtrl.text.trim(),
      bankAccountNumber: _bankAccountNumberCtrl.text.trim(),
      bankSortCode: _bankSortCodeCtrl.text.trim(),
    );

    final success = await notifier.submit(user.uid);
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
                          if (formState.currentStep < 4) ...[
                            TextButton(
                              onPressed: _skipOnboarding,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: const Text(
                                'Skip for now',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'Step ${formState.currentStep + 1} of 5',
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
                        totalSteps: 5,
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
                    phoneCtrl: _userPhoneCtrl,
                    jobTitleCtrl: _userJobTitleCtrl,
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
                    companyWebsiteCtrl: _companyWebsiteCtrl,
                    companyAddressCtrl: _companyAddressCtrl,
                    referralCodeCtrl: _referralCodeCtrl,
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
                        notifier.updateCompanyWebsite(
                            _companyWebsiteCtrl.text.trim());
                        notifier.updateCompanyAddress(
                            _companyAddressCtrl.text.trim());
                        notifier.updateReferralCode(
                            _referralCodeCtrl.text.trim());
                        notifier.nextStep();
                        _goToPage(2);
                      }
                    },
                  ),
                  _Step3RatesAndBank(
                    formKey: _step3Key,
                    taxRateCtrl: _taxRateCtrl,
                    hourlyRateCtrl: _hourlyRateCtrl,
                    bankNameCtrl: _bankNameCtrl,
                    accountNameCtrl: _bankAccountNameCtrl,
                    accountNumberCtrl: _bankAccountNumberCtrl,
                    sortCodeCtrl: _bankSortCodeCtrl,
                    onBack: () {
                      ref
                          .read(onboardingNotifierProvider.notifier)
                          .previousStep();
                      _goToPage(1);
                    },
                    onNext: () {
                      if (_step3Key.currentState!.validate()) {
                        final notifier =
                            ref.read(onboardingNotifierProvider.notifier);
                        final taxVal = double.tryParse(_taxRateCtrl.text.trim()) ?? 20.0;
                        final hourlyVal = double.tryParse(_hourlyRateCtrl.text.trim()) ?? 0.0;
                        notifier.updateDefaultTaxRate(taxVal);
                        notifier.updateDefaultHourlyRate(hourlyVal);
                        notifier.updateBankDetails(
                          bankName: _bankNameCtrl.text.trim(),
                          bankAccountName: _bankAccountNameCtrl.text.trim(),
                          bankAccountNumber: _bankAccountNumberCtrl.text.trim(),
                          bankSortCode: _bankSortCodeCtrl.text.trim(),
                        );
                        notifier.nextStep();
                        _goToPage(3);
                      }
                    },
                  ),
                  _Step4Branding(
                    formState: formState,
                    onPickLogo: _pickLogo,
                    onRemoveLogo: () => ref
                        .read(onboardingNotifierProvider.notifier)
                        .updateLogoFile(null),
                    accentColors: _accentColors,
                    templates: _templates,
                    onBack: () {
                      ref
                          .read(onboardingNotifierProvider.notifier)
                          .previousStep();
                      _goToPage(2);
                    },
                    onNext: () {
                      ref
                          .read(onboardingNotifierProvider.notifier)
                          .nextStep();
                      _goToPage(4);
                    },
                  ),
                  _Step5Success(
                    formState: formState,
                    onBack: () {
                      ref
                          .read(onboardingNotifierProvider.notifier)
                          .previousStep();
                      _goToPage(3);
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
  final TextEditingController phoneCtrl;
  final TextEditingController jobTitleCtrl;
  final VoidCallback onNext;

  const _Step1PersonalInfo({
    required this.formKey,
    required this.displayNameCtrl,
    required this.phoneCtrl,
    required this.jobTitleCtrl,
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
              "Let's start with your details so we can personalise your experience.",
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
                    controller: displayNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Your Full Name *',
                      hintText: 'e.g. Jane Smith',
                      prefixIcon: const Icon(LucideIcons.user),
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
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number (optional)',
                      hintText: 'e.g. +44 7700 900000',
                      prefixIcon: const Icon(LucideIcons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: jobTitleCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Job Title / Role (optional)',
                      hintText: 'e.g. Electrician, Carpenter',
                      prefixIcon: const Icon(LucideIcons.briefcase),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
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
                icon: const Icon(LucideIcons.arrowRight, size: 18),
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
  final TextEditingController companyWebsiteCtrl;
  final TextEditingController companyAddressCtrl;
  final TextEditingController referralCodeCtrl;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _Step2CompanyInfo({
    required this.formKey,
    required this.companyNameCtrl,
    required this.companyEmailCtrl,
    required this.companyPhoneCtrl,
    required this.companyWebsiteCtrl,
    required this.companyAddressCtrl,
    required this.referralCodeCtrl,
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
                      prefixIcon: const Icon(LucideIcons.building2),
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
                      prefixIcon: const Icon(LucideIcons.mail),
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
                      hintText: 'e.g. +44 7700 900000',
                      prefixIcon: const Icon(LucideIcons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: companyWebsiteCtrl,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'Company Website (optional)',
                      hintText: 'e.g. www.smithltd.co.uk',
                      prefixIcon: const Icon(LucideIcons.globe),
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
                      prefixIcon: const Icon(LucideIcons.mapPin),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: referralCodeCtrl,
                    decoration: InputDecoration(
                      labelText: 'Referral Code (optional)',
                      hintText: 'Have a code? Get a 7-day Premium trial',
                      prefixIcon: const Icon(LucideIcons.gift),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                    icon: const Icon(LucideIcons.arrowLeft, size: 18),
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
                      icon: const Icon(LucideIcons.arrowRight, size: 18),
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
// Step 3 – Rates and Bank Details
// ─────────────────────────────────────────────────────────────────────────────

class _Step3RatesAndBank extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController taxRateCtrl;
  final TextEditingController hourlyRateCtrl;
  final TextEditingController bankNameCtrl;
  final TextEditingController accountNameCtrl;
  final TextEditingController accountNumberCtrl;
  final TextEditingController sortCodeCtrl;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _Step3RatesAndBank({
    required this.formKey,
    required this.taxRateCtrl,
    required this.hourlyRateCtrl,
    required this.bankNameCtrl,
    required this.accountNameCtrl,
    required this.accountNumberCtrl,
    required this.sortCodeCtrl,
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
              'Rates & Bank details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set your default billing rates and bank account for client invoice payments.',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Billing Defaults',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFFFF6B00)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: taxRateCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                          decoration: InputDecoration(
                            labelText: 'Default Tax (%)',
                            hintText: 'e.g. 20.0',
                            prefixIcon: const Icon(LucideIcons.percent),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: hourlyRateCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                          decoration: InputDecoration(
                            labelText: 'Hourly Rate (£)',
                            hintText: 'e.g. 45.00',
                            prefixIcon: const Icon(Icons.currency_pound),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 14),
                  const Text(
                    'Bank Account (For Invoice Payments)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFFFF6B00)),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: bankNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Bank Name',
                      hintText: 'e.g. Barclays, HSBC',
                      prefixIcon: const Icon(LucideIcons.landmark),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: accountNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Account Name',
                      hintText: 'e.g. Smith Electrical Ltd',
                      prefixIcon: const Icon(LucideIcons.creditCard),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: sortCodeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Sort Code',
                            hintText: 'e.g. 20-45-78',
                            prefixIcon: const Icon(LucideIcons.hash),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: accountNumberCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Account Number',
                            hintText: 'e.g. 12345678',
                            prefixIcon: const Icon(LucideIcons.hash),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                    icon: const Icon(LucideIcons.arrowLeft, size: 18),
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
                      icon: const Icon(LucideIcons.arrowRight, size: 18),
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
// Step 4 – Branding & Live Preview
// ─────────────────────────────────────────────────────────────────────────────

class _Step4Branding extends ConsumerWidget {
  final OnboardingFormState formState;
  final VoidCallback onPickLogo;
  final VoidCallback onRemoveLogo;
  final List<Map<String, dynamic>> accentColors;
  final List<Map<String, String>> templates;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _Step4Branding({
    required this.formState,
    required this.onPickLogo,
    required this.onRemoveLogo,
    required this.accentColors,
    required this.templates,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoFile = formState.logoFile;

    // Resolve primary color of current selection
    Color activeThemeColor = const Color(0xFFFF6B00);
    if (formState.pdfThemeColor.isNotEmpty) {
      try {
        final hexStr = formState.pdfThemeColor.replaceAll('#', '');
        activeThemeColor = Color(int.parse('FF$hexStr', radix: 16));
      } catch (_) {}
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Branding & Style',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your PDF template and accent colour to personalise your layout.',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Pick PDF Template layout
          const Text(
            'PDF Template Layout',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final item = templates[index];
                final isSelected = formState.pdfTemplate == item['id'];

                return GestureDetector(
                  onTap: () {
                    ref.read(onboardingNotifierProvider.notifier)
                       .updatePdfTemplate(item['id'] as String);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? activeThemeColor.withValues(alpha: 0.15) 
                          : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: isSelected ? activeThemeColor : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      item['name'] as String,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                        color: isSelected ? activeThemeColor : colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Pick Accent Color
          const Text(
            'Accent Colour',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: accentColors.length,
              itemBuilder: (context, index) {
                final item = accentColors[index];
                final isSelected = formState.pdfThemeColor == item['hex'] || 
                                   (formState.pdfThemeColor.isEmpty && index == 0);
                return GestureDetector(
                  onTap: () {
                    ref.read(onboardingNotifierProvider.notifier)
                       .updatePdfThemeColor(item['hex'] as String);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: item['color'] as Color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: isSelected
                        ? const Icon(LucideIcons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Pick Logo
          const Text(
            'Company Logo (optional)',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Center(
            child: GestureDetector(
              onTap: onPickLogo,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: logoFile != null
                        ? activeThemeColor
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
                                child: Icon(LucideIcons.x,
                                    size: 14, color: colorScheme.onError),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.imagePlus,
                              size: 32, color: colorScheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text(
                            'Add logo',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Live document preview
          const Text(
            'Live Document Preview',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 10),
          _DocumentPreviewCard(
            template: formState.pdfTemplate,
            themeColorHex: formState.pdfThemeColor,
            companyName: formState.companyName,
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
                  icon: const Icon(LucideIcons.arrowLeft, size: 18),
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
                    icon: const Icon(LucideIcons.arrowRight, size: 18),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 5 – Success & Summary
// ─────────────────────────────────────────────────────────────────────────────

class _Step5Success extends StatelessWidget {
  final OnboardingFormState formState;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const _Step5Success({
    required this.formState,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          const AnimatedCelebrationIcon(
            type: CelebrationType.sparkle,
            size: 80,
          ),
          const SizedBox(height: 24),
          const Text(
            "You're all set!",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Your workspace has been successfully personalised and is ready to use.",
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Summary Card
          Container(
            width: double.infinity,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Workspace Summary',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFFFF6B00)),
                ),
                const SizedBox(height: 14),
                _SummaryRow(
                  icon: LucideIcons.user,
                  label: 'Owner',
                  value: formState.displayName.isEmpty ? 'Trade Specialist' : formState.displayName,
                ),
                _SummaryRow(
                  icon: LucideIcons.building2,
                  label: 'Company',
                  value: formState.companyName.isEmpty ? 'My Company' : formState.companyName,
                ),
                if (formState.companyWebsite.isNotEmpty)
                  _SummaryRow(
                    icon: LucideIcons.globe,
                    label: 'Website',
                    value: formState.companyWebsite,
                  ),
                _SummaryRow(
                  icon: LucideIcons.percent,
                  label: 'Default Tax',
                  value: '${formState.defaultTaxRate}%',
                ),
                if (formState.bankName.isNotEmpty)
                  _SummaryRow(
                    icon: LucideIcons.landmark,
                    label: 'Bank Name',
                    value: formState.bankName,
                  ),
                _SummaryRow(
                  icon: LucideIcons.palette,
                  label: 'Branding Theme',
                  value: formState.pdfTemplate.replaceAll('-', ' '),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Error banner
          if (formState.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: colorScheme.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.alertCircle,
                      color: colorScheme.error, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      formState.errorMessage!,
                      style: TextStyle(color: colorScheme.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
                  icon: const Icon(LucideIcons.arrowLeft, size: 18),
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
                        : const Icon(LucideIcons.check, size: 18),
                    label: Text(
                      formState.isSubmitting ? 'Setting up...' : 'Complete Setup & Launch Dashboard',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
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

// ─────────────────────────────────────────────────────────────────────────────
// Summary Row
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Mock Table Row helper for Preview
// ─────────────────────────────────────────────────────────────────────────────

class _MockRow extends StatelessWidget {
  final String desc;
  final String qty;
  final String price;

  const _MockRow({
    required this.desc,
    required this.qty,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Text(
            desc,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(
          width: 20,
          child: Text(
            qty,
            style: const TextStyle(fontSize: 8, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            price,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Preview Card Mockup
// ─────────────────────────────────────────────────────────────────────────────

class _DocumentPreviewCard extends StatelessWidget {
  final String template;
  final String themeColorHex;
  final String companyName;

  const _DocumentPreviewCard({
    required this.template,
    required this.themeColorHex,
    required this.companyName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Find active color
    Color accentColor = const Color(0xFFFF6B00);
    if (themeColorHex.isNotEmpty) {
      try {
        final hexStr = themeColorHex.replaceAll('#', '');
        accentColor = Color(int.parse('FF$hexStr', radix: 16));
      } catch (_) {}
    }

    final displayCompanyName = companyName.trim().isEmpty ? "Your Company" : companyName;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F29) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner layout based on template type
          if (template == 'modern-orange' || template == 'clean-teal' || template == 'emerald-pro')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(19),
                  topRight: Radius.circular(19),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    displayCompanyName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'QUOTATION',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            )
          else if (template == 'royal-elegant')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: accentColor, width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    displayCompanyName,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'ESTIMATE / QUOTE',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            )
          else // classic-minimal, sleek-charcoal, or fallback
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayCompanyName,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        height: 2,
                        width: 40,
                        color: accentColor,
                      ),
                    ],
                  ),
                  Text(
                    'QUOTE',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

          // Invoice Details Mockup Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info block
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quote To:', style: TextStyle(fontSize: 8, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(
                          'Acme Corporation',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Quote No: #QT-0001', style: TextStyle(fontSize: 8, color: Colors.grey)),
                        Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Lines divider
                Container(
                  height: 1,
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                ),
                const SizedBox(height: 8),

                // Table rows mockup
                const _MockRow(desc: 'Electrical Maintenance & Rewire', qty: '1', price: '£120.00'),
                const SizedBox(height: 4),
                const _MockRow(desc: 'Premium Consumer Unit Replacement', qty: '1', price: '£350.00'),
                
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                ),
                const SizedBox(height: 8),

                // Mock Totals
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Subtotal: £470.00',
                          style: TextStyle(fontSize: 8, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Total Due: £564.00',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
