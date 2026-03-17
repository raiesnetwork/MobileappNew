import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/apiConstants.dart';

class ProfileService {
  // ── Get User Profile ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final token = await _getToken();
      if (token == null) return _tokenError();

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/profile'),
        headers: _authHeaders(token),
      );

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
      final token = await _getToken();
      if (token == null) return _tokenError();

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/profile/dashboard'),
        headers: _authHeaders(token),
      );

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
  // API expects multipart/form-data with profileImage as a file field.
  // profileData keys: name, birthdate, location, address, email, mobile,
  //                   isFamilyHead (bool as string)
  // profileImagePath: local file path (nullable — omit if not changing photo)
  Future<Map<String, dynamic>> updateUserProfile(
      Map<String, dynamic> profileData, {
        String? profileImagePath,
      }) async {
    try {
      final token = await _getToken();
      if (token == null) return _tokenError();

      final uri = Uri.parse('${apiBaseUrl}api/profile');
      final request = http.MultipartRequest('PUT', uri)
        ..headers['Authorization'] = 'Bearer $token';

      // Add text fields
      profileData.forEach((key, value) {
        if (value != null && key != 'profileImage' && key != 'profileImageBase64') {
          request.fields[key] = value.toString();
        }
      });

      // Add image file if provided
      if (profileImagePath != null && profileImagePath.isNotEmpty) {
        final file = File(profileImagePath);
        if (await file.exists()) {
          final ext = profileImagePath.split('.').last.toLowerCase();
          final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
          request.files.add(await http.MultipartFile.fromPath(
            'profileImage',   // ← must match API field name exactly
            profileImagePath,
            // ignore: deprecated_member_use
          ));
          print('📸 Attaching profile image: $profileImagePath ($mimeType)');
        } else {
          print('⚠️ Image file not found: $profileImagePath');
        }
      }

      print('updateUserProfile → fields: ${request.fields.keys}');
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

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
      final token = await _getToken();
      if (token == null) return {'error': true, 'message': 'No token', 'events': []};

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/profile/event/fetch'),
        headers: _authHeaders(token),
      );

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
      final token = await _getToken();
      if (token == null) return {'error': true, 'message': 'No token', 'event': null};

      final response = await http.post(
        Uri.parse('${apiBaseUrl}api/profile/event'),
        headers: {..._authHeaders(token), 'Content-Type': 'application/json'},
        body: jsonEncode(eventData),
      );

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
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('auth_token');
    if (t == null || t.isEmpty) return null;
    return t;
  }

  Map<String, String> _authHeaders(String token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

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