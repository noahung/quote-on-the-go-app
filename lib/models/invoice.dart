import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'company.dart';
import 'line_item.dart';

part 'invoice.freezed.dart';
part 'invoice.g.dart';

@freezed
class Invoice with _$Invoice {
  const factory Invoice({
    required String id,
    required String companyId,
    required String createdBy,
    required String invoiceNumber,
    String? quotationId,
    String? quotationNumber,
    String? customerId,
    required String customerName,
    required String customerEmail,
    String? customerPhone,
    String? customerAddress,
    required String date,
    required String dueDate,
    required List<LineItem> items,
    required double subtotal,
    double? taxRate,
    double? taxAmount,
    required double total,
    @Default('Draft') String status,
    @TimestampConverter() DateTime? scheduledSendAt,
    String? notes,
    CompanyProfile? company,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
    @TimestampConverter() DateTime? paidAt,
    String? stripePaymentIntentId,
    String? stripePaymentStatus,
    String? brevoMessageId,
    // Document discounts & status
    double? discount,
    String? discountType, // 'percentage' | 'fixed'
    double? discountAmount,
    @Default(false) bool isArchived,
    String? recurringSetupId,
    // Job linking
    String? jobId,
    // Monday.com Integration
    String? mondayItemId,
    String? mondayBoardId,
    String? mondaySyncStatus,
    String? mondaySyncError,
    @TimestampConverter() DateTime? mondayLastSyncAt,
  }) = _Invoice;

  factory Invoice.fromJson(Map<String, dynamic> json) =>
      _$InvoiceFromJson(json);

  factory Invoice.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    _convertTimestamps(data);
    return Invoice.fromJson({
      'companyId': '',
      'createdBy': '',
      'invoiceNumber': '',
      'customerName': '',
      'customerEmail': '',
      'date': '',
      'dueDate': '',
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
