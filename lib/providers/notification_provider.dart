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
  final DateTime createdAt;
  final String? relatedDocumentId;

  UserNotification({
    required this.id,
    required this.userId,
    required this.companyId,
    required this.title,
    required this.message,
    this.link,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.relatedDocumentId,
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
      createdAt: createdAt,
      relatedDocumentId: data['relatedDocumentId'] as String?,
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
        data: (list) => list.where((n) => !n.isRead).length,
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

  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('user_notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}

@riverpod
NotificationRepository notificationRepository(NotificationRepositoryRef ref) {
  return NotificationRepository();
}
