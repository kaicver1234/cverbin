import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_background.dart';
import '../services/analytics_service.dart';

class IpInfoScreen extends StatefulWidget {
  const IpInfoScreen({super.key});

  @override
  State<IpInfoScreen> createState() => _IpInfoScreenState();
}

class _IpInfoScreenState extends State<IpInfoScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _ipData;
  String? _errorMessage;
  bool _copied = false;

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    AnalyticsService().logScreenView(screenName: 'Safheh_Ettelaat_IP');
    _fetchIpInfo();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchIpInfo() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _fadeController.reset();

    try {
      final response = await http.get(
        Uri.parse(
            'http://ip-api.com/json/?fields=status,message,continent,country,countryCode,region,regionName,city,lat,lon,timezone,isp,org,as,query'),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('timeout');
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          if (!mounted) return;
          setState(() {
            _ipData = data;
            _isLoading = false;
          });
          _fadeController.forward();
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
          _errorMessage = 'Server error (${response.statusCode})';
          _isLoading = false;
        });
      }
    } on http.ClientException catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No internet connection';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().contains('timeout')
            ? 'Connection timeout'
            : 'Unable to fetch IP information';
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colors = themeProvider.colors;

    return Directionality(
      textDirection: languageProvider.textDirection,
      child: AppBackground(
        useSecondaryBackground: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, colors),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState(colors)
                      : _errorMessage != null
                          ? _buildErrorState(colors)
                          : _buildContent(colors),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Consumer<LanguageProvider>(
                builder: (context, langProvider, _) => Icon(
                  langProvider.isRtl
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'IP Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Your network identity',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _isLoading ? null : () {
              AnalyticsService().logIpInfoRefresh();
              _fetchIpInfo();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00D9FF).withValues(alpha: _isLoading ? 0.3 : 1),
                    const Color(0xFF00FFA3).withValues(alpha: _isLoading ? 0.3 : 1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
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
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) => Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D9FF), Color(0xFF00FFA3)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D9FF).withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.language_rounded, color: Colors.white, size: 36),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Detecting your IP...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    width: 2),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: Color(0xFFEF4444), size: 36),
            ),
            const SizedBox(height: 24),
            const Text(
              'Connection Failed',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unable to fetch IP information',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _fetchIpInfo,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF00D9FF), Color(0xFF00FFA3)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Try Again',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(colors) {
    if (_ipData == null) return const SizedBox();
    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          children: [
            _buildHeroCard(),
            const SizedBox(height: 16),
            _buildStatsRow(),
            const SizedBox(height: 16),
            _buildSection(
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFF00D9FF),
              title: 'Location',
              items: [
                _Item(Icons.flag_rounded, 'Country',
                    '${_ipData!['country']} (${_ipData!['countryCode']})'),
                _Item(Icons.map_rounded, 'Region',
                    _ipData!['regionName'] ?? 'Unknown'),
                _Item(Icons.location_city_rounded, 'City',
                    _ipData!['city'] ?? 'Unknown'),
                _Item(Icons.access_time_rounded, 'Timezone',
                    _ipData!['timezone'] ?? 'Unknown'),
                _Item(Icons.my_location_rounded, 'Coordinates',
                    '${(_ipData!['lat'] as num).toStringAsFixed(4)}, ${(_ipData!['lon'] as num).toStringAsFixed(4)}'),
              ],
            ),
            const SizedBox(height: 14),
            _buildSection(
              icon: Icons.router_rounded,
              iconColor: const Color(0xFF00FFA3),
              title: 'Network',
              items: [
                _Item(Icons.business_rounded, 'ISP',
                    _ipData!['isp'] ?? 'Unknown'),
                _Item(Icons.corporate_fare_rounded, 'Organization',
                    _ipData!['org'] ?? 'Unknown'),
                _Item(Icons.numbers_rounded, 'AS Number',
                    _ipData!['as'] ?? 'Unknown'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    final ip = _ipData!['query'] ?? 'Unknown';
    final city = _ipData!['city'] ?? '';
    final country = _ipData!['country'] ?? '';
    final countryCode = (_ipData!['countryCode'] ?? '').toString().toUpperCase();

    String flagEmoji = '';
    if (countryCode.length == 2) {
      flagEmoji = countryCode.split('').map((c) {
        return String.fromCharCode(c.codeUnitAt(0) + 127397);
      }).join();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00D9FF).withValues(alpha: 0.15),
            const Color(0xFF00FFA3).withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF00D9FF).withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D9FF).withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF00D9FF).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00FFA3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Color(0xFF00D9FF),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              if (flagEmoji.isNotEmpty)
                Text(flagEmoji, style: const TextStyle(fontSize: 32)),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Your IP Address',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF00D9FF), Color(0xFF00FFA3)],
                  ).createShader(bounds),
                  child: Text(
                    ip,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _copyToClipboard(ip),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _copied
                        ? const Color(0xFF00FFA3).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _copied
                          ? const Color(0xFF00FFA3).withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 16,
                    color:
                        _copied ? const Color(0xFF00FFA3) : Colors.white54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_rounded,
                    size: 13, color: Colors.white.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    [city, country]
                        .where((s) => s.isNotEmpty)
                        .join(', '),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13),
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

  Widget _buildStatsRow() {
    final lat = (_ipData!['lat'] as num?)?.toStringAsFixed(2) ?? '-';
    final lon = (_ipData!['lon'] as num?)?.toStringAsFixed(2) ?? '-';
    final tz = (_ipData!['timezone'] ?? '-').toString().split('/').last;

    return Row(
      children: [
        _buildStatCard(Icons.north_east_rounded, 'Latitude', lat, const Color(0xFF00D9FF)),
        const SizedBox(width: 10),
        _buildStatCard(Icons.north_rounded, 'Longitude', lon, const Color(0xFF00FFA3)),
        const SizedBox(width: 10),
        _buildStatCard(Icons.schedule_rounded, 'Timezone', tz, const Color(0xFFFBBF24)),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<_Item> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.05),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.white.withValues(alpha: 0.04),
            ),
            itemBuilder: (_, i) => _buildItem(items[i], iconColor),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(_Item item, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(item.icon, color: accent.withValues(alpha: 0.7), size: 15),
          const SizedBox(width: 10),
          Text(
            item.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              item.value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Item {
  final IconData icon;
  final String label;
  final String value;
  _Item(this.icon, this.label, this.value);
}
