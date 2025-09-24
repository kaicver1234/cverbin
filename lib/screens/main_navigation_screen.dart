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
  @override
  void initState() {
    super.initState();
    // Auto-update all subscriptions when app opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<V2RayProvider>(context, listen: false);
      provider.updateAllSubscriptions();
    });
  }

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
