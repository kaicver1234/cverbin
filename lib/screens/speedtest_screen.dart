import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/speed_test_provider.dart';
import '../models/speed_test_state.dart';
import '../widgets/vpn_gradient_background.dart';
import '../widgets/speed_test/speed_test_progress_indicator.dart';
import '../widgets/speed_test/speed_test_start_button.dart';
import '../utils/app_localizations.dart';
import '../utils/app_colors.dart';

class SpeedTestScreen extends StatelessWidget {
  const SpeedTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: languageProvider.textDirection,
      child: Scaffold(
        body: VPNGradientBackground(
          child: SafeArea(
            child: Consumer<SpeedTestProvider>(
              builder: (context, provider, child) {
                return Column(
                  children: [
                    _buildHeader(context, provider.state),
                    Expanded(
                      child: _buildContent(context, provider),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SpeedTestState state) {
    final tr = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.translate('speed_test.title_ready'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getStatusText(state, tr),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(SpeedTestState state, AppLocalizations tr) {
    if (state.step == SpeedTestStep.loading) return tr.translate('speed_test.measuring_latency');
    if (state.step == SpeedTestStep.download) return tr.translate('speed_test.download_test');
    if (state.step == SpeedTestStep.upload) return tr.translate('speed_test.upload_test');
    if (state.testCompleted) return tr.translate('speed_test.test_completed');
    if (state.hadError) return tr.translate('speed_test.subtitle_error');
    return tr.translate('speed_test.subtitle_ready');
  }

  Widget _buildContent(BuildContext context, SpeedTestProvider provider) {
    final state = provider.state;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Expanded(
            child: _buildSpeedTestContent(context, provider, state),
          ),
          if (state.testCompleted && state.step == SpeedTestStep.ready)
            _buildResultsCard(context, state),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSpeedTestContent(
      BuildContext context, SpeedTestProvider provider, SpeedTestState state) {
    final tr = AppLocalizations.of(context);

    switch (state.step) {
      case SpeedTestStep.ready:
        return _buildReadyState(context, provider, state, tr);
      case SpeedTestStep.loading:
        return _buildLoadingState(context, provider, state);
      case SpeedTestStep.download:
        return _buildDownloadState(context, provider, state);
      case SpeedTestStep.upload:
        return _buildUploadState(context, provider, state);
    }
  }

  Widget _buildReadyState(BuildContext context, SpeedTestProvider provider,
      SpeedTestState state, AppLocalizations tr) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        SpeedTestProgressIndicator(
          progress: 0.0,
          color: AppColors.downloadColor,
          showButton: true,
          result: state.result,
          currentStep: SpeedTestStep.ready,
          button: state.testCompleted
              ? SpeedTestStartButton(
                  currentStep: SpeedTestStep.ready,
                  isEnabled: true,
                  onTap: () => provider.startTest(),
                  previousStep: SpeedTestStep.download,
                )
              : GestureDetector(
                  onTap: () => provider.startTest(),
                  child: Column(
                    children: [
                      Text(
                        tr.translate('speed_test.tap_here'),
                        style: TextStyle(
                          color: const Color(0xFFABABAB),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SpeedTestStartButton(
                        currentStep: SpeedTestStep.ready,
                        isEnabled: true,
                        onTap: () => provider.startTest(),
                      ),
                    ],
                  ),
                ),
        ),
        if (state.hadError) ...[
          const SizedBox(height: 20),
          _buildErrorMessage(context, state, tr),
        ],
      ],
    );
  }

  Widget _buildLoadingState(
      BuildContext context, SpeedTestProvider provider, SpeedTestState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        GestureDetector(
          onTap: () => provider.stopTest(),
          child: SpeedTestProgressIndicator(
            progress: 0.0,
            color: Colors.transparent,
            showButton: false,
            showLoadingIndicator: true,
            result: state.result,
            currentStep: SpeedTestStep.loading,
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadState(
      BuildContext context, SpeedTestProvider provider, SpeedTestState state) {
    // Use result.downloadSpeed for display (more accurate), currentSpeed for progress animation
    final displaySpeed = state.result.downloadSpeed > 0 ? state.result.downloadSpeed : state.currentSpeed;
    final speedProgress = (displaySpeed / 100).clamp(0.0, 1.0);
    final combinedProgress = (state.progress * 0.5) + (speedProgress * 0.5);

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        GestureDetector(
          onTap: () => provider.stopTest(),
          child: SpeedTestProgressIndicator(
            progress: combinedProgress,
            color: AppColors.downloadColor,
            showButton: false,
            centerValue: displaySpeed,
            centerUnit: 'Mbps',
            subtitle: 'DOWNLOAD',
            result: state.result,
            currentStep: SpeedTestStep.download,
          ),
        ),
      ],
    );
  }

  Widget _buildUploadState(
      BuildContext context, SpeedTestProvider provider, SpeedTestState state) {
    // Use result.uploadSpeed for display (more accurate), currentSpeed for progress animation
    final displaySpeed = state.result.uploadSpeed > 0 ? state.result.uploadSpeed : state.currentSpeed;
    final speedProgress = (displaySpeed / 50).clamp(0.0, 1.0);
    final combinedProgress = (state.progress * 0.5) + (speedProgress * 0.5);

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        GestureDetector(
          onTap: () => provider.stopTest(),
          child: SpeedTestProgressIndicator(
            progress: combinedProgress,
            color: AppColors.uploadColor,
            showButton: false,
            centerValue: displaySpeed,
            centerUnit: 'Mbps',
            subtitle: 'UPLOAD',
            result: state.result,
            currentStep: SpeedTestStep.upload,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(
      BuildContext context, SpeedTestState state, AppLocalizations tr) {
    final errorKey = state.errorMessage ?? 'test_failed';
    final errorMsg = tr.translate('speed_test.$errorKey');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade300, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMsg,
              style: TextStyle(
                color: Colors.red.shade200,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard(BuildContext context, SpeedTestState state) {
    final tr = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          _ResultItem(
            icon: Icons.download_rounded,
            label: tr.translate('speed_test.download'),
            value: state.result.downloadSpeed.toStringAsFixed(1),
            unit: tr.translate('speed_test.mbps'),
            color: AppColors.downloadColor,
          ),
          _buildDivider(),
          _ResultItem(
            icon: Icons.upload_rounded,
            label: tr.translate('speed_test.upload'),
            value: state.result.uploadSpeed.toStringAsFixed(1),
            unit: tr.translate('speed_test.mbps'),
            color: AppColors.uploadColor,
          ),
          _buildDivider(),
          _ResultItem(
            icon: Icons.network_ping,
            label: tr.translate('speed_test.ping'),
            value: state.result.ping.toString(),
            unit: tr.translate('speed_test.ms'),
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _ResultItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _ResultItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color.withValues(alpha: 0.7), size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
