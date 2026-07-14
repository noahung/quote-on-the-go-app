import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/onboarding_repository.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(),
);

// ---------------------------------------------------------------------------
// Form state held across the multi-step wizard
// ---------------------------------------------------------------------------

class OnboardingFormState {
  final int currentStep;
  final String displayName;
  final String companyName;
  final String companyEmail;
  final String companyPhone;
  final String companyAddress;
  final String companyWebsite;
  final double defaultTaxRate;
  final double defaultHourlyRate;
  final String bankName;
  final String bankAccountName;
  final String bankAccountNumber;
  final String bankSortCode;
  final String pdfTemplate;
  final String pdfThemeColor;
  final String referralCode;
  final File? logoFile;
  final bool isSubmitting;
  final String? errorMessage;

  const OnboardingFormState({
    this.currentStep = 0,
    this.displayName = '',
    this.companyName = '',
    this.companyEmail = '',
    this.companyPhone = '',
    this.companyAddress = '',
    this.companyWebsite = '',
    this.defaultTaxRate = 20.0,
    this.defaultHourlyRate = 0.0,
    this.bankName = '',
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    this.bankSortCode = '',
    this.pdfTemplate = 'modern-orange',
    this.pdfThemeColor = '',
    this.referralCode = '',
    this.logoFile,
    this.isSubmitting = false,
    this.errorMessage,
  });

  OnboardingFormState copyWith({
    int? currentStep,
    String? displayName,
    String? companyName,
    String? companyEmail,
    String? companyPhone,
    String? companyAddress,
    String? companyWebsite,
    double? defaultTaxRate,
    double? defaultHourlyRate,
    String? bankName,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankSortCode,
    String? pdfTemplate,
    String? pdfThemeColor,
    String? referralCode,
    File? logoFile,
    bool clearLogo = false,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OnboardingFormState(
      currentStep: currentStep ?? this.currentStep,
      displayName: displayName ?? this.displayName,
      companyName: companyName ?? this.companyName,
      companyEmail: companyEmail ?? this.companyEmail,
      companyPhone: companyPhone ?? this.companyPhone,
      companyAddress: companyAddress ?? this.companyAddress,
      companyWebsite: companyWebsite ?? this.companyWebsite,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      defaultHourlyRate: defaultHourlyRate ?? this.defaultHourlyRate,
      bankName: bankName ?? this.bankName,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankSortCode: bankSortCode ?? this.bankSortCode,
      pdfTemplate: pdfTemplate ?? this.pdfTemplate,
      pdfThemeColor: pdfThemeColor ?? this.pdfThemeColor,
      referralCode: referralCode ?? this.referralCode,
      logoFile: clearLogo ? null : (logoFile ?? this.logoFile),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ---------------------------------------------------------------------------
// StateNotifier
// ---------------------------------------------------------------------------

class OnboardingNotifier extends StateNotifier<OnboardingFormState> {
  final OnboardingRepository _repository;

  OnboardingNotifier(this._repository) : super(const OnboardingFormState());

  void init({required String displayName, required String email}) {
    state = state.copyWith(
      displayName: displayName,
      companyEmail: email,
      clearError: true,
    );
  }

  void updateDisplayName(String value) =>
      state = state.copyWith(displayName: value);

  void updateCompanyName(String value) =>
      state = state.copyWith(companyName: value);

  void updateCompanyEmail(String value) =>
      state = state.copyWith(companyEmail: value);

  void updateCompanyPhone(String value) =>
      state = state.copyWith(companyPhone: value);

  void updateCompanyAddress(String value) =>
      state = state.copyWith(companyAddress: value);

  void updateCompanyWebsite(String value) =>
      state = state.copyWith(companyWebsite: value);

  void updateDefaultTaxRate(double value) =>
      state = state.copyWith(defaultTaxRate: value);

  void updateDefaultHourlyRate(double value) =>
      state = state.copyWith(defaultHourlyRate: value);

  void updateBankDetails({
    String? bankName,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankSortCode,
  }) {
    state = state.copyWith(
      bankName: bankName ?? state.bankName,
      bankAccountName: bankAccountName ?? state.bankAccountName,
      bankAccountNumber: bankAccountNumber ?? state.bankAccountNumber,
      bankSortCode: bankSortCode ?? state.bankSortCode,
    );
  }

  void updatePdfTemplate(String value) =>
      state = state.copyWith(pdfTemplate: value);

  void updatePdfThemeColor(String value) =>
      state = state.copyWith(pdfThemeColor: value);

  void updateReferralCode(String value) =>
      state = state.copyWith(referralCode: value);

  void updateLogoFile(File? file) => state = file == null
      ? state.copyWith(clearLogo: true)
      : state.copyWith(logoFile: file);

  void nextStep() {
    if (state.currentStep < 4) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  Future<bool> submit(String uid) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final name = state.displayName.trim().isEmpty 
          ? (state.companyEmail.split('@').first) 
          : state.displayName;
      final compName = state.companyName.trim().isEmpty 
          ? "$name's Company" 
          : state.companyName;

      await _repository.completeOnboarding(
        uid: uid,
        displayName: name,
        email: state.companyEmail,
        companyName: compName,
        companyEmail: state.companyEmail,
        companyPhone: state.companyPhone.isEmpty ? null : state.companyPhone,
        companyAddress:
            state.companyAddress.isEmpty ? null : state.companyAddress,
        companyWebsite:
            state.companyWebsite.isEmpty ? null : state.companyWebsite,
        defaultTaxRate: state.defaultTaxRate,
        defaultHourlyRate: state.defaultHourlyRate,
        bankName: state.bankName.isEmpty ? null : state.bankName,
        bankAccountName:
            state.bankAccountName.isEmpty ? null : state.bankAccountName,
        bankAccountNumber:
            state.bankAccountNumber.isEmpty ? null : state.bankAccountNumber,
        bankSortCode: state.bankSortCode.isEmpty ? null : state.bankSortCode,
        pdfTemplate: state.pdfTemplate,
        pdfThemeColor: state.pdfThemeColor,
        logoFile: state.logoFile,
        referralCode:
            state.referralCode.trim().isEmpty ? null : state.referralCode,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }
}

final onboardingNotifierProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingFormState>(
  (ref) => OnboardingNotifier(ref.watch(onboardingRepositoryProvider)),
);
