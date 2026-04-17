import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import '../screens/auth/login_screen.dart';
import 'communities_provider.dart';

import '../main.dart' show navigatorKey;

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isInitialized = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;

  void _setLoading(bool loading) { _isLoading = loading; notifyListeners(); }
  void _setError(String error) { _errorMessage = error; notifyListeners(); }
  void clearError() { _errorMessage = ''; notifyListeners(); }

  Future<void> saveUserFromGoogle({
    required String token,
    required String userId,
    required String username,
    Map<String, dynamic>? userData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String resolvedId = userId;
      String resolvedUsername = username;

      if (resolvedId.isEmpty && token.isNotEmpty) {
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            String payload = parts[1];
            while (payload.length % 4 != 0) payload += '=';
            final decoded = utf8.decode(base64Url.decode(payload));
            final Map<String, dynamic> payloadMap = jsonDecode(decoded);
            final userMap = payloadMap['user'] as Map<String, dynamic>?;
            resolvedId = userMap?['id']?.toString() ?? '';
            resolvedUsername = userMap?['username']?.toString() ?? resolvedUsername;
          }
        } catch (e) { debugPrint('❌ JWT decode error: $e'); }
      }

      await prefs.setString('auth_token', token);
      await prefs.setString('user_id', resolvedId);
      await prefs.setString('user_name', resolvedUsername);

      final Map<String, dynamic> userMap = {
        ...?userData, 'id': resolvedId, 'username': resolvedUsername,
        'token': token, 'mobile': '', 'isFamilyHead': false,
        'guidStatus': userData?['guid'] ?? false,
      };
      await prefs.setString('user_data', jsonEncode(userMap));

      _user = User(
        id: resolvedId, username: resolvedUsername, mobile: '',
        isFamilyHead: false, guidStatus: userData?['guid'] ?? false, token: token,
      );
      notifyListeners();
    } catch (e) { debugPrint('❌ Error saving Google user data: $e'); }
  }

  Future<bool> signup({
    required String mobile, required String username,
    required String password, required bool isFamilyHead, required bool agreement,
  }) async {
    _setLoading(true); _setError('');
    final result = await AuthService.signup(
      mobile: mobile, username: username, password: password,
      isFamilyHead: isFamilyHead, agreement: agreement,
    );
    if (result['success']) {
      _user = result['user'];
      await _saveUserData(_user!);
      _setLoading(false);
      return true;
    } else {
      _setError(result['message']); _setLoading(false); return false;
    }
  }

  Future<Map<String, dynamic>> login({required String mobile, String? password}) async {
    _setLoading(true); _setError('');
    final result = await AuthService.login(mobile: mobile, password: password);
    if (result['success']) {
      if (result['otpRequired'] == true) {
        _setLoading(false);
        return {'success': true, 'otpRequired': true, 'message': result['message']};
      } else {
        _user = result['user'];
        await _saveUserData(_user!);
        _setLoading(false);
        return {'success': true, 'otpRequired': false, 'message': result['message']};
      }
    } else {
      _setError(result['message']); _setLoading(false);
      return {'success': false, 'message': result['message']};
    }
  }

  Future<bool> loginWithOTP({required String mobile, required String otp}) async {
    _setLoading(true); _setError('');
    final result = await AuthService.loginWithOTP(mobile: mobile, otp: otp);
    final success = result['success'] == true;
    if (success) {
      _user = User(
        id: result['user_id'] ?? '', username: result['username'] ?? '',
        mobile: mobile, isFamilyHead: false,
        guidStatus: result['guid'] ?? false, token: result['token'],
      );
      await _saveUserData(_user!);
      // ✅ Save FCM token for the NEW logged-in user.
      // This overwrites any stale mapping left by a previous user on this device.
      await FcmService.saveFcmToken();
      FcmService.listenForTokenRefresh();
    } else {
      _setError(result['message'] ?? 'OTP verification failed');
    }
    _setLoading(false);
    return success;
  }

  Future<bool> sendOTP(String mobile) async {
    _setLoading(true); _setError('');
    final result = await AuthService.sendOTP(mobile);
    if (result['success']) { _setLoading(false); return true; }
    else { _setError(result['message']); _setLoading(false); return false; }
  }

  Future<Map<String, dynamic>> checkMobileExists(String mobile) async {
    return await AuthService.checkMobileExists(mobile);
  }

  // ============================================================================
  // LOGOUT
  //
  // ✅ FIX — WRONG USER RECEIVING CALLS (Root Cause + Fix):
  //
  // Problem: One physical device has ONE FCM token. When UserA (Uday) logs out
  // and UserB (Sarath) logs in, the server STILL has Uday→<token> mapping.
  // When someone calls Uday, the FCM push goes to the device token → Sarath
  // sees Uday's incoming call. This is the core multi-user FCM token bug.
  //
  // Fix: BEFORE clearing our auth token, call FcmService.clearFcmToken()
  // which tells the backend: "remove this device's FCM token from current user".
  // After logout, when the new user logs in, their saveFcmToken() registers
  // the token under the new user.
  //
  // For full reliability, also add server-side logic in save-fcm:
  // "If this token already exists for another user, remove it from them first."
  // ============================================================================
  Future<void> logout(BuildContext? context) async {
    _setLoading(true);

    // ✅ Step 1: Clear FCM token WHILE we still have auth credentials
    // Must be BEFORE _clearUserData() which removes the auth token
    await FcmService.clearFcmToken();

    final result = await AuthService.logout();
    debugPrint('✅ LOGOUT: $result');

    await _clearUserData();
    _user = null;

    if (context != null && context.mounted) {
      try {
        final communityProvider = Provider.of<CommunityProvider>(context, listen: false);
        communityProvider.clearAllData();
      } catch (e) { debugPrint('⚠️ Error clearing provider data: $e'); }
    }

    _setLoading(false);
    notifyListeners();
  }

  // ============================================================================
  // FORCE LOGOUT
  // ✅ Same FCM clear fix — another device stole session, still need to clear token
  // ============================================================================
  Future<void> forceLogout() async {
    if (_user == null) return;
    debugPrint('🔐 [FORCE LOGOUT] Session expired');

    // ✅ Clear FCM token BEFORE clearing local auth data
    await FcmService.clearFcmToken();

    await _clearUserData();
    _user = null;
    notifyListeners();

    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      try { context.read<CommunityProvider>().clearAllData(); } catch (e) {}
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false,
      );
    }
  }

  Future<void> _saveUserData(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (user.token != null && user.token!.isNotEmpty) await prefs.setString('auth_token', user.token!);
      if (user.id != null && user.id!.isNotEmpty) await prefs.setString('user_id', user.id!);
      if (user.username.isNotEmpty) await prefs.setString('user_name', user.username);
      if (user.mobile.isNotEmpty) await prefs.setString('user_mobile', user.mobile);
      await prefs.setString('user_data', jsonEncode(user.toJson()));
    } catch (e) { debugPrint('❌ Error saving user data: $e'); }
  }

  Future<void> _clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('user_mobile');
      debugPrint('✅ User data cleared');
    } catch (e) { debugPrint('❌ Error clearing user data: $e'); }
  }

  Future<bool> changePassword({required String currentPassword, required String newPassword}) async {
    _setLoading(true); _setError('');
    try {
      final result = await AuthService.changePassword(currentPassword: currentPassword, newPassword: newPassword);
      if (result['success']) { _setLoading(false); return true; }
      else { _setError(result['message'] ?? 'Failed to change password'); _setLoading(false); return false; }
    } catch (e) { _setError('An error occurred'); _setLoading(false); return false; }
  }

  Future<bool> sendForgotPasswordOTP({required String email, required String mobile}) async {
    _setLoading(true); _setError('');
    final result = await AuthService.forgotPassword(mobile: mobile, email: email);
    if (result['success']) { _setLoading(false); return true; }
    else { _setError(result['message']); _setLoading(false); return false; }
  }

  Future<void> loadUserFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userDataString = prefs.getString('user_data');

      if (token != null && userDataString != null && userDataString.isNotEmpty) {
        try {
          final Map<String, dynamic> userJson = jsonDecode(userDataString);
          _user = User.fromJson(userJson);
          if (_user!.token == null || _user!.token!.isEmpty) {
            _user = User(
              id: _user!.id, username: _user!.username, mobile: _user!.mobile,
              isFamilyHead: _user!.isFamilyHead, guidStatus: _user!.guidStatus, token: token,
            );
          }
        } catch (e) {
          debugPrint('❌ Error parsing user data: $e');
          await _clearUserData(); _user = null;

        }
      } else { _user = null; }

      ApiService.onUnauthorized = () => forceLogout();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error in loadUserFromStorage: $e');
      _user = null; _isInitialized = true; notifyListeners();
    }
  }

  Future<bool> hasUserDataInStorage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') != null && prefs.getString('user_data') != null;
  }
}