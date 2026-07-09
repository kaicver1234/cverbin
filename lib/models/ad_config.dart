/// مدل تبلیغِ اختصاصی — از فایل JSON روی سرور خودمون خونده می‌شه
/// (مثل up.tiksar.ir/.../ads.json). همه‌چیز از همون فایل کنترل می‌شه:
/// نوع تبلیغ (عکس/ویدیو)، لینک مدیا، لینک کلیک، مدت زمان تا فعال‌شدن ضربدر،
/// و روشن/خاموش بودن — بدون نیاز به بیلد جدید.
class AdConfig {
  /// روشن/خاموش کل تبلیغ
  final bool enabled;

  /// نوع محتوا: 'image' یا 'video'
  final String type;

  /// لینک عکس یا ویدیوی تبلیغ
  final String mediaUrl;

  /// لینکی که با کلیک روی تبلیغ باز می‌شه (اختیاری — اگه خالی باشه کلیک کاری نمی‌کنه)
  final String clickUrl;

  /// بعد از چند ثانیه دکمهٔ بستن (ضربدر) فعال بشه (مثل تبلیغ‌های گوگل).
  /// بین ۱ تا ۳۰ ثانیه clamp می‌شه.
  final int skipAfter;

  /// کجا نمایش داده بشه: فعلاً 'app_open' (موقع باز شدن اپ).
  final String showOn;

  AdConfig({
    required this.enabled,
    required this.type,
    required this.mediaUrl,
    required this.clickUrl,
    required this.skipAfter,
    required this.showOn,
  });

  bool get isVideo => type.toLowerCase() == 'video';

  /// تبلیغ فقط وقتی قابل نمایشه که روشن باشه و لینک مدیا داشته باشه.
  bool get isValid => enabled && mediaUrl.isNotEmpty;

  factory AdConfig.fromJson(Map<String, dynamic> json) {
    // skipAfter رو امن پارس کن (ممکنه رشته یا عدد بیاد) و بین ۱..۳۰ clamp کن.
    final rawSkip = json['skip_after'];
    int skip = 5;
    if (rawSkip is int) {
      skip = rawSkip;
    } else if (rawSkip is num) {
      skip = rawSkip.round();
    } else if (rawSkip is String) {
      skip = int.tryParse(rawSkip.trim()) ?? 5;
    }
    if (skip < 1) skip = 1;
    if (skip > 30) skip = 30;

    return AdConfig(
      enabled: json['enabled'] == true,
      type: (json['type'] ?? 'image').toString(),
      mediaUrl: (json['media_url'] ?? '').toString(),
      clickUrl: (json['click_url'] ?? '').toString(),
      skipAfter: skip,
      showOn: (json['show_on'] ?? 'app_open').toString(),
    );
  }

  /// تبلیغ خالی/غیرفعال — به‌عنوان مقدار پیش‌فرض امن استفاده می‌شه.
  factory AdConfig.disabled() => AdConfig(
        enabled: false,
        type: 'image',
        mediaUrl: '',
        clickUrl: '',
        skipAfter: 5,
        showOn: 'app_open',
      );
}
