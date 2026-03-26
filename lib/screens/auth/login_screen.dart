import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ixes.app/constants/imageConstant.dart';
import 'package:ixes.app/globalwidget/global_textfild.dart';
import 'package:ixes.app/screens/BottomNaviagation.dart';
import 'package:ixes.app/screens/compoants.dart/forgetpassword.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:country_picker/country_picker.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/google_auth_service.dart';
import 'signup_screen.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isPasswordLogin = true;

  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  final GoogleAuthService _googleAuthService = GoogleAuthService();

  Country _selectedCountry = Country(
    phoneCode: '91',
    countryCode: 'IN',
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: 'India',
    example: '9876543210',
    displayName: 'India',
    displayNameNoCountryCode: 'India',
    e164Key: '',
  );

  @override
  void initState() {
    super.initState();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeController = controller;
    _fadeAnimation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    ));
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
    final lengthMap = {
      '1': 10, '44': 10, '91': 10, '86': 11, '81': 10,
      '49': 11, '33': 9, '39': 10, '34': 9, '61': 9,
      '7': 10, '55': 11, '52': 10, '27': 9, '82': 10,
      '971': 9, '966': 9, '65': 8, '60': 10, '62': 11,
      '63': 10, '84': 9, '66': 9, '92': 10, '880': 10,
    };
    return lengthMap[_selectedCountry.phoneCode] ?? 10;
  }

  int _getMinPhoneNumberLength() => _getPhoneNumberLength() - 2;

  void _handleForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
    );
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final mobile =
        '+${_selectedCountry.phoneCode}${_mobileController.text.trim()}';
    final success = await authProvider.sendOTP(mobile);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP sent to $mobile'),
          backgroundColor: const Color(0xFF6C3FE8),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => OTPScreen(mobile: mobile)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _handlePasswordLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final mobile =
        '+${_selectedCountry.phoneCode}${_mobileController.text.trim()}';
    final password = _passwordController.text.trim();
    final result = await authProvider.login(mobile: mobile, password: password);
    if (!mounted) return;
    if (result['success']) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (context) => const MainScreen(initialIndex: 0)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    // ✅ Step 1: Clear old session first so backend doesn't conflict
    final prefs = await SharedPreferences.getInstance();
    final oldToken = prefs.getString('auth_token');
    if (oldToken != null) {
      // Tell backend to invalidate old session
      await AuthService.logout();
      // Clear local storage immediately
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      await prefs.remove('user_id');
      await prefs.remove('user_name');
    }

    // ✅ Step 2: Now do Google Sign-In with clean slate
    final result = await _googleAuthService.signInWithGoogle();
    if (!mounted) return;

    if (result.success && result.token != null) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.saveUserFromGoogle(
        token: result.token!,
        userId: result.user?['id'] ?? '',
        username: result.user?['username'] ?? result.user?['name'] ?? '',
        userData: result.user,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainScreen(initialIndex: 0),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Google Sign-In failed.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A0050),
              Color(0xFF3700BB),
              Color(0xFF6C3FE8),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
              child: SlideTransition(
                position: _slideAnimation ??
                    const AlwaysStoppedAnimation(Offset.zero),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: 3.h),

                      // ── Logo ──────────────────────────────────────
                      Hero(
                        tag: 'app_logo',
                        child: Image.asset(
                          Images.LogoTrans,
                          height: 18.h,
                        ),
                      ),
                      SizedBox(height: 1.5.h),

                      // ── Tagline ───────────────────────────────────
                      Text(
                        'Welcome back',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to continue',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(height: 2.5.h),

                      // ── Form Card ─────────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Mobile Field ──────────────────────
                              CustomTextField(
                                controller: _mobileController,
                                labelText: 'Mobile Number',
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(15),
                                ],
                                prefix: InkWell(
                                  onTap: () {
                                    showCountryPicker(
                                      context: context,
                                      showPhoneCode: true,
                                      countryListTheme: CountryListThemeData(
                                        backgroundColor: const Color(0xFF1A0050),
                                        textStyle: const TextStyle(
                                            color: Colors.white),
                                        searchTextStyle: const TextStyle(
                                            color: Colors.white),
                                        bottomSheetHeight: 500,
                                        inputDecoration: const InputDecoration(
                                          hintText: 'Search country...',
                                          hintStyle: TextStyle(
                                              color: Colors.white54),
                                          prefixIcon: Icon(Icons.search,
                                              color: Colors.white54),
                                          border: OutlineInputBorder(
                                            borderSide: BorderSide(
                                                color: Colors.white30),
                                          ),
                                        ),
                                      ),
                                      onSelect: (Country country) {
                                        setState(() {
                                          _selectedCountry = country;
                                          _mobileController.clear();
                                        });
                                      },
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _selectedCountry.flagEmoji,
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '+${_selectedCountry.phoneCode}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Icon(Icons.arrow_drop_down,
                                            color: Colors.black45, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your mobile number';
                                  }
                                  if (value.length < _getMinPhoneNumberLength()) {
                                    return 'Number too short for ${_selectedCountry.name}';
                                  }
                                  if (value.length >
                                      _getPhoneNumberLength() + 2) {
                                    return 'Number too long for ${_selectedCountry.name}';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // ── Login Method Toggle ───────────────
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    _buildToggleTab('Password', true),
                                    const SizedBox(width: 4),
                                    _buildToggleTab('OTP', false),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ── Password Field ────────────────────
                              if (_isPasswordLogin) ...[
                                CustomTextField(
                                  controller: _passwordController,
                                  labelText: 'Password',
                                  obscureText: _obscurePassword,
                                  prefixIcon: const Icon(Icons.lock_outline,
                                      size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                            () => _obscurePassword = !_obscurePassword),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _handleForgotPassword,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: Color(0xFFAA8DFF),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              SizedBox(height: _isPasswordLogin ? 6 : 4),

                              // ── Primary Login Button ──────────────
                              Consumer<AuthProvider>(
                                builder: (context, authProvider, _) {
                                  return ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6C3FE8),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      minimumSize: const Size(double.infinity, 52),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14, horizontal: 24),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: authProvider.isLoading
                                        ? null
                                        : (_isPasswordLogin
                                        ? _handlePasswordLogin
                                        : _sendOTP),
                                    child: authProvider.isLoading
                                        ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                        : Text(
                                      _isPasswordLogin ? 'Login' : 'Send OTP',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                        height: 1.0,
                                      ),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 14),

                              // ── Divider ───────────────────────────
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: Colors.white.withOpacity(0.25),
                                      thickness: 1,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text(
                                      'or',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: Colors.white.withOpacity(0.25),
                                      thickness: 1,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // ── Google Sign-In Button ─────────────
                              SizedBox(
                                height: 52,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.15),
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.white.withOpacity(0.4), width: 1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                  ),
                                  onPressed: _handleGoogleSignIn,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Google "G" SVG-style icon via custom paint
                                      _GoogleIcon(size: 20),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Continue with Google',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 2.h),

                      // ── Sign Up Link ──────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13.sp,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => SignupScreen()));
                            },
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),


                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 2.h),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleTab(String label, bool isPassword) {
    final bool isSelected =
        (isPassword && _isPasswordLogin) || (!isPassword && !_isPasswordLogin);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isPasswordLogin = isPassword),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6C3FE8)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontSize: 13,
              fontWeight:
              isSelected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Google "G" Icon ──────────────────────────────────────────────────────────
class _GoogleIcon extends StatelessWidget {
  final double size;
  const _GoogleIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.25),
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: size * 0.60,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.15,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}