import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workflow.dart';
import '../models/workflow_execution.dart';

class WorkflowExecutionRepository {
  final FirebaseFirestore _firestore;

  WorkflowExecutionRepository(this._firestore);

  Stream<List<WorkflowExecution>> watchExecutions(String companyId) {
    return _firestore
        .collection('workflow_executions')
        .where('companyId', isEqualTo: companyId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkflowExecution.fromFirestore(doc))
            .toList());
  }

  Stream<List<WorkflowExecution>> watchExecutionsForTemplate(
    String companyId,
    String workflowTemplateId,
  ) {
    return _firestore
        .collection('workflow_executions')
        .where('companyId', isEqualTo: companyId)
        .where('workflowTemplateId', isEqualTo: workflowTemplateId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkflowExecution.fromFirestore(doc))
            .toList());
  }

  Future<WorkflowExecution?> getExecution(String executionId) async {
    final doc = await _firestore.collection('workflow_executions').doc(executionId).get();
    if (!doc.exists) return null;
    return WorkflowExecution.fromFirestore(doc);
  }

  Future<String> startExecution({
    required String templateId,
    required String targetDocumentId,
    required String targetType,
    required String companyId,
    String? workflowName,
    String? targetDocumentNumber,
    String? targetCustomerName,
    required List<WorkflowStep> steps,
  }) async {
    final now = DateTime.now().toUtc();
    final firstStep = steps.isNotEmpty ? steps.first : null;
    final currentStepId = firstStep != null ? 'step_${firstStep.order}' : '';
    final waitDays = firstStep?.waitDays ?? 0;
    final nextExecutionAt = now.add(Duration(days: waitDays));

    final docRef = _firestore.collection('workflow_executions').doc();
    final execution = WorkflowExecution(
      id: docRef.id,
      workflowTemplateId: templateId,
      workflowName: workflowName,
      targetDocumentId: targetDocumentId,
      targetType: targetType,
      targetDocumentNumber: targetDocumentNumber,
      targetCustomerName: targetCustomerName,
      currentStepId: currentStepId,
      status: 'active',
      startedAt: now,
      nextExecutionAt: nextExecutionAt,
      executionLog: [],
      companyId: companyId,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(execution.toJson());
    return docRef.id;
  }

  Future<void> stopExecution(String executionId) async {
    await _firestore.collection('workflow_executions').doc(executionId).update({
      'status': 'stopped',
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteExecution(String executionId) async {
    await _firestore.collection('workflow_executions').doc(executionId).delete();
  }
}
