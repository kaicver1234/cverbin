import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../models/v2ray_config.dart';
import '../widgets/vpn_gradient_background.dart';
import '../utils/app_localizations.dart';

class ServerSelectionScreen extends StatefulWidget {
  const ServerSelectionScreen({super.key});

  @override
  State<ServerSelectionScreen> createState() =>
      _ServerSelectionScreenState();
}

class _ServerSelectionScreenState
    extends State<ServerSelectionScreen>
    with TickerProviderStateMixin {
  bool _isTestingPings = false;
  bool _isRefreshing = false;
  final Map<String, int> _serverPings = {}; // Map of server ID to ping
  
  late AnimationController _pingAnimationController;
  late AnimationController _refreshAnimationController;

  @override
  void initState() {
    super.initState();
    _pingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _refreshAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _loadData();
  }

  @override
  void dispose() {
    _pingAnimationController.dispose();
    _refreshAnimationController.dispose();
    super.dispose();
  }

  void _loadData() {
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    // Initialize with existing data if available
    if (provider.configs.isNotEmpty) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _refreshServers() async {
    if (_isRefreshing) return;
    
    if (!mounted) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    // Start rotation animation
    _refreshAnimationController.repeat();
    
    try {
      final provider = Provider.of<V2RayProvider>(context, listen: false);
      
      // Clear old ping results before refreshing
      if (mounted) {
        setState(() {
          _serverPings.clear();
        });
      }
      
      // Show loading message
      _showSnackBar('🔄 Refreshing servers...', Colors.blue, duration: 2);
      
      // Update all subscriptions to get fresh server list
      await provider.updateAllSubscriptions();
      
      if (!mounted) return;
      
      if (provider.errorMessage.isEmpty) {
        // Success
        _showSnackBar('✅ Servers updated successfully!', Colors.green, duration: 2);
        
        // Optional: Auto-test pings after refresh
        // Uncomment if you want automatic ping test
        // await Future.delayed(const Duration(milliseconds: 500));
        // await _testAllServersPing();
      } else {
        // Error
        _showSnackBar('❌ ${provider.errorMessage}', Colors.red, duration: 3);
        provider.clearError();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('❌ Error: $e', Colors.red, duration: 3);
      }
    } finally {
      // Stop animation
      _refreshAnimationController.stop();
      _refreshAnimationController.reset();
      
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _testAllServersPing() async {
    if (_isTestingPings) return;
    
    if (!mounted) return;
    
    setState(() {
      _isTestingPings = true;
      _serverPings.clear();
    });
    
    _pingAnimationController.repeat();
    
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    final allServers = _getFilteredServers(provider);
    
    // IMPORTANT: Exclude Smart Connect from ping testing
    final servers = allServers.where((s) => !s.isSmartConnect).toList();
    
    // Clear any stuck ping progress flags before starting
    provider.v2rayService.clearPingProgress();
    
    _showSnackBar('🔍 Testing ${servers.length} servers...', Colors.blue, duration: 2);
    
    int successCount = 0;
    int totalPing = 0;
    
    try {
      // Test servers one by one (sequential)
      for (int i = 0; i < servers.length; i++) {
        if (!mounted || !_isTestingPings) break;
        
        final server = servers[i];
        
        debugPrint('🏓 Testing server ${i + 1}/${servers.length}: ${server.remark}');
        
        try {
          // Test single server with timeout
          final delay = await provider.v2rayService.getServerDelay(server).timeout(
            const Duration(seconds: 10),
            onTimeout: () => 9999,
          );
          
          if (!mounted) break;
          
          // Handle nullable delay value
          final pingValue = delay ?? 9999;
          
          // Update UI immediately with this server's result
          setState(() {
            _serverPings[server.id] = pingValue;
          });
          
          if (pingValue < 9999) {
            successCount++;
            totalPing += pingValue;
            debugPrint('   ✅ ${server.remark}: ${pingValue}ms');
          } else {
            debugPrint('   ❌ ${server.remark}: Timeout');
          }
          
        } catch (e) {
          debugPrint('   ⚠️ ${server.remark}: Error - $e');
          // Set timeout for failed servers
          if (mounted) {
            setState(() {
              _serverPings[server.id] = 9999;
            });
          }
        }
        
        // Small delay between tests to prevent overwhelming the system
        if (i < servers.length - 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      // Calculate statistics
      final avgPing = successCount > 0 ? totalPing ~/ successCount : 0;
      
      String message;
      if (successCount == 0) {
        message = '❌ No servers responded';
      } else if (successCount == servers.length) {
        message = '✅ All servers online (Avg: ${avgPing}ms)';
      } else {
        message = '✅ $successCount/${servers.length} servers online (Avg: ${avgPing}ms)';
      }
      
      if (mounted) {
        _showSnackBar(message, successCount > 0 ? Colors.green : Colors.red, duration: 3);
      }
      
    } catch (e) {
      debugPrint('❌ Error during ping test: $e');
      if (mounted) {
        _showSnackBar('❌ Error testing servers: $e', Colors.red, duration: 3);
      }
    } finally {
      _pingAnimationController.stop();
      if (mounted) {
        setState(() {
          _isTestingPings = false;
        });
      }
    }
  }

  Future<void> _connectToFastestServer() async {
    if (_serverPings.isEmpty) {
      await _testAllServersPing();
    }
    
    if (_serverPings.isEmpty) {
      _showSnackBar('No servers available', Colors.red);
      return;
    }
    
    // Find server with lowest ping
    String? fastestServerId;
    int lowestPing = 999999;
    
    _serverPings.forEach((serverId, ping) {
      if (ping < lowestPing && ping < 9999) {
        lowestPing = ping;
        fastestServerId = serverId;
      }
    });
    
    if (fastestServerId != null) {
      final provider = Provider.of<V2RayProvider>(context, listen: false);
      final server = provider.configs.firstWhere(
        (s) => s.id == fastestServerId,
      );
      
      await provider.selectConfig(server);
      await provider.connectToServer(server);
      
      if (!mounted) return;
      
      final serverName = server.isSmartConnect 
          ? AppLocalizations.of(context).translate('server_selection.smart_connect')
          : server.remark;
      _showSnackBar('Connected to fastest server: $serverName ($lowestPing ms)', Colors.green);
      Navigator.pop(context, server);
    } else {
      if (!mounted) return;
      _showSnackBar('No fast server found', Colors.red);
    }
  }

  List<V2RayConfig> _getFilteredServers(V2RayProvider provider) {
    var servers = provider.configs.toList();
    
    // Separate Smart Connect from regular servers
    V2RayConfig? smartConnect;
    List<V2RayConfig> regularServers = [];
    
    for (var server in servers) {
      if (server.isSmartConnect) {
        smartConnect = server;
      } else {
        regularServers.add(server);
      }
    }
    
    // Sort regular servers by ping if available
    if (_serverPings.isNotEmpty) {
      regularServers.sort((a, b) {
        final pingA = _serverPings[a.id] ?? 999999;
        final pingB = _serverPings[b.id] ?? 999999;
        return pingA.compareTo(pingB);
      });
    }
    
    // IMPORTANT: Smart Connect always stays at the top
    if (smartConnect != null) {
      return [smartConnect, ...regularServers];
    }
    
    return regularServers;
  }

  void _showSnackBar(String message, Color color, {int duration = 4}) {
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
        duration: Duration(seconds: duration),
      ),
    );
  }

  // رنگ‌بندی پینگ بر اساس مقدار
  Color _getPingColor(int ping) {
    if (ping < 1000) {
      // 0-999ms: سبز (عالی)
      return const Color(0xFF10B981); // Green
    } else if (ping < 2000) {
      // 1000-1999ms: نارنجی (متوسط)
      return const Color(0xFFF59E0B); // Orange
    } else {
      // 2000+ms: قرمز (ضعیف)
      return const Color(0xFFEF4444); // Red
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer2<LanguageProvider, V2RayProvider>(
      builder: (context, languageProvider, v2rayProvider, child) {
        final servers = _getFilteredServers(v2rayProvider);
        final isConnected = v2rayProvider.activeConfig != null;
        
        // Determine background status based on connection state
        final backgroundStatus = isConnected 
            ? VPNBackgroundStatus.connected 
            : VPNBackgroundStatus.disconnected;
        
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: VPNGradientBackground(
            status: backgroundStatus,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Column(
                  children: [
                    // Modern App Bar
                    _buildAppBar(context),
                    
                    const SizedBox(height: 12),
                    
                    // Server List
                    Expanded(
                      child: servers.isEmpty
                          ? _buildEmptyState()
                          : _buildServerList(servers, v2rayProvider),
                    ),
                  ],
                ),
              ),
              // Bottom Action Bar با دکمه‌های تست پینگ و اتصال سریع
              bottomNavigationBar: _buildBottomActionBar(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {
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
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Text(
              'Select Server',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          
          // Refresh Button
          GestureDetector(
            onTap: _isRefreshing ? null : _refreshServers,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isRefreshing 
                    ? Colors.blue.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isRefreshing
                      ? Colors.blue.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.2),
                  width: _isRefreshing ? 2 : 1,
                ),
              ),
              child: _isRefreshing
                  ? RotationTransition(
                      turns: Tween(begin: 0.0, end: 1.0).animate(_refreshAnimationController),
                      child: const Icon(
                        Icons.refresh,
                        color: Colors.blue,
                        size: 22,
                      ),
                    )
                  : const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Server count info removed as requested

  Widget _buildBottomActionBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.3),
            Colors.black.withValues(alpha: 0.5),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 12),
        child: Row(
          children: [
            // Test Ping Button
            Expanded(
              child: _buildModernActionButton(
                label: AppLocalizations.of(context).translate('server_selection.test_pings'),
                icon: Icons.speed_rounded,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981),
                    const Color(0xFF059669),
                  ],
                ),
                isLoading: _isTestingPings,
                onTap: _testAllServersPing,
              ),
            ),
            const SizedBox(width: 12),
            // Auto Connect Button
            Expanded(
              child: _buildModernActionButton(
                label: AppLocalizations.of(context).translate('server_selection.auto_connect'),
                icon: Icons.flash_on_rounded,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1),
                    const Color(0xFF4F46E5),
                  ],
                ),
                onTap: _connectToFastestServer,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildModernActionButton({
    required String label,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(
                icon,
                color: Colors.white,
                size: 26,
              ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No servers found',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try refreshing or changing filters',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerList(List<V2RayConfig> servers, V2RayProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const ClampingScrollPhysics(),
      itemCount: servers.length,
      itemBuilder: (context, index) {
        final server = servers[index];
        final isActive = provider.activeConfig?.remark == server.remark;
        final ping = _serverPings[server.id];
        
        return _buildServerItem(
          server: server,
          isActive: isActive,
          ping: ping,
          index: index,
          onTap: () async {
            await provider.selectConfig(server);
            if (!mounted) return;
            Navigator.pop(context, server);
            final serverName = server.isSmartConnect 
                ? AppLocalizations.of(context).translate('server_selection.smart_connect')
                : server.remark;
            _showSnackBar('Server selected: $serverName', Colors.blue);
          },
        );
      },
    );
  }

  Widget _buildServerItem({
    required V2RayConfig server,
    required bool isActive,
    int? ping,
    required int index,
    required VoidCallback onTap,
  }) {
    String pingText = '';
    
    if (ping != null) {
      if (ping < 0 || ping >= 9999) {
        pingText = 'Timeout';
      } else {
        pingText = '${ping}ms';
      }
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF1E293B).withValues(alpha: 0.9)
              : const Color(0xFF1E293B).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main Content
            Row(
              children: [
                // Server Flag or Smart Connect Icon
                Hero(
                  tag: 'server_${server.id}',
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.5),
                      child: server.isSmartConnect
                          ? Padding(
                              padding: const EdgeInsets.all(6),
                              child: Image.asset(
                                'assets/images/apk.png',
                                width: 28,
                                height: 28,
                                fit: BoxFit.contain,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: server.countryFlagUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Text(
                                  server.countryFlag,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 10),
                
                // Server Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Server Name
                      Text(
                        server.isSmartConnect 
                            ? AppLocalizations.of(context).translate('server_selection.smart_connect')
                            : server.remark,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Smart Connect Description
                      if (server.isSmartConnect) ...[
                        const SizedBox(height: 3),
                        Text(
                          AppLocalizations.of(context).translate('server_selection.smart_connect_description'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            // Active Badge
            if (isActive)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 10,
                        color: Colors.white,
                      ),
                      SizedBox(width: 2),
                      Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Loading Indicator
            if (_isTestingPings && ping == null && !isActive)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF475569).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            
            // Ping Display (replaces arrow icon)
            if (!isActive && !(_isTestingPings && ping == null) && !server.isSmartConnect)
              Positioned(
                top: 0,
                bottom: 0,
                right: 8,
                child: Center(
                  child: ping != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getPingColor(ping).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _getPingColor(ping).withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.speed_rounded,
                                size: 10,
                                color: _getPingColor(ping),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                pingText,
                                style: TextStyle(
                                  color: _getPingColor(ping),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 12,
                        ),
                ),
              ),
            // Arrow Icon for Smart Connect (no ping test)
            if (!isActive && !(_isTestingPings && ping == null) && server.isSmartConnect)
              Positioned(
                top: 0,
                bottom: 0,
                right: 8,
                child: Center(
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

}
