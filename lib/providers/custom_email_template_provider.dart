import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/custom_email_template.dart';
import '../repositories/custom_email_template_repository.dart';
import 'auth_provider.dart';

final customEmailTemplateRepositoryProvider = Provider<CustomEmailTemplateRepository>((ref) {
  return CustomEmailTemplateRepository();
});

final customEmailTemplatesProvider = FutureProvider.family<List<CustomEmailTemplate>, String>((ref, docType) async {
  final companyId = ref.watch(companyIdProvider);
  if (companyId == null || companyId.isEmpty) return [];

  final repo = ref.watch(customEmailTemplateRepositoryProvider);
  return repo.getTemplates(companyId, docType: docType);
});
