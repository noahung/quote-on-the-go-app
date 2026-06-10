import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'checklist_template.freezed.dart';
part 'checklist_template.g.dart';

@freezed
class ChecklistTemplate with _$ChecklistTemplate {
  const factory ChecklistTemplate({
    required String id,
    required String companyId,
    required String name,
    required List<String> items,
    @_TemplateTimestampConverter() DateTime? createdAt,
  }) = _ChecklistTemplate;

  factory ChecklistTemplate.fromJson(Map<String, dynamic> json) =>
      _$ChecklistTemplateFromJson(json);

  factory ChecklistTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    _convertTimestamps(data);
    return ChecklistTemplate.fromJson({
      'companyId': '',
      'name': '',
      'items': <String>[],
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

class _TemplateTimestampConverter implements JsonConverter<DateTime?, dynamic> {
  const _TemplateTimestampConverter();

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
