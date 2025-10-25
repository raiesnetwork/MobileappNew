import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://api.ixes.ai';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (requireAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<http.Response> get(String endpoint, {bool requireAuth = true}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print('GET: $url');
    final headers = await _getHeaders(requireAuth: requireAuth);

    return await http.get(url, headers: headers);
  }

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
    {bool requireAuth = true}
  ) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print('POST: $url');
    final headers = await _getHeaders(requireAuth: requireAuth);

    return await http.post(
      url,
      headers: headers,
      body: json.encode(body),
    );
  }

  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body,
    {bool requireAuth = true}
  ) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print('PUT: $url');
    final headers = await _getHeaders(requireAuth: requireAuth);

    return await http.put(
      url,
      headers: headers,
      body: json.encode(body),
    );
  }

  static Future<http.Response> delete(String endpoint, {bool requireAuth = true}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print('DELETE: $url');
    final headers = await _getHeaders(requireAuth: requireAuth);

    return await http.delete(url, headers: headers);
  }
}
