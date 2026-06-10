import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/modern_glass_card.dart';
import '../services/analytics_service.dart';

// Shared palette with the rest of the app (see routing_settings_screen).
const Color _kPrimary = Color(0xFF00D9FF);
const Color _kAccent = Color(0xFF00FFA3);
const Color _kDanger = Color(0xFFFF6B6B);

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

  late final AnimationController _animController;
  late final Animation<double> _fade;
  late final AnimationController _waveController;

  bool get _isRtl =>
      Provider.of<LanguageProvider>(context, listen: false).isRtl;

  String _t({required String fa, required String en}) => _isRtl ? fa : en;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
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
        _errorMessage = _t(fa: 'اتصال اینترنت برقرار نیست', en: 'No internet connection');
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().contains('timeout')
            ? _t(fa: 'زمان اتصال به پایان رسید', en: 'Connection timeout')
            : _t(fa: 'دریافت اطلاعات IP ممکن نشد', en: 'Unable to fetch IP information');
        _isLoading = false;
      });
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = _isRtl;
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                isRtl
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.arrow_back_ios_rounded,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              _t(fa: 'اطلاعات IP', en: 'IP Information'),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: _isLoading
                      ? Colors.white.withValues(alpha: 0.3)
                      : _kPrimary,
                  size: 22,
                ),
                onPressed: _isLoading
                    ? null
                    : () {
                        AnalyticsService().logIpInfoRefresh();
                        _fetchIpInfo();
                      },
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: ResponsivePageWrapper(
              child: _isLoading
                  ? _buildLoading()
                  : _errorMessage != null
                      ? _buildError()
                      : _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildWaveLoading(),
          const SizedBox(height: 26),
          Text(
            _t(fa: 'در حال شناسایی IP...', en: 'Detecting IP...'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveLoading() {
    const double barW = 4;
    const double barH = 30;
    const double hPad = 3;
    const double bounce = 15;
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final delay = index * 0.15;
            final progress = (_waveController.value + delay) % 1.0;

            final offset = progress < 0.5
                ? -bounce * (progress * 2)
                : -bounce * (2 - progress * 2);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: hPad),
              child: Transform.translate(
                offset: Offset(0, offset),
                child: Container(
                  width: barW,
                  height: barH,
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _kDanger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: _kDanger, size: 28),
            ),
            const SizedBox(height: 18),
            Text(
              _t(fa: 'اتصال ناموفق', en: 'Connection Failed'),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 26),
            GestureDetector(
              onTap: _fetchIpInfo,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kPrimary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, color: _kPrimary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _t(fa: 'تلاش دوباره', en: 'Try Again'),
                      style: GoogleFonts.poppins(
                        color: _kPrimary,
                        fontSize: 13,
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

  Widget _buildContent() {
    if (_ipData == null) return const SizedBox();
    return FadeTransition(
      opacity: _fade,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroCard(),
            const SizedBox(height: 24),
            _buildSectionLabel(_t(fa: 'موقعیت', en: 'Location')),
            const SizedBox(height: 12),
            _buildInfoCard([
              (Icons.flag_rounded, _t(fa: 'کشور', en: 'Country'),
                  '${_ipData!['country']} (${_ipData!['countryCode']})'),
              (Icons.location_city_rounded, _t(fa: 'شهر', en: 'City'),
                  (_ipData!['city'] ?? '—').toString()),
              (Icons.map_rounded, _t(fa: 'استان', en: 'Region'),
                  (_ipData!['regionName'] ?? '—').toString()),
              (Icons.schedule_rounded, _t(fa: 'منطقه زمانی', en: 'Timezone'),
                  (_ipData!['timezone'] ?? '—').toString()),
              (Icons.my_location_rounded, _t(fa: 'مختصات', en: 'Coordinates'),
                  _coords()),
            ]),
            const SizedBox(height: 22),
            _buildSectionLabel(_t(fa: 'شبکه', en: 'Network')),
            const SizedBox(height: 12),
            _buildInfoCard([
              (Icons.business_rounded, _t(fa: 'سرویس‌دهنده', en: 'ISP'),
                  (_ipData!['isp'] ?? '—').toString()),
              (Icons.corporate_fare_rounded, _t(fa: 'سازمان', en: 'Organization'),
                  (_ipData!['org'] ?? '—').toString()),
              (Icons.numbers_rounded, _t(fa: 'شماره AS', en: 'AS Number'),
                  (_ipData!['as'] ?? '—').toString()),
            ]),
          ],
        ),
      ),
    );
  }

  String _coords() {
    final lat = _ipData!['lat'];
    final lon = _ipData!['lon'];
    if (lat is num && lon is num) {
      return '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
    }
    return '—';
  }

  Widget _buildHeroCard() {
    final ip = (_ipData!['query'] ?? 'Unknown').toString();
    final city = (_ipData!['city'] ?? '').toString();
    final country = (_ipData!['country'] ?? '').toString();
    final countryCode =
        (_ipData!['countryCode'] ?? '').toString().toLowerCase();
    final location =
        [city, country].where((s) => s.isNotEmpty).join(', ');

    return ModernGlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _kAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: GoogleFonts.poppins(
                        color: _kAccent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              if (countryCode.length == 2) _buildFlag(countryCode),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            _t(fa: 'آدرس IP شما', en: 'YOUR IP ADDRESS'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  ip,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _copyToClipboard(ip),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _copied
                        ? _kAccent.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 16,
                    color: _copied
                        ? _kAccent
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
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
                      location,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12.5,
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
        ],
      ),
    );
  }

  Widget _buildFlag(String countryCode) {
    return Container(
      width: 56,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.network(
          'https://flagcdn.com/w160/$countryCode.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            final emoji = countryCode.toUpperCase().split('').map((c) {
              return String.fromCharCode(c.codeUnitAt(0) + 127397);
            }).join();
            return Center(child: Text(emoji, style: const TextStyle(fontSize: 26)));
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: 18,
                height: 18,
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
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.poppins(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildInfoCard(List<(IconData, String, String)> rows) {
    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          _buildInfoRow(rows[i].$1, rows[i].$2, rows[i].$3),
          if (i != rows.length - 1) _buildDivider(),
        ],
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12.5,
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
                fontSize: 12.5,
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
      color: Colors.white.withValues(alpha: 0.05),
    );
  }
}
