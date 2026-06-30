import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider.dart';
import 'quotation_provider.dart' show firestoreProvider;

/// A single customer-originated event surfaced from the web client portal.
///
/// These are read from the shared `activity_timeline` collection that the web
/// portal writes to when a customer views, comments on, accepts, declines, or
/// pays for a document. The mobile app does NOT recreate the customer portal —
/// it gives the business user a read/respond surface for that activity.
class ClientActivityItem {
  final String id;
  final String documentId;
  final String documentType; // 'quotation' | 'invoice'
  final String activityType; // 'viewed' | 'commented' | 'approved' | 'status_changed' | ...
  final String description;
  final String actorName;
  final String actorId;
  final String actorEmail;
  final DateTime timestamp;
  final String companyId;

  ClientActivityItem({
    required this.id,
    required this.documentId,
    required this.documentType,
    required this.activityType,
    required this.description,
    required this.actorName,
    required this.actorId,
    required this.actorEmail,
    required this.timestamp,
    required this.companyId,
  });

  /// True when the event was produced by a customer (not a team member).
  bool get isFromCustomer => actorId == 'customer';

  factory ClientActivityItem.fromMap(Map<String, dynamic> map, String docId) {
    final actor = map['actor'] as Map<String, dynamic>? ?? {};
    DateTime parsed;
    final ts = map['timestamp'];
    if (ts is Timestamp) {
      parsed = ts.toDate();
    } else if (ts is String) {
      parsed = DateTime.tryParse(ts) ?? DateTime.fromMillisecondsSinceEpoch(0);
    } else {
      parsed = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return ClientActivityItem(
      id: docId,
      documentId: map['documentId'] as String? ?? '',
      documentType: map['documentType'] as String? ?? '',
      activityType: map['activityType'] as String? ?? 'other',
      description: map['description'] as String? ?? '',
      actorName: actor['userName'] as String? ?? 'Customer',
      actorId: actor['userId'] as String? ?? '',
      actorEmail: actor['userEmail'] as String? ?? '',
      timestamp: parsed,
      companyId: map['companyId'] as String? ?? '',
    );
  }
}

/// Repository for reading customer portal activity and posting public
/// (customer-visible) replies. Public replies are written to `internal_comments`
/// with `isPrivate: false`, which is exactly what the web portal renders back to
/// the customer — so a reply here shows up in their portal automatically.
class PortalActivityRepository {
  final FirebaseFirestore _firestore;

  PortalActivityRepository(this._firestore);

  /// Streams company-wide customer activity.
  ///
  /// Uses a single-field equality filter (auto-indexed) and sorts/filters
  /// client-side to avoid requiring a manually-created composite index.
  Stream<List<ClientActivityItem>> watchCompanyCustomerActivity(
    String companyId,
  ) {
    return _firestore
        .collection('activity_timeline')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ClientActivityItem.fromMap(doc.data(), doc.id))
          .where((item) => item.isFromCustomer)
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list.take(150).toList();
    });
  }

  /// Posts a staff reply that is visible to the customer in the web portal.
  Future<void> addPublicReply({
    required String documentId,
    required String documentType,
    required String content,
    required String userId,
    required String userName,
    required String userEmail,
    required String companyId,
  }) async {
    final commentRef = _firestore.collection('internal_comments').doc();
    await commentRef.set({
      'id': commentRef.id,
      'documentId': documentId,
      'documentType': documentType,
      'content': content,
      'author': {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'isResolved': false,
      'mentions': <String>[],
      'isPrivate': false, // customer-visible
      'source': 'mobile_app',
      'companyId': companyId,
    });

    // Mirror the web behaviour: log the reply on the activity timeline.
    final activityRef = _firestore.collection('activity_timeline').doc();
    final preview =
        content.length > 50 ? '${content.substring(0, 50)}...' : content;
    await activityRef.set({
      'id': activityRef.id,
      'documentId': documentId,
      'documentType': documentType,
      'activityType': 'commented',
      'description': 'Replied to customer: "$preview"',
      'actor': {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
      },
      'timestamp': FieldValue.serverTimestamp(),
      'metadata': {'source': 'mobile_app'},
      'companyId': companyId,
    });
  }
}

final portalActivityRepositoryProvider =
    Provider<PortalActivityRepository>((ref) {
  return PortalActivityRepository(ref.watch(firestoreProvider));
});

/// Company-wide stream of customer portal activity for the current user.
final companyCustomerActivityProvider =
    StreamProvider<List<ClientActivityItem>>((ref) {
  final companyId = ref.watch(companyIdProvider);
  if (companyId == null || companyId.isEmpty) {
    return Stream.value(const <ClientActivityItem>[]);
  }
  return ref
      .watch(portalActivityRepositoryProvider)
      .watchCompanyCustomerActivity(companyId);
});

/// Tracks the last time the user opened the Client Responses inbox, persisted
/// per company so the unread badge survives restarts.
class ClientActivitySeenNotifier extends StateNotifier<DateTime?> {
  ClientActivitySeenNotifier(this._companyId) : super(null) {
    _load();
  }

  final String? _companyId;

  String get _key => 'client_activity_last_seen_${_companyId ?? 'none'}';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final millis = prefs.getInt(_key);
      if (millis != null) {
        state = DateTime.fromMillisecondsSinceEpoch(millis);
      }
    } catch (e) {
      debugPrint('[PortalActivity] Failed to load last-seen: $e');
    }
  }

  Future<void> markAllSeen() async {
    final now = DateTime.now();
    state = now;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, now.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[PortalActivity] Failed to persist last-seen: $e');
    }
  }
}

final clientActivitySeenProvider =
    StateNotifierProvider<ClientActivitySeenNotifier, DateTime?>((ref) {
  final companyId = ref.watch(companyIdProvider);
  return ClientActivitySeenNotifier(companyId);
});

/// Number of customer activity events newer than the last time the inbox was
/// opened. Drives the unread badge across the app.
final unreadClientActivityCountProvider = Provider<int>((ref) {
  final activity = ref.watch(companyCustomerActivityProvider).valueOrNull;
  if (activity == null || activity.isEmpty) return 0;
  final lastSeen = ref.watch(clientActivitySeenProvider);
  if (lastSeen == null) return activity.length;
  return activity.where((a) => a.timestamp.isAfter(lastSeen)).length;
});
