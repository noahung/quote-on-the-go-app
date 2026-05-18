import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'company.freezed.dart';
part 'company.g.dart';

@freezed
class BankAccount with _$BankAccount {
  const factory BankAccount({
    required String id,
    required String accountName,
    required String bankName,
    required String sortCode,
    required String accountNumber,
  }) = _BankAccount;

  factory BankAccount.fromJson(Map<String, dynamic> json) =>
      _$BankAccountFromJson(json);
}

@freezed
class Company with _$Company {
  const factory Company({
    required String id,
    required String ownerId,
    required String name,
    required String address,
    String? phone,
    String? email,
    String? website,
    String? logoUrl,
    List<BankAccount>? bankAccounts,
    double? defaultTaxRate,
    required String tier,
    String? subscriptionStatus,
    String? referredBy,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    @TimestampConverter() DateTime? trialEndsAt,
    @TimestampConverter() required DateTime createdAt,
    // QuickBooks Integration
    String? quickbooksRealmId,
    String? quickbooksAccessToken,
    String? quickbooksRefreshToken,
    @TimestampConverter() DateTime? quickbooksTokenExpiresAt,
    bool? quickbooksEnabled,
    @TimestampConverter() DateTime? quickbooksConnectedAt,
    @TimestampConverter() DateTime? quickbooksLastSyncAt,
    // Google Calendar Integration
    String? googleCalendarRefreshToken,
    bool? googleCalendarEnabled,
    @TimestampConverter() DateTime? googleCalendarConnectedAt,
    @TimestampConverter() DateTime? googleCalendarLastSyncAt,
    // Monday.com Integration
    String? mondayAccessToken,
    String? mondayAccountId,
    String? mondayWorkspaceId,
    bool? mondayEnabled,
    @TimestampConverter() DateTime? mondayConnectedAt,
    @TimestampConverter() DateTime? mondayLastSyncAt,
    String? mondayWebhookId,
    String? mondayQuotationsBoardId,
    String? mondayInvoicesBoardId,
    String? mondayCustomersBoardId,
  }) = _Company;

  factory Company.fromJson(Map<String, dynamic> json) =>
      _$CompanyFromJson(json);

  factory Company.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    _convertTimestamps(data);
    return Company.fromJson({
      'ownerId': '',
      'name': '',
      'address': '',
      'tier': 'free',
      'createdAt': DateTime.now().toIso8601String(),
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

@freezed
class CompanyProfile with _$CompanyProfile {
  const factory CompanyProfile({
    required String name,
    required String address,
    String? phone,
    String? email,
    String? website,
    String? logoUrl,
    List<BankAccount>? bankAccounts,
    double? defaultTaxRate,
  }) = _CompanyProfile;

  factory CompanyProfile.fromJson(Map<String, dynamic> json) =>
      _$CompanyProfileFromJson(json);
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
