import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/v2ray_config.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../utils/app_localizations.dart';

class ServerListItem extends StatefulWidget {
  final V2RayConfig config;

  const ServerListItem({super.key, required this.config});

  @override
  State<ServerListItem> createState() => _ServerListItemState();
}

class _ServerListItemState extends State<ServerListItem> {
  @override
  void initState() {
    super.initState();
    // Ping functionality removed
  }

  @override
  void didUpdateWidget(ServerListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ping functionality removed
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<V2RayProvider, LanguageProvider>(
      builder: (context, provider, languageProvider, _) {
        final isActive = provider.activeConfig?.id == widget.config.id;
        final isSelected = provider.selectedConfig?.id == widget.config.id;

        return Directionality(
          textDirection: languageProvider.textDirection,
          child: _buildServerItem(context, provider, isActive, isSelected),
        );
      },
    );
  }

  Widget _buildServerItem(
    BuildContext context,
    V2RayProvider provider,
    bool isActive,
    bool isSelected,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: isSelected 
          ? const Color(0xFF00D9FF).withValues(alpha: 0.08) 
          : const Color(0xFF121212),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected 
              ? const Color(0xFF00D9FF).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await provider.selectConfig(widget.config);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Country Flag Icon
                  if (widget.config.countryCode != null) ...[
                    Container(
                      width: 48,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: CachedNetworkImage(
                          imageUrl: 'https://flagcdn.com/w80/${widget.config.countryCode!.toLowerCase()}.png',
                          fit: BoxFit.cover,
                          memCacheWidth: 80,
                          memCacheHeight: 60,
                          maxWidthDiskCache: 80,
                          maxHeightDiskCache: 60,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.public,
                            color: Colors.grey,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Server Name (remark)
                        Text(
                          widget.config.remark,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Country Name
                        if (widget.config.countryCode != null)
                          Text(
                            widget.config.countryName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Removed ping button as requested
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(
                                context.tr(
                                  TranslationKeys
                                      .serverListItemDeleteConfiguration,
                                ),
                              ),
                              content: Text(
                                context.tr(
                                  TranslationKeys
                                      .serverListItemDeleteConfirmation,
                                  parameters: {'server': widget.config.remark},
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    context.tr(TranslationKeys.commonCancel),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    provider.removeConfig(widget.config);
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    context.tr(
                                      TranslationKeys.serverListItemDelete,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        tooltip: context.tr(
                          TranslationKeys.serverListItemDeleteTooltip,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.config.address}:${widget.config.port}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getConfigTypeColor(widget.config.configType),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.config.configType.toString().toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getSubscriptionName(context),
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isSelected)
                    ElevatedButton(
                      onPressed: isActive
                          ? () async => await provider.disconnect()
                          : () async => await provider.connectToServer(
                              widget.config,
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        isActive
                            ? context.tr(
                                TranslationKeys.serverListItemDisconnect,
                              )
                            : context.tr(TranslationKeys.serverListItemConnect),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getConfigTypeColor(String configType) {
    switch (configType.toString().toLowerCase()) {
      case 'vmess':
        return Colors.blue;
      case 'vless':
        return Colors.green;
      case 'shadowsocks':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // Removed _getPingColor method

  String _getSubscriptionName(BuildContext context) {
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    final subscriptions = provider.subscriptions;

    // Find which subscription this config belongs to
    String subscriptionName = context.tr(
      TranslationKeys.serverListItemDefaultSubscription,
    );
    for (var subscription in subscriptions) {
      if (subscription.configIds.contains(widget.config.id)) {
        subscriptionName = subscription.name;
        break;
      }
    }

    return subscriptionName;
  }
}
