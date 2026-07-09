import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../models/ad_config.dart';

/// تبلیغِ تمام‌صفحه — پیاده‌سازیِ وفادار به interstitialِ واقعیِ Google AdMob.
///
/// آناتومی (مطابق مستندات رسمی AdMob):
///  - **تمام‌صفحه**: محتوا (عکس/ویدیو) کل صفحه رو می‌پوشونه، نه یه کارتِ وسطِ صفحه.
///  - **کل صفحه قابل کلیک**: هر جای تبلیغ رو بزنی، لینکِ ثبت‌شده باز می‌شه.
///  - **برچسب «Ad»**: گوشهٔ بالا-چپ، زردِ کهربایی با متن تیره (استانداردِ AdMob، حداقل ۱۵px).
///  - **شمارش معکوس → ضربدر**: گوشهٔ بالا-راست؛ تا `skipAfter` ثانیه فقط عددِ شمارش
///    نشون داده می‌شه (نه بستن، نه back سیستم)، بعد تبدیل به دکمهٔ ضربدر (X) می‌شه.
///  - **دکمهٔ صدا**: برای ویدیو، گوشهٔ پایین-راست (شروع بی‌صدا طبق سیاست autoplay اندروید).
class AdOverlayScreen extends StatefulWidget {
  final AdConfig ad;

  const AdOverlayScreen({super.key, required this.ad});

  /// تبلیغ رو به‌صورت یه صفحهٔ تمام‌صفحهٔ opaque نشون می‌ده.
  /// وقتی کاربر ببنده، Future کامل می‌شه.
  static Future<void> show(BuildContext context, AdConfig ad) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => AdOverlayScreen(ad: ad),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<AdOverlayScreen> createState() => _AdOverlayScreenState();
}

class _AdOverlayScreenState extends State<AdOverlayScreen> {
  // رنگِ زردِ کهربایی برچسبِ «Ad» — همون تُنِ آشنای تبلیغ‌های گوگل.
  static const Color _adAmber = Color(0xFFFFCC33);
  static const Color _spinner = Color(0xFF00D9FF);

  Timer? _countdownTimer;
  late int _remaining;
  bool _canClose = false;

  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _remaining = widget.ad.skipAfter;

    if (widget.ad.isVideo) {
      _initVideo();
    } else {
      // برای عکس، شمارش معکوس بلافاصله شروع می‌شه.
      _startCountdown();
    }
  }

  void _initVideo() {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.ad.mediaUrl),
    );
    _videoController = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      controller.setVolume(0); // شروع بی‌صدا (سیاست autoplay اندروید)
      controller.setLooping(false);
      controller.play();
      setState(() => _videoReady = true);
      // شمارش معکوس بعد از آماده‌شدن ویدیو شروع می‌شه.
      _startCountdown();
    }).catchError((_) {
      // اگه ویدیو لود نشد، نگهش ندار — سریع ببند.
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  void _startCountdown() {
    if (_remaining <= 0) {
      setState(() => _canClose = true);
      return;
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          _canClose = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _onAdTapped() async {
    final url = widget.ad.clickUrl;
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _close() {
    if (!_canClose) return;
    Navigator.of(context).maybePop();
  }

  void _toggleMute() {
    final controller = _videoController;
    if (controller == null) return;
    setState(() {
      _muted = !_muted;
      controller.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // جهتِ ثابت LTR — تبلیغ مثل interstitialِ گوگل مستقل از زبانِ اپه و RTL نمی‌شه.
    return Directionality(
      textDirection: TextDirection.ltr,
      // دکمهٔ back سیستم فقط بعد از پایانِ شمارش کار کنه (مثل گوگل).
      child: PopScope(
        canPop: _canClose,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // محتوای تبلیغ — کل صفحه، قابل کلیک.
              GestureDetector(
                onTap: _onAdTapped,
                behavior: HitTestBehavior.opaque,
                child: _buildMedia(),
              ),

              // برچسب «Ad» — گوشهٔ بالا-چپ، زردِ کهربایی.
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: _buildAdBadge(),
                  ),
                ),
              ),

              // شمارش معکوس / دکمهٔ بستن — گوشهٔ بالا-راست.
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: _buildCloseControl(),
                  ),
                ),
              ),

              // دکمهٔ صدا برای ویدیو — گوشهٔ پایین-راست.
              if (widget.ad.isVideo && _videoReady)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildMuteButton(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedia() {
    if (widget.ad.isVideo) {
      if (!_videoReady || _videoController == null) {
        return const Center(
          child: SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(_spinner),
            ),
          ),
        );
      }
      // ویدیو وسطِ صفحه، با حفظ نسبت (letterbox روی مشکی) — مثل گوگل.
      return Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      );
    }

    // عکس — تمام‌صفحهٔ واقعی (cover) مثل interstitialِ تصویریِ گوگل.
    return CachedNetworkImage(
      imageUrl: widget.ad.mediaUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => const Center(
        child: SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(_spinner),
          ),
        ),
      ),
      // اگه عکس لود نشد، تبلیغ بی‌فایده‌ست — خودکار بسته بشه.
      errorWidget: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).maybePop();
        });
        return const SizedBox.shrink();
      },
    );
  }

  /// برچسب زردِ «Ad» — دقیقاً استایلِ آشنای AdMob (حداقل ۱۵px، متنِ تیرهٔ پررنگ).
  Widget _buildAdBadge() {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _adAmber,
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'Ad',
        style: TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          height: 1.1,
        ),
      ),
    );
  }

  /// شمارش معکوس (عدد) → بعد از پایان، دکمهٔ ضربدر. استایلِ دایرهٔ تیرهٔ AdMob.
  Widget _buildCloseControl() {
    return GestureDetector(
      onTap: _canClose ? _close : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: _canClose
            ? const Icon(Icons.close_rounded, color: Colors.white, size: 22)
            : Text(
                '$_remaining',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
      ),
    );
  }

  Widget _buildMuteButton() {
    return GestureDetector(
      onTap: _toggleMute,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
