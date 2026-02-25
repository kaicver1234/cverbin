import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/cyber_glow_background.dart';
import '../widgets/app_background.dart';
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

  // Quick access hosts - more popular sites
  final List<Map<String, dynamic>> _quickHosts = [
    {'name': 'Google', 'host': 'google.com', 'icon': Icons.search, 'color': Color(0xFF4285F4)},
    {'name': 'Instagram', 'host': 'instagram.com', 'icon': Icons.camera_alt, 'color': Color(0xFFE1306C)},
    {'name': 'YouTube', 'host': 'youtube.com', 'icon': Icons.play_circle_filled, 'color': Color(0xFFFF0000)},
    {'name': 'Twitter', 'host': 'x.com', 'icon': Icons.tag, 'color': Color(0xFF1DA1F2)},
    {'name': 'Facebook', 'host': 'facebook.com', 'icon': Icons.facebook, 'color': Color(0xFF1877F2)},
    {'name': 'GitHub', 'host': 'github.com', 'icon': Icons.code, 'color': Color(0xFF181717)},
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
        const Color(0xFF00FFA3),
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
    return Consumer2<LanguageProvider, ThemeProvider>(
      builder: (context, languageProvider, themeProvider, child) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: AppBackground(
            useSecondaryBackground: true,
            child: CyberGlowBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    _buildAppBar(context, themeProvider.colors),
                    Expanded(
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(child: _buildSearchSection(themeProvider.colors)),
                          SliverToBoxAdapter(child: _buildQuickAccessSection(themeProvider.colors)),
                          _buildResultsSection(themeProvider.colors),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, ThemeColors colors) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 16 : 20,
        isSmallScreen ? 12 : 16,
        isSmallScreen ? 16 : 20,
        isSmallScreen ? 12 : 16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: isSmallScreen ? 40 : 44,
              height: isSmallScreen ? 40 : 44,
              decoration: BoxDecoration(
                color: Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(colors.borderColor).withValues(alpha: 0.1)),
              ),
              child: Consumer<LanguageProvider>(
                builder: (context, langProvider, _) => Icon(
                  langProvider.isRtl ? Icons.arrow_forward_ios : Icons.arrow_back_ios_new,
                  color: Color(colors.textPrimaryColor),
                  size: isSmallScreen ? 18 : 20,
                ),
              ),
            ),
          ).animate().fadeIn().slideX(),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).translate('host_checker.title'),
                  style: GoogleFonts.poppins(
                    fontSize: isSmallScreen ? 18 : 22,
                    fontWeight: FontWeight.w700,
                    color: Color(colors.textPrimaryColor),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  AppLocalizations.of(context).translate('host_checker.start_checking'),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: Color(colors.textSecondaryColor).withValues(alpha: 0.5),
                  ),
                ),
              ],
            ).animate().fadeIn().slideX(),
          ),
          if (_results.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _results.clear()),
              child: Container(
                width: isSmallScreen ? 40 : 44,
                height: isSmallScreen ? 40 : 44,
                decoration: BoxDecoration(
                  color: Color(colors.errorColor).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(colors.errorColor).withValues(alpha: 0.3)),
                ),
                child: Icon(
                  Icons.delete_sweep_rounded,
                  color: Color(colors.errorColor),
                  size: isSmallScreen ? 20 : 22,
                ),
              ),
            ).animate().fadeIn().scale(),
        ],
      ),
    );
  }

  Widget _buildSearchSection(ThemeColors colors) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      margin: EdgeInsets.fromLTRB(
        isSmallScreen ? 16 : 20,
        8,
        isSmallScreen ? 16 : 20,
        isSmallScreen ? 12 : 16,
      ),
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
              boxShadow: _isChecking
                  ? [
                      BoxShadow(
                        color: Color(colors.primaryColor).withValues(alpha: 0.3 * _glowController.value),
                        blurRadius: isSmallScreen ? 16 : 20,
                        spreadRadius: isSmallScreen ? 1 : 2,
                      ),
                    ]
                  : null,
            ),
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity),
            borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
            border: Border.all(color: Color(colors.borderColor).withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hostController,
                  style: TextStyle(
                    color: Color(colors.textPrimaryColor),
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).translate('host_checker.enter_host'),
                    hintStyle: TextStyle(
                      color: Color(colors.textSecondaryColor).withValues(alpha: 0.35),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 20,
                      vertical: isSmallScreen ? 14 : 18,
                    ),
                    prefixIcon: Icon(
                      Icons.language_rounded,
                      color: Color(colors.textSecondaryColor).withValues(alpha: 0.5),
                      size: isSmallScreen ? 20 : 22,
                    ),
                  ),
                  onSubmitted: (value) => _checkHost(value),
                ),
              ),
              GestureDetector(
                onTap: _isChecking ? null : () => _checkHost(_hostController.text),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.all(6),
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isChecking
                          ? [const Color(0xFF4B5563), const Color(0xFF374151)]
                          : [Color(colors.primaryColor), Color(colors.secondaryColor)],
                    ),
                    borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 14),
                    boxShadow: _isChecking
                        ? null
                        : [
                            BoxShadow(
                              color: Color(colors.primaryColor).withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: _isChecking
                      ? SizedBox(
                          width: isSmallScreen ? 18 : 20,
                          height: isSmallScreen ? 18 : 20,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Icon(
                          Icons.search_rounded,
                          color: Colors.white,
                          size: isSmallScreen ? 20 : 22,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildQuickAccessSection(ThemeColors colors) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      margin: EdgeInsets.fromLTRB(
        isSmallScreen ? 16 : 20,
        0,
        isSmallScreen ? 16 : 20,
        isSmallScreen ? 16 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: isSmallScreen ? 10 : 12),
            child: Text(
              AppLocalizations.of(context).translate('host_checker.quick_check'),
              style: GoogleFonts.poppins(
                color: Color(colors.textSecondaryColor).withValues(alpha: 0.6),
                fontSize: isSmallScreen ? 12 : 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Wrap(
            spacing: isSmallScreen ? 8 : 10,
            runSpacing: isSmallScreen ? 8 : 10,
            children: _quickHosts.asMap().entries.map((entry) {
              final index = entry.key;
              final host = entry.value;
              return GestureDetector(
                onTap: _isChecking ? null : () => _checkHost(host['host']),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 14,
                    vertical: isSmallScreen ? 9 : 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (host['color'] as Color).withValues(alpha: 0.15),
                        (host['color'] as Color).withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (host['color'] as Color).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        host['icon'],
                        color: host['color'],
                        size: isSmallScreen ? 16 : 18,
                      ),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      Text(
                        host['name'],
                        style: TextStyle(
                          color: Color(colors.textPrimaryColor).withValues(alpha: 0.85),
                          fontSize: isSmallScreen ? 12 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate(delay: Duration(milliseconds: 50 * index))
                  .fadeIn()
                  .scale(begin: const Offset(0.9, 0.9));
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(ThemeColors colors) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    if (_results.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(colors),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildResultCard(_results[index], index, colors),
          childCount: _results.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeColors colors) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isSmallScreen ? 90 : 100,
              height: isSmallScreen ? 90 : 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color(colors.primaryColor).withValues(alpha: 0.2),
                    Color(colors.secondaryColor).withValues(alpha: 0.1),
                  ],
                ),
                border: Border.all(
                  color: Color(colors.primaryColor).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.dns_rounded,
                size: isSmallScreen ? 40 : 45,
                color: Color(colors.primaryColor).withValues(alpha: 0.7),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.05, 1.05),
                  duration: const Duration(seconds: 2),
                ),
            SizedBox(height: isSmallScreen ? 20 : 24),
            Text(
              AppLocalizations.of(context).translate('host_checker.no_results'),
              style: GoogleFonts.poppins(
                color: Color(colors.textPrimaryColor).withValues(alpha: 0.7),
                fontSize: isSmallScreen ? 15 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              AppLocalizations.of(context).translate('host_checker.enter_host_to_check'),
              style: TextStyle(
                color: Color(colors.textSecondaryColor).withValues(alpha: 0.4),
                fontSize: isSmallScreen ? 12 : 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(HostCheckResult result, int index, ThemeColors colors) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isSuccess = result.isSuccess;
    final statusColor = isSuccess ? Color(colors.successColor) : Color(colors.errorColor);

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 12),
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
            borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
            child: Row(
              children: [
                // Status Icon
                Container(
                  width: isSmallScreen ? 44 : 48,
                  height: isSmallScreen ? 44 : 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withValues(alpha: 0.2),
                        statusColor.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: statusColor,
                    size: isSmallScreen ? 24 : 26,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.host,
                        style: GoogleFonts.poppins(
                          color: Color(colors.textPrimaryColor),
                          fontSize: isSmallScreen ? 14 : 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 5 : 6),
                      Wrap(
                        spacing: isSmallScreen ? 6 : 8,
                        runSpacing: 4,
                        children: [
                          _buildStatusBadge(result.status, statusColor, isSmallScreen),
                          if (result.statusCode > 0)
                            _buildInfoChip(Icons.code, '${result.statusCode}', colors, isSmallScreen),
                          if (result.responseTime > 0)
                            _buildInfoChip(Icons.timer_outlined, '${result.responseTime}ms', colors, isSmallScreen),
                        ],
                      ),
                      if (result.error != null) ...[
                        SizedBox(height: isSmallScreen ? 5 : 6),
                        Text(
                          result.error!,
                          style: TextStyle(
                            color: statusColor.withValues(alpha: 0.8),
                            fontSize: isSmallScreen ? 10 : 11,
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
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 6 : 7),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isSuccess ? Icons.wifi : Icons.wifi_off,
                        color: statusColor,
                        size: isSmallScreen ? 16 : 18,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 5 : 6),
                    Text(
                      _formatTime(result.timestamp),
                      style: TextStyle(
                        color: Color(colors.textSecondaryColor).withValues(alpha: 0.35),
                        fontSize: isSmallScreen ? 10 : 11,
                        fontWeight: FontWeight.w500,
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

  Widget _buildStatusBadge(String status, Color color, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 7 : 8,
        vertical: isSmallScreen ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: isSmallScreen ? 9 : 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, ThemeColors colors, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 6 : 7,
        vertical: isSmallScreen ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Color(colors.borderColor).withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Color(colors.textSecondaryColor).withValues(alpha: 0.5),
            size: isSmallScreen ? 11 : 12,
          ),
          SizedBox(width: isSmallScreen ? 3 : 4),
          Text(
            text,
            style: TextStyle(
              color: Color(colors.textSecondaryColor).withValues(alpha: 0.6),
              fontSize: isSmallScreen ? 10 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
