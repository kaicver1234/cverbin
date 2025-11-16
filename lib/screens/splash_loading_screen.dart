import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashLoadingScreen extends StatefulWidget {
  final Future<void> Function() onInitialize;
  final VoidCallback onComplete;

  const SplashLoadingScreen({
    Key? key,
    required this.onInitialize,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<SplashLoadingScreen> createState() => _SplashLoadingScreenState();
}

class _SplashLoadingScreenState extends State<SplashLoadingScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  String _statusMessage = 'Initializing...';
  bool _hasInternet = true;
  bool _isRetrying = false;
  late AnimationController _pulseController;
  bool _isFarsi = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _loadLanguageAndStart();
  }
  
  Future<void> _loadLanguageAndStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString('language_code') ?? 'en';
      _isFarsi = languageCode == 'fa';
    } catch (e) {
      _isFarsi = false;
    }
    _startInitialization();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _t(String en, String fa) => _isFarsi ? fa : en;

  Future<void> _startInitialization() async {
    if (!mounted) return;
    
    _progress = 0.0;
    _statusMessage = _t('Checking connection...', 'بررسی اتصال...');
    _isRetrying = false;
    setState(() {});

    // Check internet connection
    final hasInternet = await _checkInternetConnection();
    
    if (!mounted) return;
    
    if (!hasInternet) {
      _hasInternet = false;
      _statusMessage = _t('No internet connection', 'اتصال به اینترنت برقرار نیست');
      setState(() {});
      return;
    }

    _hasInternet = true;
    _progress = 0.2;
    _statusMessage = _t('Connecting to services...', 'اتصال به سرویس‌ها...');
    setState(() {});

    await Future.delayed(const Duration(milliseconds: 200));

    // Initialize app
    try {
      if (!mounted) return;
      
      _progress = 0.4;
      _statusMessage = _t('Loading resources...', 'بارگیری منابع...');
      setState(() {});

      await widget.onInitialize();

      if (!mounted) return;
      
      _progress = 0.8;
      _statusMessage = _t('Almost ready...', 'تقریباً آماده...');
      setState(() {});

      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;
      
      _progress = 1.0;
      _statusMessage = _t('Ready!', 'آماده!');
      setState(() {});

      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        debugPrint('✅ Initialization complete, calling onComplete');
        try {
          widget.onComplete();
        } catch (e) {
          debugPrint('❌ Error in onComplete: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Initialization error: $e');
      if (!mounted) return;
      _statusMessage = _t('Initialization failed', 'راه‌اندازی ناموفق بود');
      setState(() {});
      
      // Retry after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _retry();
      }
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  void _retry() {
    if (!mounted) return;
    _isRetrying = true;
    setState(() {});
    _startInitialization();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Logo with pulse animation
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.1),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _hasInternet
                              ? [
                                  const Color(0xFF667EEA),
                                  const Color(0xFF764BA2),
                                ]
                              : [
                                  Colors.orange.shade700,
                                  Colors.red.shade700,
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_hasInternet
                                    ? const Color(0xFF667EEA)
                                    : Colors.orange)
                                .withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        _hasInternet
                            ? Icons.vpn_lock_rounded
                            : Icons.wifi_off_rounded,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // App Name
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFFB06AB3)],
                ).createShader(bounds),
                child: const Text(
                  'Tiksar VPN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // Progress bar or error message
              if (_hasInternet) ...[
                // Progress Bar
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF667EEA),
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: -0.2, end: 0),

                const SizedBox(height: 20),

                // Status Message
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.2, end: 0),
              ] else ...[
                // No Internet Message
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 48,
                        color: Colors.orange.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _t('No Internet Connection', 'اتصال به اینترنت برقرار نیست'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          'Please check your internet connection\nand try again',
                          'لطفاً اتصال اینترنت خود را بررسی کنید\nو دوباره تلاش کنید',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isRetrying ? null : _retry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.shade600,
                                  Colors.red.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: _isRetrying
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.refresh_rounded, size: 24),
                                        const SizedBox(width: 8),
                                        Text(
                                          _t('Retry', 'تلاش مجدد'),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(begin: const Offset(0.8, 0.8)),
              ],

              const Spacer(),

              // Footer
              Text(
                _t('Made with ❤️', 'ساخته شده با ❤️'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                ),
              ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
            ],
          ),
        ),
      ),
    );
  }
}
