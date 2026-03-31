import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ixes.app/api_service/user_api_service.dart';
import 'package:ixes.app/constants/imageConstant.dart';
import 'package:ixes.app/screens/BottomNaviagation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import '../../providers/auth_provider.dart';

class _C {
  static const bg             = Color(0xFF0A0A0F);
  static const surface        = Color(0xFF13131A);
  static const surfaceHi      = Color(0xFF1C1C27);
  static const border         = Color(0xFF2A2A3A);
  static const accent         = Color(0xFF7C5CFC);
  static const accentSoft     = Color(0x1A7C5CFC);
  static const textPrimary    = Color(0xFFF0F0F5);
  static const textSecondary  = Color(0xFF8888A0);
  static const textMuted      = Color(0xFF55556A);
  static const success        = Color(0xFF4CAF82);
  static const error          = Color(0xFFE05C6E);
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey                   = GlobalKey<FormState>();
  final _mobileController          = TextEditingController();
  final _usernameController        = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword        = true;
  bool _obscureConfirmPassword = true;
  bool _isFamilyHead           = false;
  bool _agreement              = false;
  bool _isLoading              = false;

  late final AnimationController _fadeController;
  late final Animation<double>   _fadeAnimation;
  late final Animation<Offset>   _slideAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation  = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: isError ? _C.error : _C.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreement) {
      _showSnack('Please agree to the terms and conditions', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final Map<String, dynamic> params = {
      'mobile'      : '+91${_mobileController.text.trim()}',
      'username'    : _usernameController.text.trim(),
      'password'    : _passwordController.text,
      'isFamilyHead': _isFamilyHead,
      'agreement'   : _agreement,
    };

    final response = await UserAPI().SignUpApi(context, params);
    setState(() => _isLoading = false);

    if (response['statusCode'] == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', response['token']);
      await prefs.setString('user_id', response['id']);
      await prefs.setString('username', response['username']);
      await prefs.setBool('guid', response['guid'] ?? false);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 0)),
        );
      }
    } else {
      _showSnack(response['message'] ?? 'Sign up failed. Try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 2.h),

                    // ── Top row: [←]  [Logo] ─────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _C.surfaceHi,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: _C.border),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: _C.textPrimary,
                              size: 15,
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),


                      ],
                    ),

                    SizedBox(height: 3.5.h),

                    // ── Heading ──────────────────────────────────────
                    Center(
                      child: const Text(
                        'Create account',
                        style: TextStyle(
                          color: _C.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Join iXES and connect with your community',
                      style: TextStyle(
                        color: _C.textSecondary,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),

                    SizedBox(height: 3.h),

                    // ── Form card ────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _C.border),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildLabel('Mobile Number'),
                            const SizedBox(height: 8),
                            _buildMobileField(),
                            const SizedBox(height: 16),

                            _buildLabel('Username'),
                            const SizedBox(height: 8),
                            _buildInputField(
                              controller: _usernameController,
                              hint: 'e.g. john_doe',
                              icon: Icons.person_outline_rounded,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Enter a username';
                                if (v.length < 3) return 'At least 3 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            _buildLabel('Password'),
                            const SizedBox(height: 8),
                            _buildPasswordField(
                              controller: _passwordController,
                              hint: 'Min. 6 characters',
                              obscure: _obscurePassword,
                              onToggle: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Enter a password';
                                if (v.length < 6) return 'At least 6 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            _buildLabel('Confirm Password'),
                            const SizedBox(height: 8),
                            _buildPasswordField(
                              controller: _confirmPasswordController,
                              hint: 'Re-enter your password',
                              obscure: _obscureConfirmPassword,
                              onToggle: () => setState(() =>
                              _obscureConfirmPassword = !_obscureConfirmPassword),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Confirm your password';
                                if (v != _passwordController.text)
                                  return 'Passwords do not match';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            _buildToggleTile(
                              title: 'Terms & Conditions',
                              subtitle: 'I agree to the terms and conditions',
                              icon: Icons.verified_user_outlined,
                              value: _agreement,
                              onChanged: (v) =>
                                  setState(() => _agreement = v ?? false),
                              accentOverride: const Color(0xFF4CAF82),
                            ),
                            const SizedBox(height: 24),

                            _SignupButton(
                              isLoading: _isLoading,
                              onPressed: _handleSignUp,
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 2.5.h),

                    // ── Already have account ─────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account?  ',
                          style: TextStyle(color: _C.textSecondary, fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: _C.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 3.h),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: _C.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
    ),
  );

  Widget _buildMobileField() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surfaceHi,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: _C.border)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🇮🇳', style: TextStyle(fontSize: 18)),
                SizedBox(width: 6),
                Text('+91',
                    style: TextStyle(
                        color: _C.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: const TextStyle(color: _C.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Enter mobile number',
                hintStyle: TextStyle(color: _C.textMuted, fontSize: 14),
                border: InputBorder.none,
                contentPadding:
                EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter mobile number';
                if (v.length < 10) return 'Enter a valid 10-digit number';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surfaceHi,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        style: const TextStyle(color: _C.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _C.textMuted, fontSize: 14),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          prefixIcon: icon != null
              ? Icon(icon, color: _C.textMuted, size: 18)
              : null,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surfaceHi,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: _C.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _C.textMuted, fontSize: 14),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              color: _C.textMuted, size: 18),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: _C.textMuted,
              size: 18,
            ),
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required void Function(bool?) onChanged,
    Color? accentOverride,
  }) {
    final color = accentOverride ?? _C.accent;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: value ? color.withOpacity(0.08) : _C.surfaceHi,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: value ? color.withOpacity(0.35) : _C.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: value ? color.withOpacity(0.15) : _C.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
              Icon(icon, color: value ? color : _C.textMuted, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        color: value ? _C.textPrimary : _C.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      )),
                  Text(subtitle,
                      style: const TextStyle(
                          color: _C.textMuted, fontSize: 11)),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: color,
                inactiveThumbColor: _C.textMuted,
                inactiveTrackColor: _C.surface,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SignupButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _SignupButton({required this.isLoading, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _C.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13)),
          disabledBackgroundColor: _C.accent.withOpacity(0.45),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
        )
            : const Text(
          'Create Account',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}