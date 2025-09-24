import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/v2ray_provider.dart';
import '../theme/app_theme.dart';

class ConnectionButton extends StatelessWidget {
  const ConnectionButton({Key? key}) : super(key: key);

  // Helper method to handle async selection and connection
  Future<void> _connectToFirstServer(V2RayProvider provider) async {
    await provider.selectConfig(provider.configs.first);
    await provider.connectToServer(
      provider.configs.first,
      provider.isProxyMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<V2RayProvider>(
      builder: (context, provider, _) {
        final isConnected = provider.activeConfig != null;
        final isConnecting = provider.isConnecting;
        final selectedConfig = provider.selectedConfig;

        return GestureDetector(
          onTap: () async {
            if (isConnecting) return; // Prevent multiple taps while connecting

            if (isConnected) {
              await provider.disconnect();
            } else if (selectedConfig != null) {
              await provider.connectToServer(
                selectedConfig,
                provider.isProxyMode,
              );
            } else if (provider.configs.isNotEmpty) {
              // Auto-select first config if none selected
              await _connectToFirstServer(provider);
            }
          },
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getButtonColor(
                    isConnected,
                    isConnecting,
                  ).withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer animated ring (only visible when connecting)
                if (isConnecting)
                  Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.connectingYellow,
                            width: 3,
                          ),
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat())
                      .scale(
                        duration: 1500.ms,
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1.1, 1.1),
                      )
                      .then()
                      .scale(
                        duration: 1500.ms,
                        begin: const Offset(1.1, 1.1),
                        end: const Offset(0.9, 0.9),
                      ),

                // Middle ring
                if (isConnecting)
                  Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.connectingYellow.withValues(
                              alpha: 0.7,
                            ),
                            width: 2,
                          ),
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat())
                      .rotate(duration: 3000.ms, begin: 0, end: 1),

                // Main button
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _getGradientColors(isConnected, isConnecting),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _getButtonIcon(isConnected, isConnecting),
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getButtonColor(bool isConnected, bool isConnecting) {
    if (isConnecting) return AppTheme.connectingYellow;
    return isConnected ? AppTheme.primaryGreen : AppTheme.disconnectedRed;
  }

  List<Color> _getGradientColors(bool isConnected, bool isConnecting) {
    if (isConnecting) {
      return [
        AppTheme.connectingYellow,
        AppTheme.connectingYellow.withValues(alpha: 0.7),
      ];
    } else if (isConnected) {
      return [AppTheme.primaryGreen, AppTheme.accentGreen];
    } else {
      return [
        AppTheme.disconnectedRed,
        AppTheme.disconnectedRed.withValues(alpha: 0.7),
      ];
    }
  }

  IconData _getButtonIcon(bool isConnected, bool isConnecting) {
    if (isConnecting) return Icons.hourglass_top;
    return isConnected ? Icons.power_settings_new : Icons.power_settings_new;
  }
}
