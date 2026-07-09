import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/update_checker_service.dart';
import '../services/ad_service.dart';
import '../models/ad_config.dart';
import '../widgets/update_dialog.dart';
import '../widgets/ad_overlay_screen.dart';
import '../models/app_update_info.dart';
import 'modern_home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  bool _hasCheckedUpdate = false;
  bool _hasShownAd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // اول تبلیغِ باز شدن اپ رو نشون بده (اگه روشن باشه)، بعد چک آپدیت.
      // ترتیبی انجام می‌شن تا دیالوگ آپدیت روی تبلیغ نیفته.
      _showAppOpenAdThenCheckUpdate();
    });
  }

  Future<void> _showAppOpenAdThenCheckUpdate() async {
    await _showAppOpenAd();
    if (mounted) _checkForUpdate();
  }

  /// تبلیغِ اختصاصی رو (اگه روی سرور روشن و مربوط به «باز شدن اپ» باشه) نشون می‌ده.
  Future<void> _showAppOpenAd() async {
    if (_hasShownAd) return;
    _hasShownAd = true;

    try {
      final AdConfig ad = await AdService.fetchAd();
      if (!mounted) return;
      if (ad.isValid && ad.showOn == 'app_open') {
        await AdOverlayScreen.show(context, ad);
      }
    } catch (_) {}
  }

  Future<void> _checkForUpdate() async {
    if (_hasCheckedUpdate) return;
    _hasCheckedUpdate = true;
    
    try {
      final AppUpdateInfo? updateInfo = await UpdateCheckerService.checkForUpdate();
      if (updateInfo != null && mounted) {
        _showUpdateDialog(updateInfo);
      }
    } catch (_) {}
  }

  void _showUpdateDialog(AppUpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.isForced,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => UpdateDialog(updateInfo: updateInfo),
    ).then((_) {
      // اگر آپدیت اجباری بود و دیالوگ بسته شد، دوباره نشون بده
      if (updateInfo.isForced && mounted) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _showUpdateDialog(updateInfo);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: const ModernHomeScreen(),
        );
      },
    );
  }
}
