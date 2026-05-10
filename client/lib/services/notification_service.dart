import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/api_service.dart';

// ─── Background Message Handler ───────────────────────────────────────────
// Must be a top-level function (outside any class)
// Called when app is in background or terminated
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message received: ${message.messageId}');
}

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // ─── Android Notification Channel ─────────────────────────────────────
  // Required for Android 8.0+ to show notifications
  static const _androidChannel = AndroidNotificationChannel(
    'chat_notifications',
    'Chat Notifications',
    description: 'Notifications for new chat messages',
    importance: Importance.high,
  );

  // ─── Initialize ───────────────────────────────────────────────────────
  // Sets up Firebase Messaging and local notifications
  // Called once when the app starts
  Future<void> initialize(String token) async {
    // Request permission from user
    await _requestPermission();

    // Setup local notifications for foreground messages
    await _setupLocalNotifications();

    // Get FCM token and save to backend
    await _saveFcmToken(token);

    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app is terminated
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    print('NotificationService initialized');
  }

  // ─── Request Permission ────────────────────────────────────────────────
  // Asks user for notification permission on iOS
  // Android 13+ also requires this
  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('Notification permission: ${settings.authorizationStatus}');
  }

  // ─── Setup Local Notifications ─────────────────────────────────────────
  // Configures flutter_local_notifications for showing
  // notifications when app is in foreground
  Future<void> _setupLocalNotifications() async {
    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
  }

  // ─── Save FCM Token ────────────────────────────────────────────────────
  // Gets the device's FCM token and saves it to the backend
  // The backend uses this token to send push notifications
  Future<void> _saveFcmToken(String authToken) async {
    try {
      final fcmToken = await _firebaseMessaging.getToken();
      print('FCM Token: $fcmToken');

      if (fcmToken != null) {
        await ApiService.saveFcmToken(authToken, fcmToken);
        print('FCM token saved to backend');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }

    // Listen for token refresh
    // Token can change so we update it whenever it does
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      await ApiService.saveFcmToken(authToken, newToken);
      print('FCM token refreshed and saved');
    });
  }

  // ─── Handle Foreground Message ─────────────────────────────────────────
  // Shows a local notification when a push notification
  // arrives while the app is open and in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // Show local notification
    await _localNotifications.show(
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
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ─── Handle Notification Tap ───────────────────────────────────────────
  // Called when user taps a notification
  // Can be used to navigate to the correct chat screen
  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');

    final type = message.data['type'];

    if (type == 'direct_message') {
      print('Navigate to DM with: ${message.data['senderName']}');
      // Navigation will be handled in next step
    } else if (type == 'room_message') {
      print('Navigate to room: ${message.data['roomId']}');
      // Navigation will be handled in next step
    }
  }
}
