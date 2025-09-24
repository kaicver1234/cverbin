import 'package:flutter/material.dart';
import '../services/update_checker_service.dart';
import '../widgets/update_dialog.dart';
import '../models/app_update_info.dart';

class UpdateCheckWrapper extends StatefulWidget {
  final Widget child;
  
  const UpdateCheckWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<UpdateCheckWrapper> createState() => _UpdateCheckWrapperState();
}

class _UpdateCheckWrapperState extends State<UpdateCheckWrapper> {
  bool _isCheckingUpdate = true;
  AppUpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      // Check for updates on every app launch
      final updateInfo = await UpdateCheckerService.checkForUpdate();
      
      if (mounted) {
        setState(() {
          _updateInfo = updateInfo;
          _isCheckingUpdate = false;
        });
        
        // If update is available, show dialog immediately
        if (_updateInfo != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showUpdateDialog();
          });
        }
      }
    } catch (e) {
      print('Error checking for update: $e');
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
      builder: (context) => WillPopScope(
        onWillPop: () async => !_updateInfo!.isForced,
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
    // If forced update is available, show update dialog instead of main app
    if (_updateInfo != null && _updateInfo!.isForced && !_isCheckingUpdate) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E293B),
        body: SafeArea(
          child: UpdateDialog(updateInfo: _updateInfo!),
        ),
      );
    }
    
    // Always show the main app (check for updates happens in background)
    return widget.child;
  }
}
