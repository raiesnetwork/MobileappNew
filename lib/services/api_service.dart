import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://api.ixes.ai';

  // ✅ Registered by AuthProvider.loadUserFromStorage() — fires forceLogout()
  static Function()? onUnauthorized;

  // ✅ Call this after ANY http.Response anywhere in the app
  // Paste this one line after every response in every service file:
  //   ApiService.checkResponse(response);
  static void checkResponse(http.Response response) {
    if (response.statusCode == 401 && onUnauthorized != null) {
      onUnauthorized!();
    }
  }

  static void _handleResponse(http.Response response) {
    if (response.statusCode == 401 && onUnauthorized != null) {
      onUnauthorized!();
    }
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'x-platform': 'mobile',
    };
    if (requireAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
        print('🔑 [AUTH TOKEN] Bearer $token'); // ✅ ADD THIS
      } else {
        print('⚠️ [AUTH TOKEN] No token found!'); // ✅ ADD THIS
      }
    }
    return headers;
  }
  static Future<http.Response> multipart({
    required String endpoint,
    required String method,
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
    bool requireAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print('$method (multipart): $url');

    final request = http.MultipartRequest(method, url);

    // ✅ All headers in one place including x-platform
    request.headers['x-platform'] = 'mobile';
    if (requireAuth) {
      final token = await _getToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
    }

    if (fields != null) request.fields.addAll(fields);
    if (files != null) request.files.addAll(files);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (requireAuth) _handleResponse(response);
    return response;
  }

  static Future<http.Response> get(String endpoint, {bool requireAuth = true}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print('GET: $url');
    final headers = await _getHeaders(requireAuth: requireAuth);
    final response = await http.get(url, headers: headers);
    if (requireAuth) _handleResponse(response);
    return response;
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body,
      {bool requireAuth = true}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print('POST: $url');
    final headers = await _getHeaders(requireAuth: requireAuth);
    final response = await http.post(url, headers: headers, body: json.encode(body));
    if (requireAuth) _handleResponse(response);
    return response;
  }

  static Future<http.Response> put(String endpoint, Map<String, dynamic> body,
      {bool requireAuth = true}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print('PUT: $url');
    final headers = await _getHeaders(requireAuth: requireAuth);
    final response = await http.put(url, headers: headers, body: json.encode(body));
    if (requireAuth) _handleResponse(response);
    return response;
  }

  static Future<http.Response> delete(String endpoint, {bool requireAuth = true}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print('DELETE: $url');
    final headers = await _getHeaders(requireAuth: requireAuth);
    final response = await http.delete(url, headers: headers);
    if (requireAuth) _handleResponse(response);
    return response;
  }

  static Future<bool> saveFcmToken(String fcmToken) async {
    try {
      final platform = Platform.isAndroid ? "android" : "ios";
      final response = await post(
        '/api/mobile/user/save-fcm',
        {"fcmToken": fcmToken, "platform": platform},
        requireAuth: true,
      );
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', fcmToken);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error saving FCM token: $e');
      return false;
    }
  }
}