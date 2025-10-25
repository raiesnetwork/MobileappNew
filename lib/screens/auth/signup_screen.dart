import 'package:flutter/material.dart';
import 'package:ixes.app/api_service/user_api_service.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:ixes.app/globalwidget/button.dart';
import 'package:ixes.app/globla_function/globalFunctions.dart';
import 'package:ixes.app/responsive.dart';
import 'package:ixes.app/screens/home/feedpage/feed_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
// import '../../api_service/user_api_service.dart';
import '../../providers/auth_provider.dart';
import '../BottomNaviagation.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isFamilyHead = false;
  bool _agreement = false;

  @override
  void dispose() {
    _mobileController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading:  IconButton(onPressed: (){
          Navigator.pop(context);
        }, icon:  Icon(
      Icons.arrow_back_ios_new,
      color: Colors.white,
      size: 24.0,
    
    ),
    ),
        title: const Text('Sign Up',style: TextStyle(color: tWhite),),
        backgroundColor:  Color.fromARGB(165, 55, 0, 255),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
             
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
              padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              child:   Container(
              margin: EdgeInsets.only(bottom: 21.h),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(22),
              ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Create Account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                         TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                prefixIcon: Icon(Icons.phone),
                prefixText: '+91 ',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your mobile number';
                }
                if (value.length < 10) {
                  return 'Please enter a valid mobile number';
                }
                return null;
              },
            ),
            
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a username';
                              }
                              if (value.length < 3) {
                                return 'Username must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            title: const Text('I am a family head'),
                            value: _isFamilyHead,
                            onChanged: (value) {
                              setState(() {
                                _isFamilyHead = value ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          CheckboxListTile(
                            title:
                                const Text('I agree to the terms and conditions'),
                            value: _agreement,
                            onChanged: (value) {
                              setState(() {
                                _agreement = value ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          const SizedBox(height: 24),
                          Button(
                            height:5.5.h,
                            width: 60.w,
                            textcolor: tWhite,
                            bottonText: 'Sign Up',
                            onTap: (startLoading, stopLoading, btnState) async {
                              print("🟡 Button tapped");
                    
                              if (_formKey.currentState!.validate()) {
                                print("✅ Form validated");
                    
                                if (!_agreement) {
                                  print("❌ Terms not agreed");
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Please agree to the terms and conditions'),
                                    ),
                                  );
                                  return;
                                }
                    
                                print("🟢 Starting loading...");
                                startLoading();
                    
                                final Map<String, dynamic> params = {
                                  'mobile': '+91${_mobileController.text.trim()}',
                                  'username': _usernameController.text.trim(),
                                  'password': _passwordController.text,
                                  'isFamilyHead': _isFamilyHead,
                                  'agreement': _agreement,
                                };
                    
                                print(
                                    "📤 Sending SignUp API request with params: $params");
                    
                                final response =
                                    await UserAPI().SignUpApi(context, params);
                    
                                debugPrint("📥 SignUp API Response: $response");
                    
                                stopLoading();
                                print("🛑 Stopped loading");
                    
                                if (response['statusCode'] == 200) {
                                  print(
                                      "✅ API success, saving to SharedPreferences...");
                    
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setString(
                                      'auth_token', response['token']);
                                  await prefs.setString(
                                      'user_id', response['id']);
                                  await prefs.setString(
                                      'username', response['username']);
                                  await prefs.setBool(
                                      'guid', response['guid'] ?? false);
                    
                                  print("🚀 Navigating to FeedScreen...");
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MainScreen(initialIndex: 0),
                                    ),
                                  );
                                } else {
                                  final errorMessage = response['message'] ??
                                      'Sign up failed. Try again.';
                                  print("❌ API Error: $errorMessage");
                    
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(errorMessage)),
                                    );
                                  }
                                }
                              } else {
                                print("❌ Form validation failed");
                              }
                            },
                          )
                      
                      
                      
                          
                      
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
      
        
          ],
        ),
      ),
    );
  }
}
