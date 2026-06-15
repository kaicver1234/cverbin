import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../utils/app_localizations.dart';
import '../utils/responsive_helper.dart';
import '../services/analytics_service.dart';
import '../widgets/app_background.dart';
import '../widgets/wave_loading.dart';

// ─── Design tokens (aligned with the app's main theme) ─────────────────────────

const _kCard   = Color(0xFF111111);
const _kBorder = Color(0xFF222222);
const _kAccent = Color(0xFFFF6B9D); // host-checker tool color (see home tools)
const _kGreen  = Color(0xFF00FFA3);
const _kRed    = Color(0xFFEF4444);
const _kAmber  = Color(0xFFF59E0B);

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

class _HostCheckerScreenState extends State<HostCheckerScreen> {
  final TextEditingController _hostController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<HostCheckResult> _results = [];
  bool _isChecking = false;

  static const _quickHosts = [
    {'name': 'Google', 'host': 'google.com', 'color': Color(0xFF4285F4)},
    {'name': 'YouTube', 'host': 'youtube.com', 'color': Color(0xFFFF0000)},
    {'name': 'Instagram', 'host': 'instagram.com', 'color': Color(0xFFE1306C)},
    {'name': 'Twitter', 'host': 'x.com', 'color': Color(0xFF1DA1F2)},
    {'name': 'Facebook', 'host': 'facebook.com', 'color': Color(0xFF1877F2)},
    {'name': 'GitHub', 'host': 'github.com', 'color': Color(0xFF6e40c9)},
    {'name': 'Telegram', 'host': 'telegram.org', 'color': Color(0xFF2CA5E0)},
    {'name': 'Cloudflare', 'host': 'cloudflare.com', 'color': Color(0xFFF38020)},
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsService().logScreenView(screenName: 'Safheh_Baresi_Host');
  }

