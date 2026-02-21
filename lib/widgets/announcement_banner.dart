import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/remote_config_service.dart';
import '../providers/language_provider.dart';
import '../utils/app_localizations.dart';

class AnnouncementBannerWidget extends StatefulWidget {
  const AnnouncementBannerWidget({super.key});

  @override
  State<AnnouncementBannerWidget> createState() => _AnnouncementBannerWidgetState();
}

class _AnnouncementBannerWidgetState extends State<AnnouncementBannerWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AnnouncementBanner? _banner;
  bool _isDismissed = false;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    
    _loadBanner();
    _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshBanner();
      _startTimer();
    } else if (state == AppLifecycleState.paused) {
      _refreshTimer?.cancel();
    }
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _refreshBanner();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadBanner() async {
    // Wait for remote config to initialize
    await RemoteConfigService().initialize();
    
    if (!mounted) return;
    
    final banner = RemoteConfigService().getAnnouncementBanner();
    debugPrint('📢 Banner loaded: enabled=${banner.enabled}, message=${banner.message}');
    
    if (banner.enabled && banner.message.isNotEmpty) {
      setState(() {
        _banner = banner;
        _isDismissed = false;
      });
      _controller.forward();
    }
  }

  Future<void> _refreshBanner() async {
    await RemoteConfigService().initialize();
    await RemoteConfigService().refresh();
    final banner = RemoteConfigService().getAnnouncementBanner();
    
    debugPrint('📢 Banner refreshed: enabled=${banner.enabled}, message=${banner.message}');
    
    if (!mounted) return;
    
    if (!banner.enabled || banner.message.isEmpty) {
      if (_banner != null && !_isDismissed) {
        _controller.reverse().then((_) {
          if (mounted) setState(() => _banner = null);
        });
      }
      return;
    }
    
    if (_banner == null || _banner!.message != banner.message) {
      setState(() {
        _banner = banner;
        _isDismissed = false;
      });
      _controller.forward();
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'warning':
        return const Color(0xFFfbbf24);
      case 'error':
        return const Color(0xFFef4444);
      case 'success':
        return const Color(0xFF00FFA3);
      default:
        return const Color(0xFF00D9FF);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) setState(() => _isDismissed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_banner == null || !_banner!.enabled || _isDismissed) {
      return const SizedBox.shrink();
    }

    final color = _getColor(_banner!.type);
    final hasAction = _banner!.actionUrl != null && _banner!.actionUrl!.isNotEmpty;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 14),
          padding: EdgeInsets.fromLTRB(
            isSmallScreen ? 12 : 14,
            isSmallScreen ? 10 : 12,
            isSmallScreen ? 8 : 10,
            isSmallScreen ? 10 : 12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF080808),
                const Color(0xFF040404),
              ],
            ),
            borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 14),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Message row with close button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon indicator
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 6 : 7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getIcon(_banner!.type),
                      color: color,
                      size: isSmallScreen ? 16 : 18,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 10 : 12),
                  // Message text - centered and flexible
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _banner!.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: isSmallScreen ? 12 : 13,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Action button below message (centered)
                        if (hasAction) ...[
                          SizedBox(height: isSmallScreen ? 8 : 10),
                          GestureDetector(
                            onTap: () => _launchUrl(_banner!.actionUrl!),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12 : 14,
                                vertical: isSmallScreen ? 7 : 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    color,
                                    color.withValues(alpha: 0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Consumer<LanguageProvider>(
                                builder: (context, langProvider, _) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _banner!.actionText ?? AppLocalizations.of(context).translate('announcement.view'),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isSmallScreen ? 11 : 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: isSmallScreen ? 4 : 6),
                                    Icon(
                                      langProvider.isRtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: isSmallScreen ? 14 : 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 10),
                  // Close button
                  GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      padding: EdgeInsets.all(isSmallScreen ? 4 : 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: isSmallScreen ? 16 : 18,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'error':
        return Icons.error_outline_rounded;
      case 'success':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}
