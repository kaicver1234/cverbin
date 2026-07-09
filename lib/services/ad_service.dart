import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ad_config.dart';

/// سرویس تبلیغ اختصاصی — کانفیگ تبلیغ رو از یه فایل JSON روی سرور خودمون
/// می‌گیره (همون الگوی UpdateCheckerService). چون فایل روی سروره، می‌شه
/// تبلیغ رو هر وقت خواستیم عوض/خاموش کنیم بدون بیلد جدید.
///
/// فرمت فایل JSON روی سرور:
/// {
///   "enabled": true,
///   "type": "video",                                  // یا "image"
///   "media_url": "https://up.tiksar.ir/ads/clip.mp4", // لینک ویدیو یا عکس
///   "click_url": "https://t.me/tiksar_vpn",           // لینک کلیک (اختیاری)
///   "skip_after": 5,                                  // ثانیه تا فعال‌شدن ضربدر
///   "show_on": "app_open"
/// }
class AdService {
  // آدرس فایل کانفیگ تبلیغ روی سرور خودت. هر وقت خواستی تبلیغ رو عوض کنی،
  // فقط همین فایل و فایل مدیا (عکس/ویدیو) رو روی سرور آپدیت کن.
  static const String _adUrl = 'https://up.tiksar.ir/up-tik/tiksar-ads.json';

  /// کانفیگ تبلیغ رو از سرور می‌گیره. اگه پلتفرم دسکتاپ باشه یا هر خطایی رخ بده،
  /// تبلیغِ غیرفعال برمی‌گردونه (هیچ‌وقت کرش نمی‌کنه).
  static Future<AdConfig> fetchAd() async {
    // روی دسکتاپ تبلیغ نشون نمی‌دیم (اپ اصلی فقط اندرویده).
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return AdConfig.disabled();
    }

    try {
      // چک تبلیغ در background با compute تا فریم اول اپ کند نشه.
      final result = await compute(_fetchAdConfig, _adUrl);
      return result ?? AdConfig.disabled();
    } catch (_) {
      return AdConfig.disabled();
    }
  }

  // این تابع در isolate جداگانه اجرا می‌شه.
  static Future<AdConfig?> _fetchAdConfig(String url) async {
    try {
      final fullUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';

      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return AdConfig.fromJson(json);
      }
    } catch (_) {}

    return null;
  }
}
