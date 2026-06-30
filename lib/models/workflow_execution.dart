import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'workflow_execution.freezed.dart';
part 'workflow_execution.g.dart';

@freezed
class ExecutionLogEntry with _$ExecutionLogEntry {
  const factory ExecutionLogEntry({
    required String stepId,
    String? stepName,
    required String status,
    required String action,
    String? details,
    String? error,
    @TimestampConverter() DateTime? executedAt,
  }) = _ExecutionLogEntry;

  factory ExecutionLogEntry.fromJson(Map<String, dynamic> json) =>
      _$ExecutionLogEntryFromJson(json);
}

@freezed
class WorkflowExecution with _$WorkflowExecution {
  const factory WorkflowExecution({
    required String id,
    required String workflowTemplateId,
    String? workflowName,
    required String targetDocumentId,
    required String targetType,
    String? targetDocumentNumber,
    String? targetCustomerName,
    String? currentStepId,
    @Default('active') String status,
    @Default(0) int retryCount,
    String? lastError,
    @TimestampConverter() DateTime? startedAt,
    @TimestampConverter() DateTime? completedAt,
    @TimestampConverter() DateTime? nextExecutionAt,
    @Default([]) List<ExecutionLogEntry> executionLog,
    required String companyId,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _WorkflowExecution;

  factory WorkflowExecution.fromJson(Map<String, dynamic> json) =>
      _$WorkflowExecutionFromJson(json);

  factory WorkflowExecution.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    _convertTimestamps(data);

    if (data['executionLog'] is List) {
      data['executionLog'] = (data['executionLog'] as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
    } else {
      data['executionLog'] = <Map<String, dynamic>>[];
    }

    return WorkflowExecution.fromJson({
      'workflowTemplateId': '',
      'targetDocumentId': '',
      'targetType': 'quotation',
      'companyId': '',
      ...data,
      'id': doc.id,
    });
  }

  static void _convertTimestamps(Map<String, dynamic> data) {
    for (final key in data.keys.toList()) {
      if (data[key] is Timestamp) {
        data[key] = (data[key] as Timestamp).toDate().toIso8601String();
      } else if (data[key] is Map<String, dynamic>) {
        _convertTimestamps(data[key] as Map<String, dynamic>);
      } else if (data[key] is List) {
        for (final item in data[key] as List) {
          if (item is Map<String, dynamic>) {
            _convertTimestamps(item);
          }
        }
      }
    }
  }
}

class TimestampConverter implements JsonConverter<DateTime?, dynamic> {
  const TimestampConverter();

  @override
  DateTime? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is Timestamp) return json.toDate();
    if (json is DateTime) return json;
    if (json is String) return DateTime.tryParse(json);
    return null;
  }

  @override
  dynamic toJson(DateTime? object) {
    if (object == null) return null;
    return Timestamp.fromDate(object);
  }
}
