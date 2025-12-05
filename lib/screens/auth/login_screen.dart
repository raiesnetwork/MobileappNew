import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ixes.app/constants/imageConstant.dart';
import 'package:ixes.app/globalwidget/global_textfild.dart';
import 'package:ixes.app/screens/BottomNaviagation.dart';
import 'package:ixes.app/screens/compoants.dart/forgetpassword.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:country_picker/country_picker.dart';
import '../../providers/auth_provider.dart';
import '../../services/google_auth_service.dart';
import 'signup_screen.dart';
import 'otp_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isPasswordLogin = true;

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
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Get the expected phone number length for the selected country
  int _getPhoneNumberLength() {
    // Common phone number lengths by country code
    final lengthMap = {
      '1': 10,   // US, Canada
      '44': 10,  // UK
      '91': 10,  // India
      '86': 11,  // China
      '81': 10,  // Japan
      '49': 11,  // Germany
      '33': 9,   // France
      '39': 10,  // Italy
      '34': 9,   // Spain
      '61': 9,   // Australia
      '7': 10,   // Russia
      '55': 11,  // Brazil
      '52': 10,  // Mexico
      '27': 9,   // South Africa
      '82': 10,  // South Korea
      '971': 9,  // UAE
      '966': 9,  // Saudi Arabia
      '65': 8,   // Singapore
      '60': 10,  // Malaysia
      '62': 11,  // Indonesia
      '63': 10,  // Philippines
      '84': 9,   // Vietnam
      '66': 9,   // Thailand
      '92': 10,  // Pakistan
      '880': 10, // Bangladesh
    };

    return lengthMap[_selectedCountry.phoneCode] ?? 10; // Default to 10
  }

  // Get minimum acceptable length (usually 1-2 digits less)
  int _getMinPhoneNumberLength() {
    return _getPhoneNumberLength() - 2;
  }

  void _handleForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ForgotPasswordScreen(),
      ),
    );
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final mobile =
        '+${_selectedCountry.phoneCode}${_mobileController.text.trim()}';

    print('LoginScreen: Sending OTP to: $mobile');

    final success = await authProvider.sendOTP(mobile);

    if (!mounted) return;

    if (success) {
      print('LoginScreen: OTP sent successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP sent successfully to $mobile'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OTPScreen(mobile: mobile),
        ),
      );
    } else {
      print('LoginScreen: OTP sending failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage),
          backgroundColor: Colors.red,
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

    print('Logging in with password for: $mobile');

    final result = await authProvider.login(
      mobile: mobile,
      password: password,
    );

    if (!mounted) return;

    if (result['success']) {
      print('Login successful');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainScreen(initialIndex: 0),
        ),
      );
    } else {
      print('Login failed: ${result['message']}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // ← IMPORTANT: Allow screen to resize
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(165, 55, 0, 255),
              Color.fromARGB(70, 179, 154, 219)
            ],
          ),
        ),
        child: SingleChildScrollView( // ← WRAP EVERYTHING IN SCROLLVIEW
          physics: const ClampingScrollPhysics(), // Smooth iOS/Android feel
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom, // Push up above keyboard
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo Section
                SizedBox(height: 8.h), // Add some top padding
                Container(
                  alignment: Alignment.center,
                  child: Image.asset(
                    Images.LogoTrans,
                    height: 24.h,
                  ),
                ),
                SizedBox(height: 4.h),

                // Form Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // === ALL YOUR EXISTING FIELDS (UNCHANGED) ===
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
                                    backgroundColor: Colors.black,
                                    textStyle: const TextStyle(color: Colors.white),
                                    searchTextStyle: const TextStyle(color: Colors.white),
                                    bottomSheetHeight: 500,
                                    inputDecoration: const InputDecoration(
                                      hintText: 'Search country...',
                                      hintStyle: TextStyle(color: Colors.white70),
                                      prefixIcon: Icon(Icons.search, color: Colors.white70),
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(color: Colors.white),
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
                              child: Container(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedCountry.flagEmoji,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+${_selectedCountry.phoneCode}',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your mobile number';
                              }
                              final minLength = _getMinPhoneNumberLength();
                              final expectedLength = _getPhoneNumberLength();

                              if (value.length < minLength) {
                                return 'Number too short for ${_selectedCountry.name}';
                              }
                              if (value.length > expectedLength + 2) {
                                return 'Number too long for ${_selectedCountry.name}';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 11),
                          // ... rest of your fields (ChoiceChip, password, buttons, etc.)
                          // KEEP EVERYTHING EXACTLY THE SAME BELOW
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Text('Password'),
                                  selected: _isPasswordLogin,
                                  selectedColor: const Color.fromARGB(187, 119, 0, 255),
                                  backgroundColor: Colors.white.withOpacity(0.8),
                                  labelStyle: TextStyle(
                                    color: _isPasswordLogin ? Colors.white : Colors.black,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide.none,
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      _isPasswordLogin = true;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Text('OTP'),
                                  selected: !_isPasswordLogin,
                                  selectedColor: const Color.fromARGB(187, 119, 0, 255),
                                  backgroundColor: Colors.white.withOpacity(0.8),
                                  labelStyle: TextStyle(
                                    color: !_isPasswordLogin ? Colors.white : Colors.black,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide.none,
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      _isPasswordLogin = false;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_isPasswordLogin) ...[
                            CustomTextField(
                              controller: _passwordController,
                              labelText: 'Password',
                              obscureText: _obscurePassword,
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
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
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: 4.h),
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              return Padding(
                                padding: EdgeInsets.symmetric(horizontal: 50),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color.fromARGB(187, 119, 0, 255),
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : (_isPasswordLogin ? _handlePasswordLogin : _sendOTP),
                                  child: authProvider.isLoading
                                      ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                      : Text(
                                    _isPasswordLogin ? 'Login' : 'Send OTP',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 50),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Colors.grey),
                                ),
                              ),
                              icon: const Icon(
                                Icons.g_mobiledata,
                                size: 32,
                                color: Color(0xFF4285F4),
                              ),
                              label: const Text(
                                'Sign in with Google',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              onPressed: () async {
                                await handleGoogleSignIn();
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => SignupScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Don\'t have an account? Sign Up',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 4.h), // Extra bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '71249839379-7seogt3fsiuki5ngl7bplqudb1ib9une.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  Future<void> handleGoogleSignIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        print('✅ Signed in: ${account.displayName} (${account.email})');
        // Handle successful sign-in here
        // You can navigate to the main screen or call your backend API
      } else {
        print('⚠️ User canceled sign-in.');
      }
    } catch (error) {
      print('❌ Sign-In Error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}