import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/document_outbox.dart';
import 'auth_provider.dart';

final documentOutboxProvider = ChangeNotifierProvider<DocumentOutbox?>((ref) {
  final identity = ref.watch(userProfileProvider.select(
      (profile) => profile == null ? null : (profile.uid, profile.companyId)));
  if (identity == null || identity.$2.isEmpty) return null;
  return DocumentOutbox(userId: identity.$1, companyId: identity.$2);
});
