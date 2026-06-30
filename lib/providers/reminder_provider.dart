import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'quotation_provider.dart';

class ReminderSettings {
  final bool enabled;
  final List<int> triggerDays;
  final String emailTemplate;

  ReminderSettings({
    required this.enabled,
    required this.triggerDays,
    required this.emailTemplate,
  });

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    return ReminderSettings(
      enabled: json['enabled'] as bool? ?? false,
      triggerDays: json['triggerDays'] != null
          ? List<int>.from(json['triggerDays'])
          : [1, 7, 14],
      emailTemplate: json['emailTemplate'] as String? ?? _defaultTemplate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'triggerDays': triggerDays,
      'emailTemplate': emailTemplate,
    };
  }

  static const String _defaultTemplate =
      "Hi {{customer_name}},\n\nThis is a friendly reminder that invoice {{invoice_number}} for {{invoice_total}} was due on {{due_date}}.\n\nPlease find the invoice attached or view it in the client portal: {{portal_url}}\n\nKind regards,\n{{company_name}}";

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
  final String status; // 'Sent' or 'Failed'
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
    final raw = data['sentAt'];
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
      recipientEmail: data['recipientEmail'] as String? ?? '',
      status: data['status'] as String? ?? 'Sent',
      triggerType: data['triggerType'] as String? ?? 'Manual',
      daysOverdue: data['daysOverdue'] as int?,
      error: data['error'] as String?,
    );
  }
}

class ReminderRepository {
  final FirebaseFirestore _firestore;

  ReminderRepository(this._firestore);

  Future<ReminderSettings> getReminderSettings(String companyId) async {
    try {
      final doc = await _firestore.collection('reminder_settings').doc(companyId).get();
      if (!doc.exists || doc.data() == null) {
        return ReminderSettings.defaultSettings();
      }
      return ReminderSettings.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('[ReminderRepo] Error getting settings: $e');
      return ReminderSettings.defaultSettings();
    }
  }

  Future<void> updateReminderSettings(String companyId, ReminderSettings settings) async {
    await _firestore
        .collection('reminder_settings')
        .doc(companyId)
        .set(settings.toJson(), SetOptions(merge: true));
  }

  Stream<List<ReminderHistoryEntry>> streamReminderHistory(String invoiceId) {
    return _firestore
        .collection('invoiceReminderHistory')
        .where('invoiceId', isEqualTo: invoiceId)
        .snapshots()
        .map((snap) {
      final entries = snap.docs.map((d) => ReminderHistoryEntry.fromFirestore(d)).toList();
      entries.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      return entries;
    });
  }

  Future<void> sendManualReminderEmail(String invoiceId, String recipientEmail) async {
    try {
      // 1. Fetch invoice
      final invoiceSnap = await _firestore.collection('invoices').doc(invoiceId).get();
      if (!invoiceSnap.exists || invoiceSnap.data() == null) {
        throw Exception('Invoice not found');
      }
      final invoice = Invoice.fromFirestore(invoiceSnap);

      // 2. Fetch settings
      final settings = await getReminderSettings(invoice.companyId);

      // 3. Fetch company branding to get company name
      final companySnap = await _firestore.collection('companies').doc(invoice.companyId).get();
      final companyName = companySnap.exists ? (companySnap.data()?['name'] as String? ?? 'Our Company') : 'Our Company';

      // 4. Interpolate template
      final body = _interpolateTemplate(
        settings.emailTemplate,
        invoice: invoice,
        companyName: companyName,
      );

      // 5. Send email via writing to 'mail' collection
      await _firestore.collection('mail').add({
        'to': recipientEmail,
        'message': {
          'subject': 'Payment Reminder: Invoice #${invoice.invoiceNumber}',
          'text': body,
        },
        'metadata': {
          'invoiceId': invoiceId,
          'companyId': invoice.companyId,
          'triggerType': 'Manual',
        },
      });

      // 6. Record in history
      await _firestore.collection('invoiceReminderHistory').add({
        'invoiceId': invoiceId,
        'companyId': invoice.companyId,
        'sentAt': FieldValue.serverTimestamp(),
        'recipientEmail': recipientEmail,
        'status': 'Sent',
        'triggerType': 'Manual',
      });
    } catch (e) {
      debugPrint('[ReminderRepo] Error sending manual reminder: $e');
      // Record failed history entry
      await _firestore.collection('invoiceReminderHistory').add({
        'invoiceId': invoiceId,
        'sentAt': FieldValue.serverTimestamp(),
        'recipientEmail': recipientEmail,
        'status': 'Failed',
        'triggerType': 'Manual',
        'error': e.toString(),
      });
      rethrow;
    }
  }

