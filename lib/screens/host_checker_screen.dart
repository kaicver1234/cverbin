import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../utils/app_localizations.dart';
import '../services/analytics_service.dart';

// ─── Colors ───────────────────────────────────────────────────────────────────

const _kCyan    = Color(0xFF00D9FF);
const _kGreen   = Color(0xFF00FFA3);
const _kRed     = Color(0xFFEF4444);
const _kAmber   = Color(0xFFF59E0B);
const _kSurface = Color(0xFF0D0D0D);
const _kCard    = Color(0xFF111111);

// ─── Model ────────────────────────────────────────────────────────────────────

class HostCheckResult {
  final String host;
  final String status;
  final int statusCode;
  final int responseTime;
  final DateTime timestamp;
  final bool isSuccess;
  final String? error;

  HostCheckResult({
    required this.host,
    required this.status,
    required this.statusCode,
    required this.responseTime,
    required this.timestamp,
    required this.isSuccess,
    this.error,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class HostCheckerScreen extends StatefulWidget {
  const HostCheckerScreen({super.key});

  @override
  State<HostCheckerScreen> createState() => _HostCheckerScreenState();
}

class _HostCheckerScreenState extends State<HostCheckerScreen>
    with TickerProviderStateMixin {
  final TextEditingController _hostController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<HostCheckResult> _results = [];
  bool _isChecking = false;

  late AnimationController _radarController;
  late AnimationController _pulseController;

  static const _quickHosts = [
    {'name': 'Google', 'host': 'google.com', 'color': Color(0xFF4285F4)},
    {'name': 'YouTube', 'host': 'youtube.com', 'color': Color(0xFFFF0000)},
    {'name': 'Instagram', 'host': 'instagram.com', 'color': Color(0xFFE1306C)},
    {'name': 'Twitter', 'host': 'x.com', 'color': Color(0xFF1DA1F2)},
    {'name': 'Facebook', 'host': 'facebook.com', 'color': Color(0xFF1877F2)},
    {'name': 'GitHub', 'host': 'github.com', 'color': Color(0xFF6e40c9)},
    {'name': 'Telegram', 'host': 'telegram.org', 'color': Color(0xFF2CA5E0)},
    {'name': 'Cloudflare', 'host': '1.1.1.1', 'color': Color(0xFFF38020)},
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsService().logScreenView(screenName: 'Safheh_Baresi_Host');
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _focusNode.dispose();
    _radarController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkHost(String host) async {
    if (host.trim().isEmpty) return;
    _focusNode.unfocus();
    HapticFeedback.lightImpact();

    setState(() => _isChecking = true);
    _radarController.repeat();
    _pulseController.repeat(reverse: true);

    final startTime = DateTime.now();

    try {
      String cleanHost = host.trim();
      if (!cleanHost.startsWith('http://') && !cleanHost.startsWith('https://')) {
        cleanHost = 'https://$cleanHost';
      }

      final uri = Uri.parse(cleanHost);
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('timeout'),
      );

      if (!mounted) return;

      final ms = DateTime.now().difference(startTime).inMilliseconds;
      final ok = response.statusCode >= 200 && response.statusCode < 400;

      HapticFeedback.mediumImpact();
      AnalyticsService().logHostCheck(
        host: uri.host,
        isReachable: ok,
        responseTimeMs: ms,
      );
      setState(() {
        _results.insert(
          0,
          HostCheckResult(
            host: uri.host,
            status: ok ? 'ONLINE' : 'ERROR',
            statusCode: response.statusCode,
            responseTime: ms,
            timestamp: DateTime.now(),
            isSuccess: ok,
          ),
        );
        if (_results.length > 20) _results.removeLast();
        _hostController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();

      String err;
      if (e is TimeoutException) {
        err = 'Timeout';
      } else if (e.toString().contains('Failed host lookup')) {
        err = 'Host not found';
      } else if (e.toString().contains('Connection refused')) {
        err = 'Connection refused';
      } else {
        err = 'Unreachable';
      }

      setState(() {
        _results.insert(
          0,
          HostCheckResult(
            host: host.trim(),
            status: 'OFFLINE',
            statusCode: 0,
            responseTime: 0,
            timestamp: DateTime.now(),
            isSuccess: false,
            error: err,
          ),
        );
        if (_results.length > 20) _results.removeLast();
      });
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
        _radarController.stop();
        _radarController.reset();
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = context.watch<LanguageProvider>().isRtl;
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _kSurface,
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                isChecking: _isChecking,
                hasResults: _results.isNotEmpty,
                onBack: () => Navigator.pop(context),
                onClear: () => setState(() => _results.clear()),
                isRtl: isRtl,
              ),
              _InputBar(
                controller: _hostController,
                focusNode: _focusNode,
                isChecking: _isChecking,
                onSubmit: _checkHost,
              ),
              _QuickRow(
                hosts: _quickHosts,
                isChecking: _isChecking,
                onTap: _checkHost,
              ),
              Expanded(
                child: _isChecking && _results.isEmpty
                    ? _ScanningState(
                        radarCtrl: _radarController,
                        pulseCtrl: _pulseController,
                      )
                    : _results.isEmpty
                        ? const _EmptyState()
                        : _ResultList(
                            results: _results,
                            isChecking: _isChecking,
                            radarCtrl: _radarController,
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool isChecking;
  final bool hasResults;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final bool isRtl;

  const _Header({
    required this.isChecking,
    required this.hasResults,
    required this.onBack,
    required this.onClear,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Icon(
                isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                color: Colors.white70,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).translate('host_checker.title'),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  AppLocalizations.of(context).translate('host_checker.start_checking'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: hasResults
                ? GestureDetector(
                    key: const ValueKey('clear'),
                    onTap: onClear,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _kRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: _kRed.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_sweep_rounded,
                        color: _kRed,
                        size: 20,
                      ),
                    ),
                  )
                : const SizedBox(key: ValueKey('empty'), width: 40),
          ),
        ],
      ),
    );
  }
}

// ─── Input Bar ───────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isChecking;
  final ValueChanged<String> onSubmit;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isChecking,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isChecking
                ? _kCyan.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.language_rounded, color: Colors.white30, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: GoogleFonts.robotoMono(
                  fontSize: 14,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).translate('host_checker.enter_host'),
                  hintStyle: GoogleFonts.robotoMono(
                    fontSize: 13,
                    color: Colors.white24,
                    decoration: TextDecoration.none,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: onSubmit,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.search,
              ),
            ),
            GestureDetector(
              onTap: isChecking ? null : () => onSubmit(controller.text),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.all(6),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: isChecking
                      ? null
                      : const LinearGradient(
                          colors: [_kCyan, _kGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: isChecking ? Colors.white10 : null,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: isChecking
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: _kCyan,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : const Icon(Icons.wifi_find_rounded, color: Colors.black, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Row ───────────────────────────────────────────────────────────────

class _QuickRow extends StatelessWidget {
  final List<Map<String, dynamic>> hosts;
  final bool isChecking;
  final ValueChanged<String> onTap;

  const _QuickRow({
    required this.hosts,
    required this.isChecking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: hosts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final h = hosts[i];
          final color = h['color'] as Color;
          return GestureDetector(
            onTap: isChecking ? null : () => onTap(h['host'] as String),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 0),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.22)),
              ),
              alignment: Alignment.center,
              child: Text(
                h['name'] as String,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Scanning State ───────────────────────────────────────────────────────────

class _ScanningState extends StatelessWidget {
  final AnimationController radarCtrl;
  final AnimationController pulseCtrl;

  const _ScanningState({
    required this.radarCtrl,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Modern loading animation
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: radarCtrl,
              builder: (_, __) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulsing circle
                    AnimatedBuilder(
                      animation: pulseCtrl,
                      builder: (_, __) {
                        final scale = 1.0 + (pulseCtrl.value * 0.3);
                        final opacity = 0.3 - (pulseCtrl.value * 0.2);
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _kCyan.withValues(alpha: opacity),
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    // Middle circle
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kCyan.withValues(alpha: 0.08),
                        border: Border.all(
                          color: _kCyan.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                    ),
                    
                    // Rotating dots
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        children: List.generate(3, (index) {
                          final angle = (radarCtrl.value * 2 * math.pi) + (index * 2 * math.pi / 3);
                          final x = 30 * math.cos(angle);
                          final y = 30 * math.sin(angle);
                          
                          return Transform.translate(
                            offset: Offset(x + 40, y + 40),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _kCyan,
                                boxShadow: [
                                  BoxShadow(
                                    color: _kCyan.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    
                    // Center icon
                    const Icon(
                      Icons.wifi_find_rounded,
                      color: _kCyan,
                      size: 32,
                    ),
                  ],
                );
              },
            ),
          ),
          
          const SizedBox(height: 28),
          
          // Animated text
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) {
              final opacity = 0.6 + (pulseCtrl.value * 0.4);
              return Text(
                'SCANNING...',
                style: GoogleFonts.robotoMono(
                  fontSize: 13,
                  color: _kCyan.withValues(alpha: opacity),
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _kCyan.withValues(alpha: 0.2),
                width: 1.5,
              ),
              color: _kCyan.withValues(alpha: 0.04),
            ),
            child: const Icon(
              Icons.radar_rounded,
              size: 38,
              color: _kCyan,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context).translate('host_checker.no_results'),
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).translate('host_checker.enter_host_to_check'),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white30,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Result List ─────────────────────────────────────────────────────────────

class _ResultList extends StatelessWidget {
  final List<HostCheckResult> results;
  final bool isChecking;
  final AnimationController radarCtrl;

  const _ResultList({
    required this.results,
    required this.isChecking,
    required this.radarCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      physics: const BouncingScrollPhysics(),
      itemCount: results.length + (isChecking ? 1 : 0),
      itemBuilder: (context, index) {
        if (isChecking && index == 0) {
          return _ScanningListTile(radarCtrl: radarCtrl);
        }
        final result = results[isChecking ? index - 1 : index];
        return _ResultTile(result: result, isFirst: index == (isChecking ? 1 : 0));
      },
    );
  }
}

// ─── Scanning List Tile ───────────────────────────────────────────────────────

class _ScanningListTile extends StatelessWidget {
  final AnimationController radarCtrl;

  const _ScanningListTile({required this.radarCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCyan.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Simple rotating icon instead of radar
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: radarCtrl,
              builder: (_, __) {
                return Transform.rotate(
                  angle: radarCtrl.value * 2 * math.pi,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kCyan.withValues(alpha: 0.1),
                      border: Border.all(
                        color: _kCyan.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.wifi_find_rounded,
                      color: _kCyan,
                      size: 16,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Scanning...',
            style: GoogleFonts.robotoMono(
              fontSize: 13,
              color: _kCyan,
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              color: _kCyan,
              strokeWidth: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Result Tile ─────────────────────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  final HostCheckResult result;
  final bool isFirst;

  const _ResultTile({required this.result, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    final color = result.isSuccess ? _kGreen : _kRed;
    final pingColor = _pingColor(result.responseTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFirst
              ? color.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
          width: isFirst ? 1.2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: isFirst
                  ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Host
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.host,
                  style: GoogleFonts.robotoMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.87),
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _Badge(label: result.status, color: color),
                    if (result.statusCode > 0) ...[
                      const SizedBox(width: 6),
                      _Badge(label: '${result.statusCode}', color: Colors.white24),
                    ],
                    if (result.responseTime > 0) ...[
                      const SizedBox(width: 6),
                      _Badge(label: '${result.responseTime}ms', color: pingColor),
                    ],
                    if (result.error != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          result.error!,
                          style: TextStyle(
                            fontSize: 10,
                            color: _kRed.withValues(alpha: 0.7),
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Time
          Text(
            _fmt(result.timestamp),
            style: GoogleFonts.robotoMono(
              fontSize: 10,
              color: Colors.white24,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Color _pingColor(int ms) {
    if (ms <= 0) return _kRed;
    if (ms <= 500) return _kGreen;
    if (ms <= 1000) return _kAmber;
    return _kRed;
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

// ─── Badge ────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.robotoMono(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color == Colors.white24 ? Colors.white54 : color,
          letterSpacing: 0.5,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}


