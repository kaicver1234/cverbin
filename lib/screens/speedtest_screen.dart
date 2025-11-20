import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../widgets/vpn_gradient_background.dart';
import '../utils/app_colors.dart';
import '../utils/app_localizations.dart';
import '../services/cloudflare_speed_test_service.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen>
    with TickerProviderStateMixin {
  final CloudflareSpeedTestService _speedTestService = CloudflareSpeedTestService();
  
  // Test State
  SpeedTestStatus _currentStatus = SpeedTestStatus.ready;
  TestPhase _currentPhase = TestPhase.loading;
  double _downloadSpeed = 0.0;
  double _uploadSpeed = 0.0;
  int _ping = 0;
  double _progress = 0.0;
  double _currentSpeed = 0.0;
  
  // Live ping tracking
  final List<int> _livePings = [];
  int _currentPingIndex = 0;
  Timer? _pingDisplayTimer;
  
  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _initAnimations();
  }
  
  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _speedTestService.dispose();
    _pingDisplayTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _startSpeedTest() async {
    if (_currentStatus == SpeedTestStatus.testing) {
      _stopTest();
      return;
    }
    
    if (!mounted) return;
    
    // Complete reset before starting new test
    setState(() {
      _currentStatus = SpeedTestStatus.testing;
      _currentPhase = TestPhase.loading;
      _downloadSpeed = 0.0;
      _uploadSpeed = 0.0;
      _ping = 0;
      _progress = 0.0;
      _currentSpeed = 0.0;
      _livePings.clear();
      _currentPingIndex = 0;
    });
    
    // Start live ping monitoring
    _startLivePingMonitoring();
    
    _rotationController.repeat();
    
    await _speedTestService.startTest(
      onPhaseChange: (phase, progress) {
        if (!mounted) return;
        
        setState(() {
          _currentPhase = phase;
          _progress = progress;
          
          // Update results immediately as they become available
          if (phase == TestPhase.loading && progress == 1.0) {
            // Ping test completed, show final ping result
            final result = _speedTestService.latencies;
            if (result.isNotEmpty) {
              _ping = (result.reduce((a, b) => a + b) / result.length).round();
              _livePings.addAll(result);
            }
            // Don't cancel timer here - let it continue until download starts
          }
          
          // When download phase starts, ensure final ping is shown
          if (phase == TestPhase.download && progress == 0.0) {
            final result = _speedTestService.latencies;
            if (result.isNotEmpty && _ping == 0) {
              _ping = (result.reduce((a, b) => a + b) / result.length).round();
            }
            _pingDisplayTimer?.cancel();
          }
        });
      },
      onSpeedUpdate: (speed) {
        if (!mounted) return;
        
        setState(() {
          _currentSpeed = speed;
          
          // Update current phase result in real-time
          if (_currentPhase == TestPhase.download && speed > 0) {
            _downloadSpeed = speed;
          } else if (_currentPhase == TestPhase.upload && speed > 0) {
            _uploadSpeed = speed;
          }
        });
      },
      onComplete: (result) {
        if (!mounted) return;
        
        setState(() {
          _downloadSpeed = result.downloadSpeed;
          _uploadSpeed = result.uploadSpeed;
          _ping = result.ping;
          _currentSpeed = 0.0;
          _progress = 1.0;
          _currentStatus = SpeedTestStatus.completed;
        });
        
        _rotationController.stop();
        _showCompletionAnimation();
      },
      onError: (error) {
        if (!mounted) return;
        _handleError(error);
      },
    );
  }
  
  void _startLivePingMonitoring() {
    _pingDisplayTimer?.cancel();
    _pingDisplayTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      // Keep showing ping until download phase starts
      if (_currentPhase == TestPhase.download || _currentPhase == TestPhase.upload || !mounted) {
        timer.cancel();
        return;
      }
      
      // Get latest pings from service
      final latencies = _speedTestService.latencies;
      if (latencies.length > _currentPingIndex) {
        setState(() {
          _currentPingIndex = latencies.length;
          if (latencies.isNotEmpty) {
            _ping = latencies.last;
          }
        });
      }
    });
  }
  
  void _stopTest() {
    _speedTestService.cancelTest();
    _rotationController.stop();
    _pingDisplayTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _currentStatus = SpeedTestStatus.ready;
      _progress = 0.0;
      _currentSpeed = 0.0;
    });
  }
  
  void _handleError(String error) {
    _rotationController.stop();
    if (!mounted) return;
    setState(() {
      _currentStatus = SpeedTestStatus.error;
      _currentSpeed = 0.0;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context).translate('speed_test.error')}: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _showCompletionAnimation() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _currentStatus = SpeedTestStatus.ready;
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: VPNGradientBackground(
            status: _getBackgroundStatus(),
            child: SafeArea(
              child: Column(
                children: [
                  _buildAppBar(),
                  const SizedBox(height: 40),
                  _buildHeader(),
                  const SizedBox(height: 60),
                  Expanded(
                    child: _buildMainContent(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  VPNBackgroundStatus _getBackgroundStatus() {
    switch (_currentStatus) {
      case SpeedTestStatus.testing:
        return VPNBackgroundStatus.connecting;
      case SpeedTestStatus.completed:
        return VPNBackgroundStatus.connected;
      case SpeedTestStatus.error:
        return VPNBackgroundStatus.error;
      default:
        return VPNBackgroundStatus.disconnected;
    }
  }
  
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 22,
              ),
            ),
          ).animate().fadeIn().slideX(),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              AppLocalizations.of(context).translate('speed_test.title'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ).animate().fadeIn().slideX(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    String statusText;
    String subtitleText;
    
    switch (_currentStatus) {
      case SpeedTestStatus.testing:
        statusText = AppLocalizations.of(context).translate('speed_test.tiksar_is');
        subtitleText = AppLocalizations.of(context).translate('speed_test.testing_speed');
        break;
      case SpeedTestStatus.completed:
        statusText = AppLocalizations.of(context).translate('speed_test.tiksar_has');
        subtitleText = AppLocalizations.of(context).translate('speed_test.completed_test');
        break;
      case SpeedTestStatus.error:
        statusText = AppLocalizations.of(context).translate('speed_test.tiksar_has');
        subtitleText = AppLocalizations.of(context).translate('speed_test.encountered_error');
        break;
      default:
        statusText = AppLocalizations.of(context).translate('speed_test.tiksar_is_ready');
        subtitleText = AppLocalizations.of(context).translate('speed_test.to_speed_test');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              statusText,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ],
        ).animate().fadeIn(delay: 200.ms),
        Text(
          subtitleText,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }
  
  Widget _buildMainContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildSpeedIndicator(),
        const SizedBox(height: 60),
        _buildMetrics(),
      ],
    );
  }
  
  Widget _buildSpeedIndicator() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer circle
        SizedBox(
          width: 280,
          height: 280,
          child: CustomPaint(
            painter: _ProgressPainter(
              progress: _progress,
              status: _currentStatus,
              phase: _currentPhase,
            ),
          ),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        
        // Inner content
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentStatus == SpeedTestStatus.testing) ...[
              RotationTransition(
                turns: _rotationController,
                child: Icon(
                  Icons.speed,
                  size: 60,
                  color: _getPhaseColor(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _getPhaseLabel(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currentSpeed > 0
                    ? '${_currentSpeed.toStringAsFixed(2)} ${AppLocalizations.of(context).translate('speed_test.mbps')}'
                    : '--',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else if (_currentStatus == SpeedTestStatus.completed) ...[
              Icon(
                Icons.check_circle,
                size: 80,
                color: AppColors.downloadColor,
              ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).translate('speed_test.completed'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ] else ...[
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.3),
                        Colors.white.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.play_arrow,
                      size: 50,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).translate('speed_test.tap_to_start'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ],
          ],
        ),
        
        // Tap overlay
        if (_currentStatus != SpeedTestStatus.completed)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _startSpeedTest,
                customBorder: const CircleBorder(),
                child: Container(),
              ),
            ),
          ),
      ],
    );
  }
  
  String _getPhaseLabel() {
    switch (_currentPhase) {
      case TestPhase.loading:
        return 'PING';
      case TestPhase.download:
        return AppLocalizations.of(context).translate('speed_test.download');
      case TestPhase.upload:
        return AppLocalizations.of(context).translate('speed_test.upload');
    }
  }
  
  Color _getPhaseColor() {
    switch (_currentPhase) {
      case TestPhase.loading:
        return AppColors.warningColor;
      case TestPhase.download:
        return AppColors.downloadColor;
      case TestPhase.upload:
        return AppColors.uploadColor;
    }
  }
  
  Widget _buildMetrics() {
    final mbps = AppLocalizations.of(context).translate('speed_test.mbps');
    final ms = AppLocalizations.of(context).translate('speed_test.ms');
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.1),
              Colors.white.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMetricCard(
              icon: Icons.download,
              label: AppLocalizations.of(context).translate('speed_test.download_label'),
              value: _downloadSpeed > 0
                  ? '${_downloadSpeed.toStringAsFixed(2)} $mbps'
                  : '-- $mbps',
              color: AppColors.downloadColor,
            ),
            _buildMetricCard(
              icon: Icons.upload,
              label: AppLocalizations.of(context).translate('speed_test.upload_label'),
              value: _uploadSpeed > 0
                  ? '${_uploadSpeed.toStringAsFixed(2)} $mbps'
                  : '-- $mbps',
              color: AppColors.uploadColor,
            ),
            _buildMetricCard(
              icon: Icons.speed,
              label: AppLocalizations.of(context).translate('speed_test.ping_label'),
              value: _currentPhase == TestPhase.loading && _currentStatus == SpeedTestStatus.testing
                  ? (_ping > 0 ? '$_ping $ms' : 'Testing...')
                  : (_ping > 0 ? '$_ping $ms' : '-- $ms'),
              color: AppColors.warningColor,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, end: 0);
  }
  
  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    // Check if this is ping card and we're testing
    final bool isPingCard = icon == Icons.speed;
    final bool isLivePing = isPingCard && _currentPhase == TestPhase.loading && _currentStatus == SpeedTestStatus.testing;
    
    return Column(
      children: [
        // Icon with pulse animation for live ping
        if (isLivePing)
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    color,
                    color.withValues(alpha: 0.6),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.4),
                  color.withValues(alpha: 0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        // Animated value with shimmer effect for live ping
        if (isLivePing)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              value,
              key: ValueKey(value),
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                shadows: [
                  Shadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          )
        else
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
      ],
    );
  }
}

// Custom Progress Painter
class _ProgressPainter extends CustomPainter {
  final double progress;
  final SpeedTestStatus status;
  final TestPhase phase;
  
  _ProgressPainter({
    required this.progress,
    required this.status,
    required this.phase,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Background circle
    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = LinearGradient(
          colors: _getProgressColors(),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -90 * 3.14159 / 180,
        progress * 2 * 3.14159,
        false,
        progressPaint,
      );
    }
  }
  
  List<Color> _getProgressColors() {
    if (status == SpeedTestStatus.completed) {
      return [AppColors.downloadColor, AppColors.uploadColor];
    }
    
    switch (phase) {
      case TestPhase.loading:
        return [AppColors.warningColor, AppColors.warningColor];
      case TestPhase.download:
        return [AppColors.bottomGradientConnecting, AppColors.downloadColor];
      case TestPhase.upload:
        return [AppColors.downloadColor, AppColors.uploadColor];
    }
  }
  
  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.status != status ||
           oldDelegate.phase != phase;
  }
}

// Speed Test Status Enum
enum SpeedTestStatus {
  ready,
  testing,
  completed,
  error,
}
