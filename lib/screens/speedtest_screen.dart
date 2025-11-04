import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:flutter_internet_speed_test/flutter_internet_speed_test.dart';
import '../providers/language_provider.dart';
import '../widgets/vpn_gradient_background.dart';
import '../utils/app_colors.dart';
import '../utils/app_localizations.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen>
    with TickerProviderStateMixin {
  final FlutterInternetSpeedTest speedTest = FlutterInternetSpeedTest();
  
  // Test State
  SpeedTestStatus _currentStatus = SpeedTestStatus.ready;
  double _downloadSpeed = 0.0;
  double _uploadSpeed = 0.0;
  int _ping = 0;
  double _progress = 0.0;
  
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
    speedTest.cancelTest();
    super.dispose();
  }
  
  Future<void> _startSpeedTest() async {
    if (_currentStatus == SpeedTestStatus.testing) {
      _stopTest();
      return;
    }
    
    setState(() {
      _currentStatus = SpeedTestStatus.testing;
      _downloadSpeed = 0.0;
      _uploadSpeed = 0.0;
      _ping = 0;
      _progress = 0.0;
    });
    
    _rotationController.repeat();
    
    try {
      // Start download test
      await speedTest.startTesting(
        onStarted: () {
          debugPrint('Speed test started');
        },
        onCompleted: (TestResult download, TestResult upload) {
          setState(() {
            _downloadSpeed = download.transferRate;
            _uploadSpeed = upload.transferRate;
            _progress = 1.0;
            _currentStatus = SpeedTestStatus.completed;
          });
          _rotationController.stop();
          _showCompletionAnimation();
        },
        onProgress: (double percent, TestResult data) {
          setState(() {
            if (data.type == TestType.download) {
              _downloadSpeed = data.transferRate;
              _progress = percent / 200; // 0-50%
            } else {
              _uploadSpeed = data.transferRate;
              _progress = 0.5 + (percent / 200); // 50-100%
            }
          });
        },
        onError: (String errorMessage, String speedTestError) {
          _handleError(errorMessage);
        },
        onDefaultServerSelectionInProgress: () {
          debugPrint('Selecting server...');
        },
        onDefaultServerSelectionDone: (Client? client) {
          debugPrint('Server selected: $client');
        },
        onDownloadComplete: (TestResult data) {
          setState(() {
            _downloadSpeed = data.transferRate;
            _progress = 0.5;
          });
        },
        onUploadComplete: (TestResult data) {
          setState(() {
            _uploadSpeed = data.transferRate;
            _progress = 1.0;
          });
        },
        onCancel: () {
          debugPrint('Test cancelled');
        },
      );
    } catch (e) {
      _handleError(e.toString());
    }
  }
  
  void _stopTest() {
    speedTest.cancelTest();
    _rotationController.stop();
    setState(() {
      _currentStatus = SpeedTestStatus.ready;
      _progress = 0.0;
    });
  }
  
  void _handleError(String error) {
    _rotationController.stop();
    setState(() {
      _currentStatus = SpeedTestStatus.error;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppLocalizations.of(context).translate('speed_test.error')}: $error'),
        backgroundColor: Colors.red,
      ),
    );
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
                  color: AppColors.bottomGradientConnecting,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _progress < 0.5 
                  ? AppLocalizations.of(context).translate('speed_test.download')
                  : AppLocalizations.of(context).translate('speed_test.upload'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_progress < 0.5 ? _downloadSpeed : _uploadSpeed).toStringAsFixed(2)} ${AppLocalizations.of(context).translate('speed_test.mbps')}',
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
  
  Widget _buildMetrics() {
    final mbps = AppLocalizations.of(context).translate('speed_test.mbps');
    final ms = AppLocalizations.of(context).translate('speed_test.ms');
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
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
            value: _ping > 0 ? '$_ping $ms' : '-- $ms',
            color: AppColors.warningColor,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, end: 0);
  }
  
  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
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
  
  _ProgressPainter({
    required this.progress,
    required this.status,
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
    } else if (progress < 0.5) {
      return [AppColors.bottomGradientConnecting, AppColors.downloadColor];
    } else {
      return [AppColors.downloadColor, AppColors.uploadColor];
    }
  }
  
  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.status != status;
  }
}

// Speed Test Status Enum
enum SpeedTestStatus {
  ready,
  testing,
  completed,
  error,
}
