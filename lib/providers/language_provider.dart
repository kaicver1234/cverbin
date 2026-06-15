import 'package:flutter/material.dart';
import '../models/app_language.dart';
import '../services/language_service.dart';
import '../services/analytics_service.dart';

class LanguageProvider extends ChangeNotifier {
  final LanguageService _languageService = LanguageService();
  final AnalyticsService _analyticsService = AnalyticsService();

  AppLanguage _currentLanguage = AppLanguage.getByCode('en');
  Map<String, dynamic> _translations = {};
  bool _isInitialized = false;
  bool _isLoading = false;

  // Getters
  AppLanguage get currentLanguage => _currentLanguage;
  Map<String, dynamic> get translations => _translations;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  List<AppLanguage> get supportedLanguages => AppLanguage.supportedLanguages;

  // Initialize language system
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      _currentLanguage = await _languageService.initializeLanguage();
      await _loadTranslations(_currentLanguage.code);
      _isInitialized = true;
    } catch (e) {
      // Fallback to default language
      _currentLanguage = AppLanguage.getByCode('en');
      await _loadTranslations('en');
      _isInitialized = true;
    }

    _isLoading = false;
    notifyListeners();
  }

  // Change language
  Future<bool> changeLanguage(AppLanguage language) async {
    if (_currentLanguage == language) return true;

    final oldLanguage = _currentLanguage.code;
    _isLoading = true;
    notifyListeners();

    try {
      // Save to storage
      final saved = await _languageService.saveLanguage(language);
      if (!saved) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Load translations
      await _loadTranslations(language.code);

      _currentLanguage = language;
      
      // Log language change analytics
      try {
        await _analyticsService.logLanguageChange(
          fromLanguage: oldLanguage,
          toLanguage: language.code,
        );
      } catch (e) {
        // Analytics logging failed, ignore
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load translations for specific language
  Future<void> _loadTranslations(String languageCode) async {
    try {
      _translations = await _languageService.loadTranslations(languageCode);
    } catch (e) {
      // Fallback to English if loading fails
      if (languageCode != 'en') {
        _translations = await _languageService.loadTranslations('en');
      } else {
        _translations = {};
      }
    }
  }

  // Get translation for a key
  String translate(String key, {Map<String, String>? parameters}) {
    return _getNestedTranslation(key, parameters);
  }

  // Get nested translation using dot notation (e.g., 'tools.title')
  String _getNestedTranslation(String key, Map<String, String>? parameters) {
    final keys = key.split('.');
    dynamic current = _translations;

    for (final k in keys) {
      if (current is Map<String, dynamic> && current.containsKey(k)) {
        current = current[k];
      } else {
        // Return key if translation not found
        return key;
      }
    }

    String result = current?.toString() ?? key;

    // Replace parameters
    if (parameters != null) {
      parameters.forEach((paramKey, paramValue) {
        result = result.replaceAll('{$paramKey}', paramValue);
      });
    }

    return result;
  }

  // Check if key exists in translations
  bool hasTranslation(String key) {
    final keys = key.split('.');
    dynamic current = _translations;

    for (final k in keys) {
      if (current is Map<String, dynamic> && current.containsKey(k)) {
        current = current[k];
      } else {
        return false;
      }
    }

    return current != null;
  }

  // Get text direction for current language
  TextDirection get textDirection {
    return _currentLanguage.isRtl ? TextDirection.rtl : TextDirection.ltr;
  }

  // Get locale for current language
  Locale get locale {
    return Locale(_currentLanguage.code);
  }

  // Check if current language is RTL
  bool get isRtl => _currentLanguage.isRtl;
}
