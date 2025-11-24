import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/speed_test_provider.dart';
import '../models/speed_test_state.dart';
import '../widgets/vpn_gradient_background.dart';
import '../utils/app_colors.dart';
import '../utils/app_localizations.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  
  @override
  void initState() {
    super.initState();
    _initAnimations();
  }
  
  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }
  
  void _handleTestButton(SpeedTestProvider provider) {
    final state = provider.state;
    
    if (state.step == SpeedTestStep.testing) {
      provider.stopTest();
      _rotationController.stop();
    } else {
      provider.startTest();
      _rotationController.repeat();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Directionality(
      textDirection: languageProvider.textDirection,
      child: Scaffold(
        body: VPNGradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: Consumer<SpeedTestProvider>(
                    builder: (context, provider, child) {
                      final state = provider.state;
                      
                      // Stop rotation when test completes
                      if (state.step == SpeedTestStep.completed && _rotationController.isAnimating) {
                        _rotationController.stop();
                      }
                      
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            _buildSpeedometer(state),
                            const SizedBox(height: 40),
                            _buildResultCards(state),
                            const SizedBox(height: 30),
                            _buildTestButton(context, provider, state),
                            if (state.errorMessage != null) ...[
                              const SizedBox(height: 20),
                              _buildErrorMessage(state.errorMessage!),
                            ],
                            const SizedBox(height: 20),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            AppLocalizations.of(context).translate('home.speed_test'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSpeedometer(SpeedTestState state) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (state.step == SpeedTestStep.testing)
            RotationTransition(
              turns: _rotationController,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    width: 3,
                  ),
                ),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _getSpeedText(state),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getPhaseText(state),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
              if (state.step == SpeedTestStep.testing) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    value: state.progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ).animate().scale(duration: 600.ms, curve: Curves.elasticOut);
  }
  
  String _getSpeedText(SpeedTestState state) {
    if (state.step == SpeedTestStep.ready) {
      return '--';
    } else if (state.step == SpeedTestStep.testing) {
      if (state.currentPhase == TestPhase.loading) {
        return '${state.result.ping}';
      } else {
        return state.currentSpeed.toStringAsFixed(1);
      }
    } else if (state.step == SpeedTestStep.completed) {
      return state.result.downloadSpeed.toStringAsFixed(1);
    }
    return '--';
  }
  
  String _getPhaseText(SpeedTestState state) {
    if (state.step == SpeedTestStep.ready) {
      return AppLocalizations.of(context).translate('speed_test.tap_to_start');
    } else if (state.step == SpeedTestStep.testing) {
      if (state.currentPhase == TestPhase.loading) {
        return 'ms - ${AppLocalizations.of(context).translate('speed_test.testing_ping')}';
      } else if (state.currentPhase == TestPhase.download) {
        return 'Mbps - ${AppLocalizations.of(context).translate('speed_test.testing_download')}';
      } else {
        return 'Mbps - ${AppLocalizations.of(context).translate('speed_test.testing_upload')}';
      }
    } else if (state.step == SpeedTestStep.completed) {
      return 'Mbps - ${AppLocalizations.of(context).translate('speed_test.completed')}';
    }
    return '';
  }
  
  Widget _buildResultCards(SpeedTestState state) {
    return Row(
      children: [
        Expanded(
          child: _buildResultCard(
            icon: Icons.download,
            label: AppLocalizations.of(context).translate('speed_test.download'),
            value: state.result.downloadSpeed.toStringAsFixed(2),
            unit: 'Mbps',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildResultCard(
            icon: Icons.upload,
            label: AppLocalizations.of(context).translate('speed_test.upload'),
            value: state.result.uploadSpeed.toStringAsFixed(2),
            unit: 'Mbps',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildResultCard(
            icon: Icons.speed,
            label: AppLocalizations.of(context).translate('speed_test.ping'),
            value: state.result.ping.toString(),
            unit: 'ms',
            color: Colors.orange,
          ),
        ),
      ],
    );
  }
  
  Widget _buildResultCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0);
  }
  
  Widget _buildTestButton(BuildContext context, SpeedTestProvider provider, SpeedTestState state) {
    final isTesting = state.step == SpeedTestStep.testing;
    
    return GestureDetector(
      onTap: () => _handleTestButton(provider),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isTesting
                ? [Colors.red, Colors.red.shade700]
                : [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isTesting ? Colors.red : AppColors.primary).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: Text(
            isTesting
                ? AppLocalizations.of(context).translate('speed_test.stop_test')
                : AppLocalizations.of(context).translate('speed_test.start_test'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, end: 0);
  }
  
  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
