import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'interaction_log.freezed.dart';
part 'interaction_log.g.dart';

@freezed
class InteractionLog with _$InteractionLog {
  const factory InteractionLog({
    required String id,
    required String customerId,
    required String companyId,
    required String type, // 'email' | 'meeting' | 'call' | 'portal_view' | 'job_log'
    required String title,
    String? description,
    @_TimestampConverter() DateTime? timestamp,
    required String createdBy,
  }) = _InteractionLog;

  factory InteractionLog.fromJson(Map<String, dynamic> json) =>
      _$InteractionLogFromJson(json);

  factory InteractionLog.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    _convertTimestamps(data);
    return InteractionLog.fromJson({
      'customerId': '',
      'companyId': '',
      'type': 'call',
      'title': '',
      'createdBy': '',
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

class _TimestampConverter implements JsonConverter<DateTime?, dynamic> {
  const _TimestampConverter();

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
