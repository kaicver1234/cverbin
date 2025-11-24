import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint('🏠 MainNavigationScreen: initState');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏠 MainNavigationScreen: build');
    
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        debugPrint('🏠 Language direction: ${languageProvider.textDirection}');
        
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: const HomeScreen(),
        );
      },
    );
  }
}
