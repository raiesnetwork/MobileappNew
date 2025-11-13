import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '71249839379-k60vkb5jiibh2k2j0529is3tockf5ene.apps.googleusercontent.com',
  );

  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login cancelled')),
        );
        return;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No ID token found')),
        );
        return;
      }

      final Uri url =
      Uri.parse('https://api.ixes.ai/api/mobile/google-OAuth');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': idToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Sign-In successful')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server Error: ${response.body}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }
}
