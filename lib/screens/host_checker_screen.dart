import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../widgets/vpn_gradient_background.dart';
import '../utils/app_localizations.dart';

class HostCheckerScreen extends StatefulWidget {
  const HostCheckerScreen({super.key});

  @override
  State<HostCheckerScreen> createState() => _HostCheckerScreenState();
}

class _HostCheckerScreenState extends State<HostCheckerScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _hostController = TextEditingController();
  final List<HostCheckResult> _results = [];
  final ScrollController _scrollController = ScrollController();
  bool _isChecking = false;
  late AnimationController _glowController;

  // Quick access hosts
  final List<Map<String, dynamic>> _quickHosts = [
    {'name': 'Google', 'host': 'google.com', 'icon': Icons.search},
    {'name': 'Instagram', 'host': 'instagram.com', 'icon': Icons.camera_alt},
    {'name': 'YouTube', 'host': 'youtube.com', 'icon': Icons.play_circle},
    {'name': 'Twitter', 'host': 'x.com', 'icon': Icons.alternate_email},
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _scrollController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _checkHost(String host) async {
    if (host.isEmpty) {
      _showSnackBar(
        AppLocalizations.of(context).translate('host_checker.please_enter_host'),
        const Color(0xFFFFAA66),
      );
      return;
    }

    if (!mounted) return;

    setState(() => _isChecking = true);

    final startTime = DateTime.now();

    try {
      String cleanHost = host.trim();
      if (!cleanHost.startsWith('http://') && !cleanHost.startsWith('https://')) {
        cleanHost = 'https://$cleanHost';
      }

      final uri = Uri.parse(cleanHost);
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Connection timeout'),
      );

      if (!mounted) return;

      final responseTime = DateTime.now().difference(startTime).inMilliseconds;

      setState(() {
        _results.insert(
          0,
          HostCheckResult(
            host: uri.host,
            status: AppLocalizations.of(context).translate('host_checker.online'),
            statusCode: response.statusCode,
            responseTime: responseTime,
            timestamp: DateTime.now(),
            isSuccess: response.statusCode >= 200 && response.statusCode < 400,
          ),
        );
        if (_results.length > 15) _results.removeLast();
        _hostController.clear();
      });

      _showSnackBar(
        AppLocalizations.of(context)
            .translate('host_checker.is_online')
            .replaceAll('{host}', uri.host),
        const Color(0xFF10B981),
      );
    } catch (e) {
      if (!mounted) return;

      String errorMessage;
      if (e is TimeoutException) {
        errorMessage = AppLocalizations.of(context).translate('host_checker.connection_timeout');
      } else if (e.toString().contains('Failed host lookup')) {
        errorMessage = AppLocalizations.of(context).translate('host_checker.host_not_found');
      } else if (e.toString().contains('Connection refused')) {
        errorMessage = AppLocalizations.of(context).translate('host_checker.connection_refused');
      } else {
        errorMessage = AppLocalizations.of(context).translate('host_checker.unknown_error');
      }

      setState(() {
        _results.insert(
          0,
          HostCheckResult(
            host: host,
            status: AppLocalizations.of(context).translate('host_checker.offline'),
            statusCode: 0,
            responseTime: 0,
            timestamp: DateTime.now(),
            isSuccess: false,
            error: errorMessage,
          ),
        );
        if (_results.length > 15) _results.removeLast();
      });

      _showSnackBar(
        AppLocalizations.of(context)
            .translate('host_checker.is_offline')
            .replaceAll('{host}', host)
            .replaceAll('{error}', errorMessage),
        const Color(0xFFEF4444),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: VPNGradientBackground(
            status: VPNBackgroundStatus.disconnected,
            child: SafeArea(
              child: Column(
                children: [
                  _buildAppBar(context),
                  Expanded(
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildSearchSection()),
                        SliverToBoxAdapter(child: _buildQuickAccessSection()),
                        _buildResultsSection(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            ),
          ).animate().fadeIn().slideX(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).translate('host_checker.title'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  AppLocalizations.of(context).translate('host_checker.start_checking'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ).animate().fadeIn().slideX(),
          ),
          if (_results.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _results.clear()),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
              ),
            ).animate().fadeIn().scale(),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: _isChecking
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3 * _glowController.value),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hostController,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).translate('host_checker.enter_host'),
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    prefixIcon: Icon(Icons.language, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  onSubmitted: (value) => _checkHost(value),
                ),
              ),
              GestureDetector(
                onTap: _isChecking ? null : () => _checkHost(_hostController.text),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isChecking
                          ? [const Color(0xFF4B5563), const Color(0xFF374151)]
                          : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _isChecking
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildQuickAccessSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              AppLocalizations.of(context).translate('host_checker.quick_check'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _quickHosts.asMap().entries.map((entry) {
              final index = entry.key;
              final host = entry.value;
              return GestureDetector(
                onTap: _isChecking ? null : () => _checkHost(host['host']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(host['icon'], color: Colors.white.withValues(alpha: 0.7), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        host['name'],
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate(delay: Duration(milliseconds: 50 * index)).fadeIn().scale(begin: const Offset(0.9, 0.9));
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_results.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildResultCard(_results[index], index),
          childCount: _results.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: 0.2),
                  const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
            ),
            child: Icon(
              Icons.dns_outlined,
              size: 45,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                begin: const Offset(1, 1),
                end: const Offset(1.05, 1.05),
                duration: const Duration(seconds: 2),
              ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context).translate('host_checker.no_results'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).translate('host_checker.enter_host_to_check'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(HostCheckResult result, int index) {
    final isSuccess = result.isSuccess;
    final statusColor = isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                statusColor.withValues(alpha: 0.12),
                statusColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: statusColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.host,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildStatusBadge(result.status, statusColor),
                          if (result.statusCode > 0) ...[
                            const SizedBox(width: 8),
                            _buildInfoChip(Icons.code, '${result.statusCode}'),
                          ],
                          if (result.responseTime > 0) ...[
                            const SizedBox(width: 8),
                            _buildInfoChip(Icons.timer_outlined, '${result.responseTime}ms'),
                          ],
                        ],
                      ),
                      if (result.error != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          result.error!,
                          style: TextStyle(
                            color: statusColor.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(
                      isSuccess ? Icons.signal_wifi_4_bar : Icons.signal_wifi_off,
                      color: statusColor.withValues(alpha: 0.8),
                      size: 18,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(result.timestamp),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: 60 * index)).fadeIn().slideX(begin: 0.15, end: 0);
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 12),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

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
