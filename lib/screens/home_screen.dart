import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/vpn_gradient_background.dart';
import '../models/app_language.dart';
import '../utils/app_localizations.dart';
import '../screens/server_selection_screen.dart';
import '../screens/ip_info_screen.dart';
import '../screens/speedtest_screen.dart';
import '../screens/host_checker_screen.dart';
import '../screens/about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  bool _isConnecting = false;
  late PageController _pageController;
  int _currentPage = 0;
  BoxDecoration? _statsDecoration; // Cache decoration for performance
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      keepPage: true,
      viewportFraction: 1.0,
    );
    // Listen to app lifecycle to force rebuild when resumed
    WidgetsBinding.instance.addObserver(this);
    
    // Sync VPN status and load servers when screen first loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncVpnStatus();
      _loadServers();
    });
  }
  
  Future<void> _syncVpnStatus() async {
    if (!mounted) return;
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    await provider.forceSyncVpnStatus();
    if (mounted) setState(() {});
  }
  
  Future<void> _loadServers() async {
    if (!mounted) return;
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    // Load servers if not already loaded
    if (provider.serverConfigs.isEmpty) {
      await provider.fetchServers(
        customUrl: 'https://raw.githubusercontent.com/cverhud/v2ray-sub/refs/heads/main/sub2.txt',
      );
      debugPrint('✅ Servers loaded in home screen');
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      // Force sync VPN status when app comes back from background
      debugPrint('🏠 HomeScreen: App resumed, syncing VPN status...');
      _syncVpnStatus();
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleConnectionToggle() async {
    if (_isConnecting) return;

    if (!mounted) return;
    setState(() {
      _isConnecting = true;
    });

    final provider = Provider.of<V2RayProvider>(context, listen: false);

    try {
      if (provider.activeConfig != null) {
        await provider.disconnect();
        // _showSnackBar('Disconnected Successfully', Colors.orange);
      } else {
        // Check if Smart Connect is selected
        if (provider.wasUsingSmartConnect) {
          debugPrint('⚡ Using Smart Connect...');
          await provider.smartConnect();
        } else {
          // Auto-select first server if none selected
          if (provider.selectedConfig == null && provider.configs.isNotEmpty) {
            await provider.selectConfig(provider.configs.first);
          }
          
          if (provider.selectedConfig == null) {
            if (mounted) {
              _showSnackBar(AppLocalizations.of(context).translate('common.please_select_server'), Colors.red);
            }
          } else {
            // Connect to server
            debugPrint('🚀 Starting connection to: ${provider.selectedConfig!.remark}');
            await provider.connectToServer(provider.selectedConfig!);
          }
        }
        
        // Check result after connection attempt
        if (mounted) {
          if (provider.activeConfig != null) {
            debugPrint('✅ Connection successful - activeConfig: ${provider.activeConfig!.remark}');
            // Consumer2 will rebuild automatically, no need for manual setState
          } else if (provider.errorMessage.isNotEmpty) {
            debugPrint('❌ Connection failed: ${provider.errorMessage}');
            _showSnackBar(provider.errorMessage, Colors.red);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('${AppLocalizations.of(context).translate('common.connection_failed')}: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
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
          {'name': 'فارسی', 'code': 'fa', 'flag': '🦁'},
        ];
        
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0A0A).withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          title: Text(
            AppLocalizations.of(context).translate('language_settings.select_language'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          content: SizedBox(
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
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _showSnackBar(AppLocalizations.of(context).translate('language_settings.language_changed'), Colors.green);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected 
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          lang['flag']!,
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            lang['name']!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 22,
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
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Consumer2<V2RayProvider, LanguageProvider>(
      builder: (context, v2rayProvider, languageProvider, child) {
        // Determine background status based on VPN state
        final backgroundStatus = _getBackgroundStatus(v2rayProvider);
        
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: VPNGradientBackground(
            status: backgroundStatus,
            child: SafeArea(
              child: Column(
                children: [
                  // Modern App Bar
                  _buildModernAppBar(context),
                  
                  // Page View Content with swipe support (Optimized)
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const ClampingScrollPhysics(),
                      onPageChanged: (index) {
                        if (mounted) {
                          setState(() {
                            _currentPage = index;
                          });
                        }
                      },
                      children: [
                        // Wrap in RepaintBoundary for better performance
                        RepaintBoundary(
                          key: const PageStorageKey<String>('vpn_tab'),
                          child: _buildVPNTab(v2rayProvider),
                        ),
                        RepaintBoundary(
                          key: const PageStorageKey<String>('tools_tab'),
                          child: _buildToolsTab(context),
                        ),
                      ],
                    ),
                  ),
                  
                  // Tab Bar inside the main body for unified background
                  _buildBottomTabBar(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Helper method to determine background status from VPN state
  // User wants background to stay same, NOT change when connected/connecting
  // But show error if there's an error
  VPNBackgroundStatus _getBackgroundStatus(V2RayProvider provider) {
    // Show error background if there's an error
    if (provider.errorMessage.isNotEmpty) {
      return VPNBackgroundStatus.error;
    }
    
    // Otherwise always return disconnected - user doesn't want background to change
    // Only the connect button should change color, not the background
    return VPNBackgroundStatus.disconnected;
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
                      color: Colors.white.withValues(alpha: 0.6),
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
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
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

  Widget _buildBottomTabBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // VPN Tab - Active style with rounded container
          Expanded(
            flex: 5,
            child: GestureDetector(
              onTap: () {
                if (_currentPage != 0) {
                  _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.fastOutSlowIn,
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 56,
                decoration: BoxDecoration(
                  color: _currentPage == 0
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.vpn_key,
                      color: _currentPage == 0
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(context).translate('navigation.vpn'),
                      style: TextStyle(
                        color: _currentPage == 0
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Tools Tab
          Expanded(
            flex: 4,
            child: GestureDetector(
              onTap: () {
                if (_currentPage != 1) {
                  _pageController.animateToPage(
                    1,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.fastOutSlowIn,
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 56,
                decoration: BoxDecoration(
                  color: _currentPage == 1
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.build,
                      color: _currentPage == 1
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(context).translate('navigation.tools'),
                      style: TextStyle(
                        color: _currentPage == 1
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVPNTab(V2RayProvider provider) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            
            // Main Connection Button
            _buildConnectionButton(provider),
            
            const SizedBox(height: 30),
            
            // Server Selection Card - پایین‌تر
            _buildServerCard(provider),
            
            const SizedBox(height: 20),
            
            // Stats Grid - ساده‌شده برای عملکرد بهتر
            if (provider.activeConfig != null)
              _buildStatsGrid(provider),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          
          // Title
          Text(
            AppLocalizations.of(context).translate('navigation.tools'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            AppLocalizations.of(context).translate('home.quick_actions'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Tools Grid
          Expanded(
            child: _buildToolsGrid(context),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsGrid(BuildContext context) {
    final tools = [
      {
        'icon': Icons.info_outline,
        'label': AppLocalizations.of(context).translate('home.ip_info'),
        'subtitle': AppLocalizations.of(context).translate('tools.ip_information_desc'),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const IpInfoScreen()),
          );
        },
      },
      {
        'icon': Icons.speed,
        'label': AppLocalizations.of(context).translate('home.speed_test'),
        'subtitle': AppLocalizations.of(context).translate('tools.speed_test_desc'),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SpeedTestScreen()),
          );
        },
      },
      {
        'icon': Icons.dns,
        'label': AppLocalizations.of(context).translate('home.host_checker'),
        'subtitle': AppLocalizations.of(context).translate('tools.host_checker_desc'),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HostCheckerScreen()),
          );
        },
      },
    ];

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        return _buildToolCard(
          icon: tool['icon'] as IconData,
          label: tool['label'] as String,
          subtitle: tool['subtitle'] as String,
          onTap: tool['onTap'] as VoidCallback,
        );
      },
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
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
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Simple icon container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionButton(V2RayProvider provider) {
    final isConnected = provider.activeConfig != null;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse Animation Rings
        if (isConnected)
          ...List.generate(2, (index) {
            return _PulseRing(
              delay: index * 0.5,
              size: 200.0,
              color: const Color(0xFF10B981),
            );
          })
        else
          // Subtle glow ring for disconnected state
          _PulseRing(
            delay: 0,
            size: 180.0,
            color: const Color(0xFF6366F1),
          ),
        
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
                        const Color(0xFF10B981).withValues(alpha: 0.9),
                        const Color(0xFF059669),
                        const Color(0xFF047857),
                      ]
                    : [
                        const Color(0xFF6366F1).withValues(alpha: 0.8),
                        const Color(0xFF4F46E5),
                        const Color(0xFF4338CA),
                      ],
                stops: const [0.0, 0.6, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: isConnected
                      ? const Color(0xFF10B981).withValues(alpha: 0.5)
                      : const Color(0xFF6366F1).withValues(alpha: 0.4),
                  blurRadius: 35,
                  spreadRadius: 3,
                ),
                if (!isConnected)
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                    blurRadius: 60,
                    spreadRadius: 10,
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
                                Colors.white.withValues(alpha: 0.3),
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
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: _isConnecting
                      ? _buildSmartConnectAnimation(provider.wasUsingSmartConnect)
                      : Icon(
                          isConnected 
                              ? Icons.vpn_key
                              : Icons.power_settings_new,
                          key: ValueKey(isConnected ? 'vpn_key' : 'power'),
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

  // Smart Connect animation widget
  Widget _buildSmartConnectAnimation(bool isSmartConnect) {
    if (isSmartConnect) {
      // Smart Connect: radar-like scanning animation
      return SizedBox(
        key: const ValueKey('smart_connect_anim'),
        width: 70,
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Rotating radar sweep
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1500),
              builder: (context, value, child) {
                return Transform.rotate(
                  angle: value * 2 * 3.14159,
                  child: CustomPaint(
                    size: const Size(60, 60),
                    painter: _RadarSweepPainter(progress: value),
                  ),
                );
              },
              onEnd: () {},
            ),
            // Center flash icon
            const Icon(
              Icons.flash_on,
              color: Colors.white,
              size: 28,
            ),
          ],
        ),
      );
    } else {
      // Normal connect: simple loading
      return const SizedBox(
        key: ValueKey('loading'),
        width: 40,
        height: 40,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 3,
        ),
      );
    }
  }

  // Helper to clean server name (remove country code prefix like [DE], [US], etc.)
  String _cleanServerName(String name) {
    return name.replaceAll(RegExp(r'^\[[A-Z]{2}\]\s*'), '').trim();
  }

  Widget _buildServerCard(V2RayProvider provider) {
    final isSmartConnect = provider.wasUsingSmartConnect;
    final selectedConfig = provider.selectedConfig ?? provider.activeConfig;
    
    // Determine what to show
    final String serverName;
    final String? serverSubtitle;
    final String? countryCode;
    
    if (provider.activeConfig != null) {
      // Connected - show actual server
      serverName = _cleanServerName(provider.activeConfig!.remark);
      serverSubtitle = provider.activeConfig!.countryCode != null 
          ? provider.activeConfig!.countryName 
          : null;
      countryCode = provider.activeConfig!.countryCode;
    } else if (isSmartConnect) {
      // Smart Connect selected
      serverName = AppLocalizations.of(context).translate('server_selection.smart_connect');
      serverSubtitle = AppLocalizations.of(context).translate('server_selection.smart_connect_description');
      countryCode = null;
    } else if (selectedConfig != null) {
      // Specific server selected
      serverName = _cleanServerName(selectedConfig.remark);
      serverSubtitle = selectedConfig.countryCode != null ? selectedConfig.countryName : null;
      countryCode = selectedConfig.countryCode;
    } else {
      // Nothing selected
      serverName = AppLocalizations.of(context).translate('server_selection.select_server');
      serverSubtitle = null;
      countryCode = null;
    }
    
    return GestureDetector(
      onTap: () {
        if (provider.activeConfig != null) {
          // Show dialog asking user to disconnect first
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).translate('server_selector.connection_active'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Text(
                  AppLocalizations.of(context).translate('server_selector.disconnect_first'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      AppLocalizations.of(context).translate('common.ok'),
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ServerSelectionScreen(),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            // Country Flag or Smart Connect Icon
            if (countryCode != null) ...[
              // Show country flag image
              Container(
                width: 48,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: 'https://flagcdn.com/w160/${countryCode.toLowerCase()}.png',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.white.withValues(alpha: 0.1),
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      child: const Icon(Icons.public, color: Color(0xFF6366F1), size: 24),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Smart Connect or Globe icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSmartConnect && provider.activeConfig == null
                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                      : const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSmartConnect && provider.activeConfig == null
                      ? Icons.flash_on
                      : Icons.language,
                  color: isSmartConnect && provider.activeConfig == null
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6366F1),
                  size: 24,
                ),
              ),
            ],
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).translate('home.server_location_label'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    serverName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (serverSubtitle != null)
                    Text(
                      serverSubtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: 0.3),
              size: 18,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.2, end: 0);
  }

  Widget _buildStatsGrid(V2RayProvider provider) {
    final v2rayService = provider.v2rayService;
    
    // بهینه‌سازی: هر 2 ثانیه به جای 1 ثانیه (کاهش 50% rebuild)
    return RepaintBoundary(
      child: StreamBuilder(
        key: const ValueKey('stats'),
        stream: Stream.periodic(const Duration(seconds: 2)),
        builder: (context, snapshot) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: _statsDecoration ??= BoxDecoration(
              // Glass effect matching background
              color: const Color(0xFF0A0E1A).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          child: Builder(
            builder: (context) {
              final tr = AppLocalizations.of(context);
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.timer,
                          label: tr.translate('home.duration'),
                          value: v2rayService.getFormattedConnectedTime(),
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.upload,
                          label: tr.translate('home.upload'),
                          value: v2rayService.getFormattedUpload(),
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.download,
                          label: tr.translate('home.download'),
                          value: v2rayService.getFormattedDownload(),
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.public,
                          label: tr.translate('home.ip_address'),
                          value: v2rayService.ipInfo?.ip ?? '...',
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

}

// Pulse Ring Animation Widget
class _PulseRing extends StatefulWidget {
  final double delay;
  final double size;
  final Color color;

  const _PulseRing({
    required this.delay,
    required this.size,
    required this.color,
  });

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Start animation with delay
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color,
                  width: 2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Radar sweep painter for Smart Connect animation
class _RadarSweepPainter extends CustomPainter {
  final double progress;

  _RadarSweepPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw radar circles
    final circlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, radius * 0.4, circlePaint);
    canvas.drawCircle(center, radius * 0.7, circlePaint);
    canvas.drawCircle(center, radius, circlePaint);

    // Draw sweep gradient
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 3.14159 / 2,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.4),
          const Color(0xFF10B981).withValues(alpha: 0.6),
        ],
        transform: GradientRotation(progress * 2 * 3.14159),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);
  }

  @override
  bool shouldRepaint(_RadarSweepPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
