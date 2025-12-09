import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/user_model.dart';
import 'package:url_launcher/url_launcher.dart';


class AuthService {
  static Future<Map<String, dynamic>> signup({
    required String mobile,
    required String username,
    required String password,
    required bool isFamilyHead,
    required bool agreement,
  }) async {
    try {
      final response = await ApiService.post('/api/auth/signup', {
        'mobile': mobile,
        'username': username,
        'password': password,
        'isFamilyHead': isFamilyHead,
        'agreement': agreement,
      }, requireAuth: false);
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': User.fromJson(data),
          'message': 'Signup successful',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Signup failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  static Future<Map<String, dynamic>> login({
    required String mobile,
    String? password,
  }) async {
    try {
      final body = {'mobile': mobile};
      if (password != null) {
        body['password'] = password;
      }
      
      final response = await ApiService.post('/api/auth/login', body, requireAuth: false);
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': User.fromJson(data),
          'message': 'Login successful',
        };
      } else if (response.statusCode == 201) {
        return {
          'success': true,
          'otpRequired': true,
          'message': 'OTP sent successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  static Future<Map<String, dynamic>> loginWithOTP({
    required String mobile,
    required String otp,
  }) async {
    try {
      final Uri url = Uri.parse("https://api.ixes.ai/api/auth/loginWithOTP");

      final Map<String, dynamic> body = {
        'mobile': mobile,
        'otp': otp,
      };

      print("📤 Login Request URL: $url");
      print("📤 Login BODY: $body");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      print("📥 Status Code: ${response.statusCode}");
      print("📥 Response Body: ${response.body}");

      // Parse the response
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['token'] != null) {
        final token = data['token'];
        final userId = data['id'];
        final username = data['username'];
        final guid = data['guid'];

        // ✅ Save token & user info in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('user_id', userId ?? '');
        await prefs.setString('username', username ?? '');
        await prefs.setBool('guid', guid ?? false);

        // 🧠 Verify token saved
        final savedToken = prefs.getString('auth_token');
        print("✅ Token saved successfully: $savedToken");

        return {
          'success': true,
          'message': data['message'] ?? 'Login successful',
          'token': token,
          'user_id': userId,
          'username': username,
          'guid': guid,
        };
      } else {
        print("❌ Login failed: ${data['message']}");
        return {
          'success': false,
          'message': data['message'] ?? 'OTP verification failed',
        };
      }
    } catch (e) {
      print("❌ Login Error: $e");
      return {
        'success': false,
        'message': 'Error during login: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> sendOTP(String mobile) async {
    try {
      final response = await ApiService.post('/api/auth/sendOTP', {
        'mobile': mobile,
      }, requireAuth: false);
print(response);
      final data = json.decode(response.body);
    print(data);
      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': 'OTP sent successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
 // AUTH SERVICE METHOD
static Future<Map<String, dynamic>> forgotPassword({
  required String mobile,
  required String email,
}) async {
  try {
    final response = await ApiService.post('/api/forgot-password', {
      'mobile': mobile,
      'email': email,
    }, requireAuth: false);
    
    print('API Response: ${response.body}');
    final data = json.decode(response.body);
    print('Parsed Data: $data');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return {
        'success': true,
        'message': data['message'] ?? 'OTP sent successfully',
        'data': data,
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? data['error'] ?? 'Failed to send OTP',
      };
    }
  } catch (e) {
    print('Network error: ${e.toString()}');
    return {
      'success': false,
      'message': 'Network error: ${e.toString()}',
    };
  }
}
  
  static Future<Map<String, dynamic>> checkMobileExists(String mobile) async {
    try {
      final response = await ApiService.get('/api/auth/utils/checkUserExists/$mobile', requireAuth: false);
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'available': true,
          'message': 'Mobile number is available',
        };
      } else if (response.statusCode == 409) {
        return {
          'success': true,
          'available': false,
          'message': 'Mobile number already registered',
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to check mobile',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }



  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      print('🔐 =================================');
      print('🔐 CHANGE PASSWORD - REQUEST STARTED');
      print('🔐 =================================');
      print('📤 Endpoint: /api/auth/password');
      print('📤 Method: PUT');
      print('📤 Current Password: ****${currentPassword.substring(currentPassword.length - 2)}');
      print('📤 Current Password Length: ${currentPassword.length}');
      print('📤 New Password Length: ${newPassword.length}');
      print('📤 Auth Required: true');

      // Get token to verify it exists
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getString('user_id');
      final username = prefs.getString('user_name');

      print('🔑 Token exists: ${token != null}');
      print('🔑 Token length: ${token?.length ?? 0}');
      print('🔑 User ID: ${userId ?? 'null'}');
      print('🔑 Username: ${username ?? 'null'}');

      if (token != null && token.length > 20) {
        print('🔑 Token preview: ${token.substring(0, 20)}...');
      } else if (token != null) {
        print('🔑 Token: $token');
      }

      final requestBody = {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      };
      print('📤 Request Body Keys: ${requestBody.keys.toList()}');

      final response = await ApiService.put(
          '/api/auth/password',
          requestBody,
          requireAuth: true
      );

      print('📥 Response Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');
      print('📥 Response Headers: ${response.headers}');

      final data = json.decode(response.body);
      print('📥 Decoded Data: $data');
      print('📥 Data Type: ${data.runtimeType}');
      print('📥 Has "error" key: ${data.containsKey('error')}');
      print('📥 Has "message" key: ${data.containsKey('message')}');

      if (response.statusCode == 200) {
        print('✅ SUCCESS - Password changed successfully');
        print('✅ Message: ${data['message']}');
        return {
          'success': true,
          'message': data['message'] ?? 'Password changed successfully',
        };
      }
      else if (response.statusCode == 400) {
        print('❌ ERROR 400 - Bad Request');
        print('❌ Reason: New password is required or invalid');
        final errorMsg = data['error'] ?? data['message'] ?? 'New password is required';
        print('❌ Error Message: $errorMsg');
        return {
          'success': false,
          'message': errorMsg,
        };
      }
      else if (response.statusCode == 401) {
        print('❌ ERROR 401 - Unauthorized');
        print('❌ Reason: Current password is incorrect or invalid token');
        final errorMsg = data['error'] ?? data['message'] ?? 'Current password is incorrect';
        print('❌ Error Message: $errorMsg');
        return {
          'success': false,
          'message': errorMsg,
        };
      }
      else if (response.statusCode == 404) {
        print('❌ ERROR 404 - Not Found');
        print('❌ Reason: User not found in database');
        final errorMsg = data['error'] ?? data['message'] ?? 'User not found';
        print('❌ Error Message: $errorMsg');
        return {
          'success': false,
          'message': errorMsg,
        };
      }
      else if (response.statusCode == 500) {
        print('❌ ERROR 500 - Internal Server Error');
        print('❌ Reason: Backend server error');
        print('❌ Error Field: ${data['error']}');
        print('❌ Message Field: ${data['message']}');
        print('❌ Full Response: $data');
        print('⚠️  BACKEND ISSUE: Check server logs for the actual error');
        print('⚠️  Possible causes:');
        print('   - Database connection failure');
        print('   - Password hashing error');
        print('   - User lookup error');
        print('   - Backend code exception');

        final errorMsg = data['error'] ?? data['message'] ?? 'Server error occurred. Please try again later.';
        print('❌ Returning Error: $errorMsg');

        return {
          'success': false,
          'message': errorMsg,
        };
      }
      else {
        print('❌ ERROR ${response.statusCode} - Unexpected Status Code');
        print('❌ Error Field: ${data['error']}');
        print('❌ Message Field: ${data['message']}');
        final errorMsg = data['error'] ?? data['message'] ?? 'Failed to change password';
        print('❌ Error Message: $errorMsg');
        return {
          'success': false,
          'message': errorMsg,
        };
      }
    } catch (e, stackTrace) {
      print('💥 =================================');
      print('💥 CHANGE PASSWORD - EXCEPTION CAUGHT');
      print('💥 =================================');
      print('💥 Error Type: ${e.runtimeType}');
      print('💥 Error Message: $e');
      print('💥 Stack Trace:');
      print(stackTrace);
      print('💥 Possible causes:');
      print('   - Network connection lost');
      print('   - Invalid JSON response');
      print('   - Timeout');
      print('   - API service error');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    } finally {
      print('🔐 =================================');
      print('🔐 CHANGE PASSWORD - REQUEST ENDED');
      print('🔐 =================================\n');
    }
  }

  
  static Future<bool> logout() async {
    try {
      await ApiService.post('/api/auth/logout', {});
      return true;
    } catch (e) {
      return false;
    }
  }


}