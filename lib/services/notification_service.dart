import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    try {
      // Only initialize Firebase messaging on mobile platforms
      if (Platform.isAndroid || Platform.isIOS) {
        _firebaseMessaging = FirebaseMessaging.instance;
        
        // Request notification permissions
        await _requestPermissions();
        
        // Initialize local notifications for showing notifications in foreground
        await _initializeLocalNotifications();
        
        // Subscribe to all_users topic to receive notifications for all users
        await _firebaseMessaging!.subscribeToTopic('all_users');
        
        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        
        // Handle background messages
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      }
      // Notification service initialized
      
    } catch (e) {
      // Error initializing notifications - skip for desktop
      if (Platform.isAndroid || Platform.isIOS) {
        rethrow;
      }
    }
  }

  Future<void> _requestPermissions() async {
    if (_firebaseMessaging == null) return;
    
    await _firebaseMessaging!.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    // Notification permission status checked
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Show notification when app is in foreground
    _showLocalNotification(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'tiksar_vpn_channel',
      'Tiksar VPN Notifications',
      channelDescription: 'Notifications from Tiksar VPN',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@drawable/ic_firebase_notification',
    );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    
    await _flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? 'Tiksar VPN',
      message.notification?.body ?? '',
      platformChannelSpecifics,
      payload: message.data.toString(),
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Handle notification tap if needed
  }
}

// This function MUST be top-level (outside of any class)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Handling background message
}
