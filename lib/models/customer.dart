import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'customer.freezed.dart';
part 'customer.g.dart';

@freezed
class Customer with _$Customer {
  const factory Customer({
    required String id,
    required String companyId,
    required String name,
    required String email,
    String? phone,
    String? address,
    @TimestampConverter() DateTime? createdAt,
    // Aggregated fields
    double? totalSpent,
    List<String>? quotationIds,
    List<String>? invoiceIds,
    String? firstSeenAt,
    String? lastSeenAt,
    // QuickBooks Integration
    String? quickbooksCustomerId,
    @TimestampConverter() DateTime? quickbooksLastSyncAt,
    // CRM Segmentation
    @Default([]) List<String> tags,
    String? notes,
    // Monday.com Integration
    String? mondayItemId,
    String? mondayBoardId,
    @TimestampConverter() DateTime? mondayLastSyncAt,
  }) = _Customer;

  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);

  factory Customer.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    _convertTimestamps(data);
    return Customer.fromJson({
      'companyId': '',
      'name': '',
      'email': '',
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
