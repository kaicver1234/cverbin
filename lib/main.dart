import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/telegram_proxy_provider.dart';
import 'providers/v2ray_provider.dart';
import 'providers/language_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/privacy_welcome_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/update_check_wrapper.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first
  await Firebase.initializeApp();
  
  // Initialize notification service
  await NotificationService().initialize();

  // Initialize language provider
  final languageProvider = LanguageProvider();
  await languageProvider.initialize();

  // Check if user has selected language and accepted privacy policy
  final prefs = await SharedPreferences.getInstance();
  final bool languageSelected = prefs.getBool('language_selected') ?? false;
  final bool privacyAccepted = prefs.getBool('privacy_accepted') ?? false;

  runApp(
    MyApp(
      languageSelected: languageSelected,
      privacyAccepted: privacyAccepted, 
      languageProvider: languageProvider
    ),
  );
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: languageProvider),
        ChangeNotifierProvider(create: (context) => V2RayProvider()),
        ChangeNotifierProvider(create: (context) => TelegramProxyProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            title: 'Tiksar VPN',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme(languageProvider.currentLanguage.code),
            locale: languageProvider.locale,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'), // English
              Locale('fa'), // Persian
            ],
            home: UpdateCheckWrapper(
              child: !languageSelected
                  ? const LanguageSelectionScreen()
                  : (privacyAccepted
                      ? const MainNavigationScreen()
                      : const PrivacyWelcomeScreen()),
            ),
          );
        },
      ),
    );
  }
}
