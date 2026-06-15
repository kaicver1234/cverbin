import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/remote_config_service.dart';
import '../providers/language_provider.dart';
import '../utils/app_localizations.dart';
import '../utils/responsive_helper.dart';

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

  // Muted, desaturated accents — no bright/neon tones, blends into the dark UI.
  Color _getColor(String type) {
    switch (type) {
      case 'warning':
        return const Color(0xFFC79A4B); // muted gold
      case 'error':
        return const Color(0xFFB55A5A); // muted brick
      case 'success':
        return const Color(0xFF4F9E84); // muted teal
      default:
        return const Color(0xFF5E8AA6); // muted steel blue
    }
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
        return Icons.campaign_outlined;
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
    final r = ResponsiveHelper(context);
    final isSmallScreen = r.shortestSide < 360;
    final isTablet = r.isTablet;

    // Sizing — tablet a bit more breathing room, small phones stay compact.
    final double padH       = isSmallScreen ? 14 : (isTablet ? 20 : 16);
    final double padV       = isSmallScreen ? 13 : (isTablet ? 18 : 15);
    final double radius     = isSmallScreen ? 16 : (isTablet ? 20 : 18);
    final double msgFont    = isSmallScreen ? 12.5 : (isTablet ? 15 : 13.5);
    final double actionFont = isSmallScreen ? 12 : (isTablet ? 14.5 : 13);
    final double actionIcon = isSmallScreen ? 13 : (isTablet ? 17 : 15);
    final double closeIcon  = isSmallScreen ? 14 : (isTablet ? 18 : 16);
    final double closeBtn   = isSmallScreen ? 24 : (isTablet ? 30 : 26);
    final double leadSize   = isSmallScreen ? 34 : (isTablet ? 44 : 38);
    final double leadIcon   = isSmallScreen ? 18 : (isTablet ? 24 : 20);
    final double bottomMargin = isSmallScreen ? 12 : (isTablet ? 18 : 14);
    final double actionHeight = isSmallScreen ? 36 : (isTablet ? 46 : 40);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: EdgeInsets.only(bottom: bottomMargin),
          decoration: BoxDecoration(
            // Deep, near-black surface — sits quietly inside the dark UI.
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF101011),
                Color(0xFF0A0A0B),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: color.withValues(alpha: 0.22),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                spreadRadius: -4,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              children: [
                // Subtle accent strip on the leading edge (auto-flips with RTL).
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.55),
                          color.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Leading type icon — muted tint, no glow.
                          Container(
                            width: leadSize,
                            height: leadSize,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(leadSize * 0.3),
                              border: Border.all(
                                color: color.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              _getIcon(_banner!.type),
                              color: color.withValues(alpha: 0.9),
                              size: leadIcon,
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 10 : 12),

                          // Message — leading-aligned, space reserved for close button.
                          Expanded(
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(
                                end: closeBtn,
                                top: 2,
                              ),
                              child: Text(
                                _banner!.message,
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: msgFont,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Action button — dark surface, thin accent border, no neon glow.
                      if (hasAction) ...[
                        SizedBox(height: isSmallScreen ? 11 : (isTablet ? 15 : 13)),
                        Consumer<LanguageProvider>(
                          builder: (context, langProvider, _) => Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _launchUrl(_banner!.actionUrl!),
                              borderRadius: BorderRadius.circular(11),
                              child: Ink(
                                height: actionHeight,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _banner!.actionText ?? AppLocalizations.of(context).translate('announcement.view'),
                                        style: TextStyle(
                                          color: Color.lerp(color, Colors.white, 0.35) ?? color,
                                          fontSize: actionFont,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: isSmallScreen ? 6 : 8),
                                    Icon(
                                      langProvider.isRtl
                                          ? Icons.arrow_back_rounded
                                          : Icons.arrow_forward_rounded,
                                      color: Color.lerp(color, Colors.white, 0.35) ?? color,
                                      size: actionIcon,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Close button — absolutely positioned so it doesn't shift the message.
                PositionedDirectional(
                  top: isSmallScreen ? 8 : 10,
                  end: isSmallScreen ? 8 : 10,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _dismiss,
                      borderRadius: BorderRadius.circular(closeBtn / 2),
                      child: Container(
                        width: closeBtn,
                        height: closeBtn,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: closeIcon,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
