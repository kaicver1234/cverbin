import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/language_provider.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Directionality(
      textDirection: languageProvider.textDirection,
      child: AppBackground(
        useSecondaryBackground: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, isSmallScreen),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _errorMessage != null
                          ? _buildErrorState()
                          : _buildContent(isSmallScreen),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isSmallScreen) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IP Information',
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
                  'Your network details',
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
          GestureDetector(
            onTap: _isLoading ? null : _fetchIpInfo,
            child: Container(
              width: isSmallScreen ? 40 : 44,
              height: isSmallScreen ? 40 : 44,
              decoration: BoxDecoration(
                gradient: _isLoading
                    ? LinearGradient(
                        colors: [Colors.grey.shade700, Colors.grey.shade800],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF00D9FF), Color(0xFF00FFA3)],
                      ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isLoading ? [] : [
                  BoxShadow(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: const Color(0xFF00D9FF),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading...',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    IconData errorIcon = Icons.wifi_off_rounded;
    const Color iconColor = Color(0xFFFF6B6B);
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
                gradient: LinearGradient(
                  colors: [
                    iconColor.withValues(alpha: 0.2),
                    iconColor.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.3),
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
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to fetch IP information',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D9FF), Color(0xFF00FFA3)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D9FF).withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
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
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isSmallScreen) {
    if (_ipData == null) return const SizedBox();
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      child: Column(
        children: [
          _buildIpCard(isSmallScreen),
          SizedBox(height: isSmallScreen ? 14 : 16),
          _buildInfoSection(
            isSmallScreen,
            'Location',
            Icons.location_on_rounded,
            const Color(0xFF00D9FF),
            [
              _InfoRow('Country', '${_ipData!['country']} (${_ipData!['countryCode']})'),
              _InfoRow('Region', _ipData!['regionName'] ?? 'Unknown'),
              _InfoRow('City', _ipData!['city'] ?? 'Unknown'),
              _InfoRow('Timezone', _ipData!['timezone'] ?? 'Unknown'),
              _InfoRow('Coordinates', '${_ipData!['lat']?.toStringAsFixed(4)}, ${_ipData!['lon']?.toStringAsFixed(4)}'),
            ],
          ),
          SizedBox(height: isSmallScreen ? 14 : 16),
          _buildInfoSection(
            isSmallScreen,
            'Network',
            Icons.router_rounded,
            const Color(0xFF00FFA3),
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

  Widget _buildIpCard(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 24 : 28),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1929).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: isSmallScreen ? 70 : 80,
            height: isSmallScreen ? 70 : 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00D9FF), Color(0xFF00FFA3)],
              ).scale(0.3),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.language_rounded,
              size: isSmallScreen ? 34 : 40,
              color: const Color(0xFF00D9FF),
            ),
          ),
          SizedBox(height: isSmallScreen ? 20 : 24),
          Text(
            'Your IP Address',
            style: TextStyle(
              color: const Color(0xFF00D9FF).withValues(alpha: 0.6),
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _ipData!['query'] ?? 'Unknown',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 26 : 30,
                    fontWeight: FontWeight.w700,
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00D9FF).withValues(alpha: 0.2),
                        const Color(0xFF00FFA3).withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: Color(0xFF00D9FF),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 16 : 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${_ipData!['city']}, ${_ipData!['country']}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: isSmallScreen ? 13 : 14,
                      fontWeight: FontWeight.w600,
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

  Widget _buildInfoSection(bool isSmallScreen, String title, IconData icon, Color accentColor, List<_InfoRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1929).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.15),
                  accentColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.3),
                        accentColor.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: isSmallScreen ? 20 : 22,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 14),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 16 : 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
            child: Column(
              children: rows.asMap().entries.map((entry) {
                final isLast = entry.key == rows.length - 1;
                return _buildInfoRow(isSmallScreen, entry.value, isLast);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(bool isSmallScreen, _InfoRow row, bool isLast) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : (isSmallScreen ? 10 : 12)),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              row.label,
              style: TextStyle(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.6),
                fontSize: isSmallScreen ? 13 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              row.value,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 13 : 14,
                fontWeight: FontWeight.w600,
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
        backgroundColor: const Color(0xFF10b981),
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
