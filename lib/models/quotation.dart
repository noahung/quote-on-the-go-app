import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'company.dart';
import 'line_item.dart';

part 'quotation.freezed.dart';
part 'quotation.g.dart';

@freezed
class Quotation with _$Quotation {
  const factory Quotation({
    required String id,
    required String companyId,
    required String createdBy,
    required String quotationNumber,
    required String customerName,
    required String customerEmail,
    String? customerPhone,
    String? customerAddress,
    required String date,
    required String expiryDate,
    required List<LineItem> items,
    required double subtotal,
    double? taxRate,
    double? taxAmount,
    required double total,
    @Default('Draft') String status,
    String? notes,
    String? title,
    @Default(false) bool isStarred,
    CompanyProfile? company,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
    String? amendmentComments,
    @Default(false) bool isArchived,
    @TimestampConverter() DateTime? scheduledSendAt,
    String? brevoMessageId,
    // Document discounts
    double? discount,
    String? discountType, // 'percentage' | 'fixed'
    double? discountAmount,
    // Job linking
    String? jobId,
    // Monday.com Integration
    String? mondayItemId,
    String? mondayBoardId,
    String? mondaySyncStatus,
    String? mondaySyncError,
    @TimestampConverter() DateTime? mondayLastSyncAt,
  }) = _Quotation;

  factory Quotation.fromJson(Map<String, dynamic> json) =>
      _$QuotationFromJson(json);

  factory Quotation.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    _convertTimestamps(data);
    return Quotation.fromJson({
      'companyId': '',
      'createdBy': '',
      'quotationNumber': '',
      'customerName': '',
      'customerEmail': '',
      'date': '',
      'expiryDate': '',
      'items': [],
      'subtotal': 0.0,
      'total': 0.0,
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
