import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/v2ray_provider.dart';
import '../models/v2ray_config.dart';
import '../utils/app_localizations.dart';

class ServerSelectionScreen extends StatefulWidget {
  const ServerSelectionScreen({super.key});

  @override
  State<ServerSelectionScreen> createState() => _ServerSelectionScreenState();
}

class _ServerSelectionScreenState extends State<ServerSelectionScreen> {
  bool _isTesting = false;
  Map<String, int> _pingResults = {};
  List<V2RayConfig>? _sortedConfigs; // For sorted server list

  @override
  void dispose() {
    // Clean up to prevent memory leaks
    _sortedConfigs = null;
    _pingResults.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E293B),
              Color(0xFF0F172A),
              Color(0xFF020617),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: Consumer<V2RayProvider>(
                  builder: (context, provider, child) {
                    // Use sorted configs if available, otherwise use original
                    final configs = _sortedConfigs ?? provider.configs;
                    
                    if (configs.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    return _buildServerList(context, provider, configs);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).translate('server_selection.title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  AppLocalizations.of(context).translate('server_selection.select_server'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Ping test button
          _buildPingTestButton(context),
        ],
      ),
    );
  }

  Widget _buildPingTestButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: _isTesting
            ? LinearGradient(
                colors: [
                  Colors.grey.shade600,
                  Colors.grey.shade700,
                ],
              )
            : const LinearGradient(
                colors: [
                  Color(0xFF10B981),
                  Color(0xFF059669),
                ],
              ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isTesting ? null : _testAllServerPings,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isTesting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(
                    Icons.speed,
                    color: Colors.white,
                    size: 18,
                  ),
                const SizedBox(width: 8),
                Text(
                  _isTesting
                      ? AppLocalizations.of(context).translate('server_selection.testing_servers')
                      : AppLocalizations.of(context).translate('server_selection.test_ping'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServerList(BuildContext context, V2RayProvider provider, List<V2RayConfig> configs) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      physics: const ClampingScrollPhysics(), // No bounce animation
      itemCount: configs.length,
      itemBuilder: (context, index) {
        final config = configs[index];
        
        // Smart Connect card for smart_connect config
        if (config.isSmartConnect) {
          return _buildSmartConnectCard(context, provider, config);
        }

        // Regular server card
        final isSelected = !provider.wasUsingSmartConnect && 
                          provider.selectedConfig?.id == config.id;
        
        return _buildServerCard(context, provider, config, isSelected);
      },
    );
  }

  Widget _buildSmartConnectCard(BuildContext context, V2RayProvider provider, V2RayConfig config) {
    final isSelected = provider.wasUsingSmartConnect;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSelected
              ? [
                  const Color(0xFF10B981).withValues(alpha: 0.2),
                  const Color(0xFF059669).withValues(alpha: 0.15),
                ]
              : [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.04),
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            provider.selectConfig(config);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // App Logo - smaller
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/apk.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context).translate('server_selection.smart_connect'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context).translate('server_selection.smart_connect_description'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Selection indicator
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 14,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServerCard(BuildContext context, V2RayProvider provider, V2RayConfig config, bool isSelected) {
    final countryCode = _extractCountryCode(config.remark);
    final ping = _pingResults[config.id];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            provider.selectConfig(config);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Country flag - smaller
                _buildCountryFlag(countryCode),
                const SizedBox(width: 10),
                
                // Server info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _cleanServerName(config.remark),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${config.address}:${config.port}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Ping indicator
                if (ping != null) _buildPingIndicator(ping),
                const SizedBox(width: 8),
                
                // Selection indicator
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withValues(alpha: 0.25),
                    size: 12,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountryFlag(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) {
      return Container(
        width: 36,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.public,
          color: Colors.white,
          size: 16,
        ),
      );
    }

    return Container(
      width: 36,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: 'https://flagcdn.com/w80/${countryCode.toLowerCase()}.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          placeholder: (context, url) => const Center(
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1,
                color: Colors.white,
              ),
            ),
          ),
          errorWidget: (context, url, error) => const Icon(
            Icons.public,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildPingIndicator(int ping) {
    Color pingColor;
    String pingText;
    
    if (ping > 9999) {
      pingColor = Colors.red;
      pingText = '---';
    } else if (ping < 1000) {
      pingColor = const Color(0xFF10B981);
      pingText = '${ping}ms';
    } else if (ping < 2000) {
      pingColor = Colors.orange;
      pingText = '${ping}ms';
    } else {
      pingColor = Colors.red;
      pingText = '${ping}ms';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: pingColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        pingText,
        style: TextStyle(
          color: pingColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.dns_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context).translate('server_selection.no_servers_available'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String? _extractCountryCode(String remark) {
    // Extract country code from format: [DE] server name
    final regex = RegExp(r'\[([A-Z]{2})\]');
    final match = regex.firstMatch(remark);
    return match?.group(1);
  }

  String _cleanServerName(String remark) {
    // Remove country code prefix: [DE] server name -> server name
    return remark.replaceAll(RegExp(r'^\[([A-Z]{2})\]\s*'), '').trim();
  }

  Future<void> _testAllServerPings() async {
    if (_isTesting || !mounted) return;

    setState(() {
      _isTesting = true;
      _pingResults.clear();
    });

    V2RayProvider? provider;
    try {
      provider = Provider.of<V2RayProvider>(context, listen: false);
    } catch (e) {
      debugPrint('❌ Could not get provider: $e');
      if (mounted) {
        setState(() => _isTesting = false);
      }
      return;
    }
    
    final configs = provider.serverConfigs; // Exclude Smart Connect

    if (configs.isEmpty) {
      if (mounted) {
        setState(() => _isTesting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).translate('server_selection.no_servers_available'),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    // Test servers one by one (sequential)
    final Map<String, int> results = {};
    int successCount = 0;
    int failCount = 0;
    
    try {
      for (int i = 0; i < configs.length; i++) {
        // Check mounted before each iteration
        if (!mounted) {
          debugPrint('⚠️ Widget disposed during ping test, stopping...');
          return;
        }
        
        final config = configs[i];
        
        try {
          debugPrint('🔍 Testing server ${i + 1}/${configs.length}: ${config.remark}');
          
          // Test this server
          final ping = await provider.v2rayService.getServerDelay(config);
          
          // Check mounted again after async operation
          if (!mounted) {
            debugPrint('⚠️ Widget disposed after ping test, stopping...');
            return;
          }
          
          // Store result (use 99999 for null/timeout)
          final pingValue = ping ?? 99999;
          results[config.id] = pingValue;
          
          if (pingValue < 99999) {
            successCount++;
          } else {
            failCount++;
          }
          
          // Update UI immediately with this result
          setState(() {
            _pingResults = Map.from(results);
          });
          
          debugPrint('✅ Server ${config.remark}: ${ping ?? "timeout"}ms');
        } catch (e) {
          debugPrint('❌ Error testing ${config.remark}: $e');
          // Continue to next server even if this one failed
          results[config.id] = 99999; // Mark as timeout
          failCount++;
          
          if (mounted) {
            setState(() {
              _pingResults = Map.from(results);
            });
          }
        }
      }

      if (!mounted) return;
      
      // Sort servers by ping (fastest first), but keep Smart Connect at top
      _sortServersByPing(provider, results);
      
      setState(() {
        _pingResults = results;
      });

      // Show appropriate message based on results
      final String message;
      final Color bgColor;
      
      if (successCount == 0) {
        message = AppLocalizations.of(context).translate('server_selection.all_servers_timeout');
        bgColor = Colors.orange;
      } else if (failCount > 0) {
        message = '${AppLocalizations.of(context).translate('server_selection.servers_updated')} ($successCount/${configs.length})';
        bgColor = const Color(0xFF10B981);
      } else {
        message = AppLocalizations.of(context).translate('server_selection.servers_updated');
        bgColor = const Color(0xFF10B981);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error testing server pings: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).translate('server_selection.error_updating'),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  void _sortServersByPing(V2RayProvider provider, Map<String, int> pingResults) {
    // Get Smart Connect (always first)
    final smartConnect = V2RayConfig.smartConnect();
    
    // Get all server configs (without Smart Connect)
    final serverConfigs = List<V2RayConfig>.from(provider.serverConfigs);
    
    // Sort servers by ping (lowest/fastest first)
    serverConfigs.sort((a, b) {
      final pingA = pingResults[a.id] ?? 99999;
      final pingB = pingResults[b.id] ?? 99999;
      return pingA.compareTo(pingB);
    });
    
    // Combine: Smart Connect first, then sorted servers
    final sortedList = [smartConnect, ...serverConfigs];
    
    setState(() {
      _sortedConfigs = sortedList;
    });
    
    debugPrint('🔄 Sorted ${serverConfigs.length} servers by ping speed');
    debugPrint('📊 Top 3 fastest servers:');
    for (int i = 0; i < (serverConfigs.length > 3 ? 3 : serverConfigs.length); i++) {
      final config = serverConfigs[i];
      final ping = pingResults[config.id] ?? 99999;
      debugPrint('   ${i + 1}. ${config.remark}: ${ping}ms');
    }
  }
}
