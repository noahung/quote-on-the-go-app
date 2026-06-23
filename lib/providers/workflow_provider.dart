import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/workflow.dart';
import 'auth_provider.dart';
import 'quotation_provider.dart';

part 'workflow_provider.g.dart';

@riverpod
Stream<List<WorkflowTemplate>> workflowsStream(WorkflowsStreamRef ref) {
  final companyId = ref.watch(companyIdProvider);
  final firestore = ref.watch(firestoreProvider);
  if (companyId == null) return const Stream.empty();

  return firestore
      .collection('workflows')
      .where('companyId', isEqualTo: companyId)
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => WorkflowTemplate.fromFirestore(doc))
          .toList());
}

@riverpod
Stream<WorkflowTemplate?> workflowTemplateStream(WorkflowTemplateStreamRef ref, String templateId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('workflows')
      .doc(templateId)
      .snapshots()
      .map((doc) => doc.exists ? WorkflowTemplate.fromFirestore(doc) : null);
}

@riverpod
WorkflowTemplate? workflowTemplate(WorkflowTemplateRef ref, String templateId) {
  return ref.watch(workflowTemplateStreamProvider(templateId)).valueOrNull;
}

class WorkflowRepository {
  final FirebaseFirestore _firestore;

  WorkflowRepository(this._firestore);

  Future<void> createWorkflow(WorkflowTemplate workflow) async {
    await _firestore.collection('workflows').add({
      ...workflow.toJson()..remove('id'),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateWorkflow(WorkflowTemplate workflow) async {
    await _firestore.collection('workflows').doc(workflow.id).update({
      ...workflow.toJson()..remove('id'),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteWorkflow(String workflowId) async {
    await _firestore.collection('workflows').doc(workflowId).delete();
  }

  Future<void> toggleWorkflowStatus(String workflowId, bool isActive) async {
    await _firestore
        .collection('workflows')
        .doc(workflowId)
        .update({'isActive': isActive});
  }
}

final workflowRepositoryProvider = Provider<WorkflowRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return WorkflowRepository(firestore);
});
