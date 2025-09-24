import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../models/v2ray_config.dart';
import '../utils/app_localizations.dart';
import '../widgets/modern_animated_background.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:convert';

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
  Map<String, int> _serverPings = {};
  
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
    
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    final servers = _getFilteredServers(provider);
    
    // _showSnackBar('Testing ${servers.length} servers...', Colors.blue);
    
    int testedCount = 0;
    int successCount = 0;
    
    // Test servers in batches to avoid overwhelming the system
    const int batchSize = 5;
    for (int i = 0; i < servers.length; i += batchSize) {
      if (!mounted) break;
      
      final endIndex = (i + batchSize > servers.length) ? servers.length : i + batchSize;
      final batch = servers.sublist(i, endIndex);
      
      // Test current batch in parallel
      final List<Future<void>> batchFutures = [];
      
      for (var server in batch) {
        final future = _testSingleServerPing(server).then((ping) {
          if (mounted) {
            setState(() {
              _serverPings[server.remark] = ping;
              testedCount++;
              if (ping < 999) successCount++;
            });
            
            // Show progress
            // if (testedCount % 5 == 0) {
            //   _showSnackBar(
            //     'Tested $testedCount/${servers.length} servers ($successCount active)', 
            //     Colors.blue
            //   );
            // }
          }
        });
        
        batchFutures.add(future);
      }
      
      // Wait for current batch to complete
      await Future.wait(batchFutures, eagerError: false)
          .timeout(const Duration(seconds: 5), onTimeout: () => []);
      
      // Small delay between batches to prevent overwhelming
      if (i + batchSize < servers.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    _pingAnimationController.stop();
    setState(() {
      _isTestingPings = false;
    });
    
    // Show final results with more details
    final avgPing = successCount > 0
        ? _serverPings.values
            .where((p) => p < 999)
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
    
    // _showSnackBar(message, successCount > 0 ? Colors.green : Colors.red);
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
    String? fastestServer;
    int lowestPing = 999999;
    
    _serverPings.forEach((server, ping) {
      if (ping < lowestPing) {
        lowestPing = ping;
        fastestServer = server;
      }
    });
    
    if (fastestServer != null) {
      final provider = Provider.of<V2RayProvider>(context, listen: false);
      final server = provider.configs.firstWhere(
        (s) => s.remark == fastestServer,
      );
      
      await provider.selectConfig(server);
      await provider.connectToServer(server, false);
      
      _showSnackBar('Connected to fastest server: $fastestServer ($lowestPing ms)', Colors.green);
      Navigator.pop(context, server);
    }
  }

  List<V2RayConfig> _getFilteredServers(V2RayProvider provider) {
    // Remove duplicates based on server address and port
    final uniqueServers = <String, V2RayConfig>{};
    for (var server in provider.configs) {
      final key = '${server.address}:${server.port}';
      if (!uniqueServers.containsKey(key)) {
        uniqueServers[key] = server;
      }
    }
    
    var servers = uniqueServers.values.toList();
    
    // Sort by ping if available
    if (_serverPings.isNotEmpty) {
      servers.sort((a, b) {
        final pingA = _serverPings[a.remark] ?? 999999;
        final pingB = _serverPings[b.remark] ?? 999999;
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

  // Test real delay for a V2Ray server (inspired by v2rayNG implementation)
  Future<int> _testSingleServerPing(V2RayConfig server) async {
    try {
      // Method 1: Try using flutter_v2ray's built-in delay test
      try {
        final FlutterV2ray flutterV2ray = FlutterV2ray(
          onStatusChanged: (status) {},
        );
        
        // Test with Google's 204 endpoint (same as v2rayNG)
        final delay = await flutterV2ray.getServerDelay(
          config: server.fullConfig,
          url: 'https://www.google.com/generate_204',
        );
        
        if (delay > 0 && delay < 10000) {
          return delay;
        }
      } catch (e) {
        // If flutter_v2ray method fails, fall back to TCP test
      }
      
      // Method 2: TCP connection test (fallback)
      final host = server.address;
      final port = server.port;
      
      if (host.isEmpty || port <= 0) {
        return 9999;
      }
      
      final stopwatch = Stopwatch()..start();
      
      try {
        // Resolve host
        final addresses = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 2));
        
        if (addresses.isEmpty) {
          return 9999;
        }
        
        // TCP connection test
        final socket = await Socket.connect(
          addresses.first,
          port,
          timeout: const Duration(seconds: 3),
        );
        
        stopwatch.stop();
        final delay = stopwatch.elapsedMilliseconds;
        await socket.close();
        
        return delay.clamp(1, 9999);
      } catch (e) {
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
        
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: Scaffold(
            body: ModernAnimatedBackground(
              isConnected: isConnected,
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
              await provider.updateAllSubscriptions();
              _showSnackBar('Servers updated', Colors.green);
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
            final ping = _serverPings[server.remark];
            
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
                                (ping != null && ping < 100) ? Icons.speed : Icons.signal_cellular_alt,
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
