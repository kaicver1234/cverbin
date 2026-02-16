import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/speed_test_provider.dart';
import '../models/speed_test_state.dart';
import '../widgets/app_background.dart';
import '../widgets/speed_test/speed_test_progress_indicator.dart';
import '../widgets/speed_test/speed_test_start_button.dart';
import '../utils/app_localizations.dart';

// Colors for speed test
const Color _downloadColor = Color(0xFF76F959);
const Color _uploadColor = Color(0xFF72D9FF);

class SpeedTestScreen extends StatelessWidget {
  const SpeedTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: languageProvider.textDirection,
      child: AppBackground(
        useSecondaryBackground: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 16 : 20,
        isSmallScreen ? 12 : 16,
        isSmallScreen ? 16 : 20,
        0,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: isSmallScreen ? 18 : 20,
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.translate('speed_test.title_ready'),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18 : 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _getStatusText(state, tr),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 13,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360 || screenHeight < 700;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
      child: Column(
        children: [
          SizedBox(height: isSmallScreen ? 20 : 30),
          Expanded(
            child: _buildSpeedTestContent(context, provider, state),
          ),
          if (state.testCompleted && state.step == SpeedTestStep.ready)
            _buildResultsCard(context, state),
          SizedBox(height: isSmallScreen ? 16 : 20),
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: isSmallScreen ? 20 : 30),
        SpeedTestProgressIndicator(
          progress: 0.0,
          color: _downloadColor,
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
                          fontSize: isSmallScreen ? 11 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 6 : 8),
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
          SizedBox(height: isSmallScreen ? 16 : 20),
          _buildErrorMessage(context, state, tr),
        ],
      ],
    );
  }

  Widget _buildLoadingState(
      BuildContext context, SpeedTestProvider provider, SpeedTestState state) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: isSmallScreen ? 20 : 30),
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    
    // Use result.downloadSpeed for display (more accurate), currentSpeed for progress animation
    final displaySpeed = state.result.downloadSpeed > 0 ? state.result.downloadSpeed : state.currentSpeed;
    final speedProgress = (displaySpeed / 100).clamp(0.0, 1.0);
    final combinedProgress = (state.progress * 0.5) + (speedProgress * 0.5);

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: isSmallScreen ? 20 : 30),
        GestureDetector(
          onTap: () => provider.stopTest(),
          child: SpeedTestProgressIndicator(
            progress: combinedProgress,
            color: _downloadColor,
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    
    // Use result.uploadSpeed for display (more accurate), currentSpeed for progress animation
    final displaySpeed = state.result.uploadSpeed > 0 ? state.result.uploadSpeed : state.currentSpeed;
    final speedProgress = (displaySpeed / 50).clamp(0.0, 1.0);
    final combinedProgress = (state.progress * 0.5) + (speedProgress * 0.5);

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: isSmallScreen ? 20 : 30),
        GestureDetector(
          onTap: () => provider.stopTest(),
          child: SpeedTestProgressIndicator(
            progress: combinedProgress,
            color: _uploadColor,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 16 : 20,
        horizontal: isSmallScreen ? 12 : 16,
      ),
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
            color: _downloadColor,
            isSmallScreen: isSmallScreen,
          ),
          _buildDivider(isSmallScreen),
          _ResultItem(
            icon: Icons.upload_rounded,
            label: tr.translate('speed_test.upload'),
            value: state.result.uploadSpeed.toStringAsFixed(1),
            unit: tr.translate('speed_test.mbps'),
            color: _uploadColor,
            isSmallScreen: isSmallScreen,
          ),
          _buildDivider(isSmallScreen),
          _ResultItem(
            icon: Icons.network_ping,
            label: tr.translate('speed_test.ping'),
            value: state.result.ping.toString(),
            unit: tr.translate('speed_test.ms'),
            color: Colors.white,
            isSmallScreen: isSmallScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isSmallScreen) {
    return Container(
      width: 1,
      height: isSmallScreen ? 40 : 50,
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 6 : 8),
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
  final bool isSmallScreen;

  const _ResultItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color.withValues(alpha: 0.7), size: isSmallScreen ? 18 : 20),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: isSmallScreen ? 9 : 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isSmallScreen ? 3 : 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            unit,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: isSmallScreen ? 9 : 10,
            ),
          ),
        ],
      ),
    );
  }
}
