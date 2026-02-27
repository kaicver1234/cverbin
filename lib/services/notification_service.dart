import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'tiksar_vpn_main';
  static const String _channelName = 'Tiksar VPN';
  static const String _channelDesc = 'اطلاعیه‌های Tiksar VPN';

  Future<void> initialize() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        _firebaseMessaging = FirebaseMessaging.instance;

        await _requestPermissions().timeout(
          const Duration(seconds: 3),
          onTimeout: () => debugPrint('⏱️ Notification permission timeout'),
        );

        await _initializeLocalNotifications().timeout(
          const Duration(seconds: 2),
          onTimeout: () => debugPrint('⏱️ Local notifications timeout'),
        );

        await _firebaseMessaging!.subscribeToTopic('all_users').timeout(
          const Duration(seconds: 3),
          onTimeout: () => debugPrint('⏱️ Topic subscription timeout'),
        );

        // TODO: حذف کن قبل از release — فقط برای تست
        await _firebaseMessaging!.subscribeToTopic('dev_test');
        debugPrint('🧪 Subscribed to dev_test topic');

        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        // NOTE: onBackgroundMessage is registered in main.dart BEFORE runApp()
        // to meet Firebase's requirement. Do NOT register it here again.
      }
      debugPrint('✅ Notification service initialized');
    } catch (e) {
      debugPrint('⚠️ Notification service error (app continues): $e');
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
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('ic_stat_notify');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create Android notification channel with full settings
    if (Platform.isAndroid) {
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 250, 100, 250]),
          enableLights: true,
          ledColor: const Color(0xFF1E293B),
          showBadge: true,
        ),
      );
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _showLocalNotification(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final String title = message.notification?.title ?? 'Tiksar VPN';
    final String body = message.notification?.body ?? '';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFF1E293B),
      icon: 'ic_stat_notify',
      largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
      styleInformation: BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: 'Tiksar VPN',
        htmlFormatSummaryText: false,
      ),
      autoCancel: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 100, 250]),
      enableLights: true,
      ledColor: const Color(0xFF1E293B),
      ledOnMs: 500,
      ledOffMs: 500,
      visibility: NotificationVisibility.public,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      groupKey: 'tiksar_vpn_group',
      subText: 'Tiksar VPN',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      message.hashCode.abs() % 100000,
      title,
      body,
      details,
    );

    debugPrint('🔔 Notification shown: "$title"');
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Notification tapped — app comes to foreground automatically
    debugPrint('🔔 Notification tapped');
  }
}


