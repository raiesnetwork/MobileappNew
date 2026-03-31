import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ixes.app/constants/imageConstant.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import '../../providers/auth_provider.dart';

class _C {
  static const bg             = Color(0xFF0A0A0F);
  static const surface        = Color(0xFF13131A);
  static const surfaceHi      = Color(0xFF1C1C27);
  static const border         = Color(0xFF2A2A3A);
  static const accent         = Color(0xFF7C5CFC);
  static const textPrimary    = Color(0xFFF0F0F5);
  static const textSecondary  = Color(0xFF8888A0);
  static const textMuted      = Color(0xFF55556A);
  static const success        = Color(0xFF4CAF82);
  static const error          = Color(0xFFE05C6E);
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey        = GlobalKey<FormState>();
  final _inputController = TextEditingController();
  bool _isLoading       = false;
  String _selectedType  = 'Email';

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
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _inputController.dispose();
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

  Future<void> _sendResetOTP() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String mobileParam = '';
    String emailParam  = '';

    if (_selectedType == 'Mobile') {
      mobileParam = '+91${_inputController.text.trim()}';
    } else {
      emailParam = _inputController.text.trim();
    }

    final success = await authProvider.sendForgotPasswordOTP(
      email: emailParam,
      mobile: mobileParam,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (success) {
      _showSnack(
        _selectedType == 'Mobile'
            ? 'OTP sent to $mobileParam'
            : 'OTP sent to $emailParam',
        isError: false,
      );
    } else {
      _showSnack(authProvider.errorMessage, isError: true);
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 2.h),

                    // ── Top bar: back button ─────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _BackButton(onTap: () => Navigator.pop(context)),
                    ),

                    SizedBox(height: 4.h),

                    // ── Logo centred ─────────────────────────────────
                    Center(
                      child: Hero(
                        tag: 'app_logo',
                        child: Image.asset(Images.LogoTrans, height: 9.h),
                      ),
                    ),

                    SizedBox(height: 4.h),

                    // ── Page heading ─────────────────────────────────
                    Center(
                      child: const Text(
                        'Forgot Password?',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: _C.textPrimary,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: const Text(
                        "Enter your email or mobile number below and\nwe'll send you a one-time reset code.",
                        style: TextStyle(
                          color: _C.textSecondary,
                          fontSize: 13.5,
                          height: 1.55,
                        ),
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
                            // Section label
                            const _FieldLabel('Reset via'),
                            const SizedBox(height: 8),

                            // Toggle
                            _MethodToggle(
                              selected: _selectedType,
                              onChanged: (type) => setState(() {
                                _selectedType = type;
                                _inputController.clear();
                              }),
                            ),

                            const SizedBox(height: 24),

                            // Input label
                            _FieldLabel(
                              _selectedType == 'Email'
                                  ? 'Email Address'
                                  : 'Mobile Number',
                            ),
                            const SizedBox(height: 8),

                            // Input field
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: _selectedType == 'Email'
                                  ? _buildEmailField()
                                  : _buildMobileField(),
                            ),

                            const SizedBox(height: 10),

                            // Hint row
                            Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 12,
                                  color: _C.textMuted,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _selectedType == 'Mobile'
                                      ? 'OTP will be sent to your mobile number'
                                      : 'OTP will be sent to your email address',
                                  style: const TextStyle(
                                    color: _C.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 28),

                            // Send OTP button
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _sendResetOTP,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _C.accent,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                  _C.accent.withOpacity(0.45),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Text(
                                  'Send Reset OTP',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 3.h),

                    // ── Back to sign in ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Remember your password?  ',
                          style: TextStyle(
                              color: _C.textSecondary, fontSize: 13),
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

  Widget _buildEmailField() {
    return Container(
      key: const ValueKey('email'),
      decoration: BoxDecoration(
        color: _C.surfaceHi,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: TextFormField(
        controller: _inputController,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        style: const TextStyle(color: _C.textPrimary, fontSize: 15),
        decoration: const InputDecoration(
          hintText: 'you@example.com',
          hintStyle: TextStyle(color: _C.textMuted, fontSize: 14),
          border: InputBorder.none,
          contentPadding:
          EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          prefixIcon: Icon(Icons.email_outlined,
              color: _C.textMuted, size: 18),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Enter your email address';
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v))
            return 'Enter a valid email address';
          return null;
        },
      ),
    );
  }

  Widget _buildMobileField() {
    return Container(
      key: const ValueKey('mobile'),
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
                Text(
                  '+91',
                  style: TextStyle(
                    color: _C.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _inputController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: const TextStyle(color: _C.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                hintText: '9876543210',
                hintStyle: TextStyle(color: _C.textMuted, fontSize: 14),
                border: InputBorder.none,
                contentPadding:
                EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your mobile number';
                if (v.length != 10) return 'Enter a valid 10-digit number';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _C.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _MethodToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _MethodToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _C.surfaceHi,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          _tab('Email',  Icons.email_outlined,  selected == 'Email'),
          _tab('Mobile', Icons.phone_outlined,   selected == 'Mobile'),
        ],
      ),
    );
  }

  Widget _tab(String label, IconData icon, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? _C.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: isSelected ? Colors.white : _C.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : _C.textSecondary,
                  fontSize: 13,
                  fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}