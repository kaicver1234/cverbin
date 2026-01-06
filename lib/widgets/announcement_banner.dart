import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/remote_config_service.dart';

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

  void _loadBanner() {
    final banner = RemoteConfigService().getAnnouncementBanner();
    if (banner.enabled && banner.message.isNotEmpty) {
      setState(() {
        _banner = banner;
        _isDismissed = false;
      });
      _controller.forward();
    }
  }

  Future<void> _refreshBanner() async {
    await RemoteConfigService().refresh();
    final banner = RemoteConfigService().getAnnouncementBanner();
    
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
        return const Color(0xFF10b981);
      default:
        return const Color(0xFF6366f1);
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

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1f2e),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Message row with close button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _banner!.message,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 18,
                    ),
                  ),
                ],
              ),
              // Action button below message
              if (hasAction) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _launchUrl(_banner!.actionUrl!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _banner!.actionText ?? 'مشاهده',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
