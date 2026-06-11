import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'calendar_event.freezed.dart';
part 'calendar_event.g.dart';

@freezed
class CalendarEvent with _$CalendarEvent {
  const factory CalendarEvent({
    required String id,
    required String companyId,
    required String userId,
    required String title,
    required String start,
    required String end,
    bool? allDay,
    String? description,
    String? color,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
    String? googleEventId,
    // Job-related fields (optional for backward compatibility)
    String? customerId,
    String? customerName,
    String? customerAddress,
    String? status,
    List<dynamic>? checklist,
    List<String>? assignedUserIds,
    List<dynamic>? materials,
    String? signatureUrl,
    @TimestampConverter() DateTime? signedAt,
    // Labor Time Tracker
    String? enRouteAt,
    String? startedAt,
    String? completedAt,
  }) = _CalendarEvent;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) =>
      _$CalendarEventFromJson(json);

  factory CalendarEvent.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    _convertTimestamps(data);
    // Ensure start and end are never null
    if (data['start'] == null || data['start'] == '') {
      data['start'] = DateTime.now().toIso8601String();
    }
    if (data['end'] == null || data['end'] == '') {
      data['end'] = DateTime.now().add(const Duration(hours: 1)).toIso8601String();
    }
    return CalendarEvent.fromJson({
      'companyId': '',
      'userId': '',
      'title': '',
      'start': '',
      'end': '',
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
