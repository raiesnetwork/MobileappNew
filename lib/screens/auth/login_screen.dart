import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ixes.app/constants/imageConstant.dart';
import 'package:ixes.app/screens/BottomNaviagation.dart';
import 'package:ixes.app/screens/compoants.dart/forgetpassword.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:country_picker/country_picker.dart';
import '../../app_localisations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/comment_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/google_auth_service.dart';
import 'launguage_selection_page.dart';
import 'signup_screen.dart';
import 'otp_screen.dart';

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
  static const error         = Color(0xFFE05C6E);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey            = GlobalKey<FormState>();
  final _mobileController   = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isPasswordLogin = true;

  AnimationController? _fadeController;
  Animation<double>?   _fadeAnimation;
  Animation<Offset>?   _slideAnimation;

  final GoogleAuthService _googleAuthService = GoogleAuthService();

  Country _selectedCountry = Country(
    phoneCode: '91', countryCode: 'IN', e164Sc: 0, geographic: true, level: 1,
    name: 'India', example: '9876543210', displayName: 'India',
    displayNameNoCountryCode: 'India', e164Key: '',
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    final controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeController = controller;
    _fadeAnimation  = CurvedAnimation(parent: controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));
    controller.forward();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _fadeController?.dispose();
    super.dispose();
  }

  int _getPhoneNumberLength() {
    const m = {'1':10,'44':10,'91':10,'86':11,'81':10,'49':11,'33':9,'39':10,
      '34':9,'61':9,'7':10,'55':11,'52':10,'27':9,'82':10,'971':9,'966':9,
      '65':8,'60':10,'62':11,'63':10,'84':9,'66':9,'92':10,'880':10};
    return m[_selectedCountry.phoneCode] ?? 10;
  }

  int _getMinPhoneNumberLength() => _getPhoneNumberLength() - 2;

  void _handleForgotPassword() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ForgotPasswordScreen()));

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final mobile = '+${_selectedCountry.phoneCode}${_mobileController.text.trim()}';
    final success = await authProvider.sendOTP(mobile);
    if (!mounted) return;
    if (success) {
      _showSnack(AppLocalizations.instance.otpSentToMsg(mobile), isError: false);
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OTPScreen(mobile: mobile)));
    } else {
      _showSnack(authProvider.errorMessage, isError: true);
    }
  }

  Future<void> _handlePasswordLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final mobile   = '+${_selectedCountry.phoneCode}${_mobileController.text.trim()}';
    final password = _passwordController.text.trim();
    final result   = await authProvider.login(mobile: mobile, password: password);
    if (!mounted) return;
    if (result['success']) {
      final userId = authProvider.user?.id ?? '';
      if (userId.isNotEmpty) {
        Provider.of<CommentProvider>(context, listen: false).setCurrentUserId(userId);
      }
      await _saveFcmToken();
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 0)));
    } else {
      _showSnack(result['message'], isError: true);
    }
  }

  Future<void> _saveFcmToken() async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');
      if (authToken == null || authToken.isEmpty) return;
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;
      await ApiService.post('/api/mobile/user/save-fcm',
          {'fcmToken': fcmToken, 'platform': Platform.isAndroid ? 'android' : 'ios'},
          requireAuth: true);
    } catch (e) { debugPrint('❌ FCM save error: $e'); }
  }

  Future<void> _handleGoogleSignIn() async {
    final prefs    = await SharedPreferences.getInstance();
    final oldToken = prefs.getString('auth_token');
    if (oldToken != null) {
      await AuthService.logout();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      await prefs.remove('user_id');
      await prefs.remove('user_name');
    }
    _showGoogleSigningInDialog();
    final result = await _googleAuthService.signInWithGoogle();
    if (!mounted) return;
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    if (result.success && result.token != null) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.saveUserFromGoogle(
        token: result.token!,
        userId: result.user?['id'] ?? '',
        username: result.user?['username'] ?? result.user?['name'] ?? '',
        userData: result.user,
      );
      final resolvedId = authProvider.user?.id ?? '';
      if (resolvedId.isNotEmpty) {
        Provider.of<CommentProvider>(context, listen: false).setCurrentUserId(resolvedId);
      }
      await _saveFcmToken();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 0)));
    } else {
      _showSnack(result.message ?? AppLocalizations.instance.googleSignInFailed, isError: true);
    }
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 13)),
      backgroundColor: isError ? _C.error : _C.success,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
    ));
  }

  void _showGoogleSigningInDialog() {
    final t = AppLocalizations.instance;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E0060),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
              boxShadow: [BoxShadow(
                  color: const Color(0xFF6C3FE8).withOpacity(0.4),
                  blurRadius: 40, spreadRadius: 2)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1)),
                child: const Center(child: Text('G',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
              const SizedBox(height: 20),
              Text(t.signingYouIn,
                  style: const TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              const SizedBox(height: 6),
              Text(t.verifyingGoogle, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5)),
              const SizedBox(height: 24),
              SizedBox(width: 36, height: 36,
                  child: CircularProgressIndicator(strokeWidth: 2.5,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C3FE8)),
                      backgroundColor: Colors.white.withOpacity(0.1))),
              const SizedBox(height: 16),
              Text(t.securingSession,
                  style: TextStyle(color: Colors.white.withOpacity(0.35),
                      fontSize: 11, letterSpacing: 0.3)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  // ValueListenableBuilder listens to AppLocalizations.notifier.
  // When setLanguage() is called anywhere, notifier fires → builder re-runs
  // → t is fresh → all Text widgets show the new language instantly. ✅
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocalizations.notifier,
      builder: (context, _, __) {
        final t = AppLocalizations.instance; // fresh on every language change
        return _buildScaffold(context, t);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, AppLocalizations t) {
    return Scaffold(
      backgroundColor: _C.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
          child: FadeTransition(
            opacity: _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
            child: SlideTransition(
              position: _slideAnimation ?? const AlwaysStoppedAnimation(Offset.zero),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 4.h),
                    Hero(tag: 'app_logo', child: Image.asset(Images.LogoTrans, height: 14.h)),
                    SizedBox(height: 3.h),

                    Align(alignment: Alignment.centerLeft,
                        child: Text(t.welcomeBack,
                            style: const TextStyle(color: _C.textPrimary, fontSize: 26,
                                fontWeight: FontWeight.w700, letterSpacing: -0.5))),
                    const SizedBox(height: 4),
                    Align(alignment: Alignment.centerLeft,
                        child: Text(t.signInToYourAccount,
                            style: const TextStyle(color: _C.textSecondary, fontSize: 14))),
                    SizedBox(height: 2.5.h),

                    // Form card
                    Container(
                      decoration: BoxDecoration(color: _C.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _C.border, width: 1)),
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildLabel(t.mobileNumber),
                            const SizedBox(height: 8),
                            _buildMobileField(t),
                            const SizedBox(height: 16),
                            _buildMethodToggle(t),
                            const SizedBox(height: 16),

                            if (_isPasswordLogin) ...[
                              _buildLabel(t.password),
                              const SizedBox(height: 8),
                              _buildPasswordField(t),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: _handleForgotPassword,
                                  child: Text(t.forgotPassword,
                                      style: const TextStyle(color: _C.accent,
                                          fontSize: 12, fontWeight: FontWeight.w500)),
                                ),
                              ),
                            ],

                            SizedBox(height: _isPasswordLogin ? 20 : 4),

                            Consumer<AuthProvider>(
                              builder: (_, authProvider, __) => _PrimaryButton(
                                label: _isPasswordLogin ? t.login : t.sendOtp,
                                isLoading: authProvider.isLoading,
                                onPressed: _isPasswordLogin ? _handlePasswordLogin : _sendOTP,
                              ),
                            ),

                            const SizedBox(height: 20),
                            Row(children: [
                              Expanded(child: Divider(color: _C.border, thickness: 1)),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Text(t.or,
                                      style: const TextStyle(color: _C.textMuted, fontSize: 12))),
                              Expanded(child: Divider(color: _C.border, thickness: 1)),
                            ]),
                            const SizedBox(height: 20),
                            _GoogleButton(label: t.continueWithGoogle, onPressed: _handleGoogleSignIn),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 2.5.h),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(t.dontHaveAccount,
                          style: const TextStyle(color: _C.textSecondary, fontSize: 13)),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => SignupScreen())),
                        child: Text(t.signUp,
                            style: const TextStyle(color: _C.accent,
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 15),

                    // Change Language button
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const LanguageSelectionScreen(isFromSettings: true))),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        decoration: BoxDecoration(color: _C.surfaceHi,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _C.border)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.language_rounded, color: _C.accent, size: 16),
                          const SizedBox(width: 8),
                          Text(t.changeLanguage,
                              style: const TextStyle(color: _C.accent,
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    ),
                    SizedBox(height: 2.h),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: const TextStyle(color: _C.textSecondary, fontSize: 12,
          fontWeight: FontWeight.w500, letterSpacing: 0.3));

  Widget _buildMobileField(AppLocalizations t) {
    return Container(
      decoration: BoxDecoration(color: _C.surfaceHi,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
      child: Row(children: [
        GestureDetector(
          onTap: () => showCountryPicker(
            context: context, showPhoneCode: true,
            countryListTheme: CountryListThemeData(
              backgroundColor: _C.surface,
              textStyle: const TextStyle(color: _C.textPrimary),
              searchTextStyle: const TextStyle(color: _C.textPrimary),
              bottomSheetHeight: 500,
              inputDecoration: InputDecoration(
                hintText: 'Search country...',
                hintStyle: const TextStyle(color: _C.textMuted),
                prefixIcon: const Icon(Icons.search, color: _C.textMuted, size: 18),
                filled: true, fillColor: _C.surfaceHi,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.border)),
              ),
            ),
            onSelect: (Country country) => setState(() {
              _selectedCountry = country;
              _mobileController.clear();
            }),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: _C.border))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_selectedCountry.flagEmoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text('+${_selectedCountry.phoneCode}',
                  style: const TextStyle(color: _C.textPrimary,
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down_rounded, color: _C.textMuted, size: 16),
            ]),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15)],
            style: const TextStyle(color: _C.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: t.enterNumber,
              hintStyle: const TextStyle(color: _C.textMuted, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return t.enterMobileNumber;
              if (value.length < _getMinPhoneNumberLength()) return t.numberTooShort;
              if (value.length > _getPhoneNumberLength() + 2) return t.numberTooLong;
              return null;
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildPasswordField(AppLocalizations t) {
    return Container(
      decoration: BoxDecoration(color: _C.surfaceHi,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: const TextStyle(color: _C.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: t.enterPassword,
          hintStyle: const TextStyle(color: _C.textMuted, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: _C.textMuted, size: 18),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: _C.textMuted, size: 18),
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return t.enterYourPassword;
          return null;
        },
      ),
    );
  }

  Widget _buildMethodToggle(AppLocalizations t) {
    return Container(
      height: 40,
      decoration: BoxDecoration(color: _C.surfaceHi,
          borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)),
      child: Row(children: [_buildTab(t.passwordTab, true), _buildTab(t.otpTab, false)]),
    );
  }

  Widget _buildTab(String label, bool isPassword) {
    final isSelected = (isPassword && _isPasswordLogin) || (!isPassword && !_isPasswordLogin);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isPasswordLogin = isPassword),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: isSelected ? _C.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(7)),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(
              color: isSelected ? Colors.white : _C.textSecondary,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  const _PrimaryButton({required this.label, required this.isLoading, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: _C.accent, foregroundColor: Colors.white, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            disabledBackgroundColor: _C.accent.withOpacity(0.5)),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 15,
            fontWeight: FontWeight.w600, letterSpacing: 0.2)),
      ),
    );
  }
}

// Replace the _GoogleButton class at the bottom of login_screen.dart with this:

class _GoogleButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _GoogleButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
            backgroundColor: _C.surfaceHi,
            foregroundColor: _C.textPrimary,
            side: const BorderSide(color: _C.border, width: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            elevation: 0),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.surface,
                  border: Border.all(color: _C.border)),
              alignment: Alignment.center,
              child: const Text('G',
                  style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700, color: _C.textPrimary)),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _C.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}