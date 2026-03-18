import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;



class GoogleAuthResponse {
  final bool success;
  final String? token; // JWT from backend
  final String? message;
  final Map<String, dynamic>? user;

  GoogleAuthResponse({
    required this.success,
    this.token,
    this.message,
    this.user,
  });

  factory GoogleAuthResponse.fromJson(Map<String, dynamic> json) {
    return GoogleAuthResponse(
      success: json['success'] == true,
      token: json['token'],
      message: json['message'],
      user: json['user'],
    );
  }
}

class GoogleAuthService {
  // ── Configuration ──────────────────────────────────────────────────────────

  static const String _serverClientId =
      '574318127867-kbc7sr8jf2g3eravojk5ur34ncisvn38.apps.googleusercontent.com';

  // TODO: Replace with your actual base URL once backend provides the endpoint
  static const String _baseUrl = 'https://api.ixes.ai';

  static const String _googleMobileEndpoint = '/api/auth/google/mobile';

  // ── Google Sign-In instance ─────────────────────────────────────────────────

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _serverClientId,
    scopes: ['email', 'profile'],
  );

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Signs in with Google and authenticates with the backend.
  ///
  /// Returns [GoogleAuthResponse] with JWT token on success.
  /// Returns [GoogleAuthResponse] with error message on failure.
  Future<GoogleAuthResponse> signInWithGoogle() async {
    try {
      // Step 1: Trigger Google Sign-In
      debugPrint('GoogleAuthService: Starting Google Sign-In...');
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        debugPrint('GoogleAuthService: User cancelled sign-in.');
        return GoogleAuthResponse(
          success: false,
          message: 'Sign-in cancelled by user.',
        );
      }

      debugPrint('GoogleAuthService: Got account → ${account.email}');

      // Step 2: Get ID Token
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        debugPrint('GoogleAuthService: ID Token is null.');
        return GoogleAuthResponse(
          success: false,
          message: 'Failed to retrieve Google ID Token.',
        );
      }

      debugPrint('GoogleAuthService: ID Token obtained ✅');

      // Step 3: Send ID Token to backend
      return await _sendTokenToBackend(idToken);
    } on Exception catch (e) {
      debugPrint('GoogleAuthService: Exception → $e');
      return GoogleAuthResponse(
        success: false,
        message: 'Google Sign-In failed: ${e.toString()}',
      );
    }
  }

  /// Signs out the current Google user.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      debugPrint('GoogleAuthService: Signed out from Google.');
    } catch (e) {
      debugPrint('GoogleAuthService: Sign-out error → $e');
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// POSTs the Google ID Token to the backend and returns the JWT response.
  ///
  /// Expected request body:  { "idToken": "<google_id_token>" }
  /// Expected success response: { "success": true, "token": "<jwt>", "user": { ... } }
  /// Expected failure response: { "success": false, "message": "<error>" }
  Future<GoogleAuthResponse> _sendTokenToBackend(String idToken) async {
    final Uri url = Uri.parse('$_baseUrl$_googleMobileEndpoint');

    debugPrint('GoogleAuthService: Sending ID Token to → $url');

    try {
      final http.Response response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      )
          .timeout(const Duration(seconds: 30));

      debugPrint('GoogleAuthService: Backend status → ${response.statusCode}');

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        debugPrint('GoogleAuthService: JWT received ✅');
        return GoogleAuthResponse.fromJson(data);
      } else {
        final String errorMsg = data['message'] ?? 'Authentication failed.';
        debugPrint('GoogleAuthService: Backend error → $errorMsg');
        return GoogleAuthResponse(success: false, message: errorMsg);
      }
    } on Exception catch (e) {
      debugPrint('GoogleAuthService: Network/parse error → $e');
      return GoogleAuthResponse(
        success: false,
        message: 'Network error. Please try again.',
      );
    }
  }
}