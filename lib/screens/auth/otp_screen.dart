import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../providers/auth_provider.dart';
import '../../providers/comment_provider.dart';
import '../BottomNaviagation.dart';

// ── Design Tokens (mirrors login_screen.dart exactly) ─────────────────────────
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

class OTPScreen extends StatefulWidget {
  final String mobile;
  const OTPScreen({super.key, required this.mobile});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  String _currentOTP = '';

  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeController = controller;
    _fadeAnimation =
        CurvedAnimation(parent: controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));
    controller.forward();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _fadeController?.dispose();
    super.dispose();
  }

  Future<void> _verifyOTP() async {
    if (_currentOTP.length != 6) {
      _showSnack('Please enter a valid 6-digit OTP', isError: true);
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.loginWithOTP(
      mobile: widget.mobile,
      otp: _currentOTP,
    );

    if (!mounted) return;

    if (success) {
      final userId = authProvider.user?.id ?? '';
      if (userId.isNotEmpty) {
        Provider.of<CommentProvider>(context, listen: false)
            .setCurrentUserId(userId);
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => const MainScreen(initialIndex: 0)),
      );
    } else {
      _showSnack(authProvider.errorMessage, isError: true);
    }
  }

  Future<void> _resendOTP() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.sendOTP(widget.mobile);
    if (!mounted) return;
    _showSnack(
      success ? 'OTP resent successfully' : authProvider.errorMessage,
      isError: !success,
    );
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: isError ? _C.error : _C.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      // Keeps layout stable when keyboard appears
      resizeToAvoidBottomInset: true,
      body: SafeArea(
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
                    const SizedBox(height: 48),

                    // ── Back button ───────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _C.surfaceHi,
                            borderRadius: BorderRadius.circular(10),
                            border:
                            Border.all(color: _C.border, width: 1),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: _C.textSecondary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Icon ──────────────────────────────────────
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _C.surfaceHi,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _C.border, width: 1),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: _C.accent,
                        size: 28,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Heading ───────────────────────────────────
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Verify your number',
                        style: TextStyle(
                          color: _C.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              color: _C.textSecondary, fontSize: 14),
                          children: [
                            const TextSpan(text: 'Code sent to '),
                            TextSpan(
                              text: widget.mobile,
                              style: const TextStyle(
                                color: _C.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── OTP Card ──────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _C.border, width: 1),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Label
                          const Text(
                            'Enter 6-digit code',
                            style: TextStyle(
                              color: _C.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── PIN field ─────────────────────────
                          PinCodeTextField(
                            appContext: context,
                            length: 6,
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            animationType: AnimationType.fade,
                            animationDuration:
                            const Duration(milliseconds: 180),
                            pinTheme: PinTheme(
                              shape: PinCodeFieldShape.box,
                              borderRadius: BorderRadius.circular(10),
                              fieldHeight: 52,
                              fieldWidth: 44,
                              // Active (focused + filled)
                              activeFillColor: _C.surfaceHi,
                              activeColor: _C.accent,
                              // Inactive (unfocused + filled)
                              inactiveFillColor: _C.surfaceHi,
                              inactiveColor: _C.border,
                              // Selected (focused + empty)
                              selectedFillColor: _C.surfaceHi,
                              selectedColor: _C.accent,
                            ),
                            enableActiveFill: true,
                            cursorColor: _C.accent,
                            textStyle: const TextStyle(
                              color: _C.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                            onChanged: (value) {
                              setState(() => _currentOTP = value);
                            },
                            onCompleted: (_) => _verifyOTP(),
                          ),

                          const SizedBox(height: 24),

                          // ── Verify button ─────────────────────
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, _) {
                              return SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _C.accent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(12)),
                                    disabledBackgroundColor:
                                    _C.accent.withOpacity(0.5),
                                  ),
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : _verifyOTP,
                                  child: authProvider.isLoading
                                      ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                      : const Text(
                                    'Verify & Sign In',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // ── Divider ───────────────────────────
                          Row(
                            children: [
                              Expanded(
                                  child: Divider(
                                      color: _C.border, thickness: 1)),
                              const Padding(
                                padding:
                                EdgeInsets.symmetric(horizontal: 14),
                                child: Text('or',
                                    style: TextStyle(
                                      color: _C.textMuted,
                                      fontSize: 12,
                                    )),
                              ),
                              Expanded(
                                  child: Divider(
                                      color: _C.border, thickness: 1)),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ── Resend button ─────────────────────
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, _) {
                              return SizedBox(
                                height: 50,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: _C.surfaceHi,
                                    foregroundColor: _C.textPrimary,
                                    side: const BorderSide(
                                        color: _C.border, width: 1),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : _resendOTP,
                                  child: const Text(
                                    'Resend code',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _C.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Footer hint ───────────────────────────────
                    const Text(
                      'Didn\'t get the code? Check your spam or try resend.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _C.textMuted,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}