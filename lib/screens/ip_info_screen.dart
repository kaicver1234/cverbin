import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/cyber_glow_background.dart';
import '../widgets/app_background.dart';

class IpInfoScreen extends StatefulWidget {
  const IpInfoScreen({super.key});

  @override
  State<IpInfoScreen> createState() => _IpInfoScreenState();
}

class _IpInfoScreenState extends State<IpInfoScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _ipData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchIpInfo();
  }

  Future<void> _fetchIpInfo() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://ip-api.com/json/?fields=status,message,continent,country,countryCode,region,regionName,city,lat,lon,timezone,isp,org,as,query'),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet connection.');
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          if (!mounted) return;
          setState(() {
            _ipData = data;
            _isLoading = false;
          });
        } else {
          if (!mounted) return;
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to fetch IP information';
            _isLoading = false;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Server error (${response.statusCode}). Please try again later.';
          _isLoading = false;
        });
      }
    } on http.ClientException catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No internet connection. Please check your network settings.';
        _isLoading = false;
      });
    } on FormatException catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Invalid response from server. Please try again.';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.toString().contains('timeout')) {
          _errorMessage = 'Connection timeout. Please check your internet connection.';
        } else if (e.toString().contains('SocketException')) {
          _errorMessage = 'No internet connection. Please check your network settings.';
        } else {
          _errorMessage = 'Unable to fetch IP information. Please try again.';
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colors = themeProvider.colors;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Directionality(
      textDirection: languageProvider.textDirection,
      child: AppBackground(
        useSecondaryBackground: true,
        child: CyberGlowBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, colors, isSmallScreen),
                  Expanded(
                    child: _isLoading
                        ? _buildLoadingState(colors)
                        : _errorMessage != null
                            ? _buildErrorState(colors)
                            : _buildContent(colors, isSmallScreen),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, colors, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 12 : 16,
        8,
        isSmallScreen ? 12 : 16,
        isSmallScreen ? 12 : 16,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(colors.borderColor).withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: isSmallScreen ? 40 : 44,
              height: isSmallScreen ? 40 : 44,
              decoration: BoxDecoration(
                color: Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Consumer<LanguageProvider>(
                builder: (context, langProvider, _) => Icon(
                  langProvider.isRtl ? Icons.arrow_forward_ios : Icons.arrow_back_ios_new,
                  color: Color(colors.textPrimaryColor),
                  size: isSmallScreen ? 16 : 18,
                ),
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IP Information',
                  style: TextStyle(
                    color: Color(colors.textPrimaryColor),
                    fontSize: isSmallScreen ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Your network details',
                  style: TextStyle(
                    color: Color(colors.textSecondaryColor).withValues(alpha: 0.5),
                    fontSize: isSmallScreen ? 11 : 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _isLoading ? null : _fetchIpInfo,
            child: Container(
              width: isSmallScreen ? 40 : 44,
              height: isSmallScreen ? 40 : 44,
              decoration: BoxDecoration(
                color: Color(colors.primaryColor).withValues(alpha: _isLoading ? 0.3 : 1.0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: isSmallScreen ? 20 : 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: Color(colors.primaryColor),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading...',
            style: TextStyle(
              color: Color(colors.textPrimaryColor),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(colors) {
    // Determine error icon and color based on error type
    IconData errorIcon = Icons.wifi_off_rounded;
    Color iconColor = Color(colors.errorColor);
    String errorTitle = 'Connection Failed';
    
    if (_errorMessage?.contains('internet') == true || _errorMessage?.contains('network') == true) {
      errorIcon = Icons.wifi_off_rounded;
      errorTitle = 'No Internet Connection';
    } else if (_errorMessage?.contains('timeout') == true) {
      errorIcon = Icons.access_time_rounded;
      errorTitle = 'Connection Timeout';
    } else if (_errorMessage?.contains('Server') == true) {
      errorIcon = Icons.cloud_off_rounded;
      errorTitle = 'Server Error';
    }
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                errorIcon,
                size: 56,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              errorTitle,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(colors.textPrimaryColor),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to fetch IP information',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(colors.textSecondaryColor).withValues(alpha: 0.7),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: _fetchIpInfo,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(colors.primaryColor),
                      Color(colors.secondaryColor),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Color(colors.primaryColor).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Try Again',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Tips section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color(colors.borderColor).withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 18,
                        color: Color(colors.warningColor),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Troubleshooting Tips',
                        style: TextStyle(
                          color: Color(colors.textPrimaryColor),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTip(colors, '• Check your internet connection'),
                  _buildTip(colors, '• Try disabling VPN temporarily'),
                  _buildTip(colors, '• Restart your device'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTip(colors, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: Color(colors.textSecondaryColor).withValues(alpha: 0.6),
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildContent(colors, bool isSmallScreen) {
    if (_ipData == null) return const SizedBox();
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: Column(
        children: [
          _buildIpCard(colors, isSmallScreen),
          SizedBox(height: isSmallScreen ? 12 : 16),
          _buildInfoSection(
            colors,
            isSmallScreen,
            'Location',
            Icons.location_on_rounded,
            [
              _InfoRow('Country', '${_ipData!['country']} (${_ipData!['countryCode']})'),
              _InfoRow('Region', _ipData!['regionName'] ?? 'Unknown'),
              _InfoRow('City', _ipData!['city'] ?? 'Unknown'),
              _InfoRow('Timezone', _ipData!['timezone'] ?? 'Unknown'),
              _InfoRow('Coordinates', '${_ipData!['lat']?.toStringAsFixed(4)}, ${_ipData!['lon']?.toStringAsFixed(4)}'),
            ],
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          _buildInfoSection(
            colors,
            isSmallScreen,
            'Network',
            Icons.router_rounded,
            [
              _InfoRow('ISP', _ipData!['isp'] ?? 'Unknown'),
              _InfoRow('Organization', _ipData!['org'] ?? 'Unknown'),
              _InfoRow('AS Number', _ipData!['as'] ?? 'Unknown'),
            ],
          ),
          SizedBox(height: isSmallScreen ? 16 : 20),
        ],
      ),
    );
  }

  Widget _buildIpCard(colors, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      decoration: BoxDecoration(
        color: Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(colors.primaryColor).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: isSmallScreen ? 60 : 70,
            height: isSmallScreen ? 60 : 70,
            decoration: BoxDecoration(
              color: Color(colors.primaryColor).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.language_rounded,
              size: isSmallScreen ? 30 : 36,
              color: Color(colors.primaryColor),
            ),
          ),
          SizedBox(height: isSmallScreen ? 16 : 20),
          Text(
            'Your IP Address',
            style: TextStyle(
              color: Color(colors.textSecondaryColor).withValues(alpha: 0.6),
              fontSize: isSmallScreen ? 12 : 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _ipData!['query'] ?? 'Unknown',
                  style: TextStyle(
                    color: Color(colors.textPrimaryColor),
                    fontSize: isSmallScreen ? 24 : 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _copyToClipboard(_ipData!['query'] ?? ''),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(colors.primaryColor).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: Color(colors.primaryColor),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: Color(colors.textSecondaryColor).withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${_ipData!['city']}, ${_ipData!['country']}',
                    style: TextStyle(
                      color: Color(colors.textSecondaryColor).withValues(alpha: 0.7),
                      fontSize: isSmallScreen ? 12 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(colors, bool isSmallScreen, String title, IconData icon, List<_InfoRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Color(colors.borderColor).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
            decoration: BoxDecoration(
              color: Color(colors.primaryColor).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(colors.primaryColor).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Color(colors.primaryColor),
                    size: isSmallScreen ? 18 : 20,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 10 : 12),
                Text(
                  title,
                  style: TextStyle(
                    color: Color(colors.textPrimaryColor),
                    fontSize: isSmallScreen ? 15 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              children: rows.asMap().entries.map((entry) {
                final isLast = entry.key == rows.length - 1;
                return _buildInfoRow(colors, isSmallScreen, entry.value, isLast);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(colors, bool isSmallScreen, _InfoRow row, bool isLast) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : (isSmallScreen ? 10 : 12)),
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity * 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              row.label,
              style: TextStyle(
                color: Color(colors.textSecondaryColor).withValues(alpha: 0.6),
                fontSize: isSmallScreen ? 12 : 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              row.value,
              style: TextStyle(
                color: Color(colors.textPrimaryColor),
                fontSize: isSmallScreen ? 12 : 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
  
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('Copied: $text'),
          ],
        ),
        backgroundColor: const Color(0xFF00FFA3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;

  _InfoRow(this.label, this.value);
}
