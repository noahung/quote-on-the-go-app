import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'workflow.freezed.dart';
part 'workflow.g.dart';

const List<String> kWorkflowTriggers = [
  'quotation_created',
  'quotation_sent',
  'quotation_accepted',
  'quotation_declined',
  'invoice_created',
  'invoice_sent',
  'invoice_paid',
  'job_status_changed',
  'customer_created',
];

const Map<String, String> kWorkflowTriggerLabels = {
  'quotation_created': 'Quotation Created',
  'quotation_sent': 'Quotation Sent',
  'quotation_accepted': 'Quotation Accepted',
  'quotation_declined': 'Quotation Declined',
  'invoice_created': 'Invoice Created',
  'invoice_sent': 'Invoice Sent',
  'invoice_paid': 'Invoice Paid',
  'job_status_changed': 'Job Status Changed',
  'customer_created': 'Customer Created',
};

@freezed
class DelayConfig with _$DelayConfig {
  const factory DelayConfig({
    required String type, // 'hours', 'days', 'business_days'
    required int value,
  }) = _DelayConfig;

  factory DelayConfig.fromJson(Map<String, dynamic> json) =>
      _$DelayConfigFromJson(json);
}

@freezed
class TriggerCondition with _$TriggerCondition {
  const factory TriggerCondition({
    required String field,
    required String operator, // 'equals', 'not_equals', 'greater_than', 'less_than'
    required String value,
  }) = _TriggerCondition;

  factory TriggerCondition.fromJson(Map<String, dynamic> json) =>
      _$TriggerConditionFromJson(json);
}

@freezed
class WorkflowStep with _$WorkflowStep {
  const factory WorkflowStep({
    required int order,
    required String type,
    String? subject,
    String? body,
    int? waitDays,
    DelayConfig? delay,
  }) = _WorkflowStep;

  factory WorkflowStep.fromJson(Map<String, dynamic> json) =>
      _$WorkflowStepFromJson(json);
}

@freezed
class WorkflowTemplate with _$WorkflowTemplate {
  const factory WorkflowTemplate({
    required String id,
    required String name,
    String? description,
    required String type,
    required bool isActive,
    required String companyId,
    @Default([]) List<WorkflowStep> steps,
    int? maxRetries,
    int? retryDelaySeconds,
    String? onFailureAction, // 'none', 'notify_owner', 'stop'
    List<TriggerCondition>? conditions,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _WorkflowTemplate;

  factory WorkflowTemplate.fromJson(Map<String, dynamic> json) =>
      _$WorkflowTemplateFromJson(json);

  factory WorkflowTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    _convertTimestamps(data);
    
    if (data['steps'] is List) {
      data['steps'] = (data['steps'] as List)
          .map((s) {
            final stepMap = Map<String, dynamic>.from(s as Map);
            if (stepMap['delay'] is Map) {
              stepMap['delay'] = Map<String, dynamic>.from(stepMap['delay'] as Map);
            }
            return stepMap;
          })
          .toList();
    } else {
      data['steps'] = <Map<String, dynamic>>[];
    }

    if (data['conditions'] is List) {
      data['conditions'] = (data['conditions'] as List)
          .map((c) => Map<String, dynamic>.from(c as Map))
          .toList();
    }

    return WorkflowTemplate.fromJson({
      'name': '',
      'type': '',
      'isActive': false,
      'companyId': '',
      ...data,
      'id': doc.id,
    });
  }

  static void _convertTimestamps(Map<String, dynamic> data) {
    for (final key in data.keys.toList()) {
      if (data[key] is Timestamp) {
        data[key] = (data[key] as Timestamp).toDate().toIso8601String();
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