  @override
  void dispose() {
    _hostController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Maximum time to wait for a TCP connection before giving up.
  static const Duration _connectTimeout = Duration(seconds: 8);

  /// How many TCP handshakes to perform per check. We report the *fastest* of
  /// these, which best reflects the true round-trip time and smooths out the
  /// random jitter of any single sample.
  static const int _probeCount = 3;

  /// Measures the round-trip latency to [host]:[port] in milliseconds.
  ///
  /// A reachability check must NOT download the page body — the old version did
  /// a full `http.get`, which timed out on heavy sites like YouTube (large body
  /// + redirects to consent pages) even though the browser opens them instantly.
  /// A TCP handshake reflects exactly what "can I reach this host" means and is
  /// fast and reliable through the VPN tunnel.
  ///
  /// DNS is resolved *outside* the timer on purpose. `Socket.connect(hostname,…)`
  /// folds the one-time DNS lookup into the measurement, so the first check of a
  /// host reads high (cold DNS, e.g. ~300ms) while later checks read low (the OS
  /// DNS cache is warm, e.g. ~18ms) — which looks like a bug. Timing only the
  /// handshake to an already-resolved IP keeps the result stable from the very
  /// first check, and we take the fastest of [_probeCount] handshakes.
  Future<int> _tcpConnect(String host, int port) async {
    // Resolve once, up front. Throws SocketException on DNS failure, which the
    // caller maps to "Host not found".
    final addresses = await InternetAddress.lookup(host);
    final addr = addresses.firstWhere(
      (a) => a.type == InternetAddressType.IPv4,
      orElse: () => addresses.first,
    );

    int? best;
    SocketException? lastError;
    for (var i = 0; i < _probeCount; i++) {
      try {
        final sw = Stopwatch()..start();
        final socket = await Socket.connect(addr, port, timeout: _connectTimeout);
        sw.stop();
        socket.destroy();
        final ms = sw.elapsedMilliseconds;
        if (best == null || ms < best) best = ms;
      } on SocketException catch (e) {
        lastError = e;
        // "Connection refused" means the port is closed on this host. Retrying
        // won't help; if we have no good sample yet, surface it so the caller
        // can fall back to port 80.
        final msg = (e.osError?.message ?? e.message).toLowerCase();
        if (msg.contains('refused')) {
          if (best != null) break;
          rethrow;
        }
      }
    }

    if (best == null) {
      throw lastError ?? const SocketException('Unreachable');
    }
    return best;
  }

  Future<void> _checkHost(String host) async {
    if (host.trim().isEmpty || _isChecking) return;
    _focusNode.unfocus();
    HapticFeedback.lightImpact();

    setState(() => _isChecking = true);

    // Extract a clean hostname + port from whatever the user typed
    // (e.g. "youtube.com", "https://youtube.com/watch?v=x", "1.1.1.1:80").
    final raw = host.trim();
    final parsed = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
    final hostname =
        (parsed != null && parsed.host.isNotEmpty) ? parsed.host : raw;
    final port = (parsed != null && parsed.hasPort)
        ? parsed.port
        : (parsed?.scheme == 'http' ? 80 : 443);

    try {
      int ms;
      try {
        ms = await _tcpConnect(hostname, port);
      } on SocketException catch (e) {
        // If HTTPS (443) was refused, the host may only serve plain HTTP — try 80.
        final refused =
            (e.osError?.message ?? e.message).toLowerCase().contains('refused');
        if (port == 443 && refused) {
          ms = await _tcpConnect(hostname, 80);
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      HapticFeedback.mediumImpact();
      AnalyticsService().logHostCheck(
        host: hostname,
        isReachable: true,
        responseTimeMs: ms,
      );
      setState(() {
        _results.insert(
          0,
          HostCheckResult(
            host: hostname,
            status: 'ONLINE',
            statusCode: 0,
            responseTime: ms <= 0 ? 1 : ms,
            timestamp: DateTime.now(),
            isSuccess: true,
          ),
        );
        if (_results.length > 20) _results.removeLast();
        _hostController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();

      String err;
      if (e is SocketException) {
        final msg = (e.osError?.message ?? e.message).toLowerCase();
        if (e.message.toLowerCase().contains('failed host lookup') ||
            msg.contains('lookup') ||
            msg.contains('not known') ||
            msg.contains('no address')) {
          err = 'Host not found';
        } else if (msg.contains('refused')) {
          err = 'Connection refused';
        } else if (msg.contains('timed out') || msg.contains('timeout')) {
          err = 'Timeout';
        } else {
          err = 'Unreachable';
        }
      } else if (e is TimeoutException) {
        err = 'Timeout';
      } else {
        err = 'Unreachable';
      }

      AnalyticsService().logHostCheck(
        host: hostname,
        isReachable: false,
        responseTimeMs: 0,
      );
      setState(() {
        _results.insert(
          0,
          HostCheckResult(
            host: hostname,
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = context.watch<LanguageProvider>().isRtl;
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: ResponsivePageWrapper(
              child: Column(
                children: [
                  _Header(
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
                        ? const _ScanningState()
                        : _results.isEmpty
                            ? const _EmptyState()
                            : _ResultList(
                                results: _results,
                                isChecking: _isChecking,
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool hasResults;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final bool isRtl;

  const _Header({
    required this.hasResults,
    required this.onBack,
    required this.onClear,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveHelper(context);
    final btn = r.scale(40).clamp(36.0, 50.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.horizontalPadding,
        r.scale(12).clamp(8.0, 18.0),
        r.horizontalPadding,
        r.scale(8).clamp(6.0, 14.0),
      ),
      child: Row(
        children: [
          _SquareIconButton(
            size: btn,
            icon: isRtl
                ? Icons.arrow_forward_ios_rounded
                : Icons.arrow_back_ios_new_rounded,
            onTap: onBack,
          ),
          SizedBox(width: r.scale(12).clamp(8.0, 16.0)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).translate('host_checker.title'),
                  style: GoogleFonts.poppins(
                    fontSize: r.scale(20).clamp(16.0, 26.0),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)
                      .translate('host_checker.start_checking'),
                  style: GoogleFonts.poppins(
                    fontSize: r.scale(11).clamp(9.5, 13.5),
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: hasResults
                ? _SquareIconButton(
                    key: const ValueKey('clear'),
                    size: btn,
                    icon: Icons.delete_sweep_rounded,
                    color: _kRed,
                    onTap: onClear,
                  )
                : SizedBox(key: const ValueKey('empty'), width: btn),
          ),
        ],
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final double size;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _SquareIconButton({
    super.key,
    required this.size,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: (c ?? Colors.white).withValues(alpha: c != null ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (c ?? Colors.white).withValues(alpha: c != null ? 0.25 : 0.08),
            ),
          ),
          child: Icon(
            icon,
            color: c ?? Colors.white70,
            size: size * 0.45,
          ),
        ),
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
    final r = ResponsiveHelper(context);
    final h = r.scale(54).clamp(48.0, 64.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.horizontalPadding,
        0,
        r.horizontalPadding,
        r.scale(12).clamp(8.0, 16.0),
      ),
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isChecking
                ? _kAccent.withValues(alpha: 0.45)
                : _kBorder,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.language_rounded,
                color: Colors.white.withValues(alpha: 0.3), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: GoogleFonts.robotoMono(
                  fontSize: 14,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)
                      .translate('host_checker.enter_host'),
                  hintStyle: GoogleFonts.robotoMono(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.24),
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
                width: h - 12,
                height: h - 12,
                decoration: BoxDecoration(
                  color: isChecking
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: isChecking
                    ? const Center(
                        child: WaveLoading.small(color: Colors.white54),
                      )
                    : const Icon(Icons.search_rounded,
                        color: Colors.black, size: 20),
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
    final r = ResponsiveHelper(context);
    return SizedBox(
      height: r.scale(36).clamp(32.0, 44.0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: r.horizontalPadding),
        physics: const BouncingScrollPhysics(),
        itemCount: hosts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final host = hosts[i];
          final color = host['color'] as Color;
          return GestureDetector(
            onTap: isChecking ? null : () => onTap(host['host'] as String),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.22)),
              ),
              alignment: Alignment.center,
              child: Text(
                host['name'] as String,
                style: GoogleFonts.poppins(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
  const _ScanningState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const WaveLoading(),
          const SizedBox(height: 28),
          Text(
            '${AppLocalizations.of(context).translate('host_checker.quick_check')}...',
            style: GoogleFonts.robotoMono(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 1,
              fontWeight: FontWeight.w500,
            ),
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
    final r = ResponsiveHelper(context);
    final box = r.scale(80).clamp(64.0, 104.0);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: box,
            height: box,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
              color: Colors.white.withValues(alpha: 0.03),
            ),
            child: Icon(
              Icons.language_rounded,
              size: box * 0.46,
              color: _kAccent.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context).translate('host_checker.no_results'),
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)
                .translate('host_checker.enter_host_to_check'),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.3),
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

  const _ResultList({
    required this.results,
    required this.isChecking,
  });

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveHelper(context);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        r.horizontalPadding,
        r.scale(16).clamp(12.0, 22.0),
        r.horizontalPadding,
        r.scale(80).clamp(60.0, 110.0),
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: results.length + (isChecking ? 1 : 0),
      itemBuilder: (context, index) {
        if (isChecking && index == 0) {
          return const _ScanningListTile();
        }
        final result = results[isChecking ? index - 1 : index];
        return _ResultTile(
          result: result,
          isFirst: index == (isChecking ? 1 : 0),
        );
      },
    );
  }
}

// ─── Scanning List Tile ───────────────────────────────────────────────────────

class _ScanningListTile extends StatelessWidget {
  const _ScanningListTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const WaveLoading.small(),
          const SizedBox(width: 14),
          Text(
            '${AppLocalizations.of(context).translate('host_checker.quick_check')}...',
            style: GoogleFonts.robotoMono(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
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
                          style: GoogleFonts.robotoMono(
                            fontSize: 10,
                            color: _kRed.withValues(alpha: 0.7),
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
          Text(
            _fmt(result.timestamp),
            style: GoogleFonts.robotoMono(
              fontSize: 10,
              color: Colors.white24,
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
        ),
      ),
    );
  }
}
