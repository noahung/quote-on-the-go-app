import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'calendar_event.dart' show TimestampConverter;

part 'job_note.freezed.dart';
part 'job_note.g.dart';

@freezed
class JobNote with _$JobNote {
  const factory JobNote({
    required String id,
    required String jobId,
    required String companyId,
    required String content,
    required String createdBy,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _JobNote;

  factory JobNote.fromJson(Map<String, dynamic> json) =>
      _$JobNoteFromJson(json);

  factory JobNote.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    _convertTimestamps(data);
    return JobNote.fromJson({
      'jobId': '',
      'companyId': '',
      'content': '',
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
