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
      final response = await ApiService.put('/api/auth/password', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }, requireAuth: true);

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Password changed successfully',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'message': data['error'] ?? 'New password is required',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': data['error'] ?? 'Current password is incorrect',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'message': data['error'] ?? 'User not found',
        };
      } else if (response.statusCode == 500) {
        return {
          'success': false,
          'message': data['error'] ?? 'An error occurred',
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to change password',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
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