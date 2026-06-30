import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'line_item.dart';

part 'document_template.freezed.dart';
part 'document_template.g.dart';

@freezed
class DocumentTemplate with _$DocumentTemplate {
  const factory DocumentTemplate({
    required String id,
    required String companyId,
    required String name,
    String? description,
    required String type, // 'quotation' | 'invoice'
    required List<LineItem> items,
    String? notes,
    double? taxRate,
    String? pdfTemplateId,
    String? pdfThemeColor,
    double? discount,
    String? discountType, // 'percentage' | 'fixed'
    double? discountAmount,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _DocumentTemplate;

  factory DocumentTemplate.fromJson(Map<String, dynamic> json) =>
      _$DocumentTemplateFromJson(json);

  factory DocumentTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    _convertTimestamps(data);
    return DocumentTemplate.fromJson({
      'companyId': '',
      'name': '',
      'type': 'quotation',
      'items': [],
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
