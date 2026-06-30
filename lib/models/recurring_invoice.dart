import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'line_item.dart';

part 'recurring_invoice.freezed.dart';
part 'recurring_invoice.g.dart';

@freezed
class RecurringInvoice with _$RecurringInvoice {
  const factory RecurringInvoice({
    required String id,
    required String companyId,
    required String customerId,
    required String customerName,
    required String customerEmail,
    String? customerPhone,
    String? customerAddress,
    required String frequency, // 'weekly' | 'monthly' | 'quarterly' | 'yearly'
    required String startDate, // ISO
    String? endDate, // ISO
    required String nextRunDate, // ISO
    required bool isActive,
    required List<LineItem> items,
    required double subtotal,
    double? taxRate,
    double? taxAmount,
    double? discount,
    String? discountType, // 'percentage' | 'fixed'
    double? discountAmount,
    required double total,
    String? notes,
    String? pdfTemplateId,
    String? pdfThemeColor,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
    @TimestampConverter() DateTime? lastRunAt,
    required List<String> generatedInvoiceIds,
  }) = _RecurringInvoice;

  factory RecurringInvoice.fromJson(Map<String, dynamic> json) =>
      _$RecurringInvoiceFromJson(json);

  factory RecurringInvoice.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    _convertTimestamps(data);
    return RecurringInvoice.fromJson({
      'companyId': '',
      'customerId': '',
      'customerName': '',
      'customerEmail': '',
      'frequency': 'monthly',
      'startDate': '',
      'nextRunDate': '',
      'isActive': true,
      'items': [],
      'subtotal': 0.0,
      'total': 0.0,
      'generatedInvoiceIds': <String>[],
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
