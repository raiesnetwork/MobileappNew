import 'package:flutter/material.dart';
import 'package:ixes.app/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class _C {
  static const bg            = Color(0xFFF8F9FB);
  static const surface       = Color(0xFFFFFFFF);
  static const surfaceHi     = Color(0xFFF5F7FC);
  static const border        = Color(0xFFE8EBEE);
  static const accent        = Color(0xFF7C5CFC);
  static const textPrimary   = Color(0xFF1A1F36);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted     = Color(0xFF9CA3AF);
  static const success       = Color(0xFF10B981);
  static const error         = Color(0xFFEF4444);
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({Key? key}) : super(key: key);

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      print('🔐 Attempting to change password...');

      final success = await authProvider.changePassword(
        currentPassword: _currentPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Password changed successfully!',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: _C.success,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
            elevation: 0,
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    authProvider.errorMessage.isNotEmpty
                        ? authProvider.errorMessage
                        : 'Failed to change password',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: _C.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
            elevation: 0,
          ),
        );
      }
    }
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your current password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a new password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    if (value == _currentPasswordController.text) {
      return 'New password must be different from current password';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your new password';
    }
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        foregroundColor: _C.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Change Password',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: _C.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: _C.border,
            height: 1,
          ),
        ),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical:5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Center(
                  child: Column(
                    children: [
                      // Container(
                      //   width: 70,
                      //   height: 70,
                      //   decoration: BoxDecoration(
                      //     shape: BoxShape.circle,
                      //     gradient: LinearGradient(
                      //       begin: Alignment.topLeft,
                      //       end: Alignment.bottomRight,
                      //       colors: [
                      //         _C.accent.withOpacity(0.15),
                      //         _C.accent.withOpacity(0.08),
                      //       ],
                      //     ),
                      //     // border: Border.all(
                      //     //   color: _C.accent.withOpacity(0.25),
                      //     //   width: 1.5,
                      //     // ),
                      //   ),
                      //   // child: const Center(
                      //   //   child: Icon(
                      //   //     Icons.lock_reset_rounded,
                      //   //     size: 36,
                      //   //     color: _C.accent,
                      //   //   ),
                      //   // ),
                      // ),
                      const SizedBox(height: 24),
                      const Text(
                        'Secure Your Account',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: _C.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Update your password to keep your account safe and secure',
                        style: TextStyle(
                          fontSize: 14,
                          color: _C.textSecondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Form Card
                Container(
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _C.border, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current Password Field
                        _buildLabel('Current Password'),
                        const SizedBox(height: 10),
                        _buildPasswordField(
                          controller: _currentPasswordController,
                          hintText: 'Enter current password',
                          obscure: _obscureCurrentPassword,
                          onToggleObscure: () {
                            setState(() => _obscureCurrentPassword = !_obscureCurrentPassword);
                          },
                          validator: _validateCurrentPassword,
                          enabled: !authProvider.isLoading,
                        ),

                        const SizedBox(height: 24),

                        // New Password Field
                        _buildLabel('New Password'),
                        const SizedBox(height: 10),
                        _buildPasswordField(
                          controller: _newPasswordController,
                          hintText: 'Create a new password',
                          obscure: _obscureNewPassword,
                          onToggleObscure: () {
                            setState(() => _obscureNewPassword = !_obscureNewPassword);
                          },
                          validator: _validateNewPassword,
                          enabled: !authProvider.isLoading,
                        ),

                        const SizedBox(height: 24),

                        // Confirm Password Field
                        _buildLabel('Confirm Password'),
                        const SizedBox(height: 10),
                        _buildPasswordField(
                          controller: _confirmPasswordController,
                          hintText: 'Re-enter your new password',
                          obscure: _obscureConfirmPassword,
                          onToggleObscure: () {
                            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                          },
                          validator: _validateConfirmPassword,
                          enabled: !authProvider.isLoading,
                        ),

                        const SizedBox(height: 32),

                        // Info Box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _C.accent.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _C.accent.withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: _C.accent,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Use at least 6 characters'
                                      '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _C.textSecondary,
                                    height: 1.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Change Password Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: authProvider.isLoading ? null : _changePassword,

                            style: ElevatedButton.styleFrom(
                              backgroundColor: _C.accent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _C.accent.withOpacity(0.5),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              shadowColor: _C.accent.withOpacity(0.3),
                            ),
                            child: authProvider.isLoading
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                                : const Text(
                              'Update Password',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Cancel Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: authProvider.isLoading ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: _C.border, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              foregroundColor: _C.textSecondary,
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                                color: _C.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _C.textPrimary,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required String? Function(String?) validator,
    required bool enabled,
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
        enabled: enabled,
        validator: validator,
        style: const TextStyle(
          color: _C.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: _C.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            color: _C.textMuted,
            size: 20,
          ),
          suffixIcon: GestureDetector(
            onTap: enabled ? onToggleObscure : null,
            child: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _C.textMuted,
              size: 20,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}