import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/speed_test_provider.dart';
import '../models/speed_test_state.dart';
import '../widgets/app_background.dart';
import '../widgets/speed_test/modern_speed_gauge.dart';
import '../widgets/wave_loading.dart';
import '../utils/app_localizations.dart';
import '../services/analytics_service.dart';
import '../utils/responsive_helper.dart';

// ─── Monochrome palette ────────────────────────────────────────────────────
// The speed test is intentionally black & white only — no accent hues — so it
// reads as a clean, minimal instrument rather than a colourful dashboard.
const Color _kWhite = Colors.white;

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
  // Captured once so it can be used safely in dispose() without touching
  // context after the widget is gone.
  SpeedTestProvider? _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = Provider.of<SpeedTestProvider>(context, listen: false);
  }

  @override
  void dispose() {
    // The SpeedTestProvider is registered app-level (see main.dart) and outlives
    // this screen, so a test left mid-run would keep hammering Cloudflare in the
    // background (up to 250MB down / 50MB up through the tunnel). Stop any
    // in-flight test when the user leaves the screen. A completed/idle test
    // (step == ready) is left untouched so its result survives a revisit.
    final p = _provider;
    if (p != null && p.state.step != SpeedTestStep.ready) {
      p.stopTest();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final tr = AppLocalizations.of(context);

    return Directionality(
      textDirection: lp.textDirection,
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                lp.isRtl
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.arrow_back_ios_rounded,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              tr.translate('speed_test.title_ready'),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: Consumer<SpeedTestProvider>(
            builder: (context, provider, _) {
              final r = ResponsiveHelper(context);
              return ResponsivePageWrapper(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    r.horizontalPadding,
                    8,
                    r.horizontalPadding,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                          height: r.responsiveValue(
                              small: 8, medium: 14, large: 18)),

                      // Status pill (mirrors home screen)
                      _StatusPill(state: provider.state),

                      SizedBox(
                          height: r.responsiveValue(
                              small: 22, medium: 28, large: 34)),

                      // Big gauge centerpiece
                      _GaugeStage(state: provider.state),

                      SizedBox(
                          height: r.responsiveValue(
                              small: 20, medium: 24, large: 28)),

                      // Live numeric readout (ping / download / upload / jitter)
                      _MetricsPanel(state: provider.state),

                      SizedBox(
                          height: r.responsiveValue(
                              small: 24, medium: 30, large: 36)),

                      // Segmented phase progress (replaces dot indicator)
                      _PhaseProgress(state: provider.state),

                      SizedBox(
                          height: r.responsiveValue(
                              small: 26, medium: 32, large: 38)),

                      if (provider.state.hadError) ...[
                        _ErrorMessage(state: provider.state),
                        const SizedBox(height: 18),
                      ],

                      // Primary action button
                      _PrimaryButton(
                          provider: provider, state: provider.state),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Status pill ───────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final SpeedTestState state;
  const _StatusPill({required this.state});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final isRunning = state.step != SpeedTestStep.ready;

    final String text;
    final Color color;

    if (isRunning) {
      if (state.step == SpeedTestStep.loading) {
        text = tr.translate('speed_test.measuring_latency');
      } else if (state.step == SpeedTestStep.download) {
        text = tr.translate('speed_test.download_test');
      } else {
        text = tr.translate('speed_test.upload_test');
      }
      color = _kWhite;
    } else if (state.testCompleted) {
      text = tr.translate('speed_test.test_completed');
      color = _kWhite;
    } else if (state.hadError) {
      text = tr.translate('speed_test.title_error');
      color = Colors.white.withValues(alpha: 0.7);
    } else {
      text = tr.translate('speed_test.subtitle_ready');
      color = Colors.white.withValues(alpha: 0.5);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Row(
        key: ValueKey(text),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 8,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Gauge stage ───────────────────────────────────────────────────────────

class _GaugeStage extends StatelessWidget {
  final SpeedTestState state;
  const _GaugeStage({required this.state});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final r = ResponsiveHelper(context);
    final isRunning = state.step != SpeedTestStep.ready;
    final color = _phaseColor(state.step);
    final maxScale = _phaseMaxScale(state.step);
    final label = _phaseLabel(state.step, tr, completed: state.testCompleted);
    final value = isRunning ? state.currentSpeed : state.result.downloadSpeed;
    final isIdle = state.step == SpeedTestStep.ready && !state.testCompleted;

    final size = r.scale(270).clamp(220.0, 340.0);

    return SizedBox(
      width: size,
      height: size,
      child: ModernSpeedGauge(
        value: isIdle ? 0 : value,
        maxValue: maxScale,
        color: color,
        label: label,
        size: size,
        isIdle: isIdle,
        centerOverlay: state.step == SpeedTestStep.loading
            ? const _LoadingCenter()
            : null,
      ),
    );
  }
}

class _LoadingCenter extends StatelessWidget {
  const _LoadingCenter();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const WaveLoading(color: _kWhite),
        const SizedBox(height: 14),
        Text(
          'PING',
          style: GoogleFonts.poppins(
            color: _kWhite.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}

// ─── Metrics panel (ping / download / upload / jitter) ─────────────────────

class _MetricsPanel extends StatelessWidget {
  final SpeedTestState state;
  const _MetricsPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final result = state.result;

    String fmtSpeed(double v) {
      if (v <= 0) return '--';
      if (v >= 100) return v.toStringAsFixed(0);
      if (v >= 10) return v.toStringAsFixed(1);
      return v.toStringAsFixed(2);
    }

    String fmtMs(int v) => v > 0 ? '$v' : '--';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _MetricTile(
          icon: Icons.network_ping_rounded,
          label: tr.translate('speed_test.ping'),
          value: fmtMs(result.ping),
          unit: tr.translate('speed_test.ms'),
        ),
        _MetricTile(
          icon: Icons.south_rounded,
          label: tr.translate('speed_test.download'),
          value: fmtSpeed(result.downloadSpeed),
          unit: tr.translate('speed_test.mbps'),
        ),
        _MetricTile(
          icon: Icons.north_rounded,
          label: tr.translate('speed_test.upload'),
          value: fmtSpeed(result.uploadSpeed),
          unit: tr.translate('speed_test.mbps'),
        ),
        _MetricTile(
          icon: Icons.timeline_rounded,
          label: tr.translate('speed_test.jitter'),
          value: fmtMs(result.jitter),
          unit: tr.translate('speed_test.ms'),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final active = value != '--';
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: Colors.white.withValues(alpha: active ? 0.75 : 0.30),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Colors.white.withValues(alpha: 0.40),
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white
                        .withValues(alpha: active ? 0.95 : 0.35),
                  ),
                ),
                if (active)
                  TextSpan(
                    text: ' $unit',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.45),
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

// ─── Phase progress (segmented bar) ────────────────────────────────────────

class _PhaseProgress extends StatelessWidget {
  final SpeedTestState state;
  const _PhaseProgress({required this.state});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final step = state.step;
    final completed = state.testCompleted;

    // Status of each phase: -1 not yet, 0 active, 1 done.
    int pingStatus;
    int downloadStatus;
    int uploadStatus;

    if (completed) {
      pingStatus = 1;
      downloadStatus = 1;
      uploadStatus = 1;
    } else if (step == SpeedTestStep.loading) {
      pingStatus = 0;
      downloadStatus = -1;
      uploadStatus = -1;
    } else if (step == SpeedTestStep.download) {
      pingStatus = 1;
      downloadStatus = 0;
      uploadStatus = -1;
    } else if (step == SpeedTestStep.upload) {
      pingStatus = 1;
      downloadStatus = 1;
      uploadStatus = 0;
    } else {
      pingStatus = -1;
      downloadStatus = -1;
      uploadStatus = -1;
    }

    final segments = <_PhaseSegmentData>[
      _PhaseSegmentData(
        label: tr.translate('speed_test.ping'),
        color: _kWhite,
        status: pingStatus,
      ),
      _PhaseSegmentData(
        label: tr.translate('speed_test.download'),
        color: _kWhite,
        status: downloadStatus,
      ),
      _PhaseSegmentData(
        label: tr.translate('speed_test.upload'),
        color: _kWhite,
        status: uploadStatus,
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < segments.length; i++) ...[
          Expanded(child: _PhaseSegment(data: segments[i])),
          if (i < segments.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _PhaseSegmentData {
  final String label;
  final Color color;
  // -1 pending, 0 active, 1 done
  final int status;
  _PhaseSegmentData({
    required this.label,
    required this.color,
    required this.status,
  });
}

class _PhaseSegment extends StatelessWidget {
  final _PhaseSegmentData data;
  const _PhaseSegment({required this.data});

  @override
  Widget build(BuildContext context) {
    final isActive = data.status == 0;
    final isDone = data.status == 1;
    final highlight = isActive || isDone;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          data.label.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: highlight
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          height: 3,
          decoration: BoxDecoration(
            color: highlight
                ? data.color
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(2),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: data.color.withValues(alpha: 0.55),
                      blurRadius: 8,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
        ),
      ],
    );
  }
}

// ─── Primary button ────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final SpeedTestProvider provider;
  final SpeedTestState state;
  const _PrimaryButton({required this.provider, required this.state});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final isRunning = state.step != SpeedTestStep.ready;
    final isStop = isRunning;
    final label = isRunning
        ? tr.translate('speed_test.stop')
        : (state.testCompleted
            ? tr.translate('speed_test.test_again')
            : tr.translate('speed_test.start_test'));

    // Monochrome only.
    //   • Idle / again: solid white pill with black label.
    //   • Running:      transparent pill with a white outline (stop).
    final Color background =
        isStop ? Colors.transparent : _kWhite;
    final Color borderColor =
        isStop ? Colors.white.withValues(alpha: 0.45) : Colors.transparent;
    final Color foreground = isStop ? _kWhite : Colors.black;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: GestureDetector(
        onTap: () {
          if (isRunning) {
            provider.stopTest();
          } else {
            AnalyticsService().logSpeedTestStart();
            provider.startTest();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isStop
                    ? Icons.stop_rounded
                    : (state.testCompleted
                        ? Icons.refresh_rounded
                        : Icons.play_arrow_rounded),
                color: foreground,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline,
              color: Colors.white.withValues(alpha: 0.85), size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              msg,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

Color _phaseColor(SpeedTestStep s) => _kWhite;

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

String? _phaseLabel(SpeedTestStep s, AppLocalizations tr,
    {bool completed = false}) {
  switch (s) {
    case SpeedTestStep.download:
      return tr.translate('speed_test.download').toUpperCase();
    case SpeedTestStep.upload:
      return tr.translate('speed_test.upload').toUpperCase();
    case SpeedTestStep.loading:
      return null;
    case SpeedTestStep.ready:
      return completed
          ? tr.translate('speed_test.download').toUpperCase()
          : null;
  }
}
