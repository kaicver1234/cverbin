import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/v2ray_config.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../utils/app_localizations.dart';
import '../theme/app_theme.dart';
import '../screens/server_selection_screen.dart';
import 'error_snackbar.dart';

class ServerSelector extends StatelessWidget {
  const ServerSelector({Key? key}) : super(key: key);

  // Proxy mode switch removed as requested

  @override
  Widget build(BuildContext context) {
    return Consumer2<V2RayProvider, LanguageProvider>(
      builder: (context, provider, languageProvider, _) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: _buildServerSelector(context, provider),
        );
      },
    );
  }

  Widget _buildServerSelector(BuildContext context, V2RayProvider provider) {
    final selectedConfig = provider.selectedConfig;
    final configs = provider.configs;
    final isConnecting = provider.isConnecting;
    final isLoadingServers = provider.isLoadingServers;

    if (isLoadingServers) {
      return _LoadingServerCard();
    }

    if (configs.isEmpty) {
      return _EmptyServerCard();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr(TranslationKeys.homeSelectServer),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: isConnecting
                  ? null
                  : () {
                      // Check if already connected to VPN
                      if (provider.activeConfig != null) {
                        // Show popup to inform user to disconnect first
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              context.tr(
                                TranslationKeys.serverSelectorConnectionActive,
                              ),
                            ),
                            content: Text(
                              context.tr(
                                TranslationKeys.serverSelectorDisconnectFirst,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  context.tr(TranslationKeys.commonOk),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        // Not connected, show server selector as full page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ServerSelectionScreen(),
                          ),
                        );
                      }
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardDark),
                ),
                child: Row(
                  children: [
                    if (selectedConfig != null) ...[
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getServerStatusColor(
                            selectedConfig,
                            provider,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedConfig.remark,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      // Removed server delay icon as requested
                    ] else ...[
                      Expanded(
                        child: Text(
                          context.tr(
                            TranslationKeys.serverSelectorSelectServer,
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                    const Icon(
                      Icons.arrow_drop_down,
                      color: AppTheme.primaryGreen,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Proxy Mode Switch removed as requested
            // Server and config type information removed as requested
          ],
        ),
      ),
    );
  }

  Color _getServerStatusColor(V2RayConfig config, V2RayProvider provider) {
    // Check if this is the active config (connected)
    final activeConfig = provider.activeConfig;
    if (activeConfig != null && activeConfig.id == config.id) {
      return AppTheme.primaryGreen;
    }
    // Check if this is the selected config (but not connected)
    final selectedConfig = provider.selectedConfig;
    if (selectedConfig != null && selectedConfig.id == config.id) {
      return Colors.orange;
    }
    return AppTheme.textGrey;
  }
}

class _LoadingServerCard extends StatelessWidget {
  const _LoadingServerCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryGreen),
              const SizedBox(height: 16),
              Text(context.tr(TranslationKeys.serverSelectorLoadingServers)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyServerCard extends StatelessWidget {
  const _EmptyServerCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppTheme.textGrey),
              const SizedBox(height: 16),
              Text(context.tr(TranslationKeys.serverSelectorNoServers)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final provider = Provider.of<V2RayProvider>(
                    context,
                    listen: false,
                  );
                  try {
                    // Since we no longer have default servers, we'll show a message
                    ErrorSnackbar.show(
                      context,
                      context.tr(TranslationKeys.serverSelectorAddSubscription),
                    );

                    // Check if there was an error
                    if (provider.errorMessage.isNotEmpty) {
                      ErrorSnackbar.show(context, provider.errorMessage);
                      provider.clearError();
                    }
                  } catch (e) {
                    ErrorSnackbar.show(
                      context,
                      '${context.tr(TranslationKeys.serverSelectorErrorRefreshing)}: ${e.toString()}',
                    );
                  }
                },
                child: Text(context.tr(TranslationKeys.commonRefresh)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
