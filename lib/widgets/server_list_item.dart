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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isSelected ? 3 : 1,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: () async {
          await provider.selectConfig(widget.config);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Country Flag Icon + Server Name
                  Expanded(
                    child: Row(
                      children: [
                        // Flag or Smart Connect Icon
                        Container(
                          width: 40,
                          height: 30,
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
<<<<<<< HEAD
                          child: widget.config.isSmartConnect
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: Image.asset(
=======
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: widget.config.isSmartConnect
                                ? Image.asset(
>>>>>>> 0230e278905dde01d89da8d30ca9ae07e94600a9
                                    'assets/images/apk.png',
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Text(
                                      widget.config.countryFlag,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        height: 1.0,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
<<<<<<< HEAD
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: CachedNetworkImage(
                                    imageUrl: widget.config.countryFlagUrl,
                                    width: 40,
                                    height: 30,
                                    fit: BoxFit.fill,
                                    placeholder: (context, url) => Center(
                                      child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.grey.withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Center(
                                      child: Text(
                                        widget.config.countryFlag,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ),
                                ),
=======
                          ),
>>>>>>> 0230e278905dde01d89da8d30ca9ae07e94600a9
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.config.getDisplayName(
                              (key) => AppLocalizations.of(context).translate(key),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 6),
              Text(
                '${widget.config.address}:${widget.config.port}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Protocol Type Badge
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

}
