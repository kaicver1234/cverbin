import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import 'home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  // No need to call updateAllSubscriptions here
  // It's already called in V2RayProvider constructor

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: const HomeScreen(),
        );
      },
    );
  }
}
