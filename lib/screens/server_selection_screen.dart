import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../models/v2ray_config.dart';
import '../widgets/vpn_gradient_background.dart';
import '../utils/app_localizations.dart';

class ServerSelectionScreen extends StatefulWidget {
  const ServerSelectionScreen({Key? key}) : super(key: key);

  @override
  State<ServerSelectionScreen> createState() =>
      _ServerSelectionScreenState();
}

class _ServerSelectionScreenState
    extends State<ServerSelectionScreen>
    with TickerProviderStateMixin {
  bool _isTestingPings = false;
  Map<String, int> _serverPings = {}; // Map of server ID to ping
  
  late AnimationController _listAnimationController;
  late AnimationController _pingAnimationController;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    
    _pingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _loadData();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _pingAnimationController.dispose();
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

  Future<void> _testAllServersPing() async {
    if (_isTestingPings) return;
    
    if (!mounted) return;
    
    setState(() {
      _isTestingPings = true;
      _serverPings.clear();
    });
    
    _pingAnimationController.repeat();
    
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    final servers = _getFilteredServers(provider);
    
    // Clear any stuck ping progress flags before starting
    provider.v2rayService.clearPingProgress();
    
    _showSnackBar('Testing ${servers.length} servers with V2Ray Core...', Colors.blue, duration: 2);
    
    int successCount = 0;
    
    // Test servers in batches of 2 for better reliability
    for (int i = 0; i < servers.length; i += 2) {
      final batch = servers.skip(i).take(2).toList();
      final futures = batch.map((server) async {
      try {
        // Add timeout for each server test (10 seconds max to allow for waiting)
        final ping = await _testSingleServerPing(server).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⚠️ Server ${server.remark} timed out');
            return 9999;
          },
        );
        
        if (mounted) {
          setState(() {
            _serverPings[server.id] = ping;
            if (ping < 9999) successCount++;
          });
        }
        
        return ping;
      } catch (e) {
        debugPrint('❌ Error testing ${server.remark}: $e');
        if (mounted) {
          setState(() {
            _serverPings[server.id] = 9999;
          });
        }
        return 9999;
      }
      }).toList();
      
      // Wait for this batch to complete
      try {
        await Future.wait(futures).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            debugPrint('⚠️ Batch timeout after 15s');
            return [];
          },
        );
      } catch (e) {
        debugPrint('❌ Error in batch: $e');
      }
      
      // Small delay between batches
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    _pingAnimationController.stop();
    if (!mounted) return;
    setState(() {
      _isTestingPings = false;
    });
    
    // Show final results with more details
    final avgPing = successCount > 0
        ? _serverPings.values
            .where((p) => p < 9999)
            .reduce((a, b) => a + b) ~/ successCount
        : 0;
    
    String message;
    if (successCount == 0) {
      message = '❌ No servers responded';
    } else if (successCount == servers.length) {
      message = '✅ All servers online (Avg: ${avgPing}ms)';
    } else {
      message = '✅ $successCount/${servers.length} servers online (Avg: ${avgPing}ms)';
    }
    
    _showSnackBar(message, successCount > 0 ? Colors.green : Colors.red, duration: 2);
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
      
      _showSnackBar('Connected to fastest server: ${server.remark} ($lowestPing ms)', Colors.green);
      Navigator.pop(context, server);
    } else {
      _showSnackBar('No fast server found', Colors.red);
    }
  }

  List<V2RayConfig> _getFilteredServers(V2RayProvider provider) {
    var servers = provider.configs.toList();
    
    // Sort by ping if available
    if (_serverPings.isNotEmpty) {
      servers.sort((a, b) {
        final pingA = _serverPings[a.id] ?? 999999;
        final pingB = _serverPings[b.id] ?? 999999;
        return pingA.compareTo(pingB);
      });
    }
    
    return servers;
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

  // Test real delay using V2Ray Core (faster and more accurate!)
  Future<int> _testSingleServerPing(V2RayConfig server) async {
    try {
      final provider = Provider.of<V2RayProvider>(context, listen: false);
      
      // Use V2Ray Core's built-in ping (much faster and accurate)
      final delay = await provider.v2rayService.getServerDelay(server);
      
      if (delay != null && delay >= 0 && delay < 10000) {
        return delay;
      } else {
        return 9999;
      }
    } catch (e) {
      debugPrint('❌ Ping failed for ${server.remark}: $e');
      return 9999;
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
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
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
            onTap: () async {
              final provider = Provider.of<V2RayProvider>(context, listen: false);
              _showSnackBar('Refreshing servers...', Colors.blue);
              
              // Clear old ping results before refreshing
              if (mounted) {
                setState(() {
                  _serverPings.clear();
                });
              }
              
              // Update all subscriptions to get fresh server list
              await provider.updateAllSubscriptions();
              
              if (provider.errorMessage.isEmpty) {
                _showSnackBar('Servers updated successfully!', Colors.green);
                
                // Optionally auto-test pings after refresh
                // Uncomment the line below if you want automatic ping test after refresh
                // await _testAllServersPing();
              } else {
                _showSnackBar(provider.errorMessage, Colors.red);
                provider.clearError();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              child: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 22,
              ),
            ),
          ).animate().fadeIn().scale(delay: 200.ms),
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
            Colors.black.withOpacity(0.3),
            Colors.black.withOpacity(0.5),
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
              color: Colors.black.withOpacity(0.3),
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
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No servers found',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try refreshing or changing filters',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerList(List<V2RayConfig> servers, V2RayProvider provider) {
    return AnimatedBuilder(
      animation: _listAnimationController,
      builder: (context, child) {
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
                Navigator.pop(context, server);
                _showSnackBar('Server selected: ${server.remark}', Colors.blue);
              },
            );
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [
                    const Color(0xFF6366F1),
                    const Color(0xFF4F46E5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? const Color(0xFF6366F1).withOpacity(0.5)
                : Colors.white.withOpacity(0.12),
            width: 1.5,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Row(
          children: [
            // Server Icon با انیمیشن
            Hero(
              tag: 'server_${server.id}',
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withOpacity(0.25)
                      : const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.dns_rounded,
                  color: isActive
                      ? Colors.white
                      : const Color(0xFF6366F1),
                  size: 26,
                ),
              ),
            ),
            
            const SizedBox(width: 14),
            
            // Server Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.remark,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white.withOpacity(0.95),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Protocol Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isActive 
                              ? Colors.white.withOpacity(0.2)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          server.configType.toUpperCase(),
                          style: TextStyle(
                            color: isActive 
                                ? Colors.white
                                : Colors.white.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Ping Badge or Arrow or Active Badge
            if (_isTestingPings && ping == null)
              // در حال تست پینگ - نمایش loading
              Container(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF6366F1),
                    ),
                  ),
                ),
              )
            else if (ping != null)
              // پینگ موجود - نمایش با رنگ‌بندی
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _getPingColor(ping).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getPingColor(ping).withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.speed_rounded,
                      size: 14,
                      color: _getPingColor(ping),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pingText,
                      style: TextStyle(
                        color: _getPingColor(ping),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              )
            else if (isActive)
              // سرور فعال
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              )
            else
              // فلش پیش‌فرض
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.3),
                size: 24,
              ),
          ],
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: 50 * index))
        .slideX(begin: 0.2, end: 0);
  }

}
