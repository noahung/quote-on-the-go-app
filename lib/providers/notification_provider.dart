import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'auth_provider.dart';

part 'notification_provider.g.dart';

class UserNotification {
  final String id;
  final String userId;
  final String companyId;
  final String title;
  final String message;
  final String? link;
  final String type;
  final bool isRead;
  final bool isArchived;
  final DateTime createdAt;
  final String? relatedDocumentId;
  final bool deliveryFailed;

  UserNotification({
    required this.id,
    required this.userId,
    required this.companyId,
    required this.title,
    required this.message,
    this.link,
    required this.type,
    required this.isRead,
    this.isArchived = false,
    required this.createdAt,
    this.relatedDocumentId,
    this.deliveryFailed = false,
  });

  factory UserNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    DateTime createdAt;
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      createdAt = raw.toDate();
    } else if (raw is String) {
      createdAt = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return UserNotification(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      companyId: data['companyId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      link: data['link'] as String?,
      type: data['type'] as String? ?? 'generic',
      isRead: data['isRead'] as bool? ?? false,
      isArchived: data['isArchived'] as bool? ?? false,
      createdAt: createdAt,
      relatedDocumentId: data['relatedDocumentId'] as String?,
      deliveryFailed: (data['delivery'] as Map?)?.values.any((channel) => channel is Map && channel.values.contains('failed')) ?? false,
    );
  }
}

@riverpod
Stream<List<UserNotification>> notificationsStream(NotificationsStreamRef ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final firestore = FirebaseFirestore.instance;
  return firestore
      .collection('user_notifications')
      .where('userId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    final list = snapshot.docs
        .map((doc) => UserNotification.fromFirestore(doc))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
}

@riverpod
int unreadNotificationCount(UnreadNotificationCountRef ref) {
  final notifications = ref.watch(notificationsStreamProvider);
  return notifications.whenOrNull(
        data: (list) => list.where((n) => !n.isRead && !n.isArchived).length,
      ) ??
      0;
}

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('user_notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> _changeAll(String userId, {Map<String, dynamic>? update, bool archivedOnly = false}) async {
    final query = _firestore.collection('user_notifications')
        .where('userId', isEqualTo: userId).orderBy(FieldPath.documentId).limit(400);
    DocumentSnapshot? cursor;
    while (true) {
      final snapshot = await (cursor == null ? query : query.startAfterDocument(cursor)).get();
      if (snapshot.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        if (archivedOnly && doc.data()['isArchived'] != true) continue;
        if (update == null) { batch.delete(doc.reference); }
        else { batch.update(doc.reference, update); }
      }
      await batch.commit();
      cursor = snapshot.docs.last;
    }
  }

  Future<void> markAllAsRead(String userId) => _changeAll(userId, update: {'isRead': true});

  Future<void> archive(String notificationId) async {
    await _firestore
        .collection('user_notifications')
        .doc(notificationId)
        .update({'isArchived': true, 'isRead': true});
  }

  Future<void> unarchive(String notificationId) async {
    await _firestore
        .collection('user_notifications')
        .doc(notificationId)
        .update({'isArchived': false});
  }

  Future<void> archiveAll(String userId) => _changeAll(userId, update: {'isArchived': true, 'isRead': true});

  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection('user_notifications')
        .doc(notificationId)
        .delete();
  }

  Future<void> deleteAllArchived(String userId) => _changeAll(userId, archivedOnly: true);

}

@riverpod
NotificationRepository notificationRepository(NotificationRepositoryRef ref) {
  return NotificationRepository();
}
