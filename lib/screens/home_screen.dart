import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/connection_button.dart';
import '../widgets/modern_animated_background.dart';
import '../screens/language_settings_screen.dart';
import '../models/app_language.dart';
import '../utils/app_localizations.dart';
import '../screens/server_selection_screen.dart';
import '../screens/ip_info_screen.dart';
import '../screens/speedtest_screen.dart';
import '../screens/host_checker_screen.dart';
import '../screens/about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _isConnecting = false;
  late AnimationController _backgroundAnimationController;
  
  @override
  void initState() {
    super.initState();
    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    
    // Initialize provider data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<V2RayProvider>(context, listen: false);
      // Start with fetching default servers if needed
      if (provider.configs.isEmpty) {
        provider.fetchServers(
          customUrl: 'https://raw.githubusercontent.com/cverhud/v2ray-sub/refs/heads/main/sub.txt',
        );
      }
    });
  }
  
  @override
  void dispose() {
    _backgroundAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleConnectionToggle() async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
    });

    final provider = Provider.of<V2RayProvider>(context, listen: false);

    try {
      if (provider.activeConfig != null) {
        await provider.disconnect();
        // _showSnackBar('Disconnected Successfully', Colors.orange);
      } else {
        if (provider.selectedConfig == null) {
          _showSnackBar('Please select a server first', Colors.red);
        } else {
          await provider.connectToServer(provider.selectedConfig!, false);
          if (provider.activeConfig != null) {
            // _showSnackBar('Connected Successfully', Colors.green);
          }
        }
      }
    } catch (e) {
      _showSnackBar('Connection failed: $e', Colors.red);
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        
        final languages = [
          {'name': 'English', 'code': 'en', 'flag': '🇬🇧'},
          {'name': 'فارسی', 'code': 'fa', 'flag': '🇮🇷'},
        ];
        
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            AppLocalizations.of(context).translate('language_settings.select_language'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final lang = languages[index];
                final isSelected = languageProvider.currentLanguage.code == lang['code'];
                
                return GestureDetector(
                  onTap: () async {
                    final newLanguage = AppLanguage(
                      name: lang['name']!,
                      code: lang['code']!,
                      flag: lang['flag']!,
                      direction: lang['code'] == 'fa' || lang['code'] == 'ar' ? 'rtl' : 'ltr',
                    );
                    await languageProvider.changeLanguage(newLanguage);
                    Navigator.pop(context);
                    _showSnackBar(AppLocalizations.of(context).translate('language_settings.language_changed'), Colors.green);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? const Color(0xFF6366F1).withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? const Color(0xFF6366F1)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          lang['flag']!,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            lang['name']!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF6366F1),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<V2RayProvider, LanguageProvider>(
      builder: (context, v2rayProvider, languageProvider, child) {
        final isConnected = v2rayProvider.activeConfig != null;
        
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: Scaffold(
            body: ModernAnimatedBackground(
              isConnected: isConnected,
              child: SafeArea(
                child: Column(
                    children: [
                      // Modern App Bar
                      _buildModernAppBar(context),
                      
                      // Main Content
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                const SizedBox(height: 20),
                                
                                // Main Connection Button
                                _buildConnectionButton(v2rayProvider),
                                
                                const SizedBox(height: 24),
                                
                                // Server Selection Card
                                _buildServerCard(v2rayProvider),
                                
                                const SizedBox(height: 20),
                                
                                // Stats Grid
                                if (v2rayProvider.activeConfig != null)
                                  _buildStatsGrid(v2rayProvider),
                                
                                const SizedBox(height: 20),
                                
                                // Quick Actions
                                _buildQuickActions(context),
                              ],
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
      },
    );
  }

  Widget _buildModernAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo and Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield,
                  color: Colors.white,
                  size: 24,
                ),
              ).animate()
                  .fadeIn()
                  .scale(duration: 600.ms, curve: Curves.elasticOut),
              
              const SizedBox(width: 12),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).translate('home.title'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn().slideX(),
                  Text(
                    AppLocalizations.of(context).translate('home.secure_connection'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                ],
              ),
            ],
          ),
          
          // Menu Buttons
          Row(
            children: [
              _buildAppBarButton(
                icon: Icons.language,
                onTap: () => _showLanguageDialog(context),
              ),
              const SizedBox(width: 8),
              _buildAppBarButton(
                icon: Icons.info_outline,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AboutScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    ).animate().scale(delay: 200.ms);
  }

  Widget _buildConnectionButton(V2RayProvider provider) {
    final isConnected = provider.activeConfig != null;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse Animation Rings
        ...List.generate(3, (index) {
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: Duration(seconds: 3),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return AnimatedScale(
                scale: isConnected ? (0.8 + (value * 0.6) + (index * 0.1)) : 0.8,
                duration: Duration(milliseconds: 600),
                child: AnimatedOpacity(
                  opacity: isConnected ? (1.0 - value - (index * 0.3)).clamp(0.0, 1.0) : 0,
                  duration: Duration(milliseconds: 600),
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              );
            },
            onEnd: () {
              // Animation loop handled by TweenAnimationBuilder
            },
          );
        }),
        
        // Main Circle Button
        GestureDetector(
          onTap: _isConnecting ? null : () => _handleConnectionToggle(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isConnected
                    ? [
                        const Color(0xFF10B981).withOpacity(0.9),
                        const Color(0xFF059669),
                        const Color(0xFF047857),
                      ]
                    : [
                        const Color(0xFF1E293B),
                        const Color(0xFF334155),
                        const Color(0xFF475569),
                      ],
                stops: const [0.0, 0.6, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: isConnected
                      ? const Color(0xFF10B981).withOpacity(0.5)
                      : Colors.black.withOpacity(0.4),
                  blurRadius: isConnected ? 40 : 20,
                  spreadRadius: isConnected ? 5 : 0,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animated Border Gradient
                if (isConnected)
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(seconds: 2),
                    curve: Curves.linear,
                    builder: (context, value, child) {
                      return Transform.rotate(
                        angle: value * 2 * 3.14159,
                        child: Container(
                          width: 145,
                          height: 145,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    onEnd: () {
                      // Animation loop handled by TweenAnimationBuilder
                    },
                  ),
                
                // Center Icon with Animation
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: RotationTransition(
                        turns: animation,
                        child: child,
                      ),
                    );
                  },
                  child: _isConnecting
                      ? const CircularProgressIndicator(
                          key: ValueKey('loading'),
                          color: Colors.white,
                          strokeWidth: 3,
                        )
                      : Icon(
                          isConnected 
                              ? Icons.lock
                              : Icons.power_settings_new,
                          key: ValueKey(isConnected ? 'lock' : 'power'),
                          size: 60,
                          color: Colors.white,
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServerCard(V2RayProvider provider) {
    final selectedConfig = provider.selectedConfig ?? provider.activeConfig;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ServerSelectionScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.language,
                color: Color(0xFF6366F1),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Server Location',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedConfig?.remark ?? 'Select a server',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.3),
              size: 18,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.2, end: 0);
  }

  Widget _buildStatsGrid(V2RayProvider provider) {
    final v2rayService = provider.v2rayService;
    
    // Use StreamBuilder to update stats every second
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.timer,
                      label: 'Duration',
                      value: v2rayService.getFormattedConnectedTime(),
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.upload,
                      label: 'Upload',
                      value: v2rayService.getFormattedUpload(),
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.download,
                      label: 'Download',
                      value: v2rayService.getFormattedDownload(),
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StreamBuilder<int?>(
                      stream: Stream.periodic(
                        const Duration(seconds: 5),
                        (_) => v2rayService.getCurrentPing(),
                      ).asyncMap((future) => future),
                      builder: (context, snapshot) {
                        return _buildStatItem(
                          icon: Icons.speed,
                          label: 'Latency',
                          value: snapshot.hasData && snapshot.data != null
                              ? '${snapshot.data} ms'
                              : '-- ms',
                          color: Colors.purple,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).animate().fadeIn(delay: 500.ms);
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond == 0) return '0 B/s';
    
    const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
    int unitIndex = 0;
    double speed = bytesPerSecond.toDouble();
    
    while (speed >= 1024 && unitIndex < units.length - 1) {
      speed /= 1024;
      unitIndex++;
    }
    
    return '${speed.toStringAsFixed(1)} ${units[unitIndex]}';
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).translate('home.quick_actions'),
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _buildQuickActionItem(
              icon: Icons.info_outline,
              label: AppLocalizations.of(context).translate('home.ip_info'),
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IpInfoScreen(),
                  ),
                );
              },
            ),
            _buildQuickActionItem(
              icon: Icons.speed,
              label: AppLocalizations.of(context).translate('home.speed_test'),
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SpeedTestScreen(),
                  ),
                );
              },
            ),
            _buildQuickActionItem(
              icon: Icons.refresh,
              label: AppLocalizations.of(context).translate('home.refresh'),
              color: const Color(0xFF8B5CF6),
              onTap: () async {
                final provider = Provider.of<V2RayProvider>(
                  context,
                  listen: false,
                );
                
                _showSnackBar(AppLocalizations.of(context).translate('home.updating_subscriptions'), Colors.blue);
                await provider.updateAllSubscriptions();
                
                if (provider.errorMessage.isEmpty) {
                  _showSnackBar(AppLocalizations.of(context).translate('home.subscriptions_updated'), Colors.green);
                } else {
                  _showSnackBar(provider.errorMessage, Colors.red);
                  provider.clearError();
                }
              },
            ),
            _buildQuickActionItem(
              icon: Icons.dns,
              label: AppLocalizations.of(context).translate('home.host_checker'),
              color: const Color(0xFF06B6D4),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HostCheckerScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().scale(delay: 100.ms * label.length);
  }
}
