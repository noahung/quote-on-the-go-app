import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/workflow_execution.dart';
import '../repositories/workflow_execution_repository.dart';
import 'auth_provider.dart';
import 'quotation_provider.dart';
import 'invoice_provider.dart';

part 'workflow_execution_provider.g.dart';

final workflowExecutionRepositoryProvider = Provider<WorkflowExecutionRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return WorkflowExecutionRepository(firestore);
});

@riverpod
Stream<List<WorkflowExecution>> workflowExecutionsStream(WorkflowExecutionsStreamRef ref) {
  final companyId = ref.watch(companyIdProvider);
  final repository = ref.watch(workflowExecutionRepositoryProvider);
  if (companyId == null) return Stream.value([]);
  return repository.watchExecutions(companyId);
}

@riverpod
Stream<List<WorkflowExecution>> workflowExecutionsForTemplateStream(
  WorkflowExecutionsForTemplateStreamRef ref,
  String workflowTemplateId,
) {
  final companyId = ref.watch(companyIdProvider);
  final repository = ref.watch(workflowExecutionRepositoryProvider);
  if (companyId == null) return Stream.value([]);
  return repository.watchExecutionsForTemplate(companyId, workflowTemplateId);
}

@riverpod
List<WorkflowExecution> workflowExecutions(WorkflowExecutionsRef ref) {
  return ref.watch(workflowExecutionsStreamProvider).valueOrNull ?? [];
}

@riverpod
List<WorkflowExecution> workflowExecutionsForTemplate(
  WorkflowExecutionsForTemplateRef ref,
  String workflowTemplateId,
) {
  return ref.watch(workflowExecutionsForTemplateStreamProvider(workflowTemplateId)).valueOrNull ?? [];
}

/// Recent documents that can be used as workflow targets.
@riverpod
List<WorkflowTargetDocument> workflowTargetDocuments(WorkflowTargetDocumentsRef ref) {
  final quotations = ref.watch(quotationsProvider);
  final invoices = ref.watch(invoicesProvider);

  final targets = <WorkflowTargetDocument>[
    ...quotations.map((q) => WorkflowTargetDocument(
          id: q.id,
          type: 'quotation',
          number: q.quotationNumber,
          customerName: q.customerName,
          status: q.status,
          total: q.total,
        )),
    ...invoices.map((i) => WorkflowTargetDocument(
          id: i.id,
          type: 'invoice',
          number: i.invoiceNumber,
          customerName: i.customerName,
          status: i.status,
          total: i.total,
        )),
  ];

  targets.sort((a, b) => b.number.compareTo(a.number));
  return targets;
}

class WorkflowTargetDocument {
  final String id;
  final String type;
  final String number;
  final String customerName;
  final String status;
  final double total;

  const WorkflowTargetDocument({
    required this.id,
    required this.type,
    required this.number,
    required this.customerName,
    required this.status,
    required this.total,
  });
}
