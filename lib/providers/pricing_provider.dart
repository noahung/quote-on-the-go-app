import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/pricing_service.dart';

final pricingServiceProvider = Provider<PricingService>((ref) {
  return PricingService();
});

final pricingSuggestionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, serviceId) {
  final service = ref.watch(pricingServiceProvider);
  return service.generatePricingSuggestions(serviceId: serviceId);
});

final serviceBundlesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(pricingServiceProvider);
  return service.generateServiceBundles();
});

final discountRecommendationProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, quotationId) {
  final service = ref.watch(pricingServiceProvider);
  return service.generateDiscountRecommendation(quotationId: quotationId);
});
