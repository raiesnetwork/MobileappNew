import 'package:flutter/material.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:ixes.app/constants/imageConstant.dart';
import 'package:ixes.app/screens/auth/otp_screen.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import '../../providers/auth_provider.dart';
// import 'otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inputController = TextEditingController();
  bool _isLoading = false;
  String _selectedType = 'Email'; // Default selection

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _sendResetOTP() async {
    if (!_formKey.currentState!.validate()) return;

    final input = _inputController.text.trim();
    
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your ${_selectedType.toLowerCase()}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Prepare parameters based on selected type
    String mobileParam = '';
    String emailParam = '';
    
    if (_selectedType == 'Mobile') {
      mobileParam = '+91$input';
    } else {
      emailParam = input;
    }

    print('ForgotPasswordScreen: Sending reset OTP - Type: $_selectedType, Mobile: $mobileParam, Email: $emailParam');

    // Call your forgot password method in AuthProvider
    final success = await authProvider.sendForgotPasswordOTP(
      email: emailParam,
      mobile: mobileParam,
    );

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (success) {
      print('ForgotPasswordScreen: Reset OTP sent successfully');
      final message = _selectedType == 'Mobile' 
        ? 'Password reset OTP sent to $mobileParam'
        : 'Password reset OTP sent to $emailParam';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
      // Navigator.of(context).push(
      //   MaterialPageRoute(
      //     builder: (context) => OTPScreen(
      //       mobile: mobileParam.isEmpty ? null : mobileParam,
      //       email: emailParam.isEmpty ? null : emailParam,
      //       isPasswordReset: true,
      //     ),
      //   ),
      // );
    } else {
      print('ForgotPasswordScreen: Reset OTP sending failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    
      body: Container(
        decoration: const BoxDecoration(
                      gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
               colors: [
              Color.fromARGB(165, 55, 0, 255),
              Color.fromARGB(70, 179, 154, 219)
            ],    ),
                    ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back button
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
             
                
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(22),
                ),
                child:  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Title
                          const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          // Subtitle
                          Text(
                            'Select your preferred method and we\'ll send you an OTP to reset your password.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          // Selection Toggle
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                
                            width: 2,    
                                
                                
                                color: Colors.black ),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedType = 'Email';
                                        _inputController.clear();
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _selectedType == 'Email' 
                                          ? const Color(0xFF2196F3) 
                                          : Colors.transparent,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(8),
                                          bottomLeft: Radius.circular(8),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.email,
                                            color: _selectedType == 'Email' 
                                              ? Colors.white 
                                              : Colors.grey[600],
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Email',
                                            style: TextStyle(
                                              color: _selectedType == 'Email' 
                                                ? Colors.white 
                                                : Colors.grey[600],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedType = 'Mobile';
                                        _inputController.clear();
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _selectedType == 'Mobile' 
                                          ? const Color(0xFF2196F3) 
                                          : Colors.transparent,
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(8),
                                          bottomRight: Radius.circular(8),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.phone,
                                            color: _selectedType == 'Mobile' 
                                              ? Colors.white 
                                              : Colors.grey[600],
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Mobile',
                                            style: TextStyle(
                                              color: _selectedType == 'Mobile' 
                                                ? Colors.white 
                                                : Colors.grey[600],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Input Field
                          TextFormField(
                            controller: _inputController,
                            keyboardType: _selectedType == 'Mobile' 
                              ? TextInputType.phone 
                              : TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: _selectedType == 'Mobile' 
                                ? 'Mobile Number' 
                                : 'Email Address',
                              prefixIcon: Icon(_selectedType == 'Mobile' 
                                ? Icons.phone 
                                : Icons.email),
                              prefixText: _selectedType == 'Mobile' ? '+91 ' : null,
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(8)),
                                borderSide: BorderSide(
                                  color: Colors.grey,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(8)),
                                borderSide: BorderSide(
                                  color: Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                              hintText: _selectedType == 'Mobile' 
                                ? 'Enter your mobile number' 
                                : 'Enter your email address',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your ${_selectedType.toLowerCase()}';
                              }
                              
                              if (_selectedType == 'Mobile') {
                                if (value.length != 10) {
                                  return 'Please enter a valid 10-digit mobile number';
                                }
                                if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                                  return 'Mobile number should contain only digits';
                                }
                              } else {
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(value)) {
                                  return 'Please enter a valid email address';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          // Info text
                          Text(
                            _selectedType == 'Mobile' 
                              ? 'We\'ll send an OTP to your mobile number' 
                              : 'We\'ll send an OTP to your email address',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          // Send OTP Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _sendResetOTP,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:  tPrimaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                              disabledBackgroundColor: Colors.grey[400],
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Send Reset OTP',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          // Back to Login Button
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Back to Login',
                              style: TextStyle(
                                color: Color(0xFF2196F3),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 30.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}