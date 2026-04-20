import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:ixes.app/constants/imageConstant.dart';

import 'package:ixes.app/screens/auth/login_screen.dart';

import '../../app_localisations.dart';

class _C {
  static const bg            = Color(0xFF0A0A0F);
  static const surface       = Color(0xFF13131A);
  static const surfaceHi     = Color(0xFF1C1C27);
  static const border        = Color(0xFF2A2A3A);
  static const accent        = Color(0xFF7C5CFC);
  static const textPrimary   = Color(0xFFF0F0F5);
  static const textSecondary = Color(0xFF8888A0);
  static const textMuted     = Color(0xFF55556A);
  static const success       = Color(0xFF4CAF82);
}

class LanguageSelectionScreen extends StatefulWidget {
  final bool isFromSettings;
  const LanguageSelectionScreen({super.key, this.isFromSettings = false});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with SingleTickerProviderStateMixin {

  String? _selectedCode;
  bool _isSaving = false;

  late AnimationController _fadeController;
  late Animation<double>   _fadeAnimation;
  late Animation<Offset>   _slideAnimation;

  static const _languages = [
    _Language(code: 'en', name: 'English',   nativeName: 'English',   greeting: 'Hello',        emoji: '🌐', gradient: [Color(0xFF4A90D9), Color(0xFF2C6FAC)]),
    _Language(code: 'te', name: 'Telugu',    nativeName: 'తెలుగు',    greeting: 'నమస్కారం',     emoji: '🌺', gradient: [Color(0xFF7C5CFC), Color(0xFF5B3FD4)]),
    _Language(code: 'hi', name: 'Hindi',     nativeName: 'हिन्दी',    greeting: 'नमस्ते',       emoji: '🙏', gradient: [Color(0xFFFC5C7D), Color(0xFFD43F5B)]),
    _Language(code: 'ta', name: 'Tamil',     nativeName: 'தமிழ்',     greeting: 'வணக்கம்',      emoji: '🌸', gradient: [Color(0xFF5CF0FC), Color(0xFF3FC8D4)]),
    _Language(code: 'kn', name: 'Kannada',   nativeName: 'ಕನ್ನಡ',     greeting: 'ನಮಸ್ಕಾರ',     emoji: '🌻', gradient: [Color(0xFFFCA85C), Color(0xFFD4873F)]),
    _Language(code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം',    greeting: 'നമസ്കാരം',    emoji: '🌴', gradient: [Color(0xFF5CFC8E), Color(0xFF3FD46A)]),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnimation  = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    _fadeController.forward();

    // Pre-select already saved language
    final saved = AppLocalizations.currentCode;
    if (_languages.any((l) => l.code == saved)) {
      _selectedCode = saved;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _navigateNext() {
    if (widget.isFromSettings) {
      Navigator.of(context).pop(_selectedCode);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _saveAndContinue() async {
    final t = AppLocalizations.instance;
    if (_selectedCode == null) {
      _showSnack(t.pleaseSelectLanguage, isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await AppLocalizations.setLanguage(_selectedCode!);
      if (!mounted) return;
      setState(() => _isSaving = false);
      final lang = _languages.firstWhere((l) => l.code == _selectedCode);
      _showSnack(AppLocalizations.instance.languageSelectedMsg(lang.name), isError: false);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      _navigateNext();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnack(AppLocalizations.instance.failedToSaveLanguage, isError: true);
      }
    }
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 13)),
      backgroundColor: isError ? const Color(0xFFE05C6E) : _C.success,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.instance;

    return Scaffold(
      backgroundColor: _C.bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 3.h),
                  Hero(tag: 'app_logo', child: Image.asset(Images.LogoTrans, height: 10.h)),
                  SizedBox(height: 2.5.h),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(t.chooseLanguage,
                        style: const TextStyle(color: _C.textPrimary, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(t.chooseLanguageSubtitle,
                        style: const TextStyle(color: _C.textSecondary, fontSize: 13, height: 1.4)),
                  ),
                  SizedBox(height: 2.5.h),

                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _C.border, width: 1),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _languages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final lang = _languages[index];
                          return _LanguageCard(
                            language: lang,
                            isSelected: _selectedCode == lang.code,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedCode = lang.code);
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: 2.h),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedCode != null ? _C.accent : _C.accent.withOpacity(0.4),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        disabledBackgroundColor: _C.accent.withOpacity(0.4),
                      ),
                      onPressed: _isSaving ? null : _saveAndContinue,
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _selectedCode != null
                                ? t.continueWithLang(_languages.firstWhere((l) => l.code == _selectedCode).name)
                                : t.selectALanguage,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                          ),
                          if (_selectedCode != null) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 1.5.h),

                  if (!widget.isFromSettings)
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        await AppLocalizations.setLanguage('en');
                        if (!mounted) return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        child: Text(t.skipForNow,
                            style: const TextStyle(
                              color: _C.textSecondary, fontSize: 14, fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline, decorationColor: _C.textSecondary,
                            )),
                      ),
                    ),

                  SizedBox(height: 1.5.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final _Language language;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageCard({required this.language, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _C.accent.withOpacity(0.08) : _C.surfaceHi,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _C.accent.withOpacity(0.6) : _C.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: isSelected ? LinearGradient(colors: language.gradient,
                    begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                color: isSelected ? null : _C.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? Colors.transparent : _C.border),
              ),
              alignment: Alignment.center,
              child: Text(language.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(language.nativeName,
                      style: const TextStyle(color: _C.textPrimary, fontSize: 16,
                          fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(language.name, style: const TextStyle(color: _C.textSecondary, fontSize: 12)),
                    const SizedBox(width: 6),
                    Container(width: 3, height: 3,
                        decoration: const BoxDecoration(color: _C.textMuted, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(language.greeting,
                        style: TextStyle(
                            color: isSelected ? _C.accent : _C.textMuted,
                            fontSize: 12, fontStyle: FontStyle.italic)),
                  ]),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: isSelected ? _C.accent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? _C.accent : _C.border, width: 1.5),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Language {
  final String code, name, nativeName, greeting, emoji;
  final List<Color> gradient;
  const _Language({
    required this.code, required this.name, required this.nativeName,
    required this.greeting, required this.emoji, required this.gradient,
  });
}