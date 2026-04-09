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

  // ── Update User Profile ────────────────────────────────────────────────
  Future<Map<String, dynamic>> updateUserProfile(
      Map<String, dynamic> profileData, {
        String? profileImagePath,
      }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) return _tokenError();

      final uri = Uri.parse('${apiBaseUrl}api/profile');
      final request = http.MultipartRequest('PUT', uri)
        ..headers['Authorization'] = 'Bearer $token';

      profileData.forEach((key, value) {
        if (value != null && key != 'profileImage' && key != 'profileImageBase64') {
          request.fields[key] = value.toString();
        }
      });

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
      ApiService.checkResponse(response); // ✅ 401 check

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
      print('updateUserProfile exception: $e');
      return _exception(e, 'updating profile');
    }
  }

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