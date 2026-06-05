import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
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

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    
    AnalyticsService().logScreenView(screenName: 'Safheh_Ettelaat_IP');
    _fetchIpInfo();
  }

  @override
  void dispose() {
    _animController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _fetchIpInfo() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _animController.reset();

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
          _animController.forward();
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
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: languageProvider.textDirection,
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: ResponsivePageWrapper(
              child: Column(
              children: [
                _buildMinimalHeader(context, languageProvider),
                Expanded(
                  child: _isLoading
                      ? _buildMinimalLoading()
                      : _errorMessage != null
                          ? _buildMinimalError()
                          : _buildMinimalContent(),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalHeader(BuildContext context, LanguageProvider langProvider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                langProvider.isRtl
                    ? Icons.arrow_forward_rounded
                    : Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Title
          Expanded(
            child: Text(
              'IP Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
          
          // Refresh button
          GestureDetector(
            onTap: _isLoading ? null : () {
              AnalyticsService().logIpInfoRefresh();
              _fetchIpInfo();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isLoading 
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFF00D9FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: _isLoading 
                    ? Colors.white.withValues(alpha: 0.3)
                    : const Color(0xFF00D9FF),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Wave loading animation (3 bars)
          _buildWaveLoading(),
          
          const SizedBox(height: 24),
          
          Text(
            'Detecting IP...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveLoading() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            // Calculate wave animation with delay for each bar
            final delay = index * 0.2;
            final progress = (_waveController.value + delay) % 1.0;
            
            // Calculate vertical offset (bounce up and down)
            final offset = progress < 0.5
                ? -20.0 * (progress * 2)
                : -20.0 * (2 - progress * 2);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(
                offset: Offset(0, offset),
                child: Container(
                  width: 5,
                  height: 35,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF5A5A5A),
                        Color(0xFF3A3A3A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A4A4A).withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildMinimalError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 32,
              ),
            ),
            
            const SizedBox(height: 20),
            
            Text(
              'Connection Failed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              _errorMessage ?? 'Unable to fetch IP information',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Retry button
            GestureDetector(
              onTap: _fetchIpInfo,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF00D9FF),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Try Again',
                      style: TextStyle(
                        color: Color(0xFF00D9FF),
                        fontSize: 14,
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

  Widget _buildMinimalContent() {
    if (_ipData == null) return const SizedBox();
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: child,
          );
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIPCard(),
              const SizedBox(height: 20),
              _buildLocationSection(),
              const SizedBox(height: 16),
              _buildNetworkSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIPCard() {
    final ip = _ipData!['query'] ?? 'Unknown';
    final city = _ipData!['city'] ?? '';
    final country = _ipData!['country'] ?? '';
    final countryCode = (_ipData!['countryCode'] ?? '').toString().toLowerCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00D9FF).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          // Flag and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Live indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FFA3).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                        color: Color(0xFF00FFA3),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Flag from API
              if (countryCode.isNotEmpty && countryCode.length == 2)
                Container(
                  width: 64,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6.5),
                    child: Image.network(
                      'https://flagcdn.com/w160/$countryCode.png',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to emoji if image fails to load
                        final flagEmoji = countryCode.toUpperCase().split('').map((c) {
                          return String.fromCharCode(c.codeUnitAt(0) + 127397);
                        }).join();
                        return Center(
                          child: Text(
                            flagEmoji,
                            style: const TextStyle(fontSize: 30),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // IP Address
          Text(
            'Your IP Address',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // IP with copy button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  ip,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                        ? const Color(0xFF00FFA3).withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 16,
                    color: _copied 
                        ? const Color(0xFF00FFA3)
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Location
          if (city.isNotEmpty || country.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      [city, country].where((s) => s.isNotEmpty).join(', '),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
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

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.public_rounded,
                  color: Color(0xFF00D9FF),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Location',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        // Location items
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                Icons.flag_rounded,
                'Country',
                '${_ipData!['country']} (${_ipData!['countryCode']})',
              ),
              _buildDivider(),
              _buildInfoRow(
                Icons.location_city_rounded,
                'City',
                _ipData!['city'] ?? 'Unknown',
              ),
              _buildDivider(),
              _buildInfoRow(
                Icons.map_rounded,
                'Region',
                _ipData!['regionName'] ?? 'Unknown',
              ),
              _buildDivider(),
              _buildInfoRow(
                Icons.schedule_rounded,
                'Timezone',
                _ipData!['timezone'] ?? 'Unknown',
              ),
              _buildDivider(),
              _buildInfoRow(
                Icons.my_location_rounded,
                'Coordinates',
                '${(_ipData!['lat'] as num).toStringAsFixed(4)}, ${(_ipData!['lon'] as num).toStringAsFixed(4)}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FFA3).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.router_rounded,
                  color: Color(0xFF00FFA3),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Network',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        // Network items
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                Icons.business_rounded,
                'ISP',
                _ipData!['isp'] ?? 'Unknown',
              ),
              _buildDivider(),
              _buildInfoRow(
                Icons.corporate_fare_rounded,
                'Organization',
                _ipData!['org'] ?? 'Unknown',
              ),
              _buildDivider(),
              _buildInfoRow(
                Icons.numbers_rounded,
                'AS Number',
                _ipData!['as'] ?? 'Unknown',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.4),
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Flexible(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
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

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white.withValues(alpha: 0.03),
    );
  }
}
