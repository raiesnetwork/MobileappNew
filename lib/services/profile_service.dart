import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/apiConstants.dart';
import 'api_service.dart';

class ProfileService {
  // ── Get User Profile ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await ApiService.get('/api/profile');
      ApiService.checkResponse(response);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {'error': false, 'message': 'Profile fetched', 'data': decoded};
      }
      return _errorFrom(response.body, 'Failed to fetch profile');
    } catch (e) {
      return _exception(e, 'fetching profile');
    }
  }

  // ── Get Dashboard Data ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboardData() async {
    try {
      final response = await ApiService.get('/api/profile/dashboard');
      ApiService.checkResponse(response);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {'error': false, 'message': 'Dashboard fetched', 'data': decoded};
      }
      return _errorFrom(response.body, 'Failed to fetch dashboard');
    } catch (e) {
      return _exception(e, 'fetching dashboard');
    }
  }

  // ── Update User Profile with RETRY LOGIC ───────────────────────────────
  Future<Map<String, dynamic>> updateUserProfile(
      Map<String, dynamic> profileData, {
        String? profileImagePath,
      }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) return _tokenError();

      // First attempt
      print('📤 [PROFILE_SERVICE] Attempt 1: Starting profile update...');
      var response = await _sendMultipartProfileUpdate(
        profileData: profileData,
        profileImagePath: profileImagePath,
        token: token,
      );

      // If 401, try refreshing token and retry ONCE
      if (response.statusCode == 401) {
        print('⚠️ [PROFILE_SERVICE] Got 401 — attempting token refresh and retry...');

        final refreshedToken = await ApiService.refreshToken();

        if (refreshedToken != null && refreshedToken.isNotEmpty) {
          print('✅ [PROFILE_SERVICE] Token refreshed, retrying upload...');

          // Retry with fresh token
          response = await _sendMultipartProfileUpdate(
            profileData: profileData,
            profileImagePath: profileImagePath,
            token: refreshedToken,
          );

          if (response.statusCode == 200) {
            print('✅ [PROFILE_SERVICE] Retry successful after token refresh');
            final decoded = _safeJsonDecode(response.body);
            return {
              'error': false,
              'message': decoded['message'] ?? 'Profile updated successfully',
              'data': decoded,
            };
          }
        }

        // Still 401 after retry — now logout
        print('🔐 [PROFILE_SERVICE] 401 still after retry — user needs to login');
        if (ApiService.onUnauthorized != null) {
          ApiService.onUnauthorized!();
        }
      }

      // Handle other status codes
      print('updateUserProfile status: ${response.statusCode}');
      print('updateUserProfile body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Profile updated successfully',
          'data': decoded,
        };
      }

      return _errorFrom(response.body, 'Failed to update profile');
    } catch (e) {
      print('❌ [PROFILE_SERVICE] Exception: $e');
      return _exception(e, 'updating profile');
    }
  }

  // ── Helper: Send multipart request with given token ────────────────────
  Future<http.Response> _sendMultipartProfileUpdate({
    required Map<String, dynamic> profileData,
    required String? profileImagePath,
    required String token,
  }) async {
    try {
      final uri = Uri.parse('${apiBaseUrl}api/profile');
      final request = http.MultipartRequest('PUT', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['x-platform'] = Platform.isAndroid ? 'mobile' : 'mobile'; // Add x-platform header

      // Add fields
      profileData.forEach((key, value) {
        if (value != null && key != 'profileImage' && key != 'profileImageBase64') {
          request.fields[key] = value.toString();
        }
      });

      // Add image if provided
      if (profileImagePath != null && profileImagePath.isNotEmpty) {
        final file = File(profileImagePath);
        if (await file.exists()) {
          request.files.add(await http.MultipartFile.fromPath(
            'profileImage',
            profileImagePath,
          ));
          print('📸 Attaching profile image: $profileImagePath');
        } else {
          print('⚠️ Image file not found: $profileImagePath');
        }
      }

      print('updateUserProfile → fields: ${request.fields.keys}');
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      return response;
    } catch (e) {
      print('❌ [MULTIPART] Error: $e');
      rethrow;
    }
  }

  // ── Request Account Deletion ───────────────────────────────────────────
  Future<Map<String, dynamic>> deleteAccountRequest(String message) async {
    try {
      final body = {'message': message};
      final response = await ApiService.post('/api/auth/delete-account-request', body);
      ApiService.checkResponse(response);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Account deletion request submitted',
          'data': decoded,
        };
      }
      return _errorFrom(response.body, 'Failed to submit deletion request');
    } catch (e) {
      return _exception(e, 'submitting deletion request');
    }
  }

  // // ── Permanently Delete Account ─────────────────────────────────────────
  // Future<Map<String, dynamic>> deleteAccount(String message) async {
  //   try {
  //     final body = {'message': message};
  //     final response = await ApiService.delete('/api/auth/delete-account', body);
  //     ApiService.checkResponse(response);
  //
  //     if (response.statusCode == 200) {
  //       final decoded = jsonDecode(response.body);
  //       return {
  //         'error': false,
  //         'message': decoded['message'] ?? 'Account deleted successfully',
  //         'data': decoded,
  //       };
  //     }
  //     return _errorFrom(response.body, 'Failed to delete account');
  //   } catch (e) {
  //     return _exception(e, 'deleting account');
  //   }
  // }

  // ── Fetch Events ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchEvents() async {
    try {
      final response = await ApiService.get('/api/profile/event/fetch');
      ApiService.checkResponse(response);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> events = [];
        if (decoded is List) {
          events = decoded;
        } else if (decoded is Map) {
          events = decoded['events'] ?? decoded['data'] ?? [];
        }
        return {'error': false, 'message': 'Events fetched', 'events': events};
      }
      return _errorFrom(response.body, 'Failed to fetch events',
          extra: {'events': []});
    } catch (e) {
      return {'error': true, 'message': e.toString(), 'events': []};
    }
  }

  // ── Create Event ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> eventData) async {
    try {
      final response = await ApiService.post('/api/profile/event', eventData);
      ApiService.checkResponse(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = _safeJsonDecode(response.body);
        final event = decoded['event'] ?? decoded['data'] ?? decoded;
        return {
          'error': false,
          'message': decoded['message'] ?? 'Event created',
          'event': event,
        };
      }
      return _errorFrom(response.body, 'Failed to create event',
          extra: {'event': null});
    } catch (e) {
      return {'error': true, 'message': e.toString(), 'event': null};
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────
  Map<String, dynamic> _tokenError() => {
    'error': true,
    'message': 'Authentication token is missing',
    'data': null,
  };

  Map<String, dynamic> _errorFrom(String body, String fallback,
      {Map<String, dynamic>? extra}) {
    final decoded = _safeJsonDecode(body);
    return {
      'error': true,
      'message': decoded['message'] ?? fallback,
      'data': null,
      ...?extra,
    };
  }

  Map<String, dynamic> _exception(Object e, String action) => {
    'error': true,
    'message': 'Error $action: $e',
    'data': null,
  };

  Map<String, dynamic> _safeJsonDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {'message': 'Failed to parse response'};
    }
  }
}