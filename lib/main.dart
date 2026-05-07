import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/language_provider.dart';
import 'providers/v2ray_provider.dart';
import 'providers/speed_test_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/dns_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/privacy_welcome_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/remote_config_service.dart';

// Must be a top-level function — called when app is in background or terminated.
// For notification messages (sent from Firebase Console with title/body),
// Android displays them automatically via the system tray.
// For data-only messages we show a local notification manually.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (message.notification == null && message.data.isNotEmpty) {
    final FlutterLocalNotificationsPlugin plugin =
        FlutterLocalNotificationsPlugin();
    const InitializationSettings initSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_notify'),
    );
    await plugin.initialize(initSettings);

    final String title = message.data['title'] as String? ?? 'Tiksar VPN';
    final String body = message.data['body'] as String? ?? '';

    await plugin.show(
      message.hashCode.abs() % 100000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tiksar_vpn_main',
          'Tiksar VPN',
          channelDescription: 'اطلاعیه‌های Tiksar VPN',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_notify',
          color: Color(0xFF1E293B),
          autoCancel: true,
        ),
      ),
    );
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  debugPrint('🚀 Starting Tiksar VPN...');
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 5));
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('⚠️ Firebase skipped: $e');
  }

  // Register background message handler BEFORE runApp() — Firebase requires
  // this to be set up as early as possible (ideally right after initializeApp).
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize services in background
  _initializeServices();
  
  // Load preferences
  final prefs = await SharedPreferences.getInstance();
  final bool languageSelected = prefs.getBool('language_selected') ?? false;
  final bool privacyAccepted = prefs.getBool('privacy_accepted') ?? false;
  
  // Initialize language provider
  final languageProvider = LanguageProvider();
  await languageProvider.initialize();

  // Initialize DNS provider
  final dnsProvider = DnsProvider();
  await dnsProvider.initialize();
  
  debugPrint('🎨 Launching app...');
  
  // Run app directly
  runApp(MyApp(
    languageSelected: languageSelected,
    privacyAccepted: privacyAccepted,
    languageProvider: languageProvider,
    dnsProvider: dnsProvider,
  ));
}

void _initializeServices() {
  // Analytics
  try {
    FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    FirebaseAnalytics.instance.logAppOpen();
  } catch (e) {
    debugPrint('⚠️ Analytics skipped: $e');
  }
  
  // Remote Config
  try {
    RemoteConfigService().initialize();
  } catch (e) {
    debugPrint('⚠️ Remote Config skipped: $e');
  }
  
  // Notifications
  try {
    NotificationService().initialize();
  } catch (e) {
    debugPrint('⚠️ Notifications skipped: $e');
  }
}

class MyApp extends StatelessWidget {
  final bool languageSelected;
  final bool privacyAccepted;
  final LanguageProvider languageProvider;
  final DnsProvider dnsProvider;

  const MyApp({
    super.key,
    required this.languageSelected,
    required this.privacyAccepted,
    required this.languageProvider,
    required this.dnsProvider,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ Building MyApp...');
    
    debugPrint('🎯 languageSelected=$languageSelected, privacyAccepted=$privacyAccepted');
    
    List<NavigatorObserver> observers = [];
    try {
      final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
      observers.add(FirebaseAnalyticsObserver(analytics: analytics));
    } catch (e) {
      debugPrint('⚠️ Analytics error (safe to ignore): $e');
    }
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: languageProvider),
        ChangeNotifierProvider.value(value: dnsProvider),
        ChangeNotifierProxyProvider<DnsProvider, V2RayProvider>(
          create: (_) => V2RayProvider(),
          update: (_, dns, v2ray) {
            v2ray?.setDnsProvider(dns);
            return v2ray!;
          },
        ),
        ChangeNotifierProvider(create: (_) => SpeedTestProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, langProvider, child) {
          debugPrint('🌍 Language: ${langProvider.currentLanguage.code}');
          
          // Determine the target screen after splash
          Widget targetScreen;
          
          if (!languageSelected) {
            debugPrint('🌐 → LanguageSelectionScreen');
            targetScreen = const LanguageSelectionScreen();
          } else if (!privacyAccepted) {
            debugPrint('🔒 → PrivacyWelcomeScreen');
            targetScreen = const PrivacyWelcomeScreen();
          } else {
            debugPrint('🏠 → MainNavigationScreen');
            targetScreen = const MainNavigationScreen();
          }
          
          // Wrap with new splash screen
          final homeScreen = SplashScreen(nextScreen: targetScreen);
          
          debugPrint('✅ Building MaterialApp with Splash → ${targetScreen.runtimeType}');
          
          return MaterialApp(
            title: 'Tiksar VPN',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme(langProvider.currentLanguage.code),
            locale: langProvider.locale,
            navigatorObservers: observers,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('fa'),
            ],

            home: homeScreen,
          );
        },
      ),
    );
  }
}
