import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'calendar_event.dart' show TimestampConverter;

part 'job_media.freezed.dart';
part 'job_media.g.dart';

@freezed
class JobMedia with _$JobMedia {
  const factory JobMedia({
    required String id,
    required String jobId,
    required String companyId,
    required String url,
    required String type,
    required String filename,
    required String createdBy,
    @TimestampConverter() DateTime? createdAt,
  }) = _JobMedia;

  factory JobMedia.fromJson(Map<String, dynamic> json) =>
      _$JobMediaFromJson(json);

  factory JobMedia.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    _convertTimestamps(data);
    return JobMedia.fromJson({
      'jobId': '',
      'companyId': '',
      'url': '',
      'type': 'image',
      'filename': '',
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
