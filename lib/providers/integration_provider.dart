import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/integration_service.dart';

final integrationServiceProvider = Provider<IntegrationService>((ref) {
  return IntegrationService();
});
