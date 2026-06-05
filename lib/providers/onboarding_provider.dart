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

  void updateLogoFile(File? file) => state = file == null
      ? state.copyWith(clearLogo: true)
      : state.copyWith(logoFile: file);

  void nextStep() {
    if (state.currentStep < 2) {
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
      await _repository.completeOnboarding(
        uid: uid,
        displayName: state.displayName,
        email: state.companyEmail,
        companyName: state.companyName,
        companyEmail: state.companyEmail,
        companyPhone: state.companyPhone.isEmpty ? null : state.companyPhone,
        companyAddress:
            state.companyAddress.isEmpty ? null : state.companyAddress,
        logoFile: state.logoFile,
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
