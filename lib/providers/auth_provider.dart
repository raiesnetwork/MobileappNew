import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import 'communities_provider.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isInitialized = false; // Add initialization state

  User? get user => _user;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized; // Getter for initialization state

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
  Future<void> saveUserFromGoogle({
    required String token,
    required String userId,
    required String username,
    Map<String, dynamic>? userData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ If userId is empty, decode it from the JWT token directly
      String resolvedId = userId;
      String resolvedUsername = username;

      if (resolvedId.isEmpty && token.isNotEmpty) {
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            String payload = parts[1];
            while (payload.length % 4 != 0) {
              payload += '=';
            }
            final decoded = utf8.decode(base64Url.decode(payload));
            final Map<String, dynamic> payloadMap = jsonDecode(decoded);
            final userMap = payloadMap['user'] as Map<String, dynamic>?;
            resolvedId = userMap?['id']?.toString() ?? '';
            resolvedUsername = userMap?['username']?.toString() ?? resolvedUsername;
            print('✅ Decoded from JWT → id=$resolvedId | username=$resolvedUsername');
          }
        } catch (e) {
          print('❌ JWT decode error: $e');
        }
      }

      await prefs.setString('auth_token', token);
      await prefs.setString('user_id', resolvedId);
      await prefs.setString('user_name', resolvedUsername);

      // ✅ Spread userData first, then override with resolved values
      final Map<String, dynamic> userMap = {
        ...?userData,
        'id': resolvedId,        // ✅ Always wins — not overwritten
        'username': resolvedUsername,
        'token': token,
        'mobile': '',
        'isFamilyHead': false,
        'guidStatus': userData?['guid'] ?? false,
      };
      await prefs.setString('user_data', jsonEncode(userMap));

      _user = User(
        id: resolvedId,
        username: resolvedUsername,
        mobile: '',
        isFamilyHead: false,
        guidStatus: userData?['guid'] ?? false,
        token: token,
      );

      print('✅ Google user saved → id=$resolvedId | username=$resolvedUsername');
      notifyListeners();
    } catch (e) {
      print('❌ Error saving Google user data: $e');
    }
  }

  Future<bool> signup({
    required String mobile,
    required String username,
    required String password,
    required bool isFamilyHead,
    required bool agreement,
  }) async {
    _setLoading(true);
    _setError('');

    final result = await AuthService.signup(
      mobile: mobile,
      username: username,
      password: password,
      isFamilyHead: isFamilyHead,
      agreement: agreement,
    );

    if (result['success']) {
      print('✅ SIGNUP SUCCESS - API Response:');
      print(result);
      _user = result['user'];
      await _saveUserData(_user!);
      _setLoading(false);
      return true;
    } else {
      _setError(result['message']);
      _setLoading(false);
      return false;
    }
  }

  Future<Map<String, dynamic>> login({
    required String mobile,
    String? password,
  }) async {
    _setLoading(true);
    _setError('');

    final result = await AuthService.login(
      mobile: mobile,
      password: password,
    );

    if (result['success']) {
      print('✅ LOGIN SUCCESS - API Response:');
      print(result);
      
      if (result['otpRequired'] == true) {
        _setLoading(false);
        return {
          'success': true,
          'otpRequired': true,
          'message': result['message'],
        };
      } else {
        _user = result['user'];
        await _saveUserData(_user!);
        _setLoading(false);
        return {
          'success': true,
          'otpRequired': false,
          'message': result['message'],
        };
      }
    } else {
      _setError(result['message']);
      _setLoading(false);
      return {
        'success': false,
        'message': result['message'],
      };
    }
  }

  Future<bool> loginWithOTP({
    required String mobile,
    required String otp,
  }) async {
    _setLoading(true);
    _setError('');

    final result = await AuthService.loginWithOTP(mobile: mobile, otp: otp);

    final success = result['success'] == true;
    if (success) {
      // Build User object from the response and save it
      _user = User(
        id: result['user_id'] ?? '',
        username: result['username'] ?? '',
        mobile: mobile,
        isFamilyHead: false,
        guidStatus: result['guid'] ?? false,
        token: result['token'],
      );
      await _saveUserData(_user!);   // persists to SharedPreferences

      await FcmService.saveFcmToken();
      FcmService.listenForTokenRefresh();
    } else {
      _setError(result['message'] ?? 'OTP verification failed');
    }

    _setLoading(false);
    return success;
  }


  Future<bool> sendOTP(String mobile) async {
    _setLoading(true);
    _setError('');

    final result = await AuthService.sendOTP(mobile);

    if (result['success']) {
      print('✅ SEND OTP SUCCESS - API Response:');
      print(result);
      _setLoading(false);
      return true;
    } else {
      _setError(result['message']);
      _setLoading(false);
      return false;
    }
  }

  Future<Map<String, dynamic>> checkMobileExists(String mobile) async {
    final result = await AuthService.checkMobileExists(mobile);
    
    if (result['success']) {
      print('✅ CHECK MOBILE SUCCESS - API Response:');
      print(result);
    }
    
    return result;
  }

