import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/language_provider.dart';
import 'providers/v2ray_provider.dart';
import 'providers/speed_test_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/privacy_welcome_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/update_check_wrapper.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';


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
  
  // Initialize services in background
  _initializeServices();
  
  // Load preferences
  final prefs = await SharedPreferences.getInstance();
  final bool languageSelected = prefs.getBool('language_selected') ?? false;
  final bool privacyAccepted = prefs.getBool('privacy_accepted') ?? false;
  
  // Initialize language provider
  final languageProvider = LanguageProvider();
  await languageProvider.initialize();
  
  debugPrint('🎨 Launching app...');
  
  // Run app directly
  runApp(MyApp(
    languageSelected: languageSelected,
    privacyAccepted: privacyAccepted,
    languageProvider: languageProvider,
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

  const MyApp({
    super.key,
    required this.languageSelected,
    required this.privacyAccepted,
    required this.languageProvider,
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
        ChangeNotifierProvider(create: (_) => V2RayProvider()),
        ChangeNotifierProvider(create: (_) => SpeedTestProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, langProvider, child) {
          debugPrint('🌍 Language: ${langProvider.currentLanguage.code}');
          
          Widget homeScreen;
          
          if (!languageSelected) {
            debugPrint('🌐 → LanguageSelectionScreen');
            homeScreen = const LanguageSelectionScreen();
          } else if (!privacyAccepted) {
            debugPrint('🔒 → PrivacyWelcomeScreen');
            homeScreen = const PrivacyWelcomeScreen();
          } else {
            debugPrint('🏠 → MainNavigationScreen');
            homeScreen = const MainNavigationScreen();
          }
          
          debugPrint('✅ Building MaterialApp with ${homeScreen.runtimeType}');
          
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
            builder: (context, child) {
              return UpdateCheckWrapper(child: child ?? homeScreen);
            },
            home: homeScreen,
          );
        },
      ),
    );
  }
}
