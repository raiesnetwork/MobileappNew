import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/apiConstants.dart';

class ApiService {
  static Function()? onUnauthorized;
  static bool _isRefreshing = false;

  // ─── Token expiry check ───────────────────────────────────────────────────
  static bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      String payload = parts[1];
      while (payload.length % 4 != 0) payload += '=';
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = map['exp'] as int?;
      if (exp == null) return true;
      // Consider expired if less than 5 minutes remaining
      final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return nowSecs > (exp - 300);
    } catch (_) {
      return true;
    }
  }

  // ─── Refresh token ────────────────────────────────────────────────────────
  static Future<String?> refreshToken() async {
    if (_isRefreshing) return null;
    _isRefreshing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString('auth_token');
      if (oldToken == null) return null;

      final url = Uri.parse('${apiBaseUrl}api/auth/refresh-token');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-platform': 'mobile',
          'Authorization': 'Bearer $oldToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = data['token'] as String?;
        if (newToken != null && newToken.isNotEmpty) {
          await prefs.setString('auth_token', newToken);
          print('✅ [TOKEN] Refreshed successfully');
          return newToken;
        }
      }
      print('⚠️ [TOKEN] Refresh failed: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ [TOKEN] Refresh error: $e');
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  // ─── Get valid token (refresh if needed) ──────────────────────────────────
  static Future<String?> getValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return null;
    if (isTokenExpired(token)) {
      print('⚠️ [TOKEN] Expired or expiring soon — refreshing...');
      return await refreshToken();
    }
    return token;
  }

  static void checkResponse(http.Response response) {
    if (response.statusCode == 401 && onUnauthorized != null) {
      onUnauthorized!();
    }
  }

  static void _handleResponse(http.Response response) {
    if (response.statusCode == 401 && onUnauthorized != null) {
      print('🔐 [AUTH] 401 Unauthorized — logging out');
      onUnauthorized!();
    }
    // 403 is "Forbidden" — request was rejected for some other reason,
    // not because the session expired. Don't logout the user for that.
  }

  static String _clean(String endpoint) {
    return endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
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
      // Always get valid (non-expired) token
      final token = await getValidToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
        print('🔑 [AUTH TOKEN] Bearer $token');
      } else {
        print('⚠️ [AUTH TOKEN] No valid token — user may need to login again');
        if (onUnauthorized != null) onUnauthorized!();
      }
    }
    return headers;
  }

  static Future<http.Response> getFromUrl(String fullUrl, {String? authToken}) async {
    final uri = Uri.parse(fullUrl);
    final token = authToken ?? await getValidToken();
    final headers = {
      'Content-Type': 'application/json',
      'x-platform': 'mobile',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return await http.get(uri, headers: headers);
  }

  static Future<http.Response> postToUrl(
      String fullUrl,
      Map<String, dynamic> body, {
        String? authToken,
      }) async {
    final uri = Uri.parse(fullUrl);
    final token = authToken ?? await getValidToken();
    final headers = {
      'Content-Type': 'application/json',
      'x-platform': 'mobile',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return await http.post(uri, headers: headers, body: json.encode(body));
  }

  static Future<http.Response> multipart({
    required String endpoint,
    required String method,
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
    bool requireAuth = true,
  }) async {
    final url = Uri.parse('$apiBaseUrl${_clean(endpoint)}');
    print('$method (multipart): $url');

    final request = http.MultipartRequest(method, url);
    request.headers['x-platform'] = 'mobile';
    if (requireAuth) {
      final token = await getValidToken();
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
    final url = Uri.parse('$apiBaseUrl${_clean(endpoint)}');
    print('GET: $url');
    final headers = await _getHeaders(requireAuth: requireAuth);
    final response = await http.get(url, headers: headers);
    if (requireAuth) _handleResponse(response);
    return response;
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body,
      {bool requireAuth = true}) async {
    final url = Uri.parse('$apiBaseUrl${_clean(endpoint)}');
    print('POST: $url');
    final headers = await _getHeaders(requireAuth: requireAuth);
    final response = await http.post(url, headers: headers, body: json.encode(body));
    if (requireAuth) _handleResponse(response);
    return response;
  }

  static Future<http.Response> put(String endpoint, Map<String, dynamic> body,
      {bool requireAuth = true}) async {
    final url = Uri.parse('$apiBaseUrl${_clean(endpoint)}');
    print('PUT: $url');
    final headers = await _getHeaders(requireAuth: requireAuth);
    final response = await http.put(url, headers: headers, body: json.encode(body));
    if (requireAuth) _handleResponse(response);
    return response;
  }

  static Future<http.Response> delete(String endpoint, {bool requireAuth = true}) async {
    final url = Uri.parse('$apiBaseUrl${_clean(endpoint)}');
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
        'api/mobile/user/save-fcm',
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