// Updated logout method for AuthProvider
// Replace your existing logout method with this

  Future<void> logout(BuildContext? context) async {
    _setLoading(true);

    final result = await AuthService.logout();
    print('✅ LOGOUT - API Response:');
    print(result);

    // Clear user data from SharedPreferences
    await _clearUserData();
    _user = null;

    // IMPORTANT: Clear all provider data when logging out
    if (context != null && context.mounted) {
      try {
        // Clear community provider data
        final communityProvider = Provider.of<CommunityProvider>(context, listen: false);
        communityProvider.clearAllData();
        print('✅ Community data cleared on logout');

        // You can add other provider clears here if needed
        // Example:
        // final postProvider = Provider.of<PostProvider>(context, listen: false);
        // postProvider.clearAllData();

      } catch (e) {
        print('⚠️ Error clearing provider data: $e');
      }
    }

    _setLoading(false);
    notifyListeners();
  }

  // Replace your _saveUserData method with this updated version

  Future<void> _saveUserData(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      print('💾 Attempting to save user data...');
      print('User object: ${user.toString()}');

      // Save token separately
      if (user.token != null && user.token!.isNotEmpty) {
        await prefs.setString('auth_token', user.token!);
        print('✅ Token saved: ${user.token}');
      }

      // Save user ID separately
      if (user.id != null && user.id!.isNotEmpty) {
        await prefs.setString('user_id', user.id!);
        print('✅ User ID saved: ${user.id}');
      }

      // ✅ ADD THIS: Save username separately for video call
      if (user.username.isNotEmpty) {
        await prefs.setString('user_name', user.username);
        print('✅ Username saved: ${user.username}');
      }

      // ✅ ADD THIS: Save mobile separately (useful for other features)
      if (user.mobile.isNotEmpty) {
        await prefs.setString('user_mobile', user.mobile);
        print('✅ Mobile saved: ${user.mobile}');
      }

      // Convert user object to JSON
      final Map<String, dynamic> userMap = user.toJson();
      final String userJson = jsonEncode(userMap);
      await prefs.setString('user_data', userJson);

      print('✅ User data saved successfully');
      print('JSON saved: $userJson');

      // Verify the save worked
      final savedData = prefs.getString('user_data');
      final savedToken = prefs.getString('auth_token');
      final savedUsername = prefs.getString('user_name');
      print('🔍 Verification - Saved data exists: ${savedData != null}');
      print('🔍 Verification - Saved token exists: ${savedToken != null}');
      print('🔍 Verification - Saved username exists: ${savedUsername != null}');

    } catch (e, stackTrace) {
      print('❌ Error saving user data: $e');
      print('Stack trace: $stackTrace');
    }
  }

