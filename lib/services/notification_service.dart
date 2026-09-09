import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No UI work here — FCM shows the system notification automatically
  // when the app is in the background/terminated.
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _fcm = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'qotg_high_importance',
    'Quote On The Go',
    description: 'Quotation and invoice notifications',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    // 1. Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // 2. Set up local notifications plugin for foreground display
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // 3. Create the Android high-importance channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // 4. Foreground message handler
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 5. Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 6. Handle notification tap when app was in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // Handle notification tap when app was terminated (initial message)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _onMessageOpenedApp(initialMessage);
    }

    // 7. Save token once auth is confirmed, then keep refreshed
    // Listen to auth state so the token is saved even on a fresh install
    // where persistent auth restores the user asynchronously after initialize().
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) return;
      final token = await _fcm.getToken();
      if (token != null) await _saveToken(token);
    });
    _fcm.onTokenRefresh.listen(_saveToken);
  }

  Future<String> _installationId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('notificationInstallationId');
    if (id == null) { id = const Uuid().v4(); await prefs.setString('notificationInstallationId', id); }
    return id;
  }

  Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    debugPrint('[FCM] Saving token for ${user.uid}');
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid).collection('devices').doc(await _installationId())
          .set({
        'token': token, 'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp()
      });
    } catch (e) {
      debugPrint('[FCM] Error saving token: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message: ${message.notification?.title}');
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: android?.smallIcon ?? '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['link'] ?? message.data['click_action'],
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    // Navigation handled by the router listening to FCM tap events
    final link = response.payload;
    if (link != null && link.isNotEmpty) {
      _queueRoute(link);
    }
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    final link = message.data['link'] ?? message.data['click_action'];
    if (link != null && link.isNotEmpty) {
      _queueRoute(link);
    }
  }

  /// Route to navigate to when app is opened from a notification.
  String? _pendingRoute;

  void _queueRoute(String link) {
    final route = notificationRoute(link);
    if (route == null) return;
    _pendingRoute = route;
    notifyListeners();
  }

  String? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  /// Call after sign-in to ensure the token is always current.
  Future<void> refreshTokenForCurrentUser() async {
    final token = await _fcm.getToken();
    if (token != null) await _saveToken(token);
  }

  /// Call on sign-out to clear the token from Firestore.
  Future<void> clearToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid).collection('devices').doc(await _installationId()).delete();
      final token = await _fcm.getToken();
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final profile = await transaction.get(userRef);
        if (token != null && profile.data()?['fcmToken'] == token) { transaction.update(userRef, {'fcmToken': FieldValue.delete()}); }
      });
    } catch (_) {}
  }
}

String? notificationRoute(String link) {
  final uri = Uri.tryParse(link);
  if (uri == null || (uri.hasScheme && !['http', 'https', 'qotg'].contains(uri.scheme))) return null;
  final allowed = ['quotations', 'invoices', 'schedule', 'customers', 'collaboration', 'notifications', 'client-responses'];
  if (uri.pathSegments.isEmpty || !allowed.contains(uri.pathSegments.first)) return null;
  return '/${uri.pathSegments.map(Uri.encodeComponent).join('/')}${uri.hasQuery ? '?${uri.query}' : ''}';
}
