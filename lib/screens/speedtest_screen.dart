import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/speed_test_provider.dart';
import '../models/speed_test_state.dart';
import '../widgets/cyber_glow_background.dart';
import '../widgets/app_background.dart';
import '../widgets/speed_test/modern_speed_gauge.dart';
import '../utils/app_localizations.dart';
import '../services/analytics_service.dart';
import '../utils/responsive_helper.dart';

const Color _downloadColor = Color(0xFF00FFA3);
const Color _uploadColor = Color(0xFF00D9FF);
const Color _pingColor = Color(0xFFB388FF);

class SpeedTestScreen extends StatelessWidget {
  const SpeedTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: languageProvider.textDirection,
      child: AppBackground(
        useSecondaryBackground: true,
        child: CyberGlowBackground(
          child: SafeArea(
            child: Consumer<SpeedTestProvider>(
              builder: (context, provider, child) {
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveHelper(context).maxContentWidth,
                    ),
                    child: Column(
                      children: [
                        _Header(state: provider.state),
                        Expanded(child: _Body(provider: provider)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final SpeedTestState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
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
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Consumer<LanguageProvider>(
                builder: (context, lp, _) => Icon(
                  lp.isRtl ? Icons.arrow_forward_ios : Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.translate('speed_test.title_ready'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(state, tr),
                  style: TextStyle(
                    fontSize: 12,
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

  String _subtitle(SpeedTestState s, AppLocalizations tr) {
    if (s.step == SpeedTestStep.loading) return tr.translate('speed_test.measuring_latency');
    if (s.step == SpeedTestStep.download) return tr.translate('speed_test.download_test');
    if (s.step == SpeedTestStep.upload) return tr.translate('speed_test.upload_test');
    if (s.testCompleted) return tr.translate('speed_test.test_completed');
    if (s.hadError) return tr.translate('speed_test.subtitle_error');
    return tr.translate('speed_test.subtitle_ready');
  }
}

class _Body extends StatelessWidget {
  final SpeedTestProvider provider;
  const _Body({required this.provider});

  @override
  Widget build(BuildContext context) {
    final state = provider.state;
    final tr = AppLocalizations.of(context);
    final isRunning = state.step != SpeedTestStep.ready;

    final color = _phaseColor(state.step);
    final maxScale = _phaseMaxScale(state.step);
    final phaseLabel = _phaseLabel(state.step, tr);
    final displayValue = isRunning ? state.currentSpeed : state.result.downloadSpeed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _PhaseStepper(currentStep: state.step, completed: state.testCompleted),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: ModernSpeedGauge(
                value: state.step == SpeedTestStep.ready && !state.testCompleted ? 0 : displayValue,
                maxValue: maxScale,
                color: color,
                label: phaseLabel,
                size: 300,
                isIdle: state.step == SpeedTestStep.ready && !state.testCompleted,
                centerOverlay: state.step == SpeedTestStep.loading
                    ? _LoadingCenter(tr: tr)
                    : null,
              ),
            ),
          ),
          if (state.hadError) ...[
            const SizedBox(height: 12),
            _ErrorMessage(state: state),
          ],
          const SizedBox(height: 16),
          _ResultsRow(state: state),
          const SizedBox(height: 20),
          _PrimaryButton(provider: provider, state: state),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Color _phaseColor(SpeedTestStep s) {
    switch (s) {
      case SpeedTestStep.download:
        return _downloadColor;
      case SpeedTestStep.upload:
        return _uploadColor;
      case SpeedTestStep.loading:
        return _pingColor;
      case SpeedTestStep.ready:
        return _downloadColor;
    }
  }

  double _phaseMaxScale(SpeedTestStep s) {
    switch (s) {
      case SpeedTestStep.download:
        return 100;
      case SpeedTestStep.upload:
        return 50;
      default:
        return 100;
    }
  }

  String? _phaseLabel(SpeedTestStep s, AppLocalizations tr) {
    switch (s) {
      case SpeedTestStep.download:
        return tr.translate('speed_test.download').toUpperCase();
      case SpeedTestStep.upload:
        return tr.translate('speed_test.upload').toUpperCase();
      case SpeedTestStep.loading:
        return null;
      case SpeedTestStep.ready:
        return null;
    }
  }
}

class _LoadingCenter extends StatelessWidget {
  final AppLocalizations tr;
  const _LoadingCenter({required this.tr});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(_pingColor),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          tr.translate('speed_test.measuring_latency'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PhaseStepper extends StatelessWidget {
  final SpeedTestStep currentStep;
  final bool completed;
  const _PhaseStepper({required this.currentStep, required this.completed});

  @override
  Widget build(BuildContext context) {
    final phases = <_PhaseChipData>[
      _PhaseChipData('PING', _pingColor, currentStep == SpeedTestStep.loading,
          completed || currentStep == SpeedTestStep.download || currentStep == SpeedTestStep.upload),
      _PhaseChipData('DOWNLOAD', _downloadColor,
          currentStep == SpeedTestStep.download,
          completed || currentStep == SpeedTestStep.upload),
      _PhaseChipData('UPLOAD', _uploadColor,
          currentStep == SpeedTestStep.upload, completed),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < phases.length; i++) ...[
          _PhaseChip(data: phases[i]),
          if (i < phases.length - 1)
            Container(
              width: 16,
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: Colors.white.withValues(alpha: 0.15),
            ),
        ],
      ],
    );
  }
}

class _PhaseChipData {
  final String label;
  final Color color;
  final bool active;
  final bool done;
  _PhaseChipData(this.label, this.color, this.active, this.done);
}

class _PhaseChip extends StatelessWidget {
  final _PhaseChipData data;
  const _PhaseChip({required this.data});

  @override
  Widget build(BuildContext context) {
    final highlight = data.active || data.done;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? data.color.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? data.color.withValues(alpha: data.active ? 0.6 : 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlight ? data.color : Colors.white.withValues(alpha: 0.3),
              boxShadow: data.active
                  ? [BoxShadow(color: data.color, blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: highlight
                  ? data.color
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsRow extends StatelessWidget {
  final SpeedTestState state;
  const _ResultsRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _ResultCell(
            icon: Icons.network_ping,
            color: _pingColor,
            label: tr.translate('speed_test.ping'),
            value: state.result.ping > 0 ? state.result.ping.toString() : '—',
            unit: tr.translate('speed_test.ms'),
          ),
          _divider(),
          _ResultCell(
            icon: Icons.arrow_downward_rounded,
            color: _downloadColor,
            label: tr.translate('speed_test.download'),
            value: state.result.downloadSpeed > 0
                ? state.result.downloadSpeed.toStringAsFixed(1)
                : '—',
            unit: tr.translate('speed_test.mbps'),
          ),
          _divider(),
          _ResultCell(
            icon: Icons.arrow_upward_rounded,
            color: _uploadColor,
            label: tr.translate('speed_test.upload'),
            value: state.result.uploadSpeed > 0
                ? state.result.uploadSpeed.toStringAsFixed(1)
                : '—',
            unit: tr.translate('speed_test.mbps'),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        color: Colors.white.withValues(alpha: 0.06),
      );
}

class _ResultCell extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;

  const _ResultCell({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: value == '—'
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final SpeedTestProvider provider;
  final SpeedTestState state;
  const _PrimaryButton({required this.provider, required this.state});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final isRunning = state.step != SpeedTestStep.ready;
    final color = isRunning ? Colors.redAccent : _downloadColor;
    final label = isRunning
        ? tr.translate('speed_test.stop')
        : (state.testCompleted
            ? tr.translate('speed_test.test_again')
            : tr.translate('speed_test.start_test'));

    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () {
          if (isRunning) {
            provider.stopTest();
          } else {
            AnalyticsService().logSpeedTestStart();
            provider.startTest();
          }
        },
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.9),
                color.withValues(alpha: 0.65),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: Colors.black,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  final SpeedTestState state;
  const _ErrorMessage({required this.state});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final errorKey = state.errorMessage ?? 'test_failed';
    final msg = tr.translate('speed_test.$errorKey');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade300, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(color: Colors.red.shade200, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