  Future<void> processAutoReminders(String companyId) async {
    try {
      final settings = await getReminderSettings(companyId);
      if (!settings.enabled) return;

      // Fetch all non-draft, unpaid invoices for this company (Sent or Overdue)
      final invoicesSnap = await _firestore
          .collection('invoices')
          .where('companyId', isEqualTo: companyId)
          .where('status', whereIn: ['Sent', 'Overdue'])
          .get();

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      // Fetch company name
      final companySnap = await _firestore.collection('companies').doc(companyId).get();
      final companyName = companySnap.exists ? (companySnap.data()?['name'] as String? ?? 'Our Company') : 'Our Company';

      for (final doc in invoicesSnap.docs) {
        final invoice = Invoice.fromFirestore(doc);
        final dueDate = DateTime.tryParse(invoice.dueDate);
        if (dueDate == null) continue;

        final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
        final daysOverdue = todayDate.difference(dueDateOnly).inDays;

        if (daysOverdue > 0 && settings.triggerDays.contains(daysOverdue)) {
          // Check if an auto reminder for this invoice and this daysOverdue was already sent
          final historySnap = await _firestore
              .collection('invoiceReminderHistory')
              .where('invoiceId', isEqualTo: invoice.id)
              .where('triggerType', isEqualTo: 'Auto')
              .where('daysOverdue', isEqualTo: daysOverdue)
              .limit(1)
              .get();

          if (historySnap.docs.isEmpty) {
            // Send email
            final body = _interpolateTemplate(
              settings.emailTemplate,
              invoice: invoice,
              companyName: companyName,
            );

            await _firestore.collection('mail').add({
              'to': invoice.customerEmail,
              'message': {
                'subject': 'Payment Reminder: Invoice #${invoice.invoiceNumber}',
                'text': body,
              },
              'metadata': {
                'invoiceId': invoice.id,
                'companyId': companyId,
                'triggerType': 'Auto',
                'daysOverdue': daysOverdue,
              },
            });

            await _firestore.collection('invoiceReminderHistory').add({
              'invoiceId': invoice.id,
              'companyId': companyId,
              'sentAt': FieldValue.serverTimestamp(),
              'recipientEmail': invoice.customerEmail,
              'status': 'Sent',
              'triggerType': 'Auto',
              'daysOverdue': daysOverdue,
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[ReminderRepo] Error processing auto reminders: $e');
    }
  }

  String _interpolateTemplate(
    String template, {
    required Invoice invoice,
    required String companyName,
  }) {
    final portalUrl = 'https://app.quoteonthego.co.uk/invoices/${invoice.id}/portal';
    final totalFormatted = '£${invoice.total.toStringAsFixed(2)}';

    return template
        .replaceAll('{{customer_name}}', invoice.customerName)
        .replaceAll('{{invoice_number}}', invoice.invoiceNumber)
        .replaceAll('{{invoice_total}}', totalFormatted)
        .replaceAll('{{due_date}}', invoice.dueDate)
        .replaceAll('{{portal_url}}', portalUrl)
        .replaceAll('{{company_name}}', companyName);
  }
}

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ReminderRepository(firestore);
});

final reminderSettingsStreamProvider = StreamProvider.autoDispose<ReminderSettings>((ref) {
  final companyId = ref.watch(companyIdProvider);
  if (companyId == null) {
    return Stream.value(ReminderSettings.defaultSettings());
  }
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('reminder_settings')
      .doc(companyId)
      .snapshots()
      .map((doc) => doc.exists && doc.data() != null
          ? ReminderSettings.fromJson(doc.data()!)
          : ReminderSettings.defaultSettings());
});

final reminderHistoryStreamProvider = StreamProvider.family.autoDispose<List<ReminderHistoryEntry>, String>((ref, invoiceId) {
  final repo = ref.watch(reminderRepositoryProvider);
  return repo.streamReminderHistory(invoiceId);
});
