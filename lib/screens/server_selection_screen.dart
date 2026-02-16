import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../models/v2ray_config.dart';
import '../utils/app_localizations.dart';
import '../utils/country_flags.dart';
import '../widgets/app_background.dart';

class ServerSelectionScreen extends StatefulWidget {
  const ServerSelectionScreen({super.key});

  @override
  State<ServerSelectionScreen> createState() => _ServerSelectionScreenState();
}

class _ServerSelectionScreenState extends State<ServerSelectionScreen>
    with TickerProviderStateMixin {
  bool _isTesting = false;
  bool _isRefreshing = false;
  final Map<String, int> _pingResults = {};
  List<V2RayConfig>? _sortedConfigs;
  late AnimationController _refreshAnimController;
  late PageController _pageController;
  int _currentTab = 0; // 0 = Free, 1 = Premium
  
  // V2Ray core delay test
  String _testStatusText = '';
  int _testedCount = 0;
  int _totalCount = 0;
  int _batchSize = 10; // Default batch size

  @override
  void initState() {
    super.initState();
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pageController = PageController(initialPage: 0);
    
    // Load batch size
    _loadBatchSize();
    
    // Preload flags when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadFlags();
    });
  }
  
  /// Load batch size from SharedPreferences
  Future<void> _loadBatchSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBatchSize = prefs.getInt('ping_batch_size') ?? 10;
      if (mounted) {
        setState(() {
          _batchSize = savedBatchSize.clamp(1, 20); // Between 1-20
        });
      }
    } catch (e) {
      debugPrint('Error loading batch size: $e');
    }
  }

  /// Preload all country flags in background
  Future<void> _preloadFlags() async {
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    final configs = provider.serverConfigs;
    
    // Get unique country codes
    final countryCodes = configs
        .map((c) => c.countryCode)
        .where((code) => code != null && CountryFlags.isValidCountryCode(code))
        .toSet();
    
    // Preload each flag
    for (final code in countryCodes) {
      if (!mounted) break;
      final url = CountryFlags.getFlagUrl(code);
      try {
        await precacheImage(
          CachedNetworkImageProvider(url),
          context,
        ).timeout(const Duration(seconds: 3), onTimeout: () {});
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _refreshAnimController.dispose();
    _pageController.dispose();
    _sortedConfigs = null;
    _pingResults.clear();
    super.dispose();
  }

  Future<void> _refreshServers() async {
    if (_isRefreshing || !mounted) return;
    
    setState(() => _isRefreshing = true);
    _refreshAnimController.repeat();
    
    try {
      final provider = Provider.of<V2RayProvider>(context, listen: false);
      
      debugPrint('🔄 Refreshing servers...');
      await provider.fetchServers();
      
      if (mounted) {
        setState(() {
          _sortedConfigs = null;
          _pingResults.clear();
        });
        
        // Show appropriate message based on result
        if (provider.errorMessage.isEmpty && provider.serverConfigs.isNotEmpty) {
          _showSnackBar(
            AppLocalizations.of(context).translate('server_selection.servers_updated'),
            const Color(0xFF10B981),
          );
        } else if (provider.errorMessage.isNotEmpty) {
          // Show error to user
          _showSnackBar(
            provider.errorMessage,
            Colors.orange,
          );
        } else if (provider.serverConfigs.isEmpty) {
          _showSnackBar(
            'No servers available',
            Colors.orange,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error refreshing servers: $e');
      if (mounted) {
        _showSnackBar(
          'Failed to refresh: ${e.toString()}',
          Colors.red,
        );
      }
    } finally {
      if (mounted) {
        _refreshAnimController.stop();
        _refreshAnimController.reset();
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Directionality(
      textDirection: languageProvider.textDirection,
      child: AppBackground(
        useSecondaryBackground: true,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildTabButtons(),
              if (_currentTab == 0) _buildActionButtons(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentTab = index);
                  },
                  children: [
                    _buildFreeServersTab(),
                    _buildPremiumTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 16 : 20,
        12,
        isSmallScreen ? 16 : 20,
        16,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: isSmallScreen ? 40 : 44,
              height: isSmallScreen ? 40 : 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: const Color(0xFF00D9FF),
                size: isSmallScreen ? 16 : 18,
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).translate('server_selection.title'),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 18 : 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context).translate('server_selection.select_server'),
                  style: TextStyle(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.5),
                    fontSize: isSmallScreen ? 11 : 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButtons() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
        vertical: 12,
      ),
      child: Container(
        height: isSmallScreen ? 48 : 52,
        decoration: BoxDecoration(
          color: const Color(0xFF0A1929).withValues(alpha: 0.6),
          border: Border.all(
            color: const Color(0xFF00D9FF).withValues(alpha: 0.15),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Free Tab
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _currentTab = 0);
                  _pageController.animateToPage(0, 
                    duration: const Duration(milliseconds: 300), 
                    curve: Curves.easeInOut);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 12),
                  decoration: BoxDecoration(
                    gradient: _currentTab == 0
                        ? const LinearGradient(
                            colors: [Color(0xFF00D9FF), Color(0xFF0088CC)],
                          )
                        : null,
                    color: _currentTab == 0 ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.public,
                        color: _currentTab == 0 
                            ? Colors.white 
                            : Colors.white.withValues(alpha: 0.4),
                        size: isSmallScreen ? 18 : 20,
                      ),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context).translate('server_selection.free'),
                          style: TextStyle(
                            color: _currentTab == 0 
                                ? Colors.white 
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: isSmallScreen ? 13 : 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Premium Tab
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _currentTab = 1);
                  _pageController.animateToPage(1, 
                    duration: const Duration(milliseconds: 300), 
                    curve: Curves.easeInOut);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 12),
                  decoration: BoxDecoration(
                    gradient: _currentTab == 1
                        ? const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          )
                        : null,
                    color: _currentTab == 1 ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        color: _currentTab == 1 
                            ? Colors.white 
                            : Colors.white.withValues(alpha: 0.4),
                        size: isSmallScreen ? 18 : 20,
                      ),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context).translate('server_selection.premium'),
                          style: TextStyle(
                            color: _currentTab == 1 
                                ? Colors.white 
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: isSmallScreen ? 13 : 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 16 : 20,
        8,
        isSmallScreen ? 16 : 20,
        12,
      ),
      child: Row(
        children: [
          // Refresh button
          GestureDetector(
            onTap: _isRefreshing ? null : _refreshServers,
            child: Container(
              width: isSmallScreen ? 48 : 52,
              height: isSmallScreen ? 48 : 52,
              decoration: BoxDecoration(
                color: const Color(0xFF0A1929).withValues(alpha: 0.5),
                border: Border.all(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.25),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: RotationTransition(
                turns: _refreshAnimController,
                child: Icon(
                  Icons.refresh_rounded,
                  color: _isRefreshing 
                      ? const Color(0xFF00FFA3) 
                      : const Color(0xFF00D9FF),
                  size: isSmallScreen ? 22 : 24,
                ),
              ),
            ),
          ),
          
          SizedBox(width: isSmallScreen ? 10 : 12),
          
          // Test Ping button - expanded
          Expanded(
            child: GestureDetector(
              onTap: _isTesting ? null : _testAllServerPings,
              child: Container(
                height: isSmallScreen ? 48 : 52,
                decoration: BoxDecoration(
                  gradient: _isTesting 
                      ? LinearGradient(
                          colors: [Colors.grey.shade700, Colors.grey.shade800],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF00D9FF), Color(0xFF0088CC)],
                        ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: !_isTesting ? [
                    BoxShadow(
                      color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ] : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isTesting)
                      SizedBox(
                        width: isSmallScreen ? 16 : 18,
                        height: isSmallScreen ? 16 : 18,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(Icons.speed_rounded, color: Colors.white, size: isSmallScreen ? 20 : 22),
                    SizedBox(width: isSmallScreen ? 8 : 10),
                    Flexible(
                      child: Text(
                        _isTesting 
                            ? (_testStatusText.isNotEmpty ? _testStatusText : '...') 
                            : AppLocalizations.of(context).translate('server_selection.test_ping'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 14 : 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildFreeServersTab() {
    return Consumer<V2RayProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingServers) return _buildLoadingState();
        
        List<V2RayConfig> configs;
        if (_sortedConfigs != null) {
          configs = _sortedConfigs!;
        } else {
          final smartConnect = V2RayConfig.smartConnect();
          configs = [smartConnect, ...provider.configs];
        }
        
        if (configs.length <= 1) return _buildEmptyState(context);
        return _buildServerList(context, provider, configs);
      },
    );
  }

  Widget _buildPremiumTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360 || screenHeight < 700;
    
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 32 : 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium Icon
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 28 : 32),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1929).withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                size: isSmallScreen ? 56 : 64,
                color: const Color(0xFFFFD700),
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 32 : 40),
            
            // Title
            Text(
              AppLocalizations.of(context).translate('server_selection.premium'),
              style: GoogleFonts.poppins(
                fontSize: isSmallScreen ? 26 : 30,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFFD700),
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 16 : 20),
            
            // Coming Soon
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 20 : 28,
                vertical: isSmallScreen ? 12 : 16,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1929).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                    size: isSmallScreen ? 20 : 24,
                  ),
                  SizedBox(width: isSmallScreen ? 10 : 12),
                  Text(
                    AppLocalizations.of(context).translate('server_selection.coming_soon'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: isSmallScreen ? 15 : 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerList(BuildContext context, V2RayProvider provider, List<V2RayConfig> configs) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: 8,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: configs.length,
      itemBuilder: (context, index) {
        final config = configs[index];
        if (config.isSmartConnect) {
          return _buildSmartConnectCard(context, provider);
        }
        final isSelected = !provider.wasUsingSmartConnect && 
            provider.selectedConfig?.id == config.id;
        return _buildServerCard(context, provider, config, isSelected);
      },
    );
  }

  Widget _buildSmartConnectCard(BuildContext context, V2RayProvider provider) {
    final isSelected = provider.wasUsingSmartConnect;
    final isConnected = provider.activeConfig != null;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isFarsi = languageProvider.currentLanguage.code == 'fa';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00FFA3).withValues(alpha: 0.15),
            const Color(0xFF00D9FF).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected 
              ? const Color(0xFF00FFA3).withValues(alpha: 0.6) 
              : const Color(0xFF00D9FF).withValues(alpha: 0.3),
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: const Color(0xFF00FFA3).withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ] : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isConnected) {
              _showDisconnectFirstDialog(context);
            } else {
              provider.selectConfig(V2RayConfig.smartConnect());
              Navigator.pop(context);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon with glow effect
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00FFA3), Color(0xFF00D9FF)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FFA3).withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            AppLocalizations.of(context).translate('server_selection.auto_select'),
                            style: isFarsi 
                                ? const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  )
                                : GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00FFA3), Color(0xFF00D9FF)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'AUTO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context).translate('server_selection.auto_select_description'),
                        style: TextStyle(
                          color: const Color(0xFF00D9FF).withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  color: const Color(0xFF00FFA3).withValues(alpha: 0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServerCard(BuildContext context, V2RayProvider provider, V2RayConfig config, bool isSelected) {
    final countryCode = config.countryCode ?? _extractCountryCode(config.remark);
    final ping = _pingResults[config.id];
    final isConnected = provider.activeConfig != null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected 
              ? const Color(0xFF00D9FF).withValues(alpha: 0.5) 
              : const Color(0xFF00D9FF).withValues(alpha: 0.15),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ] : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isConnected) {
              _showDisconnectFirstDialog(context);
            } else {
              provider.selectConfig(config);
              Navigator.pop(context);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Country Flag
                _buildCountryFlag(countryCode),
                const SizedBox(width: 14),
                // Server Name
                Expanded(
                  child: Text(
                    _cleanServerName(config.remark),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Ping indicator
                if (ping != null) ...[
                  _buildPingIndicator(ping),
                  const SizedBox(width: 10),
                ],
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountryFlag(String? countryCode) {
    if (countryCode == null || !CountryFlags.isValidCountryCode(countryCode)) {
      return Container(
        width: 40,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.public, color: Colors.white54, size: 18),
      );
    }
    
    return Container(
      width: 40,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: CountryFlags.getFlagUrl(countryCode),
          fit: BoxFit.cover,
          // Server selection: smaller flag (40x28 container)
          memCacheWidth: 80,
          memCacheHeight: 56,
          maxWidthDiskCache: 80,
          maxHeightDiskCache: 56,
          fadeInDuration: const Duration(milliseconds: 100),
          fadeOutDuration: const Duration(milliseconds: 100),
          placeholderFadeInDuration: Duration.zero,
          placeholder: (context, url) => Container(
            color: Colors.white.withValues(alpha: 0.1),
            child: const Center(
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white24),
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.white.withValues(alpha: 0.1),
            child: const Icon(Icons.flag, color: Colors.white54, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildPingIndicator(int ping) {
    Color pingColor;
    String pingText;
    
    if (ping >= 99999) {
      // Timeout - no response
      pingColor = Colors.red.shade400;
      pingText = 'Timeout';
    } else if (ping < 500) {
      // 0-499ms: سبز-cyan (عالی)
      pingColor = const Color(0xFF00FFA3);
      pingText = '${ping}ms';
    } else if (ping < 1000) {
      // 500-999ms: cyan (خوب)
      pingColor = const Color(0xFF00D9FF);
      pingText = '${ping}ms';
    } else if (ping < 2000) {
      // 1000-1999ms: نارنجی (متوسط)
      pingColor = Colors.orange.shade400;
      pingText = '${ping}ms';
    } else {
      // 2000ms+: قرمز (ضعیف)
      pingColor = Colors.red.shade400;
      pingText = '${ping}ms';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: pingColor.withValues(alpha: 0.15),
        border: Border.all(
          color: pingColor.withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        pingText,
        style: TextStyle(
          color: pingColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF10B981)),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).translate('common.loading_servers'),
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).translate('server_selection.no_servers_available'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _refreshServers,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _extractCountryCode(String remark) {
    return CountryFlags.extractCountryCode(remark);
  }

  String _cleanServerName(String remark) {
    // Remove country code patterns: [CC], (CC), CC-
    String clean = remark;
    clean = clean.replaceAll(RegExp(r'^[\[\(][A-Z]{2}[\]\)]\s*'), '');
    clean = clean.replaceAll(RegExp(r'^[A-Z]{2}[-\s]+'), '');
    return clean.trim().isEmpty ? remark : clean.trim();
  }

  /// Test all servers using V2Ray core delay
  /// This is more accurate for V2Ray servers
  Future<void> _testAllServerPings() async {
    if (_isTesting || !mounted) return;
    
    setState(() {
      _isTesting = true;
      _pingResults.clear();
      _sortedConfigs = null; // Reset sorting
      _testedCount = 0;
      _totalCount = 0;
      _testStatusText = 'Initializing...';
    });

    final V2RayProvider provider;
    try {
      provider = Provider.of<V2RayProvider>(context, listen: false);
    } catch (e) {
      debugPrint('❌ Could not get provider: $e');
      if (mounted) setState(() => _isTesting = false);
      return;
    }
    
    final configs = provider.serverConfigs;
    if (configs.isEmpty) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testStatusText = '';
        });
        _showSnackBar(
          AppLocalizations.of(context).translate('server_selection.no_servers_available'),
          Colors.orange,
        );
      }
      return;
    }

    try {
      debugPrint('🚀 Starting V2Ray core delay test for ${configs.length} servers');
      debugPrint('📦 Batch size: $_batchSize servers at a time');
      
      setState(() {
        _totalCount = configs.length;
        _testStatusText = '0 / $_totalCount';
      });
      
      // Test servers in batches
      int successCount = 0;
      
      for (int i = 0; i < configs.length; i += _batchSize) {
        if (!mounted || !_isTesting) break;
        
        final end = (i + _batchSize < configs.length) ? i + _batchSize : configs.length;
        final batch = configs.sublist(i, end);
        
        debugPrint('📊 Testing batch ${i ~/ _batchSize + 1}: servers $i to ${end - 1}');
        
        // Test batch in parallel but update UI as each completes
        final futures = <Future<void>>[];
        
        for (int j = 0; j < batch.length; j++) {
          final config = batch[j];
          final serverIndex = i + j;
          
          futures.add(
            _testSingleServer(config, provider).then((delay) {
              if (delay >= 0 && delay < 10000) {
                _pingResults[config.id] = delay;
                successCount++;
                debugPrint('   ✅ ${config.remark}: ${delay}ms');
              } else {
                _pingResults[config.id] = 99999; // Timeout
                debugPrint('   ❌ ${config.remark}: Timeout');
              }
              
              // Update UI immediately after this server is tested
              // AND sort servers in real-time
              if (mounted) {
                setState(() {
                  _testedCount = serverIndex + 1;
                  _testStatusText = '$_testedCount / $_totalCount';
                  // Sort servers immediately after each result
                  _sortServersByPing(provider, _pingResults);
                });
              }
            }),
          );
        }
        
        // Wait for all servers in this batch to complete
        await Future.wait(futures);
        
        // Small delay between batches
        if (end < configs.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      if (!mounted) return;
      
      // Final sort (already sorted in real-time, but ensure it's final)
      _sortServersByPing(provider, _pingResults);
      
      // Show completion message
      if (mounted) {
        _showSnackBar(
          '${AppLocalizations.of(context).translate('server_selection.servers_updated')} ($successCount/${configs.length})',
          const Color(0xFF10B981),
        );
      }
      
      debugPrint('✅ Ping test completed: $successCount/${configs.length} servers responded');
      
    } catch (e) {
      debugPrint('❌ Error testing pings: $e');
      if (mounted) {
        _showSnackBar(
          AppLocalizations.of(context).translate('server_selection.error_updating'),
          Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testStatusText = '';
        });
      }
    }
  }
  
  /// Test single server using V2Ray core delay
  Future<int> _testSingleServer(V2RayConfig config, V2RayProvider provider) async {
    try {
      final delay = await provider.v2rayService.getServerDelay(config).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('Timeout for ${config.remark}');
          return -1;
        },
      );
      
      return delay ?? -1;
    } catch (e) {
      debugPrint('Error testing ${config.remark}: $e');
      return -1;
    }
  }

  void _showDisconnectFirstDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context).translate('server_selector.connection_active'),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          AppLocalizations.of(context).translate('server_selector.disconnect_first'),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context).translate('common.ok'),
              style: const TextStyle(color: Color(0xFF6366F1), fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _sortServersByPing(V2RayProvider provider, Map<String, int> pingResults) {
    final smartConnect = V2RayConfig.smartConnect();
    final serverConfigs = List<V2RayConfig>.from(provider.serverConfigs);
    
    // Sort by ping: lowest (best) first, timeout (99999) at the end
    serverConfigs.sort((a, b) {
      final pingA = pingResults[a.id] ?? 99999;
      final pingB = pingResults[b.id] ?? 99999;
      // Lower ping = better = comes first
      return pingA.compareTo(pingB);
    });
    
    setState(() => _sortedConfigs = [smartConnect, ...serverConfigs]);
  }
}
