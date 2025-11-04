import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../models/v2ray_config.dart';
import '../widgets/vpn_gradient_background.dart';
import '../services/ping_service.dart';

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
      setState(() {});
    }
  }

  Future<void> _testAllServersPing() async {
    if (_isTestingPings) return;
    
    setState(() {
      _isTestingPings = true;
      _serverPings.clear();
    });
    
    _pingAnimationController.repeat();
    
    // Clear native ping cache to ensure fresh results
    NativePingService.clearCache();
    
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    final servers = _getFilteredServers(provider);
    
    _showSnackBar('Testing ${servers.length} servers...', Colors.blue);
    
    int successCount = 0;
    
    // Test servers sequentially with a small delay to get unique results
    // This prevents caching issues and ensures each server gets its own ping
    for (var server in servers) {
      if (!mounted) break;
      
      try {
        final ping = await _testSingleServerPing(server);
        
        if (mounted) {
          setState(() {
            // Use server ID as key to ensure uniqueness
            _serverPings[server.id] = ping;
            if (ping < 9999) successCount++;
          });
        }
        
        // Small delay between tests to ensure fresh results
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        // Error testing server, mark as timeout
        if (mounted) {
          setState(() {
            _serverPings[server.id] = 9999;
          });
        }
      }
    }
    
    _pingAnimationController.stop();
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
    
    _showSnackBar(message, successCount > 0 ? Colors.green : Colors.red);
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
      await provider.connectToServer(server, false);
      
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

  // Test real delay for a V2Ray server using Native Ping Service
  Future<int> _testSingleServerPing(V2RayConfig server) async {
    try {
      final host = server.address;
      final port = server.port;
      
      if (host.isEmpty || port <= 0) {
        return 9999;
      }
      
      // Use NativePingService for accurate ping measurement
      // Disable cache to get fresh results for each server
      final pingResult = await NativePingService.pingHost(
        host: host,
        port: port,
        timeoutMs: 8000,
        useIcmp: true,
        useTcp: true,
        useCache: false, // IMPORTANT: Disable cache for unique results
      );
      
      if (pingResult.success && pingResult.latency > 0) {
        return pingResult.latency;
      } else {
        return 9999;
      }
    } catch (e) {
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
            child: SafeArea(
              child: Column(
                children: [
                  // Modern App Bar
                  _buildAppBar(context),
                  
                  // Quick Actions
                  _buildQuickActions(),
                  
                  // Server List
                  Expanded(
                    child: servers.isEmpty
                        ? _buildEmptyState()
                        : _buildServerList(servers, v2rayProvider),
                  ),
                ],
              ),
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
          ).animate().fadeIn().slideX(),
          
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
            ).animate().fadeIn().slideX(),
          ),
          
          // Refresh Button
          GestureDetector(
            onTap: () async {
              final provider = Provider.of<V2RayProvider>(context, listen: false);
              _showSnackBar('Refreshing servers...', Colors.blue);
              
              // Clear old ping results before refreshing
              setState(() {
                _serverPings.clear();
              });
              
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

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              label: 'Test All Pings',
              icon: Icons.speed,
              color: const Color(0xFF10B981),
              isLoading: _isTestingPings,
              onTap: _testAllServersPing,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              label: 'Connect to Fastest',
              icon: Icons.flash_on,
              color: const Color(0xFF6366F1),
              onTap: _connectToFastestServer,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              color.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
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
    ).animate().fadeIn().scale();
  }

  Widget _buildServerList(List<V2RayConfig> servers, V2RayProvider provider) {
    return AnimatedBuilder(
      animation: _listAnimationController,
      builder: (context, child) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          physics: const BouncingScrollPhysics(),
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
    // Use a single neutral color for all pings
    Color pingColor = Colors.white.withOpacity(0.7);
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
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [
                    const Color(0xFF6366F1),
                    const Color(0xFF4F46E5),
                  ],
                )
              : null,
          color: isActive ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? const Color(0xFF6366F1)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            // Server Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.dns,
                color: isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.6),
                size: 24,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Server Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.remark,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Protocol Type
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          server.configType.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Server Address
                      Expanded(
                        child: Text(
                          '${server.address}:${server.port}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (ping != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: pingColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: pingColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                (ping < 100) ? Icons.speed : Icons.signal_cellular_alt,
                                size: 12,
                                color: pingColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                pingText.isNotEmpty ? pingText : 'Testing...',
                                style: TextStyle(
                                  color: pingColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Action Button
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: 50 * index))
        .slideX(begin: 0.2, end: 0);
  }

}
