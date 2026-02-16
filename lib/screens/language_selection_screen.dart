import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/language_provider.dart';
import '../models/app_language.dart';
import 'privacy_welcome_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  AppLanguage? _selectedLanguage;
  bool _isChangingLanguage = false;

  static const List<_LanguageData> _languages = [
    _LanguageData(
      language: AppLanguage(name: 'English', code: 'en', flag: '🇺🇸', direction: 'ltr'),
      name: 'English',
      nativeName: 'English',
      flag: '🇺🇸',
      gradientStart: Color(0xFF10B981),
      gradientEnd: Color(0xFF34D399),
    ),
    _LanguageData(
      language: AppLanguage(name: 'پارسی', code: 'fa', flag: '🇮🇷', direction: 'rtl'),
      name: 'پارسی',
      nativeName: 'Persian',
      flag: '🇮🇷',
      gradientStart: Color(0xFF06B6D4),
      gradientEnd: Color(0xFF22D3EE),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        setState(() {
          _selectedLanguage = languageProvider.currentLanguage;
        });
      }
    });
  }

  Future<void> _selectLanguage(AppLanguage language) async {
    if (_isChangingLanguage || !mounted) return;
    
    setState(() {
      _selectedLanguage = language;
      _isChangingLanguage = true;
    });
    
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    await languageProvider.changeLanguage(language);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('language_selected', true);
    
    if (mounted) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PrivacyWelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      body: Stack(
        children: [
          // Background decorations matching app theme
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom glow
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF10B981).withValues(alpha: 0.03),
                    const Color(0xFF10B981).withValues(alpha: 0.06),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
          
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF34D399)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.language_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 28),
                    
                    // Title English
                    const Text(
                      'Choose Your Language',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Title Persian
                    Text(
                      'زبان خود را انتخاب کنید',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 0,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Language cards
                    ..._languages.map((langData) {
                      final isSelected = _selectedLanguage == langData.language;
                      return _LanguageCard(
                        key: ValueKey(langData.language.code),
                        data: langData,
                        isSelected: isSelected,
                        onTap: () => _selectLanguage(langData.language),
                      );
                    }),
                    
                    const SizedBox(height: 28),
                    
                    // Continue button
                    if (_selectedLanguage != null)
                      _ContinueButton(
                        isLoading: _isChangingLanguage,
                        onPressed: _isChangingLanguage 
                            ? null 
                            : () => _selectLanguage(_selectedLanguage!),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Language data class
class _LanguageData {
  final AppLanguage language;
  final String name;
  final String nativeName;
  final String flag;
  final Color gradientStart;
  final Color gradientEnd;

  const _LanguageData({
    required this.language,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.gradientStart,
    required this.gradientEnd,
  });
}

// Language card widget
class _LanguageCard extends StatelessWidget {
  final _LanguageData data;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageCard({
    super.key,
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [data.gradientStart, data.gradientEnd],
                    )
                  : null,
              color: isSelected ? null : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.06),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: data.gradientStart.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                // Flag
                Text(
                  data.flag,
                  style: const TextStyle(fontSize: 34),
                ),
                
                const SizedBox(width: 14),
                
                // Language info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: isSelected 
                              ? FontWeight.bold 
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.nativeName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Check icon
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Continue button
class _ContinueButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _ContinueButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF34D399)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  'CONTINUE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
        ),
      ),
    );
  }
}
