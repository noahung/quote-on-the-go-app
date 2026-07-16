import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/models.dart';
import '../services/ai_service.dart';
import 'auth_provider.dart';

part 'ai_provider.g.dart';

// AI Service Provider
final aiServiceProvider = Provider<AIService>((ref) => AIService());

// Is Premium Provider - derived from company tier
@Riverpod(keepAlive: true)
bool isPremium(IsPremiumRef ref) {
  final company = ref.watch(companyProvider);
  final tier = company?.tier;
  return tier == 'premium' || tier == 'individual' || tier == 'organisation';
}

// AI Generation State
@immutable
class AIGenerationState {
  final bool isLoading;
  final List<LineItem>? generatedItems;
  final String? error;

  const AIGenerationState({
    this.isLoading = false,
    this.generatedItems,
    this.error,
  });

  AIGenerationState copyWith({
    bool? isLoading,
    List<LineItem>? generatedItems,
    String? error,
  }) {
    return AIGenerationState(
      isLoading: isLoading ?? this.isLoading,
      generatedItems: generatedItems ?? this.generatedItems,
      error: error ?? this.error,
    );
  }
}

// AI Generation State Notifier
class AIGenerationNotifier extends StateNotifier<AIGenerationState> {
  final Ref _ref;

  AIGenerationNotifier(this._ref) : super(const AIGenerationState());

  Future<void> generateItems({
    required String prompt,
    required String companyId,
  }) async {
    // Don't allow multiple simultaneous requests
    if (state.isLoading) return;

    state = const AIGenerationState(isLoading: true);

    try {
      final aiService = _ref.read(aiServiceProvider);
      final items = await aiService.generateLineItems(
        prompt: prompt,
        companyId: companyId,
      );

      state = AIGenerationState(
        isLoading: false,
        generatedItems: items,
      );
    } catch (e) {
      final errorMessage = e is Exception
          ? e.toString().replaceAll('Exception: ', '')
          : 'Failed to generate items';

      state = AIGenerationState(
        isLoading: false,
        error: errorMessage,
      );
    }
  }

  void clear() {
    state = const AIGenerationState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// AI Generation State Provider
final aiGenerationStateProvider =
    StateNotifierProvider<AIGenerationNotifier, AIGenerationState>((ref) {
  return AIGenerationNotifier(ref);
});
