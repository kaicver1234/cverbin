import 'package:flutter/material.dart';
import '../services/update_checker_service.dart';
import '../widgets/update_dialog.dart';
import '../models/app_update_info.dart';

class UpdateCheckWrapper extends StatefulWidget {
  final Widget child;
  
  const UpdateCheckWrapper({
    super.key,
    required this.child,
  });

  @override
  State<UpdateCheckWrapper> createState() => _UpdateCheckWrapperState();
}

class _UpdateCheckWrapperState extends State<UpdateCheckWrapper> {
  bool _isCheckingUpdate = false;  // تغییر به false - اول برنامه باز می‌شود
  AppUpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    // چک آپدیت را بعد از باز شدن برنامه انجام بده (پس‌زمینه)
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkForUpdate();
    });
  }

  Future<void> _checkForUpdate() async {
    try {
      // چک آپدیت در پس‌زمینه انجام می‌شود و برنامه را مسدود نمی‌کند
      final updateInfo = await UpdateCheckerService.checkForUpdate()
          .timeout(
            const Duration(seconds: 10),  // حداکثر 10 ثانیه منتظر می‌مانیم
            onTimeout: () {
              debugPrint('⏱️ چک آپدیت timeout شد - برنامه ادامه می‌یابد');
              return null;  // اگر timeout شد، null برگردان
            },
          );
      
      if (mounted) {
        setState(() {
          _updateInfo = updateInfo;
          _isCheckingUpdate = false;
        });
        
        // اگر آپدیت جدید موجود باشد، دیالوگ را نمایش بده
        if (_updateInfo != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showUpdateDialog();
          });
        }
      }
    } catch (e) {
      // خطا در چک آپدیت - به صورت silent ادامه می‌دهیم و برنامه را باز می‌کنیم
      debugPrint('⚠️ خطا در چک آپدیت: $e - برنامه به صورت عادی باز می‌شود');
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  void _showUpdateDialog() async {
    if (_updateInfo == null) return;
    
    await showDialog(
      context: context,
      barrierDismissible: !_updateInfo!.isForced,
      builder: (context) => PopScope(
        canPop: !_updateInfo!.isForced,
        child: UpdateDialog(updateInfo: _updateInfo!),
      ),
    );
    
    // If update is forced and dialog is closed, show it again
    if (_updateInfo!.isForced && mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showUpdateDialog();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // اگر آپدیت اجباری موجود باشد، صفحه آپدیت را نمایش بده
    // (فقط بعد از اینکه چک کامل شده باشد)
    if (_updateInfo != null && _updateInfo!.isForced && !_isCheckingUpdate) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E293B),
        body: SafeArea(
          child: UpdateDialog(updateInfo: _updateInfo!),
        ),
      );
    }
    
    // همیشه برنامه اصلی را نمایش بده (چک آپدیت در پس‌زمینه انجام می‌شود)
    // این تضمین می‌کند که حتی بدون اینترنت هم می‌توانی وارد VPN شوی
    return widget.child;
  }
}
