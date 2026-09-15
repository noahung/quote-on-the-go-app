import '../services/api_client.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'quotation_provider.dart';

class ReminderSettings {
  final bool enabled;
  final List<int> triggerDays;
  final List<int> disabledTriggerDays;
  final String emailTemplate;

  ReminderSettings({
    required this.enabled,
    required this.triggerDays,
    required this.emailTemplate,
    this.disabledTriggerDays = const [],
  });

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    return ReminderSettings(
      enabled: json['enableAutoReminders'] as bool? ??
          json['enabled'] as bool? ??
          false,
      triggerDays: json['reminderSchedule'] is List
          ? (json['reminderSchedule'] as List)
              .where((s) => s['enabled'] == true)
              .map((s) => (s['daysAfterDue'] as num).toInt())
              .toList()
          : json['triggerDays'] != null
              ? List<int>.from(json['triggerDays'])
              : [1, 7, 14],
      emailTemplate: json['reminderTemplate'] as String? ??
          json['emailTemplate'] as String? ??
          _defaultTemplate,
      disabledTriggerDays: json['reminderSchedule'] is List
          ? (json['reminderSchedule'] as List)
              .where((s) => s['enabled'] != true)
              .map((s) => (s['daysAfterDue'] as num).toInt())
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableAutoReminders': enabled,
      'reminderSchedule': [
        ...triggerDays
            .toSet()
            .map((day) => {'daysAfterDue': day, 'enabled': true}),
        ...disabledTriggerDays
            .toSet()
            .where((day) => !triggerDays.contains(day))
            .map((day) => {'daysAfterDue': day, 'enabled': false}),
      ]..sort((a, b) =>
          (a['daysAfterDue'] as int).compareTo(b['daysAfterDue'] as int)),
      'reminderTemplate': emailTemplate,
    };
  }

  static const String _defaultTemplate = '';

  factory ReminderSettings.defaultSettings() {
    return ReminderSettings(
      enabled: false,
      triggerDays: [1, 7, 14],
      emailTemplate: _defaultTemplate,
    );
  }
}

class ReminderHistoryEntry {
  final String id;
  final String invoiceId;
  final String companyId;
  final DateTime sentAt;
  final String recipientEmail;
  final String status; // 'Sent', 'Failed' or 'Skipped'
  final String triggerType; // 'Auto' or 'Manual'
  final int? daysOverdue;
  final String? error;

  ReminderHistoryEntry({
    required this.id,
    required this.invoiceId,
    required this.companyId,
    required this.sentAt,
    required this.recipientEmail,
    required this.status,
    required this.triggerType,
    this.daysOverdue,
    this.error,
  });

  factory ReminderHistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    DateTime sentAt;
    final raw = data['skippedAt'] ?? data['sentAt'];
    if (raw is Timestamp) {
      sentAt = raw.toDate();
    } else if (raw is String) {
      sentAt = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      sentAt = DateTime.now();
    }

    return ReminderHistoryEntry(
      id: doc.id,
      invoiceId: data['invoiceId'] as String? ?? '',
      companyId: data['companyId'] as String? ?? '',
      sentAt: sentAt,
      recipientEmail: data['customerEmail'] as String? ??
          data['recipientEmail'] as String? ??
          '',
      status: switch ((data['status'] as String? ?? 'sent').toLowerCase()) {
        'sent' => 'Sent',
        'skipped' => 'Skipped',
        _ => 'Failed',
      },
      triggerType: data['triggerType'] as String? ?? 'Manual',
      daysOverdue: data['daysOverdue'] as int?,
      error: data['error'] as String?,
    );
  }
}

class ReminderRepository {
  final FirebaseFirestore _firestore;

  final String companyId;
  ReminderRepository(this._firestore, this.companyId);

  Future<ReminderSettings> getReminderSettings(String companyId) async {
    final result = await ApiClient.post(
        '/api/mobile/operations', {'operation': 'reminders.get'});
    return ReminderSettings.fromJson(
        Map<String, dynamic>.from(result['data'] as Map));
  }

  Future<void> updateReminderSettings(
      String companyId, ReminderSettings settings) async {
    await ApiClient.post('/api/mobile/operations',
        {'operation': 'reminders.update', 'settings': settings.toJson()});
  }

  Stream<List<ReminderHistoryEntry>> streamReminderHistory(String invoiceId) {
    return _firestore
        .collection('invoiceReminderHistory')
        .where('companyId', isEqualTo: companyId)
        .where('invoiceId', isEqualTo: invoiceId)
        .snapshots()
        .map((snap) {
      final entries =
          snap.docs.map((d) => ReminderHistoryEntry.fromFirestore(d)).toList();
      entries.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      return entries;
    });
  }

  Future<void> sendManualReminderEmail(
      String invoiceId, String recipientEmail) async {
    await ApiClient.post('/api/mobile/operations',
        {'operation': 'reminders.send', 'invoiceId': invoiceId});
  }

  Future<void> processAutoReminders(String companyId) async {
    await ApiClient.post(
        '/api/mobile/operations', {'operation': 'reminders.process'});
  }
}

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ReminderRepository(firestore, ref.watch(companyIdProvider) ?? '');
});

final reminderSettingsStreamProvider =
    StreamProvider.autoDispose<ReminderSettings>((ref) {
  final companyId = ref.watch(companyIdProvider);
  if (companyId == null) {
    return Stream.value(ReminderSettings.defaultSettings());
  }
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('companies').doc(companyId).snapshots().map(
      (doc) => doc.exists && doc.data() != null
          ? ReminderSettings.fromJson(Map<String, dynamic>.from(
              doc.data()!['reminderSettings'] as Map? ?? {}))
          : ReminderSettings.defaultSettings());
});

final reminderHistoryStreamProvider = StreamProvider.family
    .autoDispose<List<ReminderHistoryEntry>, String>((ref, invoiceId) {
  final repo = ref.watch(reminderRepositoryProvider);
  return repo.streamReminderHistory(invoiceId);
});