// Also update your _clearUserData method to clear the new fields
  Future<void> _clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      await prefs.remove('user_id');
      await prefs.remove('user_name');  // ✅ ADD THIS
      await prefs.remove('user_mobile'); // ✅ ADD THIS
      print('✅ User data cleared from SharedPreferences');
    } catch (e) {
      print('❌ Error clearing user data: $e');
    }
  }

// Add this method to your AuthProvider class

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    _setError('');

    try {
      final result = await AuthService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (result['success']) {
        print('✅ CHANGE PASSWORD SUCCESS - API Response:');
        print(result);
        _setLoading(false);
        return true;
      } else {
        _setError(result['message'] ?? 'Failed to change password');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      print('❌ CHANGE PASSWORD ERROR: $e');
      _setError('An error occurred while changing password');
      _setLoading(false);
      return false;
    }
  }



Future<bool> sendForgotPasswordOTP({
  required String email,
  required String mobile,
}) async {
  _setLoading(true);
  _setError('');

  final result = await AuthService.forgotPassword(
    mobile: mobile,
    email: email,
  );

  if (result['success']) {
    print('✅ FORGOT PASSWORD SUCCESS - API Response:');
    print(result);
    _setLoading(false);
    return true;
  } else {
    _setError(result['message']);
    _setLoading(false);
    return false;
  }
}
 
  // Enhanced: Load user data with better error handling and debugging
  // Replace your loadUserFromStorage method with this updated version

  Future<void> loadUserFromStorage() async {
    try {
      print('🔄 Starting loadUserFromStorage...');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userDataString = prefs.getString('user_data');
      final userId = prefs.getString('user_id');
      final userName = prefs.getString('user_name');

      print('🔍 Token from storage: ${token ?? 'null'}');
      print('🔍 User ID from storage: ${userId ?? 'null'}');
      print('🔍 Username from storage: ${userName ?? 'null'}');
      print('🔍 User data from storage: ${userDataString ?? 'null'}');

      if (token != null && userDataString != null && userDataString.isNotEmpty) {
        try {
          // Parse the JSON string back to Map
          final Map<String, dynamic> userJson = jsonDecode(userDataString);
          print('🔍 Parsed JSON: $userJson');

          // Create User object from JSON
          _user = User.fromJson(userJson);
          print('🔍 User object created: ${_user.toString()}');

          // Ensure token is set
          if (_user!.token == null || _user!.token!.isEmpty) {
            print('🔧 Setting token from separate storage');
            // Create new user object with token
            _user = User(
              id: _user!.id,
              username: _user!.username,
              mobile: _user!.mobile,
              isFamilyHead: _user!.isFamilyHead,
              guidStatus: _user!.guidStatus,
              token: token,
            );
          }

          print('✅ User loaded successfully from storage');
          print('   - ID: ${_user!.id}');
          print('   - Username: ${_user!.username}');
          print('   - Mobile: ${_user!.mobile}');
          print('   - Token exists: ${_user!.token != null}');

        } catch (parseError) {
          print('❌ Error parsing user data: $parseError');
          // Clear corrupted data
          await _clearUserData();
          _user = null;
        }
      } else {
        print('ℹ️ No user data found in storage (token: ${token != null}, userData: ${userDataString != null})');
        _user = null;
      }

      _isInitialized = true;
      notifyListeners();

    } catch (e, stackTrace) {
      print('❌ Error in loadUserFromStorage: $e');
      print('Stack trace: $stackTrace');
      _user = null;
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Debug method to check storage contents
  Future<void> debugStorageContents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      print('🐛 All SharedPreferences keys: $keys');
      
      for (String key in keys) {
        final value = prefs.get(key);
        print('🐛 $key: $value');
      }
    } catch (e) {
      print('🐛 Error debugging storage: $e');
    }
  }

  // Optional: Method to check if user data exists in storage
  Future<bool> hasUserDataInStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userData = prefs.getString('user_data');
    return token != null && userData != null;
  }
  
}