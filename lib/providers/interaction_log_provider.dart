import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/interaction_log.dart';
import 'auth_provider.dart';

class InteractionLogRepository {
  final FirebaseFirestore _firestore;
  InteractionLogRepository(this._firestore);

  Stream<List<InteractionLog>> streamForCustomer(
      String companyId, String customerId) {
    return _firestore
        .collection('interaction_logs')
        .where('companyId', isEqualTo: companyId)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => InteractionLog.fromFirestore(d)).toList();
      list.sort((a, b) =>
          (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));
      return list;
    });
  }

  Future<void> addLog({
    required String companyId,
    required String customerId,
    required String type,
    required String title,
    String? description,
    required String createdBy,
  }) async {
    await _firestore.collection('interaction_logs').add({
      'companyId': companyId,
      'customerId': customerId,
      'type': type,
      'title': title,
      if (description != null && description.isNotEmpty)
        'description': description,
      'createdBy': createdBy,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteLog(String logId) async {
    await _firestore.collection('interaction_logs').doc(logId).delete();
  }
}

final interactionLogRepositoryProvider =
    Provider<InteractionLogRepository>((ref) {
  return InteractionLogRepository(FirebaseFirestore.instance);
});

/// Stream all interaction logs for a specific customer.
final customerInteractionLogsProvider =
    StreamProvider.family<List<InteractionLog>, String>((ref, customerId) {
  final companyId = ref.watch(companyIdProvider);
  if (companyId == null) return const Stream.empty();
  return ref
      .read(interactionLogRepositoryProvider)
      .streamForCustomer(companyId, customerId);
});
