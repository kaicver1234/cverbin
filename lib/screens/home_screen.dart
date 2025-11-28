import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/vpn_gradient_background.dart';
import '../models/app_language.dart';
import '../models/v2ray_config.dart';
import '../utils/app_localizations.dart';
import '../utils/app_colors.dart';
import '../screens/ip_info_screen.dart';
import '../screens/speedtest_screen.dart';
import '../screens/host_checker_screen.dart';
import '../screens/about_screen.dart';
import 'server_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  bool _isConnecting = false;
  bool _isFindingServer = false; // For smart connect searching state
  late PageController _pageController;
  int _currentPage = 0;
  BoxDecoration? _statsDecoration; // Cache decoration for performance
  String _currentIp = 'Loading...';
  
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
    
    // Check VPN status when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<V2RayProvider>(context, listen: false);
        provider.forceCheckVpnStatus();
      }
    });
  }
  
  Future<void> _fetchCurrentIp() async {
    setState(() {
      _currentIp = 'Loading...';
    });
    
    try {
      final response = await http.get(
        Uri.parse('https://api.ipify.org?format=json'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _currentIp = data['ip'] ?? 'Unknown';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentIp = 'Unknown';
        });
      }
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      // Force rebuild UI when app comes back from background
      debugPrint('🏠 HomeScreen: App resumed, checking VPN status...');
      
      // Force check actual VPN status from service
      final provider = Provider.of<V2RayProvider>(context, listen: false);
      provider.forceCheckVpnStatus().then((_) {
        if (mounted) {
          setState(() {});
        }
      });

    }
  }

  Future<void> _handleConnectionToggle() async {
    if (_isConnecting) return;

    if (!mounted) return;
    
    final provider = Provider.of<V2RayProvider>(context, listen: false);

    try {
      if (provider.activeConfig != null) {
        // Disconnect
        setState(() {
          _isConnecting = true;
        });
        await provider.disconnect();
        if (mounted) {
           _showSnackBar(AppLocalizations.of(context).translate('home.disconnected'), Colors.grey);
        }
      } else {
        // Connect based on selected config
        final selectedConfig = provider.selectedConfig;
        bool success = false;
        
        // Check if Smart Connect is selected or no specific server selected
        if (selectedConfig == null || selectedConfig.isSmartConnect) {
          // Smart Connect - find best server
          debugPrint('🧠 Smart Connect: Finding best server...');
          
          setState(() {
            _isConnecting = true;
            _isFindingServer = true;
          });
          
          success = await provider.smartConnect();
          
          if (mounted) {
            setState(() {
              _isFindingServer = false;
            });
          }
        } else {
          // Direct connect to selected server
          debugPrint('🔌 Direct Connect to: ${selectedConfig.remark}');
          
          setState(() {
            _isConnecting = true;
            _isFindingServer = false;
          });
          
          success = await provider.connectToServer(selectedConfig);
        }
        
        if (mounted) {
          if (success && provider.activeConfig != null) {
            final serverName = provider.wasUsingSmartConnect 
                ? '${AppLocalizations.of(context).translate('server_selection.smart_connect')} (${provider.activeConfig!.remark})'
                : provider.activeConfig!.remark;
            debugPrint('✅ Connection successful to: ${provider.activeConfig!.remark}');
            _showSnackBar('${AppLocalizations.of(context).translate('home.connected_to')}: $serverName', Colors.green);
          } else if (provider.errorMessage.isNotEmpty) {
            debugPrint('❌ Connection failed: ${provider.errorMessage}');
            _showSnackBar(provider.errorMessage, Colors.red);
          } else {
            _showSnackBar(AppLocalizations.of(context).translate('home.connection_failed'), Colors.red);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFindingServer = false;
        });
        _showSnackBar('${AppLocalizations.of(context).translate('home.connection_failed')}: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isFindingServer = false;
        });
        
        // Reset IP when disconnected, fetch when connected
        if (provider.activeConfig != null) {
          _fetchCurrentIp();
        } else {
          setState(() {
            _currentIp = 'Loading...';
          });
        }
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
              ),
              
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
                  ),
                  Text(
                    AppLocalizations.of(context).translate('home.secure_connection'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
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
    );
  }

  Widget _buildBottomTabBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // Use background colors for seamless look
        color: AppColors.topGradientReadyToConnect,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _buildTabButton(
                icon: Icons.vpn_key,
                label: AppLocalizations.of(context).translate('navigation.vpn'),
                isActive: _currentPage == 0,
                onTap: () {
                  if (_currentPage != 0) {
                    _pageController.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.fastOutSlowIn,
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTabButton(
                icon: Icons.build,
                label: AppLocalizations.of(context).translate('navigation.tools'),
                isActive: _currentPage == 1,
                onTap: () {
                  if (_currentPage != 1) {
                    _pageController.animateToPage(
                      1,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.fastOutSlowIn,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTabButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive 
                  ? Colors.white 
                  : Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive 
                    ? Colors.white 
                    : Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
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
            
            // Auto Server Info
            _buildAutoServerInfo(provider),
            
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
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Pulse Animation Rings when connected
            if (isConnected)
              ...List.generate(2, (index) {
                return _PulseRing(
                  delay: index * 0.5,
                  size: 200.0,
                );
              }),
            
            // Search Animation Rings when finding server
            if (_isFindingServer)
              ...List.generate(2, (index) {
                return _SearchRing(
                  delay: index * 0.4,
                  size: 170.0,
                );
              }),
            
            // Main Circle Button
            GestureDetector(
              onTap: _isConnecting ? null : () => _handleConnectionToggle(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: _isFindingServer ? 140 : 150,
                height: _isFindingServer ? 140 : 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: isConnected
                        ? [
                            AppColors.bottomGradientConnected.withValues(alpha: 0.9),
                            AppColors.middleGradientConnected,
                            const Color(0xFF047857),
                          ]
                        : _isFindingServer
                            ? [
                                const Color(0xFF6366F1).withValues(alpha: 0.9),
                                const Color(0xFF8B5CF6),
                                const Color(0xFF7C3AED),
                              ]
                            : [
                                const Color(0xFF6366F1).withValues(alpha: 0.9),
                                const Color(0xFF4F46E5),
                                const Color(0xFF4338CA),
                              ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isConnected
                          ? AppColors.bottomGradientConnected.withValues(alpha: 0.5)
                          : _isFindingServer
                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.5)
                              : const Color(0xFF6366F1).withValues(alpha: 0.4),
                      blurRadius: isConnected || _isFindingServer ? 40 : 25,
                      spreadRadius: isConnected || _isFindingServer ? 5 : 2,
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
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: child,
                    );
                  },
                  child: _isFindingServer
                      ? const SizedBox(
                          key: ValueKey('searching'),
                          width: 45,
                          height: 45,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : _isConnecting
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Icon(
                              isConnected 
                                  ? Icons.vpn_key
                                  : Icons.power_settings_new,
                              key: ValueKey(isConnected ? 'vpn_key' : 'power'),
                              size: 55,
                              color: Colors.white,
                            ),
                ),
              ],
            ),
          ),
        ),
          ],
        ),
        
        // Status text below button
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isFindingServer
              ? Text(
                  AppLocalizations.of(context).translate('server_selection.finding_best_server'),
                  key: const ValueKey('finding'),
                  style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : _isConnecting
                  ? Text(
                      AppLocalizations.of(context).translate('home.connecting'),
                      key: const ValueKey('connecting'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : isConnected
                      ? Text(
                          AppLocalizations.of(context).translate('home.tap_to_stop'),
                          key: const ValueKey('tap_stop'),
                          style: const TextStyle(
                            color: AppColors.bottomGradientConnected,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : Text(
                          AppLocalizations.of(context).translate('home.tap_to_connect'),
                          key: const ValueKey('tap_connect'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildAutoServerInfo(V2RayProvider provider) {
    final activeConfig = provider.activeConfig;
    final selectedConfig = provider.selectedConfig;
    final isConnected = activeConfig != null;
    
    // Determine what to show based on connection state and selection
    String titleText;
    String subtitleText;
    Widget iconWidget;
    
    if (isConnected) {
      // Connected - show what we're connected to
      if (provider.wasUsingSmartConnect) {
        titleText = AppLocalizations.of(context).translate('server_selection.smart_connect');
        subtitleText = '${AppLocalizations.of(context).translate('home.connected_to')}: ${_cleanServerName(activeConfig.remark)}';
        // Show app logo for Smart Connect
        iconWidget = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/apk.png',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
          ),
        );
      } else {
        titleText = _cleanServerName(activeConfig.remark);
        subtitleText = AppLocalizations.of(context).translate('home.connected');
        // Show flag - try countryCode first, then extract from remark
        final flagUrl = _getCountryFlagUrl(activeConfig);
        if (flagUrl != null) {
          iconWidget = ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: flagUrl,
              width: 32,
              height: 24,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Icon(Icons.flag, color: Colors.white, size: 24),
              errorWidget: (context, url, error) => const Icon(Icons.public, color: Colors.white, size: 24),
            ),
          );
        } else {
          iconWidget = const Icon(Icons.public, color: Colors.white, size: 28);
        }
      }
    } else {
      // Not connected - show selected server
      if (selectedConfig != null && selectedConfig.isSmartConnect) {
        titleText = AppLocalizations.of(context).translate('server_selection.smart_connect');
        subtitleText = AppLocalizations.of(context).translate('server_selection.smart_connect_description');
        // Show app logo for Smart Connect
        iconWidget = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/apk.png',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
          ),
        );
      } else if (selectedConfig != null) {
        titleText = _cleanServerName(selectedConfig.remark);
        subtitleText = AppLocalizations.of(context).translate('home.tap_to_connect');
        final flagUrl = _getCountryFlagUrl(selectedConfig);
        if (flagUrl != null) {
          iconWidget = ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: flagUrl,
              width: 32,
              height: 24,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Icon(Icons.flag, color: Colors.white, size: 24),
              errorWidget: (context, url, error) => const Icon(Icons.public, color: Colors.white, size: 24),
            ),
          );
        } else {
          iconWidget = const Icon(Icons.public, color: Colors.white, size: 28);
        }
      } else {
        // Default to Smart Connect
        titleText = AppLocalizations.of(context).translate('server_selection.smart_connect');
        subtitleText = AppLocalizations.of(context).translate('server_selection.smart_connect_description');
        // Show app logo for Smart Connect
        iconWidget = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/apk.png',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
          ),
        );
      }
    }
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ServerSelectionScreen()),
        );
      },
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
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: iconWidget,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(V2RayProvider provider) {
    final v2rayService = provider.v2rayService;
    
    // Fetch IP when stats grid is first displayed
    if (_currentIp == 'Loading...') {
      _fetchCurrentIp();
    }
    
    // بهینه‌سازی: حذف StreamBuilder - استفاده از Consumer که خودش notify میشه
    return RepaintBoundary(
      child: Container(
            padding: const EdgeInsets.all(16),
            decoration: _statsDecoration ??= BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x1AFFFFFF),
                  Color(0x0DFFFFFF),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0x33FFFFFF),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.timer,
                    label: AppLocalizations.of(context).translate('home.duration'),
                    value: v2rayService.getFormattedConnectedTime(),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.upload,
                    label: AppLocalizations.of(context).translate('home.upload'),
                    value: v2rayService.getFormattedUpload(),
                    color: Colors.white,
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
                    label: AppLocalizations.of(context).translate('home.download'),
                    value: v2rayService.getFormattedDownload(),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.public,
                    label: AppLocalizations.of(context).translate('home.ip_address'),
                    value: _currentIp,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.8),
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 10,
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
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  // Helper to get country flag URL from config
  String? _getCountryFlagUrl(V2RayConfig config) {
    // First try countryCode from config
    if (config.countryCode != null && config.countryCode!.length == 2) {
      return 'https://flagcdn.com/w80/${config.countryCode!.toLowerCase()}.png';
    }
    
    // Try to extract from remark: [CC] or (CC) format
    final remarkMatch = RegExp(r'[\[\(]([A-Za-z]{2})[\]\)]').firstMatch(config.remark);
    if (remarkMatch != null) {
      final code = remarkMatch.group(1)!.toLowerCase();
      return 'https://flagcdn.com/w80/$code.png';
    }
    
    return null;
  }

  // Helper to clean server name (remove country code prefix)
  String _cleanServerName(String remark) {
    // Remove country code prefix: [DE] server name -> server name
    return remark.replaceAll(RegExp(r'^\[([A-Z]{2})\]\s*'), '').trim();
  }
}

// Pulse Ring Animation Widget (for connected state)
class _PulseRing extends StatefulWidget {
  final double delay;
  final double size;

  const _PulseRing({
    required this.delay,
    required this.size,
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

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
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
                  color: const Color(0xFF10B981),
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

// Search Ring Animation Widget (for finding server state)
class _SearchRing extends StatefulWidget {
  final double delay;
  final double size;

  const _SearchRing({
    required this.delay,
    required this.size,
  });

  @override
  State<_SearchRing> createState() => _SearchRingState();
}

class _SearchRingState extends State<_SearchRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
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
                  color: const Color(0xFF8B5CF6),
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
