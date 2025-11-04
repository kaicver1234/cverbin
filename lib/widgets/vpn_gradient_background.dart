import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';

/// VPN Gradient Background inspired by defyxVPN
/// Changes gradient colors based on connection status
class VPNGradientBackground extends StatelessWidget {
  final Widget child;
  final VPNBackgroundStatus status;

  const VPNGradientBackground({
    super.key,
    required this.child,
    this.status = VPNBackgroundStatus.disconnected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: status == VPNBackgroundStatus.connected
          ? AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              toolbarHeight: 0,
            )
          : null,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: _getCurrentGradient(status),
        ),
        child: child,
      ),
    );
  }

  LinearGradient _getCurrentGradient(VPNBackgroundStatus status) {
    switch (status) {
      case VPNBackgroundStatus.disconnected:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.topGradientReadyToConnect,
            AppColors.middleGradient,
            AppColors.bottomGradient,
          ],
          stops: [0.2, 0.7, 1.0],
        );
        
      case VPNBackgroundStatus.connected:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.topGradient,
            AppColors.bottomGradientConnected,
          ],
          stops: [0.0, 1.0],
        );
        
      case VPNBackgroundStatus.connecting:
      case VPNBackgroundStatus.analyzing:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.topGradientConnecting,
            AppColors.middleGradientConnecting,
            AppColors.bottomGradientConnecting,
          ],
          stops: [0.2, 0.7, 1.0],
        );
        
      case VPNBackgroundStatus.error:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.topGradient,
            AppColors.middleGradientFailedToConnect,
            AppColors.bottomGradientFailedToConnect,
          ],
          stops: [0.2, 0.7, 1.0],
        );
        
      case VPNBackgroundStatus.noInternet:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.topGradient,
            AppColors.middleGradientNoInternet,
            AppColors.bottomGradientNoInternet,
          ],
          stops: [0.2, 0.7, 1.0],
        );
    }
  }
}

/// Background status enum for VPN states
enum VPNBackgroundStatus {
  disconnected,
  connecting,
  connected,
  analyzing,
  error,
  noInternet,
}
