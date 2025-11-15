import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/language_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/privacy_welcome_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/update_check_wrapper.dart';
import 'screens/splash_loading_screen.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    debugPrint('🚀 Starting Tiksar VPN...');
    debugPrint('📱 Platform: ${Platform.operatingSystem}');
    
    // Show splash screen immediately
    runApp(const SplashApp());
    } catch (e, stackTrace) {
      debugPrint('💥 INITIALIZATION ERROR: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Try to show error screen even if initialization failed
      runApp(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF0A0E1A),
            body: Center(
              child: Container(
                padding: const EdgeInsets.all(40),
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 80,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Initialization Error',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to start Tiksar VPN\n\n$e',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => exit(0),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Exit'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }, (error, stackTrace) {
    debugPrint('💥 FATAL ERROR: $error');
    debugPrint('Stack trace: $stackTrace');
  });
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
    
    return ChangeNotifierProvider.value(
      value: languageProvider,
      child: Consumer<LanguageProvider>(
        builder: (context, langProvider, child) {
          debugPrint('🌍 Language: ${langProvider.currentLanguage.code}');
          
          Widget homeScreen;
          
          try {
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
          } catch (e, stackTrace) {
            debugPrint('❌ Screen error: $e');
            debugPrint('Stack: $stackTrace');
            homeScreen = _buildErrorScreen(e.toString());
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
            home: UpdateCheckWrapper(child: homeScreen),
          );
        },
      ),
    );
  }
  
  Widget _buildErrorScreen(String error) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(40),
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Application Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => exit(0),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Exit'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// Splash App - Shows loading screen first
class SplashApp extends StatelessWidget {
  const SplashApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiksar VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: SplashLoadingScreen(
        onInitialize: () async {
          // Initialize Firebase
          debugPrint('📲 Initializing Firebase...');
          try {
            await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            ).timeout(const Duration(seconds: 5));
            
            debugPrint('✅ Firebase initialized');
            
            // Analytics
            try {
              final analytics = FirebaseAnalytics.instance;
              await analytics.setAnalyticsCollectionEnabled(true)
                  .timeout(const Duration(seconds: 2));
              await analytics.logAppOpen()
                  .timeout(const Duration(seconds: 2));
              debugPrint('✅ Analytics enabled');
            } catch (e) {
              debugPrint('⚠️ Analytics skipped: $e');
            }
            
            // Notifications
            try {
              await NotificationService().initialize()
                  .timeout(const Duration(seconds: 3));
              debugPrint('✅ Notifications enabled');
            } catch (e) {
              debugPrint('⚠️ Notifications skipped: $e');
            }
          } catch (e) {
            debugPrint('⚠️ Firebase skipped: $e');
          }
        },
        onComplete: () async {
          // Load preferences and navigate to main app
          debugPrint('🌐 Loading language provider...');
          final languageProvider = LanguageProvider();
          await languageProvider.initialize();
          
          debugPrint('💾 Loading preferences...');
          final prefs = await SharedPreferences.getInstance();
          final bool languageSelected = prefs.getBool('language_selected') ?? false;
          final bool privacyAccepted = prefs.getBool('privacy_accepted') ?? false;
          
          debugPrint('🎨 Launching main app...');
          
          // Navigate to main app
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MyApp(
                languageSelected: languageSelected,
                privacyAccepted: privacyAccepted,
                languageProvider: languageProvider,
              ),
            ),
          );
        },
      ),
    );
  }
}
