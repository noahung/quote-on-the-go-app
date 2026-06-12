import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'workflow.freezed.dart';
part 'workflow.g.dart';

@freezed
class WorkflowStep with _$WorkflowStep {
  const factory WorkflowStep({
    required int order,
    required String type,
    String? subject,
    String? body,
    int? waitDays,
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
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();
    } else {
      data['steps'] = <Map<String, dynamic>>[];
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